//+------------------------------------------------------------------+
//|                                                  GridDemoEA.mq5  |
//|   Demo-account execution for the Grid strategy (ADR 0004)        |
//|                                                                  |
//| Sends real orders, but only on a DEMO account or in the Strategy  |
//| Tester. Every order goes through mt5/Include/Exec/ExecBroker.mqh  |
//| (the single order-send point) after ExecGuard checks. Bounded     |
//| levels, bounded volume and a basket SL/TP are mandatory.          |
//| No credentials, no login, no WebRequest, no sockets.              |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Demo-only grid execution. Demo account or Strategy Tester only."

#include "../Include/Exec/ExecDemoCommon.mqh"
#include "../Include/Sim/SimGrid.mqh"
#include "../Include/Sim/SimRiskGuard.mqh"
#include "../Include/Sim/SimLogger.mqh"

enum ENUM_GRID_DEMO_SIDE
  {
   GRID_DEMO_LONG  = 1,
   GRID_DEMO_SHORT = -1
  };

enum ENUM_GRID_DEMO_EXIT
  {
   GRID_DEMO_EXIT_LEVEL  = 0,
   GRID_DEMO_EXIT_BASKET = 1
  };

input group "Demo execution"
input bool   InpEnableExecution   = true;                    // false = dry-run, no orders (ADR 0006: true by default)
input string InpAllowedSymbols    = "XAUUSD";                 // prefix allow-list, comma separated
input long   InpMagicNumber       = 25004001;
input int    InpMaxSlippagePoints = 30;                       // deviation for market orders
input string InpKillSwitchFile    = "GRID_DEMO_STOP.txt";
input bool   InpCloseOnKillSwitch = true;

input group "Journal"
input bool   InpEnableLog         = true;                     // write CSV to MQL5/Files
input string InpLogFile           = "grid_demo.csv";
input bool   InpDebug             = false;

input group "Grid"
input ENUM_GRID_DEMO_SIDE InpGridSide = GRID_DEMO_LONG;
input ENUM_SIM_GRID_SPACING InpSpacingMode = SIM_GRID_FIXED_POINTS;
input double InpSpacingPoints     = 300.0;                    // used when spacing = fixed
input int    InpAtrPeriod         = 14;                       // used when spacing = ATR
input double InpAtrMultiplier     = 1.0;                      // used when spacing = ATR
input int    InpMaxGridLevels     = 5;                        // total levels incl. first
input double InpBaseVolume        = 0.01;                     // first level, real lots
input double InpVolumeMultiplier  = 1.50;
input double InpMaxLevelVolume    = 0.10;                     // per-level hard cap

input group "Exit"
input ENUM_GRID_DEMO_EXIT InpExitMode = GRID_DEMO_EXIT_BASKET;
input double InpLevelTargetPoints = 300.0;                    // per-level profit, LEVEL mode
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

int      g_atr_handle=INVALID_HANDLE;
double   g_point=0.0;
double   g_mid=0.0;
string   g_config_hash="";
string   g_timeframe_text="";
ENUM_SIM_SIDE g_side=SIM_SIDE_BUY;

ExecDemoBasket g_basket;
datetime g_last_bar=0;
datetime g_last_exit_bar=0;
datetime g_basket_open_time=0;

double   g_equity=0.0;
double   g_peak_equity=0.0;
double   g_day_start_equity=0.0;
long     g_day_key=0;

