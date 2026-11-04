//+------------------------------------------------------------------+
//|                                              WW2InitialStop.mqh  |
//|   Initial stop distance: confirmed swing plus an ATR buffer, with |
//|   an ATR fallback when no valid swing exists.                     |
//|                                                                  |
//| Pure math, no file I/O, no account access, no trading functions.  |
//+------------------------------------------------------------------+
#ifndef WW2_INITIAL_STOP_MQH
#define WW2_INITIAL_STOP_MQH

//--- atr_pct is the indicator ATR as a percentage of price; the ATR in price
//--- terms is price * atr_pct / 100. Returns a positive distance in price or
//--- 0.0 when it cannot be resolved.
double Ww2StopDistance(const bool is_buy,const double price,
                       const double atr_pct,const double swing_price,
                       const bool have_swing,const double buffer_atr,
                       const double fallback_atr)
  {
   const double atr_price=price*(atr_pct/100.0);
   if(!(atr_price>0.0))
      return(0.0);

   if(have_swing)
     {
      if(is_buy && swing_price<price)
         return((price-swing_price)+buffer_atr*atr_price);
      if(!is_buy && swing_price>price)
         return((swing_price-price)+buffer_atr*atr_price);
     }
   return(fallback_atr*atr_price);
  }

double Ww2ScalpStopDistance(const bool is_buy,const double price,
                            const double atr_pct,const double swing_price,
                            const bool have_swing,const double buffer_atr,
                            const double fallback_atr)
  {
   return(Ww2StopDistance(is_buy,price,atr_pct,swing_price,have_swing,
                          buffer_atr,fallback_atr));
  }

double Ww2SwingStopDistance(const bool is_buy,const double price,
                            const double atr_pct,const double swing_price,
                            const bool have_swing,const double buffer_atr,
                            const double fallback_atr)
  {
   return(Ww2StopDistance(is_buy,price,atr_pct,swing_price,have_swing,
                          buffer_atr,fallback_atr));
  }

#endif
//+------------------------------------------------------------------+
