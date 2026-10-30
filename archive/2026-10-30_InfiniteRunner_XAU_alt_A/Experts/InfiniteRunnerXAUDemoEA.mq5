//+------------------------------------------------------------------+
//|                                      InfiniteRunnerXAUDemoEA.mq5 |
//|      InfiniteRunner XAU v2 - DEMO-ONLY execution EA               |
//|                                                                  |
//| V1 source is left untouched at github-demo/InfiniteRunner_XAU.    |
//| This EA upgrades direction, risk, trailing and recovery. ADR 0004 |
//| requires a demo/tester account, dry-run by default, one position, |
//| mandatory SL and TP, and every order through ExecBroker.mqh.      |
//| V1 used TP=0; v2 keeps a far protective TP at InpTakeProfitR.     |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "2.00"
#property description "Demo-only InfiniteRunner XAU v2. Demo or Strategy Tester only."
#property description "Dry-run by default. Mandatory SL/TP. One position. No live accounts."

#include "../Include/Sim/SimLogger.mqh"
#include "../Include/Sim/SimValidate.mqh"
#include "../Include/InfiniteRunner/IRTypes.mqh"
#include "../Include/InfiniteRunner/IRMarket.mqh"
#include "../Include/InfiniteRunner/IRDirection.mqh"
#include "../Include/InfiniteRunner/IRRisk.mqh"
#include "../Include/InfiniteRunner/IRTrailing.mqh"
#include "../Include/Exec/ExecGuard.mqh"
#include "../Include/Exec/ExecBroker.mqh"

input group "Demo execution"
input bool   InpEnableExecution        = false;
input string InpAllowedSymbols         = "XAUUSD";
input long   InpMagicNumber            = 25006001;
input int    InpMaxSlippagePoints      = 30;
input double InpTakeProfitR            = 8.0;
input string InpKillSwitchFile         = "INFINITE_RUNNER_DEMO_STOP.txt";

input group "Journal and state"
input bool   InpEnableLog              = true;
input string InpLogFile                = "infinite_runner_demo.csv";
input bool   InpPersistState           = true;
input string InpStateFile              = "infinite_runner_demo_state.csv";
input bool   InpResetStateOnInit       = false;
input bool   InpDebug                  = false;

input group "Direction"
input ENUM_IR_DIR_MODE InpDirectionMode = IR_DIR_EMA_MTF;
input ENUM_TIMEFRAMES InpTrendTF       = PERIOD_H1;
input ENUM_TIMEFRAMES InpStructureTF   = PERIOD_M15;
input ENUM_TIMEFRAMES InpEntryTF       = PERIOD_M5;
input int    InpFastEMA                = 21;
input int    InpSlowEMA                = 50;
input int    InpSlopeLookback          = 3;
input double InpMinFastSlope           = 0.0;
input double InpMaxSlowDownSlope       = 0.50;
input double InpPullbackAtrMult        = 0.25;

input group "Risk"
input ENUM_IR_LOT_MODE InpLotMode      = IR_LOT_RISK_PERCENT;
input double InpRiskPercent            = 0.25;
input double InpFixedLot               = 0.01;
input double InpMaxLots                = 0.10;
input int    InpMaxPositions           = 1;
input double InpDailyLossLimitPct      = 1.0;
input double InpMaxDrawdownPct         = 8.0;
input int    InpMaxConsecutiveLosses   = 3;
input int    InpCooldownMinutes        = 30;
input int    InpMaxTradesPerDay        = 8;
input int    InpMinBarsBetweenEntries  = 1;
input bool   InpManualResetDrawdown    = false;

input group "Stops"
input ENUM_IR_SL_MODE InpSlMode        = IR_SL_ATR;
input ENUM_IR_TRAIL_MODE InpTrailingMode = IR_TRAIL_HYBRID;
input double InpInitialSlPoints        = 5000.0;
input double InpAtrStopMult            = 1.5;
input double InpAtrStopBuffer          = 0.20;
input double InpMinSlAtr               = 0.50;
input double InpMaxSlAtr               = 4.0;
input double InpBreakEvenAtR           = 1.0;
input double InpBreakEvenBufferPoints  = 50.0;
input double InpTrailingStartR         = 1.5;
input double InpTrailDistancePoints    = 2500.0;
input double InpTrailStepPoints        = 500.0;
input double InpAtrTrailingMultiplier  = 1.2;
input int    InpSwingLeft              = 2;
input int    InpSwingRight             = 2;

input group "Filters"
input int    InpAtrPeriod              = 14;
input int    InpAtrBaselineBars        = 100;
input double InpAbnormalAtrRatio       = 2.5;
input double InpMaxSpreadPoints        = 600.0;
input double InpMaxSpreadAtrRatio      = 0.25;
input bool   InpEnableSessionFilter    = false;
input int    InpSessionStartHour       = 7;
input int    InpSessionEndHour         = 21;

CSimLogger       g_logger;
IRSymbolSpec     g_spec;
ExecAccountState g_account;

int      g_h1_fast=INVALID_HANDLE;
int      g_h1_slow=INVALID_HANDLE;
int      g_m15_fast=INVALID_HANDLE;
int      g_m15_slow=INVALID_HANDLE;
int      g_m5_fast=INVALID_HANDLE;
int      g_m5_slow=INVALID_HANDLE;
int      g_chart_fast=INVALID_HANDLE;
int      g_chart_slow=INVALID_HANDLE;
int      g_atr_handle=INVALID_HANDLE;

