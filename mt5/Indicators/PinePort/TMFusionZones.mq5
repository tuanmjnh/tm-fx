//+------------------------------------------------------------------+
//|                                              TMFusionZones.mq5   |
//|      MT5 EA & AI Lab - PinePort of TM Fusion Zones (signal-only) |
//|                                                                  |
//| Custom indicator only. No file I/O, no account access, no order  |
//| functions. Contract: docs/indicators/tm-fusion-zones.md        |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "TM Fusion Zones signal indicator. Confirmed bars only; no trading."
#property indicator_chart_window
#property indicator_buffers 33
#property indicator_plots   10

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1
#property indicator_label1  "Ribbon Fast"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  1
#property indicator_label2  "Ribbon Slow"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_width3  1
#property indicator_label3  "FZ LONG"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  1
#property indicator_label4  "FZ SHORT"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrAqua
#property indicator_width5  1
#property indicator_label5  "TP1"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrGold
#property indicator_width6  1
#property indicator_label6  "TP2"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrSilver
#property indicator_width7  1
#property indicator_label7  "SL"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrRed
#property indicator_style8  STYLE_DOT
#property indicator_width8  1
#property indicator_label8  "Active SL"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrMediumSeaGreen
#property indicator_style9  STYLE_DOT
#property indicator_width9  1
#property indicator_label9  "Active TP1"
#property indicator_type10  DRAW_LINE
#property indicator_color10 clrMediumSeaGreen
#property indicator_style10 STYLE_DOT
#property indicator_width10 1
#property indicator_label10 "Active TP2"

#include "../../Include/PinePort/TMFusionZonesContract.mqh"

input ENUM_FZ_ASSET     InpAssetMode      = FZ_ASSET_AUTO;        // Asset profile
input double            InpCustomVolMult  = 1.0;                  // Custom volatility multiplier
input ENUM_FZ_MA        InpRibbonType     = FZ_MA_EMA;            // Ribbon MA type
input int               InpRibbonFast     = 20;                   // Ribbon fast length
input int               InpRibbonSlow     = 50;                   // Ribbon slow length
input bool              InpRibbonFilter   = true;                 // Require ribbon direction
input int               InpZonePivotLen   = 7;                    // Zone pivot left/right bars
input double            InpZoneWidthAtr   = 0.5;                  // Zone merge width (x ATR)
input int               InpZoneMax        = 10;                   // Max live zones
input int               InpStructPivotLen = 5;                    // Structure pivot left/right bars
input bool              InpSweepOn        = true;                 // Enable swing sweeps
input bool              InpPdOn           = true;                 // Enable PDH/PDL sweeps
input bool              InpSetupPullback  = true;                 // Setup 1: trend pullback
input bool              InpSetupSweep     = true;                 // Setup 2: sweep reversal
input bool              InpSetupRange     = false;                // Setup 3: range reversion
input double            InpPullTol        = 0.4;                  // Ribbon proximity (x ATR)
input int               InpSweepConfBars  = 3;                    // Sweep confirmation window
input bool              InpMtfOn          = true;                 // Enable MTF bias
input ENUM_FZ_HTF       InpMtfTf          = FZ_HTF_H4;            // MTF timeframe
input int               InpMtfLen         = 100;                  // MTF EMA length
input double            InpWTrend         = 25.0;                 // Score weight: trend
input double            InpWZone          = 25.0;                 // Score weight: zone
input double            InpWStruct        = 20.0;                 // Score weight: structure
input double            InpWCandle        = 15.0;                 // Score weight: candle
input double            InpWMtf           = 15.0;                 // Score weight: MTF
input int               InpScrNoTrade     = 49;                   // No-trade score threshold
input int               InpScoreMargin    = 8;                    // Conflict score margin
input ENUM_FZ_SL_MODE   InpSlMode         = FZ_SL_ZONE_SWING;     // SL mode
input ENUM_FZ_TP_MODE   InpTpMode         = FZ_TP_OPPOSING;       // TP mode
input double            InpSlAtrMul       = 1.5;                  // SL ATR multiplier
input double            InpSlPadAtr       = 0.2;                  // Zone SL pad (x ATR)
input double            InpSlMinAtr       = 0.5;                  // Minimum risk (x ATR)
input double            InpSlMaxAtr       = 3.5;                  // Maximum risk (x ATR)
input double            InpRr1            = 1.0;                  // TP1 R multiple
input double            InpRr2            = 2.0;                  // TP2 R multiple
input double            InpRr3            = 3.0;                  // TP3 R multiple
input double            InpRrMin          = 1.5;                  // Minimum TP2 R multiple gate
input bool              InpObstacleGate   = true;                 // Enable opposing-zone gate
input int               InpCoolBars       = 8;                    // Cooldown bars between signals
input int               InpMaxBars        = 0;                    // Debug: replay last N bars (0 = all)

