//+------------------------------------------------------------------+
//|                                        WonderwhalesDemoEA.mq5    |
//|     Demo-account execution for the Wonderwhales strategy (ADR 0007)|
//|                                                                  |
//| Sends real orders, but only on a DEMO account or in the Strategy  |
//| Tester. Every order goes through mt5/Include/Exec/ExecBroker.mqh  |
//| (the single order-send point) after ExecGuard checks. One         |
//| position, mandatory SL/TP, risk-percent sizing and a kill switch. |
//| Signals come from iCustom PinePort\\Wonderwhales.                 |
//| No credentials, no login, no WebRequest, no sockets.              |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Demo-only Wonderwhales execution: real orders on a DEMO account or Strategy Tester."
#property description "Signals from iCustom PinePort\\Wonderwhales, mandatory SL/TP, no live trading."

#include "../Include/Exec/ExecGuard.mqh"
#include "../Include/Exec/ExecBroker.mqh"
#include "../Include/Sim/SimRiskGuard.mqh"
#include "../Include/Sim/SimLogger.mqh"
#include "../Include/Sim/SimValidate.mqh"
#include "../Include/PinePort/WonderwhalesContract.mqh"

#define WW_DEMO_STATE_VERSION 1

enum ENUM_WW_STOP_MODE
  {
   WW_STOP_PSAR    = 0,   // PSAR line from the signal bar
   WW_STOP_ATR_PCT = 1,   // price * atr_pct/100 * multiplier
   WW_STOP_FIXED   = 2    // fixed distance in points
  };

enum ENUM_WW_SIDE_FILTER
  {
   WW_SIDE_BOTH       = 0,
   WW_SIDE_LONG_ONLY  = 1,
   WW_SIDE_SHORT_ONLY = 2
  };

input group "Demo execution"
input bool   InpEnableExecution     = true;                     // false = dry-run, no orders (ADR 0006: true by default)
input string InpAllowedSymbols      = "XAUUSD";                 // prefix allow-list, comma separated
input long   InpMagicNumber         = 25007001;
input int    InpMaxSlippagePoints   = 30;                       // deviation for market orders
input string InpKillSwitchFile      = "WONDERWHALES_DEMO_STOP.txt";
input bool   InpCloseOnKillSwitch   = true;

input group "Journal and state"
input bool   InpEnableLog           = true;                     // write CSV to MQL5/Files
input string InpLogFile             = "wonderwhales_demo.csv";
input bool   InpDebug               = false;
input bool   InpPersistState        = true;
input string InpStateFile           = "wonderwhales_demo_state.csv";
input bool   InpResetStateOnInit    = false;

input group "Wonderwhales signal"
input ENUM_WW_MODE InpMode          = WW_MODE_SAR;
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
input int    InpWarmupBars          = 300;      // closed bars required before entries
input ENUM_WW_SIDE_FILTER InpSideFilter = WW_SIDE_BOTH;

input group "Stops and target"
input ENUM_WW_STOP_MODE InpStopMode = WW_STOP_PSAR;
input double InpAtrPctMultiplier    = 2.0;      // used by ATR% mode
input double InpFixedStopPoints     = 3000.0;   // used by fixed mode
input double InpMinStopPoints       = 150.0;    // minimum SL distance from entry
input double InpTakeProfitR         = 2.0;      // mandatory TP = entry +/- R * SL distance
input int    InpMaxHoldingBars      = 0;        // 0 = disabled
input bool   InpExitOnFlip          = true;     // close on the opposite signal

input group "Risk"
input double InpRiskPercent         = 1.0;      // equity risked per entry (demo)
input double InpMaxLots             = 0.10;     // exposure cap per entry
input double InpMaxSpreadPoints     = 600.0;
input int    InpCooldownBars        = 1;
input double InpMaxDailyLossPct     = 2.0;      // 0 = disabled
input double InpMaxDrawdownPct      = 8.0;      // 0 = disabled
input int    InpMaxConsecutiveLosses= 3;        // 0 = disabled
input int    InpCooldownMinutes     = 30;
input bool   InpHaltOnBreach        = true;

CSimRiskGuard    g_risk;
CSimLogger       g_logger;

int      g_handle=INVALID_HANDLE;
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

double   g_mid=0.0;
double   g_equity=0.0;
double   g_peak_equity=0.0;
double   g_day_start_equity=0.0;
long     g_day_key=0;
datetime g_block_until=0;
int      g_streak_losses=0;
bool     g_halted=false;
string   g_halt_reason="";

datetime g_last_bar=0;
datetime g_last_exit_bar=0;
datetime g_last_signal_bar=0;
string   g_signal_text="none";
string   g_last_block="none";

bool     g_have_pos=false;
ulong    g_pos_ticket=0;
bool     g_pos_is_buy=true;
double   g_pos_entry=0.0;
double   g_pos_volume=0.0;
double   g_pos_initial_sl=0.0;
double   g_pos_tp=0.0;
datetime g_pos_open_time=0;

