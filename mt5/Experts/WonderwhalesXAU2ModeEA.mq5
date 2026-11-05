//+------------------------------------------------------------------+
//|                                  WonderwhalesXAU2ModeEA.mq5       |
//|   Wonderwhales XAU 2-mode demo execution (ADR 0009).              |
//|                                                                  |
//| One bot, one magic (25008001), two strategies: Scalp (M15/M5/M1)  |
//| and Swing (W1/D1/H1). Signals come from iCustom                    |
//| PinePort\\Wonderwhales through WonderwhalesContract.mqh. Every     |
//| order goes through ExecBroker after ExecGuard. One guarded         |
//| position, mandatory SL/TP, rule-based BE/trailing, a persistent    |
//| daily/weekly/drawdown guard and a parity gate.                     |
//| Demo account or Strategy Tester only. No credentials, no login,    |
//| no WebRequest, no sockets.                                         |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Demo-only Wonderwhales XAU 2-mode execution: Scalp or Swing on a DEMO account or Strategy Tester."
#property description "Signals from iCustom PinePort\\Wonderwhales, mandatory SL/TP, parity gate, no live trading."

#include "../Include/Exec/ExecGuard.mqh"
#include "../Include/Exec/ExecBroker.mqh"
#include "../Include/Sim/SimRiskGuard.mqh"
#include "../Include/Sim/SimLogger.mqh"
#include "../Include/Sim/SimValidate.mqh"
#include "../Include/PinePort/WonderwhalesContract.mqh"
#include "../Include/Wonderwhales/WW2Types.mqh"
#include "../Include/Wonderwhales/WW2SignalReader.mqh"
#include "../Include/Wonderwhales/WW2RiskSizer.mqh"
#include "../Include/Wonderwhales/WW2Swing.mqh"
#include "../Include/Wonderwhales/WW2InitialStop.mqh"
#include "../Include/Wonderwhales/WW2RiskGuard.mqh"
#include "../Include/Wonderwhales/WW2TrailingCoordinator.mqh"
#include "../Include/Wonderwhales/WW2Telemetry.mqh"
#include "../Include/Wonderwhales/WW2Census.mqh"
#include "../Include/Wonderwhales/WW2ScalpStrategy.mqh"
#include "../Include/Wonderwhales/WW2SwingStrategy.mqh"

#define WW2_STATE_VERSION 1

//--- 01 Execution -------------------------------------------------
input group "01 Execution"
input bool   InpEnableExecution     = true;   // false = dry-run, no orders (ADR 0006: true by default)
input bool   InpDemoOnly            = true;   // demo/tester guard; must stay true
input string InpAllowedSymbols      = "XAUUSD"; // prefix allow-list, comma separated
input long   InpMagicNumber         = 25008001;
input int    InpMaxSlippagePoints   = 30;
input ENUM_WW2_MODE InpTradingMode  = WW2_SCALP;   // active strategy (SIGNAL_ONLY = observe)
input ENUM_WW_MODE  InpSignalMode   = WW_MODE_SAR_EMA; // indicator signal mode

//--- 02 Risk ------------------------------------------------------
input group "02 Risk"
input double InpRiskPercent         = 0.15;   // equity risked per entry (per-mode value comes from the preset)
input int    InpMaxPositions        = 1;
input int    InpCooldownMinutes     = 20;     // pause after a loss streak (per-mode value from the preset)
input int    InpMaxConsecutiveLosses= 2;
input double InpMaxDailyLossPct     = 1.0;    // 0 = disabled
input double InpMaxWeeklyLossPct    = 2.0;    // 0 = disabled
input double InpMaxDrawdownPct      = 5.0;    // 0 = disabled
input double InpMaxSpreadPoints     = 600.0;
input double InpMaxSpreadRatioToSlPct = 10.0; // reject when spread > this % of the stop distance
input double InpMaxExposure         = 0.10;   // volume cap; never rounds up to reach the risk
input bool   InpHaltOnBreach        = true;

//--- 03 Stops -----------------------------------------------------
input group "03 Stops"
input double InpTakeProfitR         = 1.5;    // mandatory TP = entry +/- InpTakeProfitR * SL distance (per-mode from the preset)
input double InpMinStopPoints       = 150.0;
input double InpMaxStopPoints       = 100000.0;
input double InpScalpBufferAtr      = 0.20;
input double InpScalpSlAtrFallback  = 1.2;
input double InpSwingBufferAtr      = 0.30;
input double InpSwingSlAtrFallback  = 2.0;
input bool   InpBreakEvenCostBuffer = true;   // add a cost buffer to the break-even level
input double InpBreakEvenBufferPoints = 50.0; // buffer in points when enabled

//--- 04 Journal and state ----------------------------------------
input group "04 Journal and state"
input bool   InpEnableLog           = true;
input string InpLogFile             = "wonderwhales_xau_2mode_demo.csv";
input bool   InpEnableTelemetry     = true;
input string InpTelemetryFile       = "wonderwhales_xau_2mode_telemetry.csv";
input bool   InpPersistState        = true;
input string InpStateFile           = "wonderwhales_xau_2mode_demo_state.csv";
input bool   InpResetStateOnInit    = false;
input bool   InpDebug               = false;

//--- 05 Kill switch ----------------------------------------------
input group "05 Kill switch"
input string InpKillSwitchFile      = "WONDERWHALES_XAU_2MODE_DEMO_STOP.txt";
input bool   InpCloseOnKillSwitch   = true;
input bool   InpRequireParity       = true;   // block entries until Pine<->MT5 parity is proven

//--- 06 Strategy --------------------------------------------------
input group "06 Strategy"
input double InpPsarStart           = 0.02;
input double InpPsarInc             = 0.02;
input double InpPsarMax             = 0.20;
input int    InpFastEma             = 20;
input int    InpSlowEma             = 50;
input int    InpEma200              = 200;
input int    InpAtrLen              = 14;
input double InpMinAtrPct           = 0.5;
input int    InpVolMaLen            = 20;
input int    InpRsiLen              = 14;
input int    InpBbLen               = 20;
input double InpBbMult              = 2.0;
input int    InpWarmupBars          = 300;
input ENUM_TIMEFRAMES InpScalpBiasTF    = PERIOD_M15;
input ENUM_TIMEFRAMES InpScalpSetupTF   = PERIOD_M5;
input ENUM_TIMEFRAMES InpScalpTriggerTF = PERIOD_M1;
input ENUM_TIMEFRAMES InpSwingBiasTF    = PERIOD_W1;
input ENUM_TIMEFRAMES InpSwingSetupTF   = PERIOD_D1;
input ENUM_TIMEFRAMES InpSwingTriggerTF = PERIOD_H1;
//--- Event windows. 1 = only the last closed bar (original behaviour).
//--- trigger: bars scanned inside the confirming setup bar (5 = all M1 of M5).
//--- setup:   closed setup bars scanned for the flip (5 = last five M5 bars).
input int InpTriggerWindowBars      = 1;      // trigger bars scanned per setup bar
input int InpSetupWindowBars        = 1;      // setup bars scanned for the flip
input double InpBreakEvenTriggerR   = 1.0;
input double InpTrailTriggerR       = 1.3;
input double InpMinTrailStepPoints  = 50.0;
input double InpSwingRrMin          = 1.8;    // swing TP must clear this many R
input int    InpSwingConfirmBars    = 2;
input int    InpStructureLookbackBars = 300;
input bool   InpEnableStructureTrail = true;
input bool   InpEnablePsarTrail     = false;
input bool   InpEnableAtrTrail      = false;
input bool   InpEnableStepTrail     = false;
input double InpStepTrailPoints     = 300.0;
input double InpTrailBufferAtr      = 0.25;
input bool   InpExitOnFlip          = true;
input int    InpMaxHoldingBars      = 0;      // 0 = disabled

CSimLogger    g_logger;
CWw2RiskGuard g_guard;

int      g_h_m1=INVALID_HANDLE;
int      g_h_m5=INVALID_HANDLE;
int      g_h_m15=INVALID_HANDLE;
int      g_h_h1=INVALID_HANDLE;
int      g_h_d1=INVALID_HANDLE;
int      g_h_w1=INVALID_HANDLE;
int      g_tele=INVALID_HANDLE;
int      g_census=INVALID_HANDLE;

