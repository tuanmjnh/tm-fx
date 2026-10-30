//+------------------------------------------------------------------+
//|                                              PinePlanSimEA.mq5   |
//|        MT5 EA Lab - virtual positions from PinePort trade plans  |
//|                                                                  |
//| Simulation only. Reads the plan buffers of a PinePort indicator   |
//| and opens in-memory virtual positions. No order-send call, no     |
//| trade class, no account API. Intended for the Strategy Tester.    |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Simulation-only EA: one virtual position from a PinePort plan."
#property description "No trading functions: virtual positions and CSV logs only."

#include "../Include/Sim/SimPortfolio.mqh"
#include "../Include/Sim/SimCostModel.mqh"
#include "../Include/Sim/SimRiskGuard.mqh"
#include "../Include/Sim/SimTrailing.mqh"
#include "../Include/Sim/SimPlan.mqh"
#include "../Include/Sim/SimLogger.mqh"
#include "../Include/PinePort/PriceActionMTFContract.mqh"
#include "../Include/PinePort/TMXAUSignals2Contract.mqh"
#include "../Include/PinePort/TMIndicator2Contract.mqh"

enum ENUM_PLAN_SOURCE
  {
   PLAN_SOURCE_PA  = 0,   // Price Action MTF
   PLAN_SOURCE_X2  = 1,   // TM XAU Signals 2
   PLAN_SOURCE_TM2 = 2    // TM Indicator 2
  };

enum ENUM_PLAN_SIDE_FILTER
  {
   PLAN_SIDE_BOTH       = 0,
   PLAN_SIDE_LONG_ONLY  = 1,
   PLAN_SIDE_SHORT_ONLY = -1
  };

input group "Simulation"
input ENUM_PLAN_SOURCE InpSource = PLAN_SOURCE_PA;
input double InpInitialBalance      = 10000.0;  // virtual starting balance
input double InpVolume              = 1.0;      // virtual volume per entry
input bool   InpEnableLog           = true;     // write CSV to MQL5/Files
input string InpLogFile             = "sim_plan_log.csv";
input bool   InpDebug               = false;

input group "Plan"
input ENUM_PLAN_SIDE_FILTER InpSideFilter = PLAN_SIDE_BOTH;
input ENUM_SIM_PLAN_TARGET InpTargetMode = SIM_PLAN_TARGET_TP1;
input double InpMinStopPoints       = 5.0;      // reject plans with a closer stop
input double InpMinTargetPoints     = 5.0;      // reject plans with a closer target
input int    InpMaxHoldingBars      = 0;        // 0 = disabled

input group "Indicator bridge (PriceActionMTF only)"
input double InpPaRr1               = 1.0;      // PA TP1 R multiple (indicator InpRr1Ea)
input double InpPaRrMin             = 1.5;      // PA minimum TP1 R (indicator InpRrMinEa)

input group "Management"
input bool   InpBreakEvenEnabled    = false;
input double InpBreakEvenTriggerPoints = 400.0;
input double InpBreakEvenOffsetPoints  = 0.0;
input bool   InpTrailEnabled        = false;
input double InpTrailFixedPoints    = 300.0;
input double InpMinStopPointsTrail  = 5.0;

input group "RiskGuard"
input int    InpCooldownBars        = 1;
input double InpMaxSpreadPoints     = 50.0;
input double InpMaxVirtualExposure  = 1.0;
input double InpMaxDailyLossPct     = 2.0;
input double InpMaxDrawdownPct      = 5.0;
input bool   InpHaltOnBreach        = false;

input group "Costs (modelled)"
input double InpCommissionPerVolume = 0.0;
input double InpSlippagePoints      = 0.0;

CSimPortfolio    g_portfolio;
CSimCostModel    g_cost;
CSimRiskGuard    g_risk;
CSimLogger       g_logger;

int      g_handle=INVALID_HANDLE;
double   g_point=0.0;
string   g_config_hash="";
string   g_timeframe_text="";
string   g_source_name="";
datetime g_last_bar=0;
datetime g_last_signal_bar=0;
double   g_mid=0.0;
double   g_day_start_equity=0.0;
long     g_day_key=0;