int      g_entries=0;
int      g_exits=0;
int      g_wins=0;
int      g_losses=0;
int      g_blocks=0;
double   g_realized_pnl=0.0;

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
   if(InpMode<WW_MODE_SAR || InpMode>WW_MODE_SAR_EMA_ATR)
     {
      error="mode_out_of_range";
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
   if(!SimValidateCount(InpWarmupBars,"warmup_bars_must_be_non_negative",error))
      return(false);
   if(InpWarmupBars<InpEma200)
     {
      error="warmup_bars_must_cover_ema200";
      return(false);
     }
   if(InpSideFilter!=WW_SIDE_BOTH && InpSideFilter!=WW_SIDE_LONG_ONLY &&
      InpSideFilter!=WW_SIDE_SHORT_ONLY)
     {
      error="side_filter_out_of_range";
      return(false);
     }
   if(InpStopMode!=WW_STOP_PSAR && InpStopMode!=WW_STOP_ATR_PCT &&
      InpStopMode!=WW_STOP_FIXED)
     {
      error="stop_mode_out_of_range";
      return(false);
     }
   if(!SimIsFinite(InpAtrPctMultiplier) || InpAtrPctMultiplier<=0.0)
     {
      error="atr_pct_multiplier_must_be_positive";
      return(false);
     }
   if(!SimIsFinite(InpFixedStopPoints) || InpFixedStopPoints<=0.0)
     {
      error="fixed_stop_points_must_be_positive";
      return(false);
     }
   if(!SimIsFinite(InpMinStopPoints) || InpMinStopPoints<0.0)
     {
      error="min_stop_points_must_be_finite_non_negative";
      return(false);
     }
   if(!SimIsFinite(InpTakeProfitR) || InpTakeProfitR<=0.0)
     {
      error="take_profit_r_must_be_positive";
      return(false);
     }
   if(!SimValidateCount(InpMaxHoldingBars,
                        "max_holding_bars_must_be_non_negative",error))
      return(false);
   if(!SimValidateCount(InpCooldownBars,"cooldown_bars_must_be_non_negative",error))
      return(false);
   if(!SimValidateCount(InpMaxConsecutiveLosses,
                        "max_consecutive_losses_must_be_non_negative",error))
      return(false);
   if(!SimValidateCount(InpCooldownMinutes,
                        "cooldown_minutes_must_be_non_negative",error))
      return(false);
   if(!SimIsFinite(InpRiskPercent) || InpRiskPercent<=0.0 ||
      InpRiskPercent>10.0)
     {
      error="risk_percent_must_be_between_0_and_10";
      return(false);
     }
   if(!SimIsFinite(InpMaxLots) || InpMaxLots<=0.0 || InpMaxLots>100.0)
     {
      error="max_lots_must_be_between_0_and_100";
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
   return(true);
  }

string BuildConfigHash(void)
  {
   string text=g_risk.Fingerprint()+
               SimFormatFingerprintPartInt("wwdemo.magic",(long)InpMagicNumber)+
               SimFormatFingerprintPart("wwdemo.slippage",(double)InpMaxSlippagePoints,0)+
               SimFormatFingerprintPart("wwdemo.risk_pct",InpRiskPercent,4)+
               SimFormatFingerprintPart("wwdemo.max_lots",InpMaxLots,4)+
               SimFormatFingerprintPart("wwdemo.tp_r",InpTakeProfitR,4)+
               SimFormatFingerprintPartText("wwdemo.allowed",InpAllowedSymbols)+
               SimFormatFingerprintPartText("wwdemo.kill",InpKillSwitchFile)+
               SimFormatFingerprintPartInt("ww.mode",(int)InpMode)+
               SimFormatFingerprintPart("ww.psar_start",InpPsarStart,2)+
               SimFormatFingerprintPart("ww.psar_inc",InpPsarInc,2)+
               SimFormatFingerprintPart("ww.psar_max",InpPsarMax,2)+
               SimFormatFingerprintPartInt("ww.fast",InpFastEma)+
               SimFormatFingerprintPartInt("ww.slow",InpSlowEma)+
               SimFormatFingerprintPartInt("ww.ema200",InpEma200)+
               SimFormatFingerprintPartInt("ww.atr",InpAtrLen)+
               SimFormatFingerprintPart("ww.min_atr_pct",InpMinAtrPct,3)+
               SimFormatFingerprintPartInt("ww.vol_ma",InpVolMaLen)+
               SimFormatFingerprintPartInt("ww.rsi",InpRsiLen)+
               SimFormatFingerprintPartInt("ww.bb_len",InpBbLen)+
               SimFormatFingerprintPart("ww.bb_mult",InpBbMult,2)+
               SimFormatFingerprintPartInt("ww.warmup",InpWarmupBars)+
               SimFormatFingerprintPartInt("ww.side_filter",(int)InpSideFilter)+
               SimFormatFingerprintPartInt("ww.stop_mode",(int)InpStopMode)+
               SimFormatFingerprintPart("ww.atr_pct_mult",InpAtrPctMultiplier,2)+
               SimFormatFingerprintPart("ww.fixed_stop",InpFixedStopPoints,1)+
               SimFormatFingerprintPart("ww.min_stop",InpMinStopPoints,1)+
               SimFormatFingerprintPartInt("ww.max_hold",InpMaxHoldingBars)+
               SimFormatFingerprintPartInt("ww.exit_on_flip",(InpExitOnFlip ? 1 : 0))+
               SimFormatFingerprintPartInt("ww.max_losses",InpMaxConsecutiveLosses)+
               SimFormatFingerprintPartInt("ww.cooldown_min",InpCooldownMinutes);
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
   record.bar_time=(g_last_signal_bar>0 ? g_last_signal_bar
                                        : iTime(_Symbol,_Period,0));
   record.ea="WonderwhalesDemoEA";
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
   record.exposure=(g_have_pos ? g_pos_volume : 0.0);
   record.equity=g_equity;
   record.drawdown_pct=DrawdownPct();
   record.reason=reason;

   string error="";
   if(!g_logger.Write(record,error))
      PrintFormat("LAB|ERROR|ww_demo|log_write_failed|%s",error);
  }

//+------------------------------------------------------------------+
//| Account, day and halt tracking                                   |
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
      //--- The daily loss cap is a per-day lock, not a permanent stop: a new
      //--- trading day restores the entry budget. Drawdown and kill-switch
      //--- halts stay sticky until the operator restarts the EA.
      if(g_halted && StringFind(g_halt_reason,"daily_loss_limit_reached")==0)
        {
         g_halted=false;
         g_halt_reason="";
         LogEvent("RESUME",SIM_SIDE_NONE,0.0,g_pos_volume,g_pos_entry,
                  g_pos_initial_sl,g_pos_tp,
                  StringFormat("daily_loss_lock_cleared|day_key=%d",(int)key));
         SaveState();
        }
      if(InpDebug)
         PrintFormat("LAB|DEBUG|ww_demo|day_rollover|key=%d",key);
     }
  }

