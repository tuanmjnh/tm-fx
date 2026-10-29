//+------------------------------------------------------------------+
//|                                      PATrendRiderXAUv1SimEA.mq5 |
//|      PA_TrendRider_XAU_V1 - simulation-only implementation        |
//|                                                                  |
//| Virtual positions only. No order-send, position, account or       |
//| broker API is used: the EA analyses closed H1/M15/M5 bars, sizes  |
//| virtual volume from symbol tick metrics and logs every decision.  |
//| This EA stays simulation-only; demo execution lives in            |
//| PATrendRiderXAUv1DemoEA under docs/decisions/0003-demo-execution- |
//| scope.md. Live execution is still out of scope.                   |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Simulation-only PA TrendRider XAU v1: H1/M15/M5 structure, pullback entry, virtual position."
#property description "No trading functions: virtual positions, CSV logs and research only."

#include "../Include/Sim/SimPortfolio.mqh"
#include "../Include/Sim/SimCostModel.mqh"
#include "../Include/Sim/SimTrailing.mqh"
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

input group "Simulation"
input double InpInitialBalance        = 5000.0;
input bool   InpEnableLog             = true;
input string InpLogFile               = "pa_trendrider_log.csv";
input bool   InpPersistState          = true;
input string InpStateFile             = "pa_trendrider_state.csv";
input bool   InpResetStateOnInit      = false;  // start from a clean ledger
input bool   InpDebug                 = false;

input group "Trading switch"
input bool   InpEnableTrading         = true;
input long   InpMagicNumber           = 25001001; // logged only, no orders are sent

input group "Timeframes"
input ENUM_TIMEFRAMES InpTrendTF      = PERIOD_H1;
input ENUM_TIMEFRAMES InpStructureTF  = PERIOD_M15;
input ENUM_TIMEFRAMES InpEntryTF      = PERIOD_M5;
input int    InpTrendBars             = 300;
input int    InpStructureBars         = 300;
input int    InpEntryBars             = 400;

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
input bool   InpManualResetDrawdown   = false; // explicit operator action at init
input double InpMaxVirtualExposure    = 1.0;

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

input group "Costs (modelled)"
input double InpCommissionPerVolume   = 0.0;
input double InpSlippagePoints        = 0.0;

CSimPortfolio     g_portfolio;
CSimCostModel     g_cost;
CSimLogger        g_logger;
TRRiskLedger      g_ledger;
TRStateMachine    g_state;
TRStructureEngine g_h1_engine;
TRStructureEngine g_m15_engine;
TRStructureEngine g_m5_engine;
TRConfig          g_cfg;
TRSymbolSpec      g_spec;

double   g_point=0.0;
double   g_spread_price=0.0;
double   g_atr=0.0;
string   g_config_hash="";
string   g_tf_text="";
bool     g_ready=false;
bool     g_data_ok=false;
bool     g_entries_enabled=false;
bool     g_persist_dirty=false;
bool     g_state_error_logged=false;
bool     g_data_warned=false;
bool     g_quote_warned=false;
bool     g_logger_error_logged=false;

datetime g_last_forming=0;
datetime g_analysis_bar=0;
datetime g_last_exit_bar=0;
ENUM_TR_REGIME g_last_regime=TR_REGIME_UNKNOWN;
string   g_last_block_reason="";

bool     g_has_position=false;
ENUM_SIM_SIDE g_side=SIM_SIDE_NONE;
double   g_entry=0.0;
double   g_volume=0.0;
double   g_sl=0.0;
double   g_initial_risk=0.0;       // price distance, fixed at entry
double   g_initial_risk_money=0.0;
double   g_entry_commission=0.0;
datetime g_entry_bar=0;

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
int      g_flats=0;
int      g_blocked=0;
double   g_net_pnl=0.0;