bool     g_halted=false;
string   g_halt_reason="";
int      g_levels_opened=0;
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
   if(InpMaxGridLevels<1 || InpMaxGridLevels>50)
     {
      error="max_grid_levels_must_be_between_1_and_50";
      return(false);
     }
   if(!SimIsFinite(InpBaseVolume) || InpBaseVolume<=0.0)
     {
      error="base_volume_must_be_positive";
      return(false);
     }
   if(!SimIsFinite(InpVolumeMultiplier) || InpVolumeMultiplier<1.0)
     {
      error="volume_multiplier_must_be_at_least_one";
      return(false);
     }
   if(!SimIsFinite(InpMaxLevelVolume) || InpMaxLevelVolume<InpBaseVolume)
     {
      error="max_level_volume_must_cover_base_volume";
      return(false);
     }
   if(!SimIsFinite(InpMaxExposure) || InpMaxExposure<InpMaxLevelVolume)
     {
      error="max_exposure_must_cover_max_level_volume";
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
   if(!SimIsFinite(InpSpacingPoints) || InpSpacingPoints<=0.0)
     {
      error="spacing_points_must_be_positive";
      return(false);
     }
   if(InpSpacingMode==SIM_GRID_ATR_MULTIPLE &&
      (!SimIsFinite(InpAtrMultiplier) || InpAtrMultiplier<=0.0))
     {
      error="atr_multiplier_must_be_positive";
      return(false);
     }
   return(true);
  }

string BuildConfigHash(void)
  {
   string text=SimFormatFingerprintPartText("ea","GridDemoEA")+
               SimFormatFingerprintPartInt("ea.execution_enabled",
                                           (InpEnableExecution ? 1 : 0))+
               SimFormatFingerprintPartInt("ea.magic",(int)InpMagicNumber)+
               SimFormatFingerprintPartInt("ea.deviation",InpMaxSlippagePoints)+
               SimFormatFingerprintPartInt("grid.side",(int)InpGridSide)+
               SimFormatFingerprintPartInt("grid.spacing_mode",(int)InpSpacingMode)+
               SimFormatFingerprintPart("grid.spacing_points",InpSpacingPoints,1)+
               SimFormatFingerprintPartInt("grid.atr_period",InpAtrPeriod)+
               SimFormatFingerprintPart("grid.atr_multiplier",InpAtrMultiplier,4)+
               SimFormatFingerprintPartInt("grid.max_levels",InpMaxGridLevels)+
               SimFormatFingerprintPart("grid.base_volume",InpBaseVolume,4)+
               SimFormatFingerprintPart("grid.volume_multiplier",InpVolumeMultiplier,4)+
               SimFormatFingerprintPart("grid.max_level_volume",InpMaxLevelVolume,4)+
               SimFormatFingerprintPartInt("exit.mode",(int)InpExitMode)+
               SimFormatFingerprintPart("exit.level_target_points",
                                        InpLevelTargetPoints,1)+
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
   record.ea="GridDemoEA";
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
      PrintFormat("LAB|ERROR|grid_demo|log_write_failed|%s",error);
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
   PrintFormat("LAB|WARN|grid_demo|halted|reason=%s",reason);
  }

SimRiskDecision EvaluateRisk(const double volume_to_add,const datetime bar_time)
  {
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   SimRiskContext ctx;
   ctx.spread_points=(bid>0.0 && ask>0.0 ? (ask-bid)/g_point : 0.0);
   ctx.price_valid=(bid>0.0 && ask>0.0);
   ctx.open_positions=g_basket.count;
   ctx.grid_levels=g_basket.count;
   ctx.dca_adds=0;
   ctx.exposure=g_basket.volume;
   ctx.volume_to_add=volume_to_add;
   ctx.equity=g_equity;
   ctx.day_start_equity=g_day_start_equity;
   ctx.peak_equity=g_peak_equity;
   ctx.bar_time=bar_time;
   return(g_risk.Evaluate(ctx));
  }

//--- Basket-level loss budget: what the whole basket would lose at its stop.
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
//| Spacing                                                          |
//+------------------------------------------------------------------+
bool ReadSpacing(double &spacing)
  {
   if(InpSpacingMode==SIM_GRID_FIXED_POINTS)
      spacing=InpSpacingPoints*g_point;
   else
     {
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer,true);
      if(CopyBuffer(g_atr_handle,0,0,2,atr_buffer)<2)
         return(false);
      spacing=atr_buffer[1]*InpAtrMultiplier;
     }
   return(SimIsFinite(spacing) && spacing>0.0);
  }

