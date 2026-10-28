//+------------------------------------------------------------------+
//|                                      LongKacoVSAContract.mqh    |
//|     MT5 EA & AI Lab - PinePort buffer contract and pure logic    |
//|                                                                  |
//| No file I/O, no account access, no trading functions.            |
//| Contract: docs/indicators/longkaco-vsa.md                     |
//+------------------------------------------------------------------+
#ifndef LONGKACO_VSA_CONTRACT_MQH
#define LONGKACO_VSA_CONTRACT_MQH

#define LK_CONTRACT_VERSION "1.0.0"
#define LK_PLOT_BUFFERS      8
#define LK_BUFFER_COUNT      21
#define LK_TOTAL_BUFFERS     29

enum ENUM_LK_SIGNAL_MODE
  {
   LK_SIGNAL_VSA      = 0,  // VSA dao chieu
   LK_SIGNAL_WYCKOFF  = 1   // VSA loc + Wyckoff
  };

enum ENUM_LK_WYCKOFF_EVENT
  {
   LK_WYCKOFF_SPRING = 0,
   LK_WYCKOFF_SOS    = 1,
   LK_WYCKOFF_LPS    = 2
  };

enum ENUM_LK_ENTRY_MODE
  {
   LK_ENTRY_MARKET = 0,     // Market tai close bar ST
   LK_ENTRY_LIMIT  = 1      // Limit tai cuc tri SV/BC
  };

enum ENUM_LK_TP_MODE
  {
   LK_TP_R      = 0,        // rrFb x R
   LK_TP_PIVOT  = 1,        // Pivot doi dien
   LK_TP_MM     = 2         // Measured move
  };

enum ENUM_LK_BUCKET
  {
   LK_BUCKET_VERY_LOW  = 0,
   LK_BUCKET_LOW       = 1,
   LK_BUCKET_NORMAL    = 2,
   LK_BUCKET_HIGH      = 3,
   LK_BUCKET_VERY_HIGH = 4,
   LK_BUCKET_TIM       = 5
  };

enum ENUM_LK_RESULT
  {
   LK_RESULT_NONE = 0,
   LK_RESULT_OPEN = 1,
   LK_RESULT_TP   = 2,
   LK_RESULT_SL   = 3
  };

enum ENUM_LK_EVENT
  {
   LK_EVENT_NONE = 0,
   LK_EVENT_SV   = 1,
   LK_EVENT_BC   = 2,
   LK_EVENT_ST   = 3,
   LK_EVENT_NS   = 4,
   LK_EVENT_ND   = 5
  };

//--- Buffers 0..7 are render-only price markers (plots 0..7).
//--- Contract buffers start at 8; EA reads these by name.
enum ENUM_LK_BUFFER
  {
   LK_BUF_SV          = 8,
   LK_BUF_BC          = 9,
   LK_BUF_ST_LONG     = 10,
   LK_BUF_ST_SHORT    = 11,
   LK_BUF_NS          = 12,
   LK_BUF_ND          = 13,
   LK_BUF_NO_SWEEP    = 14,
   LK_BUF_CLX_E       = 15,
   LK_BUF_TIM_BAR     = 16,
   LK_BUF_VOL_RATIO   = 17,
   LK_BUF_VOL_MA      = 18,
   LK_BUF_ATR         = 19,
   LK_BUF_PIV_LOW     = 20,
   LK_BUF_PIV_HIGH    = 21,
   LK_BUF_ENTRY       = 22,
   LK_BUF_SL          = 23,
   LK_BUF_TP          = 24,
   LK_BUF_DIR         = 25,
   LK_BUF_FILL        = 26,
   LK_BUF_RESULT      = 27,
   LK_BUF_LAST_EVENT  = 28
  };

struct LkConfig
  {
   ENUM_LK_SIGNAL_MODE     signal_mode;
   ENUM_LK_WYCKOFF_EVENT   wyckoff_event;
   ENUM_LK_ENTRY_MODE      entry_mode;
   ENUM_LK_TP_MODE         tp_mode;
   int                     len;
   double                  r_p;
   double                  r_vh;
   double                  r_h;
   double                  r_n;
   double                  r_l;
   int                     pur_win;
   double                  vol_min;
   bool                    evt_on;
   bool                    quiet_on;
   int                     run;
   double                  lv_tol;
   int                     lv_fresh;
   double                  test_r;
   double                  retest_t;
   int                     atr_len;
   int                     piv_len;
   double                  sos_spread;
   double                  sos_vol;
   double                  lps_tol;
   bool                    sweep_req;
   int                     sweep_win;
   bool                    clx_on;
   double                  clx_r;
   double                  sl_buf;
   double                  rr_fb;
   double                  fee_pct;
   double                  fee_max_r;
  };