bool     g_has_position=false;
ENUM_SIM_SIDE g_side=SIM_SIDE_NONE;
double   g_entry=0.0;
double   g_volume=0.0;
double   g_sl=0.0;
double   g_target=0.0;
double   g_ref_entry=0.0;
double   g_entry_commission=0.0;
datetime g_entry_bar=0;
datetime g_last_exit_bar=0;

int      g_trades=0;
int      g_wins=0;
int      g_losses=0;
int      g_flats=0;
double   g_net_pnl=0.0;
int      g_entries=0;
int      g_rejected=0;

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
string SourceName(void)
  {
   switch(InpSource)
     {
      case PLAN_SOURCE_X2:  return("TMXAUSignals2");
      case PLAN_SOURCE_TM2: return("TMIndicator2");
      default:              return("PriceActionMTF");
     }
  }

string SourcePath(void)
  {
   return("PinePort\\"+SourceName());
  }

bool ValidateInputs(string &error)
  {
   if(!SimValidateInitialBalance(InpInitialBalance,error))
      return(false);
   if(!SimValidateVolume(InpVolume,error))
      return(false);
   if(InpVolume>1000.0)
     {
      error="volume_must_not_exceed_1000";
      return(false);
     }
   if(InpSideFilter!=PLAN_SIDE_BOTH && InpSideFilter!=PLAN_SIDE_LONG_ONLY &&
      InpSideFilter!=PLAN_SIDE_SHORT_ONLY)
     {
      error="side_filter_must_be_minus_one_zero_or_one";
      return(false);
     }
   if(!SimIsFinite(InpMinStopPoints) || InpMinStopPoints<0.0)
     {
      error="min_stop_points_must_be_finite_non_negative";
      return(false);
     }
   if(!SimIsFinite(InpMinTargetPoints) || InpMinTargetPoints<0.0)
     {
      error="min_target_points_must_be_finite_non_negative";
      return(false);
     }
   if(!SimIsFinite(InpPaRr1) || InpPaRr1<=0.0)
     {
      error="pa_rr1_must_be_finite_positive";
      return(false);
     }
   if(!SimIsFinite(InpPaRrMin) || InpPaRrMin<0.0)
     {
      error="pa_rr_min_must_be_finite_non_negative";
      return(false);
     }
   if(!SimValidateCount(InpMaxHoldingBars,
                        "max_holding_bars_must_be_non_negative",error))
      return(false);
   if(!SimIsFinite(InpBreakEvenTriggerPoints) || InpBreakEvenTriggerPoints<0.0)
     {
      error="breakeven_trigger_points_must_be_finite_non_negative";
      return(false);
     }
   if(!SimIsFinite(InpBreakEvenOffsetPoints) || InpBreakEvenOffsetPoints<0.0)
     {
      error="breakeven_offset_points_must_be_finite_non_negative";
      return(false);
     }
   if(InpBreakEvenEnabled && InpBreakEvenTriggerPoints<=0.0)
     {
      error="breakeven_trigger_must_be_positive_when_enabled";
      return(false);
     }
   if(!SimIsFinite(InpTrailFixedPoints) || InpTrailFixedPoints<0.0)
     {
      error="trail_fixed_points_must_be_finite_non_negative";
      return(false);
     }
   if(InpTrailEnabled && InpTrailFixedPoints<=0.0)
     {
      error="trail_distance_must_be_positive_when_enabled";
      return(false);
     }
   if(!SimIsFinite(InpMinStopPointsTrail) || InpMinStopPointsTrail<0.0)
     {
      error="min_trail_stop_points_must_be_finite_non_negative";
      return(false);
     }
   if(!SimValidateCount(InpCooldownBars,"cooldown_bars_must_be_non_negative",error))
      return(false);
   if(!SimValidateSpreadPoints(InpMaxSpreadPoints,error))
      return(false);
   if(!SimIsFinite(InpMaxVirtualExposure) || InpMaxVirtualExposure<InpVolume)
     {
      error="max_virtual_exposure_must_cover_volume";
      return(false);
     }
   if(InpMaxVirtualExposure>1000.0)
     {
      error="max_virtual_exposure_must_not_exceed_1000";
      return(false);
     }
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
                     SimFormatFingerprintPartText("plan.source",SourceName())+
                     SimFormatFingerprintPartInt("plan.target_mode",(int)InpTargetMode)+
                     SimFormatFingerprintPartInt("plan.side_filter",(int)InpSideFilter)+
                     SimFormatFingerprintPart("plan.min_stop",InpMinStopPoints,1)+
                     SimFormatFingerprintPart("plan.min_target",InpMinTargetPoints,1)+
                     SimFormatFingerprintPartInt("plan.max_hold",InpMaxHoldingBars)+
                     SimFormatFingerprintPartInt("plan.be_enabled",
                                                 (InpBreakEvenEnabled ? 1 : 0))+
                     SimFormatFingerprintPart("plan.be_trigger",InpBreakEvenTriggerPoints,1)+
                     SimFormatFingerprintPart("plan.trail_enabled",
                                              (InpTrailEnabled ? 1 : 0))+
                     SimFormatFingerprintPart("plan.trail_fixed",InpTrailFixedPoints,1)+
                     SimFormatFingerprintPartInt("plan.volume",
                                                 (int)MathRound(InpVolume*100))+
                     SimFormatFingerprintPartInt("plan.balance",
                                                 (int)MathRound(InpInitialBalance))+
                     ((InpSource==PLAN_SOURCE_PA)
                      ? SimFormatFingerprintPart("plan.pa_rr1",InpPaRr1,2)+
                        SimFormatFingerprintPart("plan.pa_rr_min",InpPaRrMin,2)
                      : "");
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
   record.ea="PinePlanSimEA";
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
      PrintFormat("LAB|ERROR|plan|log_write_failed|%s",error);
  }

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
//| Indicator buffers                                                |
//+------------------------------------------------------------------+
double BufferValue(const double value)
  {
   if(value==EMPTY_VALUE || !SimIsFinite(value))
      return(0.0);
   return(value);
  }