//+------------------------------------------------------------------+
//| Basket stops                                                     |
//+------------------------------------------------------------------+
//--- Recomputes basket SL/TP from the average entry and pushes them to every
//--- leg, so the basket stops as a unit at the broker as well.
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
      PrintFormat("LAB|ERROR|grid_demo|stops_invalid|avg=%.8f|sl=%.8f|tp=%.8f",
                  g_basket.average_entry,sl,tp);
      return(false);
     }

   int updated=0;
   int failed=0;
   if(!ExecDemoBasketSetStops(InpMagicNumber,sl,tp,InpMaxSlippagePoints,
                              updated,failed))
     {
      PrintFormat("LAB|ERROR|grid_demo|stops_update_failed|updated=%d|failed=%d",
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

bool OpenLevel(const double raw_volume,const string reason)
  {
   const bool is_buy=(g_side==SIM_SIDE_BUY);

   const double volume=NormalizeVolume(raw_volume);
   if(!(volume>0.0))
     {
      LogEvent("BLOCKED",0.0,raw_volume,0.0,0.0,0.0,"volume_below_broker_minimum");
      g_blocks++;
      return(false);
     }

   //--- Basket stop/target implied by the prospective new average entry.
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
                      "GRID_DEMO",fill))
     {
      LogEvent("ERROR",reference,volume,prospective_average,sl,tp,
               StringFormat("order_failed|%s",fill.message));
      return(false);
     }

   g_levels_opened++;
   LogEvent("ENTRY",fill.price,fill.volume,g_basket.average_entry,sl,tp,
            StringFormat("GRID_OPEN|%s|retcode=%s",reason,fill.message));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|grid_demo|entry|price=%.8f|volume=%.4f|sl=%.8f|tp=%.8f",
                  fill.price,fill.volume,sl,tp);
   return(true);
  }

//--- LEVEL exit mode: closes the legs that are individually in profit.
void CloseProfitableLegs(const string reason_tag)
  {
   const bool is_buy=(g_side==SIM_SIDE_BUY);
   const double target=InpLevelTargetPoints;
   const double point=g_point;

   ulong tickets[];
   ArrayResize(tickets,0);
   const int total=PositionsTotal();
   for(int i=0; i<total; i++)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber)
         continue;
      const double open_price=PositionGetDouble(POSITION_PRICE_OPEN);
      const double current=(is_buy ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol,SYMBOL_ASK));
      const double profit_points=(is_buy ? current-open_price
                                         : open_price-current)/point;
      if(profit_points+1e-9<target)
         continue;
      const int size=ArraySize(tickets);
      ArrayResize(tickets,size+1);
      tickets[size]=ticket;
     }

   for(int i=0; i<ArraySize(tickets); i++)
     {
      if(!PositionSelectByTicket(tickets[i]))
         continue;
      const bool leg_buy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      const ulong ticket=tickets[i];
      const double open_price=PositionGetDouble(POSITION_PRICE_OPEN);
      const double volume=PositionGetDouble(POSITION_VOLUME);

      if(!InpEnableExecution)
        {
         LogEvent("DRY_RUN",0.0,volume,open_price,0.0,0.0,
                  StringFormat("%s|would_close_leg|profit_target=%.1f",
                               reason_tag,target));
         continue;
        }

      ExecFillResult fill;
      if(ExecClosePosition(ticket,leg_buy,volume,InpMaxSlippagePoints,
                           InpMagicNumber,"GRID_DEMO_LVL",fill))
        {
         g_closed_legs++;
         LogEvent("EXIT",fill.price,fill.volume,open_price,0.0,0.0,
                  StringFormat("%s|leg|retcode=%s",reason_tag,fill.message));
        }
      else
         LogEvent("ERROR",0.0,volume,open_price,0.0,0.0,
                  StringFormat("leg_close_failed|%s",fill.message));
     }
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
   ExecDemoBasketClose(InpMagicNumber,InpMaxSlippagePoints,"GRID_DEMO_CLOSE",
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

   if(pnl<0.0)
      g_consecutive_losses++;
   else if(pnl>0.0)
      g_consecutive_losses=0;

   LogEvent("EXIT",0.0,volume,average,0.0,0.0,
            StringFormat("%s|legs=%d|closed=%d|failed=%d|pnl=%.2f|"
                         "consecutive_losses=%d",
                         reason_tag,legs,closed,failed,pnl,g_consecutive_losses));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|grid_demo|close|reason=%s|closed=%d|pnl=%.2f",
                  reason_tag,closed,pnl);
  }