double   g_point=0.0;
int      g_digits=0;
double   g_tick_size=0.0;
double   g_stops_level=0.0;
double   g_volume_min=0.0;
double   g_volume_max=0.0;
double   g_volume_step=0.0;
string   g_config_hash="";
string   g_timeframe_text="";
bool     g_is_hedging=true;

double   g_equity=0.0;
bool     g_halted=false;
string   g_halt_reason="";

datetime g_last_bar=0;
datetime g_last_exit_bar=0;
datetime g_last_signal_bar=0;
string   g_signal_text="none";
string   g_last_block="none";
string   g_strike_tf_text="";

Ww2Position g_pos;
Ww2Signal   g_sig_bias;
Ww2Signal   g_sig_setup;
Ww2Signal   g_sig_trigger;
Ww2CensusStats g_census_stats;

int      g_entries=0;
int      g_exits=0;
int      g_wins=0;
int      g_losses=0;
int      g_blocks=0;
double   g_realized_pnl=0.0;

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
int HandleFor(const ENUM_TIMEFRAMES tf)
  {
   if(tf==PERIOD_M1)
      return(g_h_m1);
   if(tf==PERIOD_M5)
      return(g_h_m5);
   if(tf==PERIOD_M15)
      return(g_h_m15);
   if(tf==PERIOD_H1)
      return(g_h_h1);
   if(tf==PERIOD_D1)
      return(g_h_d1);
   if(tf==PERIOD_W1)
      return(g_h_w1);
   return(INVALID_HANDLE);
  }

double NormalizePrice(const double price)
  {
   if(!(g_tick_size>0.0))
      return(NormalizeDouble(price,g_digits));
   return(NormalizeDouble(MathRound(price/g_tick_size)*g_tick_size,g_digits));
  }

double BrokerStopPoints(void)
  {
   return((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL));
  }

ENUM_TIMEFRAMES StrikeTimeframe(const ENUM_WW2_MODE mode)
  {
   return(mode==WW2_SWING ? InpSwingTriggerTF : InpScalpSetupTF);
  }