bool ReadBuffer(const int index,double &value)
  {
   double buffer[];
   ArraySetAsSeries(buffer,true);
   if(CopyBuffer(g_handle,index,0,3,buffer)<3)
      return(false);
   value=BufferValue(buffer[1]);
   return(true);
  }

bool ReadSignalBuffers(const int long_index,const int short_index,
                       bool &signal_long,bool &signal_short)
  {
   double long_buffer[],short_buffer[];
   ArraySetAsSeries(long_buffer,true);
   ArraySetAsSeries(short_buffer,true);
   if(CopyBuffer(g_handle,long_index,0,3,long_buffer)<3)
      return(false);
   if(CopyBuffer(g_handle,short_index,0,3,short_buffer)<3)
      return(false);
   signal_long=(long_buffer[1]==1.0);
   signal_short=(short_buffer[1]==1.0);
   return(true);
  }

bool ReadPlan(SimPlan &plan,string &error)
  {
   plan.signal=false;
   plan.valid=false;
   plan.side=SIM_SIDE_NONE;
   plan.entry=0.0;
   plan.sl=0.0;
   plan.tp1=0.0;
   plan.tp2=0.0;
   plan.tp3=0.0;

   int dir_index=0;
   int valid_index=0;
   int entry_index=0;
   int sl_index=0;
   int tp1_index=0;
   int tp2_index=0;
   int tp3_index=0;
   int long_index=0;
   int short_index=0;
   bool single_signal=false;

   switch(InpSource)
     {
      case PLAN_SOURCE_X2:
         dir_index=X2_BUF_DIR;
         valid_index=X2_BUF_PLAN_VALID;
         entry_index=X2_BUF_ENTRY;
         sl_index=X2_BUF_SL;
         tp1_index=X2_BUF_TP1;
         tp2_index=X2_BUF_TP2;
         tp3_index=X2_BUF_TP3;
         long_index=X2_BUF_SIG;   // single edge signal, side comes from DIR
         single_signal=true;
         break;
      case PLAN_SOURCE_TM2:
         dir_index=TM2_BUF_DIR;
         valid_index=TM2_BUF_PLAN_VALID;
         entry_index=TM2_BUF_ENTRY;
         sl_index=TM2_BUF_SL;
         tp1_index=TM2_BUF_TP1;
         tp2_index=TM2_BUF_TP2;
         tp3_index=TM2_BUF_TP3;
         long_index=TM2_BUF_SIGNAL;
         single_signal=true;
         break;
      default:
         dir_index=PA_BUF_DIR;
         valid_index=PA_BUF_PLAN_VALID;
         entry_index=PA_BUF_ENTRY;
         sl_index=PA_BUF_SL;
         tp1_index=PA_BUF_TP1;
         tp2_index=PA_BUF_TP2;
         tp3_index=PA_BUF_TP3;
         long_index=PA_BUF_SIG_LONG;
         short_index=PA_BUF_SIG_SHORT;
         break;
     }

   bool signal_long=false;
   bool signal_short=false;
   if(single_signal)
     {
      double signal_buffer[];
      ArraySetAsSeries(signal_buffer,true);
      if(CopyBuffer(g_handle,long_index,0,3,signal_buffer)<3)
        {
         error="signal_copy_failed";
         return(false);
        }
      signal_long=(signal_buffer[1]==1.0);
      signal_short=signal_long;
     }
   else
     {
      if(!ReadSignalBuffers(long_index,short_index,signal_long,signal_short))
        {
         error="signal_copy_failed";
         return(false);
        }
     }

   double direction=0.0;
   double valid=0.0;
   if(!ReadBuffer(dir_index,direction) || !ReadBuffer(valid_index,valid))
     {
      error="plan_copy_failed";
      return(false);
     }
   plan.valid=(valid==1.0);
   plan.entry=0.0;
   if(!ReadBuffer(entry_index,plan.entry) || !ReadBuffer(sl_index,plan.sl) ||
      !ReadBuffer(tp1_index,plan.tp1) || !ReadBuffer(tp2_index,plan.tp2) ||
      !ReadBuffer(tp3_index,plan.tp3))
     {
      error="plan_copy_failed";
      return(false);
     }

   string reason="";
   plan.signal=(signal_long || signal_short);
   const int direction_code=(int)MathRound(direction);
   if(single_signal)
     {
      //--- One edge signal: the side comes from the direction buffer.
      if(signal_long && (direction_code==1 || direction_code==-1))
         plan.side=(direction_code==1 ? SIM_SIDE_BUY : SIM_SIDE_SELL);
      else
         plan.side=SIM_SIDE_NONE;
     }
   else
      plan.side=SimPlanResolveSide(signal_long,signal_short,(int)MathRound(direction),
                                   reason);

   error="";
   return(true);
  }