//+------------------------------------------------------------------+
//| Decisions                                                        |
//+------------------------------------------------------------------+
void TryStart(const datetime bar_time,const double spacing)
  {
   if(bar_time==g_last_exit_bar)
      return;
   if(!ConsecutiveLossAllows())
      return;

   const SimGridPlan plan=SimGridPlanAdd(1,InpMaxGridLevels,InpBaseVolume,
                                         InpVolumeMultiplier,InpMaxLevelVolume,
                                         0.0,InpMaxExposure);
   if(!plan.allowed)
     {
      LogEvent("BLOCKED",0.0,InpBaseVolume,0.0,0.0,0.0,
               StringFormat("plan|%s|level=1|spacing=%.8f",plan.reason,spacing));
      g_blocks++;
      return;
     }

   const double volume=NormalizeVolume(plan.volume);
   if(!(volume>0.0))
     {
      LogEvent("BLOCKED",0.0,plan.volume,0.0,0.0,0.0,
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

   if(!OpenLevel(volume,StringFormat("level=1|spacing=%.8f",spacing)))
      return;
   g_risk.RecordEntry(bar_time);
   g_basket_open_time=(g_basket_open_time>0 ? g_basket_open_time : TimeCurrent());
  }

void TryAdd(const datetime bar_time,const double spacing)
  {
   for(int guard=0; guard<InpMaxGridLevels; guard++)
     {
      const int current=g_basket.count;
      if(current<=0 || current>=InpMaxGridLevels)
         return;

      const double last_entry=(g_side==SIM_SIDE_BUY ? g_basket.min_entry
                                                    : g_basket.max_entry);
      const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(!SimGridTriggered(g_side,last_entry,spacing,bid,ask))
         return;

      const SimGridPlan plan=SimGridPlanAdd(current+1,InpMaxGridLevels,
                                            InpBaseVolume,InpVolumeMultiplier,
                                            InpMaxLevelVolume,g_basket.volume,
                                            InpMaxExposure);
      if(!plan.allowed)
        {
         LogEvent("BLOCKED",0.0,InpBaseVolume,g_basket.average_entry,0.0,0.0,
                  StringFormat("plan|%s|level=%d|spacing=%.8f",
                               plan.reason,current+1,spacing));
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
                             StringFormat("level=%d",current+1)))
         return;

      const double trigger=SimGridNextLevelPrice(g_side,last_entry,spacing);
      if(!OpenLevel(volume,StringFormat("level=%d|trigger=%.8f|spacing=%.8f",
                                       current+1,trigger,spacing)))
         return;
     }
  }

void UpdateExits(const double bid,const double ask)
  {
   if(SimGridStopHit(g_side,g_basket.average_entry,InpBasketStopPoints*g_point,
                     bid,ask))
     {
      CloseBasket("BASKET_STOP");
      return;
     }

   if(InpExitMode==GRID_DEMO_EXIT_BASKET &&
      SimGridTargetHit(g_side,g_basket.average_entry,
                       InpBasketTargetPoints*g_point,bid,ask))
     {
      CloseBasket("BASKET_TARGET");
      return;
     }

   if(InpExitMode==GRID_DEMO_EXIT_LEVEL)
      CloseProfitableLegs("LEVEL_TARGET");
  }

//+------------------------------------------------------------------+
//| Summary                                                          |
//+------------------------------------------------------------------+
void WriteSummary(void)
  {
   if(!g_logger.IsOpen())
      return;
   LogEvent("SUMMARY",g_mid,g_basket.volume,g_basket.average_entry,0.0,0.0,
            StringFormat("levels_opened=%d|closed_legs=%d|baskets=%d|"
                         "peak_exposure=%.4f|blocks=%d|consecutive_losses=%d|"
                         "halted=%s|halt_reason=%s|execution=%s",
                         g_levels_opened,g_closed_legs,g_baskets_closed,
                         g_peak_exposure,g_blocks,g_consecutive_losses,
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
      PrintFormat("LAB|ERROR|grid_demo|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(!SimValidatePoint(g_point,error))
     {
      PrintFormat("LAB|ERROR|grid_demo|init_parameters_invalid|%s",error);
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
      PrintFormat("LAB|ERROR|grid_demo|context_denied|reason=%s",
                  ExecBlockName(block));
      return(INIT_FAILED);
     }

   if(InpEnableExecution && !ExecSymbolAllowed(_Symbol,InpAllowedSymbols))
     {
      PrintFormat("LAB|ERROR|grid_demo|symbol_denied|symbol=%s",_Symbol);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SimRiskLimits limits=SimRiskLimitsDefault();
   limits.max_spread_points=InpMaxSpreadPoints;
   limits.max_virtual_positions=InpMaxGridLevels;
   limits.max_grid_levels=InpMaxGridLevels;
   limits.max_dca_adds=0;
   limits.max_virtual_exposure=InpMaxExposure;
   limits.max_daily_loss_pct=InpMaxDailyLossPct;
   limits.max_drawdown_pct=InpMaxDrawdownPct;
   limits.cooldown_bars=0;
   limits.require_valid_price=true;
   limits.kill_switch=false;
   //--- ADR 0006 §4: guard-level blocks (spread, level caps, budget) must
   //--- not escalate to a permanent halt; the guard only Halt()s on real
   //--- equity breaches and the EA promotes them via InpHaltOnBreach.
   limits.halt_on_breach=false;

   if(!g_risk.Init(limits,PeriodSeconds(_Period),error))
     {
      PrintFormat("LAB|ERROR|grid_demo|risk_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(InpSpacingMode==SIM_GRID_ATR_MULTIPLE)
     {
      g_atr_handle=iATR(_Symbol,_Period,InpAtrPeriod);
      if(g_atr_handle==INVALID_HANDLE)
        {
         PrintFormat("LAB|ERROR|grid_demo|indicator_init_failed|error=%d",
                     GetLastError());
         return(INIT_FAILED);
        }
     }

   g_side=(InpGridSide==GRID_DEMO_LONG ? SIM_SIDE_BUY : SIM_SIDE_SELL);
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
         PrintFormat("LAB|ERROR|grid_demo|log_open_failed|%s",error);
         return(INIT_FAILED);
        }
     }

   const string mode=(InpEnableExecution ? "DEMO_EXECUTION" : "DRY_RUN");
   LogEvent("INIT",0.0,InpBaseVolume,0.0,0.0,0.0,
            StringFormat("mode=%s|symbol=%s|allowed=%s|magic=%d|config_hash=%s|"
                         "equity=%.2f",mode,_Symbol,InpAllowedSymbols,
                         InpMagicNumber,g_config_hash,g_equity));
   PrintFormat("LAB|INFO|grid_demo|initialized|mode=%s|hash=%s|magic=%d|"
               "tester=%d|execution_enabled=%d",
               mode,g_config_hash,InpMagicNumber,
               (int)MQLInfoInteger(MQL_TESTER),(InpEnableExecution ? 1 : 0));
   if(!InpEnableExecution)
      PrintFormat("LAB|INFO|grid_demo|dry_run|no_orders_are_sent");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   WriteSummary();
   g_logger.Close();
   if(g_atr_handle!=INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
   PrintFormat("LAB|INFO|grid_demo|deinit|reason=%d|levels=%d|baskets=%d|"
               "consecutive_losses=%d",
               reason,g_levels_opened,g_baskets_closed,g_consecutive_losses);
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

   double spacing=0.0;
   const bool have_spacing=ReadSpacing(spacing);

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
      if(g_basket.count>0 && have_spacing)
         TryAdd(bar_time,spacing);
     }

   if(g_basket.count==0 && new_bar && have_spacing)
      TryStart(bar_time,spacing);
  }