//--- Render buffers 0..9 (plots 0..9)
double g_plot_fast[];
double g_plot_slow[];
double g_plot_long[];
double g_plot_short[];
double g_plot_hit_tp1[];
double g_plot_hit_tp2[];
double g_plot_hit_sl[];
double g_plot_level_sl[];
double g_plot_level_tp1[];
double g_plot_level_tp2[];

//--- Contract buffers 10..32
double g_buf_sig_long[];
double g_buf_sig_short[];
double g_buf_score_long[];
double g_buf_score_short[];
double g_buf_setup_long[];
double g_buf_setup_short[];
double g_buf_entry[];
double g_buf_sl[];
double g_buf_tp1[];
double g_buf_tp2[];
double g_buf_tp3[];
double g_buf_pos_side[];
double g_buf_hit_tp1[];
double g_buf_hit_tp2[];
double g_buf_hit_tp3[];
double g_buf_hit_sl[];
double g_buf_htf_ema[];
double g_buf_atr[];
double g_buf_regime[];
double g_buf_in_demand[];
double g_buf_in_supply[];
double g_buf_block_long[];
double g_buf_block_short[];

FzConfig g_cfg;
int      g_last_rates=-1;

void FzLoadMtfEma(const datetime &time[],const int total,
                  double &emaOut[],bool &validOut[])
  {
   ArrayResize(emaOut,total);
   ArrayInitialize(emaOut,EMPTY_VALUE);
   ArrayResize(validOut,total);
   for(int j=0; j<total; j++)
      validOut[j]=false;
   if(!g_cfg.mtfOn)
      return;

   const ENUM_TIMEFRAMES tf=FzHtfPeriod((int)g_cfg.mtfTf);
   const int htfSeconds=(int)PeriodSeconds(tf);
   MqlRates rates[];
   const int got=CopyRates(_Symbol,tf,0,FZ_HTF_MAX_BARS,rates);
   if(got<=0)
      return;

   datetime htfClose[];
   double htfCloses[];
   ArrayResize(htfClose,got);
   ArrayResize(htfCloses,got);
   for(int k=0; k<got; k++)
     {
      htfClose[k]=rates[k].time+htfSeconds;
      htfCloses[k]=rates[k].close;
     }

   double htfEma[];
   FzBuildMaSeries(htfCloses,got,g_cfg.mtfLen,FZ_MA_EMA,htfEma);

   const int chartSeconds=(int)PeriodSeconds(_Period);
   for(int j=0; j<total; j++)
     {
      const int k=FzMapHtfIndex(htfClose,got,time[j]+chartSeconds);
      if(k<0 || FzIsNa(htfEma[k]))
         continue;
      emaOut[j]=htfEma[k];
      validOut[j]=true;
     }
  }