//+------------------------------------------------------------------+
//| Validation                                                       |
//+------------------------------------------------------------------+
bool ValidateInputs(string &error)
  {
   error="";
   if(!InpDemoOnly)
     {
      error="demo_only_required";
      return(false);
     }
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
   if(InpPersistState && StringLen(ExecTrim(InpStateFile))==0)
     {
      error="state_file_empty";
      return(false);
     }
   if(InpEnableLog && StringLen(ExecTrim(InpLogFile))==0)
     {
      error="log_file_empty";
      return(false);
     }
   if(InpEnableTelemetry && StringLen(ExecTrim(InpTelemetryFile))==0)
     {
      error="telemetry_file_empty";
      return(false);
     }
   if(InpTradingMode!=WW2_SIGNAL_ONLY && InpTradingMode!=WW2_SCALP &&
      InpTradingMode!=WW2_SWING)
     {
      error="trading_mode_out_of_range";
      return(false);
     }
   if(InpSignalMode<WW_MODE_SAR || InpSignalMode>WW_MODE_SAR_EMA_ATR)
     {
      error="signal_mode_out_of_range";
      return(false);
     }
   if(!SimIsFinite(InpPsarStart) || InpPsarStart<=0.0 ||
      !SimIsFinite(InpPsarInc) || InpPsarInc<=0.0 ||
      !SimIsFinite(InpPsarMax) || InpPsarMax<=0.0)
     {
      error="psar_parameters_must_be_positive";
      return(false);
     }
   if(InpPsarStart>InpPsarMax || InpPsarInc>InpPsarMax)
     {
      error="psar_parameters_must_not_exceed_max";
      return(false);
     }
   if(InpFastEma<1 || InpSlowEma<1 || InpEma200<1)
     {
      error="ema_periods_must_be_positive";
      return(false);
     }
   if(InpSlowEma<=InpFastEma)
     {
      error="slow_ema_must_exceed_fast_ema";
      return(false);
     }
   if(InpEma200<=InpSlowEma)
     {
      error="ema200_must_exceed_slow_ema";
      return(false);
     }
   if(InpAtrLen<1 || InpVolMaLen<1 || InpRsiLen<1 || InpBbLen<1)
     {
      error="indicator_periods_must_be_positive";
      return(false);
     }
   if(!SimIsFinite(InpMinAtrPct) || InpMinAtrPct<0.0)
     {
      error="min_atr_pct_must_be_finite_non_negative";
      return(false);
     }
   if(!SimIsFinite(InpBbMult) || InpBbMult<=0.0)
     {
      error="bollinger_multiplier_must_be_positive";
      return(false);
     }
   if(InpWarmupBars<0 || InpWarmupBars<InpEma200)
     {
      error="warmup_bars_must_cover_ema200";
      return(false);
     }
   if(!SimIsFinite(InpRiskPercent) || InpRiskPercent<=0.0 ||
      InpRiskPercent>10.0)
     {
      error="risk_percent_must_be_between_0_and_10";
      return(false);
     }
   if(InpMaxPositions!=1)
     {
      error="max_positions_must_be_1";
      return(false);
     }
   if(!SimIsFinite(InpMaxExposure) || InpMaxExposure<=0.0 ||
      InpMaxExposure>100.0)
     {
      error="max_exposure_must_be_between_0_and_100";
      return(false);
     }
   if(InpMaxConsecutiveLosses<0 || InpCooldownMinutes<0)
     {
      error="loss_limits_negative";
      return(false);
     }
   if(!SimValidatePercent(InpMaxDailyLossPct,error) ||
      !SimValidatePercent(InpMaxWeeklyLossPct,error) ||
      !SimValidatePercent(InpMaxDrawdownPct,error))
      return(false);
   if(!SimValidateSpreadPoints(InpMaxSpreadPoints,error))
      return(false);
   if(!SimIsFinite(InpMaxSpreadRatioToSlPct) ||
      InpMaxSpreadRatioToSlPct<0.0 || InpMaxSpreadRatioToSlPct>100.0)
     {
      error="max_spread_ratio_out_of_range";
      return(false);
     }
   if(!SimIsFinite(InpTakeProfitR) || InpTakeProfitR<=0.0)
     {
      error="take_profit_r_must_be_positive";
      return(false);
     }
   if(!SimIsFinite(InpMinStopPoints) || InpMinStopPoints<0.0)
     {
      error="min_stop_points_must_be_non_negative";
      return(false);
     }
   if(!SimIsFinite(InpMaxStopPoints) || InpMaxStopPoints<=0.0 ||
      InpMaxStopPoints<InpMinStopPoints)
     {
      error="max_stop_points_must_cover_min_stop_points";
      return(false);
     }
   if(InpSwingRrMin>0.0 && InpTakeProfitR<InpSwingRrMin &&
      InpTradingMode==WW2_SWING)
     {
      error="swing_take_profit_below_min_rr";
      return(false);
     }
   if(!SimIsFinite(InpBreakEvenTriggerR) || InpBreakEvenTriggerR<0.0 ||
      !SimIsFinite(InpTrailTriggerR) || InpTrailTriggerR<0.0)
     {
      error="trigger_r_must_be_non_negative";
      return(false);
     }
   if(InpTrailTriggerR<InpBreakEvenTriggerR)
     {
      error="trail_trigger_below_break_even";
      return(false);
     }
   if(!SimIsFinite(InpMinTrailStepPoints) || InpMinTrailStepPoints<0.0)
     {
      error="min_trail_step_points_must_be_non_negative";
      return(false);
     }
   if(InpSwingConfirmBars<1 || InpStructureLookbackBars<1)
     {
      error="structure_lookback_invalid";
      return(false);
     }
   //--- Timeframes must be ordered bias > setup > trigger.
   if(!(PeriodSeconds(InpScalpBiasTF)>PeriodSeconds(InpScalpSetupTF) &&
        PeriodSeconds(InpScalpSetupTF)>PeriodSeconds(InpScalpTriggerTF)))
     {
      error="scalp_timeframes_must_be_ordered";
      return(false);
     }
   if(!(PeriodSeconds(InpSwingBiasTF)>PeriodSeconds(InpSwingSetupTF) &&
        PeriodSeconds(InpSwingSetupTF)>PeriodSeconds(InpSwingTriggerTF)))
     {
      error="swing_timeframes_must_be_ordered";
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Config hash                                                      |
//+------------------------------------------------------------------+
string BuildConfigHash(void)
  {
   const string text=g_guard.Fingerprint()+
                     SimFormatFingerprintPartInt("ww2.magic",(long)InpMagicNumber)+
                     SimFormatFingerprintPartInt("ww2.mode",(int)InpTradingMode)+
                     SimFormatFingerprintPartInt("ww2.signal",(int)InpSignalMode)+
                     SimFormatFingerprintPart("ww2.risk_pct",InpRiskPercent,4)+
                     SimFormatFingerprintPart("ww2.max_exposure",InpMaxExposure,4)+
                     SimFormatFingerprintPart("ww2.tp_r",InpTakeProfitR,4)+
                     SimFormatFingerprintPart("ww2.be_r",InpBreakEvenTriggerR,4)+
                     SimFormatFingerprintPart("ww2.trail_r",InpTrailTriggerR,4)+
                     SimFormatFingerprintPartText("ww2.allowed",InpAllowedSymbols)+
                     SimFormatFingerprintPartText("ww2.kill",InpKillSwitchFile)+
                     SimFormatFingerprintPartInt("ww2.structure",(InpEnableStructureTrail?1:0))+
                     SimFormatFingerprintPartInt("ww2.psar",(InpEnablePsarTrail?1:0))+
                     SimFormatFingerprintPartInt("ww2.atr",(InpEnableAtrTrail?1:0))+
                     SimFormatFingerprintPartInt("ww2.step",(InpEnableStepTrail?1:0));
   return(SimHashString(text));
  }

//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
void LogEvent(const string event_name,const ENUM_SIM_SIDE side,
              const double price,const double volume,const double entry,
              const double sl,const double tp,const string reason)
  {
   if(!g_logger.IsOpen())
      return;
   SimLogRecord record;
   SimClearLogRecord(record);
   record.logged_at=TimeCurrent();
   record.bar_time=(g_last_signal_bar>0 ? g_last_signal_bar : iTime(_Symbol,_Period,0));
   record.ea="WonderwhalesXAU2ModeEA";
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
   record.exposure=(g_pos.have ? g_pos.volume : 0.0);
   record.equity=g_equity;
   record.drawdown_pct=DrawdownPct();
   record.reason=reason;
   string error="";
   if(!g_logger.Write(record,error))
      PrintFormat("LAB|ERROR|ww2|log_write_failed|%s",error);
  }

//--- Realized R appended to every EXIT row. The 18-column journal contract
//--- is unchanged: R rides in the free-text reason field, measured from the
//--- stored initial SL (never the trailed one).
string RealizedRSuffix(const double pnl,const bool known)
  {
   double r=0.0;
   if(!known ||
      !Ww2RealizedR(pnl,g_pos.volume,g_pos.initial_r,
                    SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE),r))
      return("|r=NA");
   return(StringFormat("|r=%.2f",r));
  }

double DrawdownPct(void)
  {
   const double peak=g_guard.PeakEquity();
   if(!(peak>0.0) || !(g_equity>0.0) || g_equity>=peak)
      return(0.0);
   return((peak-g_equity)/peak*100.0);
  }

//+------------------------------------------------------------------+
//| Account, day/week/halt tracking                                  |
//+------------------------------------------------------------------+
void SyncHalt(void)
  {
   string reason="";
   g_halted=g_guard.Halted(reason);
   g_halt_reason=reason;
  }

void UpdateAccountState(void)
  {
   g_equity=AccountInfoDouble(ACCOUNT_EQUITY);
   string reason="";
   if(g_guard.Refresh(g_equity,TimeCurrent(),reason))
     {
      g_halted=true;
      g_halt_reason=reason;
      LogEvent("HALT",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,"risk_halt|"+reason);
      SaveState();
     }
  }

void Halt(const string reason)
  {
   if(g_halted)
      return;
   g_guard.ForceHalt(reason);
   g_halted=true;
   g_halt_reason=reason;
   PrintFormat("LAB|WARN|ww2|halted|reason=%s",reason);
   LogEvent("HALT",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,"reason="+reason);
   SaveState();
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
      PrintFormat("LAB|ERROR|ww2|state_write_failed|error=%d",GetLastError());
      return;
     }
   FileWriteString(handle,"state_version="+IntegerToString(WW2_STATE_VERSION)+"\r\n");
   FileWriteString(handle,"magic="+IntegerToString((long)InpMagicNumber)+"\r\n");
   FileWriteString(handle,"saved_at="+TimeToString(TimeCurrent())+"\r\n");
   string guard_block="";
   g_guard.Save(guard_block);
   FileWriteString(handle,guard_block);
   FileWriteString(handle,"pos_ticket="+IntegerToString((long)g_pos.ticket)+"\r\n");
   FileWriteString(handle,"pos_is_buy="+string(g_pos.is_buy ? "1" : "0")+"\r\n");
   FileWriteString(handle,StringFormat("pos_entry=%.8f\r\n",g_pos.entry));
   FileWriteString(handle,StringFormat("pos_volume=%.8f\r\n",g_pos.volume));
   FileWriteString(handle,StringFormat("pos_initial_sl=%.8f\r\n",g_pos.initial_sl));
   FileWriteString(handle,StringFormat("pos_initial_r=%.8f\r\n",g_pos.initial_r));
   FileWriteString(handle,StringFormat("pos_current_sl=%.8f\r\n",g_pos.current_sl));
   FileWriteString(handle,StringFormat("pos_tp=%.8f\r\n",g_pos.tp));
   FileWriteString(handle,"pos_open_time="+IntegerToString((long)g_pos.open_time)+"\r\n");
   FileWriteString(handle,"pos_mode="+IntegerToString((int)g_pos.mode)+"\r\n");
   FileClose(handle);
  }

bool ReadStateFile(bool &restored)
  {
   restored=false;
   if(!InpPersistState || !FileIsExist(InpStateFile))
      return(false);
   const int handle=FileOpen(InpStateFile,FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle==INVALID_HANDLE)
      return(false);

   string text="";
   while(!FileIsEnding(handle))
      text+=FileReadString(handle)+"\n";
   FileClose(handle);

   bool version_ok=false;
   bool magic_ok=false;
   long pos_ticket=0;
   bool pos_is_buy=true;
   double pos_entry=0.0,pos_volume=0.0,pos_initial_sl=0.0,pos_initial_r=0.0;
   double pos_current_sl=0.0,pos_tp=0.0;
   datetime pos_open_time=0;
   int pos_mode=0;

   int start=0;
   const int len=StringLen(text);
   while(start<len)
     {
      int nl=StringFind(text,"\n",start);
      if(nl<0)
         nl=len;
      string line=StringSubstr(text,start,nl-start);
      StringReplace(line,"\r","");
      const int eq=StringFind(line,"=");
      if(eq>0)
        {
         const string key=StringSubstr(line,0,eq);
         const string value=StringSubstr(line,eq+1);
         if(key=="state_version")
            version_ok=(StringToInteger(value)==WW2_STATE_VERSION);
         else if(key=="magic")
            magic_ok=(StringToInteger(value)==InpMagicNumber);
         else if(key=="pos_ticket")
            pos_ticket=(long)StringToInteger(value);
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
         else if(key=="pos_current_sl")
            pos_current_sl=StringToDouble(value);
         else if(key=="pos_tp")
            pos_tp=StringToDouble(value);
         else if(key=="pos_open_time")
            pos_open_time=(datetime)StringToInteger(value);
         else if(key=="pos_mode")
            pos_mode=(int)StringToInteger(value);
        }
      start=nl+1;
     }

   if(!version_ok || !magic_ok)
      return(false);

   g_guard.Load(text);
   g_pos.ticket=(ulong)pos_ticket;
   g_pos.is_buy=pos_is_buy;
   g_pos.entry=pos_entry;
   g_pos.volume=pos_volume;
   g_pos.initial_sl=pos_initial_sl;
   g_pos.initial_r=pos_initial_r;
   g_pos.current_sl=(pos_current_sl>0.0 ? pos_current_sl : pos_initial_sl);
   g_pos.tp=pos_tp;
   g_pos.open_time=pos_open_time;
   g_pos.mode=(pos_mode==(int)WW2_SCALP ? WW2_SCALP
               : (pos_mode==(int)WW2_SWING ? WW2_SWING : WW2_SIGNAL_ONLY));
   g_pos.have=(pos_ticket>0);
   restored=true;
   return(true);
  }