//+------------------------------------------------------------------+
//| Position lifecycle                                               |
//+------------------------------------------------------------------+
void ClosePosition(const double requested,const string exit_reason)
  {
   string error="";
   const ENUM_SIM_SIDE exit_side=(g_side==SIM_SIDE_BUY ? SIM_SIDE_SELL : SIM_SIDE_BUY);
   const double fill=g_cost.FillPrice(exit_side,requested,0.0);
   const double commission=g_cost.Commission(g_volume);
   double realized_delta=0.0;
   if(!g_portfolio.CloseAll(fill,commission,error,realized_delta))
     {
      PrintFormat("LAB|ERROR|plan|close_failed|%s",error);
      return;
     }

   const double trade_pnl=realized_delta-g_entry_commission;
   g_net_pnl+=trade_pnl;
   g_trades++;
   if(trade_pnl>0.0)
      g_wins++;
   else if(trade_pnl<0.0)
      g_losses++;
   else
      g_flats++;

   const long bars_held=(long)(TimeCurrent()-g_entry_bar)/
                        (long)PeriodSeconds(_Period);
   LogEvent("EXIT",g_side,fill,g_volume,g_entry,g_sl,g_target,g_volume,
            StringFormat("%s|bars=%d|pnl=%.4f|commission=%.4f",
                         exit_reason,(int)bars_held,trade_pnl,commission));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|plan|exit|side=%s|fill=%.8f|sl=%.8f|pnl=%.4f",
                  SimSideName(g_side),fill,g_sl,trade_pnl);

   g_last_exit_bar=g_last_bar;
   g_has_position=false;
   g_side=SIM_SIDE_NONE;
   g_entry=0.0;
   g_volume=0.0;
   g_sl=0.0;
   g_target=0.0;
   g_ref_entry=0.0;
   g_entry_commission=0.0;
   g_entry_bar=0;
  }

