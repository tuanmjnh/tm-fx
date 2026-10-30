//+------------------------------------------------------------------+
//|                                                      DCALabEA.mq5 |
//|        MT5 EA Lab - bounded virtual DCA basket (simulation)       |
//|                                                                  |
//| Opens one virtual position and may add a hard-capped number of    |
//| additions when price distance or bar interval triggers. No       |
//| order-sending call, no trade class and no broker/account API.     |
//| There is no infinite averaging: additions are bounded by count,   |
//| per-add volume and total virtual exposure.                        |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Simulation-only DCA basket with hard add and exposure caps."
#property description "No trading functions: virtual positions and CSV logs only."

#include "../Include/Sim/SimPortfolio.mqh"
#include "../Include/Sim/SimCostModel.mqh"
#include "../Include/Sim/SimRiskGuard.mqh"
#include "../Include/Sim/SimDca.mqh"
#include "../Include/Sim/SimGrid.mqh"
#include "../Include/Sim/SimLogger.mqh"

enum ENUM_DCA_SIDE
  {
   DCA_LONG  = 1,
   DCA_SHORT = -1
  };

input group "Simulation"
input double InpInitialBalance      = 10000.0;  // virtual starting balance
input bool   InpEnableLog           = true;     // write CSV to MQL5/Files
input string InpLogFile             = "sim_dca_log.csv";
input bool   InpDebug               = false;

input group "DCA"
input ENUM_DCA_SIDE InpDcaSide      = DCA_LONG;
input double InpBaseVirtualVolume   = 0.10;     // initial entry volume
input ENUM_SIM_DCA_TRIGGER InpTriggerMode = SIM_DCA_PRICE_DISTANCE;
input double InpDcaDistancePoints   = 300.0;    // used when trigger = price
input int    InpBarsBetweenAdds     = 5;        // used when trigger = bars
input int    InpMaxDcaAdds          = 3;        // 0 = no additions at all
input double InpAddVolumeMultiplier = 1.50;     // add volume = base * mult^n
input double InpMaxAddVolume        = 1.00;     // per-add hard cap

input group "Exit"
input double InpBasketTargetPoints  = 600.0;    // average-entry target
input double InpBasketStopPoints    = 900.0;    // average-entry stop (mandatory)

input group "RiskGuard"
input double InpMaxSpreadPoints     = 50.0;
input double InpMaxVirtualExposure  = 2.0;      // normalized volume cap
input double InpMaxDailyLossPct     = 2.0;      // 0 = disabled
input double InpMaxDrawdownPct      = 5.0;      // 0 = disabled
input bool   InpHaltOnBreach        = false;

input group "Costs (modelled)"
input double InpCommissionPerVolume = 0.0;
input double InpSlippagePoints      = 0.0;

CSimPortfolio    g_portfolio;
CSimCostModel    g_cost;
CSimRiskGuard    g_risk;
CSimLogger       g_logger;

double   g_point=0.0;
string   g_config_hash="";
string   g_timeframe_text="";
datetime g_last_bar=0;
datetime g_last_fill_bar=0;
datetime g_last_exit_bar=0;
datetime g_last_block_bar=0;
double   g_mid=0.0;
double   g_day_start_equity=0.0;
long     g_day_key=0;
ENUM_SIM_SIDE g_side=SIM_SIDE_BUY;

int      g_dca_adds=0;
int      g_total_adds=0;
int      g_entries=0;
int      g_closed_positions=0;
int      g_baskets_closed=0;

