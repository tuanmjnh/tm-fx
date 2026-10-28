//+------------------------------------------------------------------+
//|                                              LongKacoVSA.mq5     |
//|        MT5 EA & AI Lab - PinePort of LongKaco VSA (signal-only)  |
//|                                                                  |
//| Custom indicator only. No file I/O, no account access, no order  |
//| functions. Contract: docs/indicators/longkaco-vsa.md          |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "LongKaco VSA signal indicator. Confirmed bars only; no trading."
#property indicator_chart_window
#property indicator_buffers 29
#property indicator_plots   8

#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrPurple
#property indicator_width1  1
#property indicator_label1  "SV"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  1
#property indicator_label2  "BC"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrTeal
#property indicator_width3  1
#property indicator_label3  "ST LONG"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrange
#property indicator_width4  1
#property indicator_label4  "ST SHORT"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrDodgerBlue
#property indicator_width5  1
#property indicator_label5  "NS"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrSilver
#property indicator_width6  1
#property indicator_label6  "ND"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrDimGray
#property indicator_width7  1
#property indicator_label7  "NO SWEEP"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrMagenta
#property indicator_width8  1
#property indicator_label8  "CLX-E"

#include "../../Include/PinePort/LongKacoVSAContract.mqh"

input ENUM_LK_SIGNAL_MODE   InpSignalMode           = LK_SIGNAL_VSA;       // Chien luoc
input ENUM_LK_WYCKOFF_EVENT InpWyckoffEvent         = LK_WYCKOFF_LPS;      // Su kien Wyckoff
input ENUM_LK_ENTRY_MODE    InpEntryMode            = LK_ENTRY_MARKET;     // Kieu vao lenh
input ENUM_LK_TP_MODE       InpTpMode               = LK_TP_R;             // Kieu dat TP
input int                   InpLen                  = 20;                  // Volume RMA period
input double                InpRP                   = 2.2;                 // TIM ratio
input double                InpRVH                  = 1.8;                 // VeryHigh ratio
input double                InpRH                   = 1.2;                 // High ratio
input double                InpRN                   = 0.8;                 // Normal ratio
input double                InpRL                   = 0.4;                 // Low ratio
input int                   InpPurWin               = 20;                  // TIM count window
input double                InpVolMin               = 0.0;                 // Absolute minimum volume
input bool                  InpEvtOn                = true;                // Enable SV/BC/ST
input bool                  InpQuietOn              = true;                // Enable NS/ND
input int                   InpRun                  = 5;                   // Momentum lookback
input double                InpLvTol                = 0.5;                 // Level tolerance (x ATR)
input int                   InpLvFresh              = 60;                  // Level freshness (bars)
input double                InpTestR                = 1.2;                 // Test volume ratio
input double                InpRetestT              = 1.0;                 // Retest radius (x ATR)
input int                   InpAtrLen               = 14;                  // ATR period
input int                   InpPivLen               = 20;                  // Pivot left/right bars
input double                InpSosSpread            = 1.0;                 // SOS/SOW spread (x ATR)
input double                InpSosVol               = 1.2;                 // SOS/SOW volume (x MA)
input double                InpLpsTol               = 0.5;                 // LPS/LPSY tolerance (x ATR)
input bool                  InpSweepReq             = true;                // Require sweep before ST
input int                   InpSweepWin             = 10;                  // Sweep lookback (0 = unlimited)
input bool                  InpClxOn                = true;                // CLX-E dashboard flag (render only)
input double                InpClxR                 = 1.5;                 // CLX-E distance (x R)
input double                InpSlBuf                = 0.5;                 // SL buffer (x ATR)
input double                InpRrFb                 = 2.0;                 // TP fallback (R)
input double                InpFeePct               = 0.05;                // Fee per side (%)
input double                InpFeeMaxR              = 0.15;                // Fee/R warning level
input bool                  InpSessionOn            = false;               // Enable session filter
input string                InpSession              = "0800-1600";         // Session (HHMM-HHMM, local)
input int                   InpSessionUtcOffsetMin  = 420;                 // Session UTC offset (minutes east)

