//+------------------------------------------------------------------+
//|                                          RunnerTrailingLabEA.mq5 |
//|        MT5 EA Lab - simulation-only runner with trailing stop     |
//|                                                                  |
//| Opens virtual positions in memory only. No order-send call and    |
//| no trade class: virtual positions, CSV logs and research only.    |
//| The EA is intended for the Strategy Tester, not for live trading. |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Simulation-only single-position runner with breakeven and trailing stop."
#property description "No trading functions: virtual positions and CSV logs only."

#include "../Include/Sim/SimPortfolio.mqh"
#include "../Include/Sim/SimCostModel.mqh"
#include "../Include/Sim/SimRiskGuard.mqh"
#include "../Include/Sim/SimTrailing.mqh"
#include "../Include/Sim/SimLogger.mqh"

enum ENUM_RUNNER_TRAIL_MODE
  {
   RUNNER_TRAIL_FIXED = 0,
   RUNNER_TRAIL_ATR   = 1
  };

enum ENUM_RUNNER_SIDE_FILTER
  {
   RUNNER_SIDE_BOTH       = 0,
   RUNNER_SIDE_LONG_ONLY  = 1,
   RUNNER_SIDE_SHORT_ONLY = 2
  };

input group "Simulation"
input double InpInitialBalance      = 10000.0;  // virtual starting balance
input double InpVolume              = 1.0;      // virtual volume per entry
input bool   InpEnableLog           = true;     // write CSV to MQL5/Files
input string InpLogFile             = "sim_runner_log.csv";
input bool   InpDebug               = false;

input group "Signal"
input ENUM_RUNNER_SIDE_FILTER InpSideFilter = RUNNER_SIDE_BOTH;
input int    InpFastEma             = 20;
input int    InpSlowEma             = 50;
input int    InpAtrPeriod           = 14;

input group "Stops"
input double InpAtrSlMultiplier     = 2.0;      // initial SL = ATR * multiplier
input bool   InpBreakEvenEnabled    = true;
input double InpBreakEvenTriggerPoints = 400.0; // profit in points that arms breakeven
input double InpBreakEvenOffsetPoints  = 0.0;   // SL beyond entry once armed
input ENUM_RUNNER_TRAIL_MODE InpTrailMode = RUNNER_TRAIL_ATR;
input double InpTrailFixedPoints    = 300.0;    // used when mode = fixed
input double InpTrailAtrMultiplier  = 2.0;      // used when mode = ATR
input double InpMinStopPoints       = 5.0;      // minimum SL distance from price
input bool   InpUpdateOnClosedBarOnly = true;
input int    InpMaxHoldingBars      = 0;        // 0 = disabled

input group "RiskGuard"
input int    InpCooldownBars        = 1;
input double InpMaxSpreadPoints     = 50.0;
input double InpMaxVirtualExposure  = 1.0;      // normalized volume cap
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

int      g_fast_handle=INVALID_HANDLE;
int      g_slow_handle=INVALID_HANDLE;
int      g_atr_handle=INVALID_HANDLE;
double   g_point=0.0;
double   g_slippage_price=0.0;
string   g_config_hash="";
string   g_timeframe_text="";
datetime g_last_bar=0;
double   g_mid=0.0;
double   g_day_start_equity=0.0;
long     g_day_key=0;

bool     g_has_position=false;
ENUM_SIM_SIDE g_side=SIM_SIDE_NONE;
double   g_entry=0.0;
double   g_volume=0.0;
double   g_sl=0.0;
double   g_entry_commission=0.0;
datetime g_entry_bar=0;
datetime g_last_exit_bar=0;

int      g_trades=0;
int      g_wins=0;
int      g_losses=0;
int      g_flats=0;
double   g_net_pnl=0.0;

