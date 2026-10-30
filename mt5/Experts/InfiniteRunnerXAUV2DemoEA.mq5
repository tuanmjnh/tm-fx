//+------------------------------------------------------------------+
//|                                       InfiniteRunnerXAUV2DemoEA  |
//|  InfiniteRunner_XAU V2 - lab port of the runner strategy          |
//|                                                                  |
//|  Demo account / Strategy Tester ONLY (hard guard at OnInit).     |
//|  Orders are sent exclusively through mt5/Include/Exec/ExecBroker |
//|  after ExecGuard checks. Execution enabled by default (ADR 0006); |
//|  set InpEnableExecution=false for a dry-run. No credentials, no   |
//|  WebRequest/sockets, no live/real accounts.                      |
//|                                                                  |
//|  V2 changes versus V1 (docs/v2/STRATEGIES/...UPGRADE_SPEC.md):   |
//|   - decisions on CLOSED bars only (V1 read the running bar);     |
//|   - DIR_EMA_MTF (H1 context + M15 confirm + M5 reclaim trigger)   |
//|     with BUY/SELL/NO_TRADE/REVERSAL_WATCH reason codes, plus     |
//|     DIR_LEGACY_EMA as the V1-parity baseline;                    |
//|   - entries only on a new EntryTF bar, one signal per bar,       |
//|     cooldown/min-bars/max-trades and no instant re-entry;        |
//|   - risk-based lot sizing via ExecCalcProfit (OrderCalcProfit);  |
//|   - daily-loss / drawdown / loss-streak locks, persisted state;  |
//|   - initial SL fixed-points or ATR, tick-normalized, inside a    |
//|     configured band and clamped against the broker stop level;   |
//|   - break-even from the STORED initial R and monotonic trailing  |
//|     (fixed or ATR): BUY SL only rises, SELL SL only falls;       |
//|   - every order carries a mandatory SL plus a far safety TP so   |
//|     the runner still exits on its trailing stop (ADR 0004).      |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "2.00"
#property description "InfiniteRunner V2. Demo/Tester only. Closed-bar decisions, MTF direction, risk sizing, monotonic trailing."

#include "../Include/Exec/ExecBroker.mqh"
#include "../Include/Sim/SimTypes.mqh"
#include "../Include/Sim/SimValidate.mqh"
#include "../Include/Sim/SimRiskGuard.mqh"
#include "../Include/Sim/SimLogger.mqh"
#include "../Include/InfiniteRunner/IRTypes.mqh"
#include "../Include/InfiniteRunner/IRDirection.mqh"
#include "../Include/InfiniteRunner/IRTrailing.mqh"

input group "Demo execution"
input bool   InpEnableExecution     = true;                     // false = dry-run, no orders (ADR 0006: true by default)
input string InpAllowedSymbols      = "XAUUSD";                  // prefix allow-list, comma separated
input long   InpMagicNumber         = 25006001;
input int    InpMaxSlippagePoints   = 30;                        // deviation for market orders
input string InpKillSwitchFile      = "INFINITE_RUNNER_DEMO_STOP.txt";
input bool   InpCloseOnKillSwitch   = true;

input group "Journal and state"
input bool   InpEnableLog           = true;
input string InpLogFile             = "infinite_runner_demo.csv";
input bool   InpPersistState        = true;
input string InpStateFile           = "infinite_runner_demo_state.csv";
input bool   InpResetStateOnInit    = false;
input bool   InpDebug               = false;

input group "Direction"
input ENUM_IR_DIRECTION_MODE InpDirectionMode = IR_DIR_LEGACY_EMA;
input ENUM_TIMEFRAMES InpH1TF              = PERIOD_H1;
input ENUM_TIMEFRAMES InpM15TF             = PERIOD_M15;
input ENUM_TIMEFRAMES InpEntryTF          = PERIOD_M5;
input int    InpEmaFast             = 21;
input int    InpEmaSlow             = 50;
input int    InpSlopeBars           = 5;
input int    InpSlowSlopeTolPoints  = 100;
input int    InpPullbackTolPoints   = 100;

input group "Entry control"
input int    InpMaxPositions        = 1;                         // fixed to 1 by validation
input int    InpCooldownMinutes     = 0;
input int    InpMinBarsBetweenEntries = 1;
input int    InpMaxTradesPerDay     = 50;

input group "Risk"
input ENUM_IR_LOT_MODE InpLotMode   = IR_LOT_FIXED;
input double InpLots                  = 0.01;
input double InpRiskPercent           = 0.25;
input double InpMaxLots               = 0.20;
input int    InpMaxSpreadPoints       = 600;
input double InpMaxSpreadAtrRatio     = 0.0;                      // 0 = off
input double InpAbnormalAtrRatio      = 2.5;                      // 0 = off
input int    InpAtrPeriod             = 14;
input int    InpAtrBaselineBars       = 100;
input double InpMaxDailyLossPct       = 1.0;
input double InpMaxDrawdownPct        = 8.0;
input int    InpMaxConsecutiveLosses  = 3;
input bool   InpHaltOnBreach         = true;
input bool   InpManualResetDrawdown  = false;                     // log-kept manual DD reset

input group "Initial SL"
input ENUM_IR_SL_MODE InpSlMode      = IR_SL_FIXED;
input int    InpInitialSlPoints      = 5000;
input double InpSlAtrMultiplier       = 3.0;
input int    InpMinStopPoints         = 500;
input int    InpMaxStopPoints         = 20000;

input group "Trailing"
input ENUM_IR_TRAIL_MODE InpTrailMode = IR_TRAIL_FIXED;
input int    InpTrailStartPts         = 3000;
input int    InpTrailDistancePts      = 2500;
input int    InpTrailStepPts          = 500;
input double InpTrailAtrMultiplier    = 2.0;
input double InpBreakEvenTriggerR     = 0.0;                      // 0 = off
input int    InpBreakEvenBufferPts    = 100;
input int    InpSafetyTpPoints        = 100000;                   // far mandatory TP

input group "Step Trailing"
input bool   InpEnableStepTrailing    = true;                     // true = bat keo SL da tang theo nac loi nhuan
input double InpStep1_TriggerPoints   = 1500.0;                   // Dat loi nhuan nac 1 (1.5 USD vang)
input double InpStep1_LockPoints      = 200.0;                    // Khoa SL nac 1 (Hoa von + 0.2 USD bao ve phi)
input double InpStep2_TriggerPoints   = 3000.0;                   // Dat loi nhuan nac 2 (3.0 USD vang)
input double InpStep2_LockPoints      = 1500.0;                   // Khoa SL nac 2 (Bo tui +1.5 USD)
input double InpStep3_TriggerPoints   = 5000.0;                   // Dat loi nhuan nac 3 (5.0 USD vang)
input double InpStep3_LockPoints      = 3500.0;                   // Khoa SL nac 3 (Khoa chac +3.5 USD)

CSimRiskGuard g_risk;
CSimLogger    g_logger;

//--- Handles
int      g_ema_h1_fast=INVALID_HANDLE;
int      g_ema_h1_slow=INVALID_HANDLE;
int      g_ema_m15_fast=INVALID_HANDLE;
int      g_ema_m15_slow=INVALID_HANDLE;
int      g_ema_e_fast=INVALID_HANDLE;
int      g_ema_e_slow=INVALID_HANDLE;
int      g_atr_handle=INVALID_HANDLE;

//--- Runtime symbol data
double   g_point=0.0;
int      g_digits=0;
double   g_tick_size=0.0;
string   g_config_hash="";
string   g_timeframe_text="";
bool     g_is_hedging=true;

//--- Risk ledger state
double   g_equity=0.0;
double   g_peak_equity=0.0;
double   g_day_start_equity=0.0;
long     g_day_key=0;
bool     g_dd_locked=false;
int      g_streak_losses=0;
datetime g_cooldown_until=0;
int      g_trades_today=0;
bool     g_halted=false;
string   g_halt_reason="";

//--- Entry throttles
datetime g_last_signal_bar=0;    // entry-TF bar whose signal was processed
datetime g_last_entry_bar=0;     // entry-TF bar time when the last entry was sent
int      g_bars_since_last_entry=1000000;
int      g_exits_today=0;        // diagnostics only

//--- Open-position context (restored or adopted)
bool     g_have_pos=false;
bool     g_pos_is_buy=true;
ulong    g_pos_ticket=0;
double   g_pos_entry=0.0;
double   g_pos_volume=0.0;
double   g_pos_initial_sl=0.0;
double   g_pos_initial_r=0.0;    // stored at entry; not recomputed after restart
datetime g_pos_open_time=0;
bool     g_be_applied=false;
bool     g_sl_missing=false;     // position without SL: safe mode
datetime g_emergency_bar=0;

//--- Cached market snapshot per entry-TF bar (index 0 = last CLOSED bar;
//--- these arrays are only copied during RefreshMarketData).
double   g_h1_fast[];
double   g_h1_slow[];
double   g_m15_fast[];
double   g_m15_slow[];
double   g_m5_fast[];
double   g_m5_slow[];
double   g_atr_last=0.0;
double   g_atr_baseline=0.0;
string   g_h1_bias_text="unknown";
string   g_m15_bias_text="unknown";
string   g_trigger_text="none";
IRDecision g_decision;

//--- Counters for the summary
int      g_entries=0;
int      g_exits=0;
int      g_wins=0;
int      g_losses=0;
int      g_blocks=0;
int      g_sl_updates=0;
double   g_realized_pnl=0.0;

