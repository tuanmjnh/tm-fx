//+------------------------------------------------------------------+
//|                                              PriceActionMTF.mq5  |
//|      MT5 EA & AI Lab - PinePort of Price Action MTF (signal only)|
//|                                                                  |
//| Custom indicator only. No file I/O, no account access, no order  |
//| functions. Contract: docs/indicators/price-action-mtf.md       |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Price Action MTF signal indicator. Confirmed bars only; no trading."
#property indicator_chart_window
#property indicator_buffers 107
#property indicator_plots   12

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1
#property indicator_label1  "EMA Fast"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  1
#property indicator_label2  "EMA Mid"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSilver
#property indicator_width3  1
#property indicator_label3  "EMA Slow"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGold
#property indicator_width4  1
#property indicator_label4  "VWAP"
#property indicator_type5   DRAW_HISTOGRAM
#property indicator_color5  clrGray
#property indicator_width5  1
#property indicator_label5  "Volume"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrAqua
#property indicator_width6  1
#property indicator_label6  "Volume MA"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrLime
#property indicator_width7  1
#property indicator_label7  "PA LONG"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrRed
#property indicator_width8  1
#property indicator_label8  "PA SHORT"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  clrGold
#property indicator_width9  1
#property indicator_label9  "TP Hit"
#property indicator_type10  DRAW_ARROW
#property indicator_color10 clrMagenta
#property indicator_width10 1
#property indicator_label10 "SL Hit"
#property indicator_type11  DRAW_LINE
#property indicator_color11 clrRed
#property indicator_style11 STYLE_DOT
#property indicator_width11 1
#property indicator_label11 "Active SL"
#property indicator_type12  DRAW_LINE
#property indicator_color12 clrMediumSeaGreen
#property indicator_style12 STYLE_DOT
#property indicator_width12 1
#property indicator_label12 "Active TP1"

#include "../../Include/PinePort/PriceActionMTFContract.mqh"

//--- EA bridge overrides. These two inputs MUST stay first: iCustom passes
//--- parameters positionally and no input group is declared anywhere in this
//--- file, because an "input group" line consumes an iCustom slot.
//--- 0 = keep the strategy default from InpRr1 / InpRrMin further down.
input double            InpRr1Ea             = 0.0;              // EA bridge: TP1 R multiple (0 = InpRr1)
input double            InpRrMinEa           = 0.0;              // EA bridge: min TP1 R multiple (0 = InpRrMin)

input int               InpSrvOffsetMin      = 180;              // Server to UTC offset (minutes)
input int               InpMktOffsetMin      = -300;             // UTC to market offset (minutes)
input int               InpVolSessOffsetMin  = 420;              // UTC to volume-session offset (minutes)
input int               InpMaxBars           = 0;                // Debug: replay last N bars (0 = all)
input int               InpSwingLen          = 5;                // Structure/swing pivot length
input bool              InpRetestOn          = true;             // Enable retest events
input int               InpRetestBars        = 10;               // Retest window (bars)
input double            InpRetestTolAtr      = 0.5;              // Retest tolerance (x ATR)
input bool              InpFailOn            = true;             // Enable failed breakout
input int               InpFailBars          = 5;                // Failed breakout window
input bool              InpContOn            = true;             // Enable continuation
input bool              InpPullOn            = true;             // Enable pullback
input double            InpEqTolAtr          = 0.05;             // Equal high/low tolerance (x ATR)
input bool              InpPdOn              = true;             // Enable PDH/PDL liquidity
input bool              InpPwOn              = false;            // Enable PWH/PWL liquidity
input bool              InpSessOn            = true;             // Enable session levels
input int               InpSrLeft            = 10;               // S/R pivot left bars
input int               InpSrRight           = 10;               // S/R pivot right bars
input double            InpSrWidthAtr        = 0.5;              // S/R zone width (x ATR)
input int               InpSrMax             = 8;                // Max live S/R zones
input double            InpFvgMinAtr         = 0.3;              // FVG minimum size (x ATR)
input int               InpFvgMax            = 20;               // Max live FVGs
input int               InpFvgLife           = 100;              // FVG lifetime (bars)
input int               InpObMax             = 20;               // Max live order blocks
input double            InpPinRatio          = 2.0;              // Pin bar wick/body ratio
input bool              InpEngulfOn          = true;             // Enable engulfing
input bool              InpPinOn             = true;             // Enable pin bar
input bool              InpDispOn            = true;             // Enable displacement
input double            InpDispAtr           = 1.5;              // Displacement size (x ATR)
input bool              InpRejOn             = true;             // Enable rejection wick
input bool              InpIbOn              = true;             // Enable inside bar
input bool              InpDojiOn            = true;             // Enable doji
input double            InpDojiMax           = 0.10;             // Doji max body/range
input bool              InpSoldOn            = true;             // Enable 3 soldiers/crows
input double            InpStrongBody        = 0.50;             // Strong body/range threshold
input bool              InpVolVetoOn         = true;             // Enable low-volume veto
input double            InpVolVetoR          = 1.2;              // Volume veto ratio
input bool              InpStreakOn          = true;             // Enable engulf streak bonus
input int               InpStreakMin         = 2;                // Streak length for bonus
input double            InpStreakAdd         = 0.5;              // Streak score bonus
input int               InpEmaFast           = 20;               // EMA fast length
input int               InpEmaMid            = 50;               // EMA mid length
input int               InpEmaSlow           = 200;              // EMA slow length
input int               InpAtrLen            = 14;               // ATR length
input int               InpRsiLen            = 14;               // RSI length
input double            InpRsiOb             = 70;               // RSI overbought
input double            InpRsiOs             = 30;               // RSI oversold
input int               InpMacdFast          = 12;               // MACD fast
input int               InpMacdSlow          = 26;               // MACD slow
input int               InpMacdSignal        = 9;                // MACD signal
input int               InpDmiLen            = 14;               // DMI length
input int               InpDmiSmooth         = 14;               // ADX smoothing
input double            InpAdxMin            = 20;               // ADX minimum for DMI score
input int               InpBbLen             = 20;               // Bollinger length
input double            InpBbMult            = 2.0;              // Bollinger multiplier
input int               InpRvLen             = 20;               // Relative volume window
input double            InpRvMin             = 1.2;              // Relative volume minimum
input int               InpObvLen            = 20;               // OBV slope length
input int               InpVolMaLen          = 20;               // Volume MA length (RMA)
input double            InpVolSpikeR         = 2.2;              // TIM spike ratio
input double            InpVolRVH            = 1.8;              // VSA very high ratio
input double            InpVolRH             = 1.2;              // VSA high ratio
input double            InpVolRN             = 0.8;              // VSA normal ratio
input double            InpVolRL             = 0.4;              // VSA low ratio
input double            InpVolMin            = 0.0;              // Minimum volume event (0 = off)
input bool              InpVolSessOn         = false;            // Limit TIM to volume session
input int               InpVolSessStartMin   = 480;              // Volume session start (minute)
input int               InpVolSessEndMin     = 960;              // Volume session end (minute)
input ENUM_TIMEFRAMES   InpCtxTf             = PERIOD_D1;        // Context timeframe (H4/D1/W1/MN1)
input int               InpCtxLen            = 200;              // Context EMA length
input ENUM_TIMEFRAMES   InpSetupTf           = PERIOD_H1;        // Setup timeframe (M15/H1)
input int               InpSetupLen          = 50;               // Setup EMA length
input bool              InpHtfFilter         = true;             // Enable setup-TF filter
input bool              InpHtfVetoOn         = true;             // Enable context-TF veto
input double            InpWTrend            = 15;               // Weight: trend
input double            InpWStruct           = 15;               // Weight: structure
input double            InpWLiq              = 12;               // Weight: liquidity
input double            InpWLoc              = 8;                // Weight: location
input double            InpWSr               = 10;               // Weight: support/resistance
input double            InpWCandle           = 10;               // Weight: candle
input double            InpWVol              = 8;                // Weight: volume
input double            InpWAtr              = 7;                // Weight: volatility
input double            InpWMom              = 7;                // Weight: momentum
input double            InpWSess             = 4;                // Weight: session
input double            InpWMtf              = 4;                // Weight: MTF
input int               InpScrNoTrade        = 49;               // No-trade score threshold
input int               InpScrWeak           = 64;               // Weak score threshold
input int               InpScrSetup          = 74;               // Setup score threshold
input int               InpScrStrong         = 84;               // Strong score threshold
input double            InpSlAtrMul          = 1.5;              // SL ATR multiplier
input int               InpSlSwing           = 10;               // SL swing window
input double            InpSlPadAtr          = 0.2;              // SL pad (x ATR)
input double            InpSlMinAtr          = 0.5;              // Minimum risk (x ATR)
input double            InpSlMaxAtr          = 3.0;              // Maximum risk (x ATR)
input double            InpRr1               = 1.0;              // TP1 R multiple
input double            InpRr2               = 2.0;              // TP2 R multiple
input double            InpRr3               = 3.0;              // TP3 R multiple
input double            InpRrMin             = 1.5;              // Minimum TP1 R multiple
input int               InpMaxDay            = 3;                // Max entries per server day
input int               InpCoolBars          = 10;               // Cooldown bars between signals
input ENUM_PA_TP_MODE   InpTpMode            = PA_TP_R;          // TP mode (R / measured move)
input bool              InpTpMmFallback      = true;             // Fall back to R when MM missing
input bool              InpRegOn             = true;             // Enable regime gate
input double            InpRegAdxTrend       = 25;               // ADX trending threshold
input double            InpRegAdxChop        = 18;               // ADX choppy threshold
input int               InpRegBbwLen         = 100;              // BBW percentile window
input double            InpRegBbwSqueeze     = 20;               // BBW squeeze percentile
input double            InpRegRangeEdge      = 0.35;             // Range-edge tolerance (x ATR)
input bool              InpPatOn             = true;             // Enable chart patterns
input double            InpPatBandAtr        = 0.5;              // Pattern equal-level band (x ATR)
input int               InpPatMaxBars        = 200;              // Pattern freshness window
input double            InpHsRatio           = 1.2;              // H&S head/shoulder ratio
input bool              InpCfOn              = true;             // Enable confluence gate
input double            InpCfLevelTolAtr     = 0.5;              // Confluence level tolerance (x ATR)
input bool              InpCfRequire3        = true;             // Require all 3 confluences

