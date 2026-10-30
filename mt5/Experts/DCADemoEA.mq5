//+------------------------------------------------------------------+
//|                                                   DCADemoEA.mq5  |
//|   Demo-account execution for the DCA strategy (ADR 0004)         |
//|                                                                  |
//| Sends real orders, but only on a DEMO account or in the Strategy  |
//| Tester. Every order goes through mt5/Include/Exec/ExecBroker.mqh  |
//| (the single order-send point) after ExecGuard checks. Additions   |
//| are bounded in count and volume, and the basket carries a         |
//| mandatory SL/TP. No credentials, no login, no WebRequest/sockets. |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Demo-only DCA execution. Demo account or Strategy Tester only."

#include "../Include/Exec/ExecDemoCommon.mqh"
#include "../Include/Sim/SimDca.mqh"
#include "../Include/Sim/SimGrid.mqh"
#include "../Include/Sim/SimRiskGuard.mqh"
#include "../Include/Sim/SimLogger.mqh"

enum ENUM_DCA_DEMO_SIDE
  {
   DCA_DEMO_LONG  = 1,
   DCA_DEMO_SHORT = -1
  };

input group "Demo execution"
input bool   InpEnableExecution   = true;                    // false = dry-run, no orders (ADR 0006: true by default)
input string InpAllowedSymbols    = "XAUUSD";                 // prefix allow-list, comma separated
input long   InpMagicNumber       = 25005001;
input int    InpMaxSlippagePoints = 30;                       // deviation for market orders
input string InpKillSwitchFile    = "DCA_DEMO_STOP.txt";
input bool   InpCloseOnKillSwitch = true;

input group "Journal"
input bool   InpEnableLog         = true;                     // write CSV to MQL5/Files
input string InpLogFile           = "dca_demo.csv";
input bool   InpDebug             = false;

input group "DCA"
input ENUM_DCA_DEMO_SIDE InpDcaSide = DCA_DEMO_LONG;
input double InpBaseVolume        = 0.01;                     // initial entry, real lots
input ENUM_SIM_DCA_TRIGGER InpTriggerMode = SIM_DCA_PRICE_DISTANCE;
input double InpDcaDistancePoints = 300.0;                    // used when trigger = price
input int    InpBarsBetweenAdds   = 5;                        // used when trigger = bars
input int    InpMaxDcaAdds        = 3;                        // 0 = no additions at all
input double InpAddVolumeMultiplier = 1.50;                   // add volume = base * mult^n
input double InpMaxAddVolume      = 0.10;                     // per-add hard cap

input group "Exit"
input double InpBasketTargetPoints = 600.0;                   // average-entry target
input double InpBasketStopPoints  = 900.0;                    // average-entry stop (mandatory)

input group "RiskGuard"
input double InpMaxSpreadPoints   = 50.0;
input double InpMaxExposure       = 0.50;                     // total lots cap
input double InpMaxBasketLossPct  = 2.0;                      // loss at basket stop vs equity, 0 = off
input double InpMaxDailyLossPct   = 2.0;                      // 0 = off
input double InpMaxDrawdownPct    = 5.0;                      // 0 = off
input int    InpMaxConsecutiveLosses = 3;                     // 0 = off
input bool   InpHaltOnBreach      = true;

CSimRiskGuard g_risk;
CSimLogger    g_logger;

double   g_point=0.0;
double   g_mid=0.0;
string   g_config_hash="";
string   g_timeframe_text="";
ENUM_SIM_SIDE g_side=SIM_SIDE_BUY;

ExecDemoBasket g_basket;
datetime g_last_bar=0;
datetime g_last_add_bar=0;
datetime g_last_exit_bar=0;
datetime g_basket_open_time=0;

double   g_equity=0.0;
double   g_peak_equity=0.0;
double   g_day_start_equity=0.0;
long     g_day_key=0;

