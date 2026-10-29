//+------------------------------------------------------------------+
//|                                     PATrendRiderXAUv1DemoEA.mq5 |
//|      PA TrendRider XAU v1 - DEMO-ONLY execution EA                |
//|                                                                  |
//| Scope: docs/decisions/0003-demo-execution-scope.md.               |
//| Demo or Strategy Tester accounts only; live/real accounts are     |
//| rejected at OnInit. Dry-run is the default: orders are sent only  |
//| when InpEnableExecution=true. One position, mandatory SL and TP,   |
//| risk-budgeted volume, daily/drawdown locks and a kill-switch file. |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Demo-only PA TrendRider XAU v1: guarded order execution, one position, SL/TP mandatory."
#property description "Dry-run by default. Live accounts are rejected. See docs/decisions/0003-demo-execution-scope.md."

#include "../Include/Sim/SimLogger.mqh"
#include "../Include/TrendRider/TRTypes.mqh"
#include "../Include/TrendRider/TRConfig.mqh"
#include "../Include/TrendRider/TRSwing.mqh"
#include "../Include/TrendRider/TRStructure.mqh"
#include "../Include/TrendRider/TRTrend.mqh"
#include "../Include/TrendRider/TRSignal.mqh"
#include "../Include/TrendRider/TRPullback.mqh"
#include "../Include/TrendRider/TRAtr.mqh"
#include "../Include/TrendRider/TRRisk.mqh"
#include "../Include/TrendRider/TRTrailing.mqh"
#include "../Include/TrendRider/TRState.mqh"
#include "../Include/TrendRider/TRMarketData.mqh"
#include "../Include/Exec/ExecGuard.mqh"
#include "../Include/Exec/ExecBroker.mqh"

input group "Demo execution"
input bool   InpEnableExecution        = false;               // false = dry-run, no orders
input string InpAllowedSymbols         = "XAUUSD";            // prefix allow-list, comma separated
input long   InpMagicNumber            = 25002001;
input int    InpMaxSlippagePoints      = 30;                  // deviation for market orders
input double InpTakeProfitR            = 3.0;                 // TP = entry +/- R * InpTakeProfitR
input string InpKillSwitchFile         = "PA_TREND_RIDER_DEMO_STOP.txt";

input group "Journal and state"
input bool   InpEnableLog              = true;
input string InpLogFile                = "pa_trendrider_demo.csv";
input bool   InpPersistState           = true;
input string InpStateFile              = "pa_trendrider_demo_state.csv";
input bool   InpResetStateOnInit       = false;
input bool   InpDebug                  = false;

input group "Timeframes"
input ENUM_TIMEFRAMES InpTrendTF       = PERIOD_H1;
input ENUM_TIMEFRAMES InpStructureTF   = PERIOD_M15;
input ENUM_TIMEFRAMES InpEntryTF       = PERIOD_M5;
input int    InpTrendBars              = 300;
input int    InpStructureBars          = 300;
input int    InpEntryBars              = 400;

input group "Structure"
input int    InpSwingLeft                  = 2;
input int    InpSwingRight                 = 2;
input double InpSpreadBufferMultiplier     = 2.0;
input double InpAtrBreakBufferMultiplier   = 0.10;
input double InpTrendMinDeltaAtr           = 0.05;
input double InpRetestZoneAtr              = 0.25;
input double InpConfirmationBodyAtr        = 0.5;
input double InpConfirmationCloseZone      = 0.25;
input int    InpMaxSignalAgeBars           = 8;

input group "Risk"
input double InpRiskPercent           = 0.25;
input int    InpMaxPositions          = 1;
input double InpDailyLossLimitPct     = 1.0;
input double InpMaxDrawdownPct        = 8.0;
input int    InpMaxConsecutiveLosses  = 3;
input int    InpCooldownMinutes       = 30;
input bool   InpManualResetDrawdown   = false;
input double InpCommissionPerVolume   = 0.0;   // budgeted for sizing; charged by the broker

input group "Stops"
input double InpBreakEvenAtR          = 1.0;
input double InpTrailingStartR        = 1.5;
input double InpAtrStopBuffer         = 0.2;
input double InpAtrTrailingMultiplier = 1.2;
input double InpMinSlAtr              = 0.5;
input double InpMaxSlAtr              = 4.0;
input bool   InpUpdateOnClosedBarOnly = true;

input group "Volatility and spread"
input int    InpAtrPeriod             = 14;
input int    InpAtrBaselineBars       = 100;
input double InpAbnormalAtrRatio      = 2.5;
input double InpMaxSpreadPoints       = 600.0;
input double InpMaxSpreadAtrRatio     = 0.25;

CSimLogger        g_logger;
TRRiskLedger      g_ledger;
TRStateMachine    g_state;
TRStructureEngine g_h1_engine;
TRStructureEngine g_m15_engine;
TRStructureEngine g_m5_engine;
TRConfig          g_cfg;
TRSymbolSpec      g_spec;
ExecAccountState  g_account;

double   g_point=0.0;
double   g_spread_price=0.0;
double   g_atr=0.0;
string   g_config_hash="";
string   g_tf_text="";
bool     g_ready=false;
bool     g_dry_run=true;
bool     g_kill_switch=false;
bool     g_persist_dirty=false;
bool     g_block_logged=false;
bool     g_logger_error_logged=false;
bool     g_state_error_logged=false;
bool     g_data_warned=false;
bool     g_quote_warned=false;

datetime g_last_forming=0;
datetime g_analysis_bar=0;
datetime g_last_exit_bar=0;
ENUM_TR_REGIME g_last_regime=TR_REGIME_UNKNOWN;
string   g_last_block_reason="";

bool     g_has_position=false;
ENUM_SIM_SIDE g_side=SIM_SIDE_NONE;
ulong    g_ticket=0;
double   g_entry=0.0;
double   g_volume=0.0;
double   g_sl=0.0;
double   g_tp=0.0;
double   g_initial_risk=0.0;
double   g_initial_risk_money=0.0;
datetime g_entry_time=0;
datetime g_entry_bar=0;
double   g_last_profit=0.0;
int      g_close_retries=0;
bool     g_close_warned=false;
string   g_pending_close_reason="";

bool     g_has_bos=false;
ENUM_SIM_SIDE g_bos_side=SIM_SIDE_NONE;
double   g_bos_level=0.0;
datetime g_bos_time=0;

bool              g_reversal_pending=false;
ENUM_TR_DIRECTION g_reversal_direction=TR_DIR_UNKNOWN;
TRChainResult     g_m15_chain;
TRStructure       g_m5_structure;

int      g_entries=0;
int      g_exits=0;
int      g_wins=0;
int      g_losses=0;
double   g_net_pnl=0.0;