//+------------------------------------------------------------------+
//| Small helpers                                                    |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Validation                                                       |
//+------------------------------------------------------------------+
bool ValidateInputs(string &error)
  {
   error="";
   if(!SimValidateInitialBalance(InpInitialBalance,error))
      return(false);
   if(InpMaxPositions!=1)
     {
      error="max_positions_must_be_one_in_v1";
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
      error="timeframes_must_be_ordered_trend_gt_structure_gt_entry";
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
   if(InpStructureBars<g_cfg.swing_left+g_cfg.swing_right+10)
     {
      error="structure_bars_too_small";
      return(false);
     }
   if(InpTrendBars<g_cfg.swing_left+g_cfg.swing_right+10)
     {
      error="trend_bars_too_small";
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
   if(InpPersistState && StringLen(InpStateFile)==0)
     {
      error="state_file_must_not_be_empty";
      return(false);
     }
   error="";
   return(true);
  }

void ConfigFromInputs(void)
  {
   g_cfg=TRConfigDefault();
   g_cfg.swing_left=InpSwingLeft;
   g_cfg.swing_right=InpSwingRight;
   g_cfg.risk_percent=InpRiskPercent;
   g_cfg.max_positions=InpMaxPositions;
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
   g_cfg.max_virtual_exposure=InpMaxVirtualExposure;
   g_cfg.commission_per_volume=InpCommissionPerVolume;
   g_cfg.slippage_points=InpSlippagePoints;
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
   text+=SimFormatFingerprintPart("ea.balance",InpInitialBalance,2);
   text+=SimFormatFingerprintPartInt("ea.enable_trading",
                                     (InpEnableTrading ? 1 : 0));
   text+=SimFormatFingerprintPartInt("ea.log",(InpEnableLog ? 1 : 0));
   return(SimHashString(text));
  }

//+------------------------------------------------------------------+
//| Logging                                                          |
//+------------------------------------------------------------------+
double MidPrice(void)
  {
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(!TRIsFinitePositive(bid) || !TRIsFinitePositive(ask))
      return(0.0);
   return((bid+ask)*0.5);
  }

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
   record.ea="PATrendRiderXAUv1SimEA";
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
   record.equity=(g_portfolio.IsInitialized() ? g_portfolio.Equity(MidPrice())
                                               : 0.0);
   record.drawdown_pct=g_portfolio.MaxDrawdownPct();
   record.reason=reason;

   string error="";
   if(!g_logger.Write(record,error) && !g_logger_error_logged)
     {
      g_logger_error_logged=true;
      PrintFormat("LAB|ERROR|trendrider|log_write_failed|%s",error);
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
         LogEvent("STATE_ERROR",SIM_SIDE_NONE,0.0,g_volume,g_entry,g_sl,0.0,
                  g_portfolio.Exposure(),
                  error+"|desired="+TRStateName(next)+"|reason="+reason);
        }
      return;
     }

   g_state_error_logged=false;
   g_persist_dirty=true;
   LogEvent("STATE",SIM_SIDE_NONE,0.0,g_volume,g_entry,g_sl,0.0,
            g_portfolio.Exposure(),
            "to="+TRStateName(next)+"|reason="+reason+"|transitions="+
            IntegerToString(g_state.TransitionCount()));
  }

//+------------------------------------------------------------------+
//| State persistence                                                |
//+------------------------------------------------------------------+
string PositionSerialize(void)
  {
   if(!g_has_position)
      return("has=0");
   return(StringFormat("has=1;side=%s;entry=%.8f;volume=%.8f;sl=%.8f;"+
                       "risk=%.8f;risk_money=%.8f;entry_commission=%.8f;"+
                       "entry_bar=%I64d",
                       SimSideName(g_side),g_entry,g_volume,g_sl,
                       g_initial_risk,g_initial_risk_money,
                       g_entry_commission,(long)g_entry_bar));
  }

bool PositionDeserialize(const string text)
  {
   string parts[];
   const int count=StringSplit(text,';',parts);
   if(count<1)
      return(false);

   bool has=false;
   ENUM_SIM_SIDE side=SIM_SIDE_NONE;
   double entry=0.0;
   double volume=0.0;
   double sl=0.0;
   double risk=0.0;
   double risk_money=0.0;
   double commission=0.0;
   long entry_bar=0;
   int seen=0;

   for(int i=0; i<count; i++)
     {
      string pair[];
      if(StringSplit(parts[i],'=',pair)!=2)
         continue;
      const string key=pair[0];
      if(key=="has")
        {
         has=(StringToInteger(pair[1])!=0);
         seen++;
        }
      else if(key=="side")
        {
         if(pair[1]=="BUY")
            side=SIM_SIDE_BUY;
         else if(pair[1]=="SELL")
            side=SIM_SIDE_SELL;
         else
            return(false);
        }
      else if(key=="entry")
         entry=StringToDouble(pair[1]);
      else if(key=="volume")
         volume=StringToDouble(pair[1]);
      else if(key=="sl")
         sl=StringToDouble(pair[1]);
      else if(key=="risk")
         risk=StringToDouble(pair[1]);
      else if(key=="risk_money")
         risk_money=StringToDouble(pair[1]);
      else if(key=="entry_commission")
         commission=StringToDouble(pair[1]);
      else if(key=="entry_bar")
         entry_bar=(long)StringToInteger(pair[1]);
     }

   if(seen<1)
      return(false);
   if(!has)
     {
      g_has_position=false;
      return(true);
     }
   if(side==SIM_SIDE_NONE || !TRIsFinitePositive(entry) ||
      !TRIsFinitePositive(volume) || !TRIsFinitePositive(sl) ||
      !TRIsFinitePositive(risk) || !MathIsValidNumber(risk_money) ||
      commission<0.0 || entry_bar<=0)
      return(false);

   g_side=side;
   g_entry=entry;
   g_volume=volume;
   g_sl=sl;
   g_initial_risk=risk;
   g_initial_risk_money=risk_money;
   g_entry_commission=commission;
   g_entry_bar=(datetime)entry_bar;
   g_has_position=true;
   return(true);
  }

