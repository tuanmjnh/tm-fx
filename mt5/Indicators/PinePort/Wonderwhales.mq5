//+------------------------------------------------------------------+
//|                                                Wonderwhales.mq5 |
//|        MT5 EA & AI Lab - PinePort of Wonderwhales (signal-only)  |
//|                                                                  |
//| Custom indicator only. No file I/O, no account access, no order  |
//| functions. Contract: docs/30-research/indicators/wonderwhales.md        |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Wonderwhales signal indicator. Confirmed bars only; no trading."
#property indicator_chart_window
#property indicator_buffers 18
#property indicator_plots   3
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1
#property indicator_label1  "PSAR"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLimeGreen
#property indicator_width2  1
#property indicator_label2  "BUY"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrTomato
#property indicator_width3  1
#property indicator_label3  "SELL"

#include "../../Include/PinePort/WonderwhalesContract.mqh"

input ENUM_WW_MODE InpMode         = WW_MODE_SAR; // Signal mode
input double       InpPsarStart    = 0.02;        // PSAR initial acceleration
input double       InpPsarInc      = 0.02;        // PSAR increment
input double       InpPsarMax      = 0.20;        // PSAR maximum acceleration
input int          InpFastEma      = 20;          // Fast EMA period
input int          InpSlowEma      = 50;          // Slow EMA period
input int          InpEma200       = 200;         // EMA200 period (display)
input int          InpAtrLen       = 14;          // ATR period
input double       InpMinAtrPct    = 0.5;         // Minimum ATR as % of price
input int          InpVolMaLen     = 20;          // Volume MA period
input int          InpRsiLen       = 14;          // RSI period (display)
input int          InpBbLen        = 20;          // Bollinger period (display)
input double       InpBbMult       = 2.0;         // Bollinger deviation
//--- Appended last so existing positional iCustom callers keep working.
input ENUM_WW_PSAR InpPsarEngine   = WW_PSAR_ISAR; // PSAR engine (iSAR = shipped)

double g_psar[];
double g_buy_marker[];
double g_sell_marker[];
double g_buy_signal[];
double g_sell_signal[];
double g_dir[];
double g_blocked_buy[];
double g_blocked_sell[];
double g_atr_pct[];
double g_fast[];
double g_slow[];
double g_ema200[];
double g_rsi[];
double g_bb_upper[];
double g_bb_mid[];
double g_bb_lower[];
double g_vol_ma[];
double g_vol_ratio[];

//--- Built-in PSAR cache. It is a CIRCULAR buffer anchored to the END of the
//--- series (slot 0 behind g_psar_head = the last closed bar), so new bars are an
//--- O(1) push and a re-based series (the tester loads older bars as it runs)
//--- needs no rebuild at all. The per-bar state is stored so the recurrence can
//--- continue without recomputation.
double       g_psar_value[];
double       g_psar_up[];
double       g_psar_extreme[];
double       g_psar_accel[];
int          g_psar_cap=0;
int          g_psar_head=-1;
int          g_psar_count=0;
datetime     g_psar_last_closed=0;
WwPsarState  g_psar_state;

int g_sar_handle=INVALID_HANDLE;
int g_fast_handle=INVALID_HANDLE;
int g_slow_handle=INVALID_HANDLE;
int g_ema200_handle=INVALID_HANDLE;
int g_atr_handle=INVALID_HANDLE;
int g_rsi_handle=INVALID_HANDLE;
int g_bb_handle=INVALID_HANDLE;

WwConfig g_cfg;

//--- Offset between the full terminal series and the OnCalculate window.
//--- The tester hands the indicator fewer bars than Bars() returns, while the
//--- iSAR sub-indicator is computed over the full history; the built-in series
//--- must cover the same range, so it is built from CopyRates and read with this
//--- offset. Returns -1 when the series is not available yet.


//--- Extend the built-in PSAR cache up to the terminal's full series. The
//--- recurrence is sequential, so it is computed once per bar and only the new
//--- tail is added; a shrink (history reload) restarts from scratch.
//--- Cost model: OnCalculate runs on every tick, so this only does work when a
//--- NEW closed bar appears, and then copies just the new tail (CopyRates of the
//--- whole series on every tick was the reason the built-in engine was ~20x
//--- slower in the tester). A re-based series (reload, or older bars prepended
//--- while the tester loads history) forces one full rebuild.
//--- Slot of the value `back` bars behind the newest cached bar.
double PsarCached(const int back)
  {
   if(g_psar_cap<=0 || back<0 || back>=g_psar_count)
      return(EMPTY_VALUE);
   const int slot=((g_psar_head-back)%g_psar_cap+g_psar_cap)%g_psar_cap;
   return(g_psar_value[slot]);
  }