//+------------------------------------------------------------------+
//| Small helpers                                                    |
//+------------------------------------------------------------------+
double AccountEquity(void)
  {
   return(AccountInfoDouble(ACCOUNT_EQUITY));
  }

double AccountFreeMargin(void)
  {
   return(AccountInfoDouble(ACCOUNT_MARGIN_FREE));
  }

double RoundToTick(const double price,const double tick)
  {
   if(!TRIsFinitePositive(tick))
      return(NormalizeDouble(price,_Digits));
   return(NormalizeDouble(MathRound(price/tick)*tick,_Digits));
  }

double FloorToTick(const double price,const double tick)
  {
   if(!TRIsFinitePositive(tick))
      return(NormalizeDouble(price,_Digits));
   return(NormalizeDouble(MathFloor(price/tick+1e-9)*tick,_Digits));
  }

double CeilToTick(const double price,const double tick)
  {
   if(!TRIsFinitePositive(tick))
      return(NormalizeDouble(price,_Digits));
   return(NormalizeDouble(MathCeil(price/tick-1e-9)*tick,_Digits));
  }

string TimeframeText(void)
  {
   return(StringFormat("%s/%s/%s",
                       EnumToString(InpTrendTF),
                       EnumToString(InpStructureTF),
                       EnumToString(InpEntryTF)));
  }

bool BarArrayAligned(const ENUM_TIMEFRAMES tf,const TRBar &bars[])
  {
   const int count=ArraySize(bars);
   if(count<1)
      return(false);
   const datetime expected=iTime(_Symbol,tf,1);
   return(expected>0 && bars[count-1].time==expected);
  }

bool KillSwitchPresent(void)
  {
   return(StringLen(InpKillSwitchFile)>0 && FileIsExist(InpKillSwitchFile));
  }

double DrawdownPct(void)
  {
   const double peak=g_ledger.PeakEquity();
   const double equity=AccountEquity();
   if(!TRIsFinitePositive(peak) || !TRIsFinitePositive(equity))
      return(0.0);
   if(equity>=peak)
      return(0.0);
   return((peak-equity)/peak*100.0);
  }