//+------------------------------------------------------------------+
//| Input validation - fail closed                                   |
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
   if(InpMaxPositions!=1)
     {
      error="max_positions_must_be_one";
      return(false);
     }
   if(InpEmaFast<2 || InpEmaSlow<2 || InpEmaFast>=InpEmaSlow)
     {
      error="ema_periods_invalid_fast_must_be_below_slow";
      return(false);
     }
   if(InpSlopeBars<1 || InpSlopeBars>200)
     {
      error="slope_bars_must_be_between_1_and_200";
      return(false);
     }
   if(InpSlowSlopeTolPoints<0 || InpPullbackTolPoints<0)
     {
      error="slope_tolerances_must_be_non_negative";
      return(false);
     }
   if(PeriodSeconds(InpH1TF)<=PeriodSeconds(InpM15TF) ||
      PeriodSeconds(InpM15TF)<PeriodSeconds(InpEntryTF))
     {
      error="timeframes_must_satisfy_h1_gte_m15_gte_entry";
      return(false);
     }
   if(InpCooldownMinutes<0 || InpCooldownMinutes>1440)
     {
      error="cooldown_minutes_must_be_between_0_and_1440";
      return(false);
     }
   if(InpMinBarsBetweenEntries<0 || InpMinBarsBetweenEntries>1000)
     {
      error="min_bars_between_entries_must_be_between_0_and_1000";
      return(false);
     }
   if(InpMaxTradesPerDay<1 || InpMaxTradesPerDay>5000)
     {
      error="max_trades_per_day_must_be_between_1_and_5000";
      return(false);
     }
   if(!SimIsFinite(InpLots) || InpLots<=0.0)
     {
      error="lots_must_be_positive";
      return(false);
     }
   if(InpLotMode==IR_LOT_RISK &&
      (!SimIsFinite(InpRiskPercent) || InpRiskPercent<=0.0 || InpRiskPercent>10.0))
     {
      error="risk_percent_must_be_between_0_exclusive_and_10";
      return(false);
     }
   if(!SimIsFinite(InpMaxLots) || InpMaxLots<=0.0)
     {
      error="max_lots_must_be_positive";
      return(false);
     }
   if(InpMaxSpreadPoints<=0 || InpMaxSpreadPoints>100000)
     {
      error="max_spread_points_must_be_positive";
      return(false);
     }
   if(!SimIsFinite(InpMaxSpreadAtrRatio) || InpMaxSpreadAtrRatio<0.0)
     {
      error="max_spread_atr_ratio_must_be_non_negative";
      return(false);
     }
   if(!SimIsFinite(InpAbnormalAtrRatio) || InpAbnormalAtrRatio<0.0)
     {
      error="abnormal_atr_ratio_must_be_non_negative";
      return(false);
     }
   if(InpAtrPeriod<2 || InpAtrPeriod>500)
     {
      error="atr_period_must_be_between_2_and_500";
      return(false);
     }
   if(InpAtrBaselineBars<10 || InpAtrBaselineBars>5000)
     {
      error="atr_baseline_bars_must_be_between_10_and_5000";
      return(false);
     }
   if(!SimValidatePercent(InpMaxDailyLossPct,error) ||
      !SimValidatePercent(InpMaxDrawdownPct,error))
     {
      error="daily_or_drawdown_lock_percent_invalid";
      return(false);
     }
   if(InpMaxConsecutiveLosses<0)
     {
      error="max_consecutive_losses_must_be_non_negative";
      return(false);
     }
   if(InpSlMode==IR_SL_FIXED && InpInitialSlPoints<=0)
     {
      error="initial_sl_points_must_be_positive";
      return(false);
     }
   if(InpSlMode==IR_SL_ATR &&
      (!SimIsFinite(InpSlAtrMultiplier) || InpSlAtrMultiplier<=0.0))
     {
      error="sl_atr_multiplier_must_be_positive";
      return(false);
     }
   if(InpMinStopPoints<=0 || InpMaxStopPoints<InpMinStopPoints)
     {
      error="stop_band_invalid_max_must_cover_min";
      return(false);
     }
   if(!SimIsFinite(InpTrailStartPts) || InpTrailStartPts<=0.0)
     {
      error="trail_start_points_must_be_positive";
      return(false);
     }
   if(InpTrailMode==IR_TRAIL_FIXED &&
      (!SimIsFinite(InpTrailDistancePts) || InpTrailDistancePts<=0.0))
     {
      error="trail_distance_points_must_be_positive";
      return(false);
     }
   if(!SimIsFinite(InpTrailStepPts) || InpTrailStepPts<=0.0)
     {
      error="trail_step_points_must_be_positive";
      return(false);
     }
   if(InpTrailMode==IR_TRAIL_ATR &&
      (!SimIsFinite(InpTrailAtrMultiplier) || InpTrailAtrMultiplier<=0.0))
     {
      error="trail_atr_multiplier_must_be_positive";
      return(false);
     }
   if(!SimIsFinite(InpBreakEvenTriggerR) || InpBreakEvenTriggerR<0.0)
     {
      error="break_even_trigger_r_must_be_non_negative";
      return(false);
     }
   if(InpBreakEvenBufferPts<0)
     {
      error="break_even_buffer_points_must_be_non_negative";
      return(false);
     }
   if(InpSafetyTpPoints<InpMinStopPoints)
     {
      error="safety_tp_points_must_be_at_least_min_stop";
      return(false);
     }
   if(InpEnableLog && StringLen(InpLogFile)==0)
     {
      error="log_file_must_not_be_empty";
      return(false);
     }
   if(InpPersistState && StringLen(InpStateFile)==0)
     {
      error="state_file_must_not_be_empty";
      return(false);
     }
   return(true);
  }

string BuildConfigHash(void)
  {
   string text=SimFormatFingerprintPartText("ea","InfiniteRunnerXAUV2DemoEA")+
               SimFormatFingerprintPartInt("ea.version",200)+
               SimFormatFingerprintPartInt("ea.execution_enabled",
                                           (InpEnableExecution ? 1 : 0))+
               SimFormatFingerprintPartInt("ea.magic",(int)InpMagicNumber)+
               SimFormatFingerprintPartInt("ea.deviation",InpMaxSlippagePoints)+
               SimFormatFingerprintPartInt("dir.mode",(int)InpDirectionMode)+
               SimFormatFingerprintPartInt("dir.h1_tf",(int)InpH1TF)+
               SimFormatFingerprintPartInt("dir.m15_tf",(int)InpM15TF)+
               SimFormatFingerprintPartInt("dir.entry_tf",(int)InpEntryTF)+
               SimFormatFingerprintPartInt("dir.ema_fast",InpEmaFast)+
               SimFormatFingerprintPartInt("dir.ema_slow",InpEmaSlow)+
               SimFormatFingerprintPartInt("dir.slope_bars",InpSlopeBars)+
               SimFormatFingerprintPartInt("dir.slow_tol_points",
                                           InpSlowSlopeTolPoints)+
               SimFormatFingerprintPartInt("dir.pullback_tol_points",
                                           InpPullbackTolPoints)+
               SimFormatFingerprintPartInt("entry.max_positions",InpMaxPositions)+
               SimFormatFingerprintPartInt("entry.cooldown_minutes",
                                           InpCooldownMinutes)+
               SimFormatFingerprintPartInt("entry.min_bars",InpMinBarsBetweenEntries)+
               SimFormatFingerprintPartInt("entry.max_trades_day",InpMaxTradesPerDay)+
               SimFormatFingerprintPartInt("risk.lot_mode",(int)InpLotMode)+
               SimFormatFingerprintPart("risk.lots",InpLots,4)+
               SimFormatFingerprintPart("risk.percent",InpRiskPercent,4)+
               SimFormatFingerprintPart("risk.max_lots",InpMaxLots,4)+
               SimFormatFingerprintPartInt("risk.max_spread_points",
                                           InpMaxSpreadPoints)+
               SimFormatFingerprintPart("risk.spread_atr_ratio",
                                        InpMaxSpreadAtrRatio,4)+
               SimFormatFingerprintPart("risk.abnormal_atr_ratio",
                                        InpAbnormalAtrRatio,4)+
               SimFormatFingerprintPartInt("risk.atr_period",InpAtrPeriod)+
               SimFormatFingerprintPartInt("risk.atr_baseline_bars",
                                           InpAtrBaselineBars)+
               SimFormatFingerprintPart("risk.max_daily_loss_pct",
                                        InpMaxDailyLossPct,4)+
               SimFormatFingerprintPart("risk.max_drawdown_pct",
                                        InpMaxDrawdownPct,4)+
               SimFormatFingerprintPartInt("risk.max_consecutive_losses",
                                           InpMaxConsecutiveLosses)+
               SimFormatFingerprintPartInt("risk.halt_on_breach",
                                           (InpHaltOnBreach ? 1 : 0))+
               SimFormatFingerprintPartInt("sl.mode",(int)InpSlMode)+
               SimFormatFingerprintPartInt("sl.fixed_points",InpInitialSlPoints)+
               SimFormatFingerprintPart("sl.atr_multiplier",InpSlAtrMultiplier,4)+
               SimFormatFingerprintPartInt("sl.min_stop_points",InpMinStopPoints)+
               SimFormatFingerprintPartInt("sl.max_stop_points",InpMaxStopPoints)+
               SimFormatFingerprintPartInt("trail.mode",(int)InpTrailMode)+
               SimFormatFingerprintPartInt("trail.start_points",InpTrailStartPts)+
               SimFormatFingerprintPartInt("trail.distance_points",
                                           InpTrailDistancePts)+
               SimFormatFingerprintPartInt("trail.step_points",InpTrailStepPts)+
               SimFormatFingerprintPart("trail.atr_multiplier",
                                        InpTrailAtrMultiplier,4)+
               SimFormatFingerprintPart("trail.break_even_trigger_r",
                                        InpBreakEvenTriggerR,4)+
               SimFormatFingerprintPartInt("trail.break_even_buffer",
                                           InpBreakEvenBufferPts)+
               SimFormatFingerprintPartInt("trail.safety_tp_points",
                                           InpSafetyTpPoints);
   return(SimHashString(text));
  }