bool     g_halted=false;
string   g_halt_reason="";
int      g_entries=0;
int      g_adds=0;
int      g_total_adds=0;
int      g_closed_legs=0;
int      g_baskets_closed=0;
int      g_blocks=0;
int      g_consecutive_losses=0;
double   g_peak_exposure=0.0;

//+------------------------------------------------------------------+
//| Validation                                                       |
//+------------------------------------------------------------------+
bool ValidateInputs(string &error)
  {
   error="";
   if(InpMagicNumber<=0)
     {
      error="magic_must_be_positive";
      return(false);
     }
   if(InpMaxSlippagePoints<0 || InpMaxSlippagePoints>1000)
     {
      error="slippage_points_invalid";
      return(false);
     }
   if(StringLen(ExecTrim(InpAllowedSymbols))==0)
     {
      error="allowed_symbols_empty";
      return(false);
     }
   if(StringLen(ExecTrim(InpKillSwitchFile))==0)
     {
      error="kill_switch_file_empty";
      return(false);
     }
   if(!SimIsFinite(InpBaseVolume) || InpBaseVolume<=0.0)
     {
      error="base_volume_must_be_positive";
      return(false);
     }
   if(InpMaxDcaAdds<0 || InpMaxDcaAdds>50)
     {
      error="max_dca_adds_must_be_between_0_and_50";
      return(false);
     }
   if(!SimIsFinite(InpAddVolumeMultiplier) || InpAddVolumeMultiplier<1.0)
     {
      error="add_volume_multiplier_must_be_at_least_one";
      return(false);
     }
   if(!SimIsFinite(InpMaxAddVolume) || InpMaxAddVolume<InpBaseVolume)
     {
      error="max_add_volume_must_cover_base_volume";
      return(false);
     }
   if(!SimIsFinite(InpMaxExposure) || InpMaxExposure<InpMaxAddVolume)
     {
      error="max_exposure_must_cover_max_add_volume";
      return(false);
     }
   if(InpTriggerMode==SIM_DCA_PRICE_DISTANCE &&
      (!SimIsFinite(InpDcaDistancePoints) || InpDcaDistancePoints<=0.0))
     {
      error="dca_distance_points_must_be_positive";
      return(false);
     }
   if(InpTriggerMode==SIM_DCA_BAR_INTERVAL &&
      (InpBarsBetweenAdds<1 || InpBarsBetweenAdds>1000))
     {
      error="bars_between_adds_must_be_between_1_and_1000";
      return(false);
     }
   if(!SimIsFinite(InpBasketStopPoints) || InpBasketStopPoints<=0.0)
     {
      error="basket_stop_points_must_be_positive";
      return(false);
     }
   //--- Mandatory take profit: a basket without a target is not allowed.
   if(!SimIsFinite(InpBasketTargetPoints) || InpBasketTargetPoints<=0.0)
     {
      error="basket_target_points_must_be_positive";
      return(false);
     }
   if(!SimValidatePercent(InpMaxBasketLossPct,error))
     {
      error="max_basket_loss_pct_must_be_between_0_and_100";
      return(false);
     }
   if(InpMaxConsecutiveLosses<0)
     {
      error="max_consecutive_losses_must_be_non_negative";
      return(false);
     }
   if(InpEnableLog && StringLen(InpLogFile)==0)
     {
      error="log_file_must_not_be_empty";
      return(false);
     }
   return(true);
  }

