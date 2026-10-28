//+------------------------------------------------------------------+
//|                                        WonderwhalesContract.mqh |
//|     MT5 EA & AI Lab - PinePort buffer contract and pure logic   |
//|                                                                  |
//| No file I/O, no account access, no trading functions.            |
//| Contract: docs/indicators/wonderwhales.md                   |
//+------------------------------------------------------------------+
#ifndef WONDERWHALES_CONTRACT_MQH
#define WONDERWHALES_CONTRACT_MQH

#define WW_CONTRACT_VERSION "1.0.0"
#define WW_BUFFER_COUNT      18

enum ENUM_WW_MODE
  {
   WW_MODE_SAR          = 0,  // Parabolic SAR Reversal
   WW_MODE_EMA          = 1,  // EMA Crossover
   WW_MODE_SAR_EMA      = 2,  // SAR + EMA Trend Filter
   WW_MODE_SAR_EMA_ATR  = 3   // SAR + EMA + ATR Filter
  };

enum ENUM_WW_BUFFER
  {
   WW_BUF_PSAR         = 0,
   WW_BUF_BUY_MARKER   = 1,
   WW_BUF_SELL_MARKER  = 2,
   WW_BUF_BUY_SIGNAL   = 3,
   WW_BUF_SELL_SIGNAL  = 4,
   WW_BUF_SAR_DIR      = 5,
   WW_BUF_BLOCKED_BUY  = 6,
   WW_BUF_BLOCKED_SELL = 7,
   WW_BUF_ATR_PCT      = 8,
   WW_BUF_FAST_EMA     = 9,
   WW_BUF_SLOW_EMA     = 10,
   WW_BUF_EMA200       = 11,
   WW_BUF_RSI          = 12,
   WW_BUF_BB_UPPER     = 13,
   WW_BUF_BB_MID       = 14,
   WW_BUF_BB_LOWER     = 15,
   WW_BUF_VOL_MA       = 16,
   WW_BUF_VOL_RATIO    = 17
  };

struct WwConfig
  {
   ENUM_WW_MODE      mode;
   double            psar_start;
   double            psar_inc;
   double            psar_max;
   int               fast_ema;
   int               slow_ema;
   int               ema200;
   int               atr_len;
   double            min_atr_pct;
   int               vol_ma_len;
   int               rsi_len;
   int               bb_len;
   double            bb_mult;
  };

struct WwBarInput
  {
   bool              psar_valid;
   double            psar;
   double            close;
   bool              ema_now_valid;
   bool              ema_prev_valid;
   double            fast_prev;
   double            slow_prev;
   double            fast_now;
   double            slow_now;
   double            atr_pct;
  };

struct WwBarOutput
  {
   int               sar_dir;
   bool              buy_flip;
   bool              sell_flip;
   bool              ema_cross_up;
   bool              ema_cross_down;
   bool              valid_buy;
   bool              valid_sell;
   bool              blocked_buy;
   bool              blocked_sell;
   bool              signal_buy;
   bool              signal_sell;
   bool              signal_blocked_buy;
   bool              signal_blocked_sell;
  };

//--- Clamp exactly like Pine lines 129-142.
void WwNormalizeConfig(WwConfig &cfg)
  {
   cfg.psar_max=MathMax(cfg.psar_start,cfg.psar_max);
   cfg.fast_ema=(int)MathMax(1,cfg.fast_ema);
   cfg.slow_ema=(int)MathMax(cfg.fast_ema+1,cfg.slow_ema);
   cfg.ema200=(int)MathMax(10,cfg.ema200);
   cfg.atr_len=(int)MathMax(1,cfg.atr_len);
   cfg.vol_ma_len=(int)MathMax(1,cfg.vol_ma_len);
   cfg.rsi_len=(int)MathMax(1,cfg.rsi_len);
   cfg.bb_len=(int)MathMax(1,cfg.bb_len);
  }

string WwModeName(const ENUM_WW_MODE mode)
  {
   switch(mode)
     {
      case WW_MODE_SAR:         return("SAR");
      case WW_MODE_EMA:         return("EMA");
      case WW_MODE_SAR_EMA:     return("SAR_EMA");
      case WW_MODE_SAR_EMA_ATR: return("SAR_EMA_ATR");
     }
   return("UNKNOWN");
  }

string WwSignalId(const ENUM_WW_MODE mode,const bool is_buy)
  {
   if(is_buy)
     {
      switch(mode)
        {
         case WW_MODE_SAR:         return("WW_BUY_SAR_FLIP");
         case WW_MODE_EMA:         return("WW_BUY_EMA_CROSS");
         case WW_MODE_SAR_EMA:     return("WW_BUY_SAR_EMA");
         case WW_MODE_SAR_EMA_ATR: return("WW_BUY_SAR_EMA_ATR");
        }
      return("WW_BUY_UNKNOWN");
     }

   switch(mode)
     {
      case WW_MODE_SAR:         return("WW_SELL_SAR_FLIP");
      case WW_MODE_EMA:         return("WW_SELL_EMA_CROSS");
      case WW_MODE_SAR_EMA:     return("WW_SELL_SAR_EMA");
      case WW_MODE_SAR_EMA_ATR: return("WW_SELL_SAR_EMA_ATR");
     }
   return("WW_SELL_UNKNOWN");
  }

//--- Direction: invalid PSAR keeps the previous direction; equality is bearish.
int WwDirFromPsar(const bool psar_valid,const double psar,const double close,
                  const int dir_prev)
  {
   if(!psar_valid || !MathIsValidNumber(close) || close<=0.0)
      return(dir_prev);
   return(psar<close ? 1 : -1);
  }

