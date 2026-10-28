//+------------------------------------------------------------------+
//|                                        WonderwhalesSimEA.mq5     |
//|     MT5 EA Lab - Wonderwhales signal with virtual positions      |
//|                                                                  |
//| Opens virtual positions in memory only. No order-send call and   |
//| no trade class: virtual positions, CSV logs and research only.   |
//| The EA is intended for the Strategy Tester, not for live trading.|
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Simulation-only Wonderwhales EA: virtual positions, CSV logs, no trading functions."
#property description "Signals come from iCustom PinePort\\Wonderwhales; exits on PSAR-flip or SL."

#include "../Include/Sim/SimPortfolio.mqh"
#include "../Include/Sim/SimCostModel.mqh"
#include "../Include/Sim/SimRiskGuard.mqh"
#include "../Include/Sim/SimTrailing.mqh"
#include "../Include/Sim/SimLogger.mqh"
#include "../Include/PinePort/WonderwhalesContract.mqh"

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

input group "Simulation"
input double InpInitialBalance      = 10000.0;  // virtual starting balance
input double InpVolume              = 0.10;     // virtual volume per entry
input bool   InpEnableLog           = true;     // write CSV to MQL5/Files
input string InpLogFile             = "sim_wonderwhales_log.csv";
input bool   InpDebug               = false;
input string InpRequireSymbol       = "XAUUSDm"; // empty = accept any symbol

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

input group "Stops"
input ENUM_WW_STOP_MODE InpStopMode = WW_STOP_PSAR;
input double InpAtrPctMultiplier    = 2.0;      // used by ATR% mode
input double InpFixedStopPoints     = 300.0;    // used by fixed mode
input double InpMinStopPoints       = 150.0;    // minimum SL distance from entry
input int    InpMaxHoldingBars      = 0;        // 0 = disabled
input bool   InpExitOnFlip          = true;     // close on the opposite signal

input group "RiskGuard"
input int    InpCooldownBars        = 1;
input double InpMaxSpreadPoints     = 200.0;
input double InpMaxVirtualExposure  = 0.10;     // normalized volume cap
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