void CheckExits(const double bid,const double ask)
  {
   if(g_has_position && SimStopHit(g_side,g_sl,bid,ask))
     {
      const double requested=SimStopFillPrice(g_side,g_sl,bid,ask);
      const double tolerance=g_point*0.5;
      string reason="SL_HIT";
      if(SimStopGapped(g_side,g_sl,requested,tolerance))
        {
         const double gap_points=MathAbs(g_sl-requested)/g_point;
         reason=StringFormat("SL_GAP|gap_points=%.2f",gap_points);
        }
      ClosePosition(requested,reason);
      return;
     }

   if(g_has_position && SimPlanTargetHit(g_side,g_target,bid,ask))
     {
      const double requested=SimPlanTargetFill(g_target);
      ClosePosition(requested,StringFormat("TARGET_HIT|mode=%s",
                                           SimPlanTargetName(InpTargetMode)));
     }
  }

void UpdateTrailing(const bool new_bar)
  {
   if(!g_has_position)
      return;
   if(!InpTrailEnabled && !InpBreakEvenEnabled)
      return;
   if(!new_bar)
      return;

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0 || ask<=0.0)
      return;

   SimTrailingInputs in;
   in.side=g_side;
   in.entry=g_entry;
   in.old_sl=g_sl;
   in.price=(g_side==SIM_SIDE_BUY ? bid : ask);
   in.distance=(InpTrailEnabled ? InpTrailFixedPoints*g_point : 0.0);
   in.breakeven_trigger=(InpBreakEvenEnabled ? InpBreakEvenTriggerPoints*g_point : 0.0);
   in.breakeven_offset=InpBreakEvenOffsetPoints*g_point;
   in.min_stop=InpMinStopPointsTrail*g_point;

   //--- Breakeven-only mode keeps the distance at the current stop distance.
   if(!InpTrailEnabled)
      in.distance=MathAbs(in.price-in.old_sl);
   if(in.distance<=0.0)
      return;

   const SimTrailingResult out=SimTrailingEvaluate(in);
   if(out.accepted)
     {
      const double old_sl=g_sl;
      g_sl=out.candidate_sl;
      LogEvent("TRAIL",g_side,in.price,g_volume,g_entry,g_sl,g_target,g_volume,
               StringFormat("TRAIL_ACCEPTED|old_sl=%.8f|candidate_sl=%.8f",
                            old_sl,g_sl));
      return;
     }

   LogEvent("TRAIL",g_side,in.price,g_volume,g_entry,g_sl,g_target,g_volume,
            StringFormat("TRAIL_REJECTED|reason=%s|candidate_sl=%.8f",
                         out.reason,out.candidate_sl));
  }

