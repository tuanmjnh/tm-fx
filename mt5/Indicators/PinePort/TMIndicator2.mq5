//+------------------------------------------------------------------+
//|                                                TMIndicator2.mq5 |
//|  MT5 EA & AI Lab - PinePort of TM Indicator 2 (display + audit)  |
//|                                                                  |
//| Custom indicator only. No file I/O, no account access, no order  |
//| functions. Contract: docs/indicators/tm-indicator-2.md.       |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "TM Indicator 2 signal/audit indicator. Closed bars only; no trading."
#property indicator_chart_window
#property indicator_buffers 242
#property indicator_plots   16

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
// MT5 has one window per indicator: ATR is kept off-scale with DRAW_NONE.
#property indicator_type4   DRAW_NONE
#property indicator_label4  "ATR"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGold
#property indicator_width5  1
#property indicator_label5  "VWAP"
#property indicator_type6   DRAW_HISTOGRAM
#property indicator_color6  clrGray
#property indicator_width6  1
#property indicator_label6  "Volume"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrLime
#property indicator_width7  2
#property indicator_label7  "LONG Entry"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrRed
#property indicator_width8  2
#property indicator_label8  "SHORT Entry"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  clrGold
#property indicator_width9  2
#property indicator_label9  "TP Hit"
#property indicator_type10  DRAW_ARROW
#property indicator_color10 clrMagenta
#property indicator_width10 2
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
#property indicator_type13  DRAW_LINE
#property indicator_color13 clrTeal
#property indicator_style13 STYLE_DOT
#property indicator_width13 1
#property indicator_label13 "Active TP2"
#property indicator_type14  DRAW_LINE
#property indicator_color14 clrSteelBlue
#property indicator_style14 STYLE_DOT
#property indicator_width14 1
#property indicator_label14 "Active TP3"
#property indicator_type15  DRAW_LINE
#property indicator_color15 clrAqua
#property indicator_style15 STYLE_DOT
#property indicator_width15 1
#property indicator_label15 "Active Limit"
// SCORE100 is 0..100; a second window is impossible inside one indicator.
#property indicator_type16  DRAW_NONE
#property indicator_label16 "SCORE100"

#include "../../Include/PinePort/TMIndicator2Contract.mqh"

//--- MQL5-only inputs (contract 3.1)
input int               InpSrvOffsetMin      = 180;              // Server -> UTC offset (minutes)
input int               InpMktOffsetMin      = -300;             // UTC -> market session offset (minutes)
input int               InpMaxBars           = 0;                // Debug: replay last N bars (0 = all)
input string            InpBtcSymbol         = "";               // BTC leader symbol ("" = neutral)
input bool              InpAssetIsCrypto     = false;            // Treat chart symbol as crypto

//--- Asset profile (contract 3.2)
input ENUM_TM2_ASSET    InpAssetMode         = TM2_ASSET_AUTO;   // Asset profile
input bool              InpCryptoSessNeutral = true;             // Crypto session neutrality
input bool              InpWeekendFilter     = true;             // Weekend low-liquidity filter
input bool              InpBtcLeaderOn       = true;             // BTC leader veto (alts)
input double            InpBtcImpulseAtr     = 1.5;              // BTC impulse (x ATR)
input ENUM_TM2_ENTRY_MODE InpEntryMode       = TM2_ENTRY_AUTO;   // Entry mode
input ENUM_TM2_LIMIT_SOURCE InpLimitSource   = TM2_LIMIT_FVG50;  // Limit price source
input int               InpLimitCancelBars   = 5;                // Limit cancel window (bars)
input bool              InpLimitCancelOnTp1  = true;             // Cancel limit if TP1 hit first
input bool              InpModeFilterOn      = true;             // Enable entry-mode filter
input bool              InpModeAOn           = true;             // Enable mode A (trend pullback)
input bool              InpModeBOn           = true;             // Enable mode B (sweep reversal)
input bool              InpModeCOn           = false;            // Enable mode C (range fade)
input int               InpModeSweepBars     = 3;                // Mode B sweep freshness (bars)
input double            InpModePullTol       = 0.35;             // Mode A pullback tolerance (x ATR)
input double            InpModeRangeTol      = 0.35;             // Mode C range tolerance (x ATR)
input bool              InpAutoBeOn          = true;             // Auto break-even after TP1
input double            InpBeOffsetAtr       = 0.05;             // Break-even offset (x ATR)
input bool              InpTrailOn           = true;             // Trailing after TP2
input double            InpTrailDistAtr      = 1.5;              // Trail distance (x ATR)
input bool              InpTimeDecayOn       = true;             // Time-decay exit
input int               InpStagnantBars      = 15;               // Stagnation window (bars)
input int               InpMaxHoldBars       = 300;              // Max hold (bars)
input bool              InpGateRegime        = true;             // Gate: regime
input bool              InpGateObstacle      = true;             // Gate: obstacle / room
input bool              InpGateOverext       = true;             // Gate: overextension
input bool              InpGateCircuit       = true;             // Gate: circuit breaker
input bool              InpGateRisk          = true;             // Gate: risk/plan validity
input double            InpRegimeAdxTrending = 22;               // ADX trending threshold
input double            InpRegimeAdxChop     = 18;               // ADX chop threshold
input int               InpRegimeBbwLen      = 100;              // BBW percentile lookback
input double            InpRegimeBbwSqueezePct = 20;             // Squeeze percentile
input double            InpObstacleBuffer    = 0.7;              // Obstacle room (x est. TP1)
input double            InpMaxExtAtr         = 2.2;              // Max EMA extension (x ATR)
input double            InpMaxCandleAtr      = 2.5;              // Max candle range (x ATR)
input int               InpMsSwingLen        = 5;                // Structure pivot length
input bool              InpMsBosOn           = true;             // Enable BOS
input bool              InpMsChochOn         = true;             // Enable CHoCH
input bool              InpMsMssOn           = true;             // Enable MSS
input bool              InpMsRetestOn        = true;             // Enable retest
input int               InpMsRetestBars      = 10;               // Retest window (bars)
input double            InpMsRetestTolAtr    = 0.5;              // Retest tolerance (x ATR)
input bool              InpMsFailOn          = true;             // Enable failed breakout
input int               InpMsFailBars        = 5;                // Failed breakout window
input bool              InpMsContOn          = true;             // Enable continuation
input bool              InpMsPullOn          = true;             // Enable pullback
input bool              InpLiqPdOn           = true;             // PDH/PDL liquidity
input bool              InpLiqPwOn           = false;            // PWH/PWL liquidity
input bool              InpLiqSessOn         = true;             // Session-high/low liquidity
input double            InpSrWidthAtr        = 0.5;              // S/R zone width (x ATR)
input int               InpSrMax             = 8;                // Max S/R zones
input double            InpFvgMinAtr         = 0.3;              // FVG minimum (x ATR)
input int               InpFvgMax            = 20;               // Max live FVGs
input int               InpFvgLife           = 100;              // FVG lifetime (bars)
input int               InpObMax             = 15;               // Max live order blocks
input int               InpObLife            = 150;              // Order block lifetime (bars)
input int               InpEmaFast           = 20;               // EMA fast
input int               InpEmaMid            = 50;               // EMA mid
input int               InpEmaSlow           = 200;              // EMA slow
input int               InpAtrLen            = 14;               // ATR length
input int               InpRsiLen            = 14;               // RSI length
input double            InpRsiOb             = 70;               // RSI overbought
input double            InpRsiOs             = 30;               // RSI oversold
input int               InpMacdFast          = 12;               // MACD fast
input int               InpMacdSlow          = 26;               // MACD slow
input int               InpMacdSignal        = 9;                // MACD signal
input int               InpDmiLen            = 14;               // DMI length
input ENUM_TIMEFRAMES   InpCtxTf             = PERIOD_D1;        // Context timeframe
input int               InpCtxLen            = 200;              // Context EMA length
input ENUM_TIMEFRAMES   InpSetupTf           = PERIOD_H1;        // Setup timeframe
input int               InpSetupLen          = 50;               // Setup EMA length
input bool              InpHtfFilter         = true;             // Setup-TF filter
input bool              InpHtfVetoOn         = true;             // Context-TF veto
input int               InpVolMaLen          = 20;               // Volume MA (RMA) length
input double            InpVolSpikeR         = 2.2;              // Volume spike ratio
input double            InpVolRVH            = 1.8;              // VSA very-high ratio
input double            InpVolRH             = 1.2;              // VSA high ratio
input double            InpVolRN             = 0.8;              // VSA normal ratio
input double            InpVolRL             = 0.4;              // VSA low ratio
input double            InpRvMin             = 1.2;              // Relative volume minimum
input double            InpWTrend            = 15;               // Weight: trend
input double            InpWStruct           = 15;               // Weight: structure
input double            InpWLiq              = 12;               // Weight: liquidity
input double            InpWLoc              = 8;                // Weight: location
input double            InpWSr               = 10;               // Weight: support/resistance
input double            InpWCandle           = 10;               // Weight: candle
input double            InpWVol              = 8;                // Weight: volume
input double            InpWMom              = 7;                // Weight: momentum
input double            InpWSess             = 4;                // Weight: session
input double            InpWMtf              = 4;                // Weight: MTF
input int               InpScrNoTrade        = 49;               // No-trade threshold
input int               InpScrWeak           = 64;               // Weak threshold
input int               InpScrSetup          = 74;               // Setup threshold
input int               InpScrStrong         = 84;               // Strong threshold
input ENUM_TM2_MINQ     InpMinQuality        = TM2_MINQ_SETUP;   // Minimum acceptable quality
input int               InpScoreMargin       = 8;                // LONG/SHORT ambiguity margin
input ENUM_TM2_ABLATION InpAblation          = TM2_ABL_E;        // Ablation profile
input double            InpSlAtrMul          = 1.5;              // SL distance (x ATR)
input double            InpSlPadAtr          = 0.2;              // SL pad (x ATR)
input double            InpSlMinAtr          = 0.5;              // Minimum risk (x ATR)
input double            InpSlMaxAtr          = 3.0;              // Maximum risk (x ATR)
input double            InpRr1               = 1.0;              // TP1 R multiple
input double            InpRr2               = 2.0;              // TP2 R multiple
input double            InpRr3               = 3.0;              // TP3 R multiple
input double            InpRrMin             = 1.5;              // Minimum TP1 R multiple
input int               InpMaxDay            = 4;                // Max entries per server day
input int               InpCoolBars          = 8;                // Cooldown bars between entries
input double            InpRiskEquity        = 10000;            // Simulation equity
input double            InpRiskPct           = 1.0;              // Risk per trade (% equity)
input double            InpRiskMaxLev        = 20;               // Max effective leverage
input double            InpRiskMmr           = 0.005;            // Maintenance margin rate
input double            InpRiskFeeSlipPct    = 0.08;             // Fees + slippage (% of notional)
input int               InpRiskMaxLosses     = 3;                // Circuit breaker losses

//--- Render buffers 0..15 (plots 0..15)
double g_plot_ema_fast[];
double g_plot_ema_mid[];
double g_plot_ema_slow[];
double g_plot_atr[];
double g_plot_vwap[];
double g_plot_volume[];
double g_plot_long_entry[];
double g_plot_short_entry[];
double g_plot_hit_tp[];
double g_plot_hit_sl[];
double g_plot_active_sl[];
double g_plot_active_tp1[];
double g_plot_active_tp2[];
double g_plot_active_tp3[];
double g_plot_active_limit[];
double g_plot_score100[];