int LkClampInt(const int value,const int low,const int high)
  {
   return((int)MathMax((double)low,MathMin((double)high,(double)value)));
  }

double LkClampDouble(const double value,const double low,const double high)
  {
   return(MathMax(low,MathMin(high,value)));
  }

//--- Clamp exactly like the Pine input min/max declarations.
void LkNormalizeConfig(LkConfig &cfg)
  {
   cfg.len=LkClampInt(cfg.len,5,100);
   cfg.r_p=MathMax(1.5,cfg.r_p);
   cfg.r_vh=MathMax(1.0,cfg.r_vh);
   cfg.r_h=MathMax(0.8,cfg.r_h);
   cfg.r_n=MathMax(0.4,cfg.r_n);
   cfg.r_l=MathMax(0.1,cfg.r_l);
   cfg.pur_win=LkClampInt(cfg.pur_win,5,100);
   cfg.vol_min=MathMax(0.0,cfg.vol_min);
   cfg.run=LkClampInt(cfg.run,1,50);
   cfg.lv_tol=MathMax(0.1,cfg.lv_tol);
   cfg.lv_fresh=LkClampInt(cfg.lv_fresh,10,500);
   cfg.test_r=LkClampDouble(cfg.test_r,0.3,2.0);
   cfg.retest_t=MathMax(0.2,cfg.retest_t);
   cfg.atr_len=LkClampInt(cfg.atr_len,2,100);
   cfg.piv_len=LkClampInt(cfg.piv_len,5,100);
   cfg.sos_spread=MathMax(0.2,cfg.sos_spread);
   cfg.sos_vol=MathMax(0.5,cfg.sos_vol);
   cfg.lps_tol=MathMax(0.1,cfg.lps_tol);
   cfg.sweep_win=LkClampInt(cfg.sweep_win,0,100);
   cfg.clx_r=MathMax(0.5,cfg.clx_r);
   cfg.sl_buf=MathMax(0.1,cfg.sl_buf);
   cfg.rr_fb=MathMax(0.5,cfg.rr_fb);
   cfg.fee_pct=MathMax(0.0,cfg.fee_pct);
   cfg.fee_max_r=MathMax(0.01,cfg.fee_max_r);
  }

string LkSignalModeName(const ENUM_LK_SIGNAL_MODE mode)
  {
   return(mode==LK_SIGNAL_WYCKOFF ? "WYCKOFF" : "VSA");
  }

string LkWyckoffEventName(const ENUM_LK_WYCKOFF_EVENT event)
  {
   switch(event)
     {
      case LK_WYCKOFF_SPRING: return("SPRING");
      case LK_WYCKOFF_SOS:    return("SOS");
      case LK_WYCKOFF_LPS:    return("LPS");
     }
   return("UNKNOWN");
  }

//--- CSV "mode" column: VSA or WYCKOFF_<event>.
string LkStrategyTag(const LkConfig &cfg)
  {
   if(cfg.signal_mode!=LK_SIGNAL_WYCKOFF)
      return("VSA");
   return("WYCKOFF_"+LkWyckoffEventName(cfg.wyckoff_event));
  }

string LkEventName(const ENUM_LK_EVENT event)
  {
   switch(event)
     {
      case LK_EVENT_SV: return("SV");
      case LK_EVENT_BC: return("BC");
      case LK_EVENT_ST: return("ST");
      case LK_EVENT_NS: return("NS");
      case LK_EVENT_ND: return("ND");
     }
   return("NONE");
  }

//--- Wilder RMA step. The caller seeds the first value with a plain SMA.
double LkRmaUpdate(const double prev,const bool has_prev,const double src,const int len)
  {
   if(len<=1)
      return(src);
   if(!has_prev)
      return(src);
   return((prev*(double)(len-1)+src)/(double)len);
  }

double LkVolumeRatio(const double vol,const double vol_ma)
  {
   if(!MathIsValidNumber(vol_ma) || vol_ma<=0.0)
      return(0.0);
   return(vol/vol_ma);
  }

bool LkIsPurple(const double vol,const double vol_ma,const double r_p)
  {
   return(MathIsValidNumber(vol_ma) && vol_ma>0.0 && vol>=vol_ma*r_p);
  }

//--- tm_quietST: below test_r AND below the raw TIM threshold.
bool LkIsQuietSt(const double vol,const double vol_ma,const double r_p,const double test_r)
  {
   if(!MathIsValidNumber(vol_ma) || vol_ma<=0.0)
      return(false);
   return(vol<vol_ma*test_r && vol<vol_ma*r_p);
  }