string BuildConfigHash(void)
  {
   string text=SimFormatFingerprintPartText("ea","DCADemoEA")+
               SimFormatFingerprintPartInt("ea.execution_enabled",
                                           (InpEnableExecution ? 1 : 0))+
               SimFormatFingerprintPartInt("ea.magic",(int)InpMagicNumber)+
               SimFormatFingerprintPartInt("ea.deviation",InpMaxSlippagePoints)+
               SimFormatFingerprintPartInt("dca.side",(int)InpDcaSide)+
               SimFormatFingerprintPart("dca.base_volume",InpBaseVolume,4)+
               SimFormatFingerprintPartInt("dca.trigger_mode",(int)InpTriggerMode)+
               SimFormatFingerprintPart("dca.distance_points",InpDcaDistancePoints,1)+
               SimFormatFingerprintPartInt("dca.bars_between_adds",InpBarsBetweenAdds)+
               SimFormatFingerprintPartInt("dca.max_adds",InpMaxDcaAdds)+
               SimFormatFingerprintPart("dca.add_volume_multiplier",
                                        InpAddVolumeMultiplier,4)+
               SimFormatFingerprintPart("dca.max_add_volume",InpMaxAddVolume,4)+
               SimFormatFingerprintPart("exit.basket_target_points",
                                        InpBasketTargetPoints,1)+
               SimFormatFingerprintPart("exit.basket_stop_points",
                                        InpBasketStopPoints,1)+
               SimFormatFingerprintPart("risk.max_spread_points",
                                        InpMaxSpreadPoints,4)+
               SimFormatFingerprintPart("risk.max_exposure",InpMaxExposure,4)+
               SimFormatFingerprintPart("risk.max_basket_loss_pct",
                                        InpMaxBasketLossPct,4)+
               SimFormatFingerprintPart("risk.max_daily_loss_pct",
                                        InpMaxDailyLossPct,4)+
               SimFormatFingerprintPart("risk.max_drawdown_pct",
                                        InpMaxDrawdownPct,4)+
               SimFormatFingerprintPartInt("risk.max_consecutive_losses",
                                           InpMaxConsecutiveLosses);
   return(SimHashString(text));
  }

//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
void LogEvent(const string event_name,const double price,const double volume,
              const double entry,const double sl,const double tp,
              const string reason)
  {
   if(!g_logger.IsOpen())
      return;

   SimLogRecord record;
   SimClearLogRecord(record);
   record.logged_at=TimeCurrent();
   record.bar_time=g_last_bar;
   record.ea="DCADemoEA";
   record.version="1.00";
   record.config_hash=g_config_hash;
   record.symbol=_Symbol;
   record.timeframe=g_timeframe_text;
   record.event=event_name;
   record.side=g_side;
   record.price=price;
   record.volume=volume;
   record.entry=entry;
   record.sl=sl;
   record.tp=tp;
   record.exposure=g_basket.volume;
   record.equity=g_equity;
   record.drawdown_pct=DrawdownPct();
   record.reason=reason;

   string error="";
   if(!g_logger.Write(record,error))
      PrintFormat("LAB|ERROR|dca_demo|log_write_failed|%s",error);
  }

//+------------------------------------------------------------------+
//| Account state                                                    |
//+------------------------------------------------------------------+
double DrawdownPct(void)
  {
   if(!(g_peak_equity>0.0) || !(g_equity>0.0) || g_equity>=g_peak_equity)
      return(0.0);
   return((g_peak_equity-g_equity)/g_peak_equity*100.0);
  }

double DailyLossPct(void)
  {
   if(!(g_day_start_equity>0.0) || g_equity>=g_day_start_equity)
      return(0.0);
   return((g_day_start_equity-g_equity)/g_day_start_equity*100.0);
  }

void UpdateAccountState(void)
  {
   g_equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_equity>g_peak_equity)
      g_peak_equity=g_equity;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   const long key=(long)dt.year*10000+(long)dt.mon*100+(long)dt.day;
   if(key!=g_day_key)
     {
      g_day_key=key;
      g_day_start_equity=g_equity;
     }
  }

//+------------------------------------------------------------------+
//| Risk gating                                                      |
//+------------------------------------------------------------------+
void Halt(const string reason)
  {
   if(g_halted)
      return;
   g_halted=true;
   g_halt_reason=reason;
   PrintFormat("LAB|WARN|dca_demo|halted|reason=%s",reason);
  }