void Halt(const string reason)
  {
   if(g_halted)
      return;
   g_halted=true;
   g_halt_reason=reason;
   PrintFormat("LAB|WARN|ww_demo|halted|reason=%s",reason);
   LogEvent("HALT",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,
            "reason="+reason);
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
      PrintFormat("LAB|ERROR|ww_demo|state_write_failed|error=%d",GetLastError());
      return;
     }
   FileWriteString(handle,"state_version="+IntegerToString(WW_DEMO_STATE_VERSION)+"\r\n");
   FileWriteString(handle,"magic="+IntegerToString((long)InpMagicNumber)+"\r\n");
   FileWriteString(handle,"saved_at="+TimeToString(TimeCurrent())+"\r\n");
   FileWriteString(handle,StringFormat("peak_equity=%.8f\r\n",g_peak_equity));
   FileWriteString(handle,"day_key="+IntegerToString(g_day_key)+"\r\n");
   FileWriteString(handle,StringFormat("day_start_equity=%.8f\r\n",g_day_start_equity));
   FileWriteString(handle,"block_until="+IntegerToString((long)g_block_until)+"\r\n");
   FileWriteString(handle,"streak_losses="+IntegerToString(g_streak_losses)+"\r\n");
   FileWriteString(handle,"halted="+string(g_halted ? "1" : "0")+"\r\n");
   FileWriteString(handle,"halt_reason="+g_halt_reason+"\r\n");
   FileWriteString(handle,"pos_ticket="+IntegerToString((long)g_pos_ticket)+"\r\n");
   FileWriteString(handle,"pos_is_buy="+string(g_pos_is_buy ? "1" : "0")+"\r\n");
   FileWriteString(handle,StringFormat("pos_entry=%.8f\r\n",g_pos_entry));
   FileWriteString(handle,StringFormat("pos_volume=%.8f\r\n",g_pos_volume));
   FileWriteString(handle,StringFormat("pos_initial_sl=%.8f\r\n",g_pos_initial_sl));
   FileWriteString(handle,StringFormat("pos_tp=%.8f\r\n",g_pos_tp));
   FileWriteString(handle,"pos_open_time="+IntegerToString((long)g_pos_open_time)+"\r\n");
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

   bool version_ok=false;
   bool magic_ok=false;
   double peak=0.0,day_start=0.0;
   long day_key=0;
   datetime block_until=0;
   int streak=0;
   bool halted=false;
   string halt_reason="";
   ulong pos_ticket=0;
   bool pos_is_buy=true;
   double pos_entry=0.0,pos_volume=0.0,pos_initial_sl=0.0,pos_tp=0.0;
   datetime pos_open_time=0;

   while(!FileIsEnding(handle))
     {
      const string line=FileReadString(handle);
      const int eq=StringFind(line,"=");
      if(eq<=0)
         continue;
      const string key=StringSubstr(line,0,eq);
      const string value=StringSubstr(line,eq+1);
      if(key=="state_version")
         version_ok=(StringToInteger(value)==WW_DEMO_STATE_VERSION);
      else if(key=="magic")
         magic_ok=(StringToInteger(value)==InpMagicNumber);
      else if(key=="peak_equity")
         peak=StringToDouble(value);
      else if(key=="day_key")
         day_key=StringToInteger(value);
      else if(key=="day_start_equity")
         day_start=StringToDouble(value);
      else if(key=="block_until")
         block_until=(datetime)StringToInteger(value);
      else if(key=="streak_losses")
         streak=(int)StringToInteger(value);
      else if(key=="halted")
         halted=(value=="1");
      else if(key=="halt_reason")
         halt_reason=value;
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
      else if(key=="pos_tp")
         pos_tp=StringToDouble(value);
      else if(key=="pos_open_time")
         pos_open_time=(datetime)StringToInteger(value);
     }
   FileClose(handle);

   if(!version_ok || !magic_ok)
      return(false);

   if(peak>0.0)
      g_peak_equity=peak;
   g_day_key=day_key;
   if(day_start>0.0)
      g_day_start_equity=day_start;
   g_block_until=block_until;
   if(streak>0)
      g_streak_losses=streak;
   g_halted=halted;
   g_halt_reason=halt_reason;
   g_pos_ticket=pos_ticket;
   g_pos_is_buy=pos_is_buy;
   g_pos_entry=pos_entry;
   g_pos_volume=pos_volume;
   g_pos_initial_sl=pos_initial_sl;
   g_pos_tp=pos_tp;
   g_pos_open_time=pos_open_time;
   g_have_pos=(pos_ticket>0);
   restored=true;
   return(true);
  }