//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
void LogEvent(const string event_name,const bool is_buy,const double price,
              const double volume,const double entry,const double sl,
              const double tp,const string reason)
  {
   if(!g_logger.IsOpen())
      return;

   SimLogRecord record;
   SimClearLogRecord(record);
   record.logged_at=TimeCurrent();
   record.bar_time=(g_last_signal_bar>0 ? g_last_signal_bar : iTime(_Symbol,InpEntryTF,0));
   record.ea="InfiniteRunnerXAUV2DemoEA";
   record.version="2.00";
   record.config_hash=g_config_hash;
   record.symbol=_Symbol;
   record.timeframe=g_timeframe_text;
   record.event=event_name;
   record.side=(is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL);
   record.price=price;
   record.volume=volume;
   record.entry=entry;
   record.sl=sl;
   record.tp=tp;
   record.exposure=(g_have_pos ? g_pos_volume : 0.0);
   record.equity=g_equity;
   record.drawdown_pct=DrawdownPct();
   record.reason=reason;

   string error="";
   if(!g_logger.Write(record,error))
      PrintFormat("LAB|ERROR|ir_v2|log_write_failed|%s",error);
  }

//+------------------------------------------------------------------+
//| Account / day tracking                                           |
//+------------------------------------------------------------------+
double AccountEquity(void)
  {
   return(AccountInfoDouble(ACCOUNT_EQUITY));
  }

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
   g_equity=AccountEquity();
   if(g_equity>g_peak_equity)
      g_peak_equity=g_equity;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(),dt);
   const long key=(long)dt.year*10000+(long)dt.mon*100+(long)dt.day;
   if(key!=g_day_key)
     {
      g_day_key=key;
      g_day_start_equity=g_equity;
      g_trades_today=0;
      g_exits_today=0;
      if(InpDebug)
         PrintFormat("LAB|DEBUG|ir_v2|day_rollover|key=%d",key);
     }
  }

void Halt(const string reason)
  {
   if(g_halted)
      return;
   g_halted=true;
   g_halt_reason=reason;
   PrintFormat("LAB|WARN|ir_v2|halted|reason=%s",reason);
   LogEvent("HALT",true,0.0,0.0,0.0,0.0,0.0,StringFormat("reason=%s",reason));
  }

//--- Persisted drawdown lock: never resets by itself, only via the manual
//--- reset input (which is actioned once in OnInit with a journal note).
void CheckDrawdownLock(void)
  {
   if(!g_dd_locked && InpMaxDrawdownPct>0.0 && DrawdownPct()>=InpMaxDrawdownPct)
     {
      g_dd_locked=true;
      SaveState();
      Halt(StringFormat("max_drawdown_reached|dd=%.2f%%",DrawdownPct()));
     }
  }

//+------------------------------------------------------------------+
//| State persistence                                                |
//+------------------------------------------------------------------+
void SaveState(void)
  {
   if(!InpPersistState)
      return;
   const int handle=FileOpen(InpStateFile,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("LAB|ERROR|ir_v2|state_write_failed|error=%d",GetLastError());
      return;
     }
   FileWriteString(handle,"state_version="+IntegerToString(IR_STATE_VERSION)+"\r\n");
   FileWriteString(handle,"magic="+IntegerToString(InpMagicNumber)+"\r\n");
   FileWriteString(handle,"saved_at="+TimeToString(TimeCurrent())+"\r\n");
   FileWriteString(handle,StringFormat("peak_equity=%.8f"+"\r\n",g_peak_equity));
   FileWriteString(handle,StringFormat("day_key=%d"+"\r\n",g_day_key));
   FileWriteString(handle,StringFormat("day_start_equity=%.8f"+"\r\n",
                                       g_day_start_equity));
   FileWriteString(handle,"dd_locked="+(g_dd_locked ? "1" : "0")+"\r\n");
   FileWriteString(handle,"streak_losses="+IntegerToString(g_streak_losses)+"\r\n");
   FileWriteString(handle,"cooldown_until="+IntegerToString((int)g_cooldown_until)+"\r\n");
   FileWriteString(handle,"trades_today="+IntegerToString(g_trades_today)+"\r\n");
   FileWriteString(handle,"last_signal_bar="+IntegerToString((int)g_last_signal_bar)+"\r\n");
   FileWriteString(handle,"last_entry_bar="+IntegerToString((int)g_last_entry_bar)+"\r\n");
   FileWriteString(handle,"pos_ticket="+IntegerToString((int)g_pos_ticket)+"\r\n");
   FileWriteString(handle,"pos_is_buy="+(g_pos_is_buy ? "1" : "0")+"\r\n");
   FileWriteString(handle,StringFormat("pos_entry=%.8f"+"\r\n",g_pos_entry));
   FileWriteString(handle,StringFormat("pos_volume=%.8f"+"\r\n",g_pos_volume));
   FileWriteString(handle,StringFormat("pos_initial_sl=%.8f"+"\r\n",g_pos_initial_sl));
   FileWriteString(handle,StringFormat("pos_initial_r=%.8f"+"\r\n",g_pos_initial_r));
   FileWriteString(handle,"pos_open_time="+IntegerToString((int)g_pos_open_time)+"\r\n");
   FileWriteString(handle,"be_applied="+(g_be_applied ? "1" : "0")+"\r\n");
   FileClose(handle);
  }

//--- Reads key=value lines. Returns false when the file is missing or the
//--- header does not match; the caller then decides fail-safe handling.
bool ReadStateFile(bool &restored)
  {
   restored=false;
   if(!FileIsExist(InpStateFile))
      return(false);

   const int handle=FileOpen(InpStateFile,FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle==INVALID_HANDLE)
      return(false);

   bool version_ok=false;
   bool magic_ok=false;
   double peak=0.0,day_start=0.0;
   long day_key=0;
   bool dd_locked=false;
   int streak=0;
   datetime cooldown=0;
   int trades_today=0;
   datetime last_signal=0,last_entry=0;
   ulong pos_ticket=0;
   bool pos_is_buy=true;
   double pos_entry=0.0,pos_volume=0.0,pos_initial_sl=0.0,pos_initial_r=0.0;
   datetime pos_open_time=0;
   bool be_applied=false;

   while(!FileIsEnding(handle))
     {
      const string line=FileReadString(handle);
      const int eq=StringFind(line,"=");
      if(eq<=0)
         continue;
      const string key=StringSubstr(line,0,eq);
      const string value=StringSubstr(line,eq+1);
      if(key=="state_version")
         version_ok=(StringToInteger(value)==IR_STATE_VERSION);
      else if(key=="magic")
         magic_ok=(StringToInteger(value)==InpMagicNumber);
      else if(key=="peak_equity")
         peak=StringToDouble(value);
      else if(key=="day_key")
         day_key=StringToInteger(value);
      else if(key=="day_start_equity")
         day_start=StringToDouble(value);
      else if(key=="dd_locked")
         dd_locked=(value=="1");
      else if(key=="streak_losses")
         streak=(int)StringToInteger(value);
      else if(key=="cooldown_until")
         cooldown=(datetime)StringToInteger(value);
      else if(key=="trades_today")
         trades_today=(int)StringToInteger(value);
      else if(key=="last_signal_bar")
         last_signal=(datetime)StringToInteger(value);
      else if(key=="last_entry_bar")
         last_entry=(datetime)StringToInteger(value);
      else if(key=="pos_ticket")
         pos_ticket=(ulong)StringToInteger(value);
      else if(key=="pos_is_buy")
         pos_is_buy=(value=="1");
      else if(key=="pos_entry")
         pos_entry=StringToDouble(value);
      else if(key=="pos_volume")
         pos_volume=StringToDouble(value);
      else if(key=="pos_initial_sl")
         pos_initial_sl=StringToDouble(value);
      else if(key=="pos_initial_r")
         pos_initial_r=StringToDouble(value);
      else if(key=="pos_open_time")
         pos_open_time=(datetime)StringToInteger(value);
      else if(key=="be_applied")
         be_applied=(value=="1");
     }
   FileClose(handle);

   if(!version_ok || !magic_ok)
      return(false);
   if(peak>0.0)
      g_peak_equity=peak;
   g_day_key=day_key;
   if(day_start>0.0)
      g_day_start_equity=day_start;
   g_dd_locked=dd_locked;
   if(streak>0)
      g_streak_losses=streak;
   g_cooldown_until=cooldown;
   g_trades_today=trades_today;
   g_last_signal_bar=last_signal;
   g_last_entry_bar=last_entry;
   g_pos_ticket=pos_ticket;
   g_pos_is_buy=pos_is_buy;
   g_pos_entry=pos_entry;
   g_pos_volume=pos_volume;
   g_pos_initial_sl=pos_initial_sl;
   g_pos_initial_r=pos_initial_r;
   g_pos_open_time=pos_open_time;
   g_be_applied=be_applied;
   g_have_pos=(pos_ticket>0);
   restored=true;
   return(true);
  }

//+------------------------------------------------------------------+
//| Market data                                                      |
//+------------------------------------------------------------------+
bool CopySeries(const int handle,const int count,double &values[],
                const string what,string &reason)
  {
   ArraySetAsSeries(values,true);
   ArrayResize(values,0);
   if(handle==INVALID_HANDLE)
     {
      reason="handle_invalid|"+what;
      return(false);
     }
   if(CopyBuffer(handle,0,1,count,values)!=count)
     {
      reason="copy_failed|"+what;
      return(false);
     }
   return(true);
  }