//+------------------------------------------------------------------+
//| Validation and configuration                                     |
//+------------------------------------------------------------------+
bool ValidateInputs(string &error)
  {
   error="";
   if(InpMaxPositions!=1)
     {
      error="max_positions_must_be_one";
      return(false);
     }
   if(!TRIsFinitePositive(InpTakeProfitR) || InpTakeProfitR>20.0)
     {
      error="take_profit_r_must_be_in_0_20";
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
   if(InpTrendTF==PERIOD_CURRENT || InpStructureTF==PERIOD_CURRENT ||
      InpEntryTF==PERIOD_CURRENT)
     {
      error="timeframes_must_be_explicit";
      return(false);
     }
   if(InpTrendTF==InpStructureTF || InpStructureTF==InpEntryTF ||
      InpTrendTF==InpEntryTF)
     {
      error="timeframes_must_be_distinct";
      return(false);
     }
   const int trend_seconds=PeriodSeconds(InpTrendTF);
   const int structure_seconds=PeriodSeconds(InpStructureTF);
   const int entry_seconds=PeriodSeconds(InpEntryTF);
   if(!(trend_seconds>structure_seconds && structure_seconds>entry_seconds))
     {
      error="timeframes_must_be_ordered";
      return(false);
     }
   if(!TRConfigValidate(g_cfg,error))
      return(false);
   if(InpEntryBars<g_cfg.atr_period+g_cfg.atr_baseline_bars+
                    g_cfg.swing_left+g_cfg.swing_right+10)
     {
      error="entry_bars_too_small_for_atr_baseline";
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
   if(!MathIsValidNumber(InpCommissionPerVolume) || InpCommissionPerVolume<0.0)
     {
      error="commission_must_be_non_negative";
      return(false);
     }
   return(true);
  }

void ConfigFromInputs(void)
  {
   g_cfg=TRConfigDefault();
   g_cfg.swing_left=InpSwingLeft;
   g_cfg.swing_right=InpSwingRight;
   g_cfg.risk_percent=InpRiskPercent;
   g_cfg.max_positions=1;
   g_cfg.daily_loss_limit_pct=InpDailyLossLimitPct;
   g_cfg.max_drawdown_pct=InpMaxDrawdownPct;
   g_cfg.max_consecutive_losses=InpMaxConsecutiveLosses;
   g_cfg.cooldown_minutes=InpCooldownMinutes;
   g_cfg.break_even_at_r=InpBreakEvenAtR;
   g_cfg.trailing_start_r=InpTrailingStartR;
   g_cfg.atr_period=InpAtrPeriod;
   g_cfg.atr_stop_buffer=InpAtrStopBuffer;
   g_cfg.atr_trailing_multiplier=InpAtrTrailingMultiplier;
   g_cfg.abnormal_atr_ratio=InpAbnormalAtrRatio;
   g_cfg.atr_baseline_bars=InpAtrBaselineBars;
   g_cfg.spread_buffer_multiplier=InpSpreadBufferMultiplier;
   g_cfg.atr_break_buffer_multiplier=InpAtrBreakBufferMultiplier;
   g_cfg.trend_min_delta_atr=InpTrendMinDeltaAtr;
   g_cfg.retest_zone_atr=InpRetestZoneAtr;
   g_cfg.confirmation_body_atr=InpConfirmationBodyAtr;
   g_cfg.confirmation_close_zone=InpConfirmationCloseZone;
   g_cfg.max_signal_age_bars=InpMaxSignalAgeBars;
   g_cfg.min_sl_atr=InpMinSlAtr;
   g_cfg.max_sl_atr=InpMaxSlAtr;
   g_cfg.max_spread_points=InpMaxSpreadPoints;
   g_cfg.max_spread_atr_ratio=InpMaxSpreadAtrRatio;
   g_cfg.commission_per_volume=InpCommissionPerVolume;
   g_cfg.slippage_points=(double)InpMaxSlippagePoints;
  }

string BuildConfigHash(void)
  {
   string text=TRConfigFingerprint(g_cfg);
   text+=SimFormatFingerprintPartInt("ea.trend_tf",(int)InpTrendTF);
   text+=SimFormatFingerprintPartInt("ea.structure_tf",(int)InpStructureTF);
   text+=SimFormatFingerprintPartInt("ea.entry_tf",(int)InpEntryTF);
   text+=SimFormatFingerprintPartInt("ea.trend_bars",InpTrendBars);
   text+=SimFormatFingerprintPartInt("ea.structure_bars",InpStructureBars);
   text+=SimFormatFingerprintPartInt("ea.entry_bars",InpEntryBars);
   text+=SimFormatFingerprintPartInt("ea.execution_enabled",
                                     (InpEnableExecution ? 1 : 0));
   text+=SimFormatFingerprintPart("ea.tp_r",InpTakeProfitR,4);
   text+=SimFormatFingerprintPartInt("ea.magic",(int)InpMagicNumber);
   text+=SimFormatFingerprintPartInt("ea.deviation",InpMaxSlippagePoints);
   text+=SimFormatFingerprintPart("ea.allowed",(double)StringLen(InpAllowedSymbols),0);
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
   record.bar_time=(g_analysis_bar>0 ? g_analysis_bar : TimeCurrent());
   record.ea="PATrendRiderXAUv1DemoEA";
   record.version="1.00";
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
   record.exposure=exposure;
   record.equity=AccountEquity();
   record.drawdown_pct=DrawdownPct();
   record.reason=reason;

   string error="";
   if(!g_logger.Write(record,error) && !g_logger_error_logged)
     {
      g_logger_error_logged=true;
      PrintFormat("LAB|ERROR|trendrider_demo|log_write_failed|%s",error);
     }
  }

void SetState(const ENUM_TR_STATE next,const string reason)
  {
   if(g_state.State()==next)
      return;
   string error="";
   if(!g_state.Transition(next,error))
     {
      if(!g_state_error_logged)
        {
         g_state_error_logged=true;
         LogEvent("STATE_ERROR",SIM_SIDE_NONE,0.0,g_volume,g_entry,g_sl,g_tp,0.0,
                  error+"|desired="+TRStateName(next)+"|reason="+reason);
        }
      return;
     }
   g_state_error_logged=false;
   g_persist_dirty=true;
   LogEvent("STATE",SIM_SIDE_NONE,0.0,g_volume,g_entry,g_sl,g_tp,0.0,
            "to="+TRStateName(next)+"|reason="+reason+"|transitions="+
            IntegerToString(g_state.TransitionCount()));
  }

//+------------------------------------------------------------------+
//| Ledger persistence                                               |
//+------------------------------------------------------------------+
bool WriteStateFile(void)
  {
   if(!InpPersistState || StringLen(InpStateFile)==0)
      return(true);
   const int handle=FileOpen(InpStateFile,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("LAB|ERROR|trendrider_demo|state_write_failed|error=%d",
                  GetLastError());
      return(false);
     }
   FileWriteString(handle,"version=1\r\n");
   FileWriteString(handle,"state="+g_state.Serialize()+"\r\n");
   FileWriteString(handle,"ledger="+g_ledger.Serialize()+"\r\n");
   FileClose(handle);
   g_persist_dirty=false;
   return(true);
  }

bool RestoreStateFile(void)
  {
   if(!InpPersistState || StringLen(InpStateFile)==0)
      return(true);
   if(!FileIsExist(InpStateFile))
      return(true);

   const int handle=FileOpen(InpStateFile,FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle==INVALID_HANDLE)
      return(false);

   string version="";
   string state_text="";
   string ledger_text="";
   while(!FileIsEnding(handle))
     {
      const string line=FileReadString(handle);
      if(StringFind(line,"version=")==0)
         version=StringSubstr(line,8);
      else if(StringFind(line,"state=")==0)
         state_text=StringSubstr(line,6);
      else if(StringFind(line,"ledger=")==0)
         ledger_text=StringSubstr(line,7);
     }
   FileClose(handle);

   if(version!="1" || StringLen(ledger_text)==0)
      return(false);
   if(!g_ledger.Deserialize(ledger_text))
      return(false);
   if(StringLen(state_text)>0)
      g_state.Deserialize(state_text);
   return(true);
  }

//+------------------------------------------------------------------+
//| Position bookkeeping                                             |
//+------------------------------------------------------------------+
void ResetPositionContext(void)
  {
   g_has_position=false;
   g_side=SIM_SIDE_NONE;
   g_ticket=0;
   g_entry=0.0;
   g_volume=0.0;
   g_sl=0.0;
   g_tp=0.0;
   g_initial_risk=0.0;
   g_initial_risk_money=0.0;
   g_entry_time=0;
   g_entry_bar=0;
   g_last_profit=0.0;
   g_close_retries=0;
   g_close_warned=false;
   g_pending_close_reason="";
   g_reversal_pending=false;
   g_reversal_direction=TR_DIR_UNKNOWN;
   g_has_bos=false;
   g_bos_side=SIM_SIDE_NONE;
   g_bos_level=0.0;
   g_bos_time=0;
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
   g_initial_risk=MathAbs(g_entry-g_sl);
   g_initial_risk_money=g_volume*TRLossPerLot(g_spec,g_entry,g_sl);
   g_entry_time=info.open_time;
   g_entry_bar=info.open_time;
   g_last_profit=info.profit;
   g_close_retries=0;

   if(g_state.State()==TR_STATE_WAITING_FOR_SETUP ||
      g_state.State()==TR_STATE_READY ||
      g_state.State()==TR_STATE_INITIALIZING)
     {
      string error="";
      g_state.Transition(TR_STATE_ENTRY_REQUESTED,error);
      g_state.Transition(TR_STATE_POSITION_OPEN,error);
     }
   else if(g_state.State()!=TR_STATE_POSITION_OPEN &&
           g_state.State()!=TR_STATE_REVERSAL_WATCH &&
           g_state.State()!=TR_STATE_CLOSE_FOR_REVERSAL)
      SetState(TR_STATE_POSITION_OPEN,reason);

   LogEvent("ADOPT",g_side,g_entry,g_volume,g_entry,g_sl,g_tp,g_volume,
            StringFormat("%s|ticket=%I64u|risk=%.8f|risk_money=%.2f",
                         reason,g_ticket,g_initial_risk,g_initial_risk_money));
   g_persist_dirty=true;
  }

void FinalizeClosed(const double pnl,const int deals,const string reason)
  {
   if(!g_has_position)
      return;
   const string close_reason=(StringLen(g_pending_close_reason)>0
                              ? g_pending_close_reason : reason);
   LogEvent("EXIT",g_side,0.0,g_volume,g_entry,g_sl,g_tp,0.0,
            StringFormat("%s|pnl=%.2f|deals=%d|ticket=%I64u|risk_money=%.2f",
                         close_reason,pnl,deals,g_ticket,g_initial_risk_money));
   g_net_pnl+=pnl;
   g_exits++;
   if(pnl>0.0)
      g_wins++;
   else if(pnl<0.0)
      g_losses++;
   g_ledger.OnTradeClosed(pnl,TimeCurrent(),g_cfg);
   g_last_exit_bar=g_analysis_bar;
   g_last_block_reason="";
   ResetPositionContext();
   if(g_state.State()!=TR_STATE_ERROR_SAFE_MODE)
      SetState(TR_STATE_WAITING_FOR_SETUP,"position_closed|"+close_reason);
   g_persist_dirty=true;
  }

void SyncPosition(void)
  {
   ExecPositionInfo info;
   if(ExecFindOwnPosition(InpMagicNumber,info))
     {
      g_last_profit=info.profit;
      if(!g_has_position)
        {
         AdoptPosition(info,"broker_position_found");
         return;
        }
      if(info.ticket!=g_ticket)
        {
         LogEvent("SYNC",g_side,info.open_price,info.volume,g_entry,g_sl,g_tp,
                  info.volume,
                  StringFormat("ticket_changed|old=%I64u|new=%I64u",
                               g_ticket,info.ticket));
         g_ticket=info.ticket;
        }
      //--- Our SL/TP are authoritative. If the broker shows no stop or
      //--- target, repair them once; a second failure closes the position.
      if(!TRIsFinitePositive(info.sl) || !TRIsFinitePositive(info.tp))
        {
         ExecFillResult repair;
         if(ExecModifyStops(g_ticket,g_sl,g_tp,repair))
           {
            LogEvent("SYNC",g_side,info.open_price,info.volume,g_entry,g_sl,
                     g_tp,info.volume,"stops_repaired|"+repair.message);
           }
         else
           {
            LogEvent("ERROR",g_side,info.open_price,info.volume,g_entry,g_sl,
                     g_tp,info.volume,
                     "position_missing_stop_or_target|repair_failed|closing");
            g_pending_close_reason="missing_stop_or_target";
            g_dry_run=true;
            CloseWithReason("missing_stop_or_target");
           }
        }
      return;
     }

   if(!g_has_position)
      return;

   double pnl=0.0;
   int deals=0;
   if(ExecClosedPnl(g_ticket,g_entry_time,pnl,deals))
     {
      FinalizeClosed(pnl,deals,"broker_close");
      return;
     }
   g_close_retries++;
   if(g_close_retries>=3)
      FinalizeClosed(g_last_profit,0,"broker_close|pnl_fallback");
  }

bool CloseWithReason(const string reason)
  {
   if(!g_has_position)
      return(true);

   const bool is_buy=(g_side==SIM_SIDE_BUY);
   ExecFillResult result;
   if(!ExecClosePosition(g_ticket,is_buy,g_volume,InpMaxSlippagePoints,
                         InpMagicNumber,"TR_"+reason,result))
     {
      if(!g_close_warned)
        {
         g_close_warned=true;
         LogEvent("ERROR",g_side,0.0,g_volume,g_entry,g_sl,g_tp,0.0,
                  "close_failed|reason="+reason+"|"+result.message);
        }
      return(false);
     }
   g_close_warned=false;
   g_pending_close_reason=reason;
   LogEvent("CLOSE_REQUEST",g_side,result.price,g_volume,g_entry,g_sl,g_tp,0.0,
            StringFormat("reason=%s|deal=%I64u|%s",reason,result.deal,
                         result.message));
   return(true);
  }

void ManageOpenPosition(const double bid,const double ask)
  {
   if(!g_has_position)
      return;

   if(!g_reversal_pending || !g_m15_chain.valid || g_m15_chain.ranging)
      return;
   if(g_m15_chain.direction!=g_reversal_direction)
      return;

   SetState(TR_STATE_CLOSE_FOR_REVERSAL,
            "m15_confirmed|"+TRDirectionName(g_reversal_direction));
   CloseWithReason("reversal_"+TRDirectionName(g_reversal_direction));
  }

void UpdateTrailing(const bool new_bar,const double bid,const double ask)
  {
   if(!g_has_position)
      return;
   if(InpUpdateOnClosedBarOnly && !new_bar)
      return;
   if(!TRIsFinitePositive(g_atr) || !TRIsFinitePositive(g_initial_risk))
      return;

   const bool is_buy=(g_side==SIM_SIDE_BUY);
   const double price=(is_buy ? bid : ask);
   if(!TRIsFinitePositive(price))
      return;

   double structure_level=0.0;
   bool use_structure=false;
   if(is_buy && g_m5_structure.has_low)
     {
      structure_level=g_m5_structure.last_low.price;
      use_structure=true;
     }
   else if(!is_buy && g_m5_structure.has_high)
     {
      structure_level=g_m5_structure.last_high.price;
      use_structure=true;
     }

   const double broker_level=g_spec.stops_level_points*g_spec.point;
   const double freeze_level=g_spec.freeze_level_points*g_spec.point;
   const double min_stop=MathMax(MathMax(broker_level,freeze_level),
                                 g_spread_price+g_spec.point);

   TRTrailingInput in;
   in.side=g_side;
   in.entry=g_entry;
   in.sl=g_sl;
   in.price=price;
   in.initial_risk=g_initial_risk;
   in.atr=g_atr;
   in.structure_level=structure_level;
   in.use_structure=use_structure;
   in.min_stop=min_stop;
   in.break_even_r=g_cfg.break_even_at_r;
   in.trail_start_r=g_cfg.trailing_start_r;
   in.trail_atr_mult=g_cfg.atr_trailing_multiplier;

   const TRTrailingDecision out=TRTrailingEvaluate(in);
   if(!out.update)
      return;

   double candidate=RoundToTick(out.new_sl,g_spec.tick_size);
   candidate=(is_buy ? FloorToTick(candidate,g_spec.tick_size)
                     : CeilToTick(candidate,g_spec.tick_size));
   const bool improves=(is_buy ? candidate>g_sl+1e-12
                               : candidate<g_sl-1e-12);
   if(!improves || candidate<=0.0)
      return;
   if(!ExecStopsRespectBroker(g_entry,candidate,g_tp,g_spec.point,
                              MathMax(g_spec.stops_level_points,
                                      g_spec.freeze_level_points)))
     {
      if(InpDebug && new_bar)
         LogEvent("TRAIL",g_side,price,g_volume,g_entry,g_sl,g_tp,0.0,
                  StringFormat("TRAIL_REJECTED|reason=broker_level|"+
                               "candidate=%.8f",candidate));
      return;
     }

   ExecFillResult result;
   if(!ExecModifyStops(g_ticket,candidate,g_tp,result))
     {
      LogEvent("ERROR",g_side,price,g_volume,g_entry,g_sl,g_tp,0.0,
               "modify_failed|"+result.message);
      return;
     }

   const double old_sl=g_sl;
   g_sl=candidate;
   g_persist_dirty=true;
   LogEvent("TRAIL",g_side,price,g_volume,g_entry,g_sl,g_tp,0.0,
            StringFormat("%s|old_sl=%.8f|new_sl=%.8f|profit_r=%.2f|atr=%.8f",
                         out.reason,old_sl,g_sl,out.profit_r,g_atr));
  }

void LogEntryBlocked(const ENUM_SIM_SIDE side,const string reason,
                     const double atr)
  {
   if(reason==g_last_block_reason && !g_has_bos)
      return;
   g_last_block_reason=reason;
   const string head=(StringFind(reason,"ENTRY_BLOCKED|")==0
                      ? reason : "ENTRY_BLOCKED|reason="+reason);
   LogEvent("RISK",side,0.0,0.0,g_entry,g_sl,g_tp,0.0,
            StringFormat("%s|regime=%s|state=%s|spread_points=%.1f|atr=%.8f",
                         head,TRRegimeName(g_last_regime),
                         TRStateName(g_state.State()),
                         (g_point>0.0 ? g_spread_price/g_point : 0.0),atr));
  }

//+------------------------------------------------------------------+
//| Entry                                                            |
//+------------------------------------------------------------------+
bool EntryAllowedByState(void)
  {
   return(g_state.State()==TR_STATE_WAITING_FOR_SETUP);
  }

bool LogDryRun(const ENUM_SIM_SIDE side,const double fill,const double sl,
               const double tp,const TRLotDecision &lot,const double equity)
  {
   if(g_block_logged)
      return(true);
   g_block_logged=true;
   LogEvent("DRY_RUN",side,fill,lot.volume,fill,sl,tp,lot.volume,
            StringFormat("would_open|side=%s|lot=%.2f|sl=%.8f|tp=%.8f|"+
                         "risk_money=%.2f|expected_loss=%.2f|tp_r=%.2f|"+
                         "equity=%.2f|state=%s",
                         SimSideName(side),lot.volume,sl,tp,
                         lot.risk_money,lot.expected_loss,InpTakeProfitR,equity,
                         TRStateName(g_state.State())));
   return(true);
  }

void AttemptEntry(const TRStructureSnapshot &m5_snapshot,
                  const TRSignalDecision &decision,const double bid,
                  const double ask,const double equity)
  {
   if(g_has_position)
      return;

   const ENUM_SIM_SIDE side=decision.side;
   if(side==SIM_SIDE_NONE)
      return;
   if(g_analysis_bar>0 && g_analysis_bar==g_last_exit_bar)
     {
      LogEntryBlocked(side,"same_bar_as_exit",g_atr);
      return;
     }

   const bool is_buy=(side==SIM_SIDE_BUY);
   const double structure_level=(is_buy ? m5_snapshot.structure.last_low.price
                                        : m5_snapshot.structure.last_high.price);
   if(!TRIsFinitePositive(structure_level))
     {
      LogEntryBlocked(side,"sl_swing_invalid",g_atr);
      return;
     }

   const double fill=(is_buy ? ask : bid);
   if(!TRIsFinitePositive(fill))
     {
      LogEntryBlocked(side,"entry_price_invalid",g_atr);
      return;
     }

   const double buffer=g_cfg.atr_stop_buffer*g_atr;
   double sl=(is_buy ? structure_level-buffer : structure_level+buffer);
   sl=(is_buy ? FloorToTick(sl,g_spec.tick_size)
              : CeilToTick(sl,g_spec.tick_size));
   if((is_buy && sl>=fill) || (!is_buy && sl<=fill))
     {
      LogEntryBlocked(side,"sl_wrong_side",g_atr);
      return;
     }

   string stop_reason="";
   if(!TRStopDistanceValid(g_cfg,g_spec,fill,sl,g_atr,stop_reason))
     {
      LogEntryBlocked(side,"stop_rejected|"+stop_reason,g_atr);
      return;
     }

   const double tp=ExecTakeProfitPrice(is_buy,fill,sl,InpTakeProfitR);
   if(!ExecTakeProfitValid(is_buy,fill,sl,tp))
     {
      LogEntryBlocked(side,ExecBlockName(EXEC_BLOCK_TP_INVALID),g_atr);
      return;
     }
   if(!ExecStopsRespectBroker(fill,sl,tp,g_spec.point,
                              MathMax(g_spec.stops_level_points,
                                      g_spec.freeze_level_points)))
     {
      LogEntryBlocked(side,ExecBlockName(EXEC_BLOCK_STOP_TOO_CLOSE),g_atr);
      return;
     }

   TRLotDecision lot=TRCalcLot(g_cfg,g_spec,equity,fill,sl);
   if(!lot.ok)
     {
      LogEntryBlocked(side,"lot_rejected|"+lot.reason,g_atr);
      return;
     }
   lot.volume=ExecNormalizeVolume(lot.volume,g_spec.volume_min,
                                  g_spec.volume_max,g_spec.volume_step);
   if(lot.volume<=0.0)
     {
      LogEntryBlocked(side,"lot_rejected|volume_step_invalid",g_atr);
      return;
     }
   lot.expected_loss=NormalizeDouble(lot.volume*lot.loss_per_lot,8);
   if(!ExecRiskBudgetOk(lot.expected_loss,lot.risk_money))
     {
      LogEntryBlocked(side,ExecBlockName(EXEC_BLOCK_RISK_BUDGET),g_atr);
      return;
     }

   double margin=0.0;
   if(!ExecMarginRequired(is_buy,lot.volume,fill,margin) ||
      margin>AccountFreeMargin())
     {
      LogEntryBlocked(side,ExecBlockName(EXEC_BLOCK_MARGIN),g_atr);
      return;
     }

   if(g_dry_run)
     {
      LogDryRun(side,fill,sl,tp,lot,equity);
      return;
     }

   SetState(TR_STATE_ENTRY_REQUESTED,"signal_ready|side="+SimSideName(side));

   ExecFillResult result;
   if(!ExecOpenMarket(is_buy,lot.volume,sl,tp,InpMaxSlippagePoints,
                      InpMagicNumber,"TR_"+SimSideName(side),result))
     {
      LogEvent("ERROR",side,fill,lot.volume,0.0,sl,tp,0.0,
               "open_failed|"+result.message);
      SetState(TR_STATE_WAITING_FOR_SETUP,"open_failed");
      return;
     }

   g_has_position=true;
   g_ticket=result.order;
   g_side=side;
   g_entry=(TRIsFinitePositive(result.price) ? result.price : fill);
   g_volume=(TRIsFinitePositive(result.volume) ? result.volume : lot.volume);
   g_sl=sl;
   g_tp=tp;
   g_initial_risk=MathAbs(g_entry-sl);
   g_initial_risk_money=NormalizeDouble(g_volume*TRLossPerLot(g_spec,g_entry,sl),8);
   g_entry_time=TimeCurrent();
   g_entry_bar=g_analysis_bar;
   g_last_profit=0.0;
   g_close_retries=0;
   g_entries++;
   g_last_block_reason="";
   g_block_logged=false;
   g_reversal_pending=false;
   g_reversal_direction=TR_DIR_UNKNOWN;
   g_has_bos=false;
   g_bos_side=SIM_SIDE_NONE;
   g_bos_level=0.0;
   g_bos_time=0;
   g_persist_dirty=true;

   SetState(TR_STATE_POSITION_OPEN,"order_filled|side="+SimSideName(side));
   LogEvent("ENTRY",side,g_entry,g_volume,g_entry,g_sl,g_tp,g_volume,
            StringFormat("ORDER_FILLED|order=%I64u|deal=%I64u|%s|"+
                         "structure_sl=%.8f|risk_money=%.2f|expected_loss=%.2f|"+
                         "lot=%.2f|tp_r=%.2f|spread_points=%.1f|atr=%.8f|"+
                         "regime=%s",
                         result.order,result.deal,result.message,
                         structure_level,lot.risk_money,lot.expected_loss,
                         g_volume,InpTakeProfitR,
                         (g_point>0.0 ? g_spread_price/g_point : 0.0),g_atr,
                         TRRegimeName(g_last_regime)));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|trendrider_demo|entry|side=%s|fill=%.5f|sl=%.5f|"+
                  "tp=%.5f|lot=%.2f|order=%I64u",
                  SimSideName(side),g_entry,g_sl,g_tp,g_volume,result.order);
  }

//+------------------------------------------------------------------+
//| Per-closed-bar analysis                                          |
//+------------------------------------------------------------------+
void AnalyseClosedBar(const double bid,const double ask)
  {
   if(!g_ready)
      return;
   g_block_logged=false;

   TRBar h1_bars[];
   TRBar m15_bars[];
   TRBar m5_bars[];
   bool data_ok=TRLoadClosedBars(InpTrendTF,InpTrendBars,h1_bars);
   if(data_ok)
      data_ok=TRLoadClosedBars(InpStructureTF,InpStructureBars,m15_bars);
   if(data_ok)
      data_ok=TRLoadClosedBars(InpEntryTF,InpEntryBars,m5_bars);
   if(data_ok)
      data_ok=BarArrayAligned(InpTrendTF,h1_bars) &&
              BarArrayAligned(InpStructureTF,m15_bars) &&
              BarArrayAligned(InpEntryTF,m5_bars);

   double atr_h1=0.0;
   double atr_m15=0.0;
   double atr_m5=0.0;
   double median_m5=0.0;
   if(data_ok)
      data_ok=TRAtr(h1_bars,g_cfg.atr_period,atr_h1) && atr_h1>0.0;
   if(data_ok)
      data_ok=TRAtr(m15_bars,g_cfg.atr_period,atr_m15) && atr_m15>0.0;
   if(data_ok)
      data_ok=TRAtr(m5_bars,g_cfg.atr_period,atr_m5) && atr_m5>0.0;
   if(data_ok)
      data_ok=TRAtrMedian(m5_bars,g_cfg.atr_period,g_cfg.atr_baseline_bars,
                          median_m5) && median_m5>0.0;

   const double spread_price=(ask-bid);
   const double spread_points=TRSpreadPoints(bid,ask,g_point);
   if(data_ok)
      data_ok=TRIsFinitePositive(spread_points);

   if(!data_ok)
     {
      if(!g_data_warned)
        {
         g_data_warned=true;
         LogEvent("RISK",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,0.0,
                  StringFormat("ENTRY_BLOCKED|reason=data_invalid|h1_bars=%d|"+
                               "m15_bars=%d|m5_bars=%d",ArraySize(h1_bars),
                               ArraySize(m15_bars),ArraySize(m5_bars)));
        }
      return;
     }
   g_data_warned=false;
   g_atr=atr_m5;
   g_spread_price=spread_price;
   g_analysis_bar=m5_bars[ArraySize(m5_bars)-1].time;

   const TRStructureSnapshot h1_snapshot=g_h1_engine.Update(h1_bars,g_cfg,
                                                            atr_h1,spread_price);
   const TRStructureSnapshot m15_snapshot=g_m15_engine.Update(m15_bars,g_cfg,
                                                              atr_m15,
                                                              spread_price);
   const TRStructureSnapshot m5_snapshot=g_m5_engine.Update(m5_bars,g_cfg,
                                                            atr_m5,
                                                            spread_price);
   g_m5_structure=m5_snapshot.structure;
   g_m15_chain=m15_snapshot.chain;

   if(h1_snapshot.event!=TR_EVENT_NONE)
      LogEvent("BOS",SIM_SIDE_NONE,h1_snapshot.event_level,0.0,0.0,0.0,0.0,0.0,
               "tf=H1|event="+TREventName(h1_snapshot.event));

   if(m15_snapshot.event!=TR_EVENT_NONE)
     {
      LogEvent("BOS",SIM_SIDE_NONE,m15_snapshot.event_level,0.0,0.0,0.0,0.0,0.0,
               "tf=M15|event="+TREventName(m15_snapshot.event));
      if(g_has_position)
        {
         if(m15_snapshot.event==TR_EVENT_CHOCH_BEAR && g_side==SIM_SIDE_BUY)
           {
            g_reversal_pending=true;
            g_reversal_direction=TR_DIR_BEARISH;
            SetState(TR_STATE_REVERSAL_WATCH,"m15_choch_bear");
           }
         else if(m15_snapshot.event==TR_EVENT_CHOCH_BULL &&
                 g_side==SIM_SIDE_SELL)
           {
            g_reversal_pending=true;
            g_reversal_direction=TR_DIR_BULLISH;
            SetState(TR_STATE_REVERSAL_WATCH,"m15_choch_bull");
           }
        }
     }

   if(m5_snapshot.event!=TR_EVENT_NONE)
      LogEvent("BOS",SIM_SIDE_NONE,m5_snapshot.event_level,0.0,0.0,0.0,0.0,0.0,
               "tf=M5|event="+TREventName(m5_snapshot.event));

   if(m5_snapshot.event==TR_EVENT_BOS_BULL ||
      m5_snapshot.event==TR_EVENT_BOS_BEAR)
     {
      g_has_bos=true;
      g_bos_side=(m5_snapshot.event==TR_EVENT_BOS_BULL ? SIM_SIDE_BUY
                                                       : SIM_SIDE_SELL);
      g_bos_level=m5_snapshot.event_level;
      g_bos_time=m5_snapshot.event_time;
     }
   else if(m5_snapshot.event==TR_EVENT_CHOCH_BULL ||
           m5_snapshot.event==TR_EVENT_CHOCH_BEAR)
     {
      g_has_bos=false;
      g_bos_side=SIM_SIDE_NONE;
      g_bos_level=0.0;
      g_bos_time=0;
     }

   const TRBiasResult bias=TRMergeBias(h1_snapshot.chain,m15_snapshot.chain);
   const bool reversal_watch=g_m15_engine.ChochActive();
   const bool volatility_high=TRVolatilityAbnormal(atr_m5,median_m5,
                                                   g_cfg.abnormal_atr_ratio);
   const bool spread_blocked=(spread_points>g_cfg.max_spread_points ||
                              spread_price>g_cfg.max_spread_atr_ratio*atr_m5);

   const double equity=AccountEquity();
   g_ledger.UpdateEquity(equity,TimeCurrent(),g_cfg);
   const TRGuardDecision guard=g_ledger.EntryBlock(equity,TimeCurrent(),g_cfg);

   const ENUM_TR_REGIME regime=TRResolveRegime(bias,reversal_watch,
                                               volatility_high,spread_blocked,
                                               !guard.allowed,true);
   if(regime!=g_last_regime)
     {
      g_last_regime=regime;
      LogEvent("REGIME",SIM_SIDE_NONE,(bid+ask)*0.5,0.0,g_entry,g_sl,g_tp,0.0,
               "regime="+TRRegimeName(regime)+"|bias="+bias.reason+
               StringFormat("|h1=%s|m15=%s|vol=%d|spread_block=%d|risk_lock=%d",
                            TRDirectionName(h1_snapshot.chain.direction),
                            TRDirectionName(m15_snapshot.chain.direction),
                            (volatility_high ? 1 : 0),(spread_blocked ? 1 : 0),
                            (!guard.allowed ? 1 : 0)));
     }

   if(!g_has_position)
     {
      if(guard.allowed)
        {
         if(g_state.State()==TR_STATE_COOLDOWN ||
            g_state.State()==TR_STATE_DAILY_LOCKED ||
            g_state.State()==TR_STATE_DRAWDOWN_LOCKED)
            SetState(TR_STATE_WAITING_FOR_SETUP,"guard_clear");
        }
      else if(guard.reason=="drawdown_locked")
         SetState(TR_STATE_DRAWDOWN_LOCKED,"guard_drawdown");
      else if(guard.reason=="daily_loss_lock")
         SetState(TR_STATE_DAILY_LOCKED,"guard_daily");
      else if(guard.reason=="cooldown")
         SetState(TR_STATE_COOLDOWN,"guard_cooldown");
     }

   UpdateTrailing(true,bid,ask);

   string block_reason="none";
   if(!g_has_position)
     {
      TRSignalContext ctx;
      ctx.enabled=true;
      ctx.data_ok=true;
      ctx.bias=bias;
      ctx.reversal_watch=reversal_watch;
      ctx.volatility_high=volatility_high;
      ctx.spread_blocked=spread_blocked;
      ctx.risk_locked=!guard.allowed;
      ctx.has_bos=g_has_bos;
      ctx.bos_side=g_bos_side;
      ctx.bos_level=g_bos_level;
      ctx.bos_time=g_bos_time;
      ctx.pullback_start_index=(g_has_bos ? TRFirstIndexAfter(m5_bars,g_bos_time)
                                          : -1);
      ctx.entry_count=ArraySize(m5_bars);
      ctx.atr=atr_m5;
      ctx.spread_price=spread_price;

      const TRSignalDecision decision=TREvaluateSignal(g_cfg,ctx,m5_bars);
      if(!decision.entry)
        {
         block_reason=decision.reason;
         const bool protective=(decision.reason=="ENTRY_BLOCKED|reason=risk_locked" ||
                                decision.reason=="ENTRY_BLOCKED|reason=spread_blocked" ||
                                decision.reason=="ENTRY_BLOCKED|reason=volatility_high" ||
                                decision.reason=="ENTRY_BLOCKED|reason=reversal_watch" ||
                                decision.reason=="ENTRY_BLOCKED|reason=bias_unknown" ||
                                decision.reason=="ENTRY_BLOCKED|reason=timeframe_conflict");
         if(g_has_bos || protective)
            LogEntryBlocked(ctx.bos_side,decision.reason,atr_m5);
         if(StringFind(decision.reason,"bos_too_old")>=0 ||
            StringFind(decision.reason,"ZONE_INVALIDATED")>=0)
           {
            g_has_bos=false;
            g_bos_side=SIM_SIDE_NONE;
            g_bos_level=0.0;
            g_bos_time=0;
           }
        }
      else if(EntryAllowedByState())
         AttemptEntry(m5_snapshot,decision,bid,ask,equity);
      else
         block_reason="state|"+TRStateName(g_state.State());
     }
   else
      block_reason="position_open";

   if(g_persist_dirty)
      WriteStateFile();

   DrawChartStatus(regime,bias.reason,block_reason,atr_m5,spread_points,
                   m5_bars[ArraySize(m5_bars)-1].time);
  }

//+------------------------------------------------------------------+
//| On-chart status panel. Display only: no order/trade calls.       |
//+------------------------------------------------------------------+
void DrawChartStatus(const ENUM_TR_REGIME regime,const string bias_reason,
                     const string block_reason,const double atr,
                     const double spread_points,const datetime bar_time)
  {
   string position="none";
   if(g_has_position)
      position=StringFormat("%s %.2f @ %.3f|sl=%.3f|tp=%.3f",
                            (g_side==SIM_SIDE_BUY ? "BUY" : "SELL"),g_volume,
                            g_entry,g_sl,g_tp);

   const string bar_text=(bar_time>0 ? TimeToString(bar_time,
                                                    TIME_DATE|TIME_MINUTES)
                                    : "-");
   // Comment() always starts at the chart's top-left corner; leading blank
   // lines are dropped, so the panel can overlap the terminal's symbol label.
   Comment(StringFormat(
              "PATrendRiderXAUv1DemoEA  %s  magic=%I64d\n"+
              "%s %s  spread=%.1f pts  atr=%.2f  equity=%.2f\n"+
              "state=%s  regime=%s  bias=%s\n"+
              "bar=%s  block=%s\n"+
              "position=%s  entries=%d  exits=%d  dd=%.2f%%  kill=%d",
              (g_dry_run ? "DRY_RUN" : "DEMO_EXECUTION"),InpMagicNumber,
              _Symbol,g_tf_text,spread_points,atr,AccountEquity(),
              TRStateName(g_state.State()),TRRegimeName(regime),bias_reason,
              bar_text,block_reason,position,g_entries,g_exits,DrawdownPct(),
              (g_kill_switch ? 1 : 0)));
  }

//+------------------------------------------------------------------+
//| Summary                                                          |
//+------------------------------------------------------------------+
void WriteSummary(void)
  {
   if(!g_logger.IsOpen())
      return;
   LogEvent("SUMMARY",SIM_SIDE_NONE,0.0,g_volume,g_entry,g_sl,g_tp,0.0,
            StringFormat("mode=%s|entries=%d|exits=%d|wins=%d|losses=%d|"+
                         "net=%.2f|balance=%.2f|equity=%.2f|drawdown_pct=%.4f|"+
                         "state=%s|ledger=%s|ticket=%I64u|transitions=%d|"+
                         "kill_switch=%d|allowed=%s",
                         (g_dry_run ? "DRY_RUN" : "DEMO_EXECUTION"),g_entries,
                         g_exits,g_wins,g_losses,g_net_pnl,
                         AccountInfoDouble(ACCOUNT_BALANCE),AccountEquity(),
                         DrawdownPct(),TRStateName(g_state.State()),
                         g_ledger.Serialize(),g_ticket,
                         g_state.TransitionCount(),(g_kill_switch ? 1 : 0),
                         InpAllowedSymbols));
  }

//+------------------------------------------------------------------+
//| MT5 events                                                       |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   ConfigFromInputs();

   string error="";
   if(!ValidateInputs(error))
     {
      PrintFormat("LAB|ERROR|trendrider_demo|init_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(!TRLoadSymbolSpec(g_spec,error))
     {
      PrintFormat("LAB|ERROR|trendrider_demo|symbol_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_account.trade_mode=AccountInfoInteger(ACCOUNT_TRADE_MODE);
   g_account.account_trade_allowed=(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)!=0);
   g_account.terminal_trade_allowed=(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0);
   g_account.tester=(MQLInfoInteger(MQL_TESTER)!=0);

   ENUM_EXEC_BLOCK block=EXEC_OK;
   if(!ExecContextAllowed(g_account,block))
     {
      PrintFormat("LAB|ERROR|trendrider_demo|scope_rejected|%s|"
                  "this EA runs on demo or tester accounts only",
                  ExecBlockName(block));
      return(INIT_FAILED);
     }
   if(!ExecSymbolAllowed(_Symbol,InpAllowedSymbols))
     {
      PrintFormat("LAB|ERROR|trendrider_demo|scope_rejected|%s|symbol=%s|"+
                  "allowed=%s",ExecBlockName(EXEC_BLOCK_SYMBOL_DENIED),
                  _Symbol,InpAllowedSymbols);
      return(INIT_FAILED);
     }
   if(!ExecSymbolTradable((long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE),
                          block))
     {
      PrintFormat("LAB|ERROR|trendrider_demo|scope_rejected|%s",
                  ExecBlockName(block));
      return(INIT_FAILED);
     }

   g_point=g_spec.point;
   g_tf_text=TimeframeText();
   g_config_hash=BuildConfigHash();
   g_dry_run=!InpEnableExecution;

   if(InpEnableLog)
     {
      if(!g_logger.Open(InpLogFile,error))
        {
         PrintFormat("LAB|ERROR|trendrider_demo|logger_invalid|%s",error);
         return(INIT_FAILED);
        }
     }

   g_last_forming=0;
   g_analysis_bar=0;
   g_last_exit_bar=0;
   g_last_regime=TR_REGIME_UNKNOWN;
   g_last_block_reason="";
   g_kill_switch=false;
   g_block_logged=false;
   ResetPositionContext();

   bool restored=false;
   const bool state_file_present=(InpPersistState && !InpResetStateOnInit &&
                                  FileIsExist(InpStateFile));
   if(state_file_present)
     {
      restored=RestoreStateFile();
      if(!restored)
         PrintFormat("LAB|ERROR|trendrider_demo|state_restore_failed|file=%s",
                     InpStateFile);
     }

   const double equity=AccountEquity();
   if(!restored && !g_ledger.Init(equity,TimeCurrent()))
     {
      PrintFormat("LAB|ERROR|trendrider_demo|ledger_init_failed");
      return(INIT_FAILED);
     }

   if(!restored || g_state.State()==TR_STATE_INITIALIZING)
     {
      if(!g_state.Transition(TR_STATE_READY,error) ||
         !g_state.Transition(TR_STATE_WAITING_FOR_SETUP,error))
        {
         PrintFormat("LAB|ERROR|trendrider_demo|state_init_failed|%s",error);
         return(INIT_FAILED);
        }
     }

   ExecPositionInfo info;
   if(ExecFindOwnPosition(InpMagicNumber,info))
      AdoptPosition(info,"init_position_found");

   if(InpManualResetDrawdown && g_ledger.DrawdownLockedFlag())
     {
      g_ledger.ManualResetDrawdown(equity);
      g_state.ManualReset(error);
      LogEvent("RESET",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,0.0,
               "manual_drawdown_reset");
     }

   LogEvent("INIT",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,0.0,
            StringFormat("version=1.00|mode=%s|state=%s|restored=%d|"+
                         "symbol=%s|allowed=%s|magic=%I64d|tp_r=%.2f|"+
                         "timeframes=%s|point=%.8f|volume_min=%.2f|"+
                         "volume_step=%.2f|contract_size=%.2f|"+
                         "stops_level_points=%.1f|freeze_level_points=%.1f|"+
                         "equity=%.2f|config_hash=%s",
                         (g_dry_run ? "DRY_RUN" : "DEMO_EXECUTION"),
                         TRStateName(g_state.State()),(restored ? 1 : 0),
                         _Symbol,InpAllowedSymbols,InpMagicNumber,
                         InpTakeProfitR,g_tf_text,g_spec.point,
                         g_spec.volume_min,g_spec.volume_step,
                         g_spec.contract_size,g_spec.stops_level_points,
                         g_spec.freeze_level_points,equity,g_config_hash));

   g_ready=true;
   DrawChartStatus(TR_REGIME_UNKNOWN,"waiting_first_bar","none",0.0,0.0,0);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   Comment("");
   if(!g_ready)
      return;
   WriteSummary();
   WriteStateFile();
   g_ready=false;
  }

void OnTick(void)
  {
   if(!g_ready)
      return;

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(!TRIsFinitePositive(bid) || !TRIsFinitePositive(ask) || ask<bid)
     {
      if(!g_quote_warned)
        {
         g_quote_warned=true;
         LogEvent("ERROR",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,0.0,
                  "quote_invalid|bid_or_ask");
        }
      return;
     }
   g_quote_warned=false;

   SyncPosition();
   g_ledger.UpdateEquity(AccountEquity(),TimeCurrent(),g_cfg);

   if(KillSwitchPresent())
     {
      if(!g_kill_switch)
        {
         g_kill_switch=true;
         g_dry_run=true;
         LogEvent("KILL",SIM_SIDE_NONE,0.0,g_volume,g_entry,g_sl,g_tp,0.0,
                  "kill_switch_file|entries_disabled|file="+InpKillSwitchFile);
         if(g_state.State()!=TR_STATE_ERROR_SAFE_MODE)
            SetState(TR_STATE_ERROR_SAFE_MODE,"kill_switch");
        }
      if(g_has_position)
         CloseWithReason("kill_switch");
      return;
     }
   if(g_kill_switch)
      return;

   ManageOpenPosition(bid,ask);
   UpdateTrailing(false,bid,ask);

   const datetime forming=iTime(_Symbol,InpEntryTF,0);
   if(forming<=0 || forming==g_last_forming)
      return;
   g_last_forming=forming;

   AnalyseClosedBar(bid,ask);
  }