//+------------------------------------------------------------------+
//| Chart panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel(const double bid,const double ask)
  {
   const string mode=(InpEnableExecution ? "DEMO_EXECUTION" : "DRY_RUN");
   const string position=(g_have_pos
                          ? StringFormat("%s %.2f @ %.3f",
                                         (g_pos_is_buy ? "BUY" : "SELL"),
                                         g_pos_volume,g_pos_entry)
                          : "flat");
   const string state=(g_halted ? "HALTED: "+g_halt_reason
                                : (g_block_until>TimeCurrent()
                                   ? "COOLDOWN"
                                   : "ACTIVE"));
   Comment(StringFormat(
      "Wonderwhales demo v1.00 | %s | %s %s\n"
      "hash=%s  magic=%d  spread=%.1f pts\n"
      "signal=%s  position=%s\n"
      "equity=%.2f  dd=%.2f%%  day=%.2f%%\n"
      "entries=%d  exits=%d  W/L=%d/%d  streak=%d\n"
      "state=%s  last_block=%s",
      mode,_Symbol,g_timeframe_text,g_config_hash,(int)InpMagicNumber,
      (ask>bid && g_point>0.0 ? (ask-bid)/g_point : 0.0),
      g_signal_text,position,g_equity,DrawdownPct(),DailyLossPct(),
      g_entries,g_exits,g_wins,g_losses,g_streak_losses,state,g_last_block));
  }

//+------------------------------------------------------------------+
//| Signal reading                                                   |
//+------------------------------------------------------------------+
bool ReadSignalBar(const int shift,double &buy_signal,double &sell_signal,
                   double &psar,double &atr_pct)
  {
   double buy_buf[],sell_buf[],psar_buf[],atr_buf[];
   ArraySetAsSeries(buy_buf,true);
   ArraySetAsSeries(sell_buf,true);
   ArraySetAsSeries(psar_buf,true);
   ArraySetAsSeries(atr_buf,true);

   if(CopyBuffer(g_handle,WW_BUF_BUY_SIGNAL,shift,1,buy_buf)<1)
      return(false);
   if(CopyBuffer(g_handle,WW_BUF_SELL_SIGNAL,shift,1,sell_buf)<1)
      return(false);
   if(CopyBuffer(g_handle,WW_BUF_PSAR,shift,1,psar_buf)<1)
      return(false);
   if(CopyBuffer(g_handle,WW_BUF_ATR_PCT,shift,1,atr_buf)<1)
      return(false);

   buy_signal=buy_buf[0];
   sell_signal=sell_buf[0];
   psar=psar_buf[0];
   atr_pct=atr_buf[0];
   return(SimIsFinite(buy_signal) && SimIsFinite(sell_signal));
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

//+------------------------------------------------------------------+
//| Position lifecycle                                               |
//+------------------------------------------------------------------+
void ResetPositionContext(void)
  {
   g_have_pos=false;
   g_pos_ticket=0;
   g_pos_entry=0.0;
   g_pos_volume=0.0;
   g_pos_initial_sl=0.0;
   g_pos_tp=0.0;
   g_pos_open_time=0;
  }

void ApplyClosedPnl(const double pnl,const bool known)
  {
   if(known)
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
         g_block_until=0;
        }
     }
   if(InpMaxConsecutiveLosses>0 && g_streak_losses>=InpMaxConsecutiveLosses &&
      InpCooldownMinutes>0)
      g_block_until=TimeCurrent()+InpCooldownMinutes*60;
   g_exits++;
  }

//--- A position that vanished without an explicit EA close (broker SL/TP).
void FinalizeClosedPosition(void)
  {
   double pnl=0.0;
   int deals=0;
   bool known=false;
   if(g_pos_ticket>0 && g_pos_open_time>0)
     {
      if(ExecClosedPnl(g_pos_ticket,g_pos_open_time-3600,pnl,deals))
         known=true;
      else if(ExecClosedPnl(g_pos_ticket,g_pos_open_time-86400,pnl,deals))
         known=true;
     }

   ApplyClosedPnl(pnl,known);
   g_last_exit_bar=iTime(_Symbol,_Period,0);
   LogEvent("EXIT",(g_pos_is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),0.0,
            g_pos_volume,g_pos_entry,g_pos_initial_sl,g_pos_tp,
            StringFormat("BROKER_EXIT|pnl_known=%d|pnl=%.2f|deals=%d|streak=%d",
                         (known ? 1 : 0),pnl,deals,g_streak_losses));
   PrintFormat("LAB|INFO|ww_demo|exit|reason=BROKER_EXIT|pnl=%.2f|exits=%d",
               pnl,g_exits);
   ResetPositionContext();
   SaveState();
  }