double MeanSeries(const double &values[],const int count)
  {
   if(ArraySize(values)<count || count<=0)
      return(0.0);
   double total=0.0;
   for(int i=0; i<count; i++)
     {
      if(!(values[i]>0.0))
         return(0.0);
      total+=values[i];
     }
   return(total/count);
  }

//--- Refreshes EMA/ATR snapshots from CLOSED bars only (shift 1 and later).
bool RefreshMarketData(string &reason)
  {
   const int need=InpSlopeBars+1;

   double e_fast[],e_slow[];
   if(!CopySeries(g_ema_e_fast,2,e_fast,"ema_entry_fast",reason) ||
      !CopySeries(g_ema_e_slow,2,e_slow,"ema_entry_slow",reason))
      return(false);
   g_m5_fast[0]=e_fast[0];
   g_m5_fast[1]=e_fast[1];
   g_m5_slow[0]=e_slow[0];
   g_m5_slow[1]=e_slow[1];

   double atr_window[];
   if(!CopySeries(g_atr_handle,1,atr_window,"atr_last",reason))
      return(false);
   g_atr_last=atr_window[0];
   if(!(g_atr_last>0.0))
     {
      reason="atr_invalid";
      return(false);
     }

   if(InpAbnormalAtrRatio>0.0 || InpMaxSpreadAtrRatio>0.0)
     {
      double baseline[];
      if(!CopySeries(g_atr_handle,InpAtrBaselineBars,baseline,"atr_baseline",reason))
         return(false);
      g_atr_baseline=MeanSeries(baseline,InpAtrBaselineBars);
     }
   else
      g_atr_baseline=0.0;

   if(InpDirectionMode==IR_DIR_EMA_MTF)
     {
      double h1_fast[],h1_slow[],m15_fast[],m15_slow[];
      if(!CopySeries(g_ema_h1_fast,need,h1_fast,"ema_h1_fast",reason) ||
         !CopySeries(g_ema_h1_slow,need,h1_slow,"ema_h1_slow",reason) ||
         !CopySeries(g_ema_m15_fast,need,m15_fast,"ema_m15_fast",reason) ||
         !CopySeries(g_ema_m15_slow,need,m15_slow,"ema_m15_slow",reason))
         return(false);
      ArrayCopy(g_h1_fast,h1_fast);
      ArrayCopy(g_h1_slow,h1_slow);
      ArrayCopy(g_m15_fast,m15_fast);
      ArrayCopy(g_m15_slow,m15_slow);

      string h1_bull_reason="", h1_bear_reason="";
      const bool h1_b=IRBullishAlign(g_h1_fast,g_h1_slow,InpSlopeBars,g_point,
                                     InpSlowSlopeTolPoints,h1_bull_reason);
      const bool h1_s=IRBearishAlign(g_h1_fast,g_h1_slow,InpSlopeBars,g_point,
                                     InpSlowSlopeTolPoints,h1_bear_reason);
      g_h1_bias_text=(h1_b ? "BULL" : (h1_s ? "BEAR" : h1_bull_reason));

      string m15_bull_reason="", m15_bear_reason="";
      const bool m15_b=IRBullishAlign(g_m15_fast,g_m15_slow,InpSlopeBars,g_point,
                                      InpSlowSlopeTolPoints,m15_bull_reason);
      const bool m15_s=IRBearishAlign(g_m15_fast,g_m15_slow,InpSlopeBars,g_point,
                                      InpSlowSlopeTolPoints,m15_bear_reason);
      g_m15_bias_text=(m15_b ? "BULL" : (m15_s ? "BEAR" : m15_bull_reason));
     }
   else
     {
      g_h1_bias_text="legacy_mode";
      g_m15_bias_text="legacy_mode";
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Entry gating                                                     |
//+------------------------------------------------------------------+
bool ForeignPositionOnSymbol(void)
  {
   const int total=PositionsTotal();
   for(int i=0; i<total; i++)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber)
         return(true);
     }
   return(false);
  }

bool CooldownActive(const datetime now)
  {
   return(InpCooldownMinutes>0 && now<g_cooldown_until);
  }

bool EntryThrottlesOk(const datetime bar_time,string &block_reason)
  {
   const datetime now=TimeCurrent();

   if(InpMaxConsecutiveLosses>0 && g_streak_losses>=InpMaxConsecutiveLosses)
     {
      block_reason=StringFormat("loss_streak|count=%d|limit=%d",
                                g_streak_losses,InpMaxConsecutiveLosses);
      return(false);
     }
   if(CooldownActive(now))
     {
      block_reason=StringFormat("cooldown|until=%s",
                                TimeToString(g_cooldown_until));
      return(false);
     }
   if(g_trades_today>=InpMaxTradesPerDay)
     {
      block_reason=StringFormat("max_trades_day|count=%d",
                                g_trades_today);
      return(false);
     }
   if(InpMinBarsBetweenEntries>0 &&
      g_bars_since_last_entry<InpMinBarsBetweenEntries)
     {
      block_reason=StringFormat("min_bars_between|since=%d|required=%d",
                                g_bars_since_last_entry,
                                InpMinBarsBetweenEntries);
      return(false);
     }
   if(g_last_entry_bar==bar_time)
     {
      block_reason="same_bar_reentry_block";
      return(false);
     }
   return(true);
  }

SimRiskDecision EvaluateRisk(const double volume_to_add,
                             const datetime bar_time)
  {
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   SimRiskContext ctx;
   ctx.spread_points=(bid>0.0 && ask>0.0 ? (ask-bid)/g_point : 0.0);
   ctx.price_valid=(bid>0.0 && ask>0.0);
   ctx.open_positions=(g_have_pos ? 1 : 0);
   ctx.grid_levels=0;
   ctx.dca_adds=0;
   ctx.exposure=(g_have_pos ? g_pos_volume : 0.0);
   ctx.volume_to_add=volume_to_add;
   ctx.equity=g_equity;
   ctx.day_start_equity=g_day_start_equity;
   ctx.peak_equity=g_peak_equity;
   ctx.bar_time=bar_time;
   return(g_risk.Evaluate(ctx));
  }

//+------------------------------------------------------------------+
//| Sizing                                                           |
//+------------------------------------------------------------------+
double BrokerStopPoints(void)
  {
   return((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL));
  }

//--- Initial stop distance in points for the configured mode.
double InitialStopPoints(const double atr_last,string &reason)
  {
   reason="";
   if(InpSlMode==IR_SL_FIXED)
     {
      reason="mode=fixed";
      return((double)InpInitialSlPoints);
     }
   if(!(atr_last>0.0) || !(g_point>0.0))
     {
      reason="atr_data_missing";
      return(0.0);
     }
   const double points=InpSlAtrMultiplier*atr_last/g_point;
   reason=StringFormat("mode=atr|atr=%.8f|points=%.1f",atr_last,points);
   return(points);
  }

//--- Volume from the risk budget at the candidate stop, or the fixed lot.
bool SizePosition(const bool is_buy,const double entry,const double stop_points,
                  const double risk_money,const double atr_last,
                  double &volume,string &reason)
  {
   const double volume_min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   const double volume_max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   const double volume_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   const double cap=MathMin(InpMaxLots,volume_max);
   volume=0.0;

   if(!(volume_min>0.0) || !(volume_step>0.0) || !(cap>=volume_min))
     {
      reason="volume_constraints_invalid";
      return(false);
     }

   if(InpLotMode==IR_LOT_FIXED)
     {
      const double normalized=ExecNormalizeVolume(InpLots,volume_min,volume_max,
                                                  volume_step);
      if(!(normalized>0.0) || normalized>cap)
        {
         reason=StringFormat("fixed_lot_out_of_band|requested=%.4f|cap=%.4f",
                             InpLots,cap);
         return(false);
        }
      volume=normalized;
      reason=StringFormat("lot_mode=fixed|lots=%.4f|cap=%.4f",volume,cap);
      return(true);
     }

   //--- RISK_PERCENT: loss of one lot from entry to the initial stop via
   //--- OrderCalcProfit; floor to the step; re-test the final risk.
   const double sl_price=IRNormalizePrice(
      is_buy ? entry-stop_points*g_point : entry+stop_points*g_point,
      g_tick_size,g_digits);
   double loss_per_lot=0.0;
   if(!ExecCalcProfit(is_buy,1.0,entry,sl_price,loss_per_lot))
     {
      reason="order_calc_profit_failed";
      return(false);
     }
   loss_per_lot=MathAbs(loss_per_lot);
   if(!(loss_per_lot>0.0))
     {
      reason="loss_per_lot_not_positive";
      return(false);
     }

   const double raw=risk_money/loss_per_lot;
   const double floored=MathFloor(raw/volume_step)*volume_step;
   if(!(floored>=volume_min))
     {
      const double min_loss=loss_per_lot*volume_min;
      reason=StringFormat("min_lot_over_budget|min_lot_loss=%.2f|budget=%.2f",
                          min_loss,risk_money);
      return(false);
     }

   const double final_volume=MathMin(floored,cap);
   double final_loss=0.0;
   if(!ExecCalcProfit(is_buy,final_volume,entry,sl_price,final_loss))
     {
      reason="order_calc_profit_failed_final";
      return(false);
     }
   if(MathAbs(final_loss)>risk_money+1e-9)
     {
      reason=StringFormat("final_risk_over_budget|loss=%.2f|budget=%.2f",
                          MathAbs(final_loss),risk_money);
      return(false);
     }
   volume=final_volume;
   reason=StringFormat("lot_mode=risk|lots=%.4f|loss=%.2f|budget=%.2f",
                       volume,MathAbs(final_loss),risk_money);
   return(true);
  }