//+------------------------------------------------------------------+
//| Chart panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel(const double bid,const double ask)
  {
   const string mode=(InpEnableExecution ? "DEMO_EXECUTION" : "DRY_RUN");
   const string position=(g_pos.have
                          ? StringFormat("%s %s %.2f @ %.3f",
                                         Ww2ModeName(g_pos.mode),
                                         (g_pos.is_buy ? "BUY" : "SELL"),
                                         g_pos.volume,g_pos.entry)
                          : "flat");
   const string state=(g_halted ? "HALTED: "+g_halt_reason
                                : "ACTIVE");
   Comment(StringFormat(
      "Wonderwhales XAU 2-mode v1.00 | %s | %s %s\n"
      "mode=%s signal=%s hash=%s magic=%d spread=%.1f pts\n"
      "position=%s  strike_tf=%s\n"
      "equity=%.2f  dd=%.2f%%  entries=%d exits=%d W/L=%d/%d streak=%d\n"
      "state=%s  last_block=%s  parity=%s",
      mode,_Symbol,g_timeframe_text,Ww2ModeName(InpTradingMode),g_signal_text,
      g_config_hash,(int)InpMagicNumber,
      (ask>bid && g_point>0.0 ? (ask-bid)/g_point : 0.0),
      position,g_strike_tf_text,g_equity,DrawdownPct(),g_entries,g_exits,
      g_wins,g_losses,g_guard.StreakLosses(),state,g_last_block,
      (InpRequireParity ? "REQUIRED" : "OFF")));
  }

//+------------------------------------------------------------------+
//| Position lifecycle                                               |
//+------------------------------------------------------------------+
void ApplyClosedPnl(const double pnl,const bool known)
  {
   if(known)
     {
      g_realized_pnl+=pnl;
      if(pnl<0.0)
         g_losses++;
      else if(pnl>0.0)
         g_wins++;
      g_guard.RecordClosed(pnl,TimeCurrent());
     }
   SyncHalt();
   g_exits++;
  }

void FinalizeClosedPosition(void)
  {
   double pnl=0.0;
   int deals=0;
   bool known=false;
   if(g_pos.ticket>0 && g_pos.open_time>0)
     {
      if(ExecClosedPnl(g_pos.ticket,g_pos.open_time-3600,pnl,deals))
         known=true;
      else if(ExecClosedPnl(g_pos.ticket,g_pos.open_time-86400,pnl,deals))
         known=true;
     }
   ApplyClosedPnl(pnl,known);
   g_last_exit_bar=iTime(_Symbol,_Period,0);
   LogEvent("EXIT",(g_pos.is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),0.0,
            g_pos.volume,g_pos.entry,g_pos.initial_sl,g_pos.tp,
            StringFormat("BROKER_EXIT|mode=%s|pnl_known=%d|pnl=%.2f|deals=%d|streak=%d%s",
                         Ww2ModeName(g_pos.mode),(known ? 1 : 0),pnl,deals,
                         g_guard.StreakLosses(),RealizedRSuffix(pnl,known)));
   Ww2ResetPosition(g_pos);
   SaveState();
  }

bool CloseAtMarket(const string reason)
  {
   if(!g_pos.have)
      return(false);
   if(!InpEnableExecution)
     {
      LogEvent("DRY_RUN",(g_pos.is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),0.0,
               g_pos.volume,g_pos.entry,g_pos.initial_sl,g_pos.tp,
               "would_close|reason="+reason);
      return(false);
     }
   ExecFillResult fill;
   if(!ExecClosePosition(g_pos.ticket,g_pos.is_buy,g_pos.volume,
                         InpMaxSlippagePoints,InpMagicNumber,"WW2_CLOSE",fill))
     {
      LogEvent("ERROR",(g_pos.is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),0.0,
               g_pos.volume,g_pos.entry,g_pos.initial_sl,g_pos.tp,
               "close_failed|reason="+reason+"|"+fill.message);
      return(false);
     }
   double pnl=0.0;
   int deals=0;
   bool known=false;
   if(g_pos.ticket>0 && g_pos.open_time>0)
      known=ExecClosedPnl(g_pos.ticket,g_pos.open_time-3600,pnl,deals);
   ApplyClosedPnl(pnl,known);
   g_last_exit_bar=iTime(_Symbol,_Period,0);
   LogEvent("EXIT",(g_pos.is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),fill.price,
            g_pos.volume,g_pos.entry,g_pos.initial_sl,g_pos.tp,
            StringFormat("%s|mode=%s|close_price=%.3f|pnl_known=%d|pnl=%.2f|deals=%d|streak=%d|%s%s",
                         reason,Ww2ModeName(g_pos.mode),fill.price,(known ? 1 : 0),
                         pnl,deals,g_guard.StreakLosses(),fill.message,
                         RealizedRSuffix(pnl,known)));
   Ww2ResetPosition(g_pos);
   SaveState();
   return(true);
  }

void EnsureStops(void)
  {
   if(!g_pos.have || !InpEnableExecution)
      return;
   //--- Re-assert the CURRENT intended stop, never loosen it back to the initial
   //--- stop after the position has trailed.
   const double guard_sl=(g_pos.current_sl>0.0 ? g_pos.current_sl : g_pos.initial_sl);
   if(!(guard_sl>0.0) || !(g_pos.tp>0.0))
      return;
   ExecPositionInfo info;
   if(!ExecFindOwnPosition(InpMagicNumber,info))
      return;
   if(info.sl>0.0 && info.tp>0.0)
      return;
   ExecFillResult result;
   if(!ExecModifyStops(info.ticket,guard_sl,g_pos.tp,result))
     {
      LogEvent("ERROR",(g_pos.is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),
               info.open_price,info.volume,g_pos.entry,guard_sl,
               g_pos.tp,"stops_reassert_failed|"+result.message);
      return;
     }
   LogEvent("STOPS_REASSERT",(g_pos.is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),
            result.price,info.volume,g_pos.entry,guard_sl,g_pos.tp,
            "sl_tp_reasserted|"+result.message);
  }

void ReconcilePosition(void)
  {
   ExecPositionInfo info;
   const bool found=ExecFindOwnPosition(InpMagicNumber,info);
   if(g_pos.have && !found)
     {
      FinalizeClosedPosition();
      return;
     }
   if(!g_pos.have && found)
     {
      g_pos.have=true;
      g_pos.ticket=info.ticket;
      g_pos.is_buy=(info.type==POSITION_TYPE_BUY);
      g_pos.entry=info.open_price;
      g_pos.volume=info.volume;
      //--- The broker's live SL is the best available anchor but may already be
      //--- trailed, so no R is synthesized and the mode stays unknown: an
      //--- adopted position is NOT managed with the current InpTradingMode
      //--- (spec §7.3/§12.18).
      g_pos.initial_sl=info.sl;
      g_pos.initial_r=0.0;
      g_pos.current_sl=info.sl;
      g_pos.tp=info.tp;
      g_pos.open_time=info.open_time;
      g_pos.mode=WW2_SIGNAL_ONLY;
      LogEvent("ADOPT",(g_pos.is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),
               info.open_price,info.volume,info.open_price,info.sl,info.tp,
               "adopted_position_from_broker|mode_unknown_manage_safely");
      SaveState();
      return;
     }
   if(g_pos.have && found)
     {
      g_pos.ticket=info.ticket;
      g_pos.volume=info.volume;
      //--- The broker's live stop is the CURRENT stop, not the R anchor: keep
      //--- initial_sl untouched so R keeps measuring from the original risk.
      if(info.sl>0.0)
         g_pos.current_sl=info.sl;
      if(info.tp>0.0)
         g_pos.tp=info.tp;
      EnsureStops();
     }
  }