bool CloseAtMarket(const string reason)
  {
   if(!g_have_pos)
      return(false);
   if(!InpEnableExecution)
     {
      LogEvent("DRY_RUN",(g_pos_is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),
               0.0,g_pos_volume,g_pos_entry,g_pos_initial_sl,g_pos_tp,
               "would_close|reason="+reason);
      return(false);
     }

   ExecFillResult fill;
   if(!ExecClosePosition(g_pos_ticket,g_pos_is_buy,g_pos_volume,
                         InpMaxSlippagePoints,InpMagicNumber,"WW_DEMO_CLOSE",
                         fill))
     {
      LogEvent("ERROR",(g_pos_is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),0.0,
               g_pos_volume,g_pos_entry,g_pos_initial_sl,g_pos_tp,
               "close_failed|reason="+reason+"|"+fill.message);
      return(false);
     }

   double pnl=0.0;
   int deals=0;
   bool known=false;
   if(g_pos_ticket>0 && g_pos_open_time>0)
      known=ExecClosedPnl(g_pos_ticket,g_pos_open_time-3600,pnl,deals);
   ApplyClosedPnl(pnl,known);
   g_last_exit_bar=iTime(_Symbol,_Period,0);

   LogEvent("EXIT",(g_pos_is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),fill.price,
            g_pos_volume,g_pos_entry,g_pos_initial_sl,g_pos_tp,
            StringFormat("%s|close_price=%.3f|pnl_known=%d|pnl=%.2f|deals=%d|"
                         "streak=%d|%s",
                         reason,fill.price,(known ? 1 : 0),pnl,deals,
                         g_streak_losses,fill.message));
   PrintFormat("LAB|INFO|ww_demo|exit|reason=%s|price=%.3f|pnl=%.2f",
               reason,fill.price,pnl);
   ResetPositionContext();
   SaveState();
   return(true);
  }

//--- ADR 0004: every position must carry both stops. If the broker holds the
//--- position without them (for example after an external edit), re-assert
//--- the intended SL/TP instead of continuing with a naked position.
void EnsureStops(void)
  {
   if(!g_have_pos || !InpEnableExecution)
      return;
   if(!(g_pos_initial_sl>0.0) || !(g_pos_tp>0.0))
      return;

   ExecPositionInfo info;
   if(!ExecFindOwnPosition(InpMagicNumber,info))
      return;
   if(info.sl>0.0 && info.tp>0.0)
      return;

   ExecFillResult result;
   if(!ExecModifyStops(info.ticket,g_pos_initial_sl,g_pos_tp,result))
     {
      LogEvent("ERROR",(g_pos_is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),
               info.open_price,info.volume,g_pos_entry,g_pos_initial_sl,
               g_pos_tp,"stops_reassert_failed|"+result.message);
      return;
     }
   LogEvent("STOPS_REASSERT",(g_pos_is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),
            result.price,info.volume,g_pos_entry,g_pos_initial_sl,g_pos_tp,
            "sl_tp_reasserted|"+result.message);
  }

//--- Keep g_have_pos in sync with the broker. A restart adopts the real
//--- position instead of opening a second one.
void ReconcilePosition(void)
  {
   ExecPositionInfo info;
   const bool found=ExecFindOwnPosition(InpMagicNumber,info);

   if(g_have_pos && !found)
     {
      FinalizeClosedPosition();
      return;
     }
   if(!g_have_pos && found)
     {
      g_have_pos=true;
      g_pos_ticket=info.ticket;
      g_pos_is_buy=(info.type==POSITION_TYPE_BUY);
      g_pos_entry=info.open_price;
      g_pos_volume=info.volume;
      g_pos_initial_sl=info.sl;
      g_pos_tp=info.tp;
      g_pos_open_time=info.open_time;
      LogEvent("ADOPT",(g_pos_is_buy ? SIM_SIDE_BUY : SIM_SIDE_SELL),
               info.open_price,info.volume,info.open_price,info.sl,info.tp,
               "adopted_position_from_broker");
      SaveState();
      return;
     }
   if(g_have_pos && found)
     {
      g_pos_ticket=info.ticket;
      g_pos_volume=info.volume;
      if(info.sl>0.0)
         g_pos_initial_sl=info.sl;
      if(info.tp>0.0)
         g_pos_tp=info.tp;
      EnsureStops();
     }
  }

void CheckEquityHalts(void)
  {
   if(!g_halted && InpMaxDailyLossPct>0.0 &&
      DailyLossPct()>=InpMaxDailyLossPct)
      Halt(StringFormat("daily_loss_limit_reached|loss=%.2f%%",DailyLossPct()));
   if(!g_halted && InpMaxDrawdownPct>0.0 &&
      DrawdownPct()>=InpMaxDrawdownPct)
      Halt(StringFormat("max_drawdown_reached|dd=%.2f%%",DrawdownPct()));
   if(g_halted && g_have_pos)
      CloseAtMarket("RISK_HALT");
  }

//+------------------------------------------------------------------+
//| Stop, target and sizing                                          |
//+------------------------------------------------------------------+
double ResolveStopDistance(const bool is_buy,const double reference,
                           const double psar,const double atr_pct,
                           string &reason)
  {
   reason="";
   double distance=0.0;
   if(InpStopMode==WW_STOP_FIXED)
     {
      distance=InpFixedStopPoints*g_point;
      reason="mode=fixed";
     }
   else if(InpStopMode==WW_STOP_ATR_PCT)
     {
      if(!(atr_pct>0.0))
        {
         reason="atr_pct_missing";
         return(0.0);
        }
      distance=reference*(atr_pct/100.0)*InpAtrPctMultiplier;
      reason=StringFormat("mode=atr_pct|atr_pct=%.4f",atr_pct);
     }
   else
     {
      if(!(psar>0.0))
        {
         reason="psar_missing";
         return(0.0);
        }
      if(is_buy && psar>=reference)
        {
         reason="psar_wrong_side";
         return(0.0);
        }
      if(!is_buy && psar<=reference)
        {
         reason="psar_wrong_side";
         return(0.0);
        }
      distance=MathAbs(reference-psar);
      reason="mode=psar";
     }
   return(distance);
  }