int OnInit()
  {
   g_cfg.assetMode=InpAssetMode;
   g_cfg.customVolMult=InpCustomVolMult;
   g_cfg.ribbonType=InpRibbonType;
   g_cfg.ribbonFast=InpRibbonFast;
   g_cfg.ribbonSlow=InpRibbonSlow;
   g_cfg.ribbonFilter=InpRibbonFilter;
   g_cfg.zonePivotLen=InpZonePivotLen;
   g_cfg.zoneWidthAtr=InpZoneWidthAtr;
   g_cfg.zoneMax=InpZoneMax;
   g_cfg.structPivotLen=InpStructPivotLen;
   g_cfg.sweepOn=InpSweepOn;
   g_cfg.pdOn=InpPdOn;
   g_cfg.setupPullback=InpSetupPullback;
   g_cfg.setupSweep=InpSetupSweep;
   g_cfg.setupRange=InpSetupRange;
   g_cfg.pullTol=InpPullTol;
   g_cfg.sweepConfBars=InpSweepConfBars;
   g_cfg.mtfOn=InpMtfOn;
   g_cfg.mtfTf=InpMtfTf;
   g_cfg.mtfLen=InpMtfLen;
   g_cfg.wTrend=InpWTrend;
   g_cfg.wZone=InpWZone;
   g_cfg.wStruct=InpWStruct;
   g_cfg.wCandle=InpWCandle;
   g_cfg.wMtf=InpWMtf;
   g_cfg.scrNoTrade=InpScrNoTrade;
   g_cfg.scoreMargin=InpScoreMargin;
   g_cfg.slMode=InpSlMode;
   g_cfg.tpMode=InpTpMode;
   g_cfg.slAtrMul=InpSlAtrMul;
   g_cfg.slPadAtr=InpSlPadAtr;
   g_cfg.slMinAtr=InpSlMinAtr;
   g_cfg.slMaxAtr=InpSlMaxAtr;
   g_cfg.rr1=InpRr1;
   g_cfg.rr2=InpRr2;
   g_cfg.rr3=InpRr3;
   g_cfg.rrMin=InpRrMin;
   g_cfg.obstacleGate=InpObstacleGate;
   g_cfg.coolBars=InpCoolBars;
   g_cfg.maxBars=InpMaxBars;
   FzNormalizeConfig(g_cfg);
   g_cfg.effAsset=FzResolveAsset((int)g_cfg.assetMode,_Symbol);
   g_cfg.assetVolMult=FzAssetVolMult(g_cfg.effAsset,g_cfg.customVolMult);

   SetIndexBuffer(0,g_plot_fast,INDICATOR_DATA);
   SetIndexBuffer(1,g_plot_slow,INDICATOR_DATA);
   SetIndexBuffer(2,g_plot_long,INDICATOR_DATA);
   SetIndexBuffer(3,g_plot_short,INDICATOR_DATA);
   SetIndexBuffer(4,g_plot_hit_tp1,INDICATOR_DATA);
   SetIndexBuffer(5,g_plot_hit_tp2,INDICATOR_DATA);
   SetIndexBuffer(6,g_plot_hit_sl,INDICATOR_DATA);
   SetIndexBuffer(7,g_plot_level_sl,INDICATOR_DATA);
   SetIndexBuffer(8,g_plot_level_tp1,INDICATOR_DATA);
   SetIndexBuffer(9,g_plot_level_tp2,INDICATOR_DATA);

   SetIndexBuffer(FZ_BUF_SIGNAL_LONG,g_buf_sig_long,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_SIGNAL_SHORT,g_buf_sig_short,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_SCORE_LONG,g_buf_score_long,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_SCORE_SHORT,g_buf_score_short,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_SETUP_LONG,g_buf_setup_long,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_SETUP_SHORT,g_buf_setup_short,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_ENTRY,g_buf_entry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_SL,g_buf_sl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_TP1,g_buf_tp1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_TP2,g_buf_tp2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_TP3,g_buf_tp3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_POS_SIDE,g_buf_pos_side,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_HIT_TP1,g_buf_hit_tp1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_HIT_TP2,g_buf_hit_tp2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_HIT_TP3,g_buf_hit_tp3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_HIT_SL,g_buf_hit_sl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_HTF_EMA,g_buf_htf_ema,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_ATR,g_buf_atr,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_REGIME,g_buf_regime,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_IN_DEMAND,g_buf_in_demand,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_IN_SUPPLY,g_buf_in_supply,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_BLOCK_LONG,g_buf_block_long,INDICATOR_CALCULATIONS);
   SetIndexBuffer(FZ_BUF_BLOCK_SHORT,g_buf_block_short,INDICATOR_CALCULATIONS);

   for(int plot=0; plot<FZ_PLOT_BUFFERS; plot++)
      PlotIndexSetDouble(plot,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetInteger(2,PLOT_ARROW,233);
   PlotIndexSetInteger(3,PLOT_ARROW,234);
   PlotIndexSetInteger(4,PLOT_ARROW,159);
   PlotIndexSetInteger(5,PLOT_ARROW,159);
   PlotIndexSetInteger(6,PLOT_ARROW,251);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("TM Fusion Zones v%s",FZ_CONTRACT_VERSION));
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);

   PrintFormat("TMFZ|INFO|init|asset=%d mult=%.2f mode=%s rb=%d/%d/%d zn=%d/%.2f/%d ms=%d mtf=%d/%d/%d hash=%s",
               g_cfg.effAsset,g_cfg.assetVolMult,EnumToString(g_cfg.assetMode),
               (int)g_cfg.ribbonType,g_cfg.ribbonFast,g_cfg.ribbonSlow,
               g_cfg.zonePivotLen,g_cfg.zoneWidthAtr,g_cfg.zoneMax,
               g_cfg.structPivotLen,
               (int)g_cfg.mtfOn,(int)g_cfg.mtfTf,g_cfg.mtfLen,
               FzConfigHash(g_cfg));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   PrintFormat("TMFZ|INFO|deinit|reason=%d",reason);
  }

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