double   g_point=0.0;
string   g_config_hash="";
string   g_tf_text="";
bool     g_ready=false;
bool     g_dry_run=true;
bool     g_kill_switch=false;
bool     g_safe_mode=false;
bool     g_persist_dirty=false;
bool     g_quote_warned=false;
bool     g_block_logged=false;

datetime g_last_forming=0;
datetime g_analysis_bar=0;
datetime g_last_exit_bar=0;
datetime g_last_exit_time=0;
datetime g_last_modify=0;
string   g_last_signal_id="";
string   g_last_block="";
string   g_risk_status="NORMAL";

double   g_peak_equity=0.0;
double   g_day_start_equity=0.0;
long     g_day_key=0;
int      g_consecutive_losses=0;
int      g_trades_today=0;
bool     g_dd_lock=false;
bool     g_daily_lock=false;

bool     g_has_position=false;
ENUM_SIM_SIDE g_side=SIM_SIDE_NONE;
ulong    g_ticket=0;
double   g_entry=0.0;
double   g_volume=0.0;
double   g_sl=0.0;
double   g_tp=0.0;
double   g_initial_risk=0.0;
datetime g_entry_time=0;

int      g_entries=0;
int      g_exits=0;
int      g_wins=0;
int      g_losses=0;
double   g_net_pnl=0.0;
double   g_atr=0.0;
IRDirectionResult g_dir;

double AccountEquity(void) { return(AccountInfoDouble(ACCOUNT_EQUITY)); }
double AccountFreeMargin(void) { return(AccountInfoDouble(ACCOUNT_MARGIN_FREE)); }

long DayKey(const datetime now)
  {
   MqlDateTime dt;
   TimeToStruct(now,dt);
   return((long)dt.year*10000+(long)dt.mon*100+(long)dt.day);
  }

double DrawdownPct(void)
  {
   if(!(g_peak_equity>0.0))
      return(0.0);
   const double equity=AccountEquity();
   if(!(equity>0.0) || equity>=g_peak_equity)
      return(0.0);
   return((g_peak_equity-equity)/g_peak_equity*100.0);
  }

string TimeframeText(void)
  {
   return(StringFormat("%s/%s/%s",
                       EnumToString(InpTrendTF),
                       EnumToString(InpStructureTF),
                       EnumToString(InpEntryTF)));
  }

bool KillSwitchPresent(void)
  {
   return(StringLen(InpKillSwitchFile)>0 && FileIsExist(InpKillSwitchFile));
  }

void ResetPosition(void)
  {
   g_has_position=false;
   g_side=SIM_SIDE_NONE;
   g_ticket=0;
   g_entry=0.0;
   g_volume=0.0;
   g_sl=0.0;
   g_tp=0.0;
   g_initial_risk=0.0;
   g_entry_time=0;
  }

bool ValidateInputs(string &error)
  {
   error="";
   if(InpMaxPositions!=1)
     { error="max_positions_must_be_one"; return(false); }
   if(!IRIsFinitePositive(InpTakeProfitR) || InpTakeProfitR>20.0)
     { error="take_profit_r_must_be_in_0_20"; return(false); }
   if(InpMagicNumber<=0)
     { error="magic_must_be_positive"; return(false); }
   if(InpMaxSlippagePoints<0 || InpMaxSlippagePoints>1000)
     { error="slippage_points_invalid"; return(false); }
   if(StringLen(ExecTrim(InpAllowedSymbols))==0)
     { error="allowed_symbols_empty"; return(false); }
   if(StringLen(ExecTrim(InpKillSwitchFile))==0)
     { error="kill_switch_file_empty"; return(false); }
   if(InpFastEMA<2 || InpSlowEMA<=InpFastEMA)
     { error="ema_periods_invalid"; return(false); }
   if(InpSlopeLookback<1 || InpSlopeLookback>50)
     { error="slope_lookback_invalid"; return(false); }
   if(InpMinFastSlope<0.0 || InpMaxSlowDownSlope<0.0)
     { error="slope_thresholds_invalid"; return(false); }
   if(!IRIsFinitePositive(InpRiskPercent) || InpRiskPercent>5.0)
     { error="risk_percent_invalid"; return(false); }
   if(!IRIsFinitePositive(InpFixedLot) || !IRIsFinitePositive(InpMaxLots))
     { error="lot_caps_invalid"; return(false); }
   if(InpDailyLossLimitPct<0.0 || InpDailyLossLimitPct>100.0)
     { error="daily_loss_pct_invalid"; return(false); }
   if(InpMaxDrawdownPct<0.0 || InpMaxDrawdownPct>100.0)
     { error="drawdown_pct_invalid"; return(false); }
   if(InpMaxConsecutiveLosses<0)
     { error="max_consecutive_losses_must_be_non_negative"; return(false); }
   if(InpCooldownMinutes<0 || InpMaxTradesPerDay<1)
     { error="cooldown_or_trade_cap_invalid"; return(false); }
   if(InpMinBarsBetweenEntries<1)
     { error="min_bars_between_entries_invalid"; return(false); }
   if(!IRIsFinitePositive(InpAtrStopMult) || !IRIsFinitePositive(InpMinSlAtr) ||
      InpMaxSlAtr<=InpMinSlAtr)
     { error="atr_stop_band_invalid"; return(false); }
   if(!IRIsFinitePositive(InpBreakEvenAtR) || InpTrailingStartR<InpBreakEvenAtR)
     { error="trailing_r_invalid"; return(false); }
   if(InpInitialSlPoints<=0.0 || InpTrailDistancePoints<=0.0 ||
      InpTrailStepPoints<0.0)
     { error="point_distances_invalid"; return(false); }
   if(InpAtrPeriod<2 || InpAtrBaselineBars<10)
     { error="atr_period_invalid"; return(false); }
   if(InpAbnormalAtrRatio<1.0)
     { error="abnormal_atr_ratio_invalid"; return(false); }
   if(InpMaxSpreadPoints<=0.0)
     { error="max_spread_points_must_be_positive"; return(false); }
   if(InpSessionStartHour<0 || InpSessionStartHour>23 ||
      InpSessionEndHour<0 || InpSessionEndHour>23)
     { error="session_hours_invalid"; return(false); }
   if(InpEnableLog && StringLen(InpLogFile)==0)
     { error="log_file_must_not_be_empty"; return(false); }
   if(InpPersistState && StringLen(InpStateFile)==0)
     { error="state_file_must_not_be_empty"; return(false); }
   if(InpSwingLeft<1 || InpSwingRight<1)
     { error="swing_window_invalid"; return(false); }
   return(true);
  }