//--- Render buffers 0..11 (plots 0..11)
double g_plot_ema_fast[];
double g_plot_ema_mid[];
double g_plot_ema_slow[];
double g_plot_vwap[];
double g_plot_volume[];
double g_plot_vol_ma[];
double g_plot_long_entry[];
double g_plot_short_entry[];
double g_plot_hit_tp[];
double g_plot_hit_sl[];
double g_plot_active_sl[];
double g_plot_active_tp1[];

//--- Contract buffers 12..106
double g_b_score100[];
double g_b_dir[];
double g_b_quality[];
double g_b_confluence[];
double g_b_regime[];
double g_b_plan_valid[];
double g_b_entry[];
double g_b_sl[];
double g_b_tp1[];
double g_b_tp2[];
double g_b_tp3[];
double g_b_risk[];
double g_b_sig_long[];
double g_b_sig_short[];
double g_b_block[];
double g_b_ev_entry[];
double g_b_ev_tp1[];
double g_b_ev_tp2[];
double g_b_ev_tp3[];
double g_b_ev_sl[];
double g_b_ev_close[];
double g_b_close_reason[];
double g_b_pos_dir[];
double g_b_pos_entry[];
double g_b_pos_sl[];
double g_b_pos_tp1[];
double g_b_pos_tp2[];
double g_b_pos_tp3[];
double g_b_pos_risk[];
double g_b_pos_stage[];
double g_b_pos_bars[];
double g_b_day_count[];
double g_b_bars_since[];
double g_b_trades[];
double g_b_wins[];
double g_b_losses[];
double g_b_trend[];
double g_b_bos_up[];
double g_b_bos_dn[];
double g_b_choch_up[];
double g_b_choch_dn[];
double g_b_mss_up[];
double g_b_mss_dn[];
double g_b_retest_up[];
double g_b_retest_dn[];
double g_b_fail_up[];
double g_b_fail_dn[];
double g_b_sweep_up[];
double g_b_sweep_dn[];
double g_b_hh[];
double g_b_hl[];
double g_b_lh[];
double g_b_ll[];
double g_b_cont_up[];
double g_b_cont_dn[];
double g_b_pull_up[];
double g_b_pull_dn[];
double g_b_pattern[];
double g_b_pattern_dir[];
double g_b_pattern_h[];
double g_b_candle_score[];
double g_b_atr[];
double g_b_atr_pct[];
double g_b_rsi[];
double g_b_macd[];
double g_b_adx[];
double g_b_di_plus[];
double g_b_di_minus[];
double g_b_bb_width[];
double g_b_vol_ratio[];
double g_b_rel_vol[];
double g_b_obv_slope[];
double g_b_vwap[];
double g_b_pdh[];
double g_b_pdl[];
double g_b_pwh[];
double g_b_pwl[];
double g_b_sess_hi[];
double g_b_sess_lo[];
double g_b_vol_bucket[];
double g_b_sess_name[];
double g_b_ctx_dir[];
double g_b_setup_dir[];
double g_b_htf_veto[];
double g_b_cf1[];
double g_b_cf2[];
double g_b_cf3[];
double g_b_near_sup[];
double g_b_near_res[];
double g_b_near_fvg_bull[];
double g_b_near_fvg_bear[];
double g_b_swing_lo[];
double g_b_swing_hi[];
double g_b_last_high[];
double g_b_last_low[];

PaConfig g_cfg;
int      g_last_rates=-1;

//--- Incremental replay: engine state after g_replayBar, reused while the
//--- history only grows (maxBars==0). Everything the engine consumes for bar
//--- j is causal (series, pivots, necklines), so a cached state stays valid.
//--- Guard: same bar time AND same close as when the state was saved, so a
//--- revised last bar falls back to a full replay instead of a stale state.
bool         g_replayValid=false;
PaEngineState g_replayState;
int          g_replayBar=-1;
datetime     g_replayTime=0;
double       g_replayClose=0.0;
int          g_replayTotal=0;