//--- Contract buffers 16..241
double g_b_longScore[];
double g_b_shortScore[];
double g_b_score100[];
double g_b_scoreGap[];
double g_b_dir[];
double g_b_directionCode[];
double g_b_quality[];
double g_b_qualityLevel[];
double g_b_minReqLevel[];
double g_b_okQuality[];
double g_b_scoreBlock[];
double g_b_ablationCode[];
double g_b_wDirTotal[];
double g_b_longWeighted[];
double g_b_gateRegime[];
double g_b_gateMtf[];
double g_b_gateBtc[];
double g_b_gateObstacle[];
double g_b_gateOverext[];
double g_b_gateCircuit[];
double g_b_gateAll[];
double g_b_gateTopReason[];
double g_b_noTradeReason[];
double g_b_okCool[];
double g_b_okDay[];
double g_b_okCircuit[];
double g_b_planValid[];
double g_b_planReason[];
double g_b_orderType[];
double g_b_entry[];
double g_b_limit[];
double g_b_sl[];
double g_b_tp1[];
double g_b_tp2[];
double g_b_tp3[];
double g_b_risk[];
double g_b_evalRR[];
double g_b_posSize[];
double g_b_notional[];
double g_b_effLev[];
double g_b_marginReq[];
double g_b_liqPrice[];
double g_b_netRR[];
double g_b_signal[];
double g_b_candidate[];
double g_b_eligible[];
double g_b_evEntry[];
double g_b_evPending[];
double g_b_evFilled[];
double g_b_evCancel[];
double g_b_evTp[];
double g_b_evSl[];
double g_b_evBe[];
double g_b_evTrail[];
double g_b_evTimeout[];
double g_b_evDecay[];
double g_b_evClose[];
double g_b_cancelReason[];
double g_b_closeReason[];
double g_b_posDir[];
double g_b_posStage[];
double g_b_posOrderType[];
double g_b_posMode[];
double g_b_posEntry[];
double g_b_posLimit[];
double g_b_posSl[];
double g_b_posTp1[];
double g_b_posTp2[];
double g_b_posTp3[];
double g_b_posRisk[];
double g_b_posBars[];
double g_b_posBar[];
double g_b_posMaxFavR[];
double g_b_dayCount[];
double g_b_barsSince[];
double g_b_consecLosses[];
double g_b_trades[];
double g_b_tp1Hits[];
double g_b_netWins[];
double g_b_beSaves[];
double g_b_fullLosses[];
double g_b_timeouts[];
double g_b_decays[];
double g_b_realizedRSum[];
double g_b_candidates[];
double g_b_eligibleN[];
double g_b_pendingN[];
double g_b_filledN[];
double g_b_closedN[];
double g_b_xDir[];
double g_b_xEntry[];
double g_b_xSl[];
double g_b_xExit[];
double g_b_xR[];
double g_b_xReason[];
double g_b_xBar[];
double g_b_xStage[];
double g_b_regimeCode[];
double g_b_regimeDir[];
double g_b_regimeAdx[];
double g_b_regimeBbwPct[];
double g_b_isSqueeze[];
double g_b_bbWidth[];
double g_b_bbWidthMA[];
double g_b_bbExpand[];
double g_b_trend[];
double g_b_bosUp[];
double g_b_bosDown[];
double g_b_chochUp[];
double g_b_chochDown[];
double g_b_mssUp[];
double g_b_mssDown[];
double g_b_retestUp[];
double g_b_retestDown[];
double g_b_failUp[];
double g_b_failDown[];
double g_b_contUp[];
double g_b_contDown[];
double g_b_pullUp[];
double g_b_pullDown[];
double g_b_hh[];
double g_b_ll[];
double g_b_eqHi[];
double g_b_eqLo[];
double g_b_swingHi[];
double g_b_swingLo[];
double g_b_prevHigh[];
double g_b_prevLow[];
double g_b_brkLevel[];
double g_b_brkDir[];
double g_b_brkBar[];
double g_b_evtKind[];
double g_b_evtDir[];
double g_b_evtSrcBar[];
double g_b_evtSrcTime[];
double g_b_evtLevel[];
double g_b_evtCount[];
double g_b_lastSweepBullBar[];
double g_b_lastSweepBullPx[];
double g_b_lastSweepBearBar[];
double g_b_lastSweepBearPx[];
double g_b_cpBull[];
double g_b_cpBear[];
double g_b_candleScore[];
double g_b_pinBull[];
double g_b_pinBear[];
double g_b_engBull[];
double g_b_engBear[];
double g_b_dispBull[];
double g_b_dispBear[];
double g_b_rejBull[];
double g_b_rejBear[];
double g_b_isOverext[];
double g_b_extEma[];
double g_b_extCandle[];
double g_b_atr[];
double g_b_atrPct[];
double g_b_rsi[];
double g_b_macdHist[];
double g_b_adx[];
double g_b_diPlus[];
double g_b_diMinus[];
double g_b_emaSlope20[];
double g_b_emaBull[];
double g_b_emaBear[];
double g_b_atrSafe[];
double g_b_vol[];
double g_b_volMA[];
double g_b_volRatio[];
double g_b_volBucket[];
double g_b_isTim[];
double g_b_relVol[];
double g_b_obv[];
double g_b_obvSlope[];
double g_b_vwap[];
double g_b_vwapScore[];
double g_b_pdh[];
double g_b_pdl[];
double g_b_pwh[];
double g_b_pwl[];
double g_b_dayRange[];
double g_b_sessName[];
double g_b_sessHi[];
double g_b_sessLo[];
double g_b_nearSup[];
double g_b_nearRes[];
double g_b_nearFvgBull[];
double g_b_nearFvgBear[];
double g_b_nearObBull[];
double g_b_nearObBear[];
double g_b_srCount[];
double g_b_fvgCount[];
double g_b_obCount[];
double g_b_nearestRes[];
double g_b_nearestSup[];
double g_b_fvgBullPx[];
double g_b_fvgBearPx[];
double g_b_obBullPx[];
double g_b_obBearPx[];
double g_b_mtfCtxDir[];
double g_b_mtfSetupDir[];
double g_b_mtfCtxEma[];
double g_b_mtfSetupEma[];
double g_b_mtfBias[];
double g_b_mtfHierOk[];
double g_b_btcDump[];
double g_b_btcPump[];
double g_b_weekendBlock[];
double g_b_modeDir[];
double g_b_activeMode[];
double g_b_modeReady[];
double g_b_modeGateOk[];
double g_b_modeReason[];
double g_b_modeBInvalidLong[];
double g_b_modeBInvalidShort[];
double g_b_modeCBoxOk[];
double g_b_gTrend[];
double g_b_gStruct[];
double g_b_gLiq[];
double g_b_gLoc[];
double g_b_gSr[];
double g_b_gCandle[];
double g_b_gVolume[];
double g_b_gMom[];
double g_b_gSess[];
double g_b_gMtf[];

TM2Config g_cfg;
int       g_last_rates=-1;
bool      g_first=true;

//+------------------------------------------------------------------+
//| Higher-timeframe close/EMA mapped onto closed HTF bars (Pine [1])|
//+------------------------------------------------------------------+
void TMInd2LoadHtf(const ENUM_TIMEFRAMES tf,const int len,const int total,
                   const datetime &time[],double &closeOut[],double &emaOut[],
                   bool &validOut[])
  {
   ArrayResize(closeOut,total);
   ArrayInitialize(closeOut,EMPTY_VALUE);
   ArrayResize(emaOut,total);
   ArrayInitialize(emaOut,EMPTY_VALUE);
   ArrayResize(validOut,total);
   ArrayInitialize(validOut,false);
   if(len<=0)
      return;

   const int htfSeconds=(int)PeriodSeconds(tf);
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   const int got=CopyRates(_Symbol,tf,0,3000,rates);
   if(got<=0)
      return;

//--- Normalise to chronological order regardless of the terminal ordering.
   const bool descending=(got>1 && rates[0].time>rates[got-1].time);
   datetime htfClose[];
   double   htfCloses[];
   ArrayResize(htfClose,got);
   ArrayResize(htfCloses,got);
   for(int k=0; k<got; k++)
     {
      const int src=(descending ? got-1-k : k);
      htfClose[k]=rates[src].time+htfSeconds;
      htfCloses[k]=rates[src].close;
     }

   double htfEma[];
   TM2BuildEma(htfCloses,got,len,htfEma);

   for(int j=0; j<total; j++)
     {
      const int k=TM2MapHtfIndex(htfClose,got,time[j]);
      if(k<0 || TM2IsEmpty(htfEma[k]))
         continue;
      closeOut[j]=htfCloses[k];
      emaOut[j]=htfEma[k];
      validOut[j]=true;
     }
  }

//+------------------------------------------------------------------+
//| Previous completed server day/week highs and lows (Pine [1])     |
//+------------------------------------------------------------------+
void TMInd2BuildPrevPeriod(const double &high[],const double &low[],
                           const datetime &time[],const int total,
                           double &pdh[],double &pdl[],bool &hasPd[],
                           double &pwh[],double &pwl[],bool &hasPw[])
  {
   ArrayResize(pdh,total);
   ArrayResize(pdl,total);
   ArrayResize(hasPd,total);
   ArrayResize(pwh,total);
   ArrayResize(pwl,total);
   ArrayResize(hasPw,total);
   ArrayInitialize(pdh,EMPTY_VALUE);
   ArrayInitialize(pdl,EMPTY_VALUE);
   ArrayInitialize(hasPd,false);
   ArrayInitialize(pwh,EMPTY_VALUE);
   ArrayInitialize(pwl,EMPTY_VALUE);
   ArrayInitialize(hasPw,false);
   if(total<=0)
      return;

   long curDay=-1;
   long curWeek=-1;
   double dayHi=0.0;
   double dayLo=0.0;
   double weekHi=0.0;
   double weekLo=0.0;
   double prevDayHi=EMPTY_VALUE;
   double prevDayLo=EMPTY_VALUE;
   double prevWeekHi=EMPTY_VALUE;
   double prevWeekLo=EMPTY_VALUE;

   for(int j=0; j<total; j++)
     {
      const long day=TM2ServerDayStamp(time[j]);
      if(day!=curDay)
        {
         if(curDay>=0)
           {
            prevDayHi=dayHi;
            prevDayLo=dayLo;
           }
         curDay=day;
         dayHi=high[j];
         dayLo=low[j];
        }
      else
        {
         if(high[j]>dayHi)
            dayHi=high[j];
         if(low[j]<dayLo)
            dayLo=low[j];
        }

      const long week=TM2ServerWeekKey(time[j]);
      if(week!=curWeek)
        {
         if(curWeek>=0)
           {
            prevWeekHi=weekHi;
            prevWeekLo=weekLo;
           }
         curWeek=week;
         weekHi=high[j];
         weekLo=low[j];
        }
      else
        {
         if(high[j]>weekHi)
            weekHi=high[j];
         if(low[j]<weekLo)
            weekLo=low[j];
        }

      if(!TM2IsEmpty(prevDayHi))
        {
         pdh[j]=prevDayHi;
         pdl[j]=prevDayLo;
         hasPd[j]=true;
        }
      if(!TM2IsEmpty(prevWeekHi))
        {
         pwh[j]=prevWeekHi;
         pwl[j]=prevWeekLo;
         hasPw[j]=true;
        }
     }
  }

