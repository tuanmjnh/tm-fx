//+------------------------------------------------------------------+
//|                                                      SimDca.mqh |
//|        MT5 EA Lab - pure DCA trigger and addition helpers        |
//|                                                                  |
//| No state, no indicators and no trading APIs: callers pass fills,  |
//| counts and caps in, so the rules can be unit tested offline.      |
//| Basket target/stop geometry is shared with the grid helpers       |
//| (SimGridTargetHit / SimGridStopHit, vectors G10-G12).             |
//+------------------------------------------------------------------+
#ifndef SIM_DCA_MQH
#define SIM_DCA_MQH

#include "SimTypes.mqh"
#include "SimValidate.mqh"

enum ENUM_SIM_DCA_TRIGGER
  {
   SIM_DCA_PRICE_DISTANCE = 0,
   SIM_DCA_BAR_INTERVAL   = 1
  };

struct SimDcaPlan
  {
   bool              allowed;
   double            volume;
   int               add_index;   // 1-based; counts additions only
   string            reason;
  };

//--- Volume of addition `add_index`: base * multiplier^add_index.
//--- The initial entry is not an addition and always uses the base volume.
double SimDcaAddVolume(const double base_volume,const double multiplier,
                       const int add_index)
  {
   if(add_index<1)
      return(0.0);
   return(base_volume*MathPow(multiplier,(double)add_index));
  }

//--- Decides whether addition `dca_adds + 1` may open and with what volume.
//--- max_add_volume is applied first, then the exposure cap is checked.
SimDcaPlan SimDcaPlanAdd(const int dca_adds,const int max_dca_adds,
                         const double base_volume,const double multiplier,
                         const double max_add_volume,
                         const double exposure,const double max_exposure)
  {
   SimDcaPlan plan;
   plan.allowed=false;
   plan.volume=0.0;
   plan.add_index=0;
   plan.reason="";

   if(max_dca_adds<0)
     {
      plan.reason="max_dca_adds_invalid";
      return(plan);
     }
   if(dca_adds<0)
     {
      plan.reason="dca_adds_invalid";
      return(plan);
     }
   if(dca_adds>=max_dca_adds)
     {
      plan.reason="max_dca_adds_reached";
      return(plan);
     }
   if(!SimIsFinite(base_volume) || base_volume<=0.0 ||
      !SimIsFinite(multiplier) || multiplier<1.0 ||
      !SimIsFinite(max_add_volume) || max_add_volume<=0.0)
     {
      plan.reason="dca_volume_invalid";
      return(plan);
     }

   const int add_index=dca_adds+1;
   double volume=SimDcaAddVolume(base_volume,multiplier,add_index);
   if(!SimIsFinite(volume) || volume<=0.0)
     {
      plan.reason="dca_volume_invalid";
      return(plan);
     }
   volume=MathMin(volume,max_add_volume);

   if(!SimIsFinite(exposure) || exposure<0.0)
     {
      plan.reason="exposure_invalid";
      return(plan);
     }
   if(!SimIsFinite(max_exposure) || max_exposure<=0.0)
     {
      plan.reason="max_virtual_exposure_invalid";
      return(plan);
     }
   if(exposure+volume>max_exposure)
     {
      plan.reason="max_virtual_exposure_reached";
      return(plan);
     }

   plan.allowed=true;
   plan.volume=volume;
   plan.add_index=add_index;
   return(plan);
  }

//--- BUY adds when bid falls one distance below the last fill; SELL adds
//--- when ask rises one distance above it.
bool SimDcaPriceTriggered(const ENUM_SIM_SIDE side,const double last_entry,
                          const double distance,const double bid,
                          const double ask)
  {
   if(side==SIM_SIDE_NONE || !SimIsFinite(last_entry) || last_entry<=0.0 ||
      !SimIsFinite(distance) || distance<=0.0)
      return(false);
   if(side==SIM_SIDE_BUY)
      return(SimIsFinite(bid) && bid<=last_entry-distance);
   return(SimIsFinite(ask) && ask>=last_entry+distance);
  }

//--- True when at least bars_between_adds full bars elapsed since the last
//--- fill. A backward bar_time never triggers.
bool SimDcaBarTriggered(const datetime last_add_bar,const datetime bar_time,
                        const int bars_between_adds,
                        const int timeframe_seconds)
  {
   if(last_add_bar<=0 || bar_time<=0 ||
      bars_between_adds<1 || timeframe_seconds<1)
      return(false);
   if(bar_time<=last_add_bar)
      return(false);
   const long elapsed=(long)(bar_time-last_add_bar);
   const long required=(long)bars_between_adds*(long)timeframe_seconds;
   return(elapsed>=required);
  }

//--- Bars elapsed since the last fill, for logging only.
int SimDcaBarsSince(const datetime last_add_bar,const datetime bar_time,
                    const int timeframe_seconds)
  {
   if(last_add_bar<=0 || bar_time<=last_add_bar || timeframe_seconds<1)
      return(0);
   return((int)((long)(bar_time-last_add_bar)/(long)timeframe_seconds));
  }

#endif // SIM_DCA_MQH
