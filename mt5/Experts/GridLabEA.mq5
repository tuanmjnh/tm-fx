//+------------------------------------------------------------------+
//|                                                     GridLabEA.mq5 |
//|         MT5 EA Lab - bounded virtual grid basket (simulation)     |
//|                                                                  |
//| Opens virtual positions in memory only. No order-sending call,    |
//| no trade class and no broker/account API. Every level is bounded  |
//| by level count, level volume and total virtual exposure caps.     |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Simulation-only grid basket with hard level and exposure caps."
#property description "No trading functions: virtual positions and CSV logs only."

#include "../Include/Sim/SimPortfolio.mqh"
#include "../Include/Sim/SimCostModel.mqh"
#include "../Include/Sim/SimRiskGuard.mqh"
#include "../Include/Sim/SimGrid.mqh"
#include "../Include/Sim/SimLogger.mqh"

enum ENUM_GRID_SIDE
  {
   GRID_LONG  = 1,
   GRID_SHORT = -1
  };

enum ENUM_GRID_EXIT_MODE
  {
   GRID_EXIT_LEVEL  = 0,
   GRID_EXIT_BASKET = 1
  };

input group "Simulation"
input double InpInitialBalance      = 10000.0;  // virtual starting balance
input bool   InpEnableLog           = true;     // write CSV to MQL5/Files
input string InpLogFile             = "sim_grid_log.csv";
input bool   InpDebug               = false;

input group "Grid"
input ENUM_GRID_SIDE InpGridSide    = GRID_LONG;
input ENUM_SIM_GRID_SPACING InpSpacingMode = SIM_GRID_FIXED_POINTS;
input double InpSpacingPoints       = 300.0;    // used when spacing = fixed
input int    InpAtrPeriod           = 14;       // used when spacing = ATR
input double InpAtrMultiplier       = 1.0;      // used when spacing = ATR
input int    InpMaxGridLevels       = 5;        // total levels incl. first
input double InpBaseVirtualVolume   = 0.10;
input double InpVolumeMultiplier    = 1.50;
input double InpMaxLevelVolume      = 1.00;     // per-level hard cap

input group "Exit"
input ENUM_GRID_EXIT_MODE InpExitMode = GRID_EXIT_BASKET;
input double InpLevelTargetPoints   = 300.0;    // per-level profit, LEVEL mode
input double InpBasketTargetPoints  = 600.0;    // average-entry target, BASKET mode
input double InpBasketStopPoints    = 900.0;    // average-entry stop, both modes

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

int      g_atr_handle=INVALID_HANDLE;
double   g_point=0.0;
string   g_config_hash="";
string   g_timeframe_text="";
datetime g_last_bar=0;
datetime g_last_exit_bar=0;
datetime g_last_block_bar=0;
double   g_mid=0.0;
double   g_day_start_equity=0.0;
long     g_day_key=0;
ENUM_SIM_SIDE g_side=SIM_SIDE_BUY;

