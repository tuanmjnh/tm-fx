//+------------------------------------------------------------------+
//|                                             WW2SwingStrategy.mqh |
//|   Swing W1 bias / D1 agreement / H1 PSAR trigger on closed bars.  |
//|                                                                  |
//| Pure: takes indicator values, returns a decision. No I/O, no       |
//| account access, no trading calls, never recomputes the indicator.  |
//+------------------------------------------------------------------+
#ifndef WW2_SWING_STRATEGY_MQH
#define WW2_SWING_STRATEGY_MQH

#include "WW2Types.mqh"

bool Ww2SwingEntry(const Ww2Signal &w1,const Ww2Signal &d1,
                   const Ww2Signal &h1,bool &is_buy)
  {
   is_buy=false;
   if(!w1.valid || !d1.valid || !h1.valid)
      return(false);

   const bool w_buy=(w1.fast_ema>w1.slow_ema && w1.close>=w1.slow_ema);
   const bool w_sell=(w1.fast_ema<w1.slow_ema && w1.close<=w1.slow_ema);
   const bool d_buy=(d1.fast_ema>d1.slow_ema);
   const bool d_sell=(d1.fast_ema<d1.slow_ema);

   //--- W1 and D1 must not conflict; EMA200 is a preference, not a veto.
   if(w_buy && d_buy && h1.buy)
     {
      is_buy=true;
      return(true);
     }
   if(w_sell && d_sell && h1.sell)
     {
      is_buy=false;
      return(true);
     }
   return(false);
  }

#endif
//+------------------------------------------------------------------+