void PsarPush(const double value,const WwPsarState &state)
  {
   if(g_psar_cap<=0)
      return;
   g_psar_head=(g_psar_head+1)%g_psar_cap;
   g_psar_value[g_psar_head]=value;
   g_psar_up[g_psar_head]=(state.up ? 1.0 : 0.0);
   g_psar_extreme[g_psar_head]=state.extreme;
   g_psar_accel[g_psar_head]=state.accel;
   if(g_psar_count<g_psar_cap)
      g_psar_count++;
  }

void PsarRestoreFromNewest(void)
  {
   g_psar_state.up=(g_psar_up[g_psar_head]>0.5);
   g_psar_state.extreme=g_psar_extreme[g_psar_head];
   g_psar_state.accel=g_psar_accel[g_psar_head];
   g_psar_state.sar=g_psar_value[g_psar_head];
  }

//--- Keep the cache covering the window's CLOSED bars: indices 0..rates_total-2.
//--- The tester prepends older bars as it loads history, so a bar's window index is
//--- not stable; the tail is therefore validated BY TIME. In the steady state one
//--- bar closes per call and the work is O(1); a gap or a reload reseeds once.
void EnsureBuiltinPsar(const int rates_total,const datetime &time[],
                       const double &high[],const double &low[],
                       const double &close[])
  {
   const int last_idx=rates_total-2;             // last CLOSED bar; rates_total-1 is forming
   if(last_idx<1)
      return;

   const int closed_count=last_idx+1;

   if(g_psar_cap<closed_count)
     {
      g_psar_cap=closed_count+64;
      ArrayResize(g_psar_value,g_psar_cap);
      ArrayResize(g_psar_up,g_psar_cap);
      ArrayResize(g_psar_extreme,g_psar_cap);
      ArrayResize(g_psar_accel,g_psar_cap);
      g_psar_head=-1;
      g_psar_count=0;
     }

   //--- Decisions are made BY TIME only. The tester prepends older bars while it
   //--- loads history, which changes the window indices and the bar count without
   //--- adding anything at the tail; comparing counts would force a full rebuild
   //--- on every such reload.
   if(g_psar_count>0 && time[last_idx]==g_psar_last_closed)
      return;                                    // nothing new

   //--- Steady state: the cached newest bar is now the second-newest window bar,
   //--- so exactly one bar closed since the last call.
   const bool append=(g_psar_count>0 && time[last_idx-1]==g_psar_last_closed);

   if(append)
     {
      PsarRestoreFromNewest();
      const bool two=(last_idx>=2);
      const double sar=WwPsarStep(two ? high[last_idx-2] : high[last_idx-1],
                                  two ? low[last_idx-2]  : low[last_idx-1],
                                  high[last_idx-1],low[last_idx-1],
                                  high[last_idx],low[last_idx],
                                  g_cfg.psar_start,g_cfg.psar_inc,
                                  g_cfg.psar_max,g_psar_state);
      PsarPush(sar,g_psar_state);
      g_psar_last_closed=time[last_idx];
      return;
     }

   //--- Otherwise rebuild the window's closed bars from scratch.
   g_psar_head=-1;
   g_psar_count=0;
   WwPsarReset(high[0],low[0],close[0],close[1],g_cfg.psar_start,g_psar_state);
   PsarPush(EMPTY_VALUE,g_psar_state);
   for(int i=1; i<=last_idx; i++)
     {
      PsarRestoreFromNewest();
      const bool two=(i>=2);
      const double sar=WwPsarStep(two ? high[i-2] : high[i-1],
                                  two ? low[i-2]  : low[i-1],
                                  high[i-1],low[i-1],high[i],low[i],
                                  g_cfg.psar_start,g_cfg.psar_inc,
                                  g_cfg.psar_max,g_psar_state);
      PsarPush(sar,g_psar_state);
     }
   g_psar_last_closed=time[last_idx];
  }