string BuildConfigHash(void)
  {
   string text=SimFormatFingerprintPartText("ea","InfiniteRunnerXAUDemoEA")+
               SimFormatFingerprintPartInt("ea.execution_enabled",
                                           (InpEnableExecution ? 1 : 0))+
               SimFormatFingerprintPartInt("ea.magic",InpMagicNumber)+
               SimFormatFingerprintPart("ea.tp_r",InpTakeProfitR,2)+
               SimFormatFingerprintPartInt("dir.mode",(int)InpDirectionMode)+
               SimFormatFingerprintPartInt("dir.fast",InpFastEMA)+
               SimFormatFingerprintPartInt("dir.slow",InpSlowEMA)+
               SimFormatFingerprintPartInt("risk.lot_mode",(int)InpLotMode)+
               SimFormatFingerprintPart("risk.pct",InpRiskPercent,4)+
               SimFormatFingerprintPartInt("sl.mode",(int)InpSlMode)+
               SimFormatFingerprintPartInt("trail.mode",(int)InpTrailingMode);
   return(SimHashString(text));
  }

void LogEvent(const string event_name,const ENUM_SIM_SIDE side,
              const double price,const double volume,const double entry,
              const double sl,const double tp,const string reason)
  {
   if(!g_logger.IsOpen())
      return;
   SimLogRecord record;
   SimClearLogRecord(record);
   record.logged_at=TimeCurrent();
   record.bar_time=g_analysis_bar;
   record.ea="InfiniteRunnerXAUDemoEA";
   record.version="2.00";
   record.config_hash=g_config_hash;
   record.symbol=_Symbol;
   record.timeframe=g_tf_text;
   record.event=event_name;
   record.side=side;
   record.price=price;
   record.volume=volume;
   record.entry=entry;
   record.sl=sl;
   record.tp=tp;
   record.exposure=g_volume;
   record.equity=AccountEquity();
   record.drawdown_pct=DrawdownPct();
   record.reason=reason;
   string error="";
   g_logger.Write(record,error);
  }

bool LoadSymbolSpec(string &error)
  {
   g_spec.point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   g_spec.tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   g_spec.tick_value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   g_spec.volume_min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   g_spec.volume_max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   g_spec.volume_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   g_spec.stops_level_points=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   g_spec.freeze_level_points=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   if(!IRIsFinitePositive(g_spec.point) || !IRIsFinitePositive(g_spec.tick_size) ||
      !IRIsFinitePositive(g_spec.volume_min) || !IRIsFinitePositive(g_spec.volume_step))
     {
      error="symbol_metrics_invalid";
      return(false);
     }
   error="";
   return(true);
  }

bool FillEmaSnap(const int fast_handle,const int slow_handle,
                 const ENUM_TIMEFRAMES tf,IREmaSnap &snap)
  {
   snap.ready=false;
   if(fast_handle==INVALID_HANDLE || slow_handle==INVALID_HANDLE)
      return(false);
   const int need=InpSlopeLookback+2;
   double fast[];
   double slow[];
   double close[];
   ArraySetAsSeries(fast,true);
   ArraySetAsSeries(slow,true);
   ArraySetAsSeries(close,true);
   if(CopyBuffer(fast_handle,0,1,need,fast)<need)
      return(false);
   if(CopyBuffer(slow_handle,0,1,need,slow)<need)
      return(false);
   if(CopyClose(_Symbol,tf,1,2,close)<2)
      return(false);
   snap.fast=fast[0];
   snap.slow=slow[0];
   snap.fast_prev=fast[1];
   snap.slow_prev=slow[1];
   snap.close=close[0];
   snap.close_prev=close[1];
   snap.fast_slope=IREmaSlope(fast[0],fast[InpSlopeLookback],InpSlopeLookback);
   snap.slow_slope=IREmaSlope(slow[0],slow[InpSlopeLookback],InpSlopeLookback);
   snap.ready=true;
   return(IREmaSnapValid(snap));
  }

double MedianAtr(void)
  {
   double atr[];
   ArraySetAsSeries(atr,true);
   const int need=InpAtrBaselineBars;
   if(CopyBuffer(g_atr_handle,0,1,need,atr)<need)
      return(0.0);
   double sorted[];
   ArrayResize(sorted,need);
   ArrayCopy(sorted,atr);
   ArraySort(sorted);
   if((need%2)==1)
      return(sorted[need/2]);
   return(0.5*(sorted[need/2-1]+sorted[need/2]));
  }

double ClosedAtr(void)
  {
   double atr[];
   ArraySetAsSeries(atr,true);
   if(CopyBuffer(g_atr_handle,0,1,1,atr)<1)
      return(0.0);
   return(atr[0]);
  }