//+------------------------------------------------------------------+
//| Validation                                                       |
//+------------------------------------------------------------------+
bool ValidateInputs(string &error)
  {
   if(!SimValidateInitialBalance(InpInitialBalance,error))
      return(false);
   if(!SimValidateVolume(InpBaseVirtualVolume,error))
      return(false);
   if(!SimValidateMultiplier(InpAddVolumeMultiplier,error))
      return(false);
   if(InpDcaSide!=DCA_LONG && InpDcaSide!=DCA_SHORT)
     {
      error="dca_side_invalid";
      return(false);
     }

   if(!SimIsFinite(InpMaxAddVolume) || InpMaxAddVolume<InpBaseVirtualVolume)
     {
      error="max_add_volume_must_cover_base_volume";
      return(false);
     }
   if(InpMaxAddVolume>1000.0)
     {
      error="max_add_volume_must_not_exceed_1000";
      return(false);
     }

   if(InpTriggerMode!=SIM_DCA_PRICE_DISTANCE &&
      InpTriggerMode!=SIM_DCA_BAR_INTERVAL)
     {
      error="dca_trigger_mode_invalid";
      return(false);
     }
   if(InpTriggerMode==SIM_DCA_PRICE_DISTANCE)
     {
      if(!SimIsFinite(InpDcaDistancePoints) || InpDcaDistancePoints<=0.0)
        {
         error="dca_distance_must_be_positive";
         return(false);
        }
     }
   else
     {
      if(InpBarsBetweenAdds<1)
        {
         error="bars_between_adds_must_be_at_least_one";
         return(false);
        }
     }

   if(InpMaxDcaAdds<0 || InpMaxDcaAdds>1000)
     {
      error="max_dca_adds_must_be_between_0_and_1000";
      return(false);
     }

   if(!SimIsFinite(InpBasketStopPoints) || InpBasketStopPoints<=0.0)
     {
      error="basket_stop_points_must_be_positive";
      return(false);
     }
   if(!SimIsFinite(InpBasketTargetPoints) || InpBasketTargetPoints<=0.0)
     {
      error="basket_target_points_must_be_positive";
      return(false);
     }

   if(!SimIsFinite(InpMaxVirtualExposure) ||
      InpMaxVirtualExposure<InpBaseVirtualVolume)
     {
      error="max_virtual_exposure_must_cover_base_volume";
      return(false);
     }
   if(InpMaxVirtualExposure>1000.0)
     {
      error="max_virtual_exposure_must_not_exceed_1000";
      return(false);
     }
   if(!SimValidateSpreadPoints(InpMaxSpreadPoints,error))
      return(false);
   if(!SimValidatePercent(InpMaxDailyLossPct,error))
     {
      error="max_daily_loss_pct_must_be_between_0_and_100";
      return(false);
     }
   if(!SimValidatePercent(InpMaxDrawdownPct,error))
     {
      error="max_drawdown_pct_must_be_between_0_and_100";
      return(false);
     }
   if(!SimValidateCommission(InpCommissionPerVolume,error))
      return(false);
   if(!SimValidateSlippagePoints(InpSlippagePoints,error))
      return(false);
   if(InpEnableLog && StringLen(InpLogFile)==0)
     {
      error="log_file_must_not_be_empty";
      return(false);
     }
   error="";
   return(true);
  }

string BuildConfigHash(void)
  {
   const string text=g_cost.Fingerprint()+g_risk.Fingerprint()+
                     SimFormatFingerprintPartInt("dca.side",(int)InpDcaSide)+
                     SimFormatFingerprintPart("dca.base_volume",
                                              InpBaseVirtualVolume,4)+
                     SimFormatFingerprintPartInt("dca.trigger_mode",
                                                  (int)InpTriggerMode)+
                     SimFormatFingerprintPart("dca.distance",
                                              InpDcaDistancePoints,1)+
                     SimFormatFingerprintPartInt("dca.bars",
                                                 InpBarsBetweenAdds)+
                     SimFormatFingerprintPartInt("dca.max_adds",InpMaxDcaAdds)+
                     SimFormatFingerprintPart("dca.add_mult",
                                              InpAddVolumeMultiplier,4)+
                     SimFormatFingerprintPart("dca.max_add_volume",
                                              InpMaxAddVolume,4)+
                     SimFormatFingerprintPart("dca.basket_target",
                                              InpBasketTargetPoints,1)+
                     SimFormatFingerprintPart("dca.basket_stop",
                                              InpBasketStopPoints,1)+
                     SimFormatFingerprintPartInt("dca.balance",
                                                 (int)MathRound(InpInitialBalance));
   return(SimHashString(text));
  }

//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
void LogEvent(const string event_name,const ENUM_SIM_SIDE side,
              const double price,const double volume,const double entry,
              const double sl,const double tp,const double exposure,
              const string reason)
  {
   if(!g_logger.IsOpen())
      return;

   SimLogRecord record;
   SimClearLogRecord(record);
   record.logged_at=TimeCurrent();
   record.bar_time=g_last_bar;
   record.ea="DCALabEA";
   record.version="1.00";
   record.config_hash=g_config_hash;
   record.symbol=_Symbol;
   record.timeframe=g_timeframe_text;
   record.event=event_name;
   record.side=side;
   record.price=price;
   record.volume=volume;
   record.entry=entry;
   record.sl=sl;
   record.tp=tp;
   record.exposure=exposure;
   record.equity=(g_portfolio.IsInitialized() ? g_portfolio.Equity(g_mid) : 0.0);
   record.drawdown_pct=g_portfolio.MaxDrawdownPct();
   record.reason=reason;

   string error="";
   if(!g_logger.Write(record,error))
      PrintFormat("LAB|ERROR|dca|log_write_failed|%s",error);
  }

