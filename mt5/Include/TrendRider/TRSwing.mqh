//+------------------------------------------------------------------+
//|                                                      TRSwing.mqh |
//|      PA_TrendRider_XAU_V1 - confirmed fractal swing detector      |
//|                                                                  |
//| Rules (fixed and unit-tested):                                   |
//|  * strict inequality on both sides, so equal highs/lows (ties)    |
//|    are rejected instead of resolved arbitrarily;                  |
//|  * a swing exists only after `right` closed bars have printed,    |
//|    so the detector never repaints and never uses future bars;     |
//|  * `confirm_time` is the close of the right-hand bar, i.e. the    |
//|    earliest moment the swing could be known.                      |
//+------------------------------------------------------------------+
#ifndef TR_SWING_MQH
#define TR_SWING_MQH

#include "TRTypes.mqh"

bool TRIsSwingHighAt(const TRBar &bars[],const int index,
                     const int left,const int right)
  {
   const int count=ArraySize(bars);
   if(left<1 || right<1)
      return(false);
   if(index-left<0 || index+right>count-1)
      return(false);
   for(int k=1; k<=left; k++)
      if(bars[index].high<=bars[index-k].high)
         return(false);
   for(int k=1; k<=right; k++)
      if(bars[index].high<=bars[index+k].high)
         return(false);
   return(true);
  }

bool TRIsSwingLowAt(const TRBar &bars[],const int index,
                    const int left,const int right)
  {
   const int count=ArraySize(bars);
   if(left<1 || right<1)
      return(false);
   if(index-left<0 || index+right>count-1)
      return(false);
   for(int k=1; k<=left; k++)
      if(bars[index].low>=bars[index-k].low)
         return(false);
   for(int k=1; k<=right; k++)
      if(bars[index].low>=bars[index+k].low)
         return(false);
   return(true);
  }

//--- Collects confirmed swings oldest-first. Only indices with `right`
//--- closed bars to their right can qualify, so nothing is provisional.
int TRCollectSwings(const TRBar &bars[],const int left,const int right,
                    TRSwingPoint &out[])
  {
   ArrayResize(out,0);
   const int count=ArraySize(bars);
   if(count<(left+right+1))
      return(0);

   int found=0;
   for(int i=left; i+right<=count-1; i++)
     {
      bool is_high=TRIsSwingHighAt(bars,i,left,right);
      bool is_low=TRIsSwingLowAt(bars,i,left,right);
      if(!is_high && !is_low)
         continue;
      if(is_high && is_low)
         continue; // inside bar: ambiguous, rejected on purpose

      ArrayResize(out,found+1);
      out[found].valid=true;
      out[found].is_high=is_high;
      out[found].index=i;
      out[found].time=bars[i].time;
      out[found].confirm_index=i+right;
      out[found].confirm_time=bars[i+right].time;
      out[found].price=(is_high ? bars[i].high : bars[i].low);
      found++;
     }
   return(found);
  }

//--- Most recent confirmed high (or invalid when none exists).
TRSwingPoint TRLastSwingHigh(const TRSwingPoint &swings[])
  {
   TRSwingPoint result;
   result.valid=false;
   result.is_high=true;
   result.index=-1;
   result.time=0;
   result.confirm_index=-1;
   result.confirm_time=0;
   result.price=0.0;
   for(int i=ArraySize(swings)-1; i>=0; i--)
      if(swings[i].valid && swings[i].is_high)
        {
         result=swings[i];
         break;
        }
   return(result);
  }

TRSwingPoint TRLastSwingLow(const TRSwingPoint &swings[])
  {
   TRSwingPoint result;
   result.valid=false;
   result.is_high=false;
   result.index=-1;
   result.time=0;
   result.confirm_index=-1;
   result.confirm_time=0;
   result.price=0.0;
   for(int i=ArraySize(swings)-1; i>=0; i--)
      if(swings[i].valid && !swings[i].is_high)
        {
         result=swings[i];
         break;
        }
   return(result);
  }

//--- Second most recent confirmed swing of the given kind.
TRSwingPoint TRPreviousSwing(const TRSwingPoint &swings[],const bool want_high)
  {
   TRSwingPoint result;
   result.valid=false;
   result.is_high=want_high;
   result.index=-1;
   result.time=0;
   result.confirm_index=-1;
   result.confirm_time=0;
   result.price=0.0;
   int seen=0;
   for(int i=ArraySize(swings)-1; i>=0; i--)
     {
      if(!swings[i].valid || swings[i].is_high!=want_high)
         continue;
      seen++;
      if(seen==2)
        {
         result=swings[i];
         break;
        }
     }
   return(result);
  }

#endif // TR_SWING_MQH