SimRiskDecision EvaluateRisk(const double volume_to_add,const datetime bar_time)
  {
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   SimRiskContext ctx;
   ctx.spread_points=(bid>0.0 && ask>0.0 ? (ask-bid)/g_point : 0.0);
   ctx.price_valid=(bid>0.0 && ask>0.0);
   ctx.open_positions=g_basket.count;
   ctx.grid_levels=0;
   ctx.dca_adds=g_adds;
   ctx.exposure=g_basket.volume;
   ctx.volume_to_add=volume_to_add;
   ctx.equity=g_equity;
   ctx.day_start_equity=g_day_start_equity;
   ctx.peak_equity=g_peak_equity;
   ctx.bar_time=bar_time;
   return(g_risk.Evaluate(ctx));
  }

bool BasketLossBudgetOk(const double prospective_volume,const string stage)
  {
   if(!(InpMaxBasketLossPct>0.0))
      return(true);
   const double budget=g_equity*InpMaxBasketLossPct/100.0;
   const double loss=ExecDemoBasketLossMoney(prospective_volume,
                                             InpBasketStopPoints);
   if(!ExecRiskBudgetOk(loss,budget))
     {
      LogEvent("BLOCKED",0.0,prospective_volume,g_basket.average_entry,0.0,0.0,
               StringFormat("basket_loss_budget|stage=%s|loss=%.2f|budget=%.2f",
                            stage,loss,budget));
      g_blocks++;
      return(false);
     }
   return(true);
  }

bool ConsecutiveLossAllows(void)
  {
   if(InpMaxConsecutiveLosses<=0)
      return(true);
   if(g_consecutive_losses<InpMaxConsecutiveLosses)
      return(true);
   LogEvent("BLOCKED",0.0,0.0,0.0,0.0,0.0,
            StringFormat("consecutive_losses|count=%d|limit=%d",
                         g_consecutive_losses,InpMaxConsecutiveLosses));
   g_blocks++;
   return(false);
  }

//+------------------------------------------------------------------+
//| Basket stops                                                     |
//+------------------------------------------------------------------+
bool SyncBasketStops(void)
  {
   const bool is_buy=(g_side==SIM_SIDE_BUY);
   const double sl=ExecDemoStopPrice(is_buy,g_basket.average_entry,
                                     InpBasketStopPoints);
   const double tp=ExecDemoTargetPrice(is_buy,g_basket.average_entry,
                                      InpBasketTargetPoints);
   const double reference=(is_buy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol,SYMBOL_BID));
   if(!ExecDemoBasketStopsValid(is_buy,reference,sl,tp))
     {
      PrintFormat("LAB|ERROR|dca_demo|stops_invalid|avg=%.8f|sl=%.8f|tp=%.8f",
                  g_basket.average_entry,sl,tp);
      return(false);
     }

   int updated=0;
   int failed=0;
   if(!ExecDemoBasketSetStops(InpMagicNumber,sl,tp,InpMaxSlippagePoints,
                              updated,failed))
     {
      PrintFormat("LAB|ERROR|dca_demo|stops_update_failed|updated=%d|failed=%d",
                  updated,failed);
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Order flow                                                       |
//+------------------------------------------------------------------+
double NormalizeVolume(const double volume)
  {
   return(ExecNormalizeVolume(volume,
                              SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
                              SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),
                              SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)));
  }