bool WriteStateFile(void)
  {
   if(!InpPersistState || StringLen(InpStateFile)==0)
      return(true);

   const int handle=FileOpen(InpStateFile,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle==INVALID_HANDLE)
     {
      PrintFormat("LAB|ERROR|trendrider|state_write_failed|error=%d",
                  GetLastError());
      return(false);
     }
   FileWriteString(handle,"version=1\r\n");
   FileWriteString(handle,"state="+g_state.Serialize()+"\r\n");
   FileWriteString(handle,"ledger="+g_ledger.Serialize()+"\r\n");
   FileWriteString(handle,"position="+PositionSerialize()+"\r\n");
   FileClose(handle);
   g_persist_dirty=false;
   return(true);
  }

//--- Returns false only when the file exists but cannot be trusted.
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
   string position_text="";
   while(!FileIsEnding(handle))
     {
      const string line=FileReadString(handle);
      if(StringFind(line,"version=")==0)
         version=StringSubstr(line,8);
      else if(StringFind(line,"state=")==0)
         state_text=StringSubstr(line,6);
      else if(StringFind(line,"ledger=")==0)
         ledger_text=StringSubstr(line,7);
      else if(StringFind(line,"position=")==0)
         position_text=StringSubstr(line,9);
     }
   FileClose(handle);

   if(version!="1" || StringLen(state_text)==0 || StringLen(ledger_text)==0 ||
      StringLen(position_text)==0)
      return(false);
   if(!g_ledger.Deserialize(ledger_text))
      return(false);
   if(!g_state.Deserialize(state_text))
      return(false);
   if(!PositionDeserialize(position_text))
      return(false);

   LogEvent("RECOVER",g_side,g_entry,g_volume,g_entry,g_sl,0.0,
            g_portfolio.Exposure(),
            "state="+TRStateName(g_state.State())+"|ledger="+
            g_ledger.Serialize()+"|position="+PositionSerialize());
   return(true);
  }

//+------------------------------------------------------------------+
//| Position lifecycle                                               |
//+------------------------------------------------------------------+
void ResetPositionContext(void)
  {
   g_has_position=false;
   g_side=SIM_SIDE_NONE;
   g_entry=0.0;
   g_volume=0.0;
   g_sl=0.0;
   g_initial_risk=0.0;
   g_initial_risk_money=0.0;
   g_entry_commission=0.0;
   g_entry_bar=0;
   g_reversal_pending=false;
   g_reversal_direction=TR_DIR_UNKNOWN;
   g_has_bos=false;
   g_bos_side=SIM_SIDE_NONE;
   g_bos_level=0.0;
   g_bos_time=0;
  }