bool WwIsBuyFlip(const int dir,const int dir_prev)
  {
   return(dir==1 && dir_prev==-1);
  }

bool WwIsSellFlip(const int dir,const int dir_prev)
  {
   return(dir==-1 && dir_prev==1);
  }

bool WwEmaCrossUp(const bool valid,const double fast_prev,const double slow_prev,
                  const double fast_now,const double slow_now)
  {
   if(!valid)
      return(false);
   return(fast_prev<=slow_prev && fast_now>slow_now);
  }

bool WwEmaCrossDown(const bool valid,const double fast_prev,const double slow_prev,
                    const double fast_now,const double slow_now)
  {
   if(!valid)
      return(false);
   return(fast_prev>=slow_prev && fast_now<slow_now);
  }

double WwAtrPct(const bool ready,const double atr,const double close_val)
  {
   if(!ready || close_val<=0.0 || !MathIsValidNumber(atr))
      return(0.0);
   return((atr/close_val)*100.0);
  }

double WwVolRatio(const bool ready,const double vol,const double vol_ma)
  {
   if(!ready || vol_ma<=0.0)
      return(0.0);
   return(vol/vol_ma);
  }

//--- Mode gate. raw_* is the mode-specific trigger (flip or crossover).
void WwApplyMode(const ENUM_WW_MODE mode,
                 const bool raw_buy,const bool raw_sell,
                 const bool ema_bull,const bool ema_bear,const bool atr_ok,
                 bool &valid_buy,bool &valid_sell,
                 bool &blocked_buy,bool &blocked_sell)
  {
   valid_buy=false;
   valid_sell=false;
   blocked_buy=false;
   blocked_sell=false;

   if(mode==WW_MODE_SAR)
     {
      valid_buy=raw_buy;
      valid_sell=raw_sell;
      return;
     }

   if(mode==WW_MODE_EMA)
     {
      valid_buy=raw_buy;
      valid_sell=raw_sell;
      return;
     }

   if(mode==WW_MODE_SAR_EMA)
     {
      valid_buy=raw_buy && ema_bull;
      valid_sell=raw_sell && ema_bear;
      blocked_buy=raw_buy && !ema_bull;
      blocked_sell=raw_sell && !ema_bear;
      return;
     }

   valid_buy=raw_buy && ema_bull && atr_ok;
   valid_sell=raw_sell && ema_bear && atr_ok;
   blocked_buy=raw_buy && !(ema_bull && atr_ok);
   blocked_sell=raw_sell && !(ema_bear && atr_ok);
  }

void WwEvaluateBar(const WwConfig &cfg,const WwBarInput &in,const int dir_prev,
                   const bool confirmed,WwBarOutput &out)
  {
   out.sar_dir=WwDirFromPsar(in.psar_valid,in.psar,in.close,dir_prev);
   out.buy_flip=WwIsBuyFlip(out.sar_dir,dir_prev);
   out.sell_flip=WwIsSellFlip(out.sar_dir,dir_prev);

   const bool ema_both=in.ema_now_valid && in.ema_prev_valid;
   out.ema_cross_up=WwEmaCrossUp(ema_both,in.fast_prev,in.slow_prev,
                                 in.fast_now,in.slow_now);
   out.ema_cross_down=WwEmaCrossDown(ema_both,in.fast_prev,in.slow_prev,
                                     in.fast_now,in.slow_now);

   const bool ema_bull=in.ema_now_valid && in.fast_now>in.slow_now;
   const bool ema_bear=in.ema_now_valid && in.fast_now<in.slow_now;
   const bool atr_ok=(in.atr_pct>=cfg.min_atr_pct);

   bool raw_buy=false;
   bool raw_sell=false;
   if(cfg.mode==WW_MODE_EMA)
     {
      raw_buy=out.ema_cross_up;
      raw_sell=out.ema_cross_down;
     }
   else
     {
      raw_buy=out.buy_flip;
      raw_sell=out.sell_flip;
     }

   WwApplyMode(cfg.mode,raw_buy,raw_sell,ema_bull,ema_bear,atr_ok,
               out.valid_buy,out.valid_sell,out.blocked_buy,out.blocked_sell);

   out.signal_buy=out.valid_buy && confirmed;
   out.signal_sell=out.valid_sell && confirmed;
   out.signal_blocked_buy=out.blocked_buy && confirmed;
   out.signal_blocked_sell=out.blocked_sell && confirmed;
  }

string WwConfigCanonical(const WwConfig &cfg,const int warmup_bars)
  {
   return(StringFormat("v=%s|m=%d|ps=%.6f|pi=%.6f|pm=%.6f|fe=%d|se=%d|e2=%d|al=%d|am=%.6f|vm=%d|rl=%d|bl=%d|bm=%.6f|wu=%d",
                       WW_CONTRACT_VERSION,(int)cfg.mode,
                       cfg.psar_start,cfg.psar_inc,cfg.psar_max,
                       cfg.fast_ema,cfg.slow_ema,cfg.ema200,
                       cfg.atr_len,cfg.min_atr_pct,
                       cfg.vol_ma_len,cfg.rsi_len,cfg.bb_len,
                       cfg.bb_mult,warmup_bars));
  }

string WwConfigHash(const WwConfig &cfg,const int warmup_bars)
  {
   const string canonical=WwConfigCanonical(cfg,warmup_bars);
   uint hash=(uint)2166136261;
   for(int i=0; i<StringLen(canonical); i++)
     {
      hash^=(uint)(StringGetCharacter(canonical,i)&0xFF);
      hash=(uint)(hash*(uint)16777619);
     }
   return(StringFormat("%08X",(int)hash));
  }

#endif // WONDERWHALES_CONTRACT_MQH