//--- Replay the whole closed history once per new bar so Pine `var` state is
//--- rebuilt deterministically (no state carried across calls).
   if(prev_calculated==rates_total && rates_total==g_last_rates)
      return(rates_total);
   g_last_rates=rates_total;

   const int total=rates_total;
   const int lastClosed=total-2;
   const double tickSize=_Point;

   double atrRaw[],adx[],chop[];
   FzBuildAtrSeries(high,low,close,total,14,atrRaw);
   FzBuildAdxSeries(high,low,close,total,14,adx);
   FzBuildChopSeries(high,low,close,total,14,chop);

   double atrSafe[];
   ArrayResize(atrSafe,total);
   for(int j=0; j<total; j++)
      atrSafe[j]=FzAtrSafe(atrRaw[j],tickSize);

   double maFast[],maSlow[];
   FzBuildMaSeries(close,total,g_cfg.ribbonFast,(int)g_cfg.ribbonType,maFast);
   FzBuildMaSeries(close,total,g_cfg.ribbonSlow,(int)g_cfg.ribbonType,maSlow);

   double htfEma[];
   bool htfValid[];
   FzLoadMtfEma(time,total,htfEma,htfValid);

//--- Defaults for every bar; the engine overwrites closed bars below.
   for(int j=0; j<total; j++)
     {
      g_plot_fast[j]=maFast[j];
      g_plot_slow[j]=maSlow[j];
      g_plot_long[j]=EMPTY_VALUE;
      g_plot_short[j]=EMPTY_VALUE;
      g_plot_hit_tp1[j]=EMPTY_VALUE;
      g_plot_hit_tp2[j]=EMPTY_VALUE;
      g_plot_hit_sl[j]=EMPTY_VALUE;
      g_plot_level_sl[j]=EMPTY_VALUE;
      g_plot_level_tp1[j]=EMPTY_VALUE;
      g_plot_level_tp2[j]=EMPTY_VALUE;

      g_buf_sig_long[j]=0.0;
      g_buf_sig_short[j]=0.0;
      g_buf_score_long[j]=0.0;
      g_buf_score_short[j]=0.0;
      g_buf_setup_long[j]=(double)FZ_SETUP_NONE;
      g_buf_setup_short[j]=(double)FZ_SETUP_NONE;
      g_buf_entry[j]=EMPTY_VALUE;
      g_buf_sl[j]=EMPTY_VALUE;
      g_buf_tp1[j]=EMPTY_VALUE;
      g_buf_tp2[j]=EMPTY_VALUE;
      g_buf_tp3[j]=EMPTY_VALUE;
      g_buf_pos_side[j]=0.0;
      g_buf_hit_tp1[j]=0.0;
      g_buf_hit_tp2[j]=0.0;
      g_buf_hit_tp3[j]=0.0;
      g_buf_hit_sl[j]=0.0;
      g_buf_htf_ema[j]=htfEma[j];
      g_buf_atr[j]=atrSafe[j];
      g_buf_regime[j]=(double)FZ_REGIME_TRANSITIONAL;
      g_buf_in_demand[j]=0.0;
      g_buf_in_supply[j]=0.0;
      g_buf_block_long[j]=(double)FZ_BLOCK_NONE;
      g_buf_block_short[j]=(double)FZ_BLOCK_NONE;
     }