//--- Render buffers 0..7 (price markers, plots 0..7)
double g_plot_sv[];
double g_plot_bc[];
double g_plot_stl[];
double g_plot_sts[];
double g_plot_ns[];
double g_plot_nd[];
double g_plot_nosweep[];
double g_plot_clx[];

//--- Contract buffers 8..28
double g_buf_sv[];
double g_buf_bc[];
double g_buf_stl[];
double g_buf_sts[];
double g_buf_ns[];
double g_buf_nd[];
double g_buf_nosweep[];
double g_buf_clx[];
double g_buf_tim[];
double g_buf_ratio[];
double g_buf_volma[];
double g_buf_atr[];
double g_buf_pivlow[];
double g_buf_pivhigh[];
double g_buf_entry[];
double g_buf_sl[];
double g_buf_tp[];
double g_buf_dir[];
double g_buf_fill[];
double g_buf_result[];
double g_buf_lastevt[];

LkConfig g_cfg;
int      g_last_rates=-1;

bool     g_sess_on=false;
int      g_sess_start=0;
int      g_sess_end=0;
int      g_sess_offset=0;

bool LkParseClock(const string text,int &minutes)
  {
   if(StringLen(text)!=4)
      return(false);
   if(StringGetCharacter(text,0)<'0' || StringGetCharacter(text,0)>'9')
      return(false);
   for(int i=0; i<4; i++)
     {
      const ushort ch=StringGetCharacter(text,i);
      if(ch<'0' || ch>'9')
         return(false);
     }
   const int hour=(int)StringToInteger(StringSubstr(text,0,2));
   const int minute=(int)StringToInteger(StringSubstr(text,2,2));
   if(hour<0 || hour>23 || minute<0 || minute>59)
      return(false);
   minutes=hour*60+minute;
   return(true);
  }

bool LkParseSession(const string text,int &start_minutes,int &end_minutes)
  {
   const string value=text;
   const int dash=StringFind(value,"-");
   if(dash!=4 || StringLen(value)!=9)
      return(false);
   if(!LkParseClock(StringSubstr(value,0,dash),start_minutes))
      return(false);
   if(!LkParseClock(StringSubstr(value,dash+1,StringLen(value)-dash-1),end_minutes))
      return(false);
   return(true);
  }

//--- Pine time(timeframe.period, session, tz) equivalent with a fixed UTC
//--- offset. No DST rules: documented difference D2 in the spec.
bool LkSessionOk(const datetime bar_time,const int gmt_offset_sec)
  {
   if(!g_sess_on)
      return(true);
   const long utc=(long)bar_time-(long)gmt_offset_sec;
   const long local_sec=utc+(long)g_sess_offset*60;
   MqlDateTime parts;
   TimeToStruct((datetime)local_sec,parts);
   const int minute_of_day=parts.hour*60+parts.min;
   if(g_sess_start==g_sess_end)
      return(true);
   if(g_sess_start<g_sess_end)
      return(minute_of_day>=g_sess_start && minute_of_day<g_sess_end);
   return(minute_of_day>=g_sess_start || minute_of_day<g_sess_end);
  }