int      g_handle=INVALID_HANDLE;
double   g_point=0.0;
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
                     SimFormatFingerprintPartInt("ww.exit_on_flip",
                                                 (InpExitOnFlip ? 1 : 0))+
                     SimFormatFingerprintPartInt("ww.volume",
                                                 (int)MathRound(InpVolume*100))+
                     SimFormatFingerprintPartInt("ww.balance",
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
   record.ea="WonderwhalesSimEA";
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
      PrintFormat("LAB|ERROR|wonderwhales|log_write_failed|%s",error);
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
//| Indicator buffers                                                |
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
      PrintFormat("LAB|ERROR|wonderwhales|close_failed|%s",error);
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
      PrintFormat("LAB|DEBUG|wonderwhales|exit|side=%s|fill=%.5f|sl=%.5f|pnl=%.4f",
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

double ResolveStopDistance(const double psar,const double atr_pct,
                           const double reference)
  {
   double distance=0.0;
   if(InpStopMode==WW_STOP_FIXED)
      distance=InpFixedStopPoints*g_point;
   else if(InpStopMode==WW_STOP_ATR_PCT)
      distance=reference*(atr_pct/100.0)*InpAtrPctMultiplier;
   else
      distance=MathAbs(reference-psar);
   return(distance);
  }

void TryEntry(const datetime bar_time)
  {
   if(g_has_position)
      return;
   if(bar_time==g_last_exit_bar)
      return;
   if(Bars(_Symbol,_Period)<InpWarmupBars+5)
      return;

   double buy_signal=0.0,sell_signal=0.0,psar=0.0,atr_pct=0.0;
   if(!ReadSignalBar(1,buy_signal,sell_signal,psar,atr_pct))
      return;

   ENUM_SIM_SIDE signal=SIM_SIDE_NONE;
   if(buy_signal>0.5)
      signal=SIM_SIDE_BUY;
   else if(sell_signal>0.5)
      signal=SIM_SIDE_SELL;
   if(signal==SIM_SIDE_NONE)
      return;
   if((InpSideFilter==WW_SIDE_LONG_ONLY && signal==SIM_SIDE_SELL) ||
      (InpSideFilter==WW_SIDE_SHORT_ONLY && signal==SIM_SIDE_BUY))
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

   double distance=ResolveStopDistance(psar,atr_pct,fill);
   if(!SimIsFinite(distance) || distance<InpMinStopPoints*g_point)
     {
      LogEvent("RISK",signal,g_mid,InpVolume,0.0,0.0,0.0,
               g_portfolio.Exposure(),
               StringFormat("STOP_REJECTED|distance_points=%.2f|min_points=%.1f",
                            distance/g_point,InpMinStopPoints));
      return;
     }

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
      PrintFormat("LAB|ERROR|wonderwhales|open_failed|%s",error);
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
            StringFormat("SIGNAL_%s|stop_mode=%s|distance_points=%.2f|risk=%s|spread_points=%.1f",
                         (signal==SIM_SIDE_BUY ? "WW_BUY" : "WW_SELL"),
                         EnumToString(InpStopMode),distance/g_point,
                         SimRiskStateName(decision.state),spread_points));
   if(InpDebug)
      PrintFormat("LAB|DEBUG|wonderwhales|entry|side=%s|fill=%.5f|sl=%.5f|psar=%.5f|atr_pct=%.3f",
                  SimSideName(signal),fill,g_sl,psar,atr_pct);
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
      PrintFormat("LAB|ERROR|wonderwhales|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(StringLen(InpRequireSymbol)>0 && _Symbol!=InpRequireSymbol)
     {
      PrintFormat("LAB|ERROR|wonderwhales|init_parameters_invalid|"+
                  "symbol_guard_expected=%s|actual=%s",
                  InpRequireSymbol,_Symbol);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(!SimValidatePoint(g_point,error))
     {
      PrintFormat("LAB|ERROR|wonderwhales|init_parameters_invalid|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   SimCostAssumptions assumptions;
   assumptions.point=g_point;
   assumptions.commission_per_volume=InpCommissionPerVolume;
   assumptions.slippage_points=InpSlippagePoints;
   assumptions.swap_per_volume_day=0.0;
   if(!g_cost.Init(assumptions,error))
     {
      PrintFormat("LAB|ERROR|wonderwhales|cost_init_failed|%s",error);
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
      PrintFormat("LAB|ERROR|wonderwhales|risk_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(!g_portfolio.Init(InpInitialBalance,error))
     {
      PrintFormat("LAB|ERROR|wonderwhales|portfolio_init_failed|%s",error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_handle=iCustom(_Symbol,_Period,"PinePort\\Wonderwhales",
                    InpMode,InpPsarStart,InpPsarInc,InpPsarMax,
                    InpFastEma,InpSlowEma,InpEma200,InpAtrLen,InpMinAtrPct,
                    InpVolMaLen,InpRsiLen,InpBbLen,InpBbMult);
   if(g_handle==INVALID_HANDLE)
     {
      PrintFormat("LAB|ERROR|wonderwhales|indicator_init_failed|error=%d",GetLastError());
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
         PrintFormat("LAB|ERROR|wonderwhales|log_open_failed|%s",error);
         return(INIT_FAILED);
        }
     }

   LogEvent("INIT",SIM_SIDE_NONE,0.0,InpVolume,0.0,0.0,0.0,0.0,
            StringFormat("SIMULATION_ONLY|config_hash=%s|indicator=%s|contract=%s",
                         g_config_hash,WwModeName(InpMode),WW_CONTRACT_VERSION));
   PrintFormat("LAB|INFO|wonderwhales|initialized|hash=%s|log=%s|tester=%d",
               g_config_hash,(InpEnableLog ? InpLogFile : "disabled"),
               (int)MQLInfoInteger(MQL_TESTER));
   PrintFormat("LAB|INFO|wonderwhales|simulation_only|no_orders_are_sent");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   WriteSummary();
   g_logger.Close();
   if(g_handle!=INVALID_HANDLE)
      IndicatorRelease(g_handle);
   PrintFormat("LAB|INFO|wonderwhales|deinit|reason=%d|trades=%d|net=%.2f",
               reason,g_trades,g_net_pnl);
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

   UpdateDayStart(g_portfolio.Equity(g_mid));

   const datetime bar_time=iTime(_Symbol,_Period,0);
   const bool new_bar=(bar_time!=g_last_bar);
   if(new_bar)
      g_last_bar=bar_time;

   if(g_has_position)
     {
      CheckStop(bid,ask);

      if(g_has_position && new_bar)
        {
         if(InpMaxHoldingBars>0)
           {
            const long bars_held=(long)(bar_time-g_entry_bar)/
                                 (long)PeriodSeconds(_Period);
            if(bars_held>=InpMaxHoldingBars)
               ClosePosition(g_side==SIM_SIDE_BUY ? bid : ask,"MAX_HOLDING_BARS");
           }
        }

      if(g_has_position && new_bar && InpExitOnFlip)
        {
         double buy_signal=0.0,sell_signal=0.0,psar=0.0,atr_pct=0.0;
         if(ReadSignalBar(1,buy_signal,sell_signal,psar,atr_pct))
           {
            const bool flipped=(g_side==SIM_SIDE_BUY ? sell_signal>0.5
                                                     : buy_signal>0.5);
            if(flipped)
               ClosePosition(g_side==SIM_SIDE_BUY ? bid : ask,"SIGNAL_FLIP");
           }
        }
     }

   if(!g_has_position && new_bar)
      TryEntry(bar_time);
  }