//--- Engine replay on closed bars only.
   int fromBar=0;
   if(g_cfg.maxBars>0)
      fromBar=MathMax(0,lastClosed-g_cfg.maxBars+1);

   FzEngineState st;
   FzStateInit(st);
   FzBar bar;
   FzBarOut out;
   for(int j=fromBar; j<=lastClosed; j++)
     {
      bar.time=time[j];
      bar.open=open[j];
      bar.high=high[j];
      bar.low=low[j];
      bar.close=close[j];
      bar.tickSize=tickSize;
      bar.atr=atrSafe[j];
      bar.regime=FzRegime(adx[j],chop[j]);
      bar.maFast=maFast[j];
      bar.maSlow=maSlow[j];
      bar.htfEma=htfEma[j];
      bar.htfValid=htfValid[j];

      double pivotValue=EMPTY_VALUE;
      bar.znPhValid=FzPivotHighAt(high,total,j,g_cfg.zonePivotLen,pivotValue);
      bar.znPh=pivotValue;
      bar.znPlValid=FzPivotLowAt(low,total,j,g_cfg.zonePivotLen,pivotValue);
      bar.znPl=pivotValue;
      bar.msPhValid=FzPivotHighAt(high,total,j,g_cfg.structPivotLen,pivotValue);
      bar.msPh=pivotValue;
      bar.msPlValid=FzPivotLowAt(low,total,j,g_cfg.structPivotLen,pivotValue);
      bar.msPl=pivotValue;

      FzEngineStep(g_cfg,st,bar,j,out);

      g_plot_long[j]=(out.signalLong ? low[j] : EMPTY_VALUE);
      g_plot_short[j]=(out.signalShort ? high[j] : EMPTY_VALUE);
      g_plot_hit_tp1[j]=(out.hitTp1 ? high[j] : EMPTY_VALUE);
      g_plot_hit_tp2[j]=(out.hitTp2 ? high[j] : EMPTY_VALUE);
      g_plot_hit_sl[j]=(out.hitSl ? low[j] : EMPTY_VALUE);
      g_plot_level_sl[j]=(out.posSide!=0 && !FzIsNa(out.sl) ? out.sl : EMPTY_VALUE);
      g_plot_level_tp1[j]=(out.posSide!=0 && !FzIsNa(out.tp1) ? out.tp1 : EMPTY_VALUE);
      g_plot_level_tp2[j]=(out.posSide!=0 && !FzIsNa(out.tp2) ? out.tp2 : EMPTY_VALUE);

      g_buf_sig_long[j]=(out.signalLong ? 1.0 : 0.0);
      g_buf_sig_short[j]=(out.signalShort ? 1.0 : 0.0);
      g_buf_score_long[j]=out.scoreLong;
      g_buf_score_short[j]=out.scoreShort;
      g_buf_setup_long[j]=(double)out.setupLong;
      g_buf_setup_short[j]=(double)out.setupShort;
      g_buf_entry[j]=out.entry;
      g_buf_sl[j]=out.sl;
      g_buf_tp1[j]=out.tp1;
      g_buf_tp2[j]=out.tp2;
      g_buf_tp3[j]=out.tp3;
      g_buf_pos_side[j]=(double)out.posSide;
      g_buf_hit_tp1[j]=(out.hitTp1 ? 1.0 : 0.0);
      g_buf_hit_tp2[j]=(out.hitTp2 ? 1.0 : 0.0);
      g_buf_hit_tp3[j]=(out.hitTp3 ? 1.0 : 0.0);
      g_buf_hit_sl[j]=(out.hitSl ? 1.0 : 0.0);
      g_buf_htf_ema[j]=out.htfEma;
      g_buf_atr[j]=out.atr;
      g_buf_regime[j]=(double)out.regime;
      g_buf_in_demand[j]=(out.inDemand ? 1.0 : 0.0);
      g_buf_in_supply[j]=(out.inSupply ? 1.0 : 0.0);
      g_buf_block_long[j]=(double)out.blockLong;
      g_buf_block_short[j]=(double)out.blockShort;
     }

   return(rates_total);
  }