double StructureLevel(const bool is_buy)
  {
   const int bars=InpSwingLeft+InpSwingRight+20;
   double high[];
   double low[];
   ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);
   if(CopyHigh(_Symbol,InpEntryTF,1,bars,high)<bars)
      return(0.0);
   if(CopyLow(_Symbol,InpEntryTF,1,bars,low)<bars)
      return(0.0);
   return(is_buy ? IRLastConfirmedSwingLow(low,InpSwingLeft,InpSwingRight)
                 : IRLastConfirmedSwingHigh(high,InpSwingLeft,InpSwingRight));
  }

void UpdateRiskLocks(const double equity,const datetime now)
  {
   const long day=DayKey(now);
   if(g_day_key!=day)
     {
      g_day_key=day;
      g_day_start_equity=equity;
      g_trades_today=0;
      g_daily_lock=false;
      g_persist_dirty=true;
     }
   if(equity>g_peak_equity)
     {
      g_peak_equity=equity;
      g_persist_dirty=true;
     }
   g_daily_lock=IRDailyLossLocked(equity,g_day_start_equity,InpDailyLossLimitPct);
   if(!g_dd_lock)
      g_dd_lock=IRDrawdownLocked(equity,g_peak_equity,InpMaxDrawdownPct);
   if(g_dd_lock)
      g_risk_status="DD_LOCK";
   else if(g_daily_lock)
      g_risk_status="DAILY_LOCK";
   else if(IRCooldownActive(now,g_last_exit_time,InpCooldownMinutes))
      g_risk_status="COOLDOWN";
   else
      g_risk_status="NORMAL";
  }

string LedgerBlock(const datetime now)
  {
   if(g_safe_mode)
      return("safe_mode");
   if(g_dd_lock)
      return("drawdown_locked");
   if(g_daily_lock)
      return("daily_loss_lock");
   if(IRCooldownActive(now,g_last_exit_time,InpCooldownMinutes))
      return("cooldown");
   if(InpMaxConsecutiveLosses>0 && g_consecutive_losses>=InpMaxConsecutiveLosses)
      return("loss_streak_lock");
   if(g_trades_today>=InpMaxTradesPerDay)
      return("max_trades_per_day");
   return("");
  }