//--- Stable HTF cache: CopyRates(0,3000) slides its window, so raw copies
//--- would recompute a different EMA for bars that fall out of the window.
//--- Keep an append-only cache of closed HTF bars instead.
ENUM_TIMEFRAMES g_ctxTfCache=PERIOD_CURRENT;
ENUM_TIMEFRAMES g_setupTfCache=PERIOD_CURRENT;
int             g_ctxLenCache=-1;
int             g_setupLenCache=-1;
datetime        g_ctxCloseT[],g_setupCloseT[];
double          g_ctxCloses[],g_setupCloses[];
datetime        g_ctxWinT[],g_setupWinT[];
double          g_ctxEma[],g_setupEma[];

//--- Incremental replay: 0 = full replay from bar 0 on every new bar,
//--- 1 = reuse the cached engine state and replay only the new closed bar.
//--- The switch exists for A/B equivalence testing; both settings must
//--- produce identical output series.
#define PA_REPLAY_INCREMENTAL 1
//--- EMA window over the cached HTF history: 0 = whole history,
//--- N>0 = last N closed HTF bars. Kept at 3000 to preserve the signal
//--- semantics of the original CopyRates(0,3000) window.
#define PA_HTF_WINDOW 3000

//+------------------------------------------------------------------+
//| Append newly closed HTF bars to the cache                        |
//+------------------------------------------------------------------+
void PaAppendHtfCache(const ENUM_TIMEFRAMES tf,const datetime lastBarTime,
                      datetime &closeT[],double &closes[])
  {
   const int htfSeconds=(int)PeriodSeconds(tf);
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   const int got=CopyRates(_Symbol,tf,0,3000,rates);
   if(got<=0)
      return;
   const bool descending=(got>1 && rates[0].time>rates[got-1].time);
   const int cached=ArraySize(closeT);
   const datetime lastCached=(cached>0 ? closeT[cached-1] : 0);
   int added=0;
   ArrayResize(closeT,cached+got);
   ArrayResize(closes,cached+got);
   for(int k=0; k<got; k++)
     {
      const int src=(descending ? got-1-k : k);
      const datetime closeTime=rates[src].time+htfSeconds;
      if(closeTime>lastBarTime || closeTime<=lastCached)
         continue;
      closeT[cached+added]=closeTime;
      closes[cached+added]=rates[src].close;
      added++;
     }
   if(added<=0)
     {
      ArrayResize(closeT,cached);
      ArrayResize(closes,cached);
      return;
     }
   ArrayResize(closeT,cached+added);
   ArrayResize(closes,cached+added);
  }

//+------------------------------------------------------------------+
//| EMA over the mapped HTF window                                   |
//+------------------------------------------------------------------+
void PaBuildHtfEma(const datetime &closeT[],const double &closes[],const int len,
                   datetime &winT[],double &winEma[])
  {
   const int count=ArraySize(closeT);
   int first=0;
   if(PA_HTF_WINDOW>0)
      first=MathMax(0,count-PA_HTF_WINDOW);
   const int n=count-first;
   ArrayResize(winT,n);
   double tail[];
   ArrayResize(tail,n);
   for(int i=0; i<n; i++)
     {
      winT[i]=closeT[first+i];
      tail[i]=closes[first+i];
     }
   PaBuildEma(tail,n,len,winEma);
  }

void PaMapHtfSeries(const datetime &closeT[],const double &ema[],const int total,
                    const datetime &time[],const int fromBar,
                    double &emaOut[],bool &validOut[])
  {
   const int count=ArraySize(closeT);
   for(int j=fromBar; j<total; j++)
     {
      const int k=PaMapHtfIndex(closeT,count,time[j]);
      if(k<0 || PaIsEmpty(ema[k]))
         continue;
      emaOut[j]=ema[k];
      validOut[j]=true;
     }
  }

//+------------------------------------------------------------------+
//| Higher-timeframe EMA mapped onto closed HTF bars                 |
//+------------------------------------------------------------------+
void PaLoadHtfEma(const ENUM_TIMEFRAMES tf,const int len,const int total,
                  const datetime &time[],const datetime lastBarTime,const int fromBar,
                  double &emaOut[],bool &validOut[])
  {
   ArrayResize(emaOut,total);
   ArrayInitialize(emaOut,EMPTY_VALUE);
   ArrayResize(validOut,total);
   ArrayInitialize(validOut,false);
   if(len<=0)
      return;

   if(tf==g_ctxTfCache && len==g_ctxLenCache)
     {
      PaAppendHtfCache(tf,lastBarTime,g_ctxCloseT,g_ctxCloses);
      PaBuildHtfEma(g_ctxCloseT,g_ctxCloses,len,g_ctxWinT,g_ctxEma);
      PaMapHtfSeries(g_ctxWinT,g_ctxEma,total,time,fromBar,emaOut,validOut);
      return;
     }
   PaAppendHtfCache(tf,lastBarTime,g_setupCloseT,g_setupCloses);
   PaBuildHtfEma(g_setupCloseT,g_setupCloses,len,g_setupWinT,g_setupEma);
   PaMapHtfSeries(g_setupWinT,g_setupEma,total,time,fromBar,emaOut,validOut);
  }