void CloseVirtual(const double requested,const string exit_reason)
  {
   if(!g_has_position)
      return;

   const ENUM_SIM_SIDE close_side=(g_side==SIM_SIDE_BUY ? SIM_SIDE_SELL
                                                        : SIM_SIDE_BUY);
   const double fill=g_cost.FillPrice(close_side,requested,0.0);
   if(fill<=0.0)
     {
      LogEvent("ERROR",g_side,requested,g_volume,g_entry,g_sl,0.0,
               g_portfolio.Exposure(),"close_fill_invalid");
      SetState(TR_STATE_ERROR_SAFE_MODE,"close_fill_invalid");
      return;
     }

   const double commission=g_cost.Commission(g_volume);
   double realized_delta=0.0;
   string error="";
   if(!g_portfolio.CloseAll(fill,commission,error,realized_delta))
     {
      LogEvent("ERROR",g_side,fill,g_volume,g_entry,g_sl,0.0,
               g_portfolio.Exposure(),"close_failed|"+error);
      SetState(TR_STATE_ERROR_SAFE_MODE,"close_failed");
      return;
     }

   const double trade_pnl=realized_delta-g_entry_commission;
   g_net_pnl+=trade_pnl;
   g_exits++;
   if(trade_pnl>0.0)
      g_wins++;
   else if(trade_pnl<0.0)
      g_losses++;
   else
      g_flats++;

   const long bars_held=(long)(TimeCurrent()-g_entry_bar)/
                        (long)MathMax(PeriodSeconds(InpEntryTF),1);
   LogEvent("EXIT",g_side,fill,g_volume,g_entry,g_sl,0.0,0.0,
            StringFormat("%s|bars=%d|pnl=%.2f|commission=%.2f|"+
                         "initial_risk=%.8f",
                         exit_reason,(int)bars_held,trade_pnl,
                         commission,g_initial_risk));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|trendrider|exit|side=%s|fill=%.5f|pnl=%.2f",
                  SimSideName(g_side),fill,trade_pnl);

   g_ledger.OnTradeClosed(trade_pnl,TimeCurrent(),g_cfg);
   g_last_exit_bar=g_analysis_bar;
   g_last_block_reason="";
   ResetPositionContext();

   if(g_state.State()!=TR_STATE_ERROR_SAFE_MODE)
      SetState(TR_STATE_WAITING_FOR_SETUP,"position_closed|"+exit_reason);
   g_persist_dirty=true;
  }

void ManageOpenPosition(const double bid,const double ask)
  {
   if(!g_has_position)
      return;

   if(SimStopHit(g_side,g_sl,bid,ask))
     {
      const double requested=SimStopFillPrice(g_side,g_sl,bid,ask);
      const double tolerance=g_point*0.5;
      const bool gapped=SimStopGapped(g_side,g_sl,requested,tolerance);
      string reason="SL_HIT";
      if(gapped)
         reason=StringFormat("SL_GAP|gap_points=%.2f",
                             MathAbs(g_sl-requested)/g_point);
      CloseVirtual(requested,reason);
      return;
     }

   if(!g_reversal_pending || !g_m15_chain.valid || g_m15_chain.ranging)
      return;
   if(g_m15_chain.direction!=g_reversal_direction)
      return;

   SetState(TR_STATE_CLOSE_FOR_REVERSAL,
            "m15_confirmed|"+TRDirectionName(g_reversal_direction));
   const double requested=(g_side==SIM_SIDE_BUY ? bid : ask);
   CloseVirtual(requested,
                "REVERSAL_CONFIRMED|m15="+
                TRDirectionName(g_reversal_direction));
  }