int      g_levels_opened=0;
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
   if(!SimValidateMultiplier(InpVolumeMultiplier,error))
      return(false);
   if(!SimValidateLevels(InpMaxGridLevels,error))
      return(false);
   if(InpGridSide!=GRID_LONG && InpGridSide!=GRID_SHORT)
     {
      error="grid_side_invalid";
      return(false);
     }

   if(!SimIsFinite(InpMaxLevelVolume) || InpMaxLevelVolume<InpBaseVirtualVolume)
     {
      error="max_level_volume_must_cover_base_volume";
      return(false);
     }
   if(InpMaxLevelVolume>1000.0)
     {
      error="max_level_volume_must_not_exceed_1000";
      return(false);
     }

   if(InpSpacingMode!=SIM_GRID_FIXED_POINTS &&
      InpSpacingMode!=SIM_GRID_ATR_MULTIPLE)
     {
      error="grid_spacing_mode_invalid";
      return(false);
     }
   if(InpSpacingMode==SIM_GRID_FIXED_POINTS)
     {
      if(!SimIsFinite(InpSpacingPoints) || InpSpacingPoints<=0.0)
        {
         error="grid_spacing_must_be_positive";
         return(false);
        }
     }
   else
     {
      if(InpAtrPeriod<2)
        {
         error="grid_atr_period_must_be_at_least_two";
         return(false);
        }
      if(!SimIsFinite(InpAtrMultiplier) || InpAtrMultiplier<=0.0)
        {
         error="grid_atr_multiplier_must_be_positive";
         return(false);
        }
     }

   if(InpExitMode!=GRID_EXIT_LEVEL && InpExitMode!=GRID_EXIT_BASKET)
     {
      error="grid_exit_mode_invalid";
      return(false);
     }
   if(!SimIsFinite(InpBasketStopPoints) || InpBasketStopPoints<=0.0)
     {
      error="basket_stop_points_must_be_positive";
      return(false);
     }
   if(!SimIsFinite(InpBasketTargetPoints) || InpBasketTargetPoints<0.0)
     {
      error="basket_target_points_must_be_finite_non_negative";
      return(false);
     }
   if(!SimIsFinite(InpLevelTargetPoints) || InpLevelTargetPoints<0.0)
     {
      error="level_target_points_must_be_finite_non_negative";
      return(false);
     }
   if(InpExitMode==GRID_EXIT_BASKET && InpBasketTargetPoints<=0.0)
     {
      error="basket_target_must_be_positive_when_basket_exit";
      return(false);
     }
   if(InpExitMode==GRID_EXIT_LEVEL && InpLevelTargetPoints<=0.0)
     {
      error="level_target_must_be_positive_when_level_exit";
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
                     SimFormatFingerprintPartInt("grid.side",(int)InpGridSide)+
                     SimFormatFingerprintPartInt("grid.spacing_mode",(int)InpSpacingMode)+
                     SimFormatFingerprintPart("grid.spacing_points",
                                              InpSpacingPoints,1)+
                     SimFormatFingerprintPartInt("grid.atr_period",InpAtrPeriod)+
                     SimFormatFingerprintPart("grid.atr_mult",InpAtrMultiplier,4)+
                     SimFormatFingerprintPartInt("grid.max_levels",InpMaxGridLevels)+
                     SimFormatFingerprintPart("grid.base_volume",
                                              InpBaseVirtualVolume,4)+
                     SimFormatFingerprintPart("grid.volume_mult",
                                              InpVolumeMultiplier,4)+
                     SimFormatFingerprintPart("grid.max_level_volume",
                                              InpMaxLevelVolume,4)+
                     SimFormatFingerprintPartInt("grid.exit_mode",(int)InpExitMode)+
                     SimFormatFingerprintPart("grid.level_target",
                                              InpLevelTargetPoints,1)+
                     SimFormatFingerprintPart("grid.basket_target",
                                              InpBasketTargetPoints,1)+
                     SimFormatFingerprintPart("grid.basket_stop",
                                              InpBasketStopPoints,1)+
                     SimFormatFingerprintPartInt("grid.balance",
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
   record.ea="GridLabEA";
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
      PrintFormat("LAB|ERROR|grid|log_write_failed|%s",error);
  }

void LogBlocked(const string reason,const int level,const double spacing,
                const datetime bar_time)
  {
   if(bar_time==g_last_block_bar)
      return;
   g_last_block_bar=bar_time;
   LogEvent("RISK",g_side,g_mid,0.0,g_portfolio.AverageEntry(),0.0,0.0,
            g_portfolio.Exposure(),
            StringFormat("GRID_BLOCKED|reason=%s|level=%d|spacing=%.8f",
                         reason,level,spacing));
  }

void LogRiskDecision(const SimRiskDecision &decision,const double volume,
                     const int level)
  {
   LogEvent("RISK",g_side,g_mid,volume,g_portfolio.AverageEntry(),0.0,0.0,
            g_portfolio.Exposure(),
            StringFormat("GRID_BLOCKED|reason=%s|level=%d|state=%s",
                         decision.reason,level,
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
//| Spacing and risk                                                 |
//+------------------------------------------------------------------+
bool ReadSpacing(double &spacing)
  {
   if(InpSpacingMode==SIM_GRID_FIXED_POINTS)
      spacing=InpSpacingPoints*g_point;
   else
     {
      double atr_buf[];
      ArraySetAsSeries(atr_buf,true);
      if(CopyBuffer(g_atr_handle,0,0,2,atr_buf)<2)
         return(false);
      spacing=atr_buf[1]*InpAtrMultiplier;
     }
   return(SimIsFinite(spacing) && spacing>0.0);
  }

SimRiskDecision EvaluateRisk(const double volume,const datetime bar_time)
  {
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   SimRiskContext ctx;
   ctx.spread_points=(bid>0.0 && ask>0.0 ? (ask-bid)/g_point : 0.0);
   ctx.price_valid=(bid>0.0 && ask>0.0);
   ctx.open_positions=g_portfolio.OpenPositions();
   ctx.grid_levels=g_portfolio.OpenPositions();
   ctx.dca_adds=0;
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
bool OpenLevel(const double volume,const double trigger_price,
               const datetime bar_time,const double spacing)
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
      PrintFormat("LAB|ERROR|grid|open_failed|%s",error);
      return(false);
     }

   g_levels_opened++;
   const int level=g_portfolio.OpenPositions();
   LogEvent("ENTRY",g_side,fill,volume,g_portfolio.AverageEntry(),0.0,0.0,
            g_portfolio.Exposure(),
            StringFormat("GRID_ADD|level=%d|trigger=%.8f|fill=%.8f|spacing=%.8f",
                         level,trigger_price,fill,spacing));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|grid|add|level=%d|fill=%.8f|volume=%.4f|exposure=%.4f",
                  level,fill,volume,g_portfolio.Exposure());
   return(true);
  }

void CloseBasket(const string reason_tag,const double bid,const double ask)
  {
   const int levels=g_portfolio.OpenPositions();
   const double volume=g_portfolio.Exposure();
   const double requested=(g_side==SIM_SIDE_BUY ? bid : ask);
   const double fill=g_cost.FillPrice(g_side==SIM_SIDE_BUY ? SIM_SIDE_SELL : SIM_SIDE_BUY,
                                      requested,0.0);
   const double commission=g_cost.Commission(volume);
   double realized_delta=0.0;
   string error="";
   if(!g_portfolio.CloseAll(fill,commission,error,realized_delta))
     {
      PrintFormat("LAB|ERROR|grid|close_failed|%s",error);
      return;
     }

   g_closed_positions+=levels;
   g_baskets_closed++;
   g_last_exit_bar=g_last_bar;
   LogEvent("EXIT",g_side,fill,volume,0.0,0.0,0.0,0.0,
            StringFormat("%s|levels=%d|pnl=%.4f|commission=%.4f|realized=%.4f",
                         reason_tag,levels,realized_delta,commission,
                         g_portfolio.RealizedPnl()));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|grid|close|reason=%s|levels=%d|fill=%.8f|pnl=%.4f",
                  reason_tag,levels,fill,realized_delta);
  }

void TryLevelExit(const double bid,const double ask)
  {
   const double distance=InpLevelTargetPoints*g_point;
   if(distance<=0.0)
      return;
   const double price=(g_side==SIM_SIDE_BUY ? bid : ask);

   SimCostAssumptions assumptions;
   g_cost.Assumptions(assumptions);

   double realized_delta=0.0;
   int closed=0;
   string error="";
   if(!g_portfolio.CloseProfitableAtLeast(price,distance,
                                          assumptions.commission_per_volume,
                                          error,realized_delta,closed))
      return;

   g_closed_positions+=closed;
   if(g_portfolio.OpenPositions()==0)
     {
      g_baskets_closed++;
      g_last_exit_bar=g_last_bar;
     }
   LogEvent("EXIT",g_side,price,0.0,g_portfolio.AverageEntry(),0.0,0.0,
            g_portfolio.Exposure(),
            StringFormat("LEVEL_TARGET|closed=%d|levels=%d|pnl=%.4f|realized=%.4f",
                         closed,g_portfolio.OpenPositions(),realized_delta,
                         g_portfolio.RealizedPnl()));
  }

void UpdateExits(const double bid,const double ask)
  {
   if(g_portfolio.OpenPositions()<=0)
      return;

   const double average=g_portfolio.AverageEntry();
   if(SimGridStopHit(g_side,average,InpBasketStopPoints*g_point,bid,ask))
     {
      CloseBasket("BASKET_STOP",bid,ask);
      return;
     }

   if(InpExitMode==GRID_EXIT_BASKET &&
      SimGridTargetHit(g_side,average,InpBasketTargetPoints*g_point,bid,ask))
     {
      CloseBasket("BASKET_TARGET",bid,ask);
      return;
     }

   if(InpExitMode==GRID_EXIT_LEVEL)
      TryLevelExit(bid,ask);
  }

void TryStart(const datetime bar_time,const double spacing)
  {
   if(g_portfolio.OpenPositions()>0)
      return;
   if(bar_time==g_last_exit_bar)
      return;

   const SimGridPlan plan=SimGridPlanAdd(1,InpMaxGridLevels,InpBaseVirtualVolume,
                                         InpVolumeMultiplier,InpMaxLevelVolume,
                                         0.0,InpMaxVirtualExposure);
   if(!plan.allowed)
     {
      LogBlocked(plan.reason,1,spacing,bar_time);
      return;
     }

   const SimRiskDecision decision=EvaluateRisk(plan.volume,bar_time);
   if(!decision.allowed)
     {
      LogRiskDecision(decision,plan.volume,1);
      return;
     }

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double trigger=(g_side==SIM_SIDE_BUY ? ask : bid);
   if(!OpenLevel(plan.volume,trigger,bar_time,spacing))
      return;
   g_risk.RecordEntry(bar_time);
  }

void TryAdd(const datetime bar_time,const double spacing)
  {
   for(int i=0; i<InpMaxGridLevels; i++)
     {
      const int current=g_portfolio.OpenPositions();
      if(current<=0)
         return;

      const double last_entry=(g_side==SIM_SIDE_BUY ? g_portfolio.MinEntry()
                                                    : g_portfolio.MaxEntry());
      const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(!SimGridTriggered(g_side,last_entry,spacing,bid,ask))
         return;

      const int next=current+1;
      const SimGridPlan plan=SimGridPlanAdd(next,InpMaxGridLevels,
                                            InpBaseVirtualVolume,
                                            InpVolumeMultiplier,
                                            InpMaxLevelVolume,
                                            g_portfolio.Exposure(),
                                            InpMaxVirtualExposure);
      if(!plan.allowed)
        {
         LogBlocked(plan.reason,next,spacing,bar_time);
         return;
        }

      const SimRiskDecision decision=EvaluateRisk(plan.volume,bar_time);
      if(!decision.allowed)
        {
         LogRiskDecision(decision,plan.volume,next);
         return;
        }

      const double trigger=SimGridNextLevelPrice(g_side,last_entry,spacing);
      if(!OpenLevel(plan.volume,trigger,bar_time,spacing))
         return;
     }
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
            StringFormat("levels_opened=%d|closed=%d|baskets=%d|open=%d|"+
                         "realized=%.2f|max_dd=%.4f|blocks=%d|halted=%s",
                         g_levels_opened,g_closed_positions,g_baskets_closed,
                         g_portfolio.OpenPositions(),g_portfolio.RealizedPnl(),
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
      PrintFormat("LAB|ERROR|grid|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(!SimValidatePoint(g_point,error))
     {
      PrintFormat("LAB|ERROR|grid|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SimCostAssumptions assumptions;
   assumptions.point=g_point;
   assumptions.commission_per_volume=InpCommissionPerVolume;
   assumptions.slippage_points=InpSlippagePoints;
   assumptions.swap_per_volume_day=0.0;
   if(!g_cost.Init(assumptions,error))
     {
      PrintFormat("LAB|ERROR|grid|cost_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SimRiskLimits limits=SimRiskLimitsDefault();
   limits.max_spread_points=InpMaxSpreadPoints;
   limits.max_virtual_positions=InpMaxGridLevels;
   limits.max_grid_levels=InpMaxGridLevels;
   limits.max_dca_adds=0;
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
      PrintFormat("LAB|ERROR|grid|risk_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(!g_portfolio.Init(InpInitialBalance,error))
     {
      PrintFormat("LAB|ERROR|grid|portfolio_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(InpSpacingMode==SIM_GRID_ATR_MULTIPLE)
     {
      g_atr_handle=iATR(_Symbol,_Period,InpAtrPeriod);
      if(g_atr_handle==INVALID_HANDLE)
        {
         PrintFormat("LAB|ERROR|grid|indicator_init_failed|error=%d",GetLastError());
         return(INIT_FAILED);
        }
     }

   g_side=(InpGridSide==GRID_LONG ? SIM_SIDE_BUY : SIM_SIDE_SELL);
   g_timeframe_text=EnumToString(_Period);
   g_config_hash=BuildConfigHash();
   g_day_start_equity=InpInitialBalance;
   g_mid=0.0;

   if(InpEnableLog)
     {
      if(!g_logger.Open(InpLogFile,error))
        {
         PrintFormat("LAB|ERROR|grid|log_open_failed|%s",error);
         return(INIT_FAILED);
        }
     }

   LogEvent("INIT",g_side,0.0,InpBaseVirtualVolume,0.0,0.0,0.0,0.0,
            StringFormat("SIMULATION_ONLY|config_hash=%s",g_config_hash));
   PrintFormat("LAB|INFO|grid|initialized|hash=%s|log=%s|tester=%d",
               g_config_hash,(InpEnableLog ? InpLogFile : "disabled"),
               (int)MQLInfoInteger(MQL_TESTER));
   PrintFormat("LAB|INFO|grid|simulation_only|no_orders_are_sent");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   WriteSummary();
   g_logger.Close();
   if(g_atr_handle!=INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
   PrintFormat("LAB|INFO|grid|deinit|reason=%d|levels=%d|realized=%.2f",
               reason,g_levels_opened,g_portfolio.RealizedPnl());
  }

void OnTick(void)
  {
   const int warmup=(InpSpacingMode==SIM_GRID_ATR_MULTIPLE ? InpAtrPeriod+5 : 5);
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

   double spacing=0.0;
   const bool have_spacing=ReadSpacing(spacing);

   if(g_portfolio.OpenPositions()>0)
     {
      UpdateExits(bid,ask);
      if(g_portfolio.OpenPositions()>0 && have_spacing)
         TryAdd(bar_time,spacing);
     }

   if(g_portfolio.OpenPositions()==0 && new_bar && have_spacing)
      TryStart(bar_time,spacing);
  }