void LogBlocked(const string reason,const int add_index,
                const datetime bar_time)
  {
   if(bar_time==g_last_block_bar)
      return;
   g_last_block_bar=bar_time;
   LogEvent("RISK",g_side,g_mid,0.0,g_portfolio.AverageEntry(),0.0,0.0,
            g_portfolio.Exposure(),
            StringFormat("DCA_BLOCKED|reason=%s|add=%d|mode=%s",
                         reason,add_index,
                         EnumToString(InpTriggerMode)));
  }

void LogRiskDecision(const SimRiskDecision &decision,const double volume,
                     const int add_index)
  {
   LogEvent("RISK",g_side,g_mid,volume,g_portfolio.AverageEntry(),0.0,0.0,
            g_portfolio.Exposure(),
            StringFormat("DCA_BLOCKED|reason=%s|add=%d|state=%s",
                         decision.reason,add_index,
                         SimRiskStateName(decision.state)));
  }

//+------------------------------------------------------------------+
//| Day tracking                                                     |
//+------------------------------------------------------------------+
void UpdateDayStart(const double equity)
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   const long key=(long)dt.year*10000+(long)dt.mon*100+(long)dt.day;
   if(key!=g_day_key)
     {
      g_day_key=key;
      g_day_start_equity=equity;
     }
  }

//+------------------------------------------------------------------+
//| Risk                                                             |
//+------------------------------------------------------------------+
SimRiskDecision EvaluateRisk(const double volume,const int dca_adds,
                             const datetime bar_time)
  {
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   SimRiskContext ctx;
   ctx.spread_points=(bid>0.0 && ask>0.0 ? (ask-bid)/g_point : 0.0);
   ctx.price_valid=(bid>0.0 && ask>0.0);
   ctx.open_positions=g_portfolio.OpenPositions();
   ctx.grid_levels=0;
   ctx.dca_adds=dca_adds;
   ctx.exposure=g_portfolio.Exposure();
   ctx.volume_to_add=volume;
   ctx.equity=g_portfolio.Equity(g_mid);
   ctx.day_start_equity=g_day_start_equity;
   ctx.peak_equity=g_portfolio.PeakEquity();
   ctx.bar_time=bar_time;
   return(g_risk.Evaluate(ctx));
  }

//+------------------------------------------------------------------+
//| Position lifecycle                                               |
//+------------------------------------------------------------------+
bool OpenPosition(const double volume,const datetime bar_time,
                  const string reason_text)
  {
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double requested=(g_side==SIM_SIDE_BUY ? ask : bid);
   const double fill=g_cost.FillPrice(g_side,requested,0.0);
   if(fill<=0.0)
      return(false);

   const double commission=g_cost.Commission(volume);
   string error="";
   if(!g_portfolio.Open(g_side,fill,volume,commission,error))
     {
      PrintFormat("LAB|ERROR|dca|open_failed|%s",error);
      return(false);
     }

   g_last_fill_bar=bar_time;
   LogEvent("ENTRY",g_side,fill,volume,g_portfolio.AverageEntry(),0.0,0.0,
            g_portfolio.Exposure(),reason_text);
   if(InpDebug)
      PrintFormat("LAB|DEBUG|dca|fill|fill=%.8f|volume=%.4f|exposure=%.4f",
                  fill,volume,g_portfolio.Exposure());
   return(true);
  }

void CloseBasket(const string reason_tag,const double bid,const double ask)
  {
   const int levels=g_portfolio.OpenPositions();
   const int adds=g_dca_adds;
   const double volume=g_portfolio.Exposure();
   const double requested=(g_side==SIM_SIDE_BUY ? bid : ask);
   const double fill=g_cost.FillPrice(g_side==SIM_SIDE_BUY ? SIM_SIDE_SELL : SIM_SIDE_BUY,
                                      requested,0.0);
   const double commission=g_cost.Commission(volume);
   double realized_delta=0.0;
   string error="";
   if(!g_portfolio.CloseAll(fill,commission,error,realized_delta))
     {
      PrintFormat("LAB|ERROR|dca|close_failed|%s",error);
      return;
     }

   g_closed_positions+=levels;
   g_baskets_closed++;
   g_dca_adds=0;
   g_last_exit_bar=g_last_bar;
   LogEvent("EXIT",g_side,fill,volume,0.0,0.0,0.0,0.0,
            StringFormat("%s|levels=%d|adds=%d|pnl=%.4f|commission=%.4f|realized=%.4f",
                         reason_tag,levels,adds,realized_delta,commission,
                         g_portfolio.RealizedPnl()));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|dca|close|reason=%s|levels=%d|fill=%.8f|pnl=%.4f",
                  reason_tag,levels,fill,realized_delta);
  }