//+------------------------------------------------------------------+
//| Entry                                                            |
//+------------------------------------------------------------------+
void BlockEntry(const ENUM_SIM_SIDE side,const string token,const string detail)
  {
   g_blocks++;
   g_last_block=token;
   LogEvent("RISK",side,0.0,0.0,0.0,0.0,0.0,
            "ENTRY_BLOCKED|reason="+token+(StringLen(detail)>0 ? "|"+detail : ""));
  }

//--- Census file name: derived from the journal so a tester scenario writes
//--- sim_<scenario>_census.csv next to sim_<scenario>.csv.
string CensusFileName(void)
  {
   string base=InpLogFile;
   if(StringLen(base)==0)
      base="wonderwhales_xau_2mode_demo.csv";
   const int len=StringLen(base);
   if(len>4 && StringSubstr(base,len-4)==".csv")
      base=StringSubstr(base,0,len-4);
   return(base+"_census.csv");
  }

//--- Window sizes, clamped to >= 1 so the defaults keep the original
//--- "last closed bar only" behaviour.
int TriggerWindow(void)
  {
   return(InpTriggerWindowBars>1 ? InpTriggerWindowBars : 1);
  }

int SetupWindow(void)
  {
   return(InpSetupWindowBars>1 ? InpSetupWindowBars : 1);
  }

//--- One census row per chart bar, independent of the entry path. It runs only
//--- when InpDebug opened the file, so it cannot change trading behaviour.
void CensusBar(const datetime bar_time)
  {
   if(g_census==INVALID_HANDLE)
      return;

   if(InpTradingMode==WW2_SCALP)
     {
      if(!Ww2ReadSignal(g_h_m15,_Symbol,InpScalpBiasTF,1,g_sig_bias) ||
         !Ww2ReadSignalWindow(g_h_m5,_Symbol,InpScalpSetupTF,
                              SetupWindow(),g_sig_setup) ||
         !Ww2ReadSignalWindow(g_h_m1,_Symbol,InpScalpTriggerTF,
                              TriggerWindow(),g_sig_trigger))
         return;
      Ww2ScalpGates g;
      const bool signal=Ww2ScalpEvaluate(g_sig_bias,g_sig_setup,g_sig_trigger,g);
      Ww2CensusWrite(g_census,bar_time,InpTradingMode,
                     g.bias_valid,g.bias_buy,g.bias_sell,
                     g.setup_valid,g.setup_buy,g.setup_sell,g.setup_align,
                     g.trigger_valid,g.trigger_buy,g.trigger_sell,
                     signal,g.reason);
      Ww2CensusCount(g_census_stats,g.reason);
      return;
     }

   if(InpTradingMode==WW2_SWING)
     {
      if(!Ww2ReadSignal(g_h_w1,_Symbol,InpSwingBiasTF,1,g_sig_bias) ||
         !Ww2ReadSignalWindow(g_h_d1,_Symbol,InpSwingSetupTF,
                              SetupWindow(),g_sig_setup) ||
         !Ww2ReadSignalWindow(g_h_h1,_Symbol,InpSwingTriggerTF,
                              TriggerWindow(),g_sig_trigger))
         return;
      Ww2SwingGates g;
      const bool signal=Ww2SwingEvaluate(g_sig_bias,g_sig_setup,g_sig_trigger,g);
      Ww2CensusWrite(g_census,bar_time,InpTradingMode,
                     g.bias_valid,g.bias_buy,g.bias_sell,
                     g.setup_valid,g.setup_buy,g.setup_sell,g.setup_align,
                     g.trigger_valid,g.trigger_buy,g.trigger_sell,
                     signal,g.reason);
      Ww2CensusCount(g_census_stats,g.reason);
     }
  }

bool ResolveSwing(const bool is_buy,const ENUM_TIMEFRAMES tf,bool &have,
                  double &price)
  {
   have=false;
   price=0.0;
   const int need=InpStructureLookbackBars+InpSwingConfirmBars+5;
   double arr[];
   if(is_buy)
     {
      if(CopyLow(_Symbol,tf,0,need,arr)<need)
         return(false);
      ArraySetAsSeries(arr,true);
      int shift=0;
      double px=0.0;
      if(Ww2FindSwingLow(arr,1,InpStructureLookbackBars,InpSwingConfirmBars,shift,px))
        {
         have=true;
         price=px;
        }
     }
   else
     {
      if(CopyHigh(_Symbol,tf,0,need,arr)<need)
         return(false);
      ArraySetAsSeries(arr,true);
      int shift=0;
      double px=0.0;
      if(Ww2FindSwingHigh(arr,1,InpStructureLookbackBars,InpSwingConfirmBars,shift,px))
        {
         have=true;
         price=px;
        }
     }
   return(true);
  }