int OnInit()
  {
   g_cfg.signal_mode=InpSignalMode;
   g_cfg.wyckoff_event=InpWyckoffEvent;
   g_cfg.entry_mode=InpEntryMode;
   g_cfg.tp_mode=InpTpMode;
   g_cfg.len=InpLen;
   g_cfg.r_p=InpRP;
   g_cfg.r_vh=InpRVH;
   g_cfg.r_h=InpRH;
   g_cfg.r_n=InpRN;
   g_cfg.r_l=InpRL;
   g_cfg.pur_win=InpPurWin;
   g_cfg.vol_min=InpVolMin;
   g_cfg.evt_on=InpEvtOn;
   g_cfg.quiet_on=InpQuietOn;
   g_cfg.run=InpRun;
   g_cfg.lv_tol=InpLvTol;
   g_cfg.lv_fresh=InpLvFresh;
   g_cfg.test_r=InpTestR;
   g_cfg.retest_t=InpRetestT;
   g_cfg.atr_len=InpAtrLen;
   g_cfg.piv_len=InpPivLen;
   g_cfg.sos_spread=InpSosSpread;
   g_cfg.sos_vol=InpSosVol;
   g_cfg.lps_tol=InpLpsTol;
   g_cfg.sweep_req=InpSweepReq;
   g_cfg.sweep_win=InpSweepWin;
   g_cfg.clx_on=InpClxOn;
   g_cfg.clx_r=InpClxR;
   g_cfg.sl_buf=InpSlBuf;
   g_cfg.rr_fb=InpRrFb;
   g_cfg.fee_pct=InpFeePct;
   g_cfg.fee_max_r=InpFeeMaxR;
   LkNormalizeConfig(g_cfg);

   g_sess_offset=LkClampInt(InpSessionUtcOffsetMin,-720,840);
   if(InpSessionOn)
     {
      if(!LkParseSession(InpSession,g_sess_start,g_sess_end))
        {
         PrintFormat("LONGKACO|ERROR|bad_session|value=%s|expected=HHMM-HHMM",InpSession);
         return(INIT_PARAMETERS_INCORRECT);
        }
      g_sess_on=true;
     }

   SetIndexBuffer(0,g_plot_sv,INDICATOR_DATA);
   SetIndexBuffer(1,g_plot_bc,INDICATOR_DATA);
   SetIndexBuffer(2,g_plot_stl,INDICATOR_DATA);
   SetIndexBuffer(3,g_plot_sts,INDICATOR_DATA);
   SetIndexBuffer(4,g_plot_ns,INDICATOR_DATA);
   SetIndexBuffer(5,g_plot_nd,INDICATOR_DATA);
   SetIndexBuffer(6,g_plot_nosweep,INDICATOR_DATA);
   SetIndexBuffer(7,g_plot_clx,INDICATOR_DATA);
   SetIndexBuffer(LK_BUF_SV,g_buf_sv,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_BC,g_buf_bc,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_ST_LONG,g_buf_stl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_ST_SHORT,g_buf_sts,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_NS,g_buf_ns,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_ND,g_buf_nd,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_NO_SWEEP,g_buf_nosweep,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_CLX_E,g_buf_clx,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_TIM_BAR,g_buf_tim,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_VOL_RATIO,g_buf_ratio,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_VOL_MA,g_buf_volma,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_ATR,g_buf_atr,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_PIV_LOW,g_buf_pivlow,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_PIV_HIGH,g_buf_pivhigh,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_ENTRY,g_buf_entry,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_SL,g_buf_sl,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_TP,g_buf_tp,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_DIR,g_buf_dir,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_FILL,g_buf_fill,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_RESULT,g_buf_result,INDICATOR_CALCULATIONS);
   SetIndexBuffer(LK_BUF_LAST_EVENT,g_buf_lastevt,INDICATOR_CALCULATIONS);

   for(int plot=0; plot<8; plot++)
     {
      PlotIndexSetInteger(plot,PLOT_ARROW,233);
      PlotIndexSetInteger(plot,PLOT_ARROW_SHIFT,0);
      PlotIndexSetDouble(plot,PLOT_EMPTY_VALUE,EMPTY_VALUE);
     }
   PlotIndexSetInteger(1,PLOT_ARROW,234);
   PlotIndexSetInteger(3,PLOT_ARROW,234);
   PlotIndexSetInteger(5,PLOT_ARROW,234);
   PlotIndexSetInteger(6,PLOT_ARROW,234);
   PlotIndexSetInteger(7,PLOT_ARROW,251);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("LongKaco VSA %s v%s",
                                   LkStrategyTag(g_cfg),LK_CONTRACT_VERSION));
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);

   PrintFormat("LONGKACO|INFO|init|strategy=%s len=%d rP=%.2f atr=%d piv=%d sweep=%d/%d session=%d contract=%s hash=%s",
               LkStrategyTag(g_cfg),g_cfg.len,g_cfg.r_p,g_cfg.atr_len,g_cfg.piv_len,
               (int)g_cfg.sweep_req,g_cfg.sweep_win,(int)g_sess_on,
               LK_CONTRACT_VERSION,LkConfigHash(g_cfg,0));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   PrintFormat("LONGKACO|INFO|deinit|reason=%d",reason);
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