bool LkIsQuietLow(const double vol,const double vol_ma,const double r_n)
  {
   if(!MathIsValidNumber(vol_ma) || vol_ma<=0.0)
      return(false);
   return(vol<vol_ma*r_n);
  }

ENUM_LK_BUCKET LkBucket(const double vol,const double vol_ma,const double r_p,
                        const double r_vh,const double r_h,const double r_n,const double r_l)
  {
   if(!MathIsValidNumber(vol_ma) || vol_ma<=0.0)
      return(LK_BUCKET_VERY_LOW);
   if(vol>=vol_ma*r_p)  return(LK_BUCKET_TIM);
   if(vol>=vol_ma*r_vh) return(LK_BUCKET_VERY_HIGH);
   if(vol>=vol_ma*r_h)  return(LK_BUCKET_HIGH);
   if(vol>=vol_ma*r_n)  return(LK_BUCKET_NORMAL);
   if(vol>=vol_ma*r_l)  return(LK_BUCKET_LOW);
   return(LK_BUCKET_VERY_LOW);
  }

string LkBucketName(const ENUM_LK_BUCKET bucket)
  {
   switch(bucket)
     {
      case LK_BUCKET_TIM:       return("TIM");
      case LK_BUCKET_VERY_HIGH: return("VeryHigh");
      case LK_BUCKET_HIGH:      return("High");
      case LK_BUCKET_NORMAL:    return("Normal");
      case LK_BUCKET_LOW:       return("Low");
     }
   return("VeryLow");
  }

//--- sweep_bar < 0 means "never swept" (Pine na).
int LkSweepAge(const int sweep_bar,const int bar_index)
  {
   return(sweep_bar<0 ? -1 : bar_index-sweep_bar);
  }

bool LkSweepRecent(const int sweep_bar,const int bar_index,const int max_bars)
  {
   if(sweep_bar<0)
      return(false);
   return(max_bars<=0 || (bar_index-sweep_bar)<=max_bars);
  }

//--- Pivot detection with ties allowed (equal neighbour is not "lower").
bool LkIsPivotLow(const double &src[],const int pivot_index,const int left,const int right)
  {
   const int n=ArraySize(src);
   if(left<0 || right<0 || pivot_index<0 || pivot_index>=n)
      return(false);
   if(pivot_index-left<0 || pivot_index+right>=n)
      return(false);
   const double value=src[pivot_index];
   for(int k=pivot_index-left; k<=pivot_index+right; k++)
      if(k!=pivot_index && src[k]<value)
         return(false);
   return(true);
  }

bool LkIsPivotHigh(const double &src[],const int pivot_index,const int left,const int right)
  {
   const int n=ArraySize(src);
   if(left<0 || right<0 || pivot_index<0 || pivot_index>=n)
      return(false);
   if(pivot_index-left<0 || pivot_index+right>=n)
      return(false);
   const double value=src[pivot_index];
   for(int k=pivot_index-left; k<=pivot_index+right; k++)
      if(k!=pivot_index && src[k]>value)
         return(false);
   return(true);
  }

//--- Entry / SL / TP. Returns false when risk <= 0 (Pine drops the setup).
bool LkSetupLong(const LkConfig &cfg,const double close_val,const double low_val,
                 const double sv_px,const double atr,
                 const bool piv_high_valid,const double last_piv_high,
                 const bool piv_high_fresh,const double mm_up,
                 double &entry,double &sl,double &tp)
  {
   const bool market=(cfg.entry_mode==LK_ENTRY_MARKET) || (cfg.signal_mode==LK_SIGNAL_WYCKOFF);
   entry=market ? close_val : sv_px;
   sl=((cfg.signal_mode==LK_SIGNAL_WYCKOFF) ? low_val : sv_px)-cfg.sl_buf*atr;
   const double risk=entry-sl;
   const double tp_r=entry+cfg.rr_fb*risk;
   const double tp_pv=(piv_high_valid && last_piv_high>=entry+risk) ? last_piv_high : tp_r;
   const double tp_mm=(piv_high_fresh && mm_up>risk) ? entry+mm_up : tp_r;
   if(cfg.tp_mode==LK_TP_R)
      tp=tp_r;
   else if(cfg.tp_mode==LK_TP_MM)
      tp=tp_mm;
   else
      tp=tp_pv;
   return(risk>0.0);
  }