bool TryEnter(const datetime bar_time)
  {
   if(g_pos.have || g_halted)
      return(false);
   if(bar_time==g_last_exit_bar)
      return(false);

   const ENUM_WW2_MODE mode=InpTradingMode;
   if(mode==WW2_SIGNAL_ONLY)
      return(false);

   if(InpRequireParity)
     {
      BlockEntry(SIM_SIDE_NONE,"parity_blocked","parity_not_proven");
      return(false);
     }

   bool is_buy=false;
   if(mode==WW2_SCALP)
     {
      if(!Ww2ReadSignal(g_h_m15,_Symbol,InpScalpBiasTF,1,g_sig_bias))
         return(false);
      if(!Ww2ReadSignalWindow(g_h_m5,_Symbol,InpScalpSetupTF,
                              SetupWindow(),g_sig_setup))
         return(false);
      if(!Ww2ReadSignalWindow(g_h_m1,_Symbol,InpScalpTriggerTF,
                              TriggerWindow(),g_sig_trigger))
         return(false);
      if(!Ww2ScalpEntry(g_sig_bias,g_sig_setup,g_sig_trigger,is_buy))
         return(false);
     }
   else
     {
      if(!Ww2ReadSignal(g_h_w1,_Symbol,InpSwingBiasTF,1,g_sig_bias))
         return(false);
      if(!Ww2ReadSignalWindow(g_h_d1,_Symbol,InpSwingSetupTF,
                              SetupWindow(),g_sig_setup))
         return(false);
      if(!Ww2ReadSignalWindow(g_h_h1,_Symbol,InpSwingTriggerTF,
                              TriggerWindow(),g_sig_trigger))
         return(false);
      if(!Ww2SwingEntry(g_sig_bias,g_sig_setup,g_sig_trigger,is_buy))
         return(false);
     }

   const ENUM_SIM_SIDE signal=(is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL);
   g_signal_text=(is_buy ? "BUY" : "SELL");

   ENUM_EXEC_BLOCK block=EXEC_OK;
   if(!ExecSymbolTradable(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE),block))
     {
      BlockEntry(signal,ExecBlockName(block),"symbol="+_Symbol);
      return(false);
     }

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0 || ask<=0.0)
      return(false);
   const double reference=(is_buy ? ask : bid);
   const double spread_points=(ask-bid)/g_point;

   bool have_swing=false;
   double swing_price=0.0;
   ResolveSwing(is_buy,StrikeTimeframe(mode),have_swing,swing_price);

   const double atr_pct=(mode==WW2_SCALP ? g_sig_setup.atr_pct : g_sig_trigger.atr_pct);
   const double distance=(mode==WW2_SCALP
                          ? Ww2ScalpStopDistance(is_buy,reference,atr_pct,swing_price,
                                                 have_swing,InpScalpBufferAtr,InpScalpSlAtrFallback)
                          : Ww2SwingStopDistance(is_buy,reference,atr_pct,swing_price,
                                                 have_swing,InpSwingBufferAtr,InpSwingSlAtrFallback));
   if(!(distance>0.0))
     {
      BlockEntry(signal,"STOP_REJECTED","distance_not_positive");
      return(false);
     }
   const double distance_points=distance/g_point;
   if(distance_points<InpMinStopPoints ||
      (InpMaxStopPoints>0.0 && distance_points>InpMaxStopPoints))
     {
      BlockEntry(signal,"STOP_REJECTED",
                 StringFormat("distance_points=%.1f|min=%.1f|max=%.1f",
                              distance_points,InpMinStopPoints,InpMaxStopPoints));
      return(false);
     }

   string guard_reason="";
   if(!g_guard.EntryAllowed(TimeCurrent(),spread_points,distance_points,
                            InpMaxSpreadPoints,InpMaxSpreadRatioToSlPct,guard_reason))
     {
      BlockEntry(signal,guard_reason,"mode="+Ww2ModeName(mode));
      return(false);
     }

   const double sl=NormalizePrice(is_buy ? reference-distance
                                         : reference+distance);
   const double tp=NormalizePrice(ExecTakeProfitPrice(is_buy,reference,sl,InpTakeProfitR));
   if(!ExecTakeProfitValid(is_buy,reference,sl,tp))
     {
      BlockEntry(signal,"take_profit_invalid",
                 StringFormat("entry=%.3f|sl=%.3f|tp=%.3f",reference,sl,tp));
      return(false);
     }
   if(!ExecStopsRespectBroker(reference,sl,tp,g_point,BrokerStopPoints()))
     {
      BlockEntry(signal,"stop_below_broker_level",
                 StringFormat("stops_level=%.1f|sl_points=%.1f|tp_points=%.1f",
                              BrokerStopPoints(),MathAbs(reference-sl)/g_point,
                              MathAbs(tp-reference)/g_point));
      return(false);
     }

   const double risk_money=g_equity*InpRiskPercent/100.0;
   double loss_per_lot=0.0;
   if(!ExecCalcProfit(is_buy,1.0,reference,sl,loss_per_lot))
     {
      BlockEntry(signal,"risk_budget_exceeded","order_calc_profit_failed");
      return(false);
     }
   loss_per_lot=MathAbs(loss_per_lot);

   double volume=0.0;
   string size_reason="";
   if(!Ww2SizeVolume(risk_money,loss_per_lot,g_volume_min,g_volume_max,
                     g_volume_step,InpMaxExposure,volume,size_reason))
     {
      BlockEntry(signal,"risk_budget_exceeded",size_reason);
      return(false);
     }

   double margin=0.0;
   const double free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(!ExecMarginRequired(is_buy,volume,reference,margin) ||
      margin>free_margin*0.90)
     {
      BlockEntry(signal,"free_margin_insufficient",
                 StringFormat("margin=%.2f|free=%.2f",margin,free_margin));
      return(false);
     }

   g_last_signal_bar=bar_time;
   if(!InpEnableExecution)
     {
      LogEvent("DRY_RUN",signal,reference,volume,reference,sl,tp,
               StringFormat("would_open|mode=%s|%s|spread_points=%.1f",
                            Ww2ModeName(mode),size_reason,spread_points));
      return(false);
     }

   ExecFillResult fill;
   if(!ExecOpenMarket(is_buy,volume,sl,tp,InpMaxSlippagePoints,InpMagicNumber,
                      "WW2_"+Ww2ModeName(mode),fill))
     {
      LogEvent("ERROR",signal,0.0,volume,reference,sl,tp,"open_failed|"+fill.message);
      PrintFormat("LAB|ERROR|ww2|open_failed|%s",fill.message);
      return(false);
     }

   g_entries++;
   g_pos.have=true;
   g_pos.ticket=fill.order;
   g_pos.is_buy=is_buy;
   g_pos.entry=fill.price;
   g_pos.volume=fill.volume;
   g_pos.initial_sl=sl;
   g_pos.initial_r=MathAbs(fill.price-sl);
   g_pos.current_sl=sl;
   g_pos.tp=tp;
   g_pos.open_time=TimeCurrent();
   g_pos.mode=mode;

   ExecPositionInfo opened;
   if(ExecFindOwnPosition(InpMagicNumber,opened))
     {
      g_pos.ticket=opened.ticket;
      if(opened.volume>0.0)
         g_pos.volume=opened.volume;
     }
   g_guard.RecordEntry(bar_time);
   SaveState();

   LogEvent("ENTRY",signal,fill.price,fill.volume,fill.price,sl,tp,
            StringFormat("SIGNAL_%s|mode=%s|ticket=%d|%s|spread_points=%.1f|%s",
                         (is_buy ? "BUY" : "SELL"),Ww2ModeName(mode),
                         (int)fill.order,size_reason,spread_points,fill.message));
   Ww2TelemetryWrite(g_tele,bar_time,g_pos.ticket,mode,0.0,sl,"ENTRY",
                     g_sig_trigger.fast_ema,g_sig_trigger.slow_ema,
                     g_sig_trigger.ema200,g_sig_trigger.atr_pct,
                     g_sig_trigger.sar_dir);
   PrintFormat("LAB|INFO|ww2|entry|mode=%s|side=%s|price=%.3f|volume=%.2f|"
               "sl=%.3f|tp=%.3f|ticket=%d|%s",
               Ww2ModeName(mode),(is_buy ? "BUY" : "SELL"),fill.price,fill.volume,
               sl,tp,(int)fill.order,size_reason);
   return(true);
  }

//+------------------------------------------------------------------+
//| Management on a new bar                                          |
//+------------------------------------------------------------------+
void TrailPosition(const datetime bar_time)
  {
   if(!InpEnableExecution)
      return;
   if(!(g_pos.mode==WW2_SCALP || g_pos.mode==WW2_SWING))
      return;
   const bool is_buy=g_pos.is_buy;
   const ENUM_TIMEFRAMES strike=StrikeTimeframe(g_pos.mode);
   Ww2Signal sig;
   if(!Ww2ReadSignal(HandleFor(strike),_Symbol,strike,1,sig))
      return;

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0 || ask<=0.0)
      return;

   const double ref_price=(is_buy ? bid : ask);
   const double atr_price=(sig.atr_pct>0.0 ? ref_price*(sig.atr_pct/100.0) : 0.0);

   bool have_struct=false;
   double struct_sl=0.0;
   if(InpEnableStructureTrail)
      ResolveSwing(is_buy,strike,have_struct,struct_sl);
   //--- Structure trailing sits BEYOND the confirmed swing by the ATR buffer
   //--- (spec §2.1/§2.2), not exactly on the swing.
   if(have_struct && atr_price>0.0)
      struct_sl=(is_buy ? struct_sl-InpTrailBufferAtr*atr_price
                        : struct_sl+InpTrailBufferAtr*atr_price);

   //--- The current stop comes from the broker, not from memory: a manual or
   //--- broker-side change must be respected before proposing a new SL.
   ExecPositionInfo info;
   const double broker_sl=(ExecFindOwnPosition(InpMagicNumber,info) && info.sl>0.0)
                          ? info.sl : g_pos.initial_sl;

   Ww2StopInput in;
   //--- Break-even/trailing arm only when the management bar closed in the
   //--- position's direction (spec §2.1/§2.2).
   in.allow_arm=(is_buy ? (sig.close>=sig.open) : (sig.close<=sig.open));
   in.is_buy=is_buy;
   in.entry=g_pos.entry;
   in.initial_sl=g_pos.initial_sl;
   in.current_sl=broker_sl;
   in.bid=bid;
   in.ask=ask;
   in.point=g_point;
   in.min_step_points=InpMinTrailStepPoints;
   in.be_trigger_r=InpBreakEvenTriggerR;
   in.be_buffer_points=(InpBreakEvenCostBuffer ? InpBreakEvenBufferPoints : 0.0);
   in.trail_trigger_r=InpTrailTriggerR;
   in.have_structure=have_struct;
   in.structure_sl=struct_sl;
   in.enable_psar=InpEnablePsarTrail;
   in.psar=sig.psar;
   in.enable_atr=InpEnableAtrTrail;
   in.atr_distance=(sig.atr_pct>0.0 ? (bid*(sig.atr_pct/100.0))*InpTrailBufferAtr : 0.0);
   in.enable_step=InpEnableStepTrail;
   in.step_points=InpStepTrailPoints;

   string reason="";
   const double new_sl=Ww2BestStop(in,reason);
   if(!(new_sl>0.0))
      return;

   const double reference=(is_buy ? bid : ask);
   if(!ExecStopsRespectBroker(reference,NormalizePrice(new_sl),g_pos.tp,g_point,
                              BrokerStopPoints()))
      return;

   ExecFillResult fill;
   if(!ExecModifyStops(g_pos.ticket,NormalizePrice(new_sl),g_pos.tp,fill))
     {
      LogEvent("ERROR",(is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),reference,
               g_pos.volume,g_pos.entry,g_pos.initial_sl,g_pos.tp,
               "sl_modify_failed|reason="+reason+"|"+fill.message);
      return;
     }
   const double r=Ww2CurrentR(g_pos,is_buy,bid,ask);
   g_pos.current_sl=NormalizePrice(new_sl);
   SaveState();
   LogEvent("TRAIL",(is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),reference,
            g_pos.volume,g_pos.entry,NormalizePrice(new_sl),g_pos.tp,
            StringFormat("trail|reason=%s|r=%.2f|mode=%s",reason,r,
                         Ww2ModeName(g_pos.mode)));
   Ww2TelemetryWrite(g_tele,bar_time,g_pos.ticket,g_pos.mode,r,
                     NormalizePrice(new_sl),reason,sig.fast_ema,sig.slow_ema,
                     sig.ema200,sig.atr_pct,sig.sar_dir);
  }