//--- Recompute the whole history once per new bar. Keeping Pine `var` state
//--- local makes closed-bar output a pure function of closed data (no RP2).
   if(prev_calculated==rates_total && rates_total==g_last_rates)
      return(rates_total);
   g_last_rates=rates_total;

   const int atr_len=g_cfg.atr_len;
   const int vol_len=g_cfg.len;
   const int piv_len=g_cfg.piv_len;
   const int run=g_cfg.run;
   const bool wyckoff=(g_cfg.signal_mode==LK_SIGNAL_WYCKOFF);
   const bool gate_on=(g_cfg.sweep_req && !wyckoff);
   const int gmt_offset=TimeGMTOffset();

   double tr_sum=0.0;
   double vol_sum=0.0;
   double atr_val=0.0;
   bool atr_ok=false;
   double vol_ma=0.0;
   bool vol_ma_ok=false;

   double last_pl=0.0;
   double last_ph=0.0;
   int plow_bar=0;
   int phigh_bar=0;
   bool has_pl=false;
   bool has_ph=false;

   int sv_bar=0;
   int bc_bar=0;
   double sv_px=0.0;
   double bc_px=0.0;
   bool has_sv=false;
   bool has_bc=false;

   int sweep_up_bl=-1;
   int sweep_dn_bl=-1;

   bool sos_done=false;
   bool sow_done=false;
   int sos_bar=0;
   int sow_bar=0;
   double sos_low=0.0;
   double sow_high=0.0;

   double lvl_e=0.0;
   double lvl_s=0.0;
   double lvl_t=0.0;
   double lvl_risk=0.0;
   int lvl_b=0;
   int lvl_dir=0;
   bool lvl_has=false;
   bool lvl_fill=false;
   bool lvl_done=false;
   int lvl_result=LK_RESULT_NONE;
   bool clx_e=false;
   int last_evt=LK_EVENT_NONE;

   for(int j=0; j<rates_total; j++)
     {
      const bool confirmed=(j<rates_total-1);
      const double bar_open=open[j];
      const double bar_high=high[j];
      const double bar_low=low[j];
      const double bar_close=close[j];
      const double bar_vol=(double)tick_volume[j];
      const double bar_range=bar_high-bar_low;

      //--- ATR: Pine ta.atr = RMA(ta.tr(true), len), seeded with SMA.
      double tr=bar_range;
      if(j>0)
        {
         const double prev_close=close[j-1];
         tr=MathMax(tr,MathMax(MathAbs(bar_high-prev_close),MathAbs(bar_low-prev_close)));
        }
      if(j<atr_len-1)
        {
         tr_sum+=tr;
         atr_ok=false;
        }
      else if(j==atr_len-1)
        {
         tr_sum+=tr;
         atr_val=tr_sum/(double)atr_len;
         atr_ok=true;
        }
      else
        {
         atr_val=LkRmaUpdate(atr_val,true,tr,atr_len);
         atr_ok=true;
        }

      //--- Volume Wilder RMA (Pine ta.rma(nz(volume), len)).
      if(j<vol_len-1)
        {
         vol_sum+=bar_vol;
         vol_ma_ok=false;
        }
      else if(j==vol_len-1)
        {
         vol_sum+=bar_vol;
         vol_ma=vol_sum/(double)vol_len;
         vol_ma_ok=true;
        }
      else
        {
         vol_ma=LkRmaUpdate(vol_ma,true,bar_vol,vol_len);
         vol_ma_ok=true;
        }

      const double ratio=LkVolumeRatio(bar_vol,vol_ma_ok ? vol_ma : 0.0);
      const bool session_ok=LkSessionOk(time[j],gmt_offset);
      const bool evt_ok=((g_cfg.vol_min<=0.0 || bar_vol>=g_cfg.vol_min) && session_ok);
      const bool purple=LkIsPurple(bar_vol,vol_ma_ok ? vol_ma : 0.0,g_cfg.r_p) && evt_ok;
      const bool quiet_st=LkIsQuietSt(bar_vol,vol_ma_ok ? vol_ma : 0.0,g_cfg.r_p,g_cfg.test_r) && evt_ok;
      const bool quiet_low=LkIsQuietLow(bar_vol,vol_ma_ok ? vol_ma : 0.0,g_cfg.r_n) && evt_ok;

      //--- Pivots are detected at the confirmation bar (Pine tm_plowBar semantics).
      if(j>=piv_len)
        {
         const int pivot_index=j-piv_len;
         if(LkIsPivotLow(low,pivot_index,piv_len,piv_len))
           {
            last_pl=low[pivot_index];
            plow_bar=j;
            has_pl=true;
           }
         if(LkIsPivotHigh(high,pivot_index,piv_len,piv_len))
           {
            last_ph=high[pivot_index];
            phigh_bar=j;
            has_ph=true;
           }
        }

      const bool low_fresh=(has_pl && (j-plow_bar)<=g_cfg.lv_fresh);
      const bool high_fresh=(has_ph && (j-phigh_bar)<=g_cfg.lv_fresh);
      const bool near_sup=(low_fresh && atr_ok && bar_low<=last_pl+g_cfg.lv_tol*atr_val);
      const bool near_res=(high_fresh && atr_ok && bar_high>=last_ph-g_cfg.lv_tol*atr_val);
      const bool run_down=(j>=run && bar_close<close[j-run]);
      const bool run_up=(j>=run && bar_close>close[j-run]);

      //--- Wyckoff events
      const bool strong_vol=(vol_ma_ok && vol_ma>0.0 && bar_vol>=vol_ma*g_cfg.sos_vol);
      const bool w_spring=(atr_ok && low_fresh && bar_low<last_pl &&
                           bar_close>last_pl && bar_close>bar_open);
      const bool w_utad=(atr_ok && high_fresh && bar_high>last_ph &&
                         bar_close<last_ph && bar_close<bar_open);
      const bool w_sos=(atr_ok && high_fresh && bar_close>last_ph &&
                        bar_range>=g_cfg.sos_spread*atr_val && strong_vol && bar_close>bar_open);
      const bool w_sow=(atr_ok && low_fresh && bar_close<last_pl &&
                        bar_range>=g_cfg.sos_spread*atr_val && strong_vol && bar_close<bar_open);

      if(w_sos)
        {
         sos_done=true;
         sos_bar=j;
         sos_low=bar_low;
        }
      if(w_sow)
        {
         sow_done=true;
         sow_bar=j;
         sow_high=bar_high;
        }

      const bool w_lps=(atr_ok && sos_done && j>sos_bar && bar_low>sos_low &&
                        bar_low<=sos_low+g_cfg.lps_tol*atr_val && bar_close>bar_open);
      const bool w_lpsy=(atr_ok && sow_done && j>sow_bar && bar_high<sow_high &&
                         bar_high>=sow_high-g_cfg.lps_tol*atr_val && bar_close<bar_open);

      const bool ev_long=(g_cfg.wyckoff_event==LK_WYCKOFF_SPRING ? w_spring :
                          (g_cfg.wyckoff_event==LK_WYCKOFF_SOS ? w_sos : w_lps));
      const bool ev_short=(g_cfg.wyckoff_event==LK_WYCKOFF_SPRING ? w_utad :
                           (g_cfg.wyckoff_event==LK_WYCKOFF_SOS ? w_sow : w_lpsy));

      //--- SV / BC (edge events, confirmed bar only)
      const bool sig_sv=(g_cfg.evt_on && confirmed && purple && run_down && near_sup &&
                         bar_high>bar_low && bar_close>bar_open);
      const bool sig_bc=(g_cfg.evt_on && confirmed && purple && run_up && near_res &&
                         bar_high>bar_low && (bar_high-bar_close)>=0.5*bar_range);

      if(sig_sv)
        {
         sv_bar=j;
         sv_px=bar_low;
         has_sv=true;
        }
      if(sig_bc)
        {
         bc_bar=j;
         bc_px=bar_high;
         has_bc=true;
        }

      const bool sv_fresh=(has_sv && (j-sv_bar)<=g_cfg.lv_fresh);
      const bool bc_fresh=(has_bc && (j-bc_bar)<=g_cfg.lv_fresh);

      //--- Sweep gate (A-P0-1)
      const bool sweep_up_bar=(has_sv && bar_low<sv_px && bar_close>sv_px);
      const bool sweep_dn_bar=(has_bc && bar_high>bc_px && bar_close<bc_px);
      if(sweep_up_bar)
         sweep_up_bl=j;
      if(sweep_dn_bar)
         sweep_dn_bl=j;

      const bool sweep_l=(has_sv && sweep_up_bl>=0 && sweep_up_bl>=sv_bar &&
                          LkSweepRecent(sweep_up_bl,j,g_cfg.sweep_win));
      const bool sweep_s=(has_bc && sweep_dn_bl>=0 && sweep_dn_bl>=bc_bar &&
                          LkSweepRecent(sweep_dn_bl,j,g_cfg.sweep_win));

      //--- Secondary Test
      const bool st_raw_l=(g_cfg.evt_on && confirmed &&
                           (wyckoff ? (ev_long && sv_fresh)
                                    : (atr_ok && sv_fresh && quiet_st &&
                                       MathAbs(bar_low-sv_px)<=g_cfg.retest_t*atr_val &&
                                       bar_close>bar_open)));
      const bool st_raw_s=(g_cfg.evt_on && confirmed &&
                           (wyckoff ? (ev_short && bc_fresh)
                                    : (atr_ok && bc_fresh && quiet_st &&
                                       MathAbs(bar_high-bc_px)<=g_cfg.retest_t*atr_val &&
                                       bar_close<bar_open)));
      const bool st_l=(st_raw_l && (!gate_on || sweep_l));
      const bool st_s=(st_raw_s && (!gate_on || sweep_s));
      const bool no_sweep=(gate_on &&
                           ((st_raw_l && !sweep_l) || (st_raw_s && !sweep_s)));

      //--- Measured-move sources (run + 1 bars, no future data)
      double low_run1=0.0;
      double high_run1=0.0;
      bool run_window=false;
      if(j>=run)
        {
         low_run1=low[j-run];
         high_run1=high[j-run];
         for(int k=j-run+1; k<=j; k++)
           {
            low_run1=MathMin(low_run1,low[k]);
            high_run1=MathMax(high_run1,high[k]);
           }
         run_window=true;
        }
      const double mm_up=(has_ph && run_window) ? last_ph-low_run1 : 0.0;
      const double mm_dn=(has_pl && run_window) ? high_run1-last_pl : 0.0;

      //--- Setup levels (latest ST replaces the previous setup)
      if(st_l && has_sv)
        {
         double entry=0.0;
         double sl=0.0;
         double tp=0.0;
         if(LkSetupLong(g_cfg,bar_close,bar_low,sv_px,atr_val,
                        has_ph,last_ph,high_fresh,mm_up,entry,sl,tp))
           {
            lvl_e=entry;
            lvl_s=sl;
            lvl_t=tp;
            lvl_b=j;
            lvl_dir=1;
            lvl_has=true;
            lvl_done=false;
            lvl_result=LK_RESULT_OPEN;
            lvl_fill=(g_cfg.entry_mode==LK_ENTRY_MARKET || wyckoff);
            lvl_risk=entry-sl;
           }
        }
      if(st_s && has_bc)
        {
         double entry=0.0;
         double sl=0.0;
         double tp=0.0;
         if(LkSetupShort(g_cfg,bar_close,bar_high,bc_px,atr_val,
                         has_pl,last_pl,low_fresh,mm_dn,entry,sl,tp))
           {
            lvl_e=entry;
            lvl_s=sl;
            lvl_t=tp;
            lvl_b=j;
            lvl_dir=-1;
            lvl_has=true;
            lvl_done=false;
            lvl_result=LK_RESULT_OPEN;
            lvl_fill=(g_cfg.entry_mode==LK_ENTRY_MARKET || wyckoff);
            lvl_risk=sl-entry;
           }
        }

      //--- Fill first, then SL before TP; never before the bar after the setup.
      if(lvl_has && !lvl_done && j>lvl_b)
        {
         const int res=LkTrackSetup(lvl_dir,lvl_fill,lvl_e,lvl_s,lvl_t,bar_low,bar_high);
         if(res==LK_RESULT_TP)
           {
            lvl_done=true;
            lvl_result=LK_RESULT_TP;
           }
         else if(res==LK_RESULT_SL)
           {
            lvl_done=true;
            lvl_result=LK_RESULT_SL;
           }
        }

      //--- CLX-E (state, resets only on a new ST; clx_on is render-only)
      if(st_l || st_s)
         clx_e=false;
      if(purple && !lvl_done && lvl_has && lvl_risk>0.0)
        {
         if(LkClxTrigger(lvl_dir,bar_high,bar_low,lvl_e,lvl_risk,g_cfg.clx_r))
            clx_e=true;
        }

      //--- No Supply / No Demand
      const bool sig_ns=(g_cfg.quiet_on && confirmed && quiet_low && near_sup && bar_close>bar_open);
      const bool sig_nd=(g_cfg.quiet_on && confirmed && quiet_low && near_res && bar_close<bar_open);

      int event=LK_EVENT_NONE;
      if(sig_sv)
         event=LK_EVENT_SV;
      else if(sig_bc)
         event=LK_EVENT_BC;
      else if(st_l || st_s)
         event=LK_EVENT_ST;
      else if(sig_ns)
         event=LK_EVENT_NS;
      else if(sig_nd)
         event=LK_EVENT_ND;
      if(event!=LK_EVENT_NONE)
         last_evt=event;

      //--- Render buffers
      g_plot_sv[j]=(sig_sv ? bar_low : EMPTY_VALUE);
      g_plot_bc[j]=(sig_bc ? bar_high : EMPTY_VALUE);
      g_plot_stl[j]=(st_l ? bar_low : EMPTY_VALUE);
      g_plot_sts[j]=(st_s ? bar_high : EMPTY_VALUE);
      g_plot_ns[j]=(sig_ns ? bar_low : EMPTY_VALUE);
      g_plot_nd[j]=(sig_nd ? bar_high : EMPTY_VALUE);
      g_plot_nosweep[j]=(no_sweep ? bar_high : EMPTY_VALUE);
      if(clx_e && confirmed && lvl_dir==1)
         g_plot_clx[j]=bar_high;
      else if(clx_e && confirmed && lvl_dir==-1)
         g_plot_clx[j]=bar_low;
      else
         g_plot_clx[j]=EMPTY_VALUE;

      //--- Contract buffers
      g_buf_sv[j]=(sig_sv ? 1.0 : 0.0);
      g_buf_bc[j]=(sig_bc ? 1.0 : 0.0);
      g_buf_stl[j]=(st_l ? 1.0 : 0.0);
      g_buf_sts[j]=(st_s ? 1.0 : 0.0);
      g_buf_ns[j]=(sig_ns ? 1.0 : 0.0);
      g_buf_nd[j]=(sig_nd ? 1.0 : 0.0);
      g_buf_nosweep[j]=(no_sweep ? 1.0 : 0.0);
      g_buf_clx[j]=((clx_e && confirmed) ? 1.0 : 0.0);
      g_buf_tim[j]=(purple ? 1.0 : 0.0);
      g_buf_ratio[j]=ratio;
      g_buf_volma[j]=(vol_ma_ok ? vol_ma : EMPTY_VALUE);
      g_buf_atr[j]=(atr_ok ? atr_val : EMPTY_VALUE);
      g_buf_pivlow[j]=(has_pl ? last_pl : EMPTY_VALUE);
      g_buf_pivhigh[j]=(has_ph ? last_ph : EMPTY_VALUE);
      g_buf_entry[j]=(lvl_has ? lvl_e : EMPTY_VALUE);
      g_buf_sl[j]=(lvl_has ? lvl_s : EMPTY_VALUE);
      g_buf_tp[j]=(lvl_has ? lvl_t : EMPTY_VALUE);
      g_buf_dir[j]=(double)lvl_dir;
      g_buf_fill[j]=(lvl_fill ? 1.0 : 0.0);
      g_buf_result[j]=(double)lvl_result;
      g_buf_lastevt[j]=(double)last_evt;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