void UpdateExits(const double bid,const double ask)
  {
   if(g_portfolio.OpenPositions()<=0)
      return;

   const double average=g_portfolio.AverageEntry();
   //--- The stop is checked first so a same-bar stop and target cannot
   //--- both be claimed in the optimistic order.
   if(SimGridStopHit(g_side,average,InpBasketStopPoints*g_point,bid,ask))
     {
      CloseBasket("BASKET_STOP",bid,ask);
      return;
     }
   if(SimGridTargetHit(g_side,average,InpBasketTargetPoints*g_point,bid,ask))
      CloseBasket("BASKET_TARGET",bid,ask);
  }

void TryStart(const datetime bar_time)
  {
   if(g_portfolio.OpenPositions()>0)
      return;
   if(bar_time==g_last_exit_bar)
      return;

   const SimRiskDecision decision=EvaluateRisk(InpBaseVirtualVolume,0,bar_time);
   if(!decision.allowed)
     {
      LogRiskDecision(decision,InpBaseVirtualVolume,0);
      return;
     }

   if(!OpenPosition(InpBaseVirtualVolume,bar_time,"DCA_ENTRY|adds=0"))
      return;
   g_dca_adds=0;
   g_entries++;
   g_risk.RecordEntry(bar_time);
  }

void TryAdd(const datetime bar_time)
  {
   if(g_portfolio.OpenPositions()<=0)
      return;
   //--- InpMaxDcaAdds = 0 disables additions at the EA level; the guard
   //--- intentionally disables its own DCA check for zero as well.
   if(InpMaxDcaAdds<=0)
      return;
   //--- At most one fill per bar, so a tick burst cannot average in a loop.
   if(g_last_fill_bar==bar_time)
      return;

   const double distance=InpDcaDistancePoints*g_point;
   double trigger_price=0.0;
   int bars_since=0;
   bool triggered=false;

   if(InpTriggerMode==SIM_DCA_PRICE_DISTANCE)
     {
      const double last_entry=(g_side==SIM_SIDE_BUY ? g_portfolio.MinEntry()
                                                    : g_portfolio.MaxEntry());
      const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      triggered=SimDcaPriceTriggered(g_side,last_entry,distance,bid,ask);
      trigger_price=SimGridNextLevelPrice(g_side,last_entry,distance);
     }
   else
     {
      triggered=SimDcaBarTriggered(g_last_fill_bar,bar_time,
                                   InpBarsBetweenAdds,PeriodSeconds(_Period));
      bars_since=SimDcaBarsSince(g_last_fill_bar,bar_time,
                                 PeriodSeconds(_Period));
      trigger_price=(g_side==SIM_SIDE_BUY ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol,SYMBOL_BID));
     }
   if(!triggered)
      return;

   const SimDcaPlan plan=SimDcaPlanAdd(g_dca_adds,InpMaxDcaAdds,
                                       InpBaseVirtualVolume,
                                       InpAddVolumeMultiplier,
                                       InpMaxAddVolume,
                                       g_portfolio.Exposure(),
                                       InpMaxVirtualExposure);
   if(!plan.allowed)
     {
      const int blocked_add=(plan.add_index>0 ? plan.add_index : g_dca_adds+1);
      LogBlocked(plan.reason,blocked_add,bar_time);
      return;
     }

   const SimRiskDecision decision=EvaluateRisk(plan.volume,g_dca_adds,bar_time);
   if(!decision.allowed)
     {
      LogRiskDecision(decision,plan.volume,plan.add_index);
      return;
     }

   const string reason=StringFormat("DCA_ADD|add=%d|mode=%s|trigger=%.8f|"+
                                    "bars_since=%d|distance=%.8f",
                                    plan.add_index,EnumToString(InpTriggerMode),
                                    trigger_price,bars_since,distance);
   if(!OpenPosition(plan.volume,bar_time,reason))
      return;
   g_dca_adds=plan.add_index;
   g_total_adds++;
  }