//+------------------------------------------------------------------+
//| Open / close                                                     |
//+------------------------------------------------------------------+
bool OpenEntry(const bool is_buy,const double volume,const double sl_price,
               const double tp_price,const string decision_reason)
  {
   if(!InpEnableExecution)
     {
      const double reference=(is_buy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol,SYMBOL_BID));
      LogEvent("DRY_RUN",is_buy,reference,volume,reference,sl_price,tp_price,
               StringFormat("would_open|%s",decision_reason));
      return(false);
     }

   ExecFillResult fill;
   if(!ExecOpenMarket(is_buy,volume,sl_price,tp_price,InpMaxSlippagePoints,
                      InpMagicNumber,"IRV2",fill))
     {
      LogEvent("ERROR",is_buy,0.0,volume,0.0,sl_price,tp_price,
               StringFormat("open_failed|%s",fill.message));
      return(false);
     }

   g_entries++;
   g_trades_today++;
   g_last_entry_bar=iTime(_Symbol,InpEntryTF,0);
   g_bars_since_last_entry=0;
   g_have_pos=true;
   g_pos_is_buy=is_buy;
   g_pos_ticket=fill.order;
   g_pos_entry=fill.price;
   g_pos_volume=fill.volume;
   g_pos_initial_sl=sl_price;
   g_pos_initial_r=IRStopDistance(is_buy,fill.price,sl_price,g_point);
   g_pos_open_time=TimeCurrent();
   g_be_applied=false;
   SaveState();

   LogEvent("ENTRY",is_buy,fill.price,fill.volume,fill.price,sl_price,tp_price,
            StringFormat("%s|ticket=%d|r=%.8f|%s",
                         decision_reason,(int)fill.order,g_pos_initial_r,
                         fill.message));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|ir_v2|entry|price=%.8f|volume=%.4f|sl=%.8f|"
                  "tp=%.8f|r=%.8f",
                  fill.price,fill.volume,sl_price,tp_price,g_pos_initial_r);
   return(true);
  }

//--- Finalizes a vanished position from the stored context and deal history.
void FinalizeClosedPosition(void)
  {
   double pnl=0.0;
   int deals=0;
   bool have_pnl=false;
   if(g_pos_ticket>0 && g_pos_open_time>0)
     {
      if(ExecClosedPnl(g_pos_ticket,g_pos_open_time,pnl,deals))
         have_pnl=true;
      else if(ExecClosedPnl(g_pos_ticket,g_pos_open_time-3600,pnl,deals))
         have_pnl=true;
     }

   if(have_pnl)
     {
      g_realized_pnl+=pnl;
      if(pnl<0.0)
        {
         g_losses++;
         g_streak_losses++;
        }
      else if(pnl>0.0)
        {
         g_wins++;
         g_streak_losses=0;
        }
     }

   g_exits++;
   g_exits_today++;
   if(InpCooldownMinutes>0)
     {
      g_cooldown_until=TimeCurrent()+InpCooldownMinutes*60;
      g_bars_since_last_entry=1000000;
     }
   LogEvent("EXIT",g_pos_is_buy,0.0,g_pos_volume,g_pos_entry,
            g_pos_initial_sl,0.0,
            StringFormat("closed|%s|pnl=%.2f|streak=%d|cooldown_until=%s",
                         (have_pnl ? "history" : "pnl_unknown"),pnl,
                         g_streak_losses,
                         TimeToString(g_cooldown_until)));
   PrintFormat("LAB|INFO|ir_v2|exit|pnl=%.2f|streak=%d|entries=%d",
               pnl,g_streak_losses,g_entries);

   //--- Position is gone: reset context only. State file keeps the risk
   //--- ledger values (peak, dd lock, streak, cooldown) for restart safety.
   g_have_pos=false;
   g_pos_ticket=0;
   g_pos_entry=0.0;
   g_pos_volume=0.0;
   g_pos_initial_sl=0.0;
   g_pos_initial_r=0.0;
   g_pos_open_time=0;
   g_be_applied=false;
   g_sl_missing=false;
   SaveState();
  }

//+------------------------------------------------------------------+
//| Trailing management                                              |
//+------------------------------------------------------------------+
//--- Emergency policy for a position without SL (tested recovery rule):
//--- once per entry-TF bar, apply the worst protective stop inside the
//--- configured band computed from the current reference price, then keep
//--- entries blocked until the position closes.
bool EmergencyProtect(void)
  {
   const datetime bar=iTime(_Symbol,InpEntryTF,0);
   if(g_emergency_bar==bar)
      return(false);
   g_emergency_bar=bar;

   const double reference=(g_pos_is_buy ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                                       : SymbolInfoDouble(_Symbol,SYMBOL_ASK));
   if(!(reference>0.0))
      return(false);

   const double points=MathMin(InpMaxStopPoints,InpSafetyTpPoints);
   const double sl=IRNormalizePrice(
      g_pos_is_buy ? reference-points*g_point : reference+points*g_point,
      g_tick_size,g_digits);
   string reason="";
   if(!IRCandidateStopsValid(g_pos_is_buy,false,reference,sl,g_point,
                             BrokerStopPoints(),InpMinStopPoints,
                             InpMaxStopPoints,reason))
     {
      LogEvent("ERROR",g_pos_is_buy,reference,g_pos_volume,g_pos_entry,sl,0.0,
               StringFormat("emergency_sl_invalid|%s",reason));
      return(false);
     }

   LogEvent("EMERGENCY_SL",g_pos_is_buy,reference,g_pos_volume,g_pos_entry,
            sl,0.0,"position_without_sl|applying_protection");
   if(!InpEnableExecution)
      return(false);

   ExecFillResult fill;
   if(ExecModifyStops(g_pos_ticket,sl,PositionGetDouble(POSITION_TP),fill))
     {
      g_sl_updates++;
      PrintFormat("LAB|WARN|ir_v2|emergency_sl_applied|sl=%.8f",sl);
     }
   else
      LogEvent("ERROR",g_pos_is_buy,reference,g_pos_volume,g_pos_entry,sl,0.0,
               StringFormat("emergency_sl_failed|%s",fill.message));
   return(true);
  }

void ManageTrailing(void)
  {
   if(!g_have_pos)
      return;
   if(!PositionSelectByTicket(g_pos_ticket))
     {
      FinalizeClosedPosition();
      return;
     }

   const double current_sl=PositionGetDouble(POSITION_SL);
   const double current_tp=PositionGetDouble(POSITION_TP);
   const double reference=(g_pos_is_buy ? SymbolInfoDouble(_Symbol,SYMBOL_BID)
                                       : SymbolInfoDouble(_Symbol,SYMBOL_ASK));

   //--- A position without SL is an unprotected runner: safe mode + fixed
   //--- recovery policy (rate limited, documented in the guide).
   if(!(current_sl>0.0))
     {
      if(!g_sl_missing)
        {
         g_sl_missing=true;
         LogEvent("ERROR",g_pos_is_buy,reference,g_pos_volume,g_pos_entry,
                  0.0,current_tp,"sl_missing|entries_blocked_until_closed");
        }
      EmergencyProtect();
      return;
     }
   g_sl_missing=false;

   const double profit_units=(g_pos_is_buy ? reference-g_pos_entry
                                           : g_pos_entry-reference);

   //--- 1. Break-even from the STORED initial R (never from a trailing SL).
   string candidate_reason="";
   double candidate=0.0;
   bool is_be=false;
   if(!g_be_applied && g_pos_initial_r>0.0 && InpBreakEvenTriggerR>0.0)
     {
      candidate=IRBreakEvenCandidate(g_pos_is_buy,g_pos_entry,g_pos_initial_r,
                                     InpBreakEvenTriggerR,reference,
                                     InpBreakEvenBufferPts,g_point);
      if(candidate>0.0)
        {
         candidate_reason="break_even";
         is_be=true;
        }
     }

   //--- 1b. Step Trailing candidate (Nhat tien le / Tiered Locks)
   if(!(candidate>0.0) && InpEnableStepTrailing && profit_units>0.0)
     {
      string step_reason="";
      candidate=IRStepTrailCandidate(g_pos_is_buy,g_pos_entry,reference,g_point,
                                     InpStep1_TriggerPoints,InpStep1_LockPoints,
                                     InpStep2_TriggerPoints,InpStep2_LockPoints,
                                     InpStep3_TriggerPoints,InpStep3_LockPoints,
                                     step_reason);
      if(candidate>0.0)
         candidate_reason=step_reason;
     }

   //--- 2. Trailing candidates. Fixed mode: start after TrailStartPts of
   //---    profit (V1 parity). ATR mode: start after 1R of profit.
   if(!(candidate>0.0) && profit_units>0.0)
     {
      bool start_condition=false;
      if(InpTrailMode==IR_TRAIL_FIXED)
         start_condition=(profit_units>=InpTrailStartPts*g_point);
      else
        {
         const double atr_start=(g_pos_initial_r>0.0 ? g_pos_initial_r
                                : InpTrailStartPts*g_point);
         start_condition=(profit_units>=atr_start);
        }

      if(start_condition)
        {
         if(InpTrailMode==IR_TRAIL_FIXED)
            candidate=IRFixedTrailCandidate(g_pos_is_buy,reference,
                                            InpTrailDistancePts,g_point);
         else
            candidate=IRAtrTrailCandidate(g_pos_is_buy,reference,g_atr_last,
                                          InpTrailAtrMultiplier);
         if(candidate>0.0)
            candidate_reason=StringFormat("trail_%s",
               (InpTrailMode==IR_TRAIL_FIXED ? "fixed" : "atr"));
        }
     }

   if(!(candidate>0.0))
      return;

   //--- Tick-size round then monotonic gate: BUY SL may only rise, SELL SL
   //--- may only fall, by at least the step. Refused otherwise.
   candidate=IRNormalizePrice(candidate,g_tick_size,g_digits);
   if(!IRMonotonicBetter(g_pos_is_buy,current_sl,candidate,
                         InpTrailStepPts*g_point))
     {
      if(InpDebug)
         PrintFormat("LAB|DEBUG|ir_v2|trail_skip|not_better|cur=%.8f|"
                     "cand=%.8f",current_sl,candidate);
      return;
     }
   if(!(is_be || profit_units>0.0))  // never trail against an open loss
      return;

   string fail_reason="";
   if(!IRCandidateStopsValid(g_pos_is_buy,false,reference,candidate,g_point,
                             BrokerStopPoints(),InpMinStopPoints,
                             InpMaxStopPoints,fail_reason))
     {
      if(InpDebug)
         PrintFormat("LAB|DEBUG|ir_v2|trail_skip|stops_invalid|%s",fail_reason);
      return;
     }
   //--- BE only counts when it really improves protection vs the current SL.
   if(is_be && !IRMonotonicBetter(g_pos_is_buy,current_sl,candidate,0.0))
      return;

   if(!InpEnableExecution)
     {
      if(g_last_signal_bar!=iTime(_Symbol,InpEntryTF,0))
        {
         g_last_signal_bar=iTime(_Symbol,InpEntryTF,0);
         LogEvent("DRY_RUN",g_pos_is_buy,reference,g_pos_volume,g_pos_entry,
                  candidate,current_tp,
                  StringFormat("would_move_sl|%s",candidate_reason));
        }
      return;
     }

   ExecFillResult fill;
   if(!ExecModifyStops(g_pos_ticket,candidate,current_tp,fill))
     {
      //--- Rate limit is implicit: candidate improvement >= step, and no
      //--- state change on failure. Keep the old SL, log the retcode.
      LogEvent("ERROR",g_pos_is_buy,reference,g_pos_volume,g_pos_entry,
               candidate,current_tp,
               StringFormat("sl_modify_failed|%s|%s",candidate_reason,
                            fill.message));
      return;
     }

   g_sl_updates++;
   if(is_be)
      g_be_applied=true;
   LogEvent("SL_UPDATE",g_pos_is_buy,reference,g_pos_volume,g_pos_entry,
            candidate,current_tp,
            StringFormat("%s|old_sl=%.8f|new_sl=%.8f",candidate_reason,
                         current_sl,candidate));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|ir_v2|sl_update|%s|old=%.8f|new=%.8f",
                  candidate_reason,current_sl,candidate);
  }