void TryEntry(const datetime bar_time)
  {
   if(g_has_position || bar_time==g_last_exit_bar)
      return;

   SimPlan plan;
   string error="";
   if(!ReadPlan(plan,error))
     {
      if(InpDebug)
         PrintFormat("LAB|DEBUG|plan|read_failed|%s",error);
      return;
     }
   if(!plan.signal)
      return;

   const SimPlanCheck check=SimPlanValidate(plan,(int)InpSideFilter,g_point,
                                            InpMinStopPoints,InpMinTargetPoints);
   if(!check.accepted)
     {
      g_rejected++;
      g_last_signal_bar=bar_time;
      LogEvent("RISK",plan.side,g_mid,InpVolume,plan.entry,plan.sl,plan.tp1,
               g_portfolio.Exposure(),
               StringFormat("PLAN_REJECTED|reason=%s|source=%s",
                            check.reason,SourceName()));
      return;
     }

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0 || ask<=0.0)
      return;
   const double spread_points=(ask-bid)/g_point;
   const double equity=g_portfolio.Equity(g_mid);

   SimRiskContext ctx;
   ctx.spread_points=spread_points;
   ctx.price_valid=true;
   ctx.open_positions=g_portfolio.OpenPositions();
   ctx.grid_levels=0;
   ctx.dca_adds=0;
   ctx.exposure=g_portfolio.Exposure();
   ctx.volume_to_add=InpVolume;
   ctx.equity=equity;
   ctx.day_start_equity=g_day_start_equity;
   ctx.peak_equity=g_portfolio.PeakEquity();
   ctx.bar_time=bar_time;

   const SimRiskDecision decision=g_risk.Evaluate(ctx);
   g_last_signal_bar=bar_time;
   if(!decision.allowed)
     {
      LogEvent("RISK",plan.side,g_mid,InpVolume,plan.entry,plan.sl,plan.tp1,
               g_portfolio.Exposure(),
               "ENTRY_BLOCKED|reason="+decision.reason+
               "|state="+SimRiskStateName(decision.state));
      return;
     }

   const double requested=(plan.side==SIM_SIDE_BUY ? ask : bid);
   const double fill=g_cost.FillPrice(plan.side,requested,0.0);
   if(!SimIsFinite(fill) || fill<=0.0)
      return;

   const double commission=g_cost.Commission(InpVolume);
   if(!g_portfolio.Open(plan.side,fill,InpVolume,commission,error))
     {
      PrintFormat("LAB|ERROR|plan|open_failed|%s",error);
      return;
     }

   g_has_position=true;
   g_side=plan.side;
   g_entry=fill;
   g_volume=InpVolume;
   g_sl=plan.sl;
   g_target=SimPlanTargetPrice(plan,InpTargetMode);
   g_ref_entry=plan.entry;
   g_entry_commission=commission;
   g_entry_bar=bar_time;
   g_entries++;
   g_risk.RecordEntry(bar_time);

   LogEvent("ENTRY",g_side,fill,g_volume,g_entry,g_sl,g_target,g_volume,
            StringFormat("PLAN_ENTRY|source=%s|ref_entry=%.8f|risk=%s|spread_points=%.1f",
                         SourceName(),g_ref_entry,SimRiskStateName(decision.state),
                         spread_points));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|plan|entry|side=%s|fill=%.8f|ref=%.8f|sl=%.8f|target=%.8f",
                  SimSideName(g_side),fill,g_ref_entry,g_sl,g_target);
  }

