//+------------------------------------------------------------------+
//|                                                     WW2Swing.mqh |
//|   Confirmed fractal swing detection on a price array.             |
//|                                                                  |
//| Arrays are passed in series order (index 0 = newest bar). No file |
//| I/O, no account access, no trading functions.                      |
//+------------------------------------------------------------------+
#ifndef WW2_SWING_MQH
#define WW2_SWING_MQH

//--- Newest confirmed swing low: a bar whose low is not higher than the
//--- `confirm` bars on each side. start_shift is the newest bar considered
//--- (usually 1, a closed bar). Surplus bars beyond lookback are ignored.
bool Ww2FindSwingLow(const double &low[],const int start_shift,
                     const int lookback,const int confirm,int &shift,
                     double &price)
  {
   shift=-1;
   price=0.0;
   if(confirm<1 || lookback<1)
      return(false);
   const int bars=ArraySize(low);
   const int last=MathMin(bars-confirm-1,start_shift+lookback);
   for(int i=start_shift+confirm;i<=last;i++)
     {
      bool ok=true;
      for(int j=1;j<=confirm && ok;j++)
        {
         if(low[i]>low[i-j] || low[i]>=low[i+j])
            ok=false;
        }
      if(ok)
        {
         shift=i;
         price=low[i];
         return(true);
        }
     }
   return(false);
  }

bool Ww2FindSwingHigh(const double &high[],const int start_shift,
                      const int lookback,const int confirm,int &shift,
                      double &price)
  {
   shift=-1;
   price=0.0;
   if(confirm<1 || lookback<1)
      return(false);
   const int bars=ArraySize(high);
   const int last=MathMin(bars-confirm-1,start_shift+lookback);
   for(int i=start_shift+confirm;i<=last;i++)
     {
      bool ok=true;
      for(int j=1;j<=confirm && ok;j++)
        {
         if(high[i]<high[i-j] || high[i]<=high[i+j])
            ok=false;
        }
      if(ok)
        {
         shift=i;
         price=high[i];
         return(true);
        }
     }
   return(false);
  }

#endif
//+------------------------------------------------------------------+