bool LkSetupShort(const LkConfig &cfg,const double close_val,const double high_val,
                  const double bc_px,const double atr,
                  const bool piv_low_valid,const double last_piv_low,
                  const bool piv_low_fresh,const double mm_dn,
                  double &entry,double &sl,double &tp)
  {
   const bool market=(cfg.entry_mode==LK_ENTRY_MARKET) || (cfg.signal_mode==LK_SIGNAL_WYCKOFF);
   entry=market ? close_val : bc_px;
   sl=((cfg.signal_mode==LK_SIGNAL_WYCKOFF) ? high_val : bc_px)+cfg.sl_buf*atr;
   const double risk=sl-entry;
   const double tp_r=entry-cfg.rr_fb*risk;
   const double tp_pv=(piv_low_valid && last_piv_low<=entry-risk) ? last_piv_low : tp_r;
   const double tp_mm=(piv_low_fresh && mm_dn>risk) ? entry-mm_dn : tp_r;
   if(cfg.tp_mode==LK_TP_R)
      tp=tp_r;
   else if(cfg.tp_mode==LK_TP_MM)
      tp=tp_mm;
   else
      tp=tp_pv;
   return(risk>0.0);
  }

//--- Fill check first, then SL before TP (Pine order). Mutates filled.
int LkTrackSetup(const int dir,bool &filled,
                 const double entry,const double sl,const double tp,
                 const double bar_low,const double bar_high)
  {
   if(dir==0)
      return(LK_RESULT_NONE);
   if(!filled)
     {
      if(dir==1 && bar_low<=entry)
         filled=true;
      else if(dir==-1 && bar_high>=entry)
         filled=true;
     }
   if(!filled)
      return(LK_RESULT_OPEN);
   if(dir==1)
     {
      if(bar_low<=sl)
         return(LK_RESULT_SL);
      if(bar_high>=tp)
         return(LK_RESULT_TP);
     }
   else
     {
      if(bar_high>=sl)
         return(LK_RESULT_SL);
      if(bar_low<=tp)
         return(LK_RESULT_TP);
     }
   return(LK_RESULT_OPEN);
  }

bool LkClxTrigger(const int dir,const double bar_high,const double bar_low,
                  const double entry,const double risk,const double clx_r)
  {
   if(dir==0 || risk<=0.0 || !MathIsValidNumber(risk))
      return(false);
   if(dir==1)
      return(bar_high>=entry+clx_r*risk);
   if(dir==-1)
      return(bar_low<=entry-clx_r*risk);
   return(false);
  }

string LkConfigCanonical(const LkConfig &cfg,const int warmup_bars)
  {
   return(StringFormat("v=%s|sm=%d|we=%d|em=%d|tm=%d|len=%d|rP=%.6f|rVH=%.6f|rH=%.6f|rN=%.6f|rL=%.6f|pw=%d|vm=%.6f|ev=%d|q=%d|run=%d|lt=%.6f|lf=%d|tr=%.6f|rt=%.6f|al=%d|pl=%d|ss=%.6f|sv=%.6f|lps=%.6f|sr=%d|sw=%d|cr=%.6f|sb=%.6f|rr=%.6f|fp=%.6f|fm=%.6f|wu=%d",
                       LK_CONTRACT_VERSION,
                       (int)cfg.signal_mode,(int)cfg.wyckoff_event,
                       (int)cfg.entry_mode,(int)cfg.tp_mode,
                       cfg.len,cfg.r_p,cfg.r_vh,cfg.r_h,cfg.r_n,cfg.r_l,
                       cfg.pur_win,cfg.vol_min,(int)cfg.evt_on,(int)cfg.quiet_on,
                       cfg.run,cfg.lv_tol,cfg.lv_fresh,cfg.test_r,cfg.retest_t,
                       cfg.atr_len,cfg.piv_len,cfg.sos_spread,cfg.sos_vol,cfg.lps_tol,
                       (int)cfg.sweep_req,cfg.sweep_win,cfg.clx_r,cfg.sl_buf,
                       cfg.rr_fb,cfg.fee_pct,cfg.fee_max_r,warmup_bars));
  }

string LkConfigHash(const LkConfig &cfg,const int warmup_bars)
  {
   const string canonical=LkConfigCanonical(cfg,warmup_bars);
   uint hash=(uint)2166136261;
   for(int i=0; i<StringLen(canonical); i++)
     {
      hash^=(uint)(StringGetCharacter(canonical,i)&0xFF);
      hash=(uint)(hash*(uint)16777619);
     }
   return(StringFormat("%08X",(int)hash));
  }

#endif // LONGKACO_VSA_CONTRACT_MQH