//+------------------------------------------------------------------+
//| Entry decision on a new EntryTF bar                              |
//+------------------------------------------------------------------+
void ProcessEntryBar(const datetime bar_time,const string data_reason)
  {
   string reason=data_reason;

   if(InpDirectionMode==IR_DIR_LEGACY_EMA)
      IRLegacyDecision(g_m5_fast[0],g_m5_slow[0],g_decision);
   else
      {
       const double close_prev=iClose(_Symbol,InpEntryTF,2);
       const double close_last=iClose(_Symbol,InpEntryTF,1);
       IRMtfDecision(g_h1_fast,g_h1_slow,g_m15_fast,g_m15_slow,
                     close_prev,close_last,
                     g_m5_fast[1],g_m5_fast[0],g_m5_slow[0],
                     InpSlopeBars,g_point,InpSlowSlopeTolPoints,
                     InpPullbackTolPoints,g_decision);
      }
   g_trigger_text=(g_decision.decision==IR_DEC_BUY ||
                   g_decision.decision==IR_DEC_SELL ?
                   (g_decision.is_buy ? "BUY_RECLAIM" : "SELL_RECLAIM") :
                   IRDecisionName(g_decision.decision));

   LogEvent("DECISION",g_decision.is_buy,0.0,0.0,0.0,0.0,0.0,
            StringFormat("%s|%s|h1=%s|m15=%s|atr=%.8f",
                         IRDecisionName(g_decision.decision),
                         g_decision.reason,g_h1_bias_text,g_m15_bias_text,
                         g_atr_last));

   if(g_decision.decision!=IR_DEC_BUY && g_decision.decision!=IR_DEC_SELL)
      return;

   const bool is_buy=g_decision.is_buy;

   //--- Market-context gates first (cheap rejections with reason codes).
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(!(bid>0.0) || !(ask>0.0))
     {
      LogEvent("BLOCKED",is_buy,0.0,0.0,0.0,0.0,0.0,"quotes_invalid");
      g_blocks++;
      return;
     }
   const double spread_points=(ask-bid)/g_point;
   string gate_reason="";
   if(IRSpreadBlocked(spread_points,InpMaxSpreadPoints,g_atr_last,
                      InpMaxSpreadAtrRatio,g_point,gate_reason))
     {
      LogEvent("BLOCKED",is_buy,spread_points,0.0,0.0,0.0,0.0,
               gate_reason+"|decision=SPREAD_BLOCKED");
      g_blocks++;
      return;
     }
   if(IRVolatilityBlocked(g_atr_last,g_atr_baseline,InpAbnormalAtrRatio,
                          gate_reason))
     {
      LogEvent("BLOCKED",is_buy,spread_points,0.0,0.0,0.0,0.0,
               gate_reason+"|decision=VOLATILITY_BLOCKED");
      g_blocks++;
      return;
     }

   //--- Position/foreign/ledger gates. Safe mode (state conflict, missing
   //--- SL, halted lock) hard-blocks new entries.
   if(g_have_pos)
     {
      LogEvent("BLOCKED",is_buy,spread_points,0.0,0.0,0.0,0.0,
               "position_open");
      g_blocks++;
      return;
     }
   if(g_halted || g_dd_locked)
     {
      LogEvent("BLOCKED",is_buy,spread_points,0.0,0.0,0.0,0.0,
               StringFormat("lock_active|halted=%d|dd_locked=%d",
                            (g_halted ? 1 : 0),(g_dd_locked ? 1 : 0)));
      g_blocks++;
      return;
     }
   if(ForeignPositionOnSymbol())
     {
      LogEvent("BLOCKED",is_buy,spread_points,0.0,0.0,0.0,0.0,
               "foreign_position_on_symbol");
      g_blocks++;
      return;
     }
   if(InpMaxConsecutiveLosses>0 && g_streak_losses>=InpMaxConsecutiveLosses)
     {
      //--- Reported through EntryThrottlesOk below as well; keep order clear.
     }
   if(!EntryThrottlesOk(bar_time,reason))
     {
      LogEvent("BLOCKED",is_buy,spread_points,0.0,0.0,0.0,0.0,reason);
      g_blocks++;
      return;
     }

   //--- Initial SL: configured mode, distance band, tick grid, broker level.
   string sl_reason="";
   const double stop_points=InitialStopPoints(g_atr_last,sl_reason);
   if(!(stop_points>0.0))
     {
      LogEvent("BLOCKED",is_buy,spread_points,0.0,0.0,0.0,0.0,
               StringFormat("initial_stop_invalid|%s",sl_reason));
      g_blocks++;
      return;
     }
   const double entry_price=(is_buy ? ask : bid);
   const double sl_raw=(is_buy ? entry_price-stop_points*g_point
                               : entry_price+stop_points*g_point);
   const double sl_price=IRNormalizePrice(sl_raw,g_tick_size,g_digits);
   if(!IRCandidateStopsValid(is_buy,true,entry_price,sl_price,g_point,
                             BrokerStopPoints(),InpMinStopPoints,
                             InpMaxStopPoints,gate_reason))
     {
      LogEvent("BLOCKED",is_buy,entry_price,0.0,entry_price,sl_price,0.0,
               StringFormat("stops_invalid|%s",gate_reason));
      g_blocks++;
      return;
     }
   const double tp_price=IRSafetyTpPrice(is_buy,entry_price,
                                         InpSafetyTpPoints,g_point,g_digits);
   if(!(tp_price>0.0))
     {
      LogEvent("BLOCKED",is_buy,entry_price,0.0,entry_price,sl_price,0.0,
               "safety_tp_invalid");
      g_blocks++;
      return;
     }

   //--- Risk budget + sizing first, then the ledger guard with the REAL
   //--- candidate volume (the guard's exposure check is volume-dependent;
   //--- passing 0.0 here would permanently block every entry as ADR 0006 §4
   //--- documents).
   const double risk_budget=g_equity*InpRiskPercent/100.0;
   double volume=0.0;
   if(!SizePosition(is_buy,entry_price,stop_points,risk_budget,g_atr_last,
                    volume,gate_reason))
     {
      LogEvent("BLOCKED",is_buy,entry_price,0.0,entry_price,sl_price,tp_price,
               gate_reason);
      g_blocks++;
      return;
     }

   const SimRiskDecision decision=EvaluateRisk(volume,bar_time);
   if(!decision.allowed)
     {
      LogEvent("BLOCKED",is_buy,spread_points,0.0,0.0,sl_price,tp_price,
               StringFormat("risk|%s|state=%s",decision.reason,
                            SimRiskStateName(decision.state)));
      g_blocks++;
      if(decision.state==SIM_RISK_HALTED && InpHaltOnBreach)
         Halt(decision.reason);
      return;
     }

   double margin=0.0;
   if(!ExecMarginRequired(is_buy,volume,entry_price,margin))
     {
      LogEvent("BLOCKED",is_buy,entry_price,volume,entry_price,sl_price,
               tp_price,"order_calc_margin_failed");
      g_blocks++;
      return;
     }
   if(margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE)*0.9)
     {
      LogEvent("BLOCKED",is_buy,entry_price,volume,entry_price,sl_price,
               tp_price,
               StringFormat("margin_insufficient|need=%.2f|free=%.2f",margin,
                            AccountInfoDouble(ACCOUNT_MARGIN_FREE)));
      g_blocks++;
      return;
     }

   if(!OpenEntry(is_buy,volume,sl_price,tp_price,g_decision.reason))
     {
      //--- Dry-run path ends here too.
      return;
     }
   g_risk.RecordEntry(bar_time);
   SaveState();
  }