bool OpenPosition(const double raw_volume,const string reason)
  {
   const bool is_buy=(g_side==SIM_SIDE_BUY);

   const double volume=NormalizeVolume(raw_volume);
   if(!(volume>0.0))
     {
      LogEvent("BLOCKED",0.0,raw_volume,g_basket.average_entry,0.0,0.0,
               "volume_below_broker_minimum");
      g_blocks++;
      return(false);
     }

   const double prospective_volume=g_basket.volume+volume;
   const double reference=(is_buy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol,SYMBOL_BID));
   const double prospective_average=(g_basket.count>0
      ? (g_basket.average_entry*g_basket.volume+reference*volume)/prospective_volume
      : reference);
   const double sl=ExecDemoStopPrice(is_buy,prospective_average,
                                     InpBasketStopPoints);
   const double tp=ExecDemoTargetPrice(is_buy,prospective_average,
                                      InpBasketTargetPoints);
   if(!ExecDemoBasketStopsValid(is_buy,reference,sl,tp))
     {
      LogEvent("BLOCKED",reference,volume,prospective_average,sl,tp,
               "stops_invalid_against_broker_level");
      g_blocks++;
      return(false);
     }

   if(!InpEnableExecution)
     {
      LogEvent("DRY_RUN",reference,volume,prospective_average,sl,tp,
               StringFormat("would_open|%s",reason));
      return(false);
     }

   ExecFillResult fill;
   if(!ExecOpenMarket(is_buy,volume,sl,tp,InpMaxSlippagePoints,InpMagicNumber,
                      "DCA_DEMO",fill))
     {
      LogEvent("ERROR",reference,volume,prospective_average,sl,tp,
               StringFormat("order_failed|%s",fill.message));
      return(false);
     }

   LogEvent("ENTRY",fill.price,fill.volume,g_basket.average_entry,sl,tp,
            StringFormat("%s|retcode=%s",reason,fill.message));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|dca_demo|entry|price=%.8f|volume=%.4f|sl=%.8f|tp=%.8f",
                  fill.price,fill.volume,sl,tp);
   return(true);
  }

void CloseBasket(const string reason_tag)
  {
   const double volume=g_basket.volume;
   const double average=g_basket.average_entry;
   const int legs=g_basket.count;
   const datetime opened=g_basket_open_time;

   if(!InpEnableExecution)
     {
      LogEvent("DRY_RUN",0.0,volume,average,0.0,0.0,
               StringFormat("%s|would_close_basket|legs=%d",reason_tag,legs));
      return;
     }

   int closed=0;
   int failed=0;
   ExecDemoBasketClose(InpMagicNumber,InpMaxSlippagePoints,"DCA_DEMO_CLOSE",
                       closed,failed);

   double pnl=0.0;
   int deals=0;
   if(opened>0)
      ExecDemoHistoryPnl(InpMagicNumber,opened,pnl,deals);

   g_closed_legs+=closed;
   if(closed>0)
      g_baskets_closed++;
   g_last_exit_bar=g_last_bar;
   g_basket_open_time=0;
   g_adds=0;
   g_last_add_bar=0;

   if(pnl<0.0)
      g_consecutive_losses++;
   else if(pnl>0.0)
      g_consecutive_losses=0;

   LogEvent("EXIT",0.0,volume,average,0.0,0.0,
            StringFormat("%s|legs=%d|closed=%d|failed=%d|pnl=%.2f|"
                         "consecutive_losses=%d",
                         reason_tag,legs,closed,failed,pnl,g_consecutive_losses));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|dca_demo|close|reason=%s|closed=%d|pnl=%.2f",
                  reason_tag,closed,pnl);
  }

//+------------------------------------------------------------------+
//| Decisions                                                        |
//+------------------------------------------------------------------+
void TryStart(const datetime bar_time)
  {
   if(bar_time==g_last_exit_bar)
      return;
   if(!ConsecutiveLossAllows())
      return;

   const double volume=NormalizeVolume(InpBaseVolume);
   if(!(volume>0.0))
     {
      LogEvent("BLOCKED",0.0,InpBaseVolume,0.0,0.0,0.0,
               "volume_below_broker_minimum");
      g_blocks++;
      return;
     }

   const SimRiskDecision decision=EvaluateRisk(volume,bar_time);
   if(!decision.allowed)
     {
      LogEvent("BLOCKED",0.0,volume,0.0,0.0,0.0,
               StringFormat("risk|%s|state=%s",decision.reason,
                            SimRiskStateName(decision.state)));
      g_blocks++;
      if(decision.state==SIM_RISK_HALTED)
         Halt(decision.reason);
      return;
     }

   if(!BasketLossBudgetOk(volume,"start"))
      return;

   if(!OpenPosition(volume,"DCA_ENTRY|adds=0"))
      return;
   g_entries++;
   g_adds=0;
   g_last_add_bar=bar_time;
   g_risk.RecordEntry(bar_time);
   if(g_basket_open_time==0)
      g_basket_open_time=TimeCurrent();
  }