//+------------------------------------------------------------------+
//| Validation helpers                                               |
//+------------------------------------------------------------------+
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
   if(InpFastEma<1 || InpSlowEma<1)
     {
      error="ema_periods_must_be_positive";
      return(false);
     }
   if(InpSlowEma<=InpFastEma)
     {
      error="slow_ema_must_exceed_fast_ema";
      return(false);
     }
   if(InpAtrPeriod<1)
     {
      error="atr_period_must_be_positive";
      return(false);
     }
   if(!SimIsFinite(InpAtrSlMultiplier) || InpAtrSlMultiplier<=0.0)
     {
      error="atr_sl_multiplier_must_be_positive";
      return(false);
     }
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
   if(!SimIsFinite(InpTrailAtrMultiplier) || InpTrailAtrMultiplier<0.0)
     {
      error="trail_atr_multiplier_must_be_finite_non_negative";
      return(false);
     }
   if(InpTrailMode==RUNNER_TRAIL_FIXED && InpTrailFixedPoints<=0.0)
     {
      error="trail_distance_must_be_positive";
      return(false);
     }
   if(InpTrailMode==RUNNER_TRAIL_ATR && InpTrailAtrMultiplier<=0.0)
     {
      error="trail_distance_must_be_positive";
      return(false);
     }
   if(!SimIsFinite(InpMinStopPoints) || InpMinStopPoints<0.0)
     {
      error="min_stop_points_must_be_finite_non_negative";
      return(false);
     }
   if(!SimValidateCount(InpMaxHoldingBars,
                        "max_holding_bars_must_be_non_negative",error))
      return(false);
   if(!SimValidateCount(InpCooldownBars,"cooldown_bars_must_be_non_negative",error))
      return(false);
   if(!SimValidateSpreadPoints(InpMaxSpreadPoints,error))
      return(false);
   if(!SimIsFinite(InpMaxVirtualExposure) ||
      InpMaxVirtualExposure<InpVolume)
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
                     SimFormatFingerprintPartInt("runner.fast",InpFastEma)+
                     SimFormatFingerprintPartInt("runner.slow",InpSlowEma)+
                     SimFormatFingerprintPartInt("runner.atr",InpAtrPeriod)+
                     SimFormatFingerprintPartInt("runner.trail_mode",
                                                 (InpTrailMode==RUNNER_TRAIL_ATR ? 1 : 0))+
                     SimFormatFingerprintPart("runner.trail_fixed",
                                              InpTrailFixedPoints,4)+
                     SimFormatFingerprintPart("runner.trail_atr",
                                              InpTrailAtrMultiplier,4)+
                     SimFormatFingerprintPartInt("runner.be_enabled",
                                                 (InpBreakEvenEnabled ? 1 : 0))+
                     SimFormatFingerprintPart("runner.be_trigger",
                                              InpBreakEvenTriggerPoints,1)+
                     SimFormatFingerprintPart("runner.be_offset",
                                              InpBreakEvenOffsetPoints,1)+
                     SimFormatFingerprintPartInt("runner.max_hold",
                                                 InpMaxHoldingBars)+
                     SimFormatFingerprintPartInt("runner.side_filter",
                                                 (int)InpSideFilter)+
                     SimFormatFingerprintPartInt("runner.closed_bar_only",
                                                 (InpUpdateOnClosedBarOnly ? 1 : 0))+
                     SimFormatFingerprintPartInt("runner.volume",
                                                 (int)MathRound(InpVolume*100))+
                     SimFormatFingerprintPartInt("runner.balance",
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
   record.ea="RunnerTrailingLabEA";
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
      PrintFormat("LAB|ERROR|runner|log_write_failed|%s",error);
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
//| Indicators                                                       |
//+------------------------------------------------------------------+
bool ReadIndicators(double &fast,double &slow,double &atr)
  {
   double fast_buf[],slow_buf[],atr_buf[];
   ArraySetAsSeries(fast_buf,true);
   ArraySetAsSeries(slow_buf,true);
   ArraySetAsSeries(atr_buf,true);

   if(CopyBuffer(g_fast_handle,0,0,3,fast_buf)<3)
      return(false);
   if(CopyBuffer(g_slow_handle,0,0,3,slow_buf)<3)
      return(false);
   if(CopyBuffer(g_atr_handle,0,0,3,atr_buf)<3)
      return(false);

   fast=fast_buf[1];
   slow=slow_buf[1];
   atr=atr_buf[1];
   return(SimIsFinite(fast) && SimIsFinite(slow) && SimIsFinite(atr));
  }

//+------------------------------------------------------------------+
//| Position lifecycle                                               |
//+------------------------------------------------------------------+
void ClosePosition(const double requested,const string exit_reason)
  {
   string error="";
   const double fill=g_cost.FillPrice(SIM_SIDE_BUY==g_side ? SIM_SIDE_SELL : SIM_SIDE_BUY,
                                      requested,0.0);
   const double commission=g_cost.Commission(g_volume);
   double realized_delta=0.0;
   if(!g_portfolio.CloseAll(fill,commission,error,realized_delta))
     {
      PrintFormat("LAB|ERROR|runner|close_failed|%s",error);
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
   LogEvent("EXIT",g_side,fill,g_volume,g_entry,g_sl,0.0,g_volume,
            StringFormat("%s|bars=%d|pnl=%.4f|commission=%.4f",
                         exit_reason,(int)bars_held,trade_pnl,commission));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|runner|exit|side=%s|fill=%.8f|sl=%.8f|pnl=%.4f",
                  SimSideName(g_side),fill,g_sl,trade_pnl);

   g_last_exit_bar=g_last_bar;
   g_has_position=false;
   g_side=SIM_SIDE_NONE;
   g_entry=0.0;
   g_volume=0.0;
   g_sl=0.0;
   g_entry_commission=0.0;
   g_entry_bar=0;
  }

void CheckStop(const double bid,const double ask)
  {
   if(!SimStopHit(g_side,g_sl,bid,ask))
      return;

   const double requested=SimStopFillPrice(g_side,g_sl,bid,ask);
   const double tolerance=g_point*0.5;
   const bool gapped=SimStopGapped(g_side,g_sl,requested,tolerance);

   string reason="SL_HIT";
   if(gapped)
     {
      const double gap_points=MathAbs(g_sl-requested)/g_point;
      reason=StringFormat("SL_GAP|gap_points=%.2f",gap_points);
     }
   ClosePosition(requested,reason);
  }

void UpdateTrailing(const bool new_bar)
  {
   if(!g_has_position)
      return;
   if(InpUpdateOnClosedBarOnly && !new_bar)
      return;

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0 || ask<=0.0)
      return;

   double distance=0.0;
   if(InpTrailMode==RUNNER_TRAIL_FIXED)
      distance=InpTrailFixedPoints*g_point;
   else
     {
      double atr_buf[];
      ArraySetAsSeries(atr_buf,true);
      if(CopyBuffer(g_atr_handle,0,0,2,atr_buf)<2)
         return;
      distance=atr_buf[1]*InpTrailAtrMultiplier;
     }
   if(!SimIsFinite(distance) || distance<=0.0)
      return;

   SimTrailingInputs in;
   in.side=g_side;
   in.entry=g_entry;
   in.old_sl=g_sl;
   in.price=(g_side==SIM_SIDE_BUY ? bid : ask);
   in.distance=distance;
   in.breakeven_trigger=(InpBreakEvenEnabled ? InpBreakEvenTriggerPoints*g_point : 0.0);
   in.breakeven_offset=InpBreakEvenOffsetPoints*g_point;
   in.min_stop=InpMinStopPoints*g_point;

   const SimTrailingResult out=SimTrailingEvaluate(in);
   if(out.accepted)
     {
      const double old_sl=g_sl;
      g_sl=out.candidate_sl;
      LogEvent("TRAIL",g_side,in.price,g_volume,g_entry,g_sl,0.0,g_volume,
               StringFormat("TRAIL_ACCEPTED|old_sl=%.8f|candidate_sl=%.8f",
                            old_sl,g_sl));
      return;
     }

   if(new_bar)
      LogEvent("TRAIL",g_side,in.price,g_volume,g_entry,g_sl,0.0,g_volume,
               StringFormat("TRAIL_REJECTED|reason=%s|old_sl=%.8f|candidate_sl=%.8f",
                            out.reason,out.candidate_sl,out.raw_candidate));
  }