int OnInit()
  {
   g_cfg.mode=InpMode;
   g_cfg.psar_start=InpPsarStart;
   g_cfg.psar_inc=InpPsarInc;
   g_cfg.psar_max=InpPsarMax;
   g_cfg.fast_ema=InpFastEma;
   g_cfg.slow_ema=InpSlowEma;
   g_cfg.ema200=InpEma200;
   g_cfg.atr_len=InpAtrLen;
   g_cfg.min_atr_pct=InpMinAtrPct;
   g_cfg.vol_ma_len=InpVolMaLen;
   g_cfg.rsi_len=InpRsiLen;
   g_cfg.bb_len=InpBbLen;
   g_cfg.bb_mult=InpBbMult;
   WwNormalizeConfig(g_cfg);

   //--- Only create the iSAR handle when it is actually used, so the built-in
   //--- engine never waits on a sub-indicator it does not read.
   if(InpPsarEngine==WW_PSAR_ISAR)
      g_sar_handle=iSAR(_Symbol,_Period,g_cfg.psar_start,g_cfg.psar_max);
   g_fast_handle=iMA(_Symbol,_Period,g_cfg.fast_ema,0,MODE_EMA,PRICE_CLOSE);
   g_slow_handle=iMA(_Symbol,_Period,g_cfg.slow_ema,0,MODE_EMA,PRICE_CLOSE);
   g_ema200_handle=iMA(_Symbol,_Period,g_cfg.ema200,0,MODE_EMA,PRICE_CLOSE);
   g_atr_handle=iATR(_Symbol,_Period,g_cfg.atr_len);
   g_rsi_handle=iRSI(_Symbol,_Period,g_cfg.rsi_len,PRICE_CLOSE);
   g_bb_handle=iBands(_Symbol,_Period,g_cfg.bb_len,0,g_cfg.bb_mult,PRICE_CLOSE);

   if((InpPsarEngine==WW_PSAR_ISAR && g_sar_handle==INVALID_HANDLE) ||
      g_fast_handle==INVALID_HANDLE ||
      g_slow_handle==INVALID_HANDLE || g_ema200_handle==INVALID_HANDLE ||
      g_atr_handle==INVALID_HANDLE || g_rsi_handle==INVALID_HANDLE ||
      g_bb_handle==INVALID_HANDLE)
     {
      PrintFormat("WONDERWHALES|ERROR|init_handle_failed|error=%d",GetLastError());
      return(INIT_FAILED);
     }

   //--- The built-in engine is opt-in. It is validated against the independent
   //--- Python port (100% of 141503 M5 bars, max diff 5e-9) but it is NOT the
   //--- shipped default, and it disagrees with iSAR on ~2.3% of directions, so
   //--- switching it changes every signal and every measurement.
   if(InpPsarEngine==WW_PSAR_BUILTIN)
      PrintFormat("WONDERWHALES|INFO|psar_engine_builtin|"
                  "port_check=100pct_of_141503_bars|vs_isar_dir_diff=2.3pct|"
                  "not_the_shipped_default");

   if(g_cfg.slow_ema!=InpSlowEma || g_cfg.fast_ema!=InpFastEma)
      PrintFormat("WONDERWHALES|WARN|input_clamped|fast=%d slow=%d fast_safe=%d slow_safe=%d",
                  InpFastEma,InpSlowEma,g_cfg.fast_ema,g_cfg.slow_ema);

   SetIndexBuffer(WW_BUF_PSAR,g_psar,INDICATOR_DATA);
   SetIndexBuffer(WW_BUF_BUY_MARKER,g_buy_marker,INDICATOR_DATA);
   SetIndexBuffer(WW_BUF_SELL_MARKER,g_sell_marker,INDICATOR_DATA);
   SetIndexBuffer(WW_BUF_BUY_SIGNAL,g_buy_signal,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_SELL_SIGNAL,g_sell_signal,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_SAR_DIR,g_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_BLOCKED_BUY,g_blocked_buy,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_BLOCKED_SELL,g_blocked_sell,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_ATR_PCT,g_atr_pct,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_FAST_EMA,g_fast,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_SLOW_EMA,g_slow,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_EMA200,g_ema200,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_RSI,g_rsi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_BB_UPPER,g_bb_upper,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_BB_MID,g_bb_mid,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_BB_LOWER,g_bb_lower,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_VOL_MA,g_vol_ma,INDICATOR_CALCULATIONS);
   SetIndexBuffer(WW_BUF_VOL_RATIO,g_vol_ratio,INDICATOR_CALCULATIONS);

   PlotIndexSetInteger(1,PLOT_ARROW,233);
   PlotIndexSetInteger(2,PLOT_ARROW,234);
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("Wonderwhales %s v%s",
                                   WwModeName(g_cfg.mode),WW_CONTRACT_VERSION));
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);

   PrintFormat("WONDERWHALES|INFO|init|mode=%s psar_engine=%s fast=%d slow=%d ema200=%d atr=%d min_atr_pct=%.3f vol=%d rsi=%d bb=%d/%.2f contract=%s hash=%s",
               WwModeName(g_cfg.mode),
               (InpPsarEngine==WW_PSAR_ISAR ? "ISAR" : "BUILTIN"),
               g_cfg.fast_ema,g_cfg.slow_ema,g_cfg.ema200,
               g_cfg.atr_len,g_cfg.min_atr_pct,g_cfg.vol_ma_len,g_cfg.rsi_len,
               g_cfg.bb_len,g_cfg.bb_mult,WW_CONTRACT_VERSION,
               WwConfigHash(g_cfg,0));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_sar_handle!=INVALID_HANDLE)
      IndicatorRelease(g_sar_handle);
   if(g_fast_handle!=INVALID_HANDLE)
      IndicatorRelease(g_fast_handle);
   if(g_slow_handle!=INVALID_HANDLE)
      IndicatorRelease(g_slow_handle);
   if(g_ema200_handle!=INVALID_HANDLE)
      IndicatorRelease(g_ema200_handle);
   if(g_atr_handle!=INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
   if(g_rsi_handle!=INVALID_HANDLE)
      IndicatorRelease(g_rsi_handle);
   if(g_bb_handle!=INVALID_HANDLE)
      IndicatorRelease(g_bb_handle);
   PrintFormat("WONDERWHALES|INFO|deinit|reason=%d",reason);
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

   if((InpPsarEngine==WW_PSAR_ISAR && BarsCalculated(g_sar_handle)<rates_total) ||
      BarsCalculated(g_fast_handle)<rates_total ||
      BarsCalculated(g_slow_handle)<rates_total ||
      BarsCalculated(g_ema200_handle)<rates_total ||
      BarsCalculated(g_atr_handle)<rates_total ||
      BarsCalculated(g_rsi_handle)<rates_total ||
      BarsCalculated(g_bb_handle)<rates_total)
      return(0);

   int calc_start;
   if(prev_calculated<=1 || prev_calculated>rates_total)
      calc_start=0;
   else
      calc_start=prev_calculated-2;
   if(calc_start<0)
      calc_start=0;

   const int copy_start=(calc_start>0 ? calc_start-1 : 0);
   const int count=rates_total-copy_start;
   if(count<=0)
      return(rates_total);

   double sar[],fast[],slow[],ema200[],atr[],rsi[],bb_upper[],bb_mid[],bb_lower[];
   ArraySetAsSeries(sar,false);
   ArraySetAsSeries(fast,false);
   ArraySetAsSeries(slow,false);
   ArraySetAsSeries(ema200,false);
   ArraySetAsSeries(atr,false);
   ArraySetAsSeries(rsi,false);
   ArraySetAsSeries(bb_upper,false);
   ArraySetAsSeries(bb_mid,false);
   ArraySetAsSeries(bb_lower,false);

   if(InpPsarEngine==WW_PSAR_ISAR)
     {
      if(CopyBuffer(g_sar_handle,0,0,count,sar)!=count)
         return(0);
     }
   else
      EnsureBuiltinPsar(rates_total,time,high,low,close);

   if(CopyBuffer(g_fast_handle,0,0,count,fast)!=count)
      return(0);
   if(CopyBuffer(g_slow_handle,0,0,count,slow)!=count)
      return(0);
   if(CopyBuffer(g_ema200_handle,0,0,count,ema200)!=count)
      return(0);
   if(CopyBuffer(g_atr_handle,0,0,count,atr)!=count)
      return(0);
   if(CopyBuffer(g_rsi_handle,0,0,count,rsi)!=count)
      return(0);
   if(CopyBuffer(g_bb_handle,0,0,count,bb_mid)!=count)
      return(0);
   if(CopyBuffer(g_bb_handle,1,0,count,bb_upper)!=count)
      return(0);
   if(CopyBuffer(g_bb_handle,2,0,count,bb_lower)!=count)
      return(0);

   const int fast_ready_index=g_cfg.fast_ema-1;
   const int slow_ready_index=g_cfg.slow_ema-1;
   const int ema200_ready_index=g_cfg.ema200-1;
   const int rsi_ready_index=g_cfg.rsi_len;
   const int bb_ready_index=g_cfg.bb_len-1;

   for(int j=calc_start; j<rates_total; j++)
     {
      const int idx=j-copy_start;
      const bool confirmed=(j<rates_total-1);
      const double close_val=close[j];

      double sar_val=EMPTY_VALUE;
      if(InpPsarEngine==WW_PSAR_ISAR)
         sar_val=sar[idx];
      else
         sar_val=PsarCached((rates_total-2)-j);
      const bool psar_valid=(MathIsValidNumber(sar_val) && sar_val>0.0);

      int dir_prev=0;
      if(j>0)
         dir_prev=(int)g_dir[j-1];

      const bool fast_ready=(j>=fast_ready_index && MathIsValidNumber(fast[idx]) && fast[idx]>0.0);
      const bool slow_ready=(j>=slow_ready_index && MathIsValidNumber(slow[idx]) && slow[idx]>0.0);
      const bool ema_now_valid=(fast_ready && slow_ready);

      const bool fast_prev_ready=(j>=fast_ready_index+1 && idx>0 &&
                                  MathIsValidNumber(fast[idx-1]) && fast[idx-1]>0.0);
      const bool slow_prev_ready=(j>=slow_ready_index+1 && idx>0 &&
                                  MathIsValidNumber(slow[idx-1]) && slow[idx-1]>0.0);
      const bool ema_prev_valid=(fast_prev_ready && slow_prev_ready);

      WwBarInput in;
      in.psar_valid=psar_valid;
      in.psar=sar_val;
      in.close=close_val;
      in.ema_now_valid=ema_now_valid;
      in.ema_prev_valid=ema_prev_valid;
      in.fast_prev=(ema_prev_valid ? fast[idx-1] : 0.0);
      in.slow_prev=(ema_prev_valid ? slow[idx-1] : 0.0);
      in.fast_now=(ema_now_valid ? fast[idx] : 0.0);
      in.slow_now=(ema_now_valid ? slow[idx] : 0.0);

      const double atr_val=atr[idx];
      const bool atr_ready=(j>=g_cfg.atr_len && MathIsValidNumber(atr_val) &&
                            atr_val>0.0 && close_val>0.0);
      in.atr_pct=WwAtrPct(atr_ready,atr_val,close_val);

      WwBarOutput out;
      WwEvaluateBar(g_cfg,in,dir_prev,confirmed,out);

      g_psar[j]=(psar_valid ? sar_val : EMPTY_VALUE);
      g_dir[j]=(double)out.sar_dir;
      g_buy_signal[j]=(out.signal_buy ? 1.0 : 0.0);
      g_sell_signal[j]=(out.signal_sell ? 1.0 : 0.0);
      g_buy_marker[j]=(out.signal_buy ? low[j] : EMPTY_VALUE);
      g_sell_marker[j]=(out.signal_sell ? high[j] : EMPTY_VALUE);
      g_blocked_buy[j]=(out.signal_blocked_buy ? 1.0 : 0.0);
      g_blocked_sell[j]=(out.signal_blocked_sell ? 1.0 : 0.0);
      g_atr_pct[j]=in.atr_pct;
      g_fast[j]=(fast_ready ? fast[idx] : EMPTY_VALUE);
      g_slow[j]=(slow_ready ? slow[idx] : EMPTY_VALUE);

      const bool ema200_ready=(j>=ema200_ready_index &&
                               MathIsValidNumber(ema200[idx]) && ema200[idx]>0.0);
      g_ema200[j]=(ema200_ready ? ema200[idx] : EMPTY_VALUE);

      const bool rsi_ready=(j>=rsi_ready_index && MathIsValidNumber(rsi[idx]));
      g_rsi[j]=(rsi_ready ? rsi[idx] : EMPTY_VALUE);

      const bool bb_ready=(j>=bb_ready_index &&
                           MathIsValidNumber(bb_upper[idx]) &&
                           MathIsValidNumber(bb_mid[idx]) &&
                           MathIsValidNumber(bb_lower[idx]));
      g_bb_upper[j]=(bb_ready ? bb_upper[idx] : EMPTY_VALUE);
      g_bb_mid[j]=(bb_ready ? bb_mid[idx] : EMPTY_VALUE);
      g_bb_lower[j]=(bb_ready ? bb_lower[idx] : EMPTY_VALUE);

      double vol_ma_val=EMPTY_VALUE;
      double vol_ratio_val=0.0;
      if(j+1>=g_cfg.vol_ma_len)
        {
         double sum=0.0;
         bool window_ok=true;
         for(int k=0; k<g_cfg.vol_ma_len; k++)
           {
            const int vi=j-k;
            if(vi<0)
              {
               window_ok=false;
               break;
              }
            sum+=(double)tick_volume[vi];
           }
         if(window_ok)
           {
            vol_ma_val=sum/(double)g_cfg.vol_ma_len;
            vol_ratio_val=WwVolRatio(true,(double)tick_volume[j],vol_ma_val);
           }
        }
      g_vol_ma[j]=vol_ma_val;
      g_vol_ratio[j]=vol_ratio_val;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