void UpdateTrailing(const bool new_bar,const double bid,const double ask)
  {
   if(!g_has_position)
      return;
   if(InpUpdateOnClosedBarOnly && !new_bar)
      return;
   if(!TRIsFinitePositive(g_atr))
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

   const double min_stop=MathMax(g_spec.stops_level_points*g_spec.point,
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
     {
      if(InpDebug && new_bar)
         LogEvent("TRAIL",g_side,price,g_volume,g_entry,g_sl,0.0,
                  g_portfolio.Exposure(),
                  "TRAIL_REJECTED|reason="+out.reason+
                  StringFormat("|profit_r=%.2f",out.profit_r));
      return;
     }

   double candidate=RoundToTick(out.new_sl,g_spec.tick_size);
   candidate=(is_buy ? FloorToTick(candidate,g_spec.tick_size)
                     : CeilToTick(candidate,g_spec.tick_size));

   const bool improves=(is_buy ? candidate>g_sl+1e-12
                               : candidate<g_sl-1e-12);
   const bool violates_distance=(is_buy ? candidate>price-min_stop
                                        : candidate<price+min_stop);
   if(!improves || violates_distance || candidate<=0.0)
     {
      if(InpDebug && new_bar)
         LogEvent("TRAIL",g_side,price,g_volume,g_entry,g_sl,0.0,
                  g_portfolio.Exposure(),
                  StringFormat("TRAIL_REJECTED|reason=rounding_or_distance|"+
                               "candidate=%.8f",candidate));
      return;
     }

   const double old_sl=g_sl;
   g_sl=candidate;
   g_persist_dirty=true;
   LogEvent("TRAIL",g_side,price,g_volume,g_entry,g_sl,0.0,
            g_portfolio.Exposure(),
            StringFormat("%s|old_sl=%.8f|new_sl=%.8f|profit_r=%.2f|atr=%.8f",
                         out.reason,old_sl,g_sl,out.profit_r,g_atr));
  }

void LogEntryBlocked(const ENUM_SIM_SIDE side,const string reason,
                     const double atr)
  {
   if(reason==g_last_block_reason && !g_has_bos)
      return;
   g_last_block_reason=reason;
   g_blocked++;
   const string head=(StringFind(reason,"ENTRY_BLOCKED|")==0
                      ? reason
                      : "ENTRY_BLOCKED|reason="+reason);
   LogEvent("RISK",side,0.0,0.0,g_entry,g_sl,0.0,
            g_portfolio.Exposure(),
            StringFormat("%s|regime=%s|state=%s|"+
                         "spread_points=%.1f|atr=%.8f",
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

void AttemptEntry(const TRStructureSnapshot &m5_snapshot,
                  const TRSignalDecision &decision,const double bid,
                  const double ask,const double equity)
  {
   if(g_has_position)
      return;
   if(!g_entries_enabled)
     {
      LogEntryBlocked(decision.side,"disabled",g_atr);
      return;
     }
   if(!EntryAllowedByState())
     {
      LogEntryBlocked(decision.side,
                      "state_block|state="+TRStateName(g_state.State()),
                      g_atr);
      return;
     }
   if(g_analysis_bar>0 && g_analysis_bar==g_last_exit_bar)
     {
      LogEntryBlocked(decision.side,"same_bar_as_exit",g_atr);
      return;
     }

   const ENUM_SIM_SIDE side=decision.side;
   if(side==SIM_SIDE_NONE)
      return;

   const double structure_level=(side==SIM_SIDE_BUY
                                 ? m5_snapshot.structure.last_low.price
                                 : m5_snapshot.structure.last_high.price);
   if(!TRIsFinitePositive(structure_level))
     {
      LogEntryBlocked(side,"sl_swing_invalid",g_atr);
      return;
     }

   const double requested=(side==SIM_SIDE_BUY ? ask : bid);
   const double fill=g_cost.FillPrice(side,requested,0.0);
   if(!TRIsFinitePositive(fill))
     {
      LogEntryBlocked(side,"entry_fill_invalid",g_atr);
      return;
     }

   const double buffer=g_cfg.atr_stop_buffer*g_atr;
   double sl=(side==SIM_SIDE_BUY ? structure_level-buffer
                                 : structure_level+buffer);
   sl=(side==SIM_SIDE_BUY ? FloorToTick(sl,g_spec.tick_size)
                          : CeilToTick(sl,g_spec.tick_size));

   if((side==SIM_SIDE_BUY && sl>=fill) || (side==SIM_SIDE_SELL && sl<=fill))
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

   const TRLotDecision lot=TRCalcLot(g_cfg,g_spec,equity,fill,sl);
   if(!lot.ok)
     {
      LogEntryBlocked(side,"lot_rejected|"+lot.reason,g_atr);
      return;
     }
   if(g_portfolio.Exposure()+lot.volume>g_cfg.max_virtual_exposure*(1.0+1e-9))
     {
      LogEntryBlocked(side,"exposure_limit",g_atr);
      return;
     }

   const double commission=g_cost.Commission(lot.volume);
   SetState(TR_STATE_ENTRY_REQUESTED,"signal_ready|side="+SimSideName(side));

   string error="";
   if(!g_portfolio.Open(side,fill,lot.volume,commission,error))
     {
      LogEvent("ERROR",side,fill,lot.volume,0.0,0.0,0.0,
               g_portfolio.Exposure(),"open_failed|"+error);
      SetState(TR_STATE_ERROR_SAFE_MODE,"open_failed");
      return;
     }

   g_has_position=true;
   g_side=side;
   g_entry=fill;
   g_volume=lot.volume;
   g_sl=sl;
   g_initial_risk=MathAbs(fill-sl);
   g_initial_risk_money=lot.expected_loss;
   g_entry_commission=commission;
   g_entry_bar=g_analysis_bar;
   g_entries++;
   g_last_block_reason="";
   g_reversal_pending=false;
   g_reversal_direction=TR_DIR_UNKNOWN;
   g_has_bos=false;
   g_bos_side=SIM_SIDE_NONE;
   g_bos_level=0.0;
   g_bos_time=0;
   g_persist_dirty=true;

   SetState(TR_STATE_POSITION_OPEN,"virtual_fill|side="+SimSideName(side));
   LogEvent("ENTRY",side,fill,g_volume,g_entry,g_sl,0.0,g_volume,
            StringFormat("SIGNAL_OK|zone_low=%.8f|zone_high=%.8f|"+
                         "confirm_close=%.8f|bars_since_bos=%d|regime=%s|"+
                         "atr=%.8f|spread_points=%.1f|risk_money=%.2f|"+
                         "expected_loss=%.2f|lot=%.2f|structure_sl=%.8f",
                         decision.zone_low,decision.zone_high,
                         decision.confirm_close,decision.bars_since_bos,
                         TRRegimeName(g_last_regime),g_atr,
                         (g_point>0.0 ? g_spread_price/g_point : 0.0),
                         TRRiskMoney(equity,g_cfg.risk_percent),
                         lot.expected_loss,g_volume,structure_level));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|trendrider|entry|side=%s|fill=%.5f|sl=%.5f|"+
                  "lot=%.2f|atr=%.5f",
                  SimSideName(side),fill,g_sl,g_volume,g_atr);
  }

//+------------------------------------------------------------------+
//| Per-closed-bar analysis                                          |
//+------------------------------------------------------------------+
void AnalyseClosedBar(const double bid,const double ask)
  {
   if(!g_ready)
      return;

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
      g_data_ok=false;
      if(!g_data_warned)
        {
         g_data_warned=true;
         LogEvent("RISK",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,
                  g_portfolio.Exposure(),
                  StringFormat("ENTRY_BLOCKED|reason=data_invalid|h1_bars=%d|"+
                               "m15_bars=%d|m5_bars=%d|atr_h1=%.8f|atr_m15=%.8f|"+
                               "atr_m5=%.8f|median=%.8f",
                               ArraySize(h1_bars),ArraySize(m15_bars),
                               ArraySize(m5_bars),atr_h1,atr_m15,atr_m5,
                               median_m5));
        }
      return;
     }
   g_data_warned=false;
   g_data_ok=true;
   g_atr=atr_m5;
   g_spread_price=spread_price;
   g_analysis_bar=m5_bars[ArraySize(m5_bars)-1].time;

   //--- Structure engines. Each one dedupes by its own bar time.
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
      LogEvent("BOS",SIM_SIDE_NONE,h1_snapshot.event_level,0.0,0.0,0.0,0.0,
               g_portfolio.Exposure(),
               "tf=H1|event="+TREventName(h1_snapshot.event)+
               StringFormat("|level=%.8f",h1_snapshot.event_level));

   if(m15_snapshot.event!=TR_EVENT_NONE)
     {
      LogEvent("BOS",SIM_SIDE_NONE,m15_snapshot.event_level,0.0,0.0,0.0,0.0,
               g_portfolio.Exposure(),
               "tf=M15|event="+TREventName(m15_snapshot.event)+
               StringFormat("|level=%.8f",m15_snapshot.event_level));
      if(g_has_position)
        {
         if(m15_snapshot.event==TR_EVENT_CHOCH_BEAR &&
            g_side==SIM_SIDE_BUY)
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
      LogEvent("BOS",SIM_SIDE_NONE,m5_snapshot.event_level,0.0,0.0,0.0,0.0,
               g_portfolio.Exposure(),
               "tf=M5|event="+TREventName(m5_snapshot.event)+
               StringFormat("|level=%.8f|atr=%.8f",
                            m5_snapshot.event_level,atr_m5));

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

   const double mid=(bid+ask)*0.5;
   const double equity=g_portfolio.Equity(mid);
   g_ledger.UpdateEquity(equity,TimeCurrent(),g_cfg);
   const TRGuardDecision guard=g_ledger.EntryBlock(equity,TimeCurrent(),g_cfg);

   const ENUM_TR_REGIME regime=TRResolveRegime(bias,reversal_watch,
                                               volatility_high,spread_blocked,
                                               !guard.allowed,true);
   if(regime!=g_last_regime)
     {
      g_last_regime=regime;
      LogEvent("REGIME",SIM_SIDE_NONE,mid,0.0,g_entry,g_sl,0.0,
               g_portfolio.Exposure(),
               "regime="+TRRegimeName(regime)+"|bias="+bias.reason+
               StringFormat("|h1=%s|m15=%s|vol=%d|spread_block=%d|"+
                            "risk_lock=%d|median_atr=%.8f",
                            TRDirectionName(h1_snapshot.chain.direction),
                            TRDirectionName(m15_snapshot.chain.direction),
                            (volatility_high ? 1 : 0),
                            (spread_blocked ? 1 : 0),
                            (!guard.allowed ? 1 : 0),median_m5));
     }

   //--- Guard state mirror (an open position is managed regardless).
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

   if(!g_has_position)
     {
      TRSignalContext ctx;
      ctx.enabled=g_entries_enabled;
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
      ctx.pullback_start_index=(g_has_bos
                                ? TRFirstIndexAfter(m5_bars,g_bos_time)
                                : -1);
      ctx.entry_count=ArraySize(m5_bars);
      ctx.atr=atr_m5;
      ctx.spread_price=spread_price;

      const TRSignalDecision decision=TREvaluateSignal(g_cfg,ctx,m5_bars);
      if(!decision.entry)
        {
         const bool protective=(decision.reason=="ENTRY_BLOCKED|reason=risk_locked" ||
                                decision.reason=="ENTRY_BLOCKED|reason=spread_blocked" ||
                                decision.reason=="ENTRY_BLOCKED|reason=volatility_high" ||
                                decision.reason=="ENTRY_BLOCKED|reason=reversal_watch" ||
                                decision.reason=="ENTRY_BLOCKED|reason=bias_unknown" ||
                                decision.reason=="ENTRY_BLOCKED|reason=timeframe_conflict");
         if(g_has_bos || protective)
            LogEntryBlocked(ctx.bos_side,decision.reason,atr_m5);

         //--- A stale or invalidated setup is discarded, not retried forever.
         if(StringFind(decision.reason,"bos_too_old")>=0 ||
            StringFind(decision.reason,"ZONE_INVALIDATED")>=0)
           {
            g_has_bos=false;
            g_bos_side=SIM_SIDE_NONE;
            g_bos_level=0.0;
            g_bos_time=0;
           }
        }
      else
         AttemptEntry(m5_snapshot,decision,bid,ask,equity);
     }

   if(g_persist_dirty)
      WriteStateFile();
  }

//+------------------------------------------------------------------+
//| Summary                                                          |
//+------------------------------------------------------------------+
void WriteSummary(void)
  {
   if(!g_logger.IsOpen())
      return;
   LogEvent("SUMMARY",SIM_SIDE_NONE,0.0,g_volume,g_entry,g_sl,0.0,
            g_portfolio.Exposure(),
            StringFormat("entries=%d|exits=%d|wins=%d|losses=%d|flats=%d|"+
                         "net=%.2f|realized=%.2f|balance=%.2f|max_dd=%.4f|"+
                         "blocked=%d|daily_blocks=%d|dd_blocks=%d|"+
                         "cooldown_blocks=%d|state=%s|ledger=%s|"+
                         "bos=%d|choch=%d|transitions=%d|drawdown_locked=%d|"+
                         "contract_size=%.2f",
                         g_entries,g_exits,g_wins,g_losses,g_flats,
                         g_net_pnl,g_portfolio.RealizedPnl(),
                         g_portfolio.Balance(),g_portfolio.MaxDrawdownPct(),
                         g_blocked,g_ledger.DailyBlocks(),
                         g_ledger.DrawdownBlocks(),g_ledger.CooldownBlocks(),
                         TRStateName(g_state.State()),g_ledger.Serialize(),
                         g_m5_engine.BosCount(),g_m5_engine.ChochCount(),
                         g_state.TransitionCount(),
                         (g_ledger.DrawdownLockedFlag() ? 1 : 0),
                         g_portfolio.ContractSize()));
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
      PrintFormat("LAB|ERROR|trendrider|init_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(!TRLoadSymbolSpec(g_spec,error))
     {
      PrintFormat("LAB|ERROR|trendrider|symbol_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_point=g_spec.point;
   g_tf_text=TimeframeText();
   g_config_hash=BuildConfigHash();

   SimCostAssumptions assumptions=SimCostAssumptionsDefault();
   assumptions.point=g_spec.point;
   assumptions.commission_per_volume=g_cfg.commission_per_volume;
   assumptions.slippage_points=g_cfg.slippage_points;
   assumptions.swap_per_volume_day=0.0;
   if(!g_cost.Init(assumptions,error))
     {
      PrintFormat("LAB|ERROR|trendrider|cost_model_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(!g_portfolio.InitWithContractSize(InpInitialBalance,
                                        g_spec.contract_size,error))
     {
      PrintFormat("LAB|ERROR|trendrider|portfolio_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(InpEnableLog)
     {
      if(!g_logger.Open(InpLogFile,error))
        {
         PrintFormat("LAB|ERROR|trendrider|logger_invalid|%s",error);
         return(INIT_FAILED);
        }
     }

   g_entries_enabled=InpEnableTrading;
   g_last_forming=0;
   g_analysis_bar=0;
   g_last_exit_bar=0;
   g_last_regime=TR_REGIME_UNKNOWN;
   g_last_block_reason="";
   ResetPositionContext();

   bool restored=false;
   bool restore_failed=false;
   if(InpPersistState && !InpResetStateOnInit && FileIsExist(InpStateFile))
     {
      restored=RestoreStateFile();
      restore_failed=!restored;
     }

   if(!restored)
     {
      if(!g_ledger.Init(InpInitialBalance,TimeCurrent()))
        {
         PrintFormat("LAB|ERROR|trendrider|ledger_init_failed");
         return(INIT_FAILED);
        }
     }

   if(restore_failed)
     {
      g_entries_enabled=false;
      g_state.Transition(TR_STATE_ERROR_SAFE_MODE,error);
      LogEvent("ERROR",SIM_SIDE_NONE,0.0,0.0,0.0,0.0,0.0,0.0,
               "state_restore_failed|entries_disabled|"+error);
     }
   else if(!restored)
     {
      if(!g_state.Transition(TR_STATE_READY,error) ||
         !g_state.Transition(TR_STATE_WAITING_FOR_SETUP,error))
        {
         PrintFormat("LAB|ERROR|trendrider|state_init_failed|%s",error);
         return(INIT_FAILED);
        }
     }
   else if(g_state.State()==TR_STATE_INITIALIZING)
     {
      if(!g_state.Transition(TR_STATE_READY,error) ||
         !g_state.Transition(TR_STATE_WAITING_FOR_SETUP,error))
        {
         PrintFormat("LAB|ERROR|trendrider|state_init_failed|%s",error);
         return(INIT_FAILED);
        }
     }

   if(restored && g_has_position &&
      g_state.State()!=TR_STATE_POSITION_OPEN &&
      g_state.State()!=TR_STATE_REVERSAL_WATCH &&
      g_state.State()!=TR_STATE_CLOSE_FOR_REVERSAL)
     {
      g_entries_enabled=false;
      g_state.Transition(TR_STATE_ERROR_SAFE_MODE,error);
      LogEvent("ERROR",SIM_SIDE_NONE,g_entry,g_volume,g_entry,g_sl,0.0,
               g_portfolio.Exposure(),
               "restored_position_state_mismatch|state="+
               TRStateName(g_state.State())+"|entries_disabled");
     }

   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double mid=((TRIsFinitePositive(bid) && TRIsFinitePositive(ask))
                     ? (bid+ask)*0.5 : 0.0);

   if(InpManualResetDrawdown && g_ledger.DrawdownLockedFlag())
     {
      g_ledger.ManualResetDrawdown(mid);
      string reset_error="";
      g_state.ManualReset(reset_error);
      if(mid>0.0)
         LogEvent("RESET",SIM_SIDE_NONE,mid,0.0,0.0,0.0,0.0,0.0,
                  "manual_drawdown_reset|"+reset_error);
     }

   LogEvent("INIT",SIM_SIDE_NONE,mid,0.0,0.0,0.0,0.0,0.0,
            StringFormat("version=1.00|state=%s|restored=%d|"+
                         "timeframes=%s|bars=%d/%d/%d|"+
                         "point=%.8f|tick_size=%.8f|tick_value=%.8f|"+
                         "volume_min=%.2f|volume_step=%.2f|volume_max=%.2f|"+
                         "contract_size=%.2f|stops_level_points=%.1f|"+
                         "freeze_level_points=%.1f|balance=%.2f|"+
                         "magic=%I64d|currency=assumed_account|"+
                         "spread_points=%.1f|config_hash=%s",
                         TRStateName(g_state.State()),(restored ? 1 : 0),
                         g_tf_text,InpTrendBars,InpStructureBars,InpEntryBars,
                         g_spec.point,g_spec.tick_size,g_spec.tick_value,
                         g_spec.volume_min,g_spec.volume_step,
                         g_spec.volume_max,g_spec.contract_size,
                         g_spec.stops_level_points,g_spec.freeze_level_points,
                         InpInitialBalance,InpMagicNumber,
                         (g_point>0.0 && mid>0.0 ? (ask-bid)/g_point : 0.0),
                         g_config_hash));

   g_ready=true;
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
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

   const double mid=(bid+ask)*0.5;
   const double equity=g_portfolio.Equity(mid);
   g_ledger.UpdateEquity(equity,TimeCurrent(),g_cfg);

   ManageOpenPosition(bid,ask);

   const datetime forming=iTime(_Symbol,InpEntryTF,0);
   if(forming<=0 || forming==g_last_forming)
      return;
   g_last_forming=forming;

   AnalyseClosedBar(bid,ask);
  }