bool ForeignPositionOnSymbol(void)
  {
   const long margin_mode=AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(margin_mode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return(false);
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

void WriteStateFile(void)
  {
   if(!InpPersistState || StringLen(InpStateFile)==0)
      return;
   const int handle=FileOpen(InpStateFile,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle==INVALID_HANDLE)
      return;
   FileWriteString(handle,StringFormat(
                      "version=2|peak=%.8f|day_eq=%.8f|day_key=%I64d|"+
                      "losses=%d|trades=%d|last_exit=%I64d|signal=%s|"+
                      "safe=%d|dd=%d|ticket=%I64u|init_r=%.8f|side=%d\r\n",
                      g_peak_equity,g_day_start_equity,g_day_key,
                      g_consecutive_losses,g_trades_today,(long)g_last_exit_time,
                      g_last_signal_id,(g_safe_mode ? 1 : 0),(g_dd_lock ? 1 : 0),
                      g_ticket,g_initial_risk,(int)g_side));
   FileClose(handle);
   g_persist_dirty=false;
  }

bool RestoreStateFile(void)
  {
   if(!InpPersistState || !FileIsExist(InpStateFile))
      return(false);
   const int handle=FileOpen(InpStateFile,FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle==INVALID_HANDLE)
      return(false);
   const string line=FileReadString(handle);
   FileClose(handle);
   if(StringFind(line,"version=")!=0)
     {
      g_safe_mode=true;
      return(false);
     }
   string parts[];
   const int n=StringSplit(line,'|',parts);
   for(int i=0; i<n; i++)
     {
      string kv[];
      if(StringSplit(parts[i],'=',kv)!=2)
         continue;
      if(kv[0]=="peak")
         g_peak_equity=StringToDouble(kv[1]);
      else if(kv[0]=="day_eq")
         g_day_start_equity=StringToDouble(kv[1]);
      else if(kv[0]=="day_key")
         g_day_key=(long)StringToInteger(kv[1]);
      else if(kv[0]=="losses")
         g_consecutive_losses=(int)StringToInteger(kv[1]);
      else if(kv[0]=="trades")
         g_trades_today=(int)StringToInteger(kv[1]);
      else if(kv[0]=="last_exit")
         g_last_exit_time=(datetime)StringToInteger(kv[1]);
      else if(kv[0]=="signal")
         g_last_signal_id=kv[1];
      else if(kv[0]=="safe")
         g_safe_mode=(StringToInteger(kv[1])!=0);
      else if(kv[0]=="dd")
         g_dd_lock=(StringToInteger(kv[1])!=0);
      else if(kv[0]=="init_r")
         g_initial_risk=StringToDouble(kv[1]);
     }
   return(true);
  }

void AdoptPosition(const ExecPositionInfo &info,const string reason)
  {
   g_has_position=true;
   g_ticket=info.ticket;
   g_side=(info.type==POSITION_TYPE_BUY ? SIM_SIDE_BUY : SIM_SIDE_SELL);
   g_entry=info.open_price;
   g_volume=info.volume;
   g_sl=info.sl;
   g_tp=info.tp;
   g_entry_time=info.open_time;
   if(!(g_initial_risk>0.0) && g_sl>0.0)
      g_initial_risk=MathAbs(g_entry-g_sl);
   if(!(g_sl>0.0) || !(g_tp>0.0) || !(g_initial_risk>0.0))
     {
      g_safe_mode=true;
      LogEvent("ERROR",g_side,g_entry,g_volume,g_entry,g_sl,g_tp,
               "sl_or_state_missing|"+reason);
     }
   g_persist_dirty=true;
  }

void SyncPosition(void)
  {
   ExecPositionInfo info;
   const bool found=ExecFindOwnPosition(InpMagicNumber,info);
   if(found && !g_has_position)
      AdoptPosition(info,"sync_found");
   if(!found && g_has_position)
     {
      double pnl=0.0;
      int deals=0;
      ExecClosedPnl(g_ticket,g_entry_time,pnl,deals);
      g_net_pnl+=pnl;
      g_exits++;
      if(pnl<0.0)
        {
         g_losses++;
         g_consecutive_losses++;
        }
      else
        {
         g_wins++;
         g_consecutive_losses=0;
        }
      g_last_exit_time=TimeCurrent();
      g_last_exit_bar=g_analysis_bar;
      LogEvent("EXIT",g_side,0.0,g_volume,g_entry,g_sl,g_tp,
               StringFormat("closed|net=%.2f|deals=%d",pnl,deals));
      ResetPosition();
      g_persist_dirty=true;
     }
   if(found && g_has_position)
     {
      g_ticket=info.ticket;
      g_sl=info.sl;
      g_tp=info.tp;
      g_volume=info.volume;
      g_entry=info.open_price;
     }
  }

bool CloseWithReason(const string reason)
  {
   if(!g_has_position || g_dry_run)
      return(false);
   ExecFillResult result;
   const bool is_buy=(g_side==SIM_SIDE_BUY);
   if(!ExecClosePosition(g_ticket,is_buy,g_volume,InpMaxSlippagePoints,
                         InpMagicNumber,reason,result))
     {
      LogEvent("ERROR",g_side,0.0,g_volume,g_entry,g_sl,g_tp,
               "close_failed|"+result.message);
      return(false);
     }
   return(true);
  }

void UpdateTrailing(const double bid,const double ask)
  {
   if(!g_has_position || !(g_sl>0.0) || !(g_initial_risk>0.0))
      return;
   if(g_last_modify>0 && TimeCurrent()==g_last_modify)
      return;

   const bool is_buy=(g_side==SIM_SIDE_BUY);
   const double price=(is_buy ? bid : ask);
   IRTrailInput in;
   in.side=g_side;
   in.mode=InpTrailingMode;
   in.entry=g_entry;
   in.sl=g_sl;
   in.price=price;
   in.initial_risk=g_initial_risk;
   in.atr=g_atr;
   in.structure_level=StructureLevel(is_buy);
   in.min_stop=MathMax(g_spec.stops_level_points,g_spec.freeze_level_points)*g_spec.point;
   in.tick_size=g_spec.tick_size;
   in.trail_step=InpTrailStepPoints*g_spec.point;
   in.trail_distance=InpTrailDistancePoints*g_spec.point;
   in.trail_start_r=InpTrailingStartR;
   in.break_even_r=InpBreakEvenAtR;
   in.break_even_buffer=InpBreakEvenBufferPoints*g_spec.point;
   in.trail_atr_mult=InpAtrTrailingMultiplier;

   const IRTrailDecision out=IRTrailingEvaluate(in);
   if(!out.update)
      return;

   double candidate=(is_buy ? IRFloorToTick(out.new_sl,g_spec.tick_size)
                            : IRCeilToTick(out.new_sl,g_spec.tick_size));
   if(!IRSlImproves(is_buy,candidate,g_sl,in.trail_step))
      return;
   if(!ExecStopsRespectBroker(g_entry,candidate,g_tp,g_spec.point,
                              MathMax(g_spec.stops_level_points,
                                      g_spec.freeze_level_points)))
      return;

   ExecFillResult result;
   if(!ExecModifyStops(g_ticket,candidate,g_tp,result))
     {
      g_last_modify=TimeCurrent();
      LogEvent("ERROR",g_side,price,g_volume,g_entry,g_sl,g_tp,
               "modify_failed|"+result.message);
      return;
     }
   const double old_sl=g_sl;
   g_sl=candidate;
   g_last_modify=TimeCurrent();
   g_persist_dirty=true;
   LogEvent("TRAIL",g_side,price,g_volume,g_entry,g_sl,g_tp,
            StringFormat("%s|old_sl=%.8f|new_sl=%.8f|r=%.2f",
                         out.reason,old_sl,g_sl,out.profit_r));
  }

double BuildInitialSl(const bool is_buy,const double fill,const double atr)
  {
   double sl=0.0;
   if(InpSlMode==IR_SL_FIXED_POINTS)
      sl=(is_buy ? fill-InpInitialSlPoints*g_spec.point
                 : fill+InpInitialSlPoints*g_spec.point);
   else if(InpSlMode==IR_SL_STRUCTURE)
     {
      const double swing=StructureLevel(is_buy);
      const double buffer=InpAtrStopBuffer*atr;
      if(!(swing>0.0))
         return(0.0);
      sl=(is_buy ? swing-buffer : swing+buffer);
     }
   else
      sl=(is_buy ? fill-InpAtrStopMult*atr : fill+InpAtrStopMult*atr);
   sl=(is_buy ? IRFloorToTick(sl,g_spec.tick_size)
              : IRCeilToTick(sl,g_spec.tick_size));
   return(sl);
  }

void AttemptEntry(const ENUM_SIM_SIDE side,const double bid,const double ask,
                  const double equity,const datetime now)
  {
   if(g_has_position || side==SIM_SIDE_NONE)
      return;
   if(g_analysis_bar>0 && g_analysis_bar==g_last_exit_bar)
     {
      g_last_block="same_bar_as_exit";
      return;
     }
   if(g_last_exit_bar>0 && InpMinBarsBetweenEntries>1 &&
      g_analysis_bar<=g_last_exit_bar+(datetime)(InpMinBarsBetweenEntries-1)*PeriodSeconds(InpEntryTF))
     {
      g_last_block="min_bars_between_entries";
      return;
     }

   const bool is_buy=(side==SIM_SIDE_BUY);
   const double fill=(is_buy ? ask : bid);
   const double sl=BuildInitialSl(is_buy,fill,g_atr);
   string stop_reason="";
   if(!IRStopDistanceOk(fill,sl,g_atr,InpMinSlAtr,InpMaxSlAtr,g_spec.point,
                        g_spec.stops_level_points,stop_reason))
     {
      g_last_block="stop_rejected|"+stop_reason;
      LogEvent("RISK",side,fill,0.0,fill,sl,0.0,g_last_block);
      return;
     }
   const double tp=ExecTakeProfitPrice(is_buy,fill,sl,InpTakeProfitR);
   if(!ExecTakeProfitValid(is_buy,fill,sl,tp))
     {
      g_last_block=ExecBlockName(EXEC_BLOCK_TP_INVALID);
      return;
     }
   if(!ExecStopsRespectBroker(fill,sl,tp,g_spec.point,
                              MathMax(g_spec.stops_level_points,
                                      g_spec.freeze_level_points)))
     {
      g_last_block=ExecBlockName(EXEC_BLOCK_STOP_TOO_CLOSE);
      return;
     }

   double profit_one=0.0;
   if(!ExecCalcProfit(is_buy,1.0,fill,sl,profit_one) || profit_one>=0.0)
     {
      g_last_block="loss_per_lot_invalid";
      return;
     }
   const double loss_per_lot=-profit_one;
   IRLotDecision lot=IRCalcLot(InpLotMode,equity,InpRiskPercent,InpFixedLot,
                               InpMaxLots,loss_per_lot,g_spec);
   if(!lot.ok)
     {
      g_last_block="lot_rejected|"+lot.reason;
      LogEvent("RISK",side,fill,0.0,fill,sl,tp,g_last_block);
      return;
     }
   lot.volume=ExecNormalizeVolume(lot.volume,g_spec.volume_min,
                                  MathMin(g_spec.volume_max,InpMaxLots),
                                  g_spec.volume_step);
   if(!(lot.volume>0.0))
     {
      g_last_block="lot_rejected|volume_step_invalid";
      return;
     }
   lot.expected_loss=NormalizeDouble(lot.volume*loss_per_lot,8);
   if(!ExecRiskBudgetOk(lot.expected_loss,lot.risk_money) &&
      InpLotMode==IR_LOT_RISK_PERCENT)
     {
      g_last_block=ExecBlockName(EXEC_BLOCK_RISK_BUDGET);
      return;
     }

   double margin=0.0;
   if(!ExecMarginRequired(is_buy,lot.volume,fill,margin) ||
      margin>AccountFreeMargin())
     {
      g_last_block=ExecBlockName(EXEC_BLOCK_MARGIN);
      return;
     }

   if(g_dry_run)
     {
      if(!g_block_logged)
        {
         g_block_logged=true;
         LogEvent("DRY_RUN",side,fill,lot.volume,fill,sl,tp,
                  StringFormat("would_open|lot=%.2f|risk=%.2f|loss=%.2f",
                               lot.volume,lot.risk_money,lot.expected_loss));
        }
      return;
     }

   ExecFillResult result;
   if(!ExecOpenMarket(is_buy,lot.volume,sl,tp,InpMaxSlippagePoints,
                      InpMagicNumber,"IR_"+SimSideName(side),result))
     {
      LogEvent("ERROR",side,fill,lot.volume,fill,sl,tp,
               "open_failed|"+result.message);
      return;
     }

   g_has_position=true;
   g_ticket=result.order;
   g_side=side;
   g_entry=(result.price>0.0 ? result.price : fill);
   g_volume=(result.volume>0.0 ? result.volume : lot.volume);
   g_sl=sl;
   g_tp=tp;
   g_initial_risk=MathAbs(g_entry-sl);
   g_entry_time=TimeCurrent();
   g_entries++;
   g_trades_today++;
   g_last_signal_id=IRSignalId(_Symbol,g_analysis_bar,side);
   g_last_block="";
   g_persist_dirty=true;
   LogEvent("ENTRY",side,g_entry,g_volume,g_entry,g_sl,g_tp,
            StringFormat("ORDER_FILLED|%s|risk=%.2f|loss=%.2f|r_init=%.8f",
                         result.message,lot.risk_money,lot.expected_loss,
                         g_initial_risk));
  }

void AnalyseClosedBar(const double bid,const double ask)
  {
   g_block_logged=false;
   IREmaSnap h1,m15,m5,chart;
   const bool ok=FillEmaSnap(g_h1_fast,g_h1_slow,InpTrendTF,h1) &&
                 FillEmaSnap(g_m15_fast,g_m15_slow,InpStructureTF,m15) &&
                 FillEmaSnap(g_m5_fast,g_m5_slow,InpEntryTF,m5) &&
                 FillEmaSnap(g_chart_fast,g_chart_slow,_Period,chart);
   g_atr=ClosedAtr();
   const double atr_med=MedianAtr();
   const datetime bar=iTime(_Symbol,InpEntryTF,1);
   if(!ok || bar<=0 || !(g_atr>0.0))
     {
      g_dir=IRMakeResult(IR_DATA_NOT_READY,IR_BIAS_NONE,IR_BIAS_NONE,false,false,
                         "data_invalid");
      g_last_block="data_invalid";
      return;
     }
   g_analysis_bar=bar;

   const double spread_price=ask-bid;
   const double spread_points=(g_point>0.0 ? spread_price/g_point : 0.0);
   if(IRSpreadBlocked(spread_points,InpMaxSpreadPoints,spread_price,g_atr,
                      InpMaxSpreadAtrRatio))
     {
      g_dir=IRMakeResult(IR_SPREAD_BLOCKED,IR_BIAS_NONE,IR_BIAS_NONE,false,false,
                         "spread_blocked");
      g_last_block="spread_blocked";
      return;
     }
   if(IRVolatilityBlocked(g_atr,atr_med,InpAbnormalAtrRatio))
     {
      g_dir=IRMakeResult(IR_VOLATILITY_BLOCKED,IR_BIAS_NONE,IR_BIAS_NONE,false,false,
                         "volatility_blocked");
      g_last_block="volatility_blocked";
      return;
     }
   if(!IRSessionOpen(TimeCurrent(),InpEnableSessionFilter,InpSessionStartHour,
                     InpSessionEndHour))
     {
      g_dir=IRMakeResult(IR_NO_TRADE,IR_BIAS_NONE,IR_BIAS_NONE,false,false,
                         "session_closed");
      g_last_block="session_closed";
      return;
     }

   const double pullback=InpPullbackAtrMult*g_atr;
   g_dir=IREvaluateDirection(InpDirectionMode,h1,m15,m5,chart,InpMinFastSlope,
                             InpMaxSlowDownSlope,pullback);

   const string ledger=LedgerBlock(TimeCurrent());
   if(ledger!="")
     {
      g_last_block=ledger;
      g_dir.decision=IR_RISK_BLOCKED;
      g_dir.reason=ledger;
      return;
     }
   if(ForeignPositionOnSymbol())
     {
      g_safe_mode=true;
      g_last_block="foreign_position_on_symbol";
      g_dir.decision=IR_RISK_BLOCKED;
      g_dir.reason=g_last_block;
      return;
     }

   if(g_has_position)
      return;

   ENUM_SIM_SIDE side=SIM_SIDE_NONE;
   if(g_dir.decision==IR_BUY_ALLOWED)
      side=SIM_SIDE_BUY;
   else if(g_dir.decision==IR_SELL_ALLOWED)
      side=SIM_SIDE_SELL;
   else
     {
      g_last_block=g_dir.reason;
      return;
     }

   const string signal=IRSignalId(_Symbol,g_analysis_bar,side);
   if(signal==g_last_signal_id)
     {
      g_last_block="duplicate_signal";
      return;
     }
   AttemptEntry(side,bid,ask,AccountEquity(),TimeCurrent());
  }

void DrawChartStatus(void)
  {
   string position="none";
   if(g_has_position)
      position=StringFormat("%s %.2f @ %.3f sl=%.3f tp=%.3f",
                            SimSideName(g_side),g_volume,g_entry,g_sl,g_tp);
   Comment(StringFormat(
              "InfiniteRunnerXAUDemoEA  %s  magic=%I64d\n"+
              "%s %s  spread_pts=%.1f atr=%.3f equity=%.2f\n"+
              "dir=%s h1=%s m15=%s m5_buy=%d m5_sell=%d\n"+
              "risk=%s  block=%s\n"+
              "position=%s  entries=%d exits=%d dd=%.2f%% kill=%d",
              (g_dry_run ? "DRY_RUN" : "DEMO_EXECUTION"),InpMagicNumber,
              _Symbol,g_tf_text,
              (g_point>0.0 ? (SymbolInfoDouble(_Symbol,SYMBOL_ASK)-
                              SymbolInfoDouble(_Symbol,SYMBOL_BID))/g_point : 0.0),
              g_atr,AccountEquity(),
              IRDecisionName(g_dir.decision),IRBiasName(g_dir.h1_bias),
              IRBiasName(g_dir.m15_bias),(g_dir.m5_buy_trigger ? 1 : 0),
              (g_dir.m5_sell_trigger ? 1 : 0),g_risk_status,g_last_block,
              position,g_entries,g_exits,DrawdownPct(),
              (g_kill_switch ? 1 : 0)));
  }

int OnInit(void)
  {
   string error="";
   if(!ValidateInputs(error))
     {
      PrintFormat("LAB|ERROR|infinite_runner|init_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(!LoadSymbolSpec(error))
     {
      PrintFormat("LAB|ERROR|infinite_runner|symbol_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_account.trade_mode=AccountInfoInteger(ACCOUNT_TRADE_MODE);
   g_account.account_trade_allowed=(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)!=0);
   g_account.terminal_trade_allowed=(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0);
   g_account.tester=(MQLInfoInteger(MQL_TESTER)!=0);

   ENUM_EXEC_BLOCK block=EXEC_OK;
   if(!ExecContextAllowed(g_account,block))
     {
      PrintFormat("LAB|ERROR|infinite_runner|scope_rejected|%s|"
                  "this EA runs on demo or tester accounts only",
                  ExecBlockName(block));
      return(INIT_FAILED);
     }
   if(!ExecSymbolAllowed(_Symbol,InpAllowedSymbols))
     {
      PrintFormat("LAB|ERROR|infinite_runner|scope_rejected|%s",
                  ExecBlockName(EXEC_BLOCK_SYMBOL_DENIED));
      return(INIT_FAILED);
     }
   if(!ExecSymbolTradable((long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE),block))
     {
      PrintFormat("LAB|ERROR|infinite_runner|scope_rejected|%s",
                  ExecBlockName(block));
      return(INIT_FAILED);
     }

   g_h1_fast=iMA(_Symbol,InpTrendTF,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   g_h1_slow=iMA(_Symbol,InpTrendTF,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   g_m15_fast=iMA(_Symbol,InpStructureTF,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   g_m15_slow=iMA(_Symbol,InpStructureTF,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   g_m5_fast=iMA(_Symbol,InpEntryTF,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   g_m5_slow=iMA(_Symbol,InpEntryTF,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   g_chart_fast=iMA(_Symbol,_Period,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   g_chart_slow=iMA(_Symbol,_Period,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   g_atr_handle=iATR(_Symbol,InpEntryTF,InpAtrPeriod);
   if(g_h1_fast==INVALID_HANDLE || g_h1_slow==INVALID_HANDLE ||
      g_m15_fast==INVALID_HANDLE || g_m15_slow==INVALID_HANDLE ||
      g_m5_fast==INVALID_HANDLE || g_m5_slow==INVALID_HANDLE ||
      g_chart_fast==INVALID_HANDLE || g_chart_slow==INVALID_HANDLE ||
      g_atr_handle==INVALID_HANDLE)
     {
      PrintFormat("LAB|ERROR|infinite_runner|indicator_handle_failed");
      return(INIT_FAILED);
     }

   g_point=g_spec.point;
   g_tf_text=TimeframeText();
   g_config_hash=BuildConfigHash();
   g_dry_run=!InpEnableExecution;
   ResetPosition();
   g_dir=IRMakeResult(IR_NO_TRADE,IR_BIAS_NONE,IR_BIAS_NONE,false,false,"init");

   if(InpEnableLog && !g_logger.Open(InpLogFile,error))
     {
      PrintFormat("LAB|ERROR|infinite_runner|logger_invalid|%s",error);
      return(INIT_FAILED);
     }

   bool restored=false;
   if(InpPersistState && !InpResetStateOnInit && FileIsExist(InpStateFile))
      restored=RestoreStateFile();
   const double equity=AccountEquity();
   if(!restored)
     {
      g_peak_equity=equity;
      g_day_start_equity=equity;
      g_day_key=DayKey(TimeCurrent());
     }
   if(InpManualResetDrawdown && g_dd_lock)
     {
      g_dd_lock=false;
      g_peak_equity=equity;
      LogEvent("RESET",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,"manual_drawdown_reset");
     }

   ExecPositionInfo info;
   if(ExecFindOwnPosition(InpMagicNumber,info))
      AdoptPosition(info,"init_position_found");

   LogEvent("INIT",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,
            StringFormat("version=2.00|mode=%s|restored=%d|symbol=%s|"+
                         "magic=%I64d|tp_r=%.2f|hash=%s|mql_trade_allowed=%d",
                         (g_dry_run ? "DRY_RUN" : "DEMO_EXECUTION"),
                         (restored ? 1 : 0),_Symbol,InpMagicNumber,
                         InpTakeProfitR,g_config_hash,
                         (MQLInfoInteger(MQL_TRADE_ALLOWED) ? 1 : 0)));
   g_ready=true;
   DrawChartStatus();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   Comment("");
   if(!g_ready)
      return;
   LogEvent("SUMMARY",SIM_SIDE_NONE,0.0,g_volume,g_entry,g_sl,g_tp,
            StringFormat("mode=%s|entries=%d|exits=%d|wins=%d|losses=%d|net=%.2f|"+
                         "dd=%.4f|kill=%d",
                         (g_dry_run ? "DRY_RUN" : "DEMO_EXECUTION"),
                         g_entries,g_exits,g_wins,g_losses,g_net_pnl,
                         DrawdownPct(),(g_kill_switch ? 1 : 0)));
   WriteStateFile();
   g_ready=false;
  }

void OnTick(void)
  {
   if(!g_ready)
      return;
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(!IRIsFinitePositive(bid) || !IRIsFinitePositive(ask) || ask<bid)
     {
      if(!g_quote_warned)
        {
         g_quote_warned=true;
         LogEvent("ERROR",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,"quote_invalid");
        }
      return;
     }
   g_quote_warned=false;
   SyncPosition();
   UpdateRiskLocks(AccountEquity(),TimeCurrent());

   if(KillSwitchPresent())
     {
      if(!g_kill_switch)
        {
         g_kill_switch=true;
         g_dry_run=true;
         LogEvent("KILL",SIM_SIDE_NONE,0.0,g_volume,g_entry,g_sl,g_tp,
                  "kill_switch_file|file="+InpKillSwitchFile);
        }
      if(g_has_position)
         CloseWithReason("KILL_SWITCH");
      DrawChartStatus();
      return;
     }
   if(g_kill_switch)
      return;

   UpdateTrailing(bid,ask);

   const datetime forming=iTime(_Symbol,InpEntryTF,0);
   if(forming<=0 || forming==g_last_forming)
     {
      DrawChartStatus();
      if(g_persist_dirty)
         WriteStateFile();
      return;
     }
   g_last_forming=forming;
   AnalyseClosedBar(bid,ask);
   DrawChartStatus();
   if(g_persist_dirty)
      WriteStateFile();
  }
