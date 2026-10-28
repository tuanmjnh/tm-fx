//+------------------------------------------------------------------+
//|                                            TMXAUSignals2.mq5     |
//|   MT5 EA & AI Lab - PinePort of TM XAU Signals 2 (signal only)   |
//|                                                                  |
//| Custom indicator only. No file I/O, no account access, no order  |
//| functions. Contract: docs/indicators/tm-xau-signals-2.md        |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "TM XAU Signals 2 signal indicator. Confirmed bars only; no trading."
#property indicator_chart_window
#property indicator_buffers 153
#property indicator_plots   13

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
#property indicator_width7  2
#property indicator_label7  "X2 LONG"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrRed
#property indicator_width8  2
#property indicator_label8  "X2 SHORT"
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

#include "../../Include/PinePort/TMXAUSignals2Contract.mqh"

input int               InpSrvOffsetMin      = 180;              // Server to UTC offset (minutes)
input int               InpMktOffsetMin      = -300;             // UTC to market offset (minutes)
input int               InpVolSessOffsetMin  = 420;              // UTC to volume-session offset (minutes)
input int               InpVolSessStartMin   = 480;              // Volume session start (minute of day)
input int               InpVolSessEndMin     = 960;              // Volume session end (minute of day)
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

//--- Render buffers 0..12 (plots 0..12)
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
double g_plot_active_tp2[];

//--- Contract buffers 13..152
double g_b_score100[];
double g_b_dir[];
double g_b_quality[];
double g_b_raw_score[];
double g_b_g_trend[];
double g_b_g_struct[];
double g_b_g_liq[];
double g_b_g_loc[];
double g_b_g_sr[];
double g_b_g_candle[];
double g_b_g_volume[];
double g_b_g_vol[];
double g_b_g_mom[];
double g_b_g_sess[];
double g_b_g_mtf[];
double g_b_plan_valid[];
double g_b_entry[];
double g_b_sl[];
double g_b_tp1[];
double g_b_tp2[];
double g_b_tp3[];
double g_b_risk[];
double g_b_sig[];
double g_b_block[];
double g_b_ev_entry[];
double g_b_ev_tp[];
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
double g_b_pos_bar[];
double g_b_day_count[];
double g_b_bars_since[];
double g_b_trades[];
double g_b_wins[];
double g_b_losses[];
double g_b_x_entry[];
double g_b_x_sl[];
double g_b_x_dir[];
double g_b_x_bar[];
double g_b_x_exit[];
double g_b_x_r[];
double g_b_trend[];
double g_b_bos_up[];
double g_b_bos_down[];
double g_b_choch_up[];
double g_b_choch_down[];
double g_b_mss_up[];
double g_b_mss_down[];
double g_b_retest_up[];
double g_b_retest_down[];
double g_b_fail_up[];
double g_b_fail_down[];
double g_b_sweep_up[];
double g_b_sweep_down[];
double g_b_hh[];
double g_b_hl[];
double g_b_lh[];
double g_b_ll[];
double g_b_cont_up[];
double g_b_cont_down[];
double g_b_pull_up[];
double g_b_pull_down[];
double g_b_eq_hi[];
double g_b_eq_lo[];
double g_b_brk_level[];
double g_b_brk_dir[];
double g_b_cp_bull[];
double g_b_cp_bear[];
double g_b_candle_score[];
double g_b_pin_bull[];
double g_b_pin_bear[];
double g_b_eng_bull[];
double g_b_eng_bear[];
double g_b_disp_bull[];
double g_b_disp_bear[];
double g_b_disp_bull_v[];
double g_b_disp_bear_v[];
double g_b_rej_bull[];
double g_b_rej_bear[];
double g_b_atr[];
double g_b_atr_pct[];
double g_b_atr_ma[];
double g_b_atr_regime[];
double g_b_rsi[];
double g_b_macd_hist[];
double g_b_adx[];
double g_b_di_plus[];
double g_b_di_minus[];
double g_b_bb_width[];
double g_b_bb_width_ma[];
double g_b_bb_expand[];
double g_b_vol_ratio[];
double g_b_vol_bucket[];
double g_b_is_tim[];
double g_b_rel_vol[];
double g_b_obv_slope[];
double g_b_vwap[];
double g_b_pdh[];
double g_b_pdl[];
double g_b_pwh[];
double g_b_pwl[];
double g_b_day_range[];
double g_b_location_score[];
double g_b_volume_score[];
double g_b_mom_score[];
double g_b_trend_score[];
double g_b_sess_score[];
double g_b_sess_name[];
double g_b_sess_hi[];
double g_b_sess_lo[];
double g_b_mtf_ctx_dir[];
double g_b_mtf_setup_dir[];
double g_b_ok_setup[];
double g_b_htf_veto[];
double g_b_swing_lo[];
double g_b_swing_hi[];
double g_b_last_high[];
double g_b_last_low[];
double g_b_near_support[];
double g_b_near_resistance[];
double g_b_near_fvg_bull[];
double g_b_near_fvg_bear[];
double g_b_sr_count[];
double g_b_fvg_count[];
double g_b_ob_count[];
double g_b_evt_kind[];
double g_b_evt_dir[];
double g_b_evt_src_bar[];
double g_b_evt_src_time[];
double g_b_evt_level[];
double g_b_evt_count[];

X2Config g_cfg;
int      g_last_rates=-1;