//+------------------------------------------------------------------+
//| Neckline buffers for DT/HST and DB/HSN                           |
//+------------------------------------------------------------------+
void PaBuildNecklines(const double &high[],const double &low[],const int total,
                      const int swingLen,double &neckLow[],double &neckHigh[])
  {
   ArrayResize(neckLow,total);
   ArrayResize(neckHigh,total);
   ArrayInitialize(neckLow,EMPTY_VALUE);
   ArrayInitialize(neckHigh,EMPTY_VALUE);

   double hiPx[PA_PIV_HIST];
   int    hiBar[PA_PIV_HIST];
   int    hiCount=0;
   double loPx[PA_PIV_HIST];
   int    loBar[PA_PIV_HIST];
   int    loCount=0;

   for(int j=0; j<total; j++)
     {
      double value=EMPTY_VALUE;
      if(PaPivotHighAt(high,total,j,swingLen,swingLen,value))
        {
         if(hiCount>=PA_PIV_HIST)
           {
            for(int i=1; i<hiCount; i++)
              {
               hiPx[i-1]=hiPx[i];
               hiBar[i-1]=hiBar[i];
              }
            hiCount=PA_PIV_HIST-1;
           }
         hiPx[hiCount]=value;
         hiBar[hiCount]=j-swingLen;
         hiCount+=1;
         if(hiCount>=2)
           {
            const int b1=hiBar[hiCount-2];
            const int b2=hiBar[hiCount-1];
            neckLow[j]=PaNeckMinLow(low,total,b1,b2);
           }
        }

      value=EMPTY_VALUE;
      if(PaPivotLowAt(low,total,j,swingLen,swingLen,value))
        {
         if(loCount>=PA_PIV_HIST)
           {
            for(int i=1; i<loCount; i++)
              {
               loPx[i-1]=loPx[i];
               loBar[i-1]=loBar[i];
              }
            loCount=PA_PIV_HIST-1;
           }
         loPx[loCount]=value;
         loBar[loCount]=j-swingLen;
         loCount+=1;
         if(loCount>=2)
           {
            const int b1=loBar[loCount-2];
            const int b2=loBar[loCount-1];
            neckHigh[j]=PaNeckMaxHigh(high,total,b1,b2);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_cfg.srvOffsetMin=InpSrvOffsetMin;
   g_cfg.mktOffsetMin=InpMktOffsetMin;
   g_cfg.volSessOffsetMin=InpVolSessOffsetMin;
   g_cfg.maxBars=InpMaxBars;
   g_cfg.swingLen=InpSwingLen;
   g_cfg.retestOn=InpRetestOn;
   g_cfg.retestBars=InpRetestBars;
   g_cfg.retestTolAtr=InpRetestTolAtr;
   g_cfg.failOn=InpFailOn;
   g_cfg.failBars=InpFailBars;
   g_cfg.contOn=InpContOn;
   g_cfg.pullOn=InpPullOn;
   g_cfg.eqTolAtr=InpEqTolAtr;
   g_cfg.pdOn=InpPdOn;
   g_cfg.pwOn=InpPwOn;
   g_cfg.sessOn=InpSessOn;
   g_cfg.srLeft=InpSrLeft;
   g_cfg.srRight=InpSrRight;
   g_cfg.srWidthAtr=InpSrWidthAtr;
   g_cfg.srMax=InpSrMax;
   g_cfg.fvgMinAtr=InpFvgMinAtr;
   g_cfg.fvgMax=InpFvgMax;
   g_cfg.fvgLife=InpFvgLife;
   g_cfg.obMax=InpObMax;
   g_cfg.pinRatio=InpPinRatio;
   g_cfg.engulfOn=InpEngulfOn;
   g_cfg.pinOn=InpPinOn;
   g_cfg.dispOn=InpDispOn;
   g_cfg.dispAtr=InpDispAtr;
   g_cfg.rejOn=InpRejOn;
   g_cfg.ibOn=InpIbOn;
   g_cfg.dojiOn=InpDojiOn;
   g_cfg.dojiMax=InpDojiMax;
   g_cfg.soldOn=InpSoldOn;
   g_cfg.strongBody=InpStrongBody;
   g_cfg.volVetoOn=InpVolVetoOn;
   g_cfg.volVetoR=InpVolVetoR;
   g_cfg.streakOn=InpStreakOn;
   g_cfg.streakMin=InpStreakMin;
   g_cfg.streakAdd=InpStreakAdd;
   g_cfg.emaFast=InpEmaFast;
   g_cfg.emaMid=InpEmaMid;
   g_cfg.emaSlow=InpEmaSlow;
   g_cfg.atrLen=InpAtrLen;
   g_cfg.rsiLen=InpRsiLen;
   g_cfg.rsiOb=InpRsiOb;
   g_cfg.rsiOs=InpRsiOs;
   g_cfg.macdFast=InpMacdFast;
   g_cfg.macdSlow=InpMacdSlow;
   g_cfg.macdSignal=InpMacdSignal;
   g_cfg.dmiLen=InpDmiLen;
   g_cfg.dmiSmooth=InpDmiSmooth;
   g_cfg.adxMin=InpAdxMin;
   g_cfg.bbLen=InpBbLen;
   g_cfg.bbMult=InpBbMult;
   g_cfg.rvLen=InpRvLen;
   g_cfg.rvMin=InpRvMin;
   g_cfg.obvLen=InpObvLen;
   g_cfg.volMaLen=InpVolMaLen;
   g_cfg.volSpikeR=InpVolSpikeR;
   g_cfg.volRVH=InpVolRVH;
   g_cfg.volRH=InpVolRH;
   g_cfg.volRN=InpVolRN;
   g_cfg.volRL=InpVolRL;
   g_cfg.volMin=InpVolMin;
   g_cfg.volSessOn=InpVolSessOn;
   g_cfg.volSessStartMin=InpVolSessStartMin;
   g_cfg.volSessEndMin=InpVolSessEndMin;
   g_cfg.ctxTf=InpCtxTf;
   g_cfg.ctxLen=InpCtxLen;
   g_cfg.setupTf=InpSetupTf;
   g_cfg.setupLen=InpSetupLen;
   g_cfg.htfFilter=InpHtfFilter;
   g_cfg.htfVetoOn=InpHtfVetoOn;
   g_cfg.wTrend=InpWTrend;
   g_cfg.wStruct=InpWStruct;
   g_cfg.wLiq=InpWLiq;
   g_cfg.wLoc=InpWLoc;
   g_cfg.wSr=InpWSr;
   g_cfg.wCandle=InpWCandle;
   g_cfg.wVol=InpWVol;
   g_cfg.wAtr=InpWAtr;
   g_cfg.wMom=InpWMom;
   g_cfg.wSess=InpWSess;
   g_cfg.wMtf=InpWMtf;
   g_cfg.scrNoTrade=InpScrNoTrade;
   g_cfg.scrWeak=InpScrWeak;
   g_cfg.scrSetup=InpScrSetup;
   g_cfg.scrStrong=InpScrStrong;
   g_cfg.slAtrMul=InpSlAtrMul;
   g_cfg.slSwing=InpSlSwing;
   g_cfg.slPadAtr=InpSlPadAtr;
   g_cfg.slMinAtr=InpSlMinAtr;
   g_cfg.slMaxAtr=InpSlMaxAtr;
   g_cfg.rr1=InpRr1;
   g_cfg.rr2=InpRr2;
   g_cfg.rr3=InpRr3;
   g_cfg.rrMin=InpRrMin;
   g_cfg.maxDay=InpMaxDay;
   g_cfg.coolBars=InpCoolBars;
   g_cfg.tpMode=InpTpMode;
   g_cfg.tpMmFallback=InpTpMmFallback;
   g_cfg.regOn=InpRegOn;
   g_cfg.regAdxTrend=InpRegAdxTrend;
   g_cfg.regAdxChop=InpRegAdxChop;
   g_cfg.regBbwLen=InpRegBbwLen;
   g_cfg.regBbwSqueeze=InpRegBbwSqueeze;
   g_cfg.regRangeEdge=InpRegRangeEdge;
   g_cfg.patOn=InpPatOn;
   g_cfg.patBandAtr=InpPatBandAtr;
   g_cfg.patMaxBars=InpPatMaxBars;
   g_cfg.hsRatio=InpHsRatio;
   g_cfg.cfOn=InpCfOn;
   g_cfg.cfLevelTolAtr=InpCfLevelTolAtr;
   g_cfg.cfRequire3=InpCfRequire3;
   //--- EA bridge: only override when a positive value is supplied, then re-clamp.
   if(InpRr1Ea>0.0)
      g_cfg.rr1=InpRr1Ea;
   if(InpRrMinEa>0.0)
      g_cfg.rrMin=InpRrMinEa;
   PaNormalizeConfig(g_cfg);
   if(InpRr1Ea>0.0 || InpRrMinEa>0.0)
      PrintFormat("PAMTF|INFO|bridge|rr1=%.2f|rrMin=%.2f",g_cfg.rr1,g_cfg.rrMin);

   g_ctxTfCache=g_cfg.ctxTf;
   g_setupTfCache=g_cfg.setupTf;
   g_ctxLenCache=g_cfg.ctxLen;
   g_setupLenCache=g_cfg.setupLen;
   ArrayResize(g_ctxCloseT,0);
   ArrayResize(g_ctxCloses,0);
   ArrayResize(g_ctxWinT,0);
   ArrayResize(g_ctxEma,0);
   ArrayResize(g_setupCloseT,0);
   ArrayResize(g_setupCloses,0);
   ArrayResize(g_setupWinT,0);
   ArrayResize(g_setupEma,0);
   g_replayValid=false;
   g_replayBar=-1;
   g_replayTime=0;
   g_replayClose=0.0;
   g_replayTotal=0;

   if(g_cfg.ctxTf!=PERIOD_H4 && g_cfg.ctxTf!=PERIOD_D1
      && g_cfg.ctxTf!=PERIOD_W1 && g_cfg.ctxTf!=PERIOD_MN1)
     {
      PrintFormat("PAMTF|ERROR|ctxTf must be H4/D1/W1/MN1, got %s",
                  EnumToString(g_cfg.ctxTf));
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(g_cfg.setupTf!=PERIOD_M15 && g_cfg.setupTf!=PERIOD_H1)
     {
      PrintFormat("PAMTF|ERROR|setupTf must be M15/H1, got %s",
                  EnumToString(g_cfg.setupTf));
      return(INIT_PARAMETERS_INCORRECT);
     }

   SetIndexBuffer(0,g_plot_ema_fast,INDICATOR_DATA);
   SetIndexBuffer(1,g_plot_ema_mid,INDICATOR_DATA);
   SetIndexBuffer(2,g_plot_ema_slow,INDICATOR_DATA);
   SetIndexBuffer(3,g_plot_vwap,INDICATOR_DATA);
   SetIndexBuffer(4,g_plot_volume,INDICATOR_DATA);
   SetIndexBuffer(5,g_plot_vol_ma,INDICATOR_DATA);
   SetIndexBuffer(6,g_plot_long_entry,INDICATOR_DATA);
   SetIndexBuffer(7,g_plot_short_entry,INDICATOR_DATA);
   SetIndexBuffer(8,g_plot_hit_tp,INDICATOR_DATA);
   SetIndexBuffer(9,g_plot_hit_sl,INDICATOR_DATA);
   SetIndexBuffer(10,g_plot_active_sl,INDICATOR_DATA);
   SetIndexBuffer(11,g_plot_active_tp1,INDICATOR_DATA);

   SetIndexBuffer(PA_BUF_SCORE100,g_b_score100,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_DIR,g_b_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_QUALITY,g_b_quality,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_CONFLUENCE,g_b_confluence,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_REGIME,g_b_regime,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_PLAN_VALID,g_b_plan_valid,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_ENTRY,g_b_entry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_SL,g_b_sl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_TP1,g_b_tp1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_TP2,g_b_tp2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_TP3,g_b_tp3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_RISK,g_b_risk,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_SIG_LONG,g_b_sig_long,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_SIG_SHORT,g_b_sig_short,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_BLOCK,g_b_block,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_EV_ENTRY,g_b_ev_entry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_EV_TP1,g_b_ev_tp1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_EV_TP2,g_b_ev_tp2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_EV_TP3,g_b_ev_tp3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_EV_SL,g_b_ev_sl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_EV_CLOSE,g_b_ev_close,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_CLOSE_REASON,g_b_close_reason,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_POS_DIR,g_b_pos_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_POS_ENTRY,g_b_pos_entry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_POS_SL,g_b_pos_sl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_POS_TP1,g_b_pos_tp1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_POS_TP2,g_b_pos_tp2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_POS_TP3,g_b_pos_tp3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_POS_RISK,g_b_pos_risk,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_POS_STAGE,g_b_pos_stage,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_POS_BARS,g_b_pos_bars,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_DAY_COUNT,g_b_day_count,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_BARS_SINCE,g_b_bars_since,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_TRADES,g_b_trades,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_WINS,g_b_wins,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_LOSSES,g_b_losses,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_TREND,g_b_trend,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_BOS_UP,g_b_bos_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_BOS_DOWN,g_b_bos_dn,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_CHOCH_UP,g_b_choch_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_CHOCH_DOWN,g_b_choch_dn,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_MSS_UP,g_b_mss_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_MSS_DOWN,g_b_mss_dn,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_RETEST_UP,g_b_retest_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_RETEST_DOWN,g_b_retest_dn,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_FAIL_UP,g_b_fail_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_FAIL_DOWN,g_b_fail_dn,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_SWEEP_UP,g_b_sweep_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_SWEEP_DOWN,g_b_sweep_dn,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_HH,g_b_hh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_HL,g_b_hl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_LH,g_b_lh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_LL,g_b_ll,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_CONT_UP,g_b_cont_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_CONT_DOWN,g_b_cont_dn,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_PULL_UP,g_b_pull_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_PULL_DOWN,g_b_pull_dn,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_PATTERN,g_b_pattern,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_PATTERN_DIR,g_b_pattern_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_PATTERN_HEIGHT,g_b_pattern_h,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_CANDLE_SCORE,g_b_candle_score,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_ATR,g_b_atr,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_ATR_PCT,g_b_atr_pct,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_RSI,g_b_rsi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_MACD_HIST,g_b_macd,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_ADX,g_b_adx,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_DI_PLUS,g_b_di_plus,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_DI_MINUS,g_b_di_minus,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_BB_WIDTH,g_b_bb_width,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_VOL_RATIO,g_b_vol_ratio,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_REL_VOL,g_b_rel_vol,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_OBV_SLOPE,g_b_obv_slope,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_VWAP,g_b_vwap,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_PDH,g_b_pdh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_PDL,g_b_pdl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_PWH,g_b_pwh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_PWL,g_b_pwl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_SESS_HI,g_b_sess_hi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_SESS_LO,g_b_sess_lo,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_VOL_BUCKET,g_b_vol_bucket,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_SESS_NAME,g_b_sess_name,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_MTF_CTX_DIR,g_b_ctx_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_MTF_SETUP_DIR,g_b_setup_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_HTF_VETO,g_b_htf_veto,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_CF1,g_b_cf1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_CF2,g_b_cf2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_CF3,g_b_cf3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_NEAR_SUPPORT,g_b_near_sup,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_NEAR_RESISTANCE,g_b_near_res,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_NEAR_FVG_BULL,g_b_near_fvg_bull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_NEAR_FVG_BEAR,g_b_near_fvg_bear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_SWING_LO,g_b_swing_lo,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_SWING_HI,g_b_swing_hi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_LAST_HIGH,g_b_last_high,INDICATOR_CALCULATIONS);
   SetIndexBuffer(PA_BUF_LAST_LOW,g_b_last_low,INDICATOR_CALCULATIONS);

   for(int plot=0; plot<PA_PLOT_BUFFERS; plot++)
      PlotIndexSetDouble(plot,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(4,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetInteger(6,PLOT_ARROW,233);
   PlotIndexSetInteger(7,PLOT_ARROW,234);
   PlotIndexSetInteger(8,PLOT_ARROW,159);
   PlotIndexSetInteger(9,PLOT_ARROW,251);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("Price Action MTF v%s",PA_CONTRACT_VERSION));
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);

   PrintFormat("PAMTF|INFO|init|srv=%d mkt=%d vol=%d bars=%d swing=%d sr=%d/%d/%d/%d "
               "ema=%d/%d/%d htf=%d/%d hash=%08X",
               g_cfg.srvOffsetMin,g_cfg.mktOffsetMin,g_cfg.volSessOffsetMin,
               g_cfg.maxBars,g_cfg.swingLen,g_cfg.srLeft,g_cfg.srRight,
               g_cfg.srWidthAtr,g_cfg.srMax,g_cfg.emaFast,g_cfg.emaMid,
               g_cfg.emaSlow,(int)g_cfg.ctxTf,(int)g_cfg.setupTf,
               PaConfigHash(g_cfg));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   PrintFormat("PAMTF|INFO|deinit|reason=%d",reason);
  }

//+------------------------------------------------------------------+
//| Calculate                                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total<3)
      return(0);

//--- Full replay on every new bar so Pine `var` state is rebuilt from scratch.
   if(prev_calculated==rates_total && rates_total==g_last_rates)
      return(rates_total);
   g_last_rates=rates_total;

   const int total=rates_total;
   const int lastClosed=total-2;
   const double tickSize=_Point;

   int fromBar=0;
   if(g_cfg.maxBars>0)
      fromBar=MathMax(0,lastClosed-g_cfg.maxBars+1);
   int start=fromBar;
   bool fast=false;
   if(PA_REPLAY_INCREMENTAL!=0 && g_cfg.maxBars==0 && g_replayValid
      && total>=g_replayTotal && g_replayBar>=0 && g_replayBar<total
      && lastClosed>=g_replayBar+1 && time[g_replayBar]==g_replayTime
      && close[g_replayBar]==g_replayClose)
     {
      start=g_replayBar+1;
      fast=true;
     }
   const int resetFrom=(fast ? start : 0);

   double volD[];
   ArrayResize(volD,total);
   for(int j=0; j<total; j++)
      volD[j]=(double)tick_volume[j];

//--- Pass 1: indicator series
   double atr[],volMA[],volSma[],emaF[],emaM[],emaS[];
   PaBuildAtr(high,low,close,total,g_cfg.atrLen,atr);
   PaBuildRma(volD,total,g_cfg.volMaLen,volMA);
   PaBuildSma(volD,total,g_cfg.rvLen,volSma);
   PaBuildEma(close,total,g_cfg.emaFast,emaF);
   PaBuildEma(close,total,g_cfg.emaMid,emaM);
   PaBuildEma(close,total,g_cfg.emaSlow,emaS);

   double swingLo[],swingHi[];
   ArrayResize(swingLo,total);
   ArrayResize(swingHi,total);
   for(int j=0; j<total; j++)
     {
      swingLo[j]=PaRollingMin(low,total,j,g_cfg.slSwing);
      swingHi[j]=PaRollingMax(high,total,j,g_cfg.slSwing);
     }

   double pivH[],pivL[];
   bool pivHOk[],pivLOk[];
   ArrayResize(pivH,total);
   ArrayResize(pivL,total);
   ArrayInitialize(pivH,EMPTY_VALUE);
   ArrayInitialize(pivL,EMPTY_VALUE);
   ArrayResize(pivHOk,total);
   ArrayResize(pivLOk,total);
   ArrayInitialize(pivHOk,false);
   ArrayInitialize(pivLOk,false);
   for(int j=0; j<total; j++)
     {
      double value=EMPTY_VALUE;
      pivHOk[j]=PaPivotHighAt(high,total,j,g_cfg.swingLen,g_cfg.swingLen,value);
      pivH[j]=value;
      value=EMPTY_VALUE;
      pivLOk[j]=PaPivotLowAt(low,total,j,g_cfg.swingLen,g_cfg.swingLen,value);
      pivL[j]=value;
     }

   double srPivH[],srPivL[];
   bool srPivHOk[],srPivLOk[];
   ArrayResize(srPivH,total);
   ArrayResize(srPivL,total);
   ArrayInitialize(srPivH,EMPTY_VALUE);
   ArrayInitialize(srPivL,EMPTY_VALUE);
   ArrayResize(srPivHOk,total);
   ArrayResize(srPivLOk,total);
   ArrayInitialize(srPivHOk,false);
   ArrayInitialize(srPivLOk,false);
   for(int j=0; j<total; j++)
     {
      double value=EMPTY_VALUE;
      srPivHOk[j]=PaPivotHighAt(high,total,j,g_cfg.srLeft,g_cfg.srRight,value);
      srPivH[j]=value;
      value=EMPTY_VALUE;
      srPivLOk[j]=PaPivotLowAt(low,total,j,g_cfg.srLeft,g_cfg.srRight,value);
      srPivL[j]=value;
     }

   double neckLow[],neckHigh[];
   PaBuildNecklines(high,low,total,g_cfg.swingLen,neckLow,neckHigh);

   double rsi[],macdHist[],diPlus[],diMinus[],adx[];
   PaBuildRsi(close,total,g_cfg.rsiLen,rsi);
   PaBuildMacdHist(close,total,g_cfg.macdFast,g_cfg.macdSlow,g_cfg.macdSignal,macdHist);
   PaBuildDmi(high,low,close,total,g_cfg.dmiLen,g_cfg.dmiSmooth,diPlus,diMinus,adx);

   double bbMid[],bbUp[],bbLo[],bbWidth[],bbWidthMA[],atrMA[];
   PaBuildBb(close,total,g_cfg.bbLen,g_cfg.bbMult,bbMid,bbUp,bbLo);
   ArrayResize(bbWidth,total);
   ArrayInitialize(bbWidth,EMPTY_VALUE);
   for(int j=0; j<total; j++)
     {
      if(!PaIsEmpty(bbMid[j]) && !PaIsEmpty(bbUp[j]) && !PaIsEmpty(bbLo[j])
         && bbMid[j]!=0.0)
         bbWidth[j]=(bbUp[j]-bbLo[j])/bbMid[j]*100.0;
     }
   PaBuildSma(bbWidth,total,g_cfg.bbLen,bbWidthMA);
   PaBuildSma(atr,total,20,atrMA);

   double htfCtx[],htfSetup[];
   bool htfCtxOk[],htfSetupOk[];
   PaLoadHtfEma(g_cfg.ctxTf,g_cfg.ctxLen,total,time,time[lastClosed],start,htfCtx,htfCtxOk);
   PaLoadHtfEma(g_cfg.setupTf,g_cfg.setupLen,total,time,time[lastClosed],start,htfSetup,htfSetupOk);

//--- Defaults for every bar; the live bar (rates_total-1) stays empty.
   for(int j=resetFrom; j<total; j++)
     {
      g_plot_ema_fast[j]=EMPTY_VALUE;
      g_plot_ema_mid[j]=EMPTY_VALUE;
      g_plot_ema_slow[j]=EMPTY_VALUE;
      g_plot_vwap[j]=EMPTY_VALUE;
      g_plot_volume[j]=0.0;
      g_plot_vol_ma[j]=EMPTY_VALUE;
      g_plot_long_entry[j]=EMPTY_VALUE;
      g_plot_short_entry[j]=EMPTY_VALUE;
      g_plot_hit_tp[j]=EMPTY_VALUE;
      g_plot_hit_sl[j]=EMPTY_VALUE;
      g_plot_active_sl[j]=EMPTY_VALUE;
      g_plot_active_tp1[j]=EMPTY_VALUE;

      g_b_score100[j]=0.0;
      g_b_dir[j]=0.0;
      g_b_quality[j]=0.0;
      g_b_confluence[j]=0.0;
      g_b_regime[j]=0.0;
      g_b_plan_valid[j]=0.0;
      g_b_entry[j]=EMPTY_VALUE;
      g_b_sl[j]=EMPTY_VALUE;
      g_b_tp1[j]=EMPTY_VALUE;
      g_b_tp2[j]=EMPTY_VALUE;
      g_b_tp3[j]=EMPTY_VALUE;
      g_b_risk[j]=EMPTY_VALUE;
      g_b_sig_long[j]=0.0;
      g_b_sig_short[j]=0.0;
      g_b_block[j]=0.0;
      g_b_ev_entry[j]=0.0;
      g_b_ev_tp1[j]=0.0;
      g_b_ev_tp2[j]=0.0;
      g_b_ev_tp3[j]=0.0;
      g_b_ev_sl[j]=0.0;
      g_b_ev_close[j]=0.0;
      g_b_close_reason[j]=0.0;
      g_b_pos_dir[j]=0.0;
      g_b_pos_entry[j]=EMPTY_VALUE;
      g_b_pos_sl[j]=EMPTY_VALUE;
      g_b_pos_tp1[j]=EMPTY_VALUE;
      g_b_pos_tp2[j]=EMPTY_VALUE;
      g_b_pos_tp3[j]=EMPTY_VALUE;
      g_b_pos_risk[j]=EMPTY_VALUE;
      g_b_pos_stage[j]=0.0;
      g_b_pos_bars[j]=0.0;
      g_b_day_count[j]=0.0;
      g_b_bars_since[j]=0.0;
      g_b_trades[j]=0.0;
      g_b_wins[j]=0.0;
      g_b_losses[j]=0.0;
      g_b_trend[j]=0.0;
      g_b_bos_up[j]=0.0;
      g_b_bos_dn[j]=0.0;
      g_b_choch_up[j]=0.0;
      g_b_choch_dn[j]=0.0;
      g_b_mss_up[j]=0.0;
      g_b_mss_dn[j]=0.0;
      g_b_retest_up[j]=0.0;
      g_b_retest_dn[j]=0.0;
      g_b_fail_up[j]=0.0;
      g_b_fail_dn[j]=0.0;
      g_b_sweep_up[j]=0.0;
      g_b_sweep_dn[j]=0.0;
      g_b_hh[j]=0.0;
      g_b_hl[j]=0.0;
      g_b_lh[j]=0.0;
      g_b_ll[j]=0.0;
      g_b_cont_up[j]=0.0;
      g_b_cont_dn[j]=0.0;
      g_b_pull_up[j]=0.0;
      g_b_pull_dn[j]=0.0;
      g_b_pattern[j]=0.0;
      g_b_pattern_dir[j]=0.0;
      g_b_pattern_h[j]=0.0;
      g_b_candle_score[j]=0.0;
      g_b_atr[j]=EMPTY_VALUE;
      g_b_atr_pct[j]=EMPTY_VALUE;
      g_b_rsi[j]=EMPTY_VALUE;
      g_b_macd[j]=EMPTY_VALUE;
      g_b_adx[j]=EMPTY_VALUE;
      g_b_di_plus[j]=EMPTY_VALUE;
      g_b_di_minus[j]=EMPTY_VALUE;
      g_b_bb_width[j]=EMPTY_VALUE;
      g_b_vol_ratio[j]=0.0;
      g_b_rel_vol[j]=0.0;
      g_b_obv_slope[j]=0.0;
      g_b_vwap[j]=EMPTY_VALUE;
      g_b_pdh[j]=EMPTY_VALUE;
      g_b_pdl[j]=EMPTY_VALUE;
      g_b_pwh[j]=EMPTY_VALUE;
      g_b_pwl[j]=EMPTY_VALUE;
      g_b_sess_hi[j]=EMPTY_VALUE;
      g_b_sess_lo[j]=EMPTY_VALUE;
      g_b_vol_bucket[j]=0.0;
      g_b_sess_name[j]=0.0;
      g_b_ctx_dir[j]=0.0;
      g_b_setup_dir[j]=0.0;
      g_b_htf_veto[j]=0.0;
      g_b_cf1[j]=0.0;
      g_b_cf2[j]=0.0;
      g_b_cf3[j]=0.0;
      g_b_near_sup[j]=0.0;
      g_b_near_res[j]=0.0;
      g_b_near_fvg_bull[j]=0.0;
      g_b_near_fvg_bear[j]=0.0;
      g_b_swing_lo[j]=EMPTY_VALUE;
      g_b_swing_hi[j]=EMPTY_VALUE;
      g_b_last_high[j]=EMPTY_VALUE;
      g_b_last_low[j]=EMPTY_VALUE;
     }

//--- Closed-bar series for plots (live bar intentionally left empty).
   for(int j=resetFrom; j<=lastClosed; j++)
     {
      g_plot_ema_fast[j]=emaF[j];
      g_plot_ema_mid[j]=emaM[j];
      g_plot_ema_slow[j]=emaS[j];
      g_plot_volume[j]=volD[j];
      g_plot_vol_ma[j]=volMA[j];
      g_b_atr[j]=atr[j];
      g_b_rsi[j]=rsi[j];
      g_b_macd[j]=macdHist[j];
      g_b_adx[j]=adx[j];
      g_b_di_plus[j]=diPlus[j];
      g_b_di_minus[j]=diMinus[j];
      g_b_bb_width[j]=bbWidth[j];
      g_b_swing_lo[j]=swingLo[j];
      g_b_swing_hi[j]=swingHi[j];
     }

//--- Pass 2: engine replay on closed bars only.
   PaEngineState st;
   if(fast)
      st=g_replayState;
   else
     {
      PaStateInit(st);
      g_replayValid=false;
     }
   PaBar bar;
   PaBarOut out;
   for(int j=start; j<=lastClosed; j++)
     {
      PaBarInit(bar);
      bar.time=time[j];
      bar.open=open[j];
      bar.high=high[j];
      bar.low=low[j];
      bar.close=close[j];
      bar.volume=volD[j];
      bar.tickSize=tickSize;
      bar.atr=atr[j];
      bar.volMA=volMA[j];
      bar.volSma=volSma[j];
      bar.emaF=emaF[j];
      bar.emaM=emaM[j];
      bar.emaS=emaS[j];
      bar.swingLo=swingLo[j];
      bar.swingHi=swingHi[j];
      bar.pivH=pivH[j];
      bar.pivHValid=pivHOk[j];
      bar.pivL=pivL[j];
      bar.pivLValid=pivLOk[j];
      bar.srPivH=srPivH[j];
      bar.srPivHValid=srPivHOk[j];
      bar.srPivL=srPivL[j];
      bar.srPivLValid=srPivLOk[j];
      bar.pivNeckLow=neckLow[j];
      bar.pivNeckHigh=neckHigh[j];
      bar.rsi=rsi[j];
      bar.macdHist=macdHist[j];
      bar.diPlus=diPlus[j];
      bar.diMinus=diMinus[j];
      bar.adx=adx[j];
      bar.bbMid=bbMid[j];
      bar.bbUp=bbUp[j];
      bar.bbLo=bbLo[j];
      bar.bbWidth=bbWidth[j];
      bar.bbWidthMA=bbWidthMA[j];
      bar.atrMA=atrMA[j];
      bar.htfCtxEma=htfCtx[j];
      bar.htfCtxValid=htfCtxOk[j];
      bar.htfSetupEma=htfSetup[j];
      bar.htfSetupValid=htfSetupOk[j];

      PaEngineStep(g_cfg,st,bar,j,out);

      g_plot_vwap[j]=out.vwap;
      g_plot_long_entry[j]=(out.evEntry && out.posDir==1 ? low[j] : EMPTY_VALUE);
      g_plot_short_entry[j]=(out.evEntry && out.posDir==-1 ? high[j] : EMPTY_VALUE);
      g_plot_hit_tp[j]=((out.evTp1 || out.evTp2 || out.evTp3) ? high[j] : EMPTY_VALUE);
      g_plot_hit_sl[j]=(out.evSl ? low[j] : EMPTY_VALUE);
      g_plot_active_sl[j]=(out.posDir!=0 && !PaIsEmpty(out.posSl) ? out.posSl : EMPTY_VALUE);
      g_plot_active_tp1[j]=(out.posDir!=0 && !PaIsEmpty(out.posTp1) ? out.posTp1 : EMPTY_VALUE);

      g_b_score100[j]=(double)out.score100;
      g_b_dir[j]=(double)out.dir;
      g_b_quality[j]=(double)out.quality;
      g_b_confluence[j]=(double)out.confluence;
      g_b_regime[j]=(double)out.regime;
      g_b_plan_valid[j]=(out.planValid ? 1.0 : 0.0);
      g_b_entry[j]=out.entry;
      g_b_sl[j]=out.sl;
      g_b_tp1[j]=out.tp1;
      g_b_tp2[j]=out.tp2;
      g_b_tp3[j]=out.tp3;
      g_b_risk[j]=out.risk;
      g_b_sig_long[j]=(out.sigLong ? 1.0 : 0.0);
      g_b_sig_short[j]=(out.sigShort ? 1.0 : 0.0);
      g_b_block[j]=(double)out.block;
      g_b_ev_entry[j]=(out.evEntry ? 1.0 : 0.0);
      g_b_ev_tp1[j]=(out.evTp1 ? 1.0 : 0.0);
      g_b_ev_tp2[j]=(out.evTp2 ? 1.0 : 0.0);
      g_b_ev_tp3[j]=(out.evTp3 ? 1.0 : 0.0);
      g_b_ev_sl[j]=(out.evSl ? 1.0 : 0.0);
      g_b_ev_close[j]=(out.evClose ? 1.0 : 0.0);
      g_b_close_reason[j]=(double)out.closeReason;
      g_b_pos_dir[j]=(double)out.posDir;
      g_b_pos_entry[j]=out.posEntry;
      g_b_pos_sl[j]=out.posSl;
      g_b_pos_tp1[j]=out.posTp1;
      g_b_pos_tp2[j]=out.posTp2;
      g_b_pos_tp3[j]=out.posTp3;
      g_b_pos_risk[j]=out.posRisk;
      g_b_pos_stage[j]=(double)out.posStage;
      g_b_pos_bars[j]=(double)out.posBars;
      g_b_day_count[j]=(double)out.dayCount;
      g_b_bars_since[j]=(double)out.barsSince;
      g_b_trades[j]=(double)out.trades;
      g_b_wins[j]=(double)out.wins;
      g_b_losses[j]=(double)out.losses;
      g_b_trend[j]=(double)out.trend;
      g_b_bos_up[j]=(out.bosUp ? 1.0 : 0.0);
      g_b_bos_dn[j]=(out.bosDown ? 1.0 : 0.0);
      g_b_choch_up[j]=(out.chochUp ? 1.0 : 0.0);
      g_b_choch_dn[j]=(out.chochDown ? 1.0 : 0.0);
      g_b_mss_up[j]=(out.mssUp ? 1.0 : 0.0);
      g_b_mss_dn[j]=(out.mssDown ? 1.0 : 0.0);
      g_b_retest_up[j]=(out.retestUp ? 1.0 : 0.0);
      g_b_retest_dn[j]=(out.retestDown ? 1.0 : 0.0);
      g_b_fail_up[j]=(out.failUp ? 1.0 : 0.0);
      g_b_fail_dn[j]=(out.failDown ? 1.0 : 0.0);
      g_b_sweep_up[j]=(out.sweepUp ? 1.0 : 0.0);
      g_b_sweep_dn[j]=(out.sweepDown ? 1.0 : 0.0);
      g_b_hh[j]=(out.hh ? 1.0 : 0.0);
      g_b_hl[j]=(out.hl ? 1.0 : 0.0);
      g_b_lh[j]=(out.lh ? 1.0 : 0.0);
      g_b_ll[j]=(out.ll ? 1.0 : 0.0);
      g_b_cont_up[j]=(out.contUp ? 1.0 : 0.0);
      g_b_cont_dn[j]=(out.contDown ? 1.0 : 0.0);
      g_b_pull_up[j]=(out.pullUp ? 1.0 : 0.0);
      g_b_pull_dn[j]=(out.pullDown ? 1.0 : 0.0);
      g_b_pattern[j]=(double)out.pattern;
      g_b_pattern_dir[j]=(double)out.patternDir;
      g_b_pattern_h[j]=out.patternHeight;
      g_b_candle_score[j]=out.candleScore;
      g_b_atr_pct[j]=out.atrPct;
      g_b_vol_ratio[j]=out.volRatio;
      g_b_rel_vol[j]=out.relVol;
      g_b_obv_slope[j]=out.obvSlope;
      g_b_vwap[j]=out.vwap;
      g_b_pdh[j]=out.pdh;
      g_b_pdl[j]=out.pdl;
      g_b_pwh[j]=out.pwh;
      g_b_pwl[j]=out.pwl;
      g_b_sess_hi[j]=out.sessHi;
      g_b_sess_lo[j]=out.sessLo;
      g_b_vol_bucket[j]=(double)out.volBucket;
      g_b_sess_name[j]=(double)out.sessName;
      g_b_ctx_dir[j]=(double)out.mtfCtxDir;
      g_b_setup_dir[j]=(double)out.mtfSetupDir;
      g_b_htf_veto[j]=(out.htfVeto ? 1.0 : 0.0);
      g_b_cf1[j]=(out.cf1 ? 1.0 : 0.0);
      g_b_cf2[j]=(out.cf2 ? 1.0 : 0.0);
      g_b_cf3[j]=(out.cf3 ? 1.0 : 0.0);
      g_b_near_sup[j]=(out.nearSupport ? 1.0 : 0.0);
      g_b_near_res[j]=(out.nearResistance ? 1.0 : 0.0);
      g_b_near_fvg_bull[j]=(out.nearFvgBull ? 1.0 : 0.0);
      g_b_near_fvg_bear[j]=(out.nearFvgBear ? 1.0 : 0.0);
      g_b_last_high[j]=out.lastHigh;
      g_b_last_low[j]=out.lastLow;
     }

   if(g_cfg.maxBars==0 && lastClosed>=start)
     {
      g_replayState=st;
      g_replayBar=lastClosed;
      g_replayTime=time[lastClosed];
      g_replayClose=close[lastClosed];
      g_replayTotal=total;
      g_replayValid=true;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