//+------------------------------------------------------------------+
//| Summary                                                          |
//+------------------------------------------------------------------+
void WriteSummary(void)
  {
   if(!g_logger.IsOpen())
      return;
   LogEvent("SUMMARY",SIM_SIDE_NONE,g_mid,g_volume,g_entry,g_sl,g_target,
            g_portfolio.Exposure(),
            StringFormat("source=%s|entries=%d|rejected=%d|trades=%d|wins=%d|"+
                         "losses=%d|flats=%d|net=%.2f|realized=%.2f|max_dd=%.4f|"+
                         "blocks=%d|halted=%s",
                         SourceName(),g_entries,g_rejected,g_trades,g_wins,
                         g_losses,g_flats,g_net_pnl,g_portfolio.RealizedPnl(),
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
      PrintFormat("LAB|ERROR|plan|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(!SimValidatePoint(g_point,error))
     {
      PrintFormat("LAB|ERROR|plan|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SimCostAssumptions assumptions;
   assumptions.point=g_point;
   assumptions.commission_per_volume=InpCommissionPerVolume;
   assumptions.slippage_points=InpSlippagePoints;
   assumptions.swap_per_volume_day=0.0;
   if(!g_cost.Init(assumptions,error))
     {
      PrintFormat("LAB|ERROR|plan|cost_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SimRiskLimits limits=SimRiskLimitsDefault();
   limits.max_spread_points=InpMaxSpreadPoints;
   limits.max_virtual_positions=1;
   limits.max_grid_levels=0;
   limits.max_dca_adds=0;
   limits.max_virtual_exposure=InpMaxVirtualExposure;
   limits.max_daily_loss_pct=InpMaxDailyLossPct;
   limits.max_drawdown_pct=InpMaxDrawdownPct;
   limits.cooldown_bars=InpCooldownBars;
   limits.require_valid_price=true;
   limits.kill_switch=false;
   limits.halt_on_breach=InpHaltOnBreach;

   if(!g_risk.Init(limits,PeriodSeconds(_Period),error))
     {
      PrintFormat("LAB|ERROR|plan|risk_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(!g_portfolio.Init(InpInitialBalance,error))
     {
      PrintFormat("LAB|ERROR|plan|portfolio_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_source_name=SourceName();
   //--- PriceActionMTF exposes two leading bridge inputs (rr1, rrMin). Every other
   //--- source keeps the zero-parameter call so its defaults stay authoritative.
   if(InpSource==PLAN_SOURCE_PA)
      g_handle=iCustom(_Symbol,_Period,SourcePath(),InpPaRr1,InpPaRrMin);
   else
      g_handle=iCustom(_Symbol,_Period,SourcePath());
   if(g_handle==INVALID_HANDLE)
     {
      PrintFormat("LAB|ERROR|plan|indicator_init_failed|source=%s|error=%d",
                  g_source_name,GetLastError());
      return(INIT_FAILED);
     }

   g_timeframe_text=EnumToString(_Period);
   g_config_hash=BuildConfigHash();
   g_day_start_equity=InpInitialBalance;

   if(InpEnableLog)
     {
      if(!g_logger.Open(InpLogFile,error))
        {
         PrintFormat("LAB|ERROR|plan|log_open_failed|%s",error);
         return(INIT_FAILED);
        }
     }

   LogEvent("INIT",SIM_SIDE_NONE,0.0,InpVolume,0.0,0.0,0.0,0.0,
            StringFormat("SIMULATION_ONLY|source=%s|config_hash=%s",
                         g_source_name,g_config_hash));
   PrintFormat("LAB|INFO|plan|initialized|source=%s|hash=%s|log=%s|tester=%d",
               g_source_name,g_config_hash,(InpEnableLog ? InpLogFile : "disabled"),
               (int)MQLInfoInteger(MQL_TESTER));
   if(InpSource==PLAN_SOURCE_PA)
      PrintFormat("LAB|INFO|plan|pa_bridge|rr1=%.2f|rr_min=%.2f",
                  InpPaRr1,InpPaRrMin);
   PrintFormat("LAB|INFO|plan|simulation_only|no_orders_are_sent");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   WriteSummary();
   g_logger.Close();
   if(g_handle!=INVALID_HANDLE)
      IndicatorRelease(g_handle);
   PrintFormat("LAB|INFO|plan|deinit|reason=%d|trades=%d|net=%.2f",
               reason,g_trades,g_net_pnl);
  }

void OnTick(void)
  {
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

   if(g_has_position)
     {
      CheckExits(bid,ask);
      if(g_has_position && new_bar && InpMaxHoldingBars>0)
        {
         const long bars_held=(long)(bar_time-g_entry_bar)/
                              (long)PeriodSeconds(_Period);
         if(bars_held>=InpMaxHoldingBars)
            ClosePosition(g_side==SIM_SIDE_BUY ? bid : ask,"MAX_HOLDING_BARS");
        }
      if(g_has_position)
         UpdateTrailing(new_bar);
     }

   if(!g_has_position && new_bar && bar_time!=g_last_signal_bar)
      TryEntry(bar_time);
  }