void TryAdd(const datetime bar_time)
  {
   if(InpMaxDcaAdds<=0)
     return;
   //--- At most one fill per bar so a tick burst cannot average in a loop.
   if(g_last_add_bar==bar_time)
      return;

   const double distance=InpDcaDistancePoints*g_point;
   double trigger_price=0.0;
   int bars_since=0;
   bool triggered=false;

   if(InpTriggerMode==SIM_DCA_PRICE_DISTANCE)
     {
      const double last_entry=(g_side==SIM_SIDE_BUY ? g_basket.min_entry
                                                    : g_basket.max_entry);
      const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      triggered=SimDcaPriceTriggered(g_side,last_entry,distance,bid,ask);
      trigger_price=SimGridNextLevelPrice(g_side,last_entry,distance);
     }
   else
     {
      triggered=SimDcaBarTriggered(g_last_add_bar,bar_time,InpBarsBetweenAdds,
                                   PeriodSeconds(_Period));
      bars_since=SimDcaBarsSince(g_last_add_bar,bar_time,
                                 PeriodSeconds(_Period));
      trigger_price=(g_side==SIM_SIDE_BUY ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol,SYMBOL_BID));
     }
   if(!triggered)
      return;

   const SimDcaPlan plan=SimDcaPlanAdd(g_adds,InpMaxDcaAdds,InpBaseVolume,
                                       InpAddVolumeMultiplier,InpMaxAddVolume,
                                       g_basket.volume,InpMaxExposure);
   if(!plan.allowed)
     {
      const int blocked_add=(plan.add_index>0 ? plan.add_index : g_adds+1);
      LogEvent("BLOCKED",0.0,InpBaseVolume,g_basket.average_entry,0.0,0.0,
               StringFormat("plan|%s|add=%d",plan.reason,blocked_add));
      g_blocks++;
      return;
     }

   const double volume=NormalizeVolume(plan.volume);
   if(!(volume>0.0))
     {
      LogEvent("BLOCKED",0.0,plan.volume,g_basket.average_entry,0.0,0.0,
               "volume_below_broker_minimum");
      g_blocks++;
      return;
     }

   const SimRiskDecision decision=EvaluateRisk(volume,bar_time);
   if(!decision.allowed)
     {
      LogEvent("BLOCKED",0.0,volume,g_basket.average_entry,0.0,0.0,
               StringFormat("risk|%s|state=%s",decision.reason,
                            SimRiskStateName(decision.state)));
      g_blocks++;
      if(decision.state==SIM_RISK_HALTED)
         Halt(decision.reason);
      return;
     }

   if(!BasketLossBudgetOk(g_basket.volume+volume,
                          StringFormat("add=%d",plan.add_index)))
      return;

   const string reason=StringFormat("DCA_ADD|add=%d|mode=%s|trigger=%.8f|"
                                    "bars_since=%d|distance=%.8f",
                                    plan.add_index,EnumToString(InpTriggerMode),
                                    trigger_price,bars_since,distance);
   if(!OpenPosition(volume,reason))
      return;
   g_adds=plan.add_index;
   g_total_adds++;
   g_last_add_bar=bar_time;
  }

void UpdateExits(const double bid,const double ask)
  {
   //--- Stop is checked first: a same-bar stop and target cannot both be
   //--- claimed in the optimistic order.
   if(SimGridStopHit(g_side,g_basket.average_entry,InpBasketStopPoints*g_point,
                     bid,ask))
     {
      CloseBasket("BASKET_STOP");
      return;
     }
   if(SimGridTargetHit(g_side,g_basket.average_entry,
                       InpBasketTargetPoints*g_point,bid,ask))
      CloseBasket("BASKET_TARGET");
  }