void ManagePosition(const datetime bar_time)
  {
   if(!g_pos.have)
      return;

   if(InpMaxHoldingBars>0)
     {
      const long bars_held=(long)(bar_time-g_pos.open_time)/
                           (long)PeriodSeconds(_Period);
      if(bars_held>=InpMaxHoldingBars)
        {
         CloseAtMarket(StringFormat("MAX_HOLDING_BARS|bars=%d",(int)bars_held));
         return;
        }
     }

   //--- A position with an unknown mode (adopted without state) is protected by
   //--- its broker SL/TP only: no mode-specific exit or trailing runs.
   const bool mode_known=(g_pos.mode==WW2_SCALP || g_pos.mode==WW2_SWING);
   if(!mode_known)
     {
      EnsureStops();
      return;
     }

   //--- Read the strike timeframe for the STORED mode (not the current input).
   const ENUM_TIMEFRAMES strike=StrikeTimeframe(g_pos.mode);
   Ww2Signal sig;
   const bool have_sig=Ww2ReadSignal(HandleFor(strike),_Symbol,strike,1,sig);

   if(InpExitOnFlip && have_sig)
     {
      const bool flipped=(g_pos.is_buy ? sig.sell : sig.buy);
      g_signal_text=(sig.buy ? "BUY" : (sig.sell ? "SELL" : "none"));
      if(flipped)
        {
         CloseAtMarket("SIGNAL_FLIP");
         return;
        }
     }

   TrailPosition(bar_time);
  }

void WriteSummary(void)
  {
   if(!g_logger.IsOpen())
      return;
   string detail=StringFormat("mode=%s|trades=%d|entries=%d|exits=%d|wins=%d|losses=%d|"
                              "net=%.2f|blocks=%d|streak=%d|halted=%s|parity=%s|execution=%s",
                              Ww2ModeName(InpTradingMode),g_wins+g_losses,g_entries,
                              g_exits,g_wins,g_losses,g_realized_pnl,g_blocks,
                              g_guard.StreakLosses(),(g_halted ? "HALTED" : "ACTIVE"),
                              (InpRequireParity ? "REQUIRED" : "OFF"),
                              (InpEnableExecution ? "DEMO_EXECUTION" : "DRY_RUN"));
   //--- Keep the census counters in the archived journal: the tester log is
   //--- not part of the report archive.
   if(g_census!=INVALID_HANDLE)
      detail+="|"+Ww2CensusSummary(g_census_stats);
   LogEvent("SUMMARY",SIM_SIDE_NONE,0.0,g_pos.volume,g_pos.entry,
            g_pos.initial_sl,g_pos.tp,detail);
  }

//+------------------------------------------------------------------+
//| MT5 events                                                       |
//+------------------------------------------------------------------+
int CreateHandles(string &error)
  {
   g_h_m1=iCustom(_Symbol,PERIOD_M1,"PinePort\\Wonderwhales",InpSignalMode,
                  InpPsarStart,InpPsarInc,InpPsarMax,InpFastEma,InpSlowEma,
                  InpEma200,InpAtrLen,InpMinAtrPct,InpVolMaLen,InpRsiLen,InpBbLen,
                  InpBbMult);
   g_h_m5=iCustom(_Symbol,PERIOD_M5,"PinePort\\Wonderwhales",InpSignalMode,
                  InpPsarStart,InpPsarInc,InpPsarMax,InpFastEma,InpSlowEma,
                  InpEma200,InpAtrLen,InpMinAtrPct,InpVolMaLen,InpRsiLen,InpBbLen,
                  InpBbMult);
   g_h_m15=iCustom(_Symbol,PERIOD_M15,"PinePort\\Wonderwhales",InpSignalMode,
                   InpPsarStart,InpPsarInc,InpPsarMax,InpFastEma,InpSlowEma,
                   InpEma200,InpAtrLen,InpMinAtrPct,InpVolMaLen,InpRsiLen,InpBbLen,
                   InpBbMult);
   g_h_h1=iCustom(_Symbol,PERIOD_H1,"PinePort\\Wonderwhales",InpSignalMode,
                  InpPsarStart,InpPsarInc,InpPsarMax,InpFastEma,InpSlowEma,
                  InpEma200,InpAtrLen,InpMinAtrPct,InpVolMaLen,InpRsiLen,InpBbLen,
                  InpBbMult);
   g_h_d1=iCustom(_Symbol,PERIOD_D1,"PinePort\\Wonderwhales",InpSignalMode,
                  InpPsarStart,InpPsarInc,InpPsarMax,InpFastEma,InpSlowEma,
                  InpEma200,InpAtrLen,InpMinAtrPct,InpVolMaLen,InpRsiLen,InpBbLen,
                  InpBbMult);
   g_h_w1=iCustom(_Symbol,PERIOD_W1,"PinePort\\Wonderwhales",InpSignalMode,
                  InpPsarStart,InpPsarInc,InpPsarMax,InpFastEma,InpSlowEma,
                  InpEma200,InpAtrLen,InpMinAtrPct,InpVolMaLen,InpRsiLen,InpBbLen,
                  InpBbMult);
   if(g_h_m1==INVALID_HANDLE || g_h_m5==INVALID_HANDLE || g_h_m15==INVALID_HANDLE ||
      g_h_h1==INVALID_HANDLE || g_h_d1==INVALID_HANDLE || g_h_w1==INVALID_HANDLE)
     {
      error=StringFormat("indicator_init_failed|error=%d",GetLastError());
      return(false);
     }
   return(true);
  }