//+------------------------------------------------------------------+
//| Summary                                                          |
//+------------------------------------------------------------------+
void WriteSummary(void)
  {
   if(!g_logger.IsOpen())
      return;
   LogEvent("SUMMARY",g_side,g_mid,g_portfolio.Exposure(),
            g_portfolio.AverageEntry(),0.0,0.0,g_portfolio.Exposure(),
            StringFormat("entries=%d|adds=%d|basket_adds=%d|closed=%d|baskets=%d|open=%d|"+
                         "realized=%.2f|max_dd=%.4f|blocks=%d|halted=%s",
                         g_entries,g_total_adds,g_dca_adds,g_closed_positions,
                         g_baskets_closed,g_portfolio.OpenPositions(),
                         g_portfolio.RealizedPnl(),
                         g_portfolio.MaxDrawdownPct(),g_risk.BlockedCount(),
                         SimRiskStateName(g_risk.State())));
  }

//+------------------------------------------------------------------+
//| MT5 events                                                       |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   string error="";
   if(!ValidateInputs(error))
     {
      PrintFormat("LAB|ERROR|dca|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(!SimValidatePoint(g_point,error))
     {
      PrintFormat("LAB|ERROR|dca|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SimCostAssumptions assumptions;
   assumptions.point=g_point;
   assumptions.commission_per_volume=InpCommissionPerVolume;
   assumptions.slippage_points=InpSlippagePoints;
   assumptions.swap_per_volume_day=0.0;
   if(!g_cost.Init(assumptions,error))
     {
      PrintFormat("LAB|ERROR|dca|cost_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SimRiskLimits limits=SimRiskLimitsDefault();
   limits.max_spread_points=InpMaxSpreadPoints;
   limits.max_virtual_positions=InpMaxDcaAdds+1;
   limits.max_grid_levels=0;
   limits.max_dca_adds=InpMaxDcaAdds;
   limits.max_virtual_exposure=InpMaxVirtualExposure;
   limits.max_daily_loss_pct=InpMaxDailyLossPct;
   limits.max_drawdown_pct=InpMaxDrawdownPct;
   limits.cooldown_bars=0;
   limits.require_valid_price=true;
   limits.kill_switch=false;
   limits.halt_on_breach=InpHaltOnBreach;

   const int timeframe_seconds=PeriodSeconds(_Period);
   if(!g_risk.Init(limits,timeframe_seconds,error))
     {
      PrintFormat("LAB|ERROR|dca|risk_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(!g_portfolio.Init(InpInitialBalance,error))
     {
      PrintFormat("LAB|ERROR|dca|portfolio_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_side=(InpDcaSide==DCA_LONG ? SIM_SIDE_BUY : SIM_SIDE_SELL);
   g_timeframe_text=EnumToString(_Period);
   g_config_hash=BuildConfigHash();
   g_day_start_equity=InpInitialBalance;
   g_mid=0.0;

   if(InpEnableLog)
     {
      if(!g_logger.Open(InpLogFile,error))
        {
         PrintFormat("LAB|ERROR|dca|log_open_failed|%s",error);
         return(INIT_FAILED);
        }
     }

   LogEvent("INIT",g_side,0.0,InpBaseVirtualVolume,0.0,0.0,0.0,0.0,
            StringFormat("SIMULATION_ONLY|config_hash=%s",g_config_hash));
   PrintFormat("LAB|INFO|dca|initialized|hash=%s|log=%s|tester=%d",
               g_config_hash,(InpEnableLog ? InpLogFile : "disabled"),
               (int)MQLInfoInteger(MQL_TESTER));
   PrintFormat("LAB|INFO|dca|simulation_only|no_orders_are_sent");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   WriteSummary();
   g_logger.Close();
   PrintFormat("LAB|INFO|dca|deinit|reason=%d|entries=%d|realized=%.2f",
               reason,g_entries,g_portfolio.RealizedPnl());
  }

void OnTick(void)
  {
   const int warmup=(InpTriggerMode==SIM_DCA_BAR_INTERVAL
                     ? InpBarsBetweenAdds+5 : 5);
   if(Bars(_Symbol,_Period)<warmup)
      return;

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0 || ask<=0.0)
      return;
   g_mid=(bid+ask)*0.5;

   UpdateDayStart(g_portfolio.Equity(g_mid));

   const datetime bar_time=iTime(_Symbol,_Period,0);
   const bool new_bar=(bar_time!=g_last_bar);
   if(new_bar)
      g_last_bar=bar_time;

   if(g_portfolio.OpenPositions()>0)
     {
      UpdateExits(bid,ask);
      if(g_portfolio.OpenPositions()>0)
         TryAdd(bar_time);
     }

   if(g_portfolio.OpenPositions()==0 && new_bar)
      TryStart(bar_time);
  }
