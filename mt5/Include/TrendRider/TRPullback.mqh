//+------------------------------------------------------------------+
//|                                                   TRPullback.mqh |
//|      PA_TrendRider_XAU_V1 - retest zone and confirmation candle   |
//|                                                                  |
//| One simple, reproducible definition: the broken swing level plus  |
//| a symmetric ATR band. A confirmation candle must close in the     |
//| outer quarter of its range and have a body of at least half ATR.  |
//+------------------------------------------------------------------+
#ifndef TR_PULLBACK_MQH
#define TR_PULLBACK_MQH

#include "TRTypes.mqh"
#include "TRConfig.mqh"

struct TRRetestZone
  {
   bool              valid;
   ENUM_SIM_SIDE     side;
   double            level;
   double            low;
   double            high;
   datetime          bos_time;
   int               bos_index;
  };

struct TRPullbackResult
  {
   bool              ok;
   string            reason;
   int               confirm_index;
   bool              touched;
   bool              invalidated;
  };

TRRetestZone TRBuildRetestZone(const ENUM_SIM_SIDE side,const double level,
                               const datetime bos_time,const int bos_index,
                               const double atr,const double zone_atr)
  {
   TRRetestZone zone;
   zone.valid=false;
   zone.side=side;
   zone.level=level;
   zone.low=level;
   zone.high=level;
   zone.bos_time=bos_time;
   zone.bos_index=bos_index;

   if(side==SIM_SIDE_NONE || !TRIsFinitePositive(level) ||
      !TRIsFinitePositive(atr) || !TRIsFinitePositive(zone_atr))
      return(zone);

   const double width=atr*zone_atr;
   zone.low=level-width;
   zone.high=level+width;
   zone.valid=true;
   return(zone);
  }

//--- True when any bar in [from_index, to_index] traded inside the band.
bool TRZoneTouched(const TRRetestZone &zone,const TRBar &bars[],
                   const int from_index,const int to_index)
  {
   if(!zone.valid)
      return(false);
   const int count=ArraySize(bars);
   const int start=(from_index<0 ? 0 : from_index);
   const int end=(to_index>count-1 ? count-1 : to_index);
   for(int i=start; i<=end; i++)
      if(bars[i].low<=zone.high && bars[i].high>=zone.low)
         return(true);
   return(false);
  }

//--- A close beyond the opposite side of the band voids the setup.
bool TRZoneInvalidated(const TRRetestZone &zone,const double close,
                       const double buffer)
  {
   if(!zone.valid)
      return(true);
   if(zone.side==SIM_SIDE_BUY)
      return(close<zone.low-buffer);
   if(zone.side==SIM_SIDE_SELL)
      return(close>zone.high+buffer);
   return(true);
  }

bool TRIsConfirmationCandle(const TRBar &bar,const ENUM_SIM_SIDE side,
                            const double atr,const TRConfig &cfg)
  {
   if(side==SIM_SIDE_NONE || !TRIsFinitePositive(atr))
      return(false);

   const double range=bar.high-bar.low;
   if(!TRIsFinitePositive(range))
      return(false); // zero-range bars cannot confirm anything

   const double min_body=cfg.confirmation_body_atr*atr;
   const double zone=cfg.confirmation_close_zone;

   if(side==SIM_SIDE_BUY)
     {
      const double body=bar.close-bar.open;
      if(body<=0.0 || body<min_body)
         return(false);
      return((bar.close-bar.low)>=(1.0-zone)*range);
     }

   const double body=bar.open-bar.close;
   if(body<=0.0 || body<min_body)
      return(false);
   return((bar.high-bar.close)>=(1.0-zone)*range);
  }

//--- Scans bars after the BOS for a touch, rejects a zone that closed
//--- through, and requires the newest closed bar to confirm.
TRPullbackResult TREvaluatePullback(const TRRetestZone &zone,
                                    const TRBar &bars[],
                                    const int start_index,
                                    const double atr,
                                    const double buffer,
                                    const TRConfig &cfg)
  {
   TRPullbackResult result;
   result.ok=false;
   result.reason="NO_PULLBACK";
   result.confirm_index=-1;
   result.touched=false;
   result.invalidated=false;

   const int count=ArraySize(bars);
   if(!zone.valid || count<2 || start_index>=count)
      return(result);

   const int start=(start_index<0 ? 0 : start_index);
   for(int i=start; i<count-1; i++)
      if(TRZoneInvalidated(zone,bars[i].close,buffer))
        {
         result.reason="ZONE_INVALIDATED";
         result.invalidated=true;
         return(result);
        }

   const int last=count-1;
   if(TRZoneInvalidated(zone,bars[last].close,buffer))
     {
      result.reason="ZONE_INVALIDATED";
      result.invalidated=true;
      return(result);
     }

   result.touched=TRZoneTouched(zone,bars,start,last);
   if(!result.touched)
      return(result);

   if(!TRIsConfirmationCandle(bars[last],zone.side,atr,cfg))
     {
      result.reason="NO_CONFIRMATION";
      return(result);
     }

   result.ok=true;
   result.reason="OK";
   result.confirm_index=last;
   return(result);
  }

#endif // TR_PULLBACK_MQH
