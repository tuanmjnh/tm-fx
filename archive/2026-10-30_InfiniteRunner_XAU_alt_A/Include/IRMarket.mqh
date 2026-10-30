//+------------------------------------------------------------------+
//|                                                      IRMarket.mqh |
//|      Closed-bar helpers and confirmed-swing SL levels             |
//+------------------------------------------------------------------+
#ifndef IR_MARKET_MQH
#define IR_MARKET_MQH

#include "IRTypes.mqh"

double IREmaSlope(const double now,const double then,const int lookback)
  {
   if(lookback<=0 || !IRIsFinite(now) || !IRIsFinite(then))
      return(0.0);
   return((now-then)/(double)lookback);
  }

bool IREmaSnapValid(const IREmaSnap &snap)
  {
   return(snap.ready &&
          IRIsFinite(snap.fast) && IRIsFinite(snap.slow) &&
          IRIsFinite(snap.close) && IRIsFinite(snap.close_prev) &&
          IRIsFinite(snap.fast_prev) && IRIsFinite(snap.slow_prev));
  }

ENUM_IR_BIAS IRBiasFromEma(const IREmaSnap &snap,const double min_fast_slope,
                           const double max_slow_down_slope)
  {
   if(!IREmaSnapValid(snap))
      return(IR_BIAS_NONE);
   if(snap.fast>snap.slow && snap.fast_slope>min_fast_slope &&
      snap.slow_slope>=-max_slow_down_slope)
      return(IR_BIAS_BULL);
   if(snap.fast<snap.slow && snap.fast_slope<-min_fast_slope &&
      snap.slow_slope<=max_slow_down_slope)
      return(IR_BIAS_BEAR);
   return(IR_BIAS_NONE);
  }

//--- Closed-bar pullback/reclaim. Uses shift-1 (confirm) and shift-2 (prior).
bool IRBuyReclaim(const IREmaSnap &m5,const double pullback_tol)
  {
   if(!IREmaSnapValid(m5))
      return(false);
   const double near=MathMax(pullback_tol,0.0);
   if(m5.close_prev>m5.fast_prev+near)
      return(false);
   return(m5.close>m5.fast && m5.close>m5.slow);
  }

bool IRSellReclaim(const IREmaSnap &m5,const double pullback_tol)
  {
   if(!IREmaSnapValid(m5))
      return(false);
   const double near=MathMax(pullback_tol,0.0);
   if(m5.close_prev<m5.fast_prev-near)
      return(false);
   return(m5.close<m5.fast && m5.close<m5.slow);
  }

string IRSignalId(const string symbol,const datetime bar_time,
                  const ENUM_SIM_SIDE side)
  {
   return(symbol+"|"+IntegerToString((long)bar_time)+"|"+SimSideName(side));
  }

//--- Confirmed fractal: a bar is a swing only with `right` closed bars after it.
bool IRSwingLow(const double &low[],const int index,const int left,const int right)
  {
   const int last=ArraySize(low)-1;
   if(index-left<0 || index+right>last)
      return(false);
   const double pivot=low[index];
   for(int i=index-left; i<=index+right; i++)
     {
      if(i==index)
         continue;
      if(low[i]<pivot)
         return(false);
     }
   return(true);
  }

bool IRSwingHigh(const double &high[],const int index,const int left,const int right)
  {
   const int last=ArraySize(high)-1;
   if(index-left<0 || index+right>last)
      return(false);
   const double pivot=high[index];
   for(int i=index-left; i<=index+right; i++)
     {
      if(i==index)
         continue;
      if(high[i]>pivot)
         return(false);
     }
   return(true);
  }

//--- Latest confirmed swing strictly before the last (closed) bar.
double IRLastConfirmedSwingLow(const double &low[],const int left,const int right)
  {
   const int last=ArraySize(low)-1-right;
   for(int i=last; i>=left; i--)
     {
      if(IRSwingLow(low,i,left,right))
         return(low[i]);
     }
   return(0.0);
  }

double IRLastConfirmedSwingHigh(const double &high[],const int left,const int right)
  {
   const int last=ArraySize(high)-1-right;
   for(int i=last; i>=left; i--)
     {
      if(IRSwingHigh(high,i,left,right))
         return(high[i]);
     }
   return(0.0);
  }

bool IRSessionOpen(const datetime now,const bool enabled,const int start_hour,
                   const int end_hour)
  {
   if(!enabled)
      return(true);
   if(start_hour<0 || start_hour>23 || end_hour<0 || end_hour>23)
      return(false);
   MqlDateTime dt;
   TimeToStruct(now,dt);
   const int hour=dt.hour;
   if(start_hour==end_hour)
      return(true);
   if(start_hour<end_hour)
      return(hour>=start_hour && hour<end_hour);
   return(hour>=start_hour || hour<end_hour);
  }

#endif // IR_MARKET_MQH