bool SizeVolume(const bool is_buy,const double entry,const double sl,
                const double risk_money,double &volume,string &reason)
  {
   volume=0.0;
   const double cap=MathMin(InpMaxLots,g_volume_max);
   if(!(g_volume_min>0.0) || !(g_volume_step>0.0) || cap<g_volume_min)
     {
      reason="volume_constraints_invalid";
      return(false);
     }

   double loss_per_lot=0.0;
   if(!ExecCalcProfit(is_buy,1.0,entry,sl,loss_per_lot))
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
   const double floored=MathFloor(raw/g_volume_step)*g_volume_step;
   if(!(floored>=g_volume_min))
     {
      reason=StringFormat("min_lot_over_budget|min_lot_loss=%.2f|budget=%.2f",
                          loss_per_lot*g_volume_min,risk_money);
      return(false);
     }

   const double final_volume=MathMin(floored,cap);
   double final_loss=0.0;
   if(!ExecCalcProfit(is_buy,final_volume,entry,sl,final_loss))
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
   volume=ExecNormalizeVolume(final_volume,g_volume_min,g_volume_max,g_volume_step);
   if(!(volume>0.0))
     {
      reason="volume_normalized_to_zero";
      return(false);
     }
   reason=StringFormat("lots=%.4f|loss=%.2f|budget=%.2f",
                       volume,MathAbs(final_loss),risk_money);
   return(true);
  }

//+------------------------------------------------------------------+
//| Entry                                                            |
//+------------------------------------------------------------------+
void BlockEntry(const ENUM_SIM_SIDE side,const string token,const string detail)
  {
   g_blocks++;
   g_last_block=token;
   LogEvent("RISK",side,g_mid,0.0,0.0,0.0,0.0,
            "ENTRY_BLOCKED|reason="+token+(StringLen(detail)>0 ? "|"+detail : ""));
  }

bool TryEnter(const datetime bar_time)
  {
   if(g_have_pos || g_halted)
      return(false);
   if(bar_time==g_last_exit_bar)
      return(false);
   if(Bars(_Symbol,_Period)<InpWarmupBars+5)
      return(false);
   if(InpMaxConsecutiveLosses>0 && g_streak_losses>=InpMaxConsecutiveLosses &&
      g_block_until>TimeCurrent())
     {
      BlockEntry(SIM_SIDE_NONE,"consecutive_loss_cooldown",
                 StringFormat("streak=%d|until=%s",g_streak_losses,
                              TimeToString(g_block_until)));
      return(false);
     }

   double buy_signal=0.0,sell_signal=0.0,psar=0.0,atr_pct=0.0;
   if(!ReadSignalBar(1,buy_signal,sell_signal,psar,atr_pct))
      return(false);

   ENUM_SIM_SIDE signal=SIM_SIDE_NONE;
   if(buy_signal>0.5)
      signal=SIM_SIDE_BUY;
   else if(sell_signal>0.5)
      signal=SIM_SIDE_SELL;
   if(signal==SIM_SIDE_NONE)
      return(false);

   g_signal_text=(signal==SIM_SIDE_BUY ? "BUY" : "SELL");
   if((InpSideFilter==WW_SIDE_LONG_ONLY && signal==SIM_SIDE_SELL) ||
      (InpSideFilter==WW_SIDE_SHORT_ONLY && signal==SIM_SIDE_BUY))
     {
      BlockEntry(signal,"side_filter","mode="+EnumToString(InpSideFilter));
      return(false);
     }

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
   const bool is_buy=(signal==SIM_SIDE_BUY);
   const double reference=(is_buy ? ask : bid);
   const double spread_points=(ask-bid)/g_point;

   string stop_reason="";
   const double distance=ResolveStopDistance(is_buy,reference,psar,atr_pct,
                                             stop_reason);
   if(!(distance>0.0) || distance<InpMinStopPoints*g_point)
     {
      BlockEntry(signal,"STOP_REJECTED",
                 StringFormat("%s|distance_points=%.2f|min_points=%.1f",
                              stop_reason,distance/g_point,InpMinStopPoints));
      return(false);
     }

   const double sl=NormalizePrice(is_buy ? reference-distance
                                         : reference+distance);
   const double tp=NormalizePrice(ExecTakeProfitPrice(is_buy,reference,sl,
                                                      InpTakeProfitR));
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
   double volume=0.0;
   string size_reason="";
   if(!SizeVolume(is_buy,reference,sl,risk_money,volume,size_reason))
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

   SimRiskContext ctx;
   ctx.spread_points=spread_points;
   ctx.price_valid=true;
   ctx.open_positions=0;
   ctx.grid_levels=0;
   ctx.dca_adds=0;
   ctx.exposure=0.0;
   ctx.volume_to_add=volume;
   ctx.equity=g_equity;
   ctx.day_start_equity=g_day_start_equity;
   ctx.peak_equity=g_peak_equity;
   ctx.bar_time=bar_time;

   const SimRiskDecision decision=g_risk.Evaluate(ctx);
   if(!decision.allowed)
     {
      BlockEntry(signal,decision.reason,
                 "state="+SimRiskStateName(decision.state));
      if(decision.state==SIM_RISK_HALTED && InpHaltOnBreach)
         Halt(decision.reason);
      return(false);
     }

   g_last_signal_bar=bar_time;
   if(!InpEnableExecution)
     {
      LogEvent("DRY_RUN",signal,reference,volume,reference,sl,tp,
               StringFormat("would_open|%s|spread_points=%.1f",
                            size_reason,spread_points));
      return(false);
     }

   ExecFillResult fill;
   if(!ExecOpenMarket(is_buy,volume,sl,tp,InpMaxSlippagePoints,
                      InpMagicNumber,"WW_DEMO",fill))
     {
      LogEvent("ERROR",signal,0.0,volume,reference,sl,tp,
               "open_failed|"+fill.message);
      PrintFormat("LAB|ERROR|ww_demo|open_failed|%s",fill.message);
      return(false);
     }

   g_entries++;
   g_have_pos=true;
   g_pos_ticket=fill.order;
   g_pos_is_buy=is_buy;
   g_pos_entry=fill.price;
   g_pos_volume=fill.volume;
   g_pos_initial_sl=sl;
   g_pos_tp=tp;
   g_pos_open_time=TimeCurrent();
   //--- ExecOpenMarket returns the order ticket, but the history calls need
   //--- the position ticket. Sync it when the broker already lists the
   //--- position; otherwise the next tick reconcile does it (no finalize
   //--- here: an async-visibility gap must not look like a close).
   ExecPositionInfo opened;
   if(ExecFindOwnPosition(InpMagicNumber,opened))
     {
      g_pos_ticket=opened.ticket;
      if(opened.volume>0.0)
         g_pos_volume=opened.volume;
     }
   g_risk.RecordEntry(bar_time);
   SaveState();

   LogEvent("ENTRY",signal,fill.price,fill.volume,fill.price,sl,tp,
            StringFormat("SIGNAL_%s|ticket=%d|%s|spread_points=%.1f|%s",
                         (is_buy ? "WW_BUY" : "WW_SELL"),(int)fill.order,
                         size_reason,spread_points,fill.message));
   PrintFormat("LAB|INFO|ww_demo|entry|side=%s|price=%.3f|volume=%.2f|"
               "sl=%.3f|tp=%.3f|ticket=%d|%s",
               (is_buy ? "BUY" : "SELL"),fill.price,fill.volume,sl,tp,
               (int)fill.order,size_reason);
   return(true);
  }