//+------------------------------------------------------------------+
//| Summary                                                          |
//+------------------------------------------------------------------+
void WriteSummary(void)
  {
   if(!g_logger.IsOpen())
      return;
   LogEvent("SUMMARY",g_mid,g_basket.volume,g_basket.average_entry,0.0,0.0,
            StringFormat("entries=%d|adds=%d|basket_adds=%d|closed_legs=%d|"
                         "baskets=%d|peak_exposure=%.4f|blocks=%d|"
                         "consecutive_losses=%d|halted=%s|halt_reason=%s|"
                         "execution=%s",
                         g_entries,g_total_adds,g_adds,g_closed_legs,
                         g_baskets_closed,g_peak_exposure,g_blocks,
                         g_consecutive_losses,
                         (g_halted ? "HALTED" : "ACTIVE"),g_halt_reason,
                         (InpEnableExecution ? "DEMO_EXECUTION" : "DRY_RUN")));
  }

//+------------------------------------------------------------------+
//| MT5 events                                                       |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   string error="";
   if(!ValidateInputs(error))
     {
      PrintFormat("LAB|ERROR|dca_demo|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(!SimValidatePoint(g_point,error))
     {
      PrintFormat("LAB|ERROR|dca_demo|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   //--- Hard demo gate: real/contest accounts are rejected here.
   ExecAccountState state;
   state.trade_mode=AccountInfoInteger(ACCOUNT_TRADE_MODE);
   state.account_trade_allowed=(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)!=0);
   state.terminal_trade_allowed=(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0);
   state.tester=(MQLInfoInteger(MQL_TESTER)!=0);

   ENUM_EXEC_BLOCK block=EXEC_OK;
   if(!ExecContextAllowed(state,block))
     {
      PrintFormat("LAB|ERROR|dca_demo|context_denied|reason=%s",
                  ExecBlockName(block));
      return(INIT_FAILED);
     }

   if(InpEnableExecution && !ExecSymbolAllowed(_Symbol,InpAllowedSymbols))
     {
      PrintFormat("LAB|ERROR|dca_demo|symbol_denied|symbol=%s",_Symbol);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SimRiskLimits limits=SimRiskLimitsDefault();
   limits.max_spread_points=InpMaxSpreadPoints;
   limits.max_virtual_positions=InpMaxDcaAdds+1;
   limits.max_grid_levels=0;
   limits.max_dca_adds=InpMaxDcaAdds;
   limits.max_virtual_exposure=InpMaxExposure;
   limits.max_daily_loss_pct=InpMaxDailyLossPct;
   limits.max_drawdown_pct=InpMaxDrawdownPct;
   limits.cooldown_bars=0;
   limits.require_valid_price=true;
   limits.kill_switch=false;
   //--- ADR 0006 §4: guard-level blocks (spread, add caps, budget) must
   //--- not escalate to a permanent halt; the guard only Halt()s on real
   //--- equity breaches and the EA promotes them via InpHaltOnBreach.
   limits.halt_on_breach=false;

   if(!g_risk.Init(limits,PeriodSeconds(_Period),error))
     {
      PrintFormat("LAB|ERROR|dca_demo|risk_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_side=(InpDcaSide==DCA_DEMO_LONG ? SIM_SIDE_BUY : SIM_SIDE_SELL);
   g_timeframe_text=EnumToString(_Period);
   g_config_hash=BuildConfigHash();
   g_mid=0.0;
   ExecDemoBasketReset(g_basket);
   UpdateAccountState();
   g_day_start_equity=g_equity;

   if(InpEnableLog)
     {
      if(!g_logger.Open(InpLogFile,error))
        {
         PrintFormat("LAB|ERROR|dca_demo|log_open_failed|%s",error);
         return(INIT_FAILED);
        }
     }

   const string mode=(InpEnableExecution ? "DEMO_EXECUTION" : "DRY_RUN");
   LogEvent("INIT",0.0,InpBaseVolume,0.0,0.0,0.0,
            StringFormat("mode=%s|symbol=%s|allowed=%s|magic=%d|config_hash=%s|"
                         "equity=%.2f",mode,_Symbol,InpAllowedSymbols,
                         InpMagicNumber,g_config_hash,g_equity));
   PrintFormat("LAB|INFO|dca_demo|initialized|mode=%s|hash=%s|magic=%d|"
               "tester=%d|execution_enabled=%d",
               mode,g_config_hash,InpMagicNumber,
               (int)MQLInfoInteger(MQL_TESTER),(InpEnableExecution ? 1 : 0));
   if(!InpEnableExecution)
      PrintFormat("LAB|INFO|dca_demo|dry_run|no_orders_are_sent");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   WriteSummary();
   g_logger.Close();
   PrintFormat("LAB|INFO|dca_demo|deinit|reason=%d|entries=%d|adds=%d|baskets=%d|"
               "consecutive_losses=%d",
               reason,g_entries,g_total_adds,g_baskets_closed,
               g_consecutive_losses);
  }

void OnTick(void)
  {
   if(Bars(_Symbol,_Period)<InpBarsBetweenAdds+5)
      return;

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0 || ask<=0.0)
      return;
   g_mid=(bid+ask)*0.5;

   UpdateAccountState();

   const datetime bar_time=iTime(_Symbol,_Period,0);
   const bool new_bar=(bar_time!=g_last_bar);
   if(new_bar)
      g_last_bar=bar_time;

   //--- Kill switch: close the basket and stop entering until restart.
   if(ExecDemoKillSwitchPresent(InpKillSwitchFile))
     {
      ExecDemoBasketRead(InpMagicNumber,g_basket);
      if(g_basket.count>0 && InpCloseOnKillSwitch && InpEnableExecution)
        {
         LogEvent("KILL_SWITCH",0.0,g_basket.volume,g_basket.average_entry,
                  0.0,0.0,"kill_switch_active|closing_basket");
         CloseBasket("KILL_SWITCH");
        }
      else if(g_basket.count>0)
         LogEvent("BLOCKED",0.0,g_basket.volume,g_basket.average_entry,0.0,0.0,
                  "kill_switch_active|hold_only");
      Halt("kill_switch_active");
      return;
     }

   ExecDemoBasketRead(InpMagicNumber,g_basket);
   if(g_basket.volume>g_peak_exposure)
      g_peak_exposure=g_basket.volume;

   if(g_basket.count>0 && g_basket.side<0)
     {
      Halt("foreign_basket_mixed_sides");
      return;
     }
   if(g_basket.count>0 && g_basket_open_time==0)
      g_basket_open_time=g_basket.first_time;

   //--- Hard equity breach: stop trading and flatten the basket.
   if(!g_halted && InpMaxDailyLossPct>0.0 && DailyLossPct()>=InpMaxDailyLossPct)
      Halt("daily_loss_limit_reached");
   if(!g_halted && InpMaxDrawdownPct>0.0 && DrawdownPct()>=InpMaxDrawdownPct)
      Halt("max_drawdown_reached");

   if(g_halted)
     {
      if(g_basket.count>0 && InpEnableExecution)
        {
         LogEvent("HALT",0.0,g_basket.volume,g_basket.average_entry,0.0,0.0,
                  StringFormat("halt_reason=%s|closing_basket",g_halt_reason));
         CloseBasket("RISK_HALT");
        }
      return;
     }

   if(g_basket.count>0)
     {
      //--- Keep the broker-side stops aligned with the live average entry.
      if(InpEnableExecution)
         SyncBasketStops();

      UpdateExits(bid,ask);
      ExecDemoBasketRead(InpMagicNumber,g_basket);
      if(g_basket.count>0)
         TryAdd(bar_time);
     }

   if(g_basket.count==0 && new_bar)
      TryStart(bar_time);
  }
