//+------------------------------------------------------------------+
//|                                             WW2ScalpStrategy.mqh |
//|   Scalp M15 bias / M5 setup / M1 trigger on closed bars.          |
//|                                                                  |
//| Pure: takes indicator values, returns a decision. No I/O, no       |
//| account access, no trading calls, never recomputes the indicator.  |
//+------------------------------------------------------------------+
#ifndef WW2_SCALP_STRATEGY_MQH
#define WW2_SCALP_STRATEGY_MQH

#include "WW2Types.mqh"

//--- M15 trend filter: EMA20/EMA50 plus the close against EMA200.
bool Ww2ScalpBias(const Ww2Signal &m15,bool &bias_buy,bool &bias_sell)
  {
   bias_buy=false;
   bias_sell=false;
   if(!m15.valid)
      return(false);
   if(m15.fast_ema>m15.slow_ema && m15.close>m15.ema200)
      bias_buy=true;
   if(m15.fast_ema<m15.slow_ema && m15.close<m15.ema200)
      bias_sell=true;
   return(bias_buy || bias_sell);
  }

//--- M5 setup (PSAR flip agreeing with the M15 bias and its own EMAs) plus an
//--- M1 confirmation on the closed bar.
bool Ww2ScalpEntry(const Ww2Signal &m15,const Ww2Signal &m5,
                   const Ww2Signal &m1,bool &is_buy)
  {
   is_buy=false;
   bool bias_buy=false,bias_sell=false;
   if(!Ww2ScalpBias(m15,bias_buy,bias_sell))
      return(false);
   if(!m5.valid || !m1.valid)
      return(false);

   if(bias_buy && m5.buy && m5.fast_ema>=m5.slow_ema && m1.buy)
     {
      is_buy=true;
      return(true);
     }
   if(bias_sell && m5.sell && m5.fast_ema<=m5.slow_ema && m1.sell)
     {
      is_buy=false;
      return(true);
     }
   return(false);
  }

#endif
//+------------------------------------------------------------------+