//+------------------------------------------------------------------+
//| Chart panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel(const double bid,const double ask)
  {
   const int spread=(int)((ask-bid)/g_point);
   const string mode=(InpEnableExecution ? "DEMO_EXECUTION" : "DRY_RUN");
   string state="NORMAL";
   if(g_dd_locked)          state="DD_LOCK";
   else if(g_halted)        state="HALTED";
   else if(CooldownActive(TimeCurrent())) state="COOLDOWN";
   else if(g_sl_missing)    state="SAFE_MODE_SL_MISSING";

   string position="none";
   if(g_have_pos)
      position=StringFormat("%s %.4f @ %.5f sl=%.5f r=%.5f",
                            (g_pos_is_buy ? "BUY" : "SELL"),g_pos_volume,
                            g_pos_entry,PositionSelectByTicket(g_pos_ticket)
                            ? PositionGetDouble(POSITION_SL) : g_pos_initial_sl,
                            g_pos_initial_r);

   Comment(StringFormat(
      "InfiniteRunnerXAUV2DemoEA  %s  magic=%d\n"
      "%s %s  spread=%d pts  atr=%.5f (baseline %.5f)\n"
      "dir=%s  H1=%s  M15=%s  trigger=%s\n"
      "risk=%s  dd=%.2f%%  dayLoss=%.2f%%  streak=%d  tradesToday=%d\n"
      "position: %s\n"
      "lastBlock=%s",
      mode,(int)InpMagicNumber,_Symbol,g_timeframe_text,spread,g_atr_last,
      g_atr_baseline,IRDecisionName(g_decision.decision),g_h1_bias_text,
      g_m15_bias_text,g_trigger_text,state,
      DrawdownPct(),DailyLossPct(),g_streak_losses,g_trades_today,
      position,g_decision.reason));
  }