void TryEntry(const datetime bar_time)
  {
   if(g_has_position)
      return;
   if(bar_time==g_last_exit_bar)
      return;

   double fast=0.0,slow=0.0,atr=0.0;
   if(!ReadIndicators(fast,slow,atr))
      return;
   if(atr<=0.0)
     {
      LogEvent("RISK",SIM_SIDE_NONE,g_mid,0.0,0.0,0.0,0.0,0.0,"atr_invalid");
      return;
     }

   const bool cross_up=(fast>slow);
   const bool cross_down=(fast<slow);
   double fast_prev=0.0,slow_prev=0.0;
   double fast_buf[],slow_buf[];
   ArraySetAsSeries(fast_buf,true);
   ArraySetAsSeries(slow_buf,true);
   if(CopyBuffer(g_fast_handle,0,0,3,fast_buf)<3 ||
      CopyBuffer(g_slow_handle,0,0,3,slow_buf)<3)
      return;
   fast_prev=fast_buf[2];
   slow_prev=slow_buf[2];

   ENUM_SIM_SIDE signal=SIM_SIDE_NONE;
   if(cross_up && fast_prev<=slow_prev)
      signal=SIM_SIDE_BUY;
   else if(cross_down && fast_prev>=slow_prev)
      signal=SIM_SIDE_SELL;
   if(signal==SIM_SIDE_NONE)
      return;
   if((InpSideFilter==RUNNER_SIDE_LONG_ONLY && signal==SIM_SIDE_SELL) ||
      (InpSideFilter==RUNNER_SIDE_SHORT_ONLY && signal==SIM_SIDE_BUY))
     {
      LogEvent("RISK",signal,g_mid,InpVolume,0.0,0.0,0.0,
               g_portfolio.Exposure(),
               "ENTRY_BLOCKED|reason=side_filter|state="+
               SimRiskStateName(g_risk.State()));
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
   if(!decision.allowed)
     {
      LogEvent("RISK",signal,g_mid,InpVolume,0.0,0.0,0.0,
               g_portfolio.Exposure(),
               "ENTRY_BLOCKED|reason="+decision.reason+
               "|state="+SimRiskStateName(decision.state));
      return;
     }

   const double requested=(signal==SIM_SIDE_BUY ? ask : bid);
   const double fill=g_cost.FillPrice(signal,requested,0.0);
   if(fill<=0.0)
      return;

   const double distance=atr*InpAtrSlMultiplier;
   const double sl=(signal==SIM_SIDE_BUY ? fill-distance : fill+distance);
   if(sl<=0.0)
     {
      LogEvent("RISK",signal,g_mid,InpVolume,0.0,0.0,0.0,0.0,"sl_invalid");
      return;
     }

   const double commission=g_cost.Commission(InpVolume);
   string error="";
   if(!g_portfolio.Open(signal,fill,InpVolume,commission,error))
     {
      PrintFormat("LAB|ERROR|runner|open_failed|%s",error);
      return;
     }

   g_has_position=true;
   g_side=signal;
   g_entry=fill;
   g_volume=InpVolume;
   g_sl=sl;
   g_entry_commission=commission;
   g_entry_bar=bar_time;
   g_risk.RecordEntry(bar_time);

   LogEvent("ENTRY",signal,fill,g_volume,g_entry,g_sl,0.0,g_volume,
            StringFormat("SIGNAL_EMA_CROSS|risk=%s|spread_points=%.1f",
                         SimRiskStateName(decision.state),spread_points));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|runner|entry|side=%s|fill=%.8f|sl=%.8f|atr=%.8f",
                  SimSideName(signal),fill,g_sl,atr);
  }