//+------------------------------------------------------------------+
//| BTC leader series mapped onto chart bars (Pine BTC requests)     |
//+------------------------------------------------------------------+
void TMInd2LoadBtc(const string symbol,const int total,const datetime &time[],
                   double &btcClose[],double &btcEma[],double &btcRsi[],
                   double &btcAtr[],bool &btcOk[])
  {
   ArrayResize(btcClose,total);
   ArrayInitialize(btcClose,EMPTY_VALUE);
   ArrayResize(btcEma,total);
   ArrayInitialize(btcEma,EMPTY_VALUE);
   ArrayResize(btcRsi,total);
   ArrayInitialize(btcRsi,EMPTY_VALUE);
   ArrayResize(btcAtr,total);
   ArrayInitialize(btcAtr,EMPTY_VALUE);
   ArrayResize(btcOk,total);
   ArrayInitialize(btcOk,false);
   if(symbol=="" || total<=0)
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   const int got=CopyRates(symbol,PERIOD_CURRENT,0,3000,rates);
   if(got<=0)
      return;

   const bool descending=(got>1 && rates[0].time>rates[got-1].time);
   const int barSeconds=(int)PeriodSeconds(PERIOD_CURRENT);
   datetime btcCloseTime[];
   double btcHighs[];
   double btcLows[];
   double btcCloses[];
   ArrayResize(btcCloseTime,got);
   ArrayResize(btcHighs,got);
   ArrayResize(btcLows,got);
   ArrayResize(btcCloses,got);
   for(int k=0; k<got; k++)
     {
      const int src=(descending ? got-1-k : k);
      btcCloseTime[k]=rates[src].time+barSeconds;
      btcHighs[k]=rates[src].high;
      btcLows[k]=rates[src].low;
      btcCloses[k]=rates[src].close;
     }

   double ema[];
   double rsi[];
   double atr[];
   TM2BuildEma(btcCloses,got,20,ema);
   TM2BuildRsi(btcCloses,got,14,rsi);
   TM2BuildAtr(btcHighs,btcLows,btcCloses,got,14,atr);

   for(int j=0; j<total; j++)
     {
      const int k=TM2MapHtfIndex(btcCloseTime,got,time[j]);
      if(k<0)
         continue;
      if(TM2IsEmpty(btcCloses[k]) || TM2IsEmpty(ema[k]) ||
         TM2IsEmpty(rsi[k]) || TM2IsEmpty(atr[k]))
         continue;
      btcClose[j]=btcCloses[k];
      btcEma[j]=ema[k];
      btcRsi[j]=rsi[k];
      btcAtr[j]=atr[k];
      btcOk[j]=true;
     }
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_cfg.srvOffsetMin=InpSrvOffsetMin;
   g_cfg.mktOffsetMin=InpMktOffsetMin;
   g_cfg.maxBars=InpMaxBars;
   g_cfg.btcSymbol=InpBtcSymbol;
   g_cfg.assetIsCrypto=InpAssetIsCrypto;
   g_cfg.assetMode=(int)InpAssetMode;
   g_cfg.cryptoSessNeutral=InpCryptoSessNeutral;
   g_cfg.weekendFilter=InpWeekendFilter;
   g_cfg.btcLeaderOn=InpBtcLeaderOn;
   g_cfg.btcImpulseAtr=InpBtcImpulseAtr;
   g_cfg.entryMode=(int)InpEntryMode;
   g_cfg.limitSource=(int)InpLimitSource;
   g_cfg.limitCancelBars=InpLimitCancelBars;
   g_cfg.limitCancelOnTp1=InpLimitCancelOnTp1;
   g_cfg.modeFilterOn=InpModeFilterOn;
   g_cfg.modeAOn=InpModeAOn;
   g_cfg.modeBOn=InpModeBOn;
   g_cfg.modeCOn=InpModeCOn;
   g_cfg.modeSweepBars=InpModeSweepBars;
   g_cfg.modePullTol=InpModePullTol;
   g_cfg.modeRangeTol=InpModeRangeTol;
   g_cfg.autoBeOn=InpAutoBeOn;
   g_cfg.beOffsetAtr=InpBeOffsetAtr;
   g_cfg.trailOn=InpTrailOn;
   g_cfg.trailDistAtr=InpTrailDistAtr;
   g_cfg.timeDecayOn=InpTimeDecayOn;
   g_cfg.stagnantBars=InpStagnantBars;
   g_cfg.maxHoldBars=InpMaxHoldBars;
   g_cfg.gateRegime=InpGateRegime;
   g_cfg.gateObstacle=InpGateObstacle;
   g_cfg.gateOverext=InpGateOverext;
   g_cfg.gateCircuit=InpGateCircuit;
   g_cfg.gateRisk=InpGateRisk;
   g_cfg.adxTrending=InpRegimeAdxTrending;
   g_cfg.adxChop=InpRegimeAdxChop;
   g_cfg.bbwLen=InpRegimeBbwLen;
   g_cfg.bbwSqueezePct=InpRegimeBbwSqueezePct;
   g_cfg.obstacleBuffer=InpObstacleBuffer;
   g_cfg.maxExtAtr=InpMaxExtAtr;
   g_cfg.maxCandleAtr=InpMaxCandleAtr;
   g_cfg.msSwingLen=InpMsSwingLen;
   g_cfg.msBosOn=InpMsBosOn;
   g_cfg.msChochOn=InpMsChochOn;
   g_cfg.msMssOn=InpMsMssOn;
   g_cfg.msRetestOn=InpMsRetestOn;
   g_cfg.msRetestBars=InpMsRetestBars;
   g_cfg.msRetestTolAtr=InpMsRetestTolAtr;
   g_cfg.msFailOn=InpMsFailOn;
   g_cfg.msFailBars=InpMsFailBars;
   g_cfg.msContOn=InpMsContOn;
   g_cfg.msPullOn=InpMsPullOn;
   g_cfg.liqPdOn=InpLiqPdOn;
   g_cfg.liqPwOn=InpLiqPwOn;
   g_cfg.liqSessOn=InpLiqSessOn;
   g_cfg.srWidthAtr=InpSrWidthAtr;
   g_cfg.srMax=InpSrMax;
   g_cfg.fvgMinAtr=InpFvgMinAtr;
   g_cfg.fvgMax=InpFvgMax;
   g_cfg.fvgLife=InpFvgLife;
   g_cfg.obMax=InpObMax;
   g_cfg.obLife=InpObLife;
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
   g_cfg.ctxTf=InpCtxTf;
   g_cfg.ctxLen=InpCtxLen;
   g_cfg.setupTf=InpSetupTf;
   g_cfg.setupLen=InpSetupLen;
   g_cfg.htfFilter=InpHtfFilter;
   g_cfg.htfVetoOn=InpHtfVetoOn;
   g_cfg.volMaLen=InpVolMaLen;
   g_cfg.volSpikeR=InpVolSpikeR;
   g_cfg.volRVH=InpVolRVH;
   g_cfg.volRH=InpVolRH;
   g_cfg.volRN=InpVolRN;
   g_cfg.volRL=InpVolRL;
   g_cfg.rvMin=InpRvMin;
   g_cfg.wTrend=InpWTrend;
   g_cfg.wStruct=InpWStruct;
   g_cfg.wLiq=InpWLiq;
   g_cfg.wLoc=InpWLoc;
   g_cfg.wSr=InpWSr;
   g_cfg.wCandle=InpWCandle;
   g_cfg.wVol=InpWVol;
   g_cfg.wMom=InpWMom;
   g_cfg.wSess=InpWSess;
   g_cfg.wMtf=InpWMtf;
   g_cfg.scrNoTrade=InpScrNoTrade;
   g_cfg.scrWeak=InpScrWeak;
   g_cfg.scrSetup=InpScrSetup;
   g_cfg.scrStrong=InpScrStrong;
   g_cfg.minQuality=(int)InpMinQuality;
   g_cfg.scoreMargin=InpScoreMargin;
   g_cfg.ablation=(int)InpAblation;
   g_cfg.slAtrMul=InpSlAtrMul;
   g_cfg.slPadAtr=InpSlPadAtr;
   g_cfg.slMinAtr=InpSlMinAtr;
   g_cfg.slMaxAtr=InpSlMaxAtr;
   g_cfg.rr1=InpRr1;
   g_cfg.rr2=InpRr2;
   g_cfg.rr3=InpRr3;
   g_cfg.rrMin=InpRrMin;
   g_cfg.maxDay=InpMaxDay;
   g_cfg.coolBars=InpCoolBars;
   g_cfg.riskEquity=InpRiskEquity;
   g_cfg.riskPct=InpRiskPct;
   g_cfg.riskMaxLev=InpRiskMaxLev;
   g_cfg.riskMmr=InpRiskMmr;
   g_cfg.riskFeeSlipPct=InpRiskFeeSlipPct;
   g_cfg.riskMaxLosses=InpRiskMaxLosses;
   TM2NormalizeConfig(g_cfg);

//--- Bind buffers 0..241 (contract order)
   SetIndexBuffer(0,g_plot_ema_fast,INDICATOR_DATA);
   SetIndexBuffer(1,g_plot_ema_mid,INDICATOR_DATA);
   SetIndexBuffer(2,g_plot_ema_slow,INDICATOR_DATA);
   SetIndexBuffer(3,g_plot_atr,INDICATOR_DATA);
   SetIndexBuffer(4,g_plot_vwap,INDICATOR_DATA);
   SetIndexBuffer(5,g_plot_volume,INDICATOR_DATA);
   SetIndexBuffer(6,g_plot_long_entry,INDICATOR_DATA);
   SetIndexBuffer(7,g_plot_short_entry,INDICATOR_DATA);
   SetIndexBuffer(8,g_plot_hit_tp,INDICATOR_DATA);
   SetIndexBuffer(9,g_plot_hit_sl,INDICATOR_DATA);
   SetIndexBuffer(10,g_plot_active_sl,INDICATOR_DATA);
   SetIndexBuffer(11,g_plot_active_tp1,INDICATOR_DATA);
   SetIndexBuffer(12,g_plot_active_tp2,INDICATOR_DATA);
   SetIndexBuffer(13,g_plot_active_tp3,INDICATOR_DATA);
   SetIndexBuffer(14,g_plot_active_limit,INDICATOR_DATA);
   SetIndexBuffer(15,g_plot_score100,INDICATOR_DATA);
   SetIndexBuffer(16,g_b_longScore,INDICATOR_CALCULATIONS);
   SetIndexBuffer(17,g_b_shortScore,INDICATOR_CALCULATIONS);
   SetIndexBuffer(18,g_b_score100,INDICATOR_CALCULATIONS);
   SetIndexBuffer(19,g_b_scoreGap,INDICATOR_CALCULATIONS);
   SetIndexBuffer(20,g_b_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(21,g_b_directionCode,INDICATOR_CALCULATIONS);
   SetIndexBuffer(22,g_b_quality,INDICATOR_CALCULATIONS);
   SetIndexBuffer(23,g_b_qualityLevel,INDICATOR_CALCULATIONS);
   SetIndexBuffer(24,g_b_minReqLevel,INDICATOR_CALCULATIONS);
   SetIndexBuffer(25,g_b_okQuality,INDICATOR_CALCULATIONS);
   SetIndexBuffer(26,g_b_scoreBlock,INDICATOR_CALCULATIONS);
   SetIndexBuffer(27,g_b_ablationCode,INDICATOR_CALCULATIONS);
   SetIndexBuffer(28,g_b_wDirTotal,INDICATOR_CALCULATIONS);
   SetIndexBuffer(29,g_b_longWeighted,INDICATOR_CALCULATIONS);
   SetIndexBuffer(30,g_b_gateRegime,INDICATOR_CALCULATIONS);
   SetIndexBuffer(31,g_b_gateMtf,INDICATOR_CALCULATIONS);
   SetIndexBuffer(32,g_b_gateBtc,INDICATOR_CALCULATIONS);
   SetIndexBuffer(33,g_b_gateObstacle,INDICATOR_CALCULATIONS);
   SetIndexBuffer(34,g_b_gateOverext,INDICATOR_CALCULATIONS);
   SetIndexBuffer(35,g_b_gateCircuit,INDICATOR_CALCULATIONS);
   SetIndexBuffer(36,g_b_gateAll,INDICATOR_CALCULATIONS);
   SetIndexBuffer(37,g_b_gateTopReason,INDICATOR_CALCULATIONS);
   SetIndexBuffer(38,g_b_noTradeReason,INDICATOR_CALCULATIONS);
   SetIndexBuffer(39,g_b_okCool,INDICATOR_CALCULATIONS);
   SetIndexBuffer(40,g_b_okDay,INDICATOR_CALCULATIONS);
   SetIndexBuffer(41,g_b_okCircuit,INDICATOR_CALCULATIONS);
   SetIndexBuffer(42,g_b_planValid,INDICATOR_CALCULATIONS);
   SetIndexBuffer(43,g_b_planReason,INDICATOR_CALCULATIONS);
   SetIndexBuffer(44,g_b_orderType,INDICATOR_CALCULATIONS);
   SetIndexBuffer(45,g_b_entry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(46,g_b_limit,INDICATOR_CALCULATIONS);
   SetIndexBuffer(47,g_b_sl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(48,g_b_tp1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(49,g_b_tp2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(50,g_b_tp3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(51,g_b_risk,INDICATOR_CALCULATIONS);
   SetIndexBuffer(52,g_b_evalRR,INDICATOR_CALCULATIONS);
   SetIndexBuffer(53,g_b_posSize,INDICATOR_CALCULATIONS);
   SetIndexBuffer(54,g_b_notional,INDICATOR_CALCULATIONS);
   SetIndexBuffer(55,g_b_effLev,INDICATOR_CALCULATIONS);
   SetIndexBuffer(56,g_b_marginReq,INDICATOR_CALCULATIONS);
   SetIndexBuffer(57,g_b_liqPrice,INDICATOR_CALCULATIONS);
   SetIndexBuffer(58,g_b_netRR,INDICATOR_CALCULATIONS);
   SetIndexBuffer(59,g_b_signal,INDICATOR_CALCULATIONS);
   SetIndexBuffer(60,g_b_candidate,INDICATOR_CALCULATIONS);
   SetIndexBuffer(61,g_b_eligible,INDICATOR_CALCULATIONS);
   SetIndexBuffer(62,g_b_evEntry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(63,g_b_evPending,INDICATOR_CALCULATIONS);
   SetIndexBuffer(64,g_b_evFilled,INDICATOR_CALCULATIONS);
   SetIndexBuffer(65,g_b_evCancel,INDICATOR_CALCULATIONS);
   SetIndexBuffer(66,g_b_evTp,INDICATOR_CALCULATIONS);
   SetIndexBuffer(67,g_b_evSl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(68,g_b_evBe,INDICATOR_CALCULATIONS);
   SetIndexBuffer(69,g_b_evTrail,INDICATOR_CALCULATIONS);
   SetIndexBuffer(70,g_b_evTimeout,INDICATOR_CALCULATIONS);
   SetIndexBuffer(71,g_b_evDecay,INDICATOR_CALCULATIONS);
   SetIndexBuffer(72,g_b_evClose,INDICATOR_CALCULATIONS);
   SetIndexBuffer(73,g_b_cancelReason,INDICATOR_CALCULATIONS);
   SetIndexBuffer(74,g_b_closeReason,INDICATOR_CALCULATIONS);
   SetIndexBuffer(75,g_b_posDir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(76,g_b_posStage,INDICATOR_CALCULATIONS);
   SetIndexBuffer(77,g_b_posOrderType,INDICATOR_CALCULATIONS);
   SetIndexBuffer(78,g_b_posMode,INDICATOR_CALCULATIONS);
   SetIndexBuffer(79,g_b_posEntry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(80,g_b_posLimit,INDICATOR_CALCULATIONS);
   SetIndexBuffer(81,g_b_posSl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(82,g_b_posTp1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(83,g_b_posTp2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(84,g_b_posTp3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(85,g_b_posRisk,INDICATOR_CALCULATIONS);
   SetIndexBuffer(86,g_b_posBars,INDICATOR_CALCULATIONS);
   SetIndexBuffer(87,g_b_posBar,INDICATOR_CALCULATIONS);
   SetIndexBuffer(88,g_b_posMaxFavR,INDICATOR_CALCULATIONS);
   SetIndexBuffer(89,g_b_dayCount,INDICATOR_CALCULATIONS);
   SetIndexBuffer(90,g_b_barsSince,INDICATOR_CALCULATIONS);
   SetIndexBuffer(91,g_b_consecLosses,INDICATOR_CALCULATIONS);
   SetIndexBuffer(92,g_b_trades,INDICATOR_CALCULATIONS);
   SetIndexBuffer(93,g_b_tp1Hits,INDICATOR_CALCULATIONS);
   SetIndexBuffer(94,g_b_netWins,INDICATOR_CALCULATIONS);
   SetIndexBuffer(95,g_b_beSaves,INDICATOR_CALCULATIONS);
   SetIndexBuffer(96,g_b_fullLosses,INDICATOR_CALCULATIONS);
   SetIndexBuffer(97,g_b_timeouts,INDICATOR_CALCULATIONS);
   SetIndexBuffer(98,g_b_decays,INDICATOR_CALCULATIONS);
   SetIndexBuffer(99,g_b_realizedRSum,INDICATOR_CALCULATIONS);
   SetIndexBuffer(100,g_b_candidates,INDICATOR_CALCULATIONS);
   SetIndexBuffer(101,g_b_eligibleN,INDICATOR_CALCULATIONS);
   SetIndexBuffer(102,g_b_pendingN,INDICATOR_CALCULATIONS);
   SetIndexBuffer(103,g_b_filledN,INDICATOR_CALCULATIONS);
   SetIndexBuffer(104,g_b_closedN,INDICATOR_CALCULATIONS);
   SetIndexBuffer(105,g_b_xDir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(106,g_b_xEntry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(107,g_b_xSl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(108,g_b_xExit,INDICATOR_CALCULATIONS);
   SetIndexBuffer(109,g_b_xR,INDICATOR_CALCULATIONS);
   SetIndexBuffer(110,g_b_xReason,INDICATOR_CALCULATIONS);
   SetIndexBuffer(111,g_b_xBar,INDICATOR_CALCULATIONS);
   SetIndexBuffer(112,g_b_xStage,INDICATOR_CALCULATIONS);
   SetIndexBuffer(113,g_b_regimeCode,INDICATOR_CALCULATIONS);
   SetIndexBuffer(114,g_b_regimeDir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(115,g_b_regimeAdx,INDICATOR_CALCULATIONS);
   SetIndexBuffer(116,g_b_regimeBbwPct,INDICATOR_CALCULATIONS);
   SetIndexBuffer(117,g_b_isSqueeze,INDICATOR_CALCULATIONS);
   SetIndexBuffer(118,g_b_bbWidth,INDICATOR_CALCULATIONS);
   SetIndexBuffer(119,g_b_bbWidthMA,INDICATOR_CALCULATIONS);
   SetIndexBuffer(120,g_b_bbExpand,INDICATOR_CALCULATIONS);
   SetIndexBuffer(121,g_b_trend,INDICATOR_CALCULATIONS);
   SetIndexBuffer(122,g_b_bosUp,INDICATOR_CALCULATIONS);
   SetIndexBuffer(123,g_b_bosDown,INDICATOR_CALCULATIONS);
   SetIndexBuffer(124,g_b_chochUp,INDICATOR_CALCULATIONS);
   SetIndexBuffer(125,g_b_chochDown,INDICATOR_CALCULATIONS);
   SetIndexBuffer(126,g_b_mssUp,INDICATOR_CALCULATIONS);
   SetIndexBuffer(127,g_b_mssDown,INDICATOR_CALCULATIONS);
   SetIndexBuffer(128,g_b_retestUp,INDICATOR_CALCULATIONS);
   SetIndexBuffer(129,g_b_retestDown,INDICATOR_CALCULATIONS);
   SetIndexBuffer(130,g_b_failUp,INDICATOR_CALCULATIONS);
   SetIndexBuffer(131,g_b_failDown,INDICATOR_CALCULATIONS);
   SetIndexBuffer(132,g_b_contUp,INDICATOR_CALCULATIONS);
   SetIndexBuffer(133,g_b_contDown,INDICATOR_CALCULATIONS);
   SetIndexBuffer(134,g_b_pullUp,INDICATOR_CALCULATIONS);
   SetIndexBuffer(135,g_b_pullDown,INDICATOR_CALCULATIONS);
   SetIndexBuffer(136,g_b_hh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(137,g_b_ll,INDICATOR_CALCULATIONS);
   SetIndexBuffer(138,g_b_eqHi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(139,g_b_eqLo,INDICATOR_CALCULATIONS);
   SetIndexBuffer(140,g_b_swingHi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(141,g_b_swingLo,INDICATOR_CALCULATIONS);
   SetIndexBuffer(142,g_b_prevHigh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(143,g_b_prevLow,INDICATOR_CALCULATIONS);
   SetIndexBuffer(144,g_b_brkLevel,INDICATOR_CALCULATIONS);
   SetIndexBuffer(145,g_b_brkDir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(146,g_b_brkBar,INDICATOR_CALCULATIONS);
   SetIndexBuffer(147,g_b_evtKind,INDICATOR_CALCULATIONS);
   SetIndexBuffer(148,g_b_evtDir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(149,g_b_evtSrcBar,INDICATOR_CALCULATIONS);
   SetIndexBuffer(150,g_b_evtSrcTime,INDICATOR_CALCULATIONS);
   SetIndexBuffer(151,g_b_evtLevel,INDICATOR_CALCULATIONS);
   SetIndexBuffer(152,g_b_evtCount,INDICATOR_CALCULATIONS);
   SetIndexBuffer(153,g_b_lastSweepBullBar,INDICATOR_CALCULATIONS);
   SetIndexBuffer(154,g_b_lastSweepBullPx,INDICATOR_CALCULATIONS);
   SetIndexBuffer(155,g_b_lastSweepBearBar,INDICATOR_CALCULATIONS);
   SetIndexBuffer(156,g_b_lastSweepBearPx,INDICATOR_CALCULATIONS);
   SetIndexBuffer(157,g_b_cpBull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(158,g_b_cpBear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(159,g_b_candleScore,INDICATOR_CALCULATIONS);
   SetIndexBuffer(160,g_b_pinBull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(161,g_b_pinBear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(162,g_b_engBull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(163,g_b_engBear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(164,g_b_dispBull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(165,g_b_dispBear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(166,g_b_rejBull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(167,g_b_rejBear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(168,g_b_isOverext,INDICATOR_CALCULATIONS);
   SetIndexBuffer(169,g_b_extEma,INDICATOR_CALCULATIONS);
   SetIndexBuffer(170,g_b_extCandle,INDICATOR_CALCULATIONS);
   SetIndexBuffer(171,g_b_atr,INDICATOR_CALCULATIONS);
   SetIndexBuffer(172,g_b_atrPct,INDICATOR_CALCULATIONS);
   SetIndexBuffer(173,g_b_rsi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(174,g_b_macdHist,INDICATOR_CALCULATIONS);
   SetIndexBuffer(175,g_b_adx,INDICATOR_CALCULATIONS);
   SetIndexBuffer(176,g_b_diPlus,INDICATOR_CALCULATIONS);
   SetIndexBuffer(177,g_b_diMinus,INDICATOR_CALCULATIONS);
   SetIndexBuffer(178,g_b_emaSlope20,INDICATOR_CALCULATIONS);
   SetIndexBuffer(179,g_b_emaBull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(180,g_b_emaBear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(181,g_b_atrSafe,INDICATOR_CALCULATIONS);
   SetIndexBuffer(182,g_b_vol,INDICATOR_CALCULATIONS);
   SetIndexBuffer(183,g_b_volMA,INDICATOR_CALCULATIONS);
   SetIndexBuffer(184,g_b_volRatio,INDICATOR_CALCULATIONS);
   SetIndexBuffer(185,g_b_volBucket,INDICATOR_CALCULATIONS);
   SetIndexBuffer(186,g_b_isTim,INDICATOR_CALCULATIONS);
   SetIndexBuffer(187,g_b_relVol,INDICATOR_CALCULATIONS);
   SetIndexBuffer(188,g_b_obv,INDICATOR_CALCULATIONS);
   SetIndexBuffer(189,g_b_obvSlope,INDICATOR_CALCULATIONS);
   SetIndexBuffer(190,g_b_vwap,INDICATOR_CALCULATIONS);
   SetIndexBuffer(191,g_b_vwapScore,INDICATOR_CALCULATIONS);
   SetIndexBuffer(192,g_b_pdh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(193,g_b_pdl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(194,g_b_pwh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(195,g_b_pwl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(196,g_b_dayRange,INDICATOR_CALCULATIONS);
   SetIndexBuffer(197,g_b_sessName,INDICATOR_CALCULATIONS);
   SetIndexBuffer(198,g_b_sessHi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(199,g_b_sessLo,INDICATOR_CALCULATIONS);
   SetIndexBuffer(200,g_b_nearSup,INDICATOR_CALCULATIONS);
   SetIndexBuffer(201,g_b_nearRes,INDICATOR_CALCULATIONS);
   SetIndexBuffer(202,g_b_nearFvgBull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(203,g_b_nearFvgBear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(204,g_b_nearObBull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(205,g_b_nearObBear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(206,g_b_srCount,INDICATOR_CALCULATIONS);
   SetIndexBuffer(207,g_b_fvgCount,INDICATOR_CALCULATIONS);
   SetIndexBuffer(208,g_b_obCount,INDICATOR_CALCULATIONS);
   SetIndexBuffer(209,g_b_nearestRes,INDICATOR_CALCULATIONS);
   SetIndexBuffer(210,g_b_nearestSup,INDICATOR_CALCULATIONS);
   SetIndexBuffer(211,g_b_fvgBullPx,INDICATOR_CALCULATIONS);
   SetIndexBuffer(212,g_b_fvgBearPx,INDICATOR_CALCULATIONS);
   SetIndexBuffer(213,g_b_obBullPx,INDICATOR_CALCULATIONS);
   SetIndexBuffer(214,g_b_obBearPx,INDICATOR_CALCULATIONS);
   SetIndexBuffer(215,g_b_mtfCtxDir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(216,g_b_mtfSetupDir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(217,g_b_mtfCtxEma,INDICATOR_CALCULATIONS);
   SetIndexBuffer(218,g_b_mtfSetupEma,INDICATOR_CALCULATIONS);
   SetIndexBuffer(219,g_b_mtfBias,INDICATOR_CALCULATIONS);
   SetIndexBuffer(220,g_b_mtfHierOk,INDICATOR_CALCULATIONS);
   SetIndexBuffer(221,g_b_btcDump,INDICATOR_CALCULATIONS);
   SetIndexBuffer(222,g_b_btcPump,INDICATOR_CALCULATIONS);
   SetIndexBuffer(223,g_b_weekendBlock,INDICATOR_CALCULATIONS);
   SetIndexBuffer(224,g_b_modeDir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(225,g_b_activeMode,INDICATOR_CALCULATIONS);
   SetIndexBuffer(226,g_b_modeReady,INDICATOR_CALCULATIONS);
   SetIndexBuffer(227,g_b_modeGateOk,INDICATOR_CALCULATIONS);
   SetIndexBuffer(228,g_b_modeReason,INDICATOR_CALCULATIONS);
   SetIndexBuffer(229,g_b_modeBInvalidLong,INDICATOR_CALCULATIONS);
   SetIndexBuffer(230,g_b_modeBInvalidShort,INDICATOR_CALCULATIONS);
   SetIndexBuffer(231,g_b_modeCBoxOk,INDICATOR_CALCULATIONS);
   SetIndexBuffer(232,g_b_gTrend,INDICATOR_CALCULATIONS);
   SetIndexBuffer(233,g_b_gStruct,INDICATOR_CALCULATIONS);
   SetIndexBuffer(234,g_b_gLiq,INDICATOR_CALCULATIONS);
   SetIndexBuffer(235,g_b_gLoc,INDICATOR_CALCULATIONS);
   SetIndexBuffer(236,g_b_gSr,INDICATOR_CALCULATIONS);
   SetIndexBuffer(237,g_b_gCandle,INDICATOR_CALCULATIONS);
   SetIndexBuffer(238,g_b_gVolume,INDICATOR_CALCULATIONS);
   SetIndexBuffer(239,g_b_gMom,INDICATOR_CALCULATIONS);
   SetIndexBuffer(240,g_b_gSess,INDICATOR_CALCULATIONS);
   SetIndexBuffer(241,g_b_gMtf,INDICATOR_CALCULATIONS);

//--- Plot appearance
   PlotIndexSetInteger(6,PLOT_ARROW,233);
   PlotIndexSetInteger(7,PLOT_ARROW,234);
   PlotIndexSetInteger(8,PLOT_ARROW,159);
   PlotIndexSetInteger(9,PLOT_ARROW,251);
   for(int p=0; p<16; p++)
     {
      if(p==5)
         PlotIndexSetDouble(p,PLOT_EMPTY_VALUE,0.0);
      else
         PlotIndexSetDouble(p,PLOT_EMPTY_VALUE,EMPTY_VALUE);
     }
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   IndicatorSetString(INDICATOR_SHORTNAME,"TM Indicator 2 (PinePort)");

   return(INIT_SUCCEEDED);
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
   const double point=_Point;

//--- Pass 1: indicator series
   double volD[];
   ArrayResize(volD,total);
   for(int j=0; j<total; j++)
      volD[j]=(double)tick_volume[j];

   double atr[],atrPct[],atrSafe[],emaF[],emaM[],emaS[],slope20[];
   TM2BuildAtr(high,low,close,total,g_cfg.atrLen,atr);
   TM2BuildEma(close,total,g_cfg.emaFast,emaF);
   TM2BuildEma(close,total,g_cfg.emaMid,emaM);
   TM2BuildEma(close,total,g_cfg.emaSlow,emaS);
   ArrayResize(atrPct,total);
   ArrayResize(atrSafe,total);
   ArrayResize(slope20,total);
   for(int j=0; j<total; j++)
     {
      const bool atrOk=!TM2IsEmpty(atr[j]) && atr[j]>0.0;
      atrPct[j]=(atrOk && close[j]>0.0) ? atr[j]/close[j]*100.0 : 0.0;
      atrSafe[j]=atrOk ? atr[j] : close[j]*0.01;
      if(j>=3 && !TM2IsEmpty(emaF[j]) && !TM2IsEmpty(emaF[j-3]) && atrOk)
         slope20[j]=(emaF[j]-emaF[j-3])/(3.0*atr[j]);
      else
         slope20[j]=0.0;
     }

   double bbMid[],bbUp[],bbLo[],bbWidth[],bbWidthMA[],bbwPct[];
   TM2BuildBb(close,total,TM2_BB_LEN,TM2_BB_MULT,bbMid,bbUp,bbLo);
   ArrayResize(bbWidth,total);
   ArrayInitialize(bbWidth,EMPTY_VALUE);
   for(int j=0; j<total; j++)
     {
      if(!TM2IsEmpty(bbMid[j]) && !TM2IsEmpty(bbUp[j]) && !TM2IsEmpty(bbLo[j])
         && bbMid[j]>0.0)
         bbWidth[j]=(bbUp[j]-bbLo[j])/bbMid[j]*100.0;
     }
   TM2BuildSma(bbWidth,total,TM2_BBW_MA,bbWidthMA);
   TM2BuildBbWidthPct(bbWidth,total,g_cfg.bbwLen,bbwPct);

   double diP[],diM[],adx[],rsi[],macdHist[],macdPrev[];
   TM2BuildDmi(high,low,close,total,g_cfg.dmiLen,TM2_DMI_SMOOTH,
               diP,diM,adx);
   TM2BuildRsi(close,total,g_cfg.rsiLen,rsi);
   TM2BuildMacdHist(close,total,g_cfg.macdFast,g_cfg.macdSlow,g_cfg.macdSignal,macdHist);
   ArrayResize(macdPrev,total);
   ArrayInitialize(macdPrev,EMPTY_VALUE);
   for(int j=1; j<total; j++)
      macdPrev[j]=macdHist[j-1];

   double volMA[],volSma[];
   TM2BuildRma(volD,total,g_cfg.volMaLen,volMA);
   TM2BuildSma(volD,total,TM2_VOL_SMA,volSma);

   double vwap[];
   TM2BuildVwap(close,high,low,tick_volume,time,total,g_cfg.srvOffsetMin,vwap);

//--- Structure pivots (msSwingLen) and S/R pivots (10/10)
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
      pivHOk[j]=TM2PivotHighAt(high,total,j,g_cfg.msSwingLen,g_cfg.msSwingLen,value);
      pivH[j]=value;
      value=EMPTY_VALUE;
      pivLOk[j]=TM2PivotLowAt(low,total,j,g_cfg.msSwingLen,g_cfg.msSwingLen,value);
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
      srPivHOk[j]=TM2PivotHighAt(high,total,j,TM2_SR_PIV,TM2_SR_PIV,value);
      srPivH[j]=value;
      value=EMPTY_VALUE;
      srPivLOk[j]=TM2PivotLowAt(low,total,j,TM2_SR_PIV,TM2_SR_PIV,value);
      srPivL[j]=value;
     }

//--- HTF close/EMA (Pine request.security expr[1], lookahead_on)
   double ctxClose[],ctxEma[],setupClose[],setupEma[];
   bool ctxOk[],setupOk[];
   TMInd2LoadHtf(g_cfg.ctxTf,g_cfg.ctxLen,total,time,ctxClose,ctxEma,ctxOk);
   TMInd2LoadHtf(g_cfg.setupTf,g_cfg.setupLen,total,time,setupClose,setupEma,setupOk);

   const int secChart=(int)PeriodSeconds((ENUM_TIMEFRAMES)Period());
   const int secSetup=(int)PeriodSeconds(g_cfg.setupTf);
   const int secCtx=(int)PeriodSeconds(g_cfg.ctxTf);
   const bool hierOk=TM2MtfHierarchyOk(secChart,secSetup,secCtx);

//--- Previous completed server day/week levels
   double pdh[],pdl[],pwh[],pwl[];
   bool hasPd[],hasPw[];
   TMInd2BuildPrevPeriod(high,low,time,total,pdh,pdl,hasPd,pwh,pwl,hasPw);

//--- BTC leader + asset profile
   double btcClose[],btcEma[],btcRsi[],btcAtr[];
   bool btcOk[];
   TMInd2LoadBtc(g_cfg.btcSymbol,total,time,btcClose,btcEma,btcRsi,btcAtr,btcOk);
   const bool btcNeed=TM2NeedBtcLeader(g_cfg,_Symbol);
   const bool isCrypto=TM2IsCrypto(g_cfg,_Symbol);

//--- Plot defaults; the live bar (rates_total-1) stays 0/EMPTY.
   for(int j=0; j<total; j++)
     {
      g_plot_ema_fast[j]=EMPTY_VALUE;
      g_plot_ema_mid[j]=EMPTY_VALUE;
      g_plot_ema_slow[j]=EMPTY_VALUE;
      g_plot_atr[j]=EMPTY_VALUE;
      g_plot_vwap[j]=EMPTY_VALUE;
      g_plot_volume[j]=0.0;
      g_plot_long_entry[j]=EMPTY_VALUE;
      g_plot_short_entry[j]=EMPTY_VALUE;
      g_plot_hit_tp[j]=EMPTY_VALUE;
      g_plot_hit_sl[j]=EMPTY_VALUE;
      g_plot_active_sl[j]=EMPTY_VALUE;
      g_plot_active_tp1[j]=EMPTY_VALUE;
      g_plot_active_tp2[j]=EMPTY_VALUE;
      g_plot_active_tp3[j]=EMPTY_VALUE;
      g_plot_active_limit[j]=EMPTY_VALUE;
      g_plot_score100[j]=EMPTY_VALUE;
     }
   for(int j=0; j<=lastClosed; j++)
     {
      g_plot_ema_fast[j]=emaF[j];
      g_plot_ema_mid[j]=emaM[j];
      g_plot_ema_slow[j]=emaS[j];
      g_plot_atr[j]=atr[j];
      g_plot_vwap[j]=vwap[j];
      g_plot_volume[j]=(double)tick_volume[j];
     }

//--- First pass: every contract buffer starts at its documented "missing" value.
   if(g_first)
     {
      ArrayInitialize(g_b_longScore,EMPTY_VALUE);
      ArrayInitialize(g_b_shortScore,EMPTY_VALUE);
      ArrayInitialize(g_b_score100,EMPTY_VALUE);
      ArrayInitialize(g_b_scoreGap,EMPTY_VALUE);
      ArrayInitialize(g_b_dir,0.0);
      ArrayInitialize(g_b_directionCode,0.0);
      ArrayInitialize(g_b_quality,0.0);
      ArrayInitialize(g_b_qualityLevel,0.0);
      ArrayInitialize(g_b_minReqLevel,0.0);
      ArrayInitialize(g_b_okQuality,0.0);
      ArrayInitialize(g_b_scoreBlock,0.0);
      ArrayInitialize(g_b_ablationCode,0.0);
      ArrayInitialize(g_b_wDirTotal,0.0);
      ArrayInitialize(g_b_longWeighted,EMPTY_VALUE);
      ArrayInitialize(g_b_gateRegime,1.0);
      ArrayInitialize(g_b_gateMtf,1.0);
      ArrayInitialize(g_b_gateBtc,1.0);
      ArrayInitialize(g_b_gateObstacle,1.0);
      ArrayInitialize(g_b_gateOverext,1.0);
      ArrayInitialize(g_b_gateCircuit,1.0);
      ArrayInitialize(g_b_gateAll,0.0);
      ArrayInitialize(g_b_gateTopReason,0.0);
      ArrayInitialize(g_b_noTradeReason,0.0);
      ArrayInitialize(g_b_okCool,0.0);
      ArrayInitialize(g_b_okDay,0.0);
      ArrayInitialize(g_b_okCircuit,0.0);
      ArrayInitialize(g_b_planValid,0.0);
      ArrayInitialize(g_b_planReason,0.0);
      ArrayInitialize(g_b_orderType,0.0);
      ArrayInitialize(g_b_entry,EMPTY_VALUE);
      ArrayInitialize(g_b_limit,EMPTY_VALUE);
      ArrayInitialize(g_b_sl,EMPTY_VALUE);
      ArrayInitialize(g_b_tp1,EMPTY_VALUE);
      ArrayInitialize(g_b_tp2,EMPTY_VALUE);
      ArrayInitialize(g_b_tp3,EMPTY_VALUE);
      ArrayInitialize(g_b_risk,EMPTY_VALUE);
      ArrayInitialize(g_b_evalRR,EMPTY_VALUE);
      ArrayInitialize(g_b_posSize,EMPTY_VALUE);
      ArrayInitialize(g_b_notional,EMPTY_VALUE);
      ArrayInitialize(g_b_effLev,EMPTY_VALUE);
      ArrayInitialize(g_b_marginReq,EMPTY_VALUE);
      ArrayInitialize(g_b_liqPrice,EMPTY_VALUE);
      ArrayInitialize(g_b_netRR,EMPTY_VALUE);
      ArrayInitialize(g_b_signal,0.0);
      ArrayInitialize(g_b_candidate,0.0);
      ArrayInitialize(g_b_eligible,0.0);
      ArrayInitialize(g_b_evEntry,0.0);
      ArrayInitialize(g_b_evPending,0.0);
      ArrayInitialize(g_b_evFilled,0.0);
      ArrayInitialize(g_b_evCancel,0.0);
      ArrayInitialize(g_b_evTp,0.0);
      ArrayInitialize(g_b_evSl,0.0);
      ArrayInitialize(g_b_evBe,0.0);
      ArrayInitialize(g_b_evTrail,0.0);
      ArrayInitialize(g_b_evTimeout,0.0);
      ArrayInitialize(g_b_evDecay,0.0);
      ArrayInitialize(g_b_evClose,0.0);
      ArrayInitialize(g_b_cancelReason,0.0);
      ArrayInitialize(g_b_closeReason,0.0);
      ArrayInitialize(g_b_posDir,0.0);
      ArrayInitialize(g_b_posStage,0.0);
      ArrayInitialize(g_b_posOrderType,0.0);
      ArrayInitialize(g_b_posMode,0.0);
      ArrayInitialize(g_b_posEntry,EMPTY_VALUE);
      ArrayInitialize(g_b_posLimit,EMPTY_VALUE);
      ArrayInitialize(g_b_posSl,EMPTY_VALUE);
      ArrayInitialize(g_b_posTp1,EMPTY_VALUE);
      ArrayInitialize(g_b_posTp2,EMPTY_VALUE);
      ArrayInitialize(g_b_posTp3,EMPTY_VALUE);
      ArrayInitialize(g_b_posRisk,EMPTY_VALUE);
      ArrayInitialize(g_b_posBars,0.0);
      ArrayInitialize(g_b_posBar,-1.0);
      ArrayInitialize(g_b_posMaxFavR,0.0);
      ArrayInitialize(g_b_dayCount,0.0);
      ArrayInitialize(g_b_barsSince,0.0);
      ArrayInitialize(g_b_consecLosses,0.0);
      ArrayInitialize(g_b_trades,0.0);
      ArrayInitialize(g_b_tp1Hits,0.0);
      ArrayInitialize(g_b_netWins,0.0);
      ArrayInitialize(g_b_beSaves,0.0);
      ArrayInitialize(g_b_fullLosses,0.0);
      ArrayInitialize(g_b_timeouts,0.0);
      ArrayInitialize(g_b_decays,0.0);
      ArrayInitialize(g_b_realizedRSum,0.0);
      ArrayInitialize(g_b_candidates,0.0);
      ArrayInitialize(g_b_eligibleN,0.0);
      ArrayInitialize(g_b_pendingN,0.0);
      ArrayInitialize(g_b_filledN,0.0);
      ArrayInitialize(g_b_closedN,0.0);
      ArrayInitialize(g_b_xDir,0.0);
      ArrayInitialize(g_b_xEntry,EMPTY_VALUE);
      ArrayInitialize(g_b_xSl,EMPTY_VALUE);
      ArrayInitialize(g_b_xExit,EMPTY_VALUE);
      ArrayInitialize(g_b_xR,EMPTY_VALUE);
      ArrayInitialize(g_b_xReason,0.0);
      ArrayInitialize(g_b_xBar,-1.0);
      ArrayInitialize(g_b_xStage,0.0);
      ArrayInitialize(g_b_regimeCode,0.0);
      ArrayInitialize(g_b_regimeDir,0.0);
      ArrayInitialize(g_b_regimeAdx,EMPTY_VALUE);
      ArrayInitialize(g_b_regimeBbwPct,50.0);
      ArrayInitialize(g_b_isSqueeze,0.0);
      ArrayInitialize(g_b_bbWidth,EMPTY_VALUE);
      ArrayInitialize(g_b_bbWidthMA,EMPTY_VALUE);
      ArrayInitialize(g_b_bbExpand,0.0);
      ArrayInitialize(g_b_trend,0.0);
      ArrayInitialize(g_b_bosUp,0.0);
      ArrayInitialize(g_b_bosDown,0.0);
      ArrayInitialize(g_b_chochUp,0.0);
      ArrayInitialize(g_b_chochDown,0.0);
      ArrayInitialize(g_b_mssUp,0.0);
      ArrayInitialize(g_b_mssDown,0.0);
      ArrayInitialize(g_b_retestUp,0.0);
      ArrayInitialize(g_b_retestDown,0.0);
      ArrayInitialize(g_b_failUp,0.0);
      ArrayInitialize(g_b_failDown,0.0);
      ArrayInitialize(g_b_contUp,0.0);
      ArrayInitialize(g_b_contDown,0.0);
      ArrayInitialize(g_b_pullUp,0.0);
      ArrayInitialize(g_b_pullDown,0.0);
      ArrayInitialize(g_b_hh,0.0);
      ArrayInitialize(g_b_ll,0.0);
      ArrayInitialize(g_b_eqHi,0.0);
      ArrayInitialize(g_b_eqLo,0.0);
      ArrayInitialize(g_b_swingHi,EMPTY_VALUE);
      ArrayInitialize(g_b_swingLo,EMPTY_VALUE);
      ArrayInitialize(g_b_prevHigh,EMPTY_VALUE);
      ArrayInitialize(g_b_prevLow,EMPTY_VALUE);
      ArrayInitialize(g_b_brkLevel,EMPTY_VALUE);
      ArrayInitialize(g_b_brkDir,0.0);
      ArrayInitialize(g_b_brkBar,-1.0);
      ArrayInitialize(g_b_evtKind,0.0);
      ArrayInitialize(g_b_evtDir,0.0);
      ArrayInitialize(g_b_evtSrcBar,-1.0);
      ArrayInitialize(g_b_evtSrcTime,0.0);
      ArrayInitialize(g_b_evtLevel,EMPTY_VALUE);
      ArrayInitialize(g_b_evtCount,0.0);
      ArrayInitialize(g_b_lastSweepBullBar,-1.0);
      ArrayInitialize(g_b_lastSweepBullPx,EMPTY_VALUE);
      ArrayInitialize(g_b_lastSweepBearBar,-1.0);
      ArrayInitialize(g_b_lastSweepBearPx,EMPTY_VALUE);
      ArrayInitialize(g_b_cpBull,0.0);
      ArrayInitialize(g_b_cpBear,0.0);
      ArrayInitialize(g_b_candleScore,0.0);
      ArrayInitialize(g_b_pinBull,0.0);
      ArrayInitialize(g_b_pinBear,0.0);
      ArrayInitialize(g_b_engBull,0.0);
      ArrayInitialize(g_b_engBear,0.0);
      ArrayInitialize(g_b_dispBull,0.0);
      ArrayInitialize(g_b_dispBear,0.0);
      ArrayInitialize(g_b_rejBull,0.0);
      ArrayInitialize(g_b_rejBear,0.0);
      ArrayInitialize(g_b_isOverext,0.0);
      ArrayInitialize(g_b_extEma,0.0);
      ArrayInitialize(g_b_extCandle,1.0);
      ArrayInitialize(g_b_atr,EMPTY_VALUE);
      ArrayInitialize(g_b_atrPct,0.0);
      ArrayInitialize(g_b_rsi,EMPTY_VALUE);
      ArrayInitialize(g_b_macdHist,EMPTY_VALUE);
      ArrayInitialize(g_b_adx,EMPTY_VALUE);
      ArrayInitialize(g_b_diPlus,EMPTY_VALUE);
      ArrayInitialize(g_b_diMinus,EMPTY_VALUE);
      ArrayInitialize(g_b_emaSlope20,0.0);
      ArrayInitialize(g_b_emaBull,0.0);
      ArrayInitialize(g_b_emaBear,0.0);
      ArrayInitialize(g_b_atrSafe,EMPTY_VALUE);
      ArrayInitialize(g_b_vol,0.0);
      ArrayInitialize(g_b_volMA,EMPTY_VALUE);
      ArrayInitialize(g_b_volRatio,0.0);
      ArrayInitialize(g_b_volBucket,0.0);
      ArrayInitialize(g_b_isTim,0.0);
      ArrayInitialize(g_b_relVol,0.0);
      ArrayInitialize(g_b_obv,0.0);
      ArrayInitialize(g_b_obvSlope,0.0);
      ArrayInitialize(g_b_vwap,EMPTY_VALUE);
      ArrayInitialize(g_b_vwapScore,0.0);
      ArrayInitialize(g_b_pdh,EMPTY_VALUE);
      ArrayInitialize(g_b_pdl,EMPTY_VALUE);
      ArrayInitialize(g_b_pwh,EMPTY_VALUE);
      ArrayInitialize(g_b_pwl,EMPTY_VALUE);
      ArrayInitialize(g_b_dayRange,0.0);
      ArrayInitialize(g_b_sessName,0.0);
      ArrayInitialize(g_b_sessHi,EMPTY_VALUE);
      ArrayInitialize(g_b_sessLo,EMPTY_VALUE);
      ArrayInitialize(g_b_nearSup,0.0);
      ArrayInitialize(g_b_nearRes,0.0);
      ArrayInitialize(g_b_nearFvgBull,0.0);
      ArrayInitialize(g_b_nearFvgBear,0.0);
      ArrayInitialize(g_b_nearObBull,0.0);
      ArrayInitialize(g_b_nearObBear,0.0);
      ArrayInitialize(g_b_srCount,0.0);
      ArrayInitialize(g_b_fvgCount,0.0);
      ArrayInitialize(g_b_obCount,0.0);
      ArrayInitialize(g_b_nearestRes,EMPTY_VALUE);
      ArrayInitialize(g_b_nearestSup,EMPTY_VALUE);
      ArrayInitialize(g_b_fvgBullPx,EMPTY_VALUE);
      ArrayInitialize(g_b_fvgBearPx,EMPTY_VALUE);
      ArrayInitialize(g_b_obBullPx,EMPTY_VALUE);
      ArrayInitialize(g_b_obBearPx,EMPTY_VALUE);
      ArrayInitialize(g_b_mtfCtxDir,0.0);
      ArrayInitialize(g_b_mtfSetupDir,0.0);
      ArrayInitialize(g_b_mtfCtxEma,EMPTY_VALUE);
      ArrayInitialize(g_b_mtfSetupEma,EMPTY_VALUE);
      ArrayInitialize(g_b_mtfBias,0.0);
      ArrayInitialize(g_b_mtfHierOk,0.0);
      ArrayInitialize(g_b_btcDump,0.0);
      ArrayInitialize(g_b_btcPump,0.0);
      ArrayInitialize(g_b_weekendBlock,0.0);
      ArrayInitialize(g_b_modeDir,0.0);
      ArrayInitialize(g_b_activeMode,0.0);
      ArrayInitialize(g_b_modeReady,0.0);
      ArrayInitialize(g_b_modeGateOk,0.0);
      ArrayInitialize(g_b_modeReason,0.0);
      ArrayInitialize(g_b_modeBInvalidLong,0.0);
      ArrayInitialize(g_b_modeBInvalidShort,0.0);
      ArrayInitialize(g_b_modeCBoxOk,0.0);
      ArrayInitialize(g_b_gTrend,EMPTY_VALUE);
      ArrayInitialize(g_b_gStruct,0.0);
      ArrayInitialize(g_b_gLiq,0.0);
      ArrayInitialize(g_b_gLoc,0.0);
      ArrayInitialize(g_b_gSr,0.0);
      ArrayInitialize(g_b_gCandle,0.0);
      ArrayInitialize(g_b_gVolume,EMPTY_VALUE);
      ArrayInitialize(g_b_gMom,EMPTY_VALUE);
      ArrayInitialize(g_b_gSess,0.0);
      ArrayInitialize(g_b_gMtf,0.0);
      g_first=false;
     }

//--- Contract buffers: live bar keeps the documented "missing" values.
   const int liveBar=total-1;
   g_b_longScore[liveBar]=EMPTY_VALUE;
   g_b_shortScore[liveBar]=EMPTY_VALUE;
   g_b_score100[liveBar]=EMPTY_VALUE;
   g_b_scoreGap[liveBar]=EMPTY_VALUE;
   g_b_dir[liveBar]=0.0;
   g_b_directionCode[liveBar]=0.0;
   g_b_quality[liveBar]=0.0;
   g_b_qualityLevel[liveBar]=0.0;
   g_b_minReqLevel[liveBar]=0.0;
   g_b_okQuality[liveBar]=0.0;
   g_b_scoreBlock[liveBar]=0.0;
   g_b_ablationCode[liveBar]=0.0;
   g_b_wDirTotal[liveBar]=0.0;
   g_b_longWeighted[liveBar]=EMPTY_VALUE;
   g_b_gateRegime[liveBar]=1.0;
   g_b_gateMtf[liveBar]=1.0;
   g_b_gateBtc[liveBar]=1.0;
   g_b_gateObstacle[liveBar]=1.0;
   g_b_gateOverext[liveBar]=1.0;
   g_b_gateCircuit[liveBar]=1.0;
   g_b_gateAll[liveBar]=0.0;
   g_b_gateTopReason[liveBar]=0.0;
   g_b_noTradeReason[liveBar]=0.0;
   g_b_okCool[liveBar]=0.0;
   g_b_okDay[liveBar]=0.0;
   g_b_okCircuit[liveBar]=0.0;
   g_b_planValid[liveBar]=0.0;
   g_b_planReason[liveBar]=0.0;
   g_b_orderType[liveBar]=0.0;
   g_b_entry[liveBar]=EMPTY_VALUE;
   g_b_limit[liveBar]=EMPTY_VALUE;
   g_b_sl[liveBar]=EMPTY_VALUE;
   g_b_tp1[liveBar]=EMPTY_VALUE;
   g_b_tp2[liveBar]=EMPTY_VALUE;
   g_b_tp3[liveBar]=EMPTY_VALUE;
   g_b_risk[liveBar]=EMPTY_VALUE;
   g_b_evalRR[liveBar]=EMPTY_VALUE;
   g_b_posSize[liveBar]=EMPTY_VALUE;
   g_b_notional[liveBar]=EMPTY_VALUE;
   g_b_effLev[liveBar]=EMPTY_VALUE;
   g_b_marginReq[liveBar]=EMPTY_VALUE;
   g_b_liqPrice[liveBar]=EMPTY_VALUE;
   g_b_netRR[liveBar]=EMPTY_VALUE;
   g_b_signal[liveBar]=0.0;
   g_b_candidate[liveBar]=0.0;
   g_b_eligible[liveBar]=0.0;
   g_b_evEntry[liveBar]=0.0;
   g_b_evPending[liveBar]=0.0;
   g_b_evFilled[liveBar]=0.0;
   g_b_evCancel[liveBar]=0.0;
   g_b_evTp[liveBar]=0.0;
   g_b_evSl[liveBar]=0.0;
   g_b_evBe[liveBar]=0.0;
   g_b_evTrail[liveBar]=0.0;
   g_b_evTimeout[liveBar]=0.0;
   g_b_evDecay[liveBar]=0.0;
   g_b_evClose[liveBar]=0.0;
   g_b_cancelReason[liveBar]=0.0;
   g_b_closeReason[liveBar]=0.0;
   g_b_posDir[liveBar]=0.0;
   g_b_posStage[liveBar]=0.0;
   g_b_posOrderType[liveBar]=0.0;
   g_b_posMode[liveBar]=0.0;
   g_b_posEntry[liveBar]=EMPTY_VALUE;
   g_b_posLimit[liveBar]=EMPTY_VALUE;
   g_b_posSl[liveBar]=EMPTY_VALUE;
   g_b_posTp1[liveBar]=EMPTY_VALUE;
   g_b_posTp2[liveBar]=EMPTY_VALUE;
   g_b_posTp3[liveBar]=EMPTY_VALUE;
   g_b_posRisk[liveBar]=EMPTY_VALUE;
   g_b_posBars[liveBar]=0.0;
   g_b_posBar[liveBar]=-1.0;
   g_b_posMaxFavR[liveBar]=0.0;
   g_b_dayCount[liveBar]=0.0;
   g_b_barsSince[liveBar]=0.0;
   g_b_consecLosses[liveBar]=0.0;
   g_b_trades[liveBar]=0.0;
   g_b_tp1Hits[liveBar]=0.0;
   g_b_netWins[liveBar]=0.0;
   g_b_beSaves[liveBar]=0.0;
   g_b_fullLosses[liveBar]=0.0;
   g_b_timeouts[liveBar]=0.0;
   g_b_decays[liveBar]=0.0;
   g_b_realizedRSum[liveBar]=0.0;
   g_b_candidates[liveBar]=0.0;
   g_b_eligibleN[liveBar]=0.0;
   g_b_pendingN[liveBar]=0.0;
   g_b_filledN[liveBar]=0.0;
   g_b_closedN[liveBar]=0.0;
   g_b_xDir[liveBar]=0.0;
   g_b_xEntry[liveBar]=EMPTY_VALUE;
   g_b_xSl[liveBar]=EMPTY_VALUE;
   g_b_xExit[liveBar]=EMPTY_VALUE;
   g_b_xR[liveBar]=EMPTY_VALUE;
   g_b_xReason[liveBar]=0.0;
   g_b_xBar[liveBar]=-1.0;
   g_b_xStage[liveBar]=0.0;
   g_b_regimeCode[liveBar]=0.0;
   g_b_regimeDir[liveBar]=0.0;
   g_b_regimeAdx[liveBar]=EMPTY_VALUE;
   g_b_regimeBbwPct[liveBar]=50.0;
   g_b_isSqueeze[liveBar]=0.0;
   g_b_bbWidth[liveBar]=EMPTY_VALUE;
   g_b_bbWidthMA[liveBar]=EMPTY_VALUE;
   g_b_bbExpand[liveBar]=0.0;
   g_b_trend[liveBar]=0.0;
   g_b_bosUp[liveBar]=0.0;
   g_b_bosDown[liveBar]=0.0;
   g_b_chochUp[liveBar]=0.0;
   g_b_chochDown[liveBar]=0.0;
   g_b_mssUp[liveBar]=0.0;
   g_b_mssDown[liveBar]=0.0;
   g_b_retestUp[liveBar]=0.0;
   g_b_retestDown[liveBar]=0.0;
   g_b_failUp[liveBar]=0.0;
   g_b_failDown[liveBar]=0.0;
   g_b_contUp[liveBar]=0.0;
   g_b_contDown[liveBar]=0.0;
   g_b_pullUp[liveBar]=0.0;
   g_b_pullDown[liveBar]=0.0;
   g_b_hh[liveBar]=0.0;
   g_b_ll[liveBar]=0.0;
   g_b_eqHi[liveBar]=0.0;
   g_b_eqLo[liveBar]=0.0;
   g_b_swingHi[liveBar]=EMPTY_VALUE;
   g_b_swingLo[liveBar]=EMPTY_VALUE;
   g_b_prevHigh[liveBar]=EMPTY_VALUE;
   g_b_prevLow[liveBar]=EMPTY_VALUE;
   g_b_brkLevel[liveBar]=EMPTY_VALUE;
   g_b_brkDir[liveBar]=0.0;
   g_b_brkBar[liveBar]=-1.0;
   g_b_evtKind[liveBar]=0.0;
   g_b_evtDir[liveBar]=0.0;
   g_b_evtSrcBar[liveBar]=-1.0;
   g_b_evtSrcTime[liveBar]=0.0;
   g_b_evtLevel[liveBar]=EMPTY_VALUE;
   g_b_evtCount[liveBar]=0.0;
   g_b_lastSweepBullBar[liveBar]=-1.0;
   g_b_lastSweepBullPx[liveBar]=EMPTY_VALUE;
   g_b_lastSweepBearBar[liveBar]=-1.0;
   g_b_lastSweepBearPx[liveBar]=EMPTY_VALUE;
   g_b_cpBull[liveBar]=0.0;
   g_b_cpBear[liveBar]=0.0;
   g_b_candleScore[liveBar]=0.0;
   g_b_pinBull[liveBar]=0.0;
   g_b_pinBear[liveBar]=0.0;
   g_b_engBull[liveBar]=0.0;
   g_b_engBear[liveBar]=0.0;
   g_b_dispBull[liveBar]=0.0;
   g_b_dispBear[liveBar]=0.0;
   g_b_rejBull[liveBar]=0.0;
   g_b_rejBear[liveBar]=0.0;
   g_b_isOverext[liveBar]=0.0;
   g_b_extEma[liveBar]=0.0;
   g_b_extCandle[liveBar]=1.0;
   g_b_atr[liveBar]=EMPTY_VALUE;
   g_b_atrPct[liveBar]=0.0;
   g_b_rsi[liveBar]=EMPTY_VALUE;
   g_b_macdHist[liveBar]=EMPTY_VALUE;
   g_b_adx[liveBar]=EMPTY_VALUE;
   g_b_diPlus[liveBar]=EMPTY_VALUE;
   g_b_diMinus[liveBar]=EMPTY_VALUE;
   g_b_emaSlope20[liveBar]=0.0;
   g_b_emaBull[liveBar]=0.0;
   g_b_emaBear[liveBar]=0.0;
   g_b_atrSafe[liveBar]=EMPTY_VALUE;
   g_b_vol[liveBar]=0.0;
   g_b_volMA[liveBar]=EMPTY_VALUE;
   g_b_volRatio[liveBar]=0.0;
   g_b_volBucket[liveBar]=0.0;
   g_b_isTim[liveBar]=0.0;
   g_b_relVol[liveBar]=0.0;
   g_b_obv[liveBar]=0.0;
   g_b_obvSlope[liveBar]=0.0;
   g_b_vwap[liveBar]=EMPTY_VALUE;
   g_b_vwapScore[liveBar]=0.0;
   g_b_pdh[liveBar]=EMPTY_VALUE;
   g_b_pdl[liveBar]=EMPTY_VALUE;
   g_b_pwh[liveBar]=EMPTY_VALUE;
   g_b_pwl[liveBar]=EMPTY_VALUE;
   g_b_dayRange[liveBar]=0.0;
   g_b_sessName[liveBar]=0.0;
   g_b_sessHi[liveBar]=EMPTY_VALUE;
   g_b_sessLo[liveBar]=EMPTY_VALUE;
   g_b_nearSup[liveBar]=0.0;
   g_b_nearRes[liveBar]=0.0;
   g_b_nearFvgBull[liveBar]=0.0;
   g_b_nearFvgBear[liveBar]=0.0;
   g_b_nearObBull[liveBar]=0.0;
   g_b_nearObBear[liveBar]=0.0;
   g_b_srCount[liveBar]=0.0;
   g_b_fvgCount[liveBar]=0.0;
   g_b_obCount[liveBar]=0.0;
   g_b_nearestRes[liveBar]=EMPTY_VALUE;
   g_b_nearestSup[liveBar]=EMPTY_VALUE;
   g_b_fvgBullPx[liveBar]=EMPTY_VALUE;
   g_b_fvgBearPx[liveBar]=EMPTY_VALUE;
   g_b_obBullPx[liveBar]=EMPTY_VALUE;
   g_b_obBearPx[liveBar]=EMPTY_VALUE;
   g_b_mtfCtxDir[liveBar]=0.0;
   g_b_mtfSetupDir[liveBar]=0.0;
   g_b_mtfCtxEma[liveBar]=EMPTY_VALUE;
   g_b_mtfSetupEma[liveBar]=EMPTY_VALUE;
   g_b_mtfBias[liveBar]=0.0;
   g_b_mtfHierOk[liveBar]=0.0;
   g_b_btcDump[liveBar]=0.0;
   g_b_btcPump[liveBar]=0.0;
   g_b_weekendBlock[liveBar]=0.0;
   g_b_modeDir[liveBar]=0.0;
   g_b_activeMode[liveBar]=0.0;
   g_b_modeReady[liveBar]=0.0;
   g_b_modeGateOk[liveBar]=0.0;
   g_b_modeReason[liveBar]=0.0;
   g_b_modeBInvalidLong[liveBar]=0.0;
   g_b_modeBInvalidShort[liveBar]=0.0;
   g_b_modeCBoxOk[liveBar]=0.0;
   g_b_gTrend[liveBar]=EMPTY_VALUE;
   g_b_gStruct[liveBar]=0.0;
   g_b_gLiq[liveBar]=0.0;
   g_b_gLoc[liveBar]=0.0;
   g_b_gSr[liveBar]=0.0;
   g_b_gCandle[liveBar]=0.0;
   g_b_gVolume[liveBar]=EMPTY_VALUE;
   g_b_gMom[liveBar]=EMPTY_VALUE;
   g_b_gSess[liveBar]=0.0;
   g_b_gMtf[liveBar]=0.0;

//--- Engine replay over closed bars only
   TM2EngineState st;
   TM2StateInit(st);
   TM2Bar bar;
   TM2BarOut out;

   const int fromBar=(g_cfg.maxBars>0 ? (int)MathMax(0,lastClosed-g_cfg.maxBars+1) : 0);

   for(int j=fromBar; j<=lastClosed; j++)
     {
      ZeroMemory(bar);
      ZeroMemory(out);

      bar.time=time[j];
      bar.open=open[j];
      bar.high=high[j];
      bar.low=low[j];
      bar.close=close[j];
      bar.vol=tick_volume[j];
      bar.volMA=volMA[j];
      bar.volSma20=volSma[j];
      bar.mintick=point;
      bar.prevOpen=(j>0 ? open[j-1] : EMPTY_VALUE);
      bar.prevClose=(j>0 ? close[j-1] : EMPTY_VALUE);
      bar.prevHigh=(j>0 ? high[j-1] : EMPTY_VALUE);
      bar.prevLow=(j>0 ? low[j-1] : EMPTY_VALUE);
      bar.high2=(j>1 ? high[j-2] : EMPTY_VALUE);
      bar.low2=(j>1 ? low[j-2] : EMPTY_VALUE);
      bar.atr=atr[j];
      bar.atrPct=atrPct[j];
      bar.atrSafe=atrSafe[j];
      bar.emaF=emaF[j];
      bar.emaM=emaM[j];
      bar.emaS=emaS[j];
      bar.rsi=rsi[j];
      bar.macdHist=macdHist[j];
      bar.macdPrevHist=macdPrev[j];
      bar.diPlus=diP[j];
      bar.diMinus=diM[j];
      bar.adx=adx[j];
      bar.slope20=slope20[j];
      bar.bbMid=bbMid[j];
      bar.bbUp=bbUp[j];
      bar.bbLo=bbLo[j];
      bar.bbWidth=bbWidth[j];
      bar.bbWidthMA=bbWidthMA[j];
      bar.bbwPct=bbwPct[j];
      bar.isSqueeze=!TM2IsEmpty(bbwPct[j]) && bbwPct[j]<=g_cfg.bbwSqueezePct;
      bar.bbExpand=!TM2IsEmpty(bbWidth[j]) && !TM2IsEmpty(bbWidthMA[j]) &&
                   bbWidth[j]>bbWidthMA[j];
      bar.pivHOk=pivHOk[j];
      bar.pivLOk=pivLOk[j];
      bar.pivH=pivH[j];
      bar.pivL=pivL[j];
      bar.srPivHOk=srPivHOk[j];
      bar.srPivLOk=srPivLOk[j];
      bar.srPivH=srPivH[j];
      bar.srPivL=srPivL[j];
      bar.ctxEma=(ctxOk[j] ? ctxEma[j] : EMPTY_VALUE);
      bar.setupEma=(setupOk[j] ? setupEma[j] : EMPTY_VALUE);
      bar.ctxOk=ctxOk[j];
      bar.setupOk=setupOk[j];
      bar.ctxDir=(hierOk ? (int)TM2HtfBias(ctxClose[j],ctxEma[j],ctxOk[j]) : 0);
      bar.setupDir=(hierOk ? (int)TM2HtfBias(setupClose[j],setupEma[j],setupOk[j]) : 0);
      bar.mtfHierOk=hierOk;
      bar.sessName=TM2SessionName(TM2LocalMinute(time[j],g_cfg.srvOffsetMin,
                                                 g_cfg.mktOffsetMin));
      bar.pdh=pdh[j];
      bar.pdl=pdl[j];
      bar.pwh=pwh[j];
      bar.pwl=pwl[j];
      bar.hasPd=hasPd[j];
      bar.hasPw=hasPw[j];
      bar.btcClose=btcClose[j];
      bar.btcEma=btcEma[j];
      bar.btcRsi=btcRsi[j];
      bar.btcAtr=btcAtr[j];
      bar.btcOk=btcOk[j];
      bar.btcNeed=btcNeed;
      bar.isCrypto=isCrypto;

      MqlDateTime dt;
      TimeToStruct(time[j],dt);
      bar.isWeekend=(dt.day_of_week==0 || dt.day_of_week==6);
      const double volRatioPre=(!TM2IsEmpty(volMA[j]) && volMA[j]>0.0)
                               ? (double)tick_volume[j]/volMA[j] : 0.0;
      bar.weekendBlocked=TM2WeekendBlocked(g_cfg,isCrypto,bar.isWeekend,
                                           volRatioPre,atrPct[j]);

      const double extEmaPre=TM2ExtEma(close[j],emaF[j],atr[j]);
      const double extCandlePre=TM2ExtCandle(high[j],low[j],atr[j]);
      bar.isOverext=TM2IsOverextended(extEmaPre,extCandlePre,
                                      g_cfg.maxExtAtr,g_cfg.maxCandleAtr);

      TM2EngineStep(g_cfg,st,bar,j,out);

//--- Render buffers
      g_plot_long_entry[j]=(out.evEntry && out.posDir==1 ? low[j] : EMPTY_VALUE);
      g_plot_short_entry[j]=(out.evEntry && out.posDir==-1 ? high[j] : EMPTY_VALUE);
      g_plot_hit_tp[j]=(out.evTp>0 ? high[j] : EMPTY_VALUE);
      g_plot_hit_sl[j]=(out.evSl ? low[j] : EMPTY_VALUE);
      g_plot_active_sl[j]=(out.posDir!=0 && !TM2IsEmpty(out.posSl)
                           ? out.posSl : EMPTY_VALUE);
      g_plot_active_tp1[j]=(out.posDir!=0 && !TM2IsEmpty(out.posTp1)
                            ? out.posTp1 : EMPTY_VALUE);
      g_plot_active_tp2[j]=(out.posDir!=0 && !TM2IsEmpty(out.posTp2)
                            ? out.posTp2 : EMPTY_VALUE);
      g_plot_active_tp3[j]=(out.posDir!=0 && !TM2IsEmpty(out.posTp3)
                            ? out.posTp3 : EMPTY_VALUE);
      g_plot_active_limit[j]=(out.posStage==TM2_STAGE_PENDING && !TM2IsEmpty(out.posLimit)
                              ? out.posLimit : EMPTY_VALUE);
      g_plot_score100[j]=out.score100;

//--- Contract buffers 16..241
      g_b_longScore[j]=out.longScore;
      g_b_shortScore[j]=out.shortScore;
      g_b_score100[j]=out.score100;
      g_b_scoreGap[j]=out.scoreGap;
      g_b_dir[j]=(double)out.dir;
      g_b_directionCode[j]=(double)out.directionCode;
      g_b_quality[j]=(double)out.quality;
      g_b_qualityLevel[j]=(double)out.qualityLevel;
      g_b_minReqLevel[j]=(double)out.minReqLevel;
      g_b_okQuality[j]=(out.okQuality ? 1.0 : 0.0);
      g_b_scoreBlock[j]=(double)out.scoreBlock;
      g_b_ablationCode[j]=(double)out.ablationCode;
      g_b_wDirTotal[j]=out.wDirTotal;
      g_b_longWeighted[j]=out.longWeighted;
      g_b_gateRegime[j]=(out.gateRegime ? 1.0 : 0.0);
      g_b_gateMtf[j]=(out.gateMtf ? 1.0 : 0.0);
      g_b_gateBtc[j]=(out.gateBtc ? 1.0 : 0.0);
      g_b_gateObstacle[j]=(out.gateObstacle ? 1.0 : 0.0);
      g_b_gateOverext[j]=(out.gateOverext ? 1.0 : 0.0);
      g_b_gateCircuit[j]=(out.gateCircuit ? 1.0 : 0.0);
      g_b_gateAll[j]=(out.gateAll ? 1.0 : 0.0);
      g_b_gateTopReason[j]=(double)out.gateTopReason;
      g_b_noTradeReason[j]=(double)out.noTradeReason;
      g_b_okCool[j]=(out.okCool ? 1.0 : 0.0);
      g_b_okDay[j]=(out.okDay ? 1.0 : 0.0);
      g_b_okCircuit[j]=(out.okCircuit ? 1.0 : 0.0);
      g_b_planValid[j]=(out.planValid ? 1.0 : 0.0);
      g_b_planReason[j]=(double)out.planReason;
      g_b_orderType[j]=(double)out.orderType;
      g_b_entry[j]=out.entry;
      g_b_limit[j]=out.limit;
      g_b_sl[j]=out.sl;
      g_b_tp1[j]=out.tp1;
      g_b_tp2[j]=out.tp2;
      g_b_tp3[j]=out.tp3;
      g_b_risk[j]=out.risk;
      g_b_evalRR[j]=out.evalRR;
      g_b_posSize[j]=out.posSize;
      g_b_notional[j]=out.notional;
      g_b_effLev[j]=out.effLev;
      g_b_marginReq[j]=out.marginReq;
      g_b_liqPrice[j]=out.liqPrice;
      g_b_netRR[j]=out.netRR;
      g_b_signal[j]=(out.signal ? 1.0 : 0.0);
      g_b_candidate[j]=(out.candidate ? 1.0 : 0.0);
      g_b_eligible[j]=(out.eligible ? 1.0 : 0.0);
      g_b_evEntry[j]=(out.evEntry ? 1.0 : 0.0);
      g_b_evPending[j]=(out.evPending ? 1.0 : 0.0);
      g_b_evFilled[j]=(out.evFilled ? 1.0 : 0.0);
      g_b_evCancel[j]=(out.evCancel ? 1.0 : 0.0);
      g_b_evTp[j]=(double)out.evTp;
      g_b_evSl[j]=(out.evSl ? 1.0 : 0.0);
      g_b_evBe[j]=(out.evBe ? 1.0 : 0.0);
      g_b_evTrail[j]=(out.evTrail ? 1.0 : 0.0);
      g_b_evTimeout[j]=(out.evTimeout ? 1.0 : 0.0);
      g_b_evDecay[j]=(out.evDecay ? 1.0 : 0.0);
      g_b_evClose[j]=(out.evClose ? 1.0 : 0.0);
      g_b_cancelReason[j]=(double)out.cancelReason;
      g_b_closeReason[j]=(double)out.closeReason;
      g_b_posDir[j]=(double)out.posDir;
      g_b_posStage[j]=(double)out.posStage;
      g_b_posOrderType[j]=(double)out.posOrderType;
      g_b_posMode[j]=(double)out.posMode;
      g_b_posEntry[j]=out.posEntry;
      g_b_posLimit[j]=out.posLimit;
      g_b_posSl[j]=out.posSl;
      g_b_posTp1[j]=out.posTp1;
      g_b_posTp2[j]=out.posTp2;
      g_b_posTp3[j]=out.posTp3;
      g_b_posRisk[j]=out.posRisk;
      g_b_posBars[j]=(double)out.posBars;
      g_b_posBar[j]=(double)out.posBar;
      g_b_posMaxFavR[j]=out.posMaxFavR;
      g_b_dayCount[j]=(double)out.dayCount;
      g_b_barsSince[j]=(double)out.barsSince;
      g_b_consecLosses[j]=(double)out.consecLosses;
      g_b_trades[j]=(double)out.trades;
      g_b_tp1Hits[j]=(double)out.tp1Hits;
      g_b_netWins[j]=(double)out.netWins;
      g_b_beSaves[j]=(double)out.beSaves;
      g_b_fullLosses[j]=(double)out.fullLosses;
      g_b_timeouts[j]=(double)out.timeouts;
      g_b_decays[j]=(double)out.decays;
      g_b_realizedRSum[j]=out.realizedRSum;
      g_b_candidates[j]=(double)out.candidates;
      g_b_eligibleN[j]=(double)out.eligibleN;
      g_b_pendingN[j]=(double)out.pendingN;
      g_b_filledN[j]=(double)out.filledN;
      g_b_closedN[j]=(double)out.closedN;
      g_b_xDir[j]=(double)out.xDir;
      g_b_xEntry[j]=out.xEntry;
      g_b_xSl[j]=out.xSl;
      g_b_xExit[j]=out.xExit;
      g_b_xR[j]=out.xR;
      g_b_xReason[j]=(double)out.xReason;
      g_b_xBar[j]=(double)out.xBar;
      g_b_xStage[j]=(double)out.xStage;
      g_b_regimeCode[j]=(double)out.regimeCode;
      g_b_regimeDir[j]=(double)out.regimeDir;
      g_b_regimeAdx[j]=out.regimeAdx;
      g_b_regimeBbwPct[j]=TM2IsEmpty(out.regimeBbwPct) ? 50.0 : out.regimeBbwPct;
      g_b_isSqueeze[j]=(out.isSqueeze ? 1.0 : 0.0);
      g_b_bbWidth[j]=out.bbWidth;
      g_b_bbWidthMA[j]=out.bbWidthMA;
      g_b_bbExpand[j]=(out.bbExpand ? 1.0 : 0.0);
      g_b_trend[j]=(double)out.trend;
      g_b_bosUp[j]=(out.bosUp ? 1.0 : 0.0);
      g_b_bosDown[j]=(out.bosDown ? 1.0 : 0.0);
      g_b_chochUp[j]=(out.chochUp ? 1.0 : 0.0);
      g_b_chochDown[j]=(out.chochDown ? 1.0 : 0.0);
      g_b_mssUp[j]=(out.mssUp ? 1.0 : 0.0);
      g_b_mssDown[j]=(out.mssDown ? 1.0 : 0.0);
      g_b_retestUp[j]=(out.retestUp ? 1.0 : 0.0);
      g_b_retestDown[j]=(out.retestDown ? 1.0 : 0.0);
      g_b_failUp[j]=(out.failUp ? 1.0 : 0.0);
      g_b_failDown[j]=(out.failDown ? 1.0 : 0.0);
      g_b_contUp[j]=(out.contUp ? 1.0 : 0.0);
      g_b_contDown[j]=(out.contDown ? 1.0 : 0.0);
      g_b_pullUp[j]=(out.pullUp ? 1.0 : 0.0);
      g_b_pullDown[j]=(out.pullDown ? 1.0 : 0.0);
      g_b_hh[j]=(out.hh ? 1.0 : 0.0);
      g_b_ll[j]=(out.ll ? 1.0 : 0.0);
      g_b_eqHi[j]=(out.eqHi ? 1.0 : 0.0);
      g_b_eqLo[j]=(out.eqLo ? 1.0 : 0.0);
      g_b_swingHi[j]=out.swingHi;
      g_b_swingLo[j]=out.swingLo;
      g_b_prevHigh[j]=out.prevHigh;
      g_b_prevLow[j]=out.prevLow;
      g_b_brkLevel[j]=out.brkLevel;
      g_b_brkDir[j]=(double)out.brkDir;
      g_b_brkBar[j]=(double)out.brkBar;
      g_b_evtKind[j]=(double)out.evtKind;
      g_b_evtDir[j]=(double)out.evtDir;
      g_b_evtSrcBar[j]=(double)out.evtSrcBar;
      g_b_evtSrcTime[j]=(double)out.evtSrcTime;
      g_b_evtLevel[j]=out.evtLevel;
      g_b_evtCount[j]=(double)out.evtCount;
      g_b_lastSweepBullBar[j]=(double)out.lastSweepBullBar;
      g_b_lastSweepBullPx[j]=out.lastSweepBullPx;
      g_b_lastSweepBearBar[j]=(double)out.lastSweepBearBar;
      g_b_lastSweepBearPx[j]=out.lastSweepBearPx;
      g_b_cpBull[j]=out.cpBull;
      g_b_cpBear[j]=out.cpBear;
      g_b_candleScore[j]=out.candleScore;
      g_b_pinBull[j]=(out.pinBull ? 1.0 : 0.0);
      g_b_pinBear[j]=(out.pinBear ? 1.0 : 0.0);
      g_b_engBull[j]=(out.engBull ? 1.0 : 0.0);
      g_b_engBear[j]=(out.engBear ? 1.0 : 0.0);
      g_b_dispBull[j]=(out.dispBull ? 1.0 : 0.0);
      g_b_dispBear[j]=(out.dispBear ? 1.0 : 0.0);
      g_b_rejBull[j]=(out.rejBull ? 1.0 : 0.0);
      g_b_rejBear[j]=(out.rejBear ? 1.0 : 0.0);
      g_b_isOverext[j]=(out.isOverext ? 1.0 : 0.0);
      g_b_extEma[j]=out.extEma;
      g_b_extCandle[j]=out.extCandle;
      g_b_atr[j]=out.atr;
      g_b_atrPct[j]=out.atrPct;
      g_b_rsi[j]=out.rsi;
      g_b_macdHist[j]=out.macdHist;
      g_b_adx[j]=out.adx;
      g_b_diPlus[j]=out.diPlus;
      g_b_diMinus[j]=out.diMinus;
      g_b_emaSlope20[j]=out.emaSlope20;
      g_b_emaBull[j]=(out.emaBull ? 1.0 : 0.0);
      g_b_emaBear[j]=(out.emaBear ? 1.0 : 0.0);
      g_b_atrSafe[j]=out.atrSafe;
      g_b_vol[j]=out.vol;
      g_b_volMA[j]=out.volMA;
      g_b_volRatio[j]=out.volRatio;
      g_b_volBucket[j]=(double)out.volBucket;
      g_b_isTim[j]=(out.isTim ? 1.0 : 0.0);
      g_b_relVol[j]=out.relVol;
      g_b_obv[j]=out.obv;
      g_b_obvSlope[j]=out.obvSlope;
      g_b_vwap[j]=out.vwap;
      g_b_vwapScore[j]=out.vwapScore;
      g_b_pdh[j]=out.pdh;
      g_b_pdl[j]=out.pdl;
      g_b_pwh[j]=out.pwh;
      g_b_pwl[j]=out.pwl;
      g_b_dayRange[j]=out.dayRange;
      g_b_sessName[j]=(double)out.sessName;
      g_b_sessHi[j]=out.sessHi;
      g_b_sessLo[j]=out.sessLo;
      g_b_nearSup[j]=(out.nearSup ? 1.0 : 0.0);
      g_b_nearRes[j]=(out.nearRes ? 1.0 : 0.0);
      g_b_nearFvgBull[j]=(out.nearFvgBull ? 1.0 : 0.0);
      g_b_nearFvgBear[j]=(out.nearFvgBear ? 1.0 : 0.0);
      g_b_nearObBull[j]=(out.nearObBull ? 1.0 : 0.0);
      g_b_nearObBear[j]=(out.nearObBear ? 1.0 : 0.0);
      g_b_srCount[j]=(double)out.srCount;
      g_b_fvgCount[j]=(double)out.fvgCount;
      g_b_obCount[j]=(double)out.obCount;
      g_b_nearestRes[j]=out.nearestRes;
      g_b_nearestSup[j]=out.nearestSup;
      g_b_fvgBullPx[j]=out.fvgBullPx;
      g_b_fvgBearPx[j]=out.fvgBearPx;
      g_b_obBullPx[j]=out.obBullPx;
      g_b_obBearPx[j]=out.obBearPx;
      g_b_mtfCtxDir[j]=(double)out.mtfCtxDir;
      g_b_mtfSetupDir[j]=(double)out.mtfSetupDir;
      g_b_mtfCtxEma[j]=out.mtfCtxEma;
      g_b_mtfSetupEma[j]=out.mtfSetupEma;
      g_b_mtfBias[j]=out.mtfBias;
      g_b_mtfHierOk[j]=(out.mtfHierOk ? 1.0 : 0.0);
      g_b_btcDump[j]=(out.btcDump ? 1.0 : 0.0);
      g_b_btcPump[j]=(out.btcPump ? 1.0 : 0.0);
      g_b_weekendBlock[j]=(out.weekendBlock ? 1.0 : 0.0);
      g_b_modeDir[j]=(double)out.modeDir;
      g_b_activeMode[j]=(double)out.activeMode;
      g_b_modeReady[j]=(out.modeReady ? 1.0 : 0.0);
      g_b_modeGateOk[j]=(out.modeGateOk ? 1.0 : 0.0);
      g_b_modeReason[j]=(double)out.modeReason;
      g_b_modeBInvalidLong[j]=(out.modeBInvalidLong ? 1.0 : 0.0);
      g_b_modeBInvalidShort[j]=(out.modeBInvalidShort ? 1.0 : 0.0);
      g_b_modeCBoxOk[j]=(out.modeCBoxOk ? 1.0 : 0.0);
      g_b_gTrend[j]=out.gTrend;
      g_b_gStruct[j]=out.gStruct;
      g_b_gLiq[j]=out.gLiq;
      g_b_gLoc[j]=out.gLoc;
      g_b_gSr[j]=out.gSr;
      g_b_gCandle[j]=out.gCandle;
      g_b_gVolume[j]=out.gVolume;
      g_b_gMom[j]=out.gMom;
      g_b_gSess[j]=out.gSess;
      g_b_gMtf[j]=out.gMtf;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