//+------------------------------------------------------------------+
//| MQL5 events                                                      |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   string error="";
   if(!ValidateInputs(error))
     {
      PrintFormat("LAB|ERROR|ir_v2|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   g_digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   g_tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(!SimValidatePoint(g_point,error) || !(g_tick_size>0.0))
     {
      PrintFormat("LAB|ERROR|ir_v2|symbol_data_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   //--- Account isolation: hedging accounts give each magic its own
   //--- position; on netting we refuse to run while a foreign position
   //--- shares the symbol (checked per bar below).
   g_is_hedging=(AccountInfoInteger(ACCOUNT_MARGIN_MODE)==
                 ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);

   //--- Hard demo gate: real/contest accounts are rejected at OnInit.
   ExecAccountState state;
   state.trade_mode=AccountInfoInteger(ACCOUNT_TRADE_MODE);
   state.account_trade_allowed=(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)!=0);
   state.terminal_trade_allowed=(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0);
   //--- MQL_TESTER is 0 in a headless tester run (terminal64 /config:<ini>),
   //--- so the Strategy Tester is recognised by its account name as well.
   state.tester=(MQLInfoInteger(MQL_TESTER)!=0);

   ENUM_EXEC_BLOCK block=EXEC_OK;
   if(!ExecContextAllowed(state,block))
     {
      PrintFormat("LAB|ERROR|ir_v2|context_denied|reason=%s",
                  ExecBlockName(block));
      return(INIT_FAILED);
     }

   if(InpEnableExecution && !ExecSymbolAllowed(_Symbol,InpAllowedSymbols))
     {
      PrintFormat("LAB|ERROR|ir_v2|symbol_denied|symbol=%s",_Symbol);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SimRiskLimits limits=SimRiskLimitsDefault();
   limits.max_spread_points=InpMaxSpreadPoints;
   limits.max_virtual_positions=InpMaxPositions;
   limits.max_grid_levels=0;
   limits.max_dca_adds=0;
   limits.max_virtual_exposure=InpMaxLots;
   limits.max_daily_loss_pct=InpMaxDailyLossPct;
   limits.max_drawdown_pct=InpMaxDrawdownPct;
   limits.cooldown_bars=0;
   limits.require_valid_price=true;
   limits.kill_switch=false;
   //--- ADR 0006 §4: guard-level blocks must NOT escalate to a permanent
   //--- halt. Real equity breaches (daily loss/drawdown/kill) use Halt()
   //--- regardless; ordinary blocks (spread, exposure checks) stay blocks.
   //--- The EA promotes guard halts itself via InpHaltOnBreach.
   limits.halt_on_breach=false;
   if(!g_risk.Init(limits,PeriodSeconds(InpEntryTF),error))
     {
      PrintFormat("LAB|ERROR|ir_v2|risk_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_ema_e_fast=iMA(_Symbol,InpEntryTF,InpEmaFast,0,MODE_EMA,PRICE_CLOSE);
   g_ema_e_slow=iMA(_Symbol,InpEntryTF,InpEmaSlow,0,MODE_EMA,PRICE_CLOSE);
   g_atr_handle=iATR(_Symbol,InpEntryTF,InpAtrPeriod);
   if(g_ema_e_fast==INVALID_HANDLE || g_ema_e_slow==INVALID_HANDLE ||
      g_atr_handle==INVALID_HANDLE)
     {
      PrintFormat("LAB|ERROR|ir_v2|indicator_init_failed|error=%d",GetLastError());
      return(INIT_FAILED);
     }
   if(InpDirectionMode==IR_DIR_EMA_MTF)
     {
      g_ema_h1_fast=iMA(_Symbol,InpH1TF,InpEmaFast,0,MODE_EMA,PRICE_CLOSE);
      g_ema_h1_slow=iMA(_Symbol,InpH1TF,InpEmaSlow,0,MODE_EMA,PRICE_CLOSE);
      g_ema_m15_fast=iMA(_Symbol,InpM15TF,InpEmaFast,0,MODE_EMA,PRICE_CLOSE);
      g_ema_m15_slow=iMA(_Symbol,InpM15TF,InpEmaSlow,0,MODE_EMA,PRICE_CLOSE);
      if(g_ema_h1_fast==INVALID_HANDLE || g_ema_h1_slow==INVALID_HANDLE ||
         g_ema_m15_fast==INVALID_HANDLE || g_ema_m15_slow==INVALID_HANDLE)
        {
         PrintFormat("LAB|ERROR|ir_v2|indicator_init_mtf_failed|error=%d",
                     GetLastError());
         return(INIT_FAILED);
        }
     }

   g_timeframe_text=EnumToString(InpEntryTF);
   g_config_hash=BuildConfigHash();
   IRClearDecision(g_decision);
   //--- Reserve static capacity BEFORE any tick writes into these caches.
   //--- A zero-size dynamic array would raise "array out of range" at the
   //--- first RefreshMarketData call (strategy tester, OnTick).
   const int series_capacity=MathMax(2,InpSlopeBars+1);
   ArrayResize(g_h1_fast,series_capacity);
   ArrayResize(g_h1_slow,series_capacity);
   ArrayResize(g_m15_fast,series_capacity);
   ArrayResize(g_m15_slow,series_capacity);
   ArrayResize(g_m5_fast,2);
   ArrayResize(g_m5_slow,2);
   ArrayInitialize(g_h1_fast,0.0);
   ArrayInitialize(g_h1_slow,0.0);
   ArrayInitialize(g_m15_fast,0.0);
   ArrayInitialize(g_m15_slow,0.0);
   ArrayInitialize(g_m5_fast,0.0);
   ArrayInitialize(g_m5_slow,0.0);
   UpdateAccountState();
   g_day_start_equity=g_equity;

   //--- State restore + reconcile with actual positions (spec §10).
   bool restored=false;
   if(InpPersistState && InpResetStateOnInit)
     {
      FileDelete(InpStateFile);
      PrintFormat("LAB|INFO|ir_v2|state_reset_on_init|file_deleted=%s", InpStateFile);
     }
   const bool state_ok=(InpPersistState && !InpResetStateOnInit ? ReadStateFile(restored) : false);
   if(restored && !state_ok)
     {
      PrintFormat("LAB|ERROR|ir_v2|state_version_or_magic_mismatch|"
                  "entering_safe_mode");
     }

   if(InpManualResetDrawdown)
     {
      if(g_dd_locked)
         PrintFormat("LAB|INFO|ir_v2|manual_reset_drawdown|lock_cleared");
      g_dd_locked=false;
      SaveState();
     }

   //--- Reconcile the stored position context with the real one.
   if(g_have_pos)
     {
      bool adopt_missing=false;
      ExecPositionInfo info;
      const bool found=ExecFindOwnPosition(InpMagicNumber,info);
      if(found)
        {
         if(info.ticket!=g_pos_ticket)
           {
            if(g_pos_ticket>0)
              {
               //--- Ticket drifted (e.g. restart on netting): not conflicting
               //--- in direction/type check below, refuse entries instead.
              }
            if(!info.found || (info.type==POSITION_TYPE_BUY)!=g_pos_is_buy)
              {
               PrintFormat("LAB|ERROR|ir_v2|state_conflict|ticket_mismatch|"
                           "entering_safe_mode");
               g_dd_locked=true;
               SaveState();
               g_have_pos=false;
               adopt_missing=true;
              }
            else
              {
               g_pos_ticket=info.ticket;
              }
          }
         if(!adopt_missing)
           {
            g_have_pos=true;
            g_pos_ticket=info.ticket;
            g_pos_is_buy=(info.type==POSITION_TYPE_BUY);
            g_pos_entry=info.open_price;
            g_pos_volume=info.volume;
            g_pos_open_time=info.open_time;
            if(!(g_pos_initial_r>0.0))
              {
               //--- Restart without stored initial R: BE is disabled, the
               //--- current SL still governs; NEVER recompute initial risk.
               PrintFormat("LAB|WARN|ir_v2|initial_r_unknown_after_restart|"
                           "break_even_disabled");
               g_pos_initial_r=0.0;
              }
           }
        }
      else
        {
         //--- Position was closed while the EA was offline.
         g_have_pos=false;
         FinalizeClosedPosition();
        }
     }
   else
     {
      //--- No stored state: positions may still exist (attached onto an
      //--- existing runner). Adopt any own position so it gets managed.
      ExecPositionInfo position_info_scratch;
      if(ExecFindOwnPosition(InpMagicNumber,position_info_scratch))
        {
         g_have_pos=true;
         g_pos_ticket=position_info_scratch.ticket;
         g_pos_is_buy=(position_info_scratch.type==POSITION_TYPE_BUY);
         g_pos_entry=position_info_scratch.open_price;
         g_pos_volume=position_info_scratch.volume;
         g_pos_open_time=position_info_scratch.open_time;
         g_pos_initial_r=0.0;
         PrintFormat("LAB|WARN|ir_v2|adopted_position_without_state|"
                     "break_even_disabled");
        }
     }

   if(InpEnableLog)
     {
      if(!g_logger.Open(InpLogFile,error))
        {
         PrintFormat("LAB|ERROR|ir_v2|log_open_failed|%s",error);
         return(INIT_FAILED);
        }
     }

   const string mode=(InpEnableExecution ? "DEMO_EXECUTION" : "DRY_RUN");
   LogEvent("INIT",true,0.0,0.0,0.0,0.0,0.0,
            StringFormat("mode=%s|symbol=%s|allowed=%s|magic=%d|hash=%s|"
                         "direction=%s|sl=%s|trail=%s|lot=%s|equity=%.2f",
                         mode,_Symbol,InpAllowedSymbols,(int)InpMagicNumber,
                         g_config_hash,
                         (InpDirectionMode==IR_DIR_EMA_MTF ? "EMA_MTF" : "LEGACY"),
                         (InpSlMode==IR_SL_FIXED ? "fixed" : "atr"),
                         (InpTrailMode==IR_TRAIL_FIXED ? "fixed" : "atr"),
                         (InpLotMode==IR_LOT_FIXED ? "fixed" : "risk"),
                         g_equity));
   PrintFormat("LAB|INFO|ir_v2|initialized|mode=%s|hash=%s|magic=%d|"
               "direction_mode=%d|tester=%d|restored=%d|hedging=%d",
               mode,g_config_hash,(int)InpMagicNumber,(int)InpDirectionMode,
               (int)MQLInfoInteger(MQL_TESTER),(restored ? 1 : 0),
               (g_is_hedging ? 1 : 0));
   if(!InpEnableExecution)
      PrintFormat("LAB|INFO|ir_v2|dry_run|no_orders_are_sent");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   SaveState();
   if(g_logger.IsOpen())
      LogEvent("SUMMARY",(g_decision.is_buy),0.0,0.0,0.0,0.0,0.0,
               StringFormat("entries=%d|exits=%d|wins=%d|losses=%d|"
                            "blocks=%d|sl_updates=%d|realized=%.2f|"
                            "streak=%d|dd_locked=%d|halted=%s|reason=%s|"
                            "execution=%s",
                            g_entries,g_exits,g_wins,g_losses,g_blocks,
                            g_sl_updates,g_realized_pnl,g_streak_losses,
                            (g_dd_locked ? 1 : 0),
                            (g_halted ? "HALTED" : "ACTIVE"),g_halt_reason,
                            (InpEnableExecution ? "DEMO_EXECUTION" : "DRY_RUN")));
   g_logger.Close();
   if(g_ema_e_fast!=INVALID_HANDLE) IndicatorRelease(g_ema_e_fast);
   if(g_ema_e_slow!=INVALID_HANDLE) IndicatorRelease(g_ema_e_slow);
   if(g_ema_h1_fast!=INVALID_HANDLE) IndicatorRelease(g_ema_h1_fast);
   if(g_ema_h1_slow!=INVALID_HANDLE) IndicatorRelease(g_ema_h1_slow);
   if(g_ema_m15_fast!=INVALID_HANDLE) IndicatorRelease(g_ema_m15_fast);
   if(g_ema_m15_slow!=INVALID_HANDLE) IndicatorRelease(g_ema_m15_slow);
   if(g_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   Comment("");
   PrintFormat("LAB|INFO|ir_v2|deinit|reason=%d|entries=%d|wins=%d|losses=%d",
               reason,g_entries,g_wins,g_losses);
  }

void OnTick(void)
  {
   const int warmup=InpAtrPeriod+InpAtrBaselineBars+InpSlopeBars+10;
   if(Bars(_Symbol,InpEntryTF)<warmup)
      return;
   if(InpDirectionMode==IR_DIR_EMA_MTF &&
      Bars(_Symbol,InpH1TF)<InpSlopeBars+3)
      return;

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(!(bid>0.0) || !(ask>0.0))
      return;

   UpdateAccountState();
   CheckDrawdownLock();

   //--- Kill switch: close the runner and stop until restart.
   if(StringLen(ExecTrim(InpKillSwitchFile))>0 &&
      FileIsExist(InpKillSwitchFile))
     {
      if(g_have_pos)
        {
         ExecFillResult kill_fill;
         ExecClearResult(kill_fill);
         if(PositionSelectByTicket(g_pos_ticket) && InpCloseOnKillSwitch &&
            InpEnableExecution)
           {
            if(!ExecClosePosition(g_pos_ticket,g_pos_is_buy,g_pos_volume,
                                  InpMaxSlippagePoints,InpMagicNumber,
                                  "IRV2_KILL",kill_fill))
              {
               LogEvent("ERROR",g_pos_is_buy,0.0,g_pos_volume,g_pos_entry,
                        0.0,0.0,
                        StringFormat("kill_close_failed|%s",
                                     kill_fill.message));
              }
           }
        }
      if(!g_halted || g_halt_reason!="kill_switch_active")
         Halt("kill_switch_active");
      return;
     }

   //--- Position lifecycle first: adopt, exit detect, trailing.
   ExecPositionInfo info;
   const bool found=ExecFindOwnPosition(InpMagicNumber,info);
   if(g_have_pos && !found)
     {
      FinalizeClosedPosition();
     }
   else if(!g_have_pos && found)
     {
      //--- Re-opened externally? Adopt defensively and disable BE.
      g_have_pos=true;
      g_pos_ticket=info.ticket;
      g_pos_is_buy=(info.type==POSITION_TYPE_BUY);
      g_pos_entry=info.open_price;
      g_pos_volume=info.volume;
      g_pos_open_time=info.open_time;
      g_pos_initial_r=0.0;
      LogEvent("ADOPT",g_pos_is_buy,info.open_price,info.volume,
               info.open_price,info.sl,info.tp,"adopted_on_tick");
     }

   if(g_have_pos)
      ManageTrailing();

   //--- Hard equity breach: close and stop.
   if(!g_halted && InpMaxDailyLossPct>0.0 && DailyLossPct()>=InpMaxDailyLossPct)
     {
      Halt(StringFormat("daily_loss_limit_reached|loss=%.2f%%",DailyLossPct()));
     }
   if(g_halted)
     {
      if(g_have_pos && InpEnableExecution && g_halt_reason!="kill_switch_active")
        {
         if(PositionSelectByTicket(g_pos_ticket))
           {
            ExecFillResult close_result;
            if(ExecClosePosition(g_pos_ticket,g_pos_is_buy,g_pos_volume,
                                 InpMaxSlippagePoints,InpMagicNumber,
                                 "IRV2_HALT",close_result))
               LogEvent("HALT_EXIT",g_pos_is_buy,close_result.price,
                        g_pos_volume,g_pos_entry,0.0,0.0,
                        StringFormat("halt_flatten|reason=%s",g_halt_reason));
           }
        }
      UpdatePanel(bid,ask);
      return;
     }

   UpdatePanel(bid,ask);

   //--- Strategy decisions only on a brand-new closed EntryTF bar.
   const datetime bar_time=iTime(_Symbol,InpEntryTF,0);
   const bool new_bar=(bar_time!=g_last_signal_bar);
   if(!new_bar)
      return;
   g_last_signal_bar=bar_time;
   g_bars_since_last_entry++;

   string data_reason="";
   if(!RefreshMarketData(data_reason))
     {
      g_decision.decision=IR_DEC_DATA_NOT_READY;
      g_decision.reason="data|"+data_reason;
      LogEvent("DECISION",true,0.0,0.0,0.0,0.0,0.0,
               StringFormat("%s|%s",IRDecisionName(g_decision.decision),
                            g_decision.reason));
      return;
     }

   if(g_have_pos)
      return; //--- closed-bar analysis while running is for context only

   ProcessEntryBar(bar_time,data_reason);
  }