//+------------------------------------------------------------------+
//| Summary                                                          |
//+------------------------------------------------------------------+
void WriteSummary(void)
  {
   if(!g_logger.IsOpen())
      return;
   LogEvent("SUMMARY",SIM_SIDE_NONE,g_mid,g_volume,g_entry,g_sl,0.0,
            g_portfolio.Exposure(),
            StringFormat("trades=%d|wins=%d|losses=%d|flats=%d|net=%.2f|"+
                         "realized=%.2f|max_dd=%.4f|blocks=%d|halted=%s",
                         g_trades,g_wins,g_losses,g_flats,g_net_pnl,
                         g_portfolio.RealizedPnl(),
                         g_portfolio.MaxDrawdownPct(),
                         g_risk.BlockedCount(),
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
      PrintFormat("LAB|ERROR|runner|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(!SimValidatePoint(g_point,error))
     {
      PrintFormat("LAB|ERROR|runner|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SimCostAssumptions assumptions;
   assumptions.point=g_point;
   assumptions.commission_per_volume=InpCommissionPerVolume;
   assumptions.slippage_points=InpSlippagePoints;
   assumptions.swap_per_volume_day=0.0;
   if(!g_cost.Init(assumptions,error))
     {
      PrintFormat("LAB|ERROR|runner|cost_init_failed|%s",error);
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

   const int timeframe_seconds=PeriodSeconds(_Period);
   if(!g_risk.Init(limits,timeframe_seconds,error))
     {
      PrintFormat("LAB|ERROR|runner|risk_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(!g_portfolio.Init(InpInitialBalance,error))
     {
      PrintFormat("LAB|ERROR|runner|portfolio_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_fast_handle=iMA(_Symbol,_Period,InpFastEma,0,MODE_EMA,PRICE_CLOSE);
   g_slow_handle=iMA(_Symbol,_Period,InpSlowEma,0,MODE_EMA,PRICE_CLOSE);
   g_atr_handle=iATR(_Symbol,_Period,InpAtrPeriod);
   if(g_fast_handle==INVALID_HANDLE || g_slow_handle==INVALID_HANDLE ||
      g_atr_handle==INVALID_HANDLE)
     {
      PrintFormat("LAB|ERROR|runner|indicator_init_failed|error=%d",GetLastError());
      return(INIT_FAILED);
     }

   g_timeframe_text=EnumToString(_Period);
   g_config_hash=BuildConfigHash();
   g_day_start_equity=InpInitialBalance;
   g_mid=0.0;

   if(InpEnableLog)
     {
      if(!g_logger.Open(InpLogFile,error))
        {
         PrintFormat("LAB|ERROR|runner|log_open_failed|%s",error);
         return(INIT_FAILED);
        }
     }

   LogEvent("INIT",SIM_SIDE_NONE,0.0,InpVolume,0.0,0.0,0.0,0.0,
            StringFormat("SIMULATION_ONLY|config_hash=%s",g_config_hash));
   PrintFormat("LAB|INFO|runner|initialized|hash=%s|log=%s|tester=%d",
               g_config_hash,(InpEnableLog ? InpLogFile : "disabled"),
               (int)MQLInfoInteger(MQL_TESTER));
   PrintFormat("LAB|INFO|runner|simulation_only|no_orders_are_sent");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   WriteSummary();
   g_logger.Close();
   if(g_fast_handle!=INVALID_HANDLE)
      IndicatorRelease(g_fast_handle);
   if(g_slow_handle!=INVALID_HANDLE)
      IndicatorRelease(g_slow_handle);
   if(g_atr_handle!=INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
   PrintFormat("LAB|INFO|runner|deinit|reason=%d|trades=%d|net=%.2f",
               reason,g_trades,g_net_pnl);
  }

void OnTick(void)
  {
   if(Bars(_Symbol,_Period)<InpSlowEma+InpAtrPeriod+5)
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

   if(g_has_position)
     {
      CheckStop(bid,ask);
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

   if(!g_has_position && new_bar)
      TryEntry(bar_time);
  }
