//+------------------------------------------------------------------+
//|                                                  Indicators.mqh |
//|          MT5 EA & AI Lab - deterministic indicator primitives   |
//|                                                                  |
//| All functions take a chronological array (index 0 = oldest bar). |
//| Callers must pass closed-bar data only; this module never reads  |
//| the terminal directly.                                           |
//+------------------------------------------------------------------+
#ifndef LAB_INDICATORS_MQH
#define LAB_INDICATORS_MQH

//--- A value usable by price-based indicators: finite and positive.
bool LabIsUsableValue(const double value)
  {
   return(MathIsValidNumber(value) && value>0.0);
  }

//--- Simple moving average over chronological values.
//--- out[] has the same size as values[]; entries before period-1 are 0.
bool LabComputeSma(const double &values[],const int count,const int period,
                   double &out[])
  {
   if(period<=0 || count<period)
      return(false);

   for(int i=0; i<count; i++)
     {
      if(!LabIsUsableValue(values[i]))
         return(false);
     }

   if(ArrayResize(out,count)!=count)
      return(false);

   double sum=0.0;
   for(int i=0; i<period; i++)
      sum+=values[i];
   out[period-1]=sum/period;

   for(int i=period; i<count; i++)
     {
      sum+=values[i]-values[i-period];
      out[i]=sum/period;
     }

   for(int i=0; i<period-1; i++)
      out[i]=0.0;

   return(true);
  }

//--- Exponential moving average seeded with the SMA of the first period.
//--- out[] has the same size as values[]; entries before period-1 are 0.
bool LabComputeEma(const double &values[],const int count,const int period,
                   double &out[])
  {
   if(period<=0 || count<period)
      return(false);

   for(int i=0; i<count; i++)
     {
      if(!LabIsUsableValue(values[i]))
         return(false);
     }

   if(ArrayResize(out,count)!=count)
      return(false);

   double seed=0.0;
   for(int i=0; i<period; i++)
      seed+=values[i];
   seed/=period;

   for(int i=0; i<period-1; i++)
      out[i]=0.0;
   out[period-1]=seed;

   const double alpha=2.0/((double)period+1.0);
   for(int i=period; i<count; i++)
      out[i]=alpha*values[i]+(1.0-alpha)*out[i-1];

   return(true);
  }

#endif // LAB_INDICATORS_MQH