//+------------------------------------------------------------------+
//| Higher-timeframe EMA mapped onto closed HTF bars (Pine [1])      |
//+------------------------------------------------------------------+
void X2LoadHtfEma(const ENUM_TIMEFRAMES tf,const int len,const int total,
                  const datetime &time[],double &emaOut[],bool &validOut[])
  {
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
   double htfCloses[];
   ArrayResize(htfClose,got);
   ArrayResize(htfCloses,got);
   for(int k=0; k<got; k++)
     {
      const int src=(descending ? got-1-k : k);
      htfClose[k]=rates[src].time+htfSeconds;
      htfCloses[k]=rates[src].close;
     }

   double htfEma[];
   X2BuildEma(htfCloses,got,len,htfEma);

   for(int j=0; j<total; j++)
     {
      const int k=X2MapHtfIndex(htfClose,got,time[j]);
      if(k<0 || X2IsEmpty(htfEma[k]))
         continue;
      emaOut[j]=htfEma[k];
      validOut[j]=true;
     }
  }

//+------------------------------------------------------------------+
//| Previous completed server day/week highs and lows (Pine [1])     |
//+------------------------------------------------------------------+
void X2BuildPrevPeriod(const double &high[],const double &low[],
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
      const long day=X2DayIndex(time[j]);
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

      const long week=X2WeekIndex(time[j]);
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

      if(!X2IsEmpty(prevDayHi))
        {
         pdh[j]=prevDayHi;
         pdl[j]=prevDayLo;
         hasPd[j]=true;
        }
      if(!X2IsEmpty(prevWeekHi))
        {
         pwh[j]=prevWeekHi;
         pwl[j]=prevWeekLo;
         hasPw[j]=true;
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
   X2NormalizeConfig(g_cfg);

//--- Bind buffers 0..152 (contract order)
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
   SetIndexBuffer(12,g_plot_active_tp2,INDICATOR_DATA);
   SetIndexBuffer(13,g_b_score100,INDICATOR_CALCULATIONS);
   SetIndexBuffer(14,g_b_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(15,g_b_quality,INDICATOR_CALCULATIONS);
   SetIndexBuffer(16,g_b_raw_score,INDICATOR_CALCULATIONS);
   SetIndexBuffer(17,g_b_g_trend,INDICATOR_CALCULATIONS);
   SetIndexBuffer(18,g_b_g_struct,INDICATOR_CALCULATIONS);
   SetIndexBuffer(19,g_b_g_liq,INDICATOR_CALCULATIONS);
   SetIndexBuffer(20,g_b_g_loc,INDICATOR_CALCULATIONS);
   SetIndexBuffer(21,g_b_g_sr,INDICATOR_CALCULATIONS);
   SetIndexBuffer(22,g_b_g_candle,INDICATOR_CALCULATIONS);
   SetIndexBuffer(23,g_b_g_volume,INDICATOR_CALCULATIONS);
   SetIndexBuffer(24,g_b_g_vol,INDICATOR_CALCULATIONS);
   SetIndexBuffer(25,g_b_g_mom,INDICATOR_CALCULATIONS);
   SetIndexBuffer(26,g_b_g_sess,INDICATOR_CALCULATIONS);
   SetIndexBuffer(27,g_b_g_mtf,INDICATOR_CALCULATIONS);
   SetIndexBuffer(28,g_b_plan_valid,INDICATOR_CALCULATIONS);
   SetIndexBuffer(29,g_b_entry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(30,g_b_sl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(31,g_b_tp1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(32,g_b_tp2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(33,g_b_tp3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(34,g_b_risk,INDICATOR_CALCULATIONS);
   SetIndexBuffer(35,g_b_sig,INDICATOR_CALCULATIONS);
   SetIndexBuffer(36,g_b_block,INDICATOR_CALCULATIONS);
   SetIndexBuffer(37,g_b_ev_entry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(38,g_b_ev_tp,INDICATOR_CALCULATIONS);
   SetIndexBuffer(39,g_b_ev_sl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(40,g_b_ev_close,INDICATOR_CALCULATIONS);
   SetIndexBuffer(41,g_b_close_reason,INDICATOR_CALCULATIONS);
   SetIndexBuffer(42,g_b_pos_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(43,g_b_pos_entry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(44,g_b_pos_sl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(45,g_b_pos_tp1,INDICATOR_CALCULATIONS);
   SetIndexBuffer(46,g_b_pos_tp2,INDICATOR_CALCULATIONS);
   SetIndexBuffer(47,g_b_pos_tp3,INDICATOR_CALCULATIONS);
   SetIndexBuffer(48,g_b_pos_risk,INDICATOR_CALCULATIONS);
   SetIndexBuffer(49,g_b_pos_stage,INDICATOR_CALCULATIONS);
   SetIndexBuffer(50,g_b_pos_bars,INDICATOR_CALCULATIONS);
   SetIndexBuffer(51,g_b_pos_bar,INDICATOR_CALCULATIONS);
   SetIndexBuffer(52,g_b_day_count,INDICATOR_CALCULATIONS);
   SetIndexBuffer(53,g_b_bars_since,INDICATOR_CALCULATIONS);
   SetIndexBuffer(54,g_b_trades,INDICATOR_CALCULATIONS);
   SetIndexBuffer(55,g_b_wins,INDICATOR_CALCULATIONS);
   SetIndexBuffer(56,g_b_losses,INDICATOR_CALCULATIONS);
   SetIndexBuffer(57,g_b_x_entry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(58,g_b_x_sl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(59,g_b_x_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(60,g_b_x_bar,INDICATOR_CALCULATIONS);
   SetIndexBuffer(61,g_b_x_exit,INDICATOR_CALCULATIONS);
   SetIndexBuffer(62,g_b_x_r,INDICATOR_CALCULATIONS);
   SetIndexBuffer(63,g_b_trend,INDICATOR_CALCULATIONS);
   SetIndexBuffer(64,g_b_bos_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(65,g_b_bos_down,INDICATOR_CALCULATIONS);
   SetIndexBuffer(66,g_b_choch_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(67,g_b_choch_down,INDICATOR_CALCULATIONS);
   SetIndexBuffer(68,g_b_mss_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(69,g_b_mss_down,INDICATOR_CALCULATIONS);
   SetIndexBuffer(70,g_b_retest_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(71,g_b_retest_down,INDICATOR_CALCULATIONS);
   SetIndexBuffer(72,g_b_fail_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(73,g_b_fail_down,INDICATOR_CALCULATIONS);
   SetIndexBuffer(74,g_b_sweep_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(75,g_b_sweep_down,INDICATOR_CALCULATIONS);
   SetIndexBuffer(76,g_b_hh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(77,g_b_hl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(78,g_b_lh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(79,g_b_ll,INDICATOR_CALCULATIONS);
   SetIndexBuffer(80,g_b_cont_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(81,g_b_cont_down,INDICATOR_CALCULATIONS);
   SetIndexBuffer(82,g_b_pull_up,INDICATOR_CALCULATIONS);
   SetIndexBuffer(83,g_b_pull_down,INDICATOR_CALCULATIONS);
   SetIndexBuffer(84,g_b_eq_hi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(85,g_b_eq_lo,INDICATOR_CALCULATIONS);
   SetIndexBuffer(86,g_b_brk_level,INDICATOR_CALCULATIONS);
   SetIndexBuffer(87,g_b_brk_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(88,g_b_cp_bull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(89,g_b_cp_bear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(90,g_b_candle_score,INDICATOR_CALCULATIONS);
   SetIndexBuffer(91,g_b_pin_bull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(92,g_b_pin_bear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(93,g_b_eng_bull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(94,g_b_eng_bear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(95,g_b_disp_bull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(96,g_b_disp_bear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(97,g_b_disp_bull_v,INDICATOR_CALCULATIONS);
   SetIndexBuffer(98,g_b_disp_bear_v,INDICATOR_CALCULATIONS);
   SetIndexBuffer(99,g_b_rej_bull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(100,g_b_rej_bear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(101,g_b_atr,INDICATOR_CALCULATIONS);
   SetIndexBuffer(102,g_b_atr_pct,INDICATOR_CALCULATIONS);
   SetIndexBuffer(103,g_b_atr_ma,INDICATOR_CALCULATIONS);
   SetIndexBuffer(104,g_b_atr_regime,INDICATOR_CALCULATIONS);
   SetIndexBuffer(105,g_b_rsi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(106,g_b_macd_hist,INDICATOR_CALCULATIONS);
   SetIndexBuffer(107,g_b_adx,INDICATOR_CALCULATIONS);
   SetIndexBuffer(108,g_b_di_plus,INDICATOR_CALCULATIONS);
   SetIndexBuffer(109,g_b_di_minus,INDICATOR_CALCULATIONS);
   SetIndexBuffer(110,g_b_bb_width,INDICATOR_CALCULATIONS);
   SetIndexBuffer(111,g_b_bb_width_ma,INDICATOR_CALCULATIONS);
   SetIndexBuffer(112,g_b_bb_expand,INDICATOR_CALCULATIONS);
   SetIndexBuffer(113,g_b_vol_ratio,INDICATOR_CALCULATIONS);
   SetIndexBuffer(114,g_b_vol_bucket,INDICATOR_CALCULATIONS);
   SetIndexBuffer(115,g_b_is_tim,INDICATOR_CALCULATIONS);
   SetIndexBuffer(116,g_b_rel_vol,INDICATOR_CALCULATIONS);
   SetIndexBuffer(117,g_b_obv_slope,INDICATOR_CALCULATIONS);
   SetIndexBuffer(118,g_b_vwap,INDICATOR_CALCULATIONS);
   SetIndexBuffer(119,g_b_pdh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(120,g_b_pdl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(121,g_b_pwh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(122,g_b_pwl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(123,g_b_day_range,INDICATOR_CALCULATIONS);
   SetIndexBuffer(124,g_b_location_score,INDICATOR_CALCULATIONS);
   SetIndexBuffer(125,g_b_volume_score,INDICATOR_CALCULATIONS);
   SetIndexBuffer(126,g_b_mom_score,INDICATOR_CALCULATIONS);
   SetIndexBuffer(127,g_b_trend_score,INDICATOR_CALCULATIONS);
   SetIndexBuffer(128,g_b_sess_score,INDICATOR_CALCULATIONS);
   SetIndexBuffer(129,g_b_sess_name,INDICATOR_CALCULATIONS);
   SetIndexBuffer(130,g_b_sess_hi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(131,g_b_sess_lo,INDICATOR_CALCULATIONS);
   SetIndexBuffer(132,g_b_mtf_ctx_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(133,g_b_mtf_setup_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(134,g_b_ok_setup,INDICATOR_CALCULATIONS);
   SetIndexBuffer(135,g_b_htf_veto,INDICATOR_CALCULATIONS);
   SetIndexBuffer(136,g_b_swing_lo,INDICATOR_CALCULATIONS);
   SetIndexBuffer(137,g_b_swing_hi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(138,g_b_last_high,INDICATOR_CALCULATIONS);
   SetIndexBuffer(139,g_b_last_low,INDICATOR_CALCULATIONS);
   SetIndexBuffer(140,g_b_near_support,INDICATOR_CALCULATIONS);
   SetIndexBuffer(141,g_b_near_resistance,INDICATOR_CALCULATIONS);
   SetIndexBuffer(142,g_b_near_fvg_bull,INDICATOR_CALCULATIONS);
   SetIndexBuffer(143,g_b_near_fvg_bear,INDICATOR_CALCULATIONS);
   SetIndexBuffer(144,g_b_sr_count,INDICATOR_CALCULATIONS);
   SetIndexBuffer(145,g_b_fvg_count,INDICATOR_CALCULATIONS);
   SetIndexBuffer(146,g_b_ob_count,INDICATOR_CALCULATIONS);
   SetIndexBuffer(147,g_b_evt_kind,INDICATOR_CALCULATIONS);
   SetIndexBuffer(148,g_b_evt_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(149,g_b_evt_src_bar,INDICATOR_CALCULATIONS);
   SetIndexBuffer(150,g_b_evt_src_time,INDICATOR_CALCULATIONS);
   SetIndexBuffer(151,g_b_evt_level,INDICATOR_CALCULATIONS);
   SetIndexBuffer(152,g_b_evt_count,INDICATOR_CALCULATIONS);

//--- Plot appearance
   PlotIndexSetInteger(6,PLOT_ARROW,233);
   PlotIndexSetInteger(7,PLOT_ARROW,234);
   PlotIndexSetInteger(8,PLOT_ARROW,159);
   PlotIndexSetInteger(9,PLOT_ARROW,251);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   IndicatorSetString(INDICATOR_SHORTNAME,"TM XAU Signals 2 (PinePort)");

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
   const double tickSize=_Point;

   double volD[];
   ArrayResize(volD,total);
   for(int j=0; j<total; j++)
      volD[j]=(double)tick_volume[j];

//--- Pass 1: indicator series
   double atr[],atrMA[],volMA[],volSma[],emaF[],emaM[],emaS[];
   X2BuildAtr(high,low,close,total,g_cfg.atrLen,atr);
   X2BuildRma(volD,total,g_cfg.volMaLen,volMA);
   X2BuildSma(volD,total,g_cfg.rvLen,volSma);
   X2BuildEma(close,total,g_cfg.emaFast,emaF);
   X2BuildEma(close,total,g_cfg.emaMid,emaM);
   X2BuildEma(close,total,g_cfg.emaSlow,emaS);
   X2BuildSma(atr,total,20,atrMA);

   double rsi[],macdHist[],diPlus[],diMinus[],adx[];
   X2BuildRsi(close,total,g_cfg.rsiLen,rsi);
   X2BuildMacdHist(close,total,g_cfg.macdFast,g_cfg.macdSlow,
                   g_cfg.macdSignal,macdHist);
   X2BuildDmi(high,low,close,total,g_cfg.dmiLen,g_cfg.dmiSmooth,
              diPlus,diMinus,adx);

   double bbMid[],bbUp[],bbLo[],bbWidth[],bbWidthMA[];
   X2BuildBb(close,total,g_cfg.bbLen,g_cfg.bbMult,bbMid,bbUp,bbLo);
   ArrayResize(bbWidth,total);
   ArrayInitialize(bbWidth,EMPTY_VALUE);
   for(int j=0; j<total; j++)
     {
      if(!X2IsEmpty(bbMid[j]) && !X2IsEmpty(bbUp[j]) && !X2IsEmpty(bbLo[j])
         && bbMid[j]!=0.0)
         bbWidth[j]=(bbUp[j]-bbLo[j])/bbMid[j]*100.0;
     }
   X2BuildSma(bbWidth,total,g_cfg.bbLen,bbWidthMA);

   double vwap[];
   X2BuildVwap(close,tick_volume,time,total,vwap);

//--- Swing range for SL (slSwing, independent of structure pivots)
   double swingLo[],swingHi[];
   ArrayResize(swingLo,total);
   ArrayResize(swingHi,total);
   for(int j=0; j<total; j++)
     {
      swingLo[j]=X2RollingMin(low,total,j,g_cfg.slSwing);
      swingHi[j]=X2RollingMax(high,total,j,g_cfg.slSwing);
     }

//--- Structure pivots (swingLen) and S/R pivots (srLeft/srRight)
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
      pivHOk[j]=X2PivotHighAt(high,total,j,g_cfg.swingLen,g_cfg.swingLen,value);
      pivH[j]=value;
      value=EMPTY_VALUE;
      pivLOk[j]=X2PivotLowAt(low,total,j,g_cfg.swingLen,g_cfg.swingLen,value);
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
      srPivHOk[j]=X2PivotHighAt(high,total,j,g_cfg.srLeft,g_cfg.srRight,value);
      srPivH[j]=value;
      value=EMPTY_VALUE;
      srPivLOk[j]=X2PivotLowAt(low,total,j,g_cfg.srLeft,g_cfg.srRight,value);
      srPivL[j]=value;
     }

//--- HTF EMAs (Pine request.security expr[1], lookahead_on)
   double htfCtx[],htfSetup[];
   bool htfCtxOk[],htfSetupOk[];
   X2LoadHtfEma(g_cfg.ctxTf,g_cfg.ctxLen,total,time,htfCtx,htfCtxOk);
   X2LoadHtfEma(g_cfg.setupTf,g_cfg.setupLen,total,time,htfSetup,htfSetupOk);

//--- Previous completed server day/week levels
   double pdh[],pdl[],pwh[],pwl[];
   bool hasPd[],hasPw[];
   X2BuildPrevPeriod(high,low,time,total,pdh,pdl,hasPd,pwh,pwl,hasPw);

//--- Session name (market time) and volume-session window
   int sessName[];
   bool volSessOk[];
   ArrayResize(sessName,total);
   ArrayResize(volSessOk,total);
   for(int j=0; j<total; j++)
     {
      const int minute=X2LocalMinute(time[j],g_cfg.srvOffsetMin,g_cfg.mktOffsetMin);
      sessName[j]=X2SessionName(minute);
      const int volMinute=X2LocalMinute(time[j],g_cfg.srvOffsetMin,
                                        g_cfg.volSessOffsetMin);
      volSessOk[j]=(!g_cfg.volSessOn
                    || X2InWindow(volMinute,g_cfg.volSessStartMin,
                                  g_cfg.volSessEndMin));
     }

//--- Defaults for every bar; the live bar (rates_total-1) stays 0/EMPTY.
   for(int j=0; j<total; j++)
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
      g_plot_active_tp2[j]=EMPTY_VALUE;

      g_b_score100[j]=0.0;
      g_b_dir[j]=0.0;
      g_b_quality[j]=0.0;
      g_b_raw_score[j]=0.0;
      g_b_g_trend[j]=0.0;
      g_b_g_struct[j]=0.0;
      g_b_g_liq[j]=0.0;
      g_b_g_loc[j]=0.0;
      g_b_g_sr[j]=0.0;
      g_b_g_candle[j]=0.0;
      g_b_g_volume[j]=0.0;
      g_b_g_vol[j]=0.0;
      g_b_g_mom[j]=0.0;
      g_b_g_sess[j]=0.0;
      g_b_g_mtf[j]=0.0;
      g_b_plan_valid[j]=0.0;
      g_b_entry[j]=EMPTY_VALUE;
      g_b_sl[j]=EMPTY_VALUE;
      g_b_tp1[j]=EMPTY_VALUE;
      g_b_tp2[j]=EMPTY_VALUE;
      g_b_tp3[j]=EMPTY_VALUE;
      g_b_risk[j]=EMPTY_VALUE;
      g_b_sig[j]=0.0;
      g_b_block[j]=0.0;
      g_b_ev_entry[j]=0.0;
      g_b_ev_tp[j]=0.0;
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
      g_b_pos_bar[j]=-1.0;
      g_b_day_count[j]=0.0;
      g_b_bars_since[j]=0.0;
      g_b_trades[j]=0.0;
      g_b_wins[j]=0.0;
      g_b_losses[j]=0.0;
      g_b_x_entry[j]=EMPTY_VALUE;
      g_b_x_sl[j]=EMPTY_VALUE;
      g_b_x_dir[j]=0.0;
      g_b_x_bar[j]=-1.0;
      g_b_x_exit[j]=EMPTY_VALUE;
      g_b_x_r[j]=EMPTY_VALUE;
      g_b_trend[j]=0.0;
      g_b_bos_up[j]=0.0;
      g_b_bos_down[j]=0.0;
      g_b_choch_up[j]=0.0;
      g_b_choch_down[j]=0.0;
      g_b_mss_up[j]=0.0;
      g_b_mss_down[j]=0.0;
      g_b_retest_up[j]=0.0;
      g_b_retest_down[j]=0.0;
      g_b_fail_up[j]=0.0;
      g_b_fail_down[j]=0.0;
      g_b_sweep_up[j]=0.0;
      g_b_sweep_down[j]=0.0;
      g_b_hh[j]=0.0;
      g_b_hl[j]=0.0;
      g_b_lh[j]=0.0;
      g_b_ll[j]=0.0;
      g_b_cont_up[j]=0.0;
      g_b_cont_down[j]=0.0;
      g_b_pull_up[j]=0.0;
      g_b_pull_down[j]=0.0;
      g_b_eq_hi[j]=0.0;
      g_b_eq_lo[j]=0.0;
      g_b_brk_level[j]=EMPTY_VALUE;
      g_b_brk_dir[j]=0.0;
      g_b_cp_bull[j]=0.0;
      g_b_cp_bear[j]=0.0;
      g_b_candle_score[j]=0.0;
      g_b_pin_bull[j]=0.0;
      g_b_pin_bear[j]=0.0;
      g_b_eng_bull[j]=0.0;
      g_b_eng_bear[j]=0.0;
      g_b_disp_bull[j]=0.0;
      g_b_disp_bear[j]=0.0;
      g_b_disp_bull_v[j]=0.0;
      g_b_disp_bear_v[j]=0.0;
      g_b_rej_bull[j]=0.0;
      g_b_rej_bear[j]=0.0;
      g_b_atr[j]=EMPTY_VALUE;
      g_b_atr_pct[j]=EMPTY_VALUE;
      g_b_atr_ma[j]=EMPTY_VALUE;
      g_b_atr_regime[j]=0.5;
      g_b_rsi[j]=EMPTY_VALUE;
      g_b_macd_hist[j]=EMPTY_VALUE;
      g_b_adx[j]=EMPTY_VALUE;
      g_b_di_plus[j]=EMPTY_VALUE;
      g_b_di_minus[j]=EMPTY_VALUE;
      g_b_bb_width[j]=EMPTY_VALUE;
      g_b_bb_width_ma[j]=EMPTY_VALUE;
      g_b_bb_expand[j]=0.0;
      g_b_vol_ratio[j]=0.0;
      g_b_vol_bucket[j]=0.0;
      g_b_is_tim[j]=0.0;
      g_b_rel_vol[j]=0.0;
      g_b_obv_slope[j]=0.0;
      g_b_vwap[j]=EMPTY_VALUE;
      g_b_pdh[j]=EMPTY_VALUE;
      g_b_pdl[j]=EMPTY_VALUE;
      g_b_pwh[j]=EMPTY_VALUE;
      g_b_pwl[j]=EMPTY_VALUE;
      g_b_day_range[j]=0.0;
      g_b_location_score[j]=0.0;
      g_b_volume_score[j]=0.0;
      g_b_mom_score[j]=0.0;
      g_b_trend_score[j]=0.0;
      g_b_sess_score[j]=0.0;
      g_b_sess_name[j]=0.0;
      g_b_sess_hi[j]=EMPTY_VALUE;
      g_b_sess_lo[j]=EMPTY_VALUE;
      g_b_mtf_ctx_dir[j]=0.0;
      g_b_mtf_setup_dir[j]=0.0;
      g_b_ok_setup[j]=0.0;
      g_b_htf_veto[j]=0.0;
      g_b_swing_lo[j]=EMPTY_VALUE;
      g_b_swing_hi[j]=EMPTY_VALUE;
      g_b_last_high[j]=EMPTY_VALUE;
      g_b_last_low[j]=EMPTY_VALUE;
      g_b_near_support[j]=0.0;
      g_b_near_resistance[j]=0.0;
      g_b_near_fvg_bull[j]=0.0;
      g_b_near_fvg_bear[j]=0.0;
      g_b_sr_count[j]=0.0;
      g_b_fvg_count[j]=0.0;
      g_b_ob_count[j]=0.0;
      g_b_evt_kind[j]=0.0;
      g_b_evt_dir[j]=0.0;
      g_b_evt_src_bar[j]=-1.0;
      g_b_evt_src_time[j]=0.0;
      g_b_evt_level[j]=EMPTY_VALUE;
      g_b_evt_count[j]=0.0;
     }

//--- Closed-bar plot series (live bar intentionally left empty).
   for(int j=0; j<=lastClosed; j++)
     {
      g_plot_ema_fast[j]=emaF[j];
      g_plot_ema_mid[j]=emaM[j];
      g_plot_ema_slow[j]=emaS[j];
      g_plot_vwap[j]=vwap[j];
      g_plot_volume[j]=volD[j];
      g_plot_vol_ma[j]=volMA[j];
      g_b_atr[j]=atr[j];
      g_b_atr_ma[j]=atrMA[j];
      g_b_rsi[j]=rsi[j];
      g_b_macd_hist[j]=macdHist[j];
      g_b_adx[j]=adx[j];
      g_b_di_plus[j]=diPlus[j];
      g_b_di_minus[j]=diMinus[j];
      g_b_bb_width[j]=bbWidth[j];
      g_b_bb_width_ma[j]=bbWidthMA[j];
      g_b_swing_lo[j]=swingLo[j];
      g_b_swing_hi[j]=swingHi[j];
      g_b_vwap[j]=vwap[j];
      g_b_pdh[j]=pdh[j];
      g_b_pdl[j]=pdl[j];
      g_b_pwh[j]=pwh[j];
      g_b_pwl[j]=pwl[j];
     }

//--- Pass 2: engine replay on closed bars only.
   int fromBar=0;
   if(g_cfg.maxBars>0)
      fromBar=MathMax(0,lastClosed-g_cfg.maxBars+1);

   X2EngineState st;
   X2StateInit(st);
   X2Bar bar;
   X2BarOut out;

   for(int j=fromBar; j<=lastClosed; j++)
     {
      X2BarInit(bar);
      bar.time=time[j];
      bar.open=open[j];
      bar.high=high[j];
      bar.low=low[j];
      bar.close=close[j];
      bar.volume=volD[j];
      bar.tickSize=tickSize;
      bar.prevOpen=(j>0 ? open[j-1] : EMPTY_VALUE);
      bar.prevClose=(j>0 ? close[j-1] : EMPTY_VALUE);
      bar.prevHigh=(j>0 ? high[j-1] : EMPTY_VALUE);
      bar.prevLow=(j>0 ? low[j-1] : EMPTY_VALUE);
      bar.high2=(j>1 ? high[j-2] : EMPTY_VALUE);
      bar.low2=(j>1 ? low[j-2] : EMPTY_VALUE);
      bar.atr=atr[j];
      bar.atrMA=atrMA[j];
      bar.volMA=volMA[j];
      bar.volSma=volSma[j];
      bar.emaF=emaF[j];
      bar.emaM=emaM[j];
      bar.emaS=emaS[j];
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
      bar.pivH=pivH[j];
      bar.pivHValid=pivHOk[j];
      bar.pivL=pivL[j];
      bar.pivLValid=pivLOk[j];
      bar.srPivH=srPivH[j];
      bar.srPivHValid=srPivHOk[j];
      bar.srPivL=srPivL[j];
      bar.srPivLValid=srPivLOk[j];
      bar.swingLo=swingLo[j];
      bar.swingHi=swingHi[j];
      bar.htfCtxEma=htfCtx[j];
      bar.htfCtxValid=htfCtxOk[j];
      bar.htfSetupEma=htfSetup[j];
      bar.htfSetupValid=htfSetupOk[j];
      bar.sessName=sessName[j];
      bar.volSessOk=volSessOk[j];
      bar.dayStamp=X2DayIndex(time[j]);
      bar.vwap=vwap[j];
      bar.pdh=pdh[j];
      bar.pdl=pdl[j];
      bar.pwh=pwh[j];
      bar.pwl=pwl[j];
      bar.hasPd=hasPd[j];
      bar.hasPw=hasPw[j];

      X2EngineStep(g_cfg,st,bar,j,out);

      g_plot_long_entry[j]=(out.evEntry && out.posDir==1 ? low[j] : EMPTY_VALUE);
      g_plot_short_entry[j]=(out.evEntry && out.posDir==-1 ? high[j] : EMPTY_VALUE);
      g_plot_hit_tp[j]=(out.evTp>0 ? high[j] : EMPTY_VALUE);
      g_plot_hit_sl[j]=(out.evSl ? low[j] : EMPTY_VALUE);
      g_plot_active_sl[j]=(out.posDir!=0 && !X2IsEmpty(out.posSl)
                           ? out.posSl : EMPTY_VALUE);
      g_plot_active_tp1[j]=(out.posDir!=0 && !X2IsEmpty(out.posTp1)
                            ? out.posTp1 : EMPTY_VALUE);
      g_plot_active_tp2[j]=(out.posDir!=0 && !X2IsEmpty(out.posTp2)
                            ? out.posTp2 : EMPTY_VALUE);

      g_b_score100[j]=(double)out.score100;
      g_b_dir[j]=(double)out.dir;
      g_b_quality[j]=(double)out.quality;
      g_b_raw_score[j]=out.rawScore;
      g_b_g_trend[j]=out.gTrend;
      g_b_g_struct[j]=out.gStruct;
      g_b_g_liq[j]=out.gLiq;
      g_b_g_loc[j]=out.gLoc;
      g_b_g_sr[j]=out.gSr;
      g_b_g_candle[j]=out.gCandle;
      g_b_g_volume[j]=out.gVolume;
      g_b_g_vol[j]=out.gVol;
      g_b_g_mom[j]=out.gMom;
      g_b_g_sess[j]=out.gSess;
      g_b_g_mtf[j]=out.gMtf;
      g_b_plan_valid[j]=(out.planValid ? 1.0 : 0.0);
      g_b_entry[j]=out.entry;
      g_b_sl[j]=out.sl;
      g_b_tp1[j]=out.tp1;
      g_b_tp2[j]=out.tp2;
      g_b_tp3[j]=out.tp3;
      g_b_risk[j]=out.risk;
      g_b_sig[j]=(out.signal ? 1.0 : 0.0);
      g_b_block[j]=(double)out.block;
      g_b_ev_entry[j]=(out.evEntry ? 1.0 : 0.0);
      g_b_ev_tp[j]=(double)out.evTp;
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
      g_b_pos_bar[j]=(double)out.posBar;
      g_b_day_count[j]=(double)out.dayCount;
      g_b_bars_since[j]=(double)out.barsSince;
      g_b_trades[j]=(double)out.trades;
      g_b_wins[j]=(double)out.wins;
      g_b_losses[j]=(double)out.losses;
      g_b_x_entry[j]=out.xEntry;
      g_b_x_sl[j]=out.xSl;
      g_b_x_dir[j]=(double)out.xDir;
      g_b_x_bar[j]=(double)out.xBar;
      g_b_x_exit[j]=out.xExit;
      g_b_x_r[j]=out.xR;
      g_b_trend[j]=(double)out.trend;
      g_b_bos_up[j]=(out.bosUp ? 1.0 : 0.0);
      g_b_bos_down[j]=(out.bosDown ? 1.0 : 0.0);
      g_b_choch_up[j]=(out.chochUp ? 1.0 : 0.0);
      g_b_choch_down[j]=(out.chochDown ? 1.0 : 0.0);
      g_b_mss_up[j]=(out.mssUp ? 1.0 : 0.0);
      g_b_mss_down[j]=(out.mssDown ? 1.0 : 0.0);
      g_b_retest_up[j]=(out.retestUp ? 1.0 : 0.0);
      g_b_retest_down[j]=(out.retestDown ? 1.0 : 0.0);
      g_b_fail_up[j]=(out.failUp ? 1.0 : 0.0);
      g_b_fail_down[j]=(out.failDown ? 1.0 : 0.0);
      g_b_sweep_up[j]=(out.sweepUp ? 1.0 : 0.0);
      g_b_sweep_down[j]=(out.sweepDown ? 1.0 : 0.0);
      g_b_hh[j]=(out.hh ? 1.0 : 0.0);
      g_b_hl[j]=(out.hl ? 1.0 : 0.0);
      g_b_lh[j]=(out.lh ? 1.0 : 0.0);
      g_b_ll[j]=(out.ll ? 1.0 : 0.0);
      g_b_cont_up[j]=(out.contUp ? 1.0 : 0.0);
      g_b_cont_down[j]=(out.contDown ? 1.0 : 0.0);
      g_b_pull_up[j]=(out.pullUp ? 1.0 : 0.0);
      g_b_pull_down[j]=(out.pullDown ? 1.0 : 0.0);
      g_b_eq_hi[j]=(out.eqHi ? 1.0 : 0.0);
      g_b_eq_lo[j]=(out.eqLo ? 1.0 : 0.0);
      g_b_brk_level[j]=out.brkLevel;
      g_b_brk_dir[j]=(double)out.brkDir;
      g_b_cp_bull[j]=out.cpBull;
      g_b_cp_bear[j]=out.cpBear;
      g_b_candle_score[j]=out.candleScore;
      g_b_pin_bull[j]=(out.pinBull ? 1.0 : 0.0);
      g_b_pin_bear[j]=(out.pinBear ? 1.0 : 0.0);
      g_b_eng_bull[j]=(out.engBull ? 1.0 : 0.0);
      g_b_eng_bear[j]=(out.engBear ? 1.0 : 0.0);
      g_b_disp_bull[j]=(out.dispBull ? 1.0 : 0.0);
      g_b_disp_bear[j]=(out.dispBear ? 1.0 : 0.0);
      g_b_disp_bull_v[j]=(out.dispBullV ? 1.0 : 0.0);
      g_b_disp_bear_v[j]=(out.dispBearV ? 1.0 : 0.0);
      g_b_rej_bull[j]=(out.rejBull ? 1.0 : 0.0);
      g_b_rej_bear[j]=(out.rejBear ? 1.0 : 0.0);
      g_b_atr[j]=out.atr;
      g_b_atr_pct[j]=out.atrPct;
      g_b_atr_ma[j]=out.atrMA;
      g_b_atr_regime[j]=out.atrRegime;
      g_b_rsi[j]=out.rsi;
      g_b_macd_hist[j]=out.macdHist;
      g_b_adx[j]=out.adx;
      g_b_di_plus[j]=out.diPlus;
      g_b_di_minus[j]=out.diMinus;
      g_b_bb_width[j]=out.bbWidth;
      g_b_bb_width_ma[j]=out.bbWidthMA;
      g_b_bb_expand[j]=(out.bbExpand ? 1.0 : 0.0);
      g_b_vol_ratio[j]=out.volRatio;
      g_b_vol_bucket[j]=(double)out.volBucket;
      g_b_is_tim[j]=(out.isTim ? 1.0 : 0.0);
      g_b_rel_vol[j]=out.relVol;
      g_b_obv_slope[j]=out.obvSlope;
      g_b_vwap[j]=out.vwap;
      g_b_pdh[j]=out.pdh;
      g_b_pdl[j]=out.pdl;
      g_b_pwh[j]=out.pwh;
      g_b_pwl[j]=out.pwl;
      g_b_day_range[j]=out.dayRange;
      g_b_location_score[j]=out.locationScore;
      g_b_volume_score[j]=out.volumeScore;
      g_b_mom_score[j]=out.momScore;
      g_b_trend_score[j]=out.trendScore;
      g_b_sess_score[j]=out.sessScore;
      g_b_sess_name[j]=(double)out.sessName;
      g_b_sess_hi[j]=out.sessHi;
      g_b_sess_lo[j]=out.sessLo;
      g_b_mtf_ctx_dir[j]=(double)out.mtfCtxDir;
      g_b_mtf_setup_dir[j]=(double)out.mtfSetupDir;
      g_b_ok_setup[j]=(out.okSetup ? 1.0 : 0.0);
      g_b_htf_veto[j]=(out.htfVeto ? 1.0 : 0.0);
      g_b_swing_lo[j]=out.swingLo;
      g_b_swing_hi[j]=out.swingHi;
      g_b_last_high[j]=out.lastHigh;
      g_b_last_low[j]=out.lastLow;
      g_b_near_support[j]=(out.nearSupport ? 1.0 : 0.0);
      g_b_near_resistance[j]=(out.nearResistance ? 1.0 : 0.0);
      g_b_near_fvg_bull[j]=(out.nearFvgBull ? 1.0 : 0.0);
      g_b_near_fvg_bear[j]=(out.nearFvgBear ? 1.0 : 0.0);
      g_b_sr_count[j]=(double)out.srCount;
      g_b_fvg_count[j]=(double)out.fvgCount;
      g_b_ob_count[j]=(double)out.obCount;
      g_b_evt_kind[j]=(double)out.evtKind;
      g_b_evt_dir[j]=(double)out.evtDir;
      g_b_evt_src_bar[j]=(double)out.evtSrcBar;
      g_b_evt_src_time[j]=(double)out.evtSrcTime;
      g_b_evt_level[j]=out.evtLevel;
      g_b_evt_count[j]=(double)out.evtCount;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