//+------------------------------------------------------------------+
//| Management on a new bar                                          |
//+------------------------------------------------------------------+
void ManagePosition(const datetime bar_time)
  {
   if(!g_have_pos)
      return;

   if(InpMaxHoldingBars>0)
     {
      const long bars_held=(long)(bar_time-g_pos_open_time)/
                           (long)PeriodSeconds(_Period);
      if(bars_held>=InpMaxHoldingBars)
        {
         CloseAtMarket(StringFormat("MAX_HOLDING_BARS|bars=%d",(int)bars_held));
         return;
        }
     }

   if(!InpExitOnFlip)
      return;

   double buy_signal=0.0,sell_signal=0.0,psar=0.0,atr_pct=0.0;
   if(!ReadSignalBar(1,buy_signal,sell_signal,psar,atr_pct))
      return;
   const bool flipped=(g_pos_is_buy ? sell_signal>0.5 : buy_signal>0.5);
   g_signal_text=(buy_signal>0.5 ? "BUY" : (sell_signal>0.5 ? "SELL" : "none"));
   if(flipped)
      CloseAtMarket("SIGNAL_FLIP");
  }

//+------------------------------------------------------------------+
//| Summary                                                          |
//+------------------------------------------------------------------+
void WriteSummary(void)
  {
   if(!g_logger.IsOpen())
      return;
   LogEvent("SUMMARY",SIM_SIDE_NONE,0.0,g_pos_volume,g_pos_entry,
            g_pos_initial_sl,g_pos_tp,
            StringFormat("trades=%d|entries=%d|exits=%d|wins=%d|losses=%d|"
                         "net=%.2f|blocks=%d|streak=%d|halted=%s|"
                         "execution=%s",
                         g_wins+g_losses,g_entries,g_exits,g_wins,g_losses,
                         g_realized_pnl,g_blocks,g_streak_losses,
                         (g_halted ? "HALTED" : "ACTIVE"),
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
      PrintFormat("LAB|ERROR|ww_demo|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   g_digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   g_tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(!SimValidatePoint(g_point,error) || !(g_tick_size>0.0))
     {
      PrintFormat("LAB|ERROR|ww_demo|symbol_data_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_stops_level=BrokerStopPoints();
   g_volume_min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   g_volume_max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   g_volume_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(!(g_volume_min>0.0) || !(g_volume_step>0.0) ||
      g_volume_max<g_volume_min)
     {
      PrintFormat("LAB|ERROR|ww_demo|symbol_volume_invalid|min=%.4f|max=%.4f|step=%.4f",
                  g_volume_min,g_volume_max,g_volume_step);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_is_hedging=(AccountInfoInteger(ACCOUNT_MARGIN_MODE)==
                 ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);

   //--- Hard demo gate: real/contest accounts are rejected at OnInit.
   ExecAccountState state;
   state.trade_mode=AccountInfoInteger(ACCOUNT_TRADE_MODE);
   state.account_trade_allowed=(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)!=0);
   state.terminal_trade_allowed=(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0);
   state.tester=(MQLInfoInteger(MQL_TESTER)!=0);

   ENUM_EXEC_BLOCK block=EXEC_OK;
   if(!ExecContextAllowed(state,block))
     {
      PrintFormat("LAB|ERROR|ww_demo|context_denied|reason=%s",
                  ExecBlockName(block));
      return(INIT_FAILED);
     }

   if(InpEnableExecution && !ExecSymbolAllowed(_Symbol,InpAllowedSymbols))
     {
      PrintFormat("LAB|ERROR|ww_demo|symbol_denied|symbol=%s|allowed=%s",
                  _Symbol,InpAllowedSymbols);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SimRiskLimits limits=SimRiskLimitsDefault();
   limits.max_spread_points=InpMaxSpreadPoints;
   limits.max_virtual_positions=1;
   limits.max_grid_levels=0;
   limits.max_dca_adds=0;
   limits.max_virtual_exposure=InpMaxLots;
   limits.max_daily_loss_pct=InpMaxDailyLossPct;
   limits.max_drawdown_pct=InpMaxDrawdownPct;
   limits.cooldown_bars=InpCooldownBars;
   limits.require_valid_price=true;
   limits.kill_switch=false;
   //--- ADR 0006 §4: ordinary blocks stay blocks; the EA promotes a guard
   //--- halt itself through InpHaltOnBreach.
   limits.halt_on_breach=false;
   if(!g_risk.Init(limits,PeriodSeconds(_Period),error))
     {
      PrintFormat("LAB|ERROR|ww_demo|risk_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_handle=iCustom(_Symbol,_Period,"PinePort\\Wonderwhales",
                    InpMode,InpPsarStart,InpPsarInc,InpPsarMax,
                    InpFastEma,InpSlowEma,InpEma200,InpAtrLen,InpMinAtrPct,
                    InpVolMaLen,InpRsiLen,InpBbLen,InpBbMult);
   if(g_handle==INVALID_HANDLE)
     {
      PrintFormat("LAB|ERROR|ww_demo|indicator_init_failed|error=%d",GetLastError());
      return(INIT_FAILED);
     }

   g_timeframe_text=EnumToString(_Period);
   g_config_hash=BuildConfigHash();
   UpdateAccountState();

   bool restored=false;
   if(InpPersistState && InpResetStateOnInit)
     {
      FileDelete(InpStateFile);
      PrintFormat("LAB|INFO|ww_demo|state_reset_on_init|file_deleted=%s",
                  InpStateFile);
     }
   const bool state_ok=ReadStateFile(restored);
   if(!state_ok && InpPersistState && !InpResetStateOnInit)
      PrintFormat("LAB|INFO|ww_demo|state_not_restored|file=%s",InpStateFile);

   if(g_peak_equity<g_equity)
      g_peak_equity=g_equity;
   if(g_day_start_equity<=0.0)
      g_day_start_equity=g_equity;

   //--- Open the journal before reconciliation so an ADOPT/EXIT row
   //--- produced during init is not dropped.
   if(InpEnableLog)
     {
      if(!g_logger.Open(InpLogFile,error))
        {
         PrintFormat("LAB|ERROR|ww_demo|log_open_failed|%s",error);
         return(INIT_FAILED);
        }
     }

   //--- Reconcile the persisted context with the broker.
   ReconcilePosition();

   const string mode=(InpEnableExecution ? "DEMO_EXECUTION" : "DRY_RUN");
   LogEvent("INIT",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,
            StringFormat("mode=%s|symbol=%s|allowed=%s|magic=%d|tp_r=%.2f|"
                         "hash=%s|equity=%.2f|restored=%d",
                         mode,_Symbol,InpAllowedSymbols,(int)InpMagicNumber,
                         InpTakeProfitR,g_config_hash,g_equity,
                         (restored ? 1 : 0)));
   PrintFormat("LAB|INFO|ww_demo|initialized|mode=%s|hash=%s|magic=%d|"
               "tester=%d|restored=%d|hedging=%d|stops_level=%.0f|"
               "mql_trade_allowed=%d",
               mode,g_config_hash,(int)InpMagicNumber,
               (int)MQLInfoInteger(MQL_TESTER),(restored ? 1 : 0),
               (g_is_hedging ? 1 : 0),g_stops_level,
               (int)MQLInfoInteger(MQL_TRADE_ALLOWED));
   if(!InpEnableExecution)
      PrintFormat("LAB|INFO|ww_demo|dry_run|no_orders_are_sent");
   UpdatePanel(SymbolInfoDouble(_Symbol,SYMBOL_BID),
               SymbolInfoDouble(_Symbol,SYMBOL_ASK));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   SaveState();
   WriteSummary();
   g_logger.Close();
   if(g_handle!=INVALID_HANDLE)
      IndicatorRelease(g_handle);
   Comment("");
   PrintFormat("LAB|INFO|ww_demo|deinit|reason=%d|entries=%d|exits=%d|net=%.2f",
               reason,g_entries,g_exits,g_realized_pnl);
  }

void OnTick(void)
  {
   if(Bars(_Symbol,_Period)<InpWarmupBars+5)
      return;

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(bid<=0.0 || ask<=0.0)
      return;
   g_mid=(bid+ask)*0.5;

   UpdateAccountState();

   //--- Kill switch: flatten and stop until restart after the file is removed.
   if(StringLen(ExecTrim(InpKillSwitchFile))>0 &&
      FileIsExist(InpKillSwitchFile))
     {
      if(g_have_pos && InpCloseOnKillSwitch)
         CloseAtMarket("KILL_SWITCH");
      if(!g_halted || g_halt_reason!="kill_switch_active")
         Halt("kill_switch_active");
      UpdatePanel(bid,ask);
      return;
     }

   ReconcilePosition();
   CheckEquityHalts();
   if(g_halted)
     {
      UpdatePanel(bid,ask);
      return;
     }

   const datetime bar_time=iTime(_Symbol,_Period,0);
   const bool new_bar=(bar_time!=g_last_bar);
   if(new_bar)
      g_last_bar=bar_time;

   if(g_have_pos)
     {
      if(new_bar)
         ManagePosition(bar_time);
     }
   else if(new_bar && bar_time!=g_last_exit_bar)
      TryEnter(bar_time);

   UpdatePanel(bid,ask);
  }
