//+------------------------------------------------------------------+
//|                                                         TRAtr.mqh |
//|      PA_TrendRider_XAU_V1 - deterministic ATR helpers             |
//|                                                                  |
//| ATR is computed from closed bars with the simple average of true  |
//| range, so tests do not depend on a terminal indicator handle.     |
//| The median ATR is the median of the same series over the baseline |
//| window and is used only for the abnormal-volatility filter.       |
//+------------------------------------------------------------------+
#ifndef TR_ATR_MQH
#define TR_ATR_MQH

#include "TRTypes.mqh"

double TRTrueRangeAt(const TRBar &bars[],const int index)
  {
   if(index<1 || index>=ArraySize(bars))
      return(0.0);
   const double previous_close=bars[index-1].close;
   return(MathMax(bars[index].high-bars[index].low,
                  MathMax(MathAbs(bars[index].high-previous_close),
                          MathAbs(bars[index].low-previous_close))));
  }

//--- Simple ATR ending at end_index over `period` true ranges.
bool TRAtrAt(const TRBar &bars[],const int period,const int end_index,
             double &atr)
  {
   atr=0.0;
   if(period<1 || end_index<period || end_index>=ArraySize(bars))
      return(false);
   double sum=0.0;
   for(int i=end_index-period+1; i<=end_index; i++)
      sum+=TRTrueRangeAt(bars,i);
   atr=sum/(double)period;
   return(MathIsValidNumber(atr) && atr>=0.0);
  }

bool TRAtr(const TRBar &bars[],const int period,double &atr)
  {
   return(TRAtrAt(bars,period,ArraySize(bars)-1,atr));
  }

bool TRAtrMedian(const TRBar &bars[],const int period,const int baseline,
                 double &median)
  {
   median=0.0;
   const int count=ArraySize(bars);
   if(period<1 || baseline<1 || count<period+baseline)
      return(false);

   double values[];
   ArrayResize(values,baseline);
   for(int k=0; k<baseline; k++)
     {
      const int end_index=count-baseline+k;
      double atr=0.0;
      if(!TRAtrAt(bars,period,end_index,atr))
         return(false);
      values[k]=atr;
     }
   ArraySort(values);
   if(baseline%2==1)
      median=values[baseline/2];
   else
      median=(values[baseline/2-1]+values[baseline/2])*0.5;
   return(MathIsValidNumber(median));
  }

bool TRVolatilityAbnormal(const double atr,const double median_atr,
                          const double ratio)
  {
   if(!TRIsFinitePositive(atr) || !TRIsFinitePositive(median_atr) ||
      !TRIsFinitePositive(ratio))
      return(false);
   return(atr>ratio*median_atr);
  }

#endif // TR_ATR_MQH