int OnInit(void)
  {
   string error="";
   if(!ValidateInputs(error))
     {
      PrintFormat("LAB|ERROR|ww2|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   Ww2ResetPosition(g_pos);

   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   g_digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   g_tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(!SimValidatePoint(g_point,error) || !(g_tick_size>0.0))
     {
      PrintFormat("LAB|ERROR|ww2|symbol_data_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_stops_level=BrokerStopPoints();
   g_volume_min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   g_volume_max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   g_volume_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(!(g_volume_min>0.0) || !(g_volume_step>0.0) || g_volume_max<g_volume_min)
     {
      PrintFormat("LAB|ERROR|ww2|symbol_volume_invalid|min=%.4f|max=%.4f|step=%.4f",
                  g_volume_min,g_volume_max,g_volume_step);
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_is_hedging=(AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);

   //--- Demo/tester gate. Real/contest accounts are rejected at OnInit.
   ExecAccountState state;
   state.trade_mode=AccountInfoInteger(ACCOUNT_TRADE_MODE);
   state.account_trade_allowed=(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)!=0);
   state.terminal_trade_allowed=(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0);
   state.tester=(MQLInfoInteger(MQL_TESTER)!=0);
   ENUM_EXEC_BLOCK block=EXEC_OK;
   if(!ExecContextAllowed(state,block))
     {
      PrintFormat("LAB|ERROR|ww2|context_denied|reason=%s",ExecBlockName(block));
      return(INIT_FAILED);
     }
   if(InpEnableExecution && !ExecSymbolAllowed(_Symbol,InpAllowedSymbols))
     {
      PrintFormat("LAB|ERROR|ww2|symbol_denied|symbol=%s|allowed=%s",
                  _Symbol,InpAllowedSymbols);
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(!g_guard.Init(InpMaxDailyLossPct,InpMaxWeeklyLossPct,InpMaxDrawdownPct,
                    InpMaxConsecutiveLosses,InpCooldownMinutes,error))
     {
      PrintFormat("LAB|ERROR|ww2|risk_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(!CreateHandles(error))
     {
      PrintFormat("LAB|ERROR|ww2|%s",error);
      return(INIT_FAILED);
     }

   g_timeframe_text=Ww2ModeName(InpTradingMode);
   g_strike_tf_text=EnumToString(StrikeTimeframe(InpTradingMode==WW2_SCALP ? WW2_SCALP : InpTradingMode));
   UpdateAccountState();
   g_config_hash=BuildConfigHash();

   bool restored=false;
   if(InpPersistState && InpResetStateOnInit)
     {
      FileDelete(InpStateFile);
      PrintFormat("LAB|INFO|ww2|state_reset_on_init|file_deleted=%s",InpStateFile);
     }
   const bool state_ok=ReadStateFile(restored);
   if(!state_ok && InpPersistState && !InpResetStateOnInit)
      PrintFormat("LAB|INFO|ww2|state_not_restored|file=%s",InpStateFile);

   if(!g_guard.Refresh(g_equity,TimeCurrent(),error))
      { /* no halt on first refresh */ }
   SyncHalt();

   //--- A kill-switch halt is released once the operator removed the file and
   //--- restarted (ADR 0009 recovery); every other halt stays sticky.
   if(!FileIsExist(InpKillSwitchFile))
     {
      g_guard.ClearHalt("kill_switch_active");
      SyncHalt();
     }

   if(InpEnableLog)
     {
      if(!g_logger.Open(InpLogFile,error))
        {
         PrintFormat("LAB|ERROR|ww2|log_open_failed|%s",error);
         return(INIT_FAILED);
        }
     }
   if(InpEnableTelemetry)
     {
      if(!Ww2TelemetryOpen(InpTelemetryFile,g_tele))
         PrintFormat("LAB|WARN|ww2|telemetry_open_failed|file=%s",InpTelemetryFile);
     }
   if(InpDebug)
     {
      const string census_file=CensusFileName();
      Ww2CensusReset(g_census_stats);
      if(!Ww2CensusOpen(census_file,g_census))
         PrintFormat("LAB|WARN|ww2|census_open_failed|file=%s",census_file);
      else
         PrintFormat("LAB|INFO|ww2|census_enabled|file=%s",census_file);
     }

   ReconcilePosition();
   UpdateAccountState();
   SyncHalt();

   const string mode=(InpEnableExecution ? "DEMO_EXECUTION" : "DRY_RUN");
   LogEvent("INIT",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,
            StringFormat("execution=%s|trading_mode=%s|signal=%s|symbol=%s|allowed=%s|"
                         "magic=%d|tp_r=%.2f|risk_pct=%.2f|parity=%s|hash=%s|"
                         "equity=%.2f|restored=%d",
                         mode,Ww2ModeName(InpTradingMode),EnumToString(InpSignalMode),
                         _Symbol,InpAllowedSymbols,(int)InpMagicNumber,InpTakeProfitR,
                         InpRiskPercent,(InpRequireParity ? "REQUIRED" : "OFF"),
                         g_config_hash,g_equity,(restored ? 1 : 0)));
   PrintFormat("LAB|INFO|ww2|initialized|mode=%s|signal=%d|hash=%s|magic=%d|tester=%d|"
               "restored=%d|hedging=%d|stops_level=%.0f|parity=%d",
               Ww2ModeName(InpTradingMode),(int)InpSignalMode,g_config_hash,
               (int)InpMagicNumber,(int)MQLInfoInteger(MQL_TESTER),(restored ? 1 : 0),
               (g_is_hedging ? 1 : 0),g_stops_level,(InpRequireParity ? 1 : 0));
   if(!InpEnableExecution)
      PrintFormat("LAB|INFO|ww2|dry_run|no_orders_are_sent");
   UpdatePanel(SymbolInfoDouble(_Symbol,SYMBOL_BID),SymbolInfoDouble(_Symbol,SYMBOL_ASK));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   SaveState();
   WriteSummary();
   g_logger.Close();
   Ww2TelemetryClose(g_tele);
   if(g_census!=INVALID_HANDLE)
      PrintFormat("LAB|INFO|ww2|census_summary|%s",Ww2CensusSummary(g_census_stats));
   Ww2CensusClose(g_census);
   if(g_h_m1!=INVALID_HANDLE)
      IndicatorRelease(g_h_m1);
   if(g_h_m5!=INVALID_HANDLE)
      IndicatorRelease(g_h_m5);
   if(g_h_m15!=INVALID_HANDLE)
      IndicatorRelease(g_h_m15);
   if(g_h_h1!=INVALID_HANDLE)
      IndicatorRelease(g_h_h1);
   if(g_h_d1!=INVALID_HANDLE)
      IndicatorRelease(g_h_d1);
   if(g_h_w1!=INVALID_HANDLE)
      IndicatorRelease(g_h_w1);
   Comment("");
   PrintFormat("LAB|INFO|ww2|deinit|reason=%d|entries=%d|exits=%d|net=%.2f",
               reason,g_entries,g_exits,g_realized_pnl);
  }

void OnTick(void)
  {
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0 || ask<=0.0)
      return;

   UpdateAccountState();

   if(StringLen(ExecTrim(InpKillSwitchFile))>0 && FileIsExist(InpKillSwitchFile))
     {
      if(g_pos.have && InpCloseOnKillSwitch)
         CloseAtMarket("KILL_SWITCH");
      Halt("kill_switch_active");
      UpdatePanel(bid,ask);
      return;
     }

   ReconcilePosition();
   SyncHalt();
   if(g_halted)
     {
      const datetime halt_bar=iTime(_Symbol,_Period,0);
      const bool halt_new=(halt_bar!=g_last_bar);
      if(halt_new)
         g_last_bar=halt_bar;
      //--- InpHaltOnBreach=true (default) promotes a guard breach to a full
      //--- halt and flatten. When false, entries stay blocked but the position
      //--- keeps its broker SL/TP and its management.
      if(InpHaltOnBreach && g_pos.have)
         CloseAtMarket("RISK_HALT");
      else if(g_pos.have && halt_new)
         ManagePosition(halt_bar);
      UpdatePanel(bid,ask);
      return;
     }

   //--- Signal-based work needs enough closed history; the emergency controls
   //--- above already ran.
   if(Bars(_Symbol,_Period)<InpWarmupBars+5)
      return;

   const datetime bar_time=iTime(_Symbol,_Period,0);
   const bool new_bar=(bar_time!=g_last_bar);
   if(new_bar)
      g_last_bar=bar_time;

   //--- Diagnostic census: independent of the entry path, so it also records
   //--- the signals a parity gate or a sizing block would have suppressed.
   if(new_bar && !g_pos.have)
      CensusBar(bar_time);

   if(g_pos.have)
     {
      if(new_bar)
         ManagePosition(bar_time);
     }
   else if(InpTradingMode==WW2_SIGNAL_ONLY)
     {
      //--- Observation mode: log the signal each new bar, send nothing.
      if(new_bar)
        {
         const ENUM_TIMEFRAMES strike=StrikeTimeframe(WW2_SCALP);
         Ww2Signal s;
         if(Ww2ReadSignal(HandleFor(strike),_Symbol,strike,1,s))
            g_signal_text=(s.buy ? "BUY" : (s.sell ? "SELL" : "none"));
        }
     }
   else if(new_bar && bar_time!=g_last_exit_bar)
      TryEnter(bar_time);

   UpdatePanel(bid,ask);
  }
//+------------------------------------------------------------------+
