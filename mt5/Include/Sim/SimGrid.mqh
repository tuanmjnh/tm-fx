//+------------------------------------------------------------------+
//|                                                     SimGrid.mqh |
//|        MT5 EA Lab - pure grid level and cap helpers              |
//|                                                                  |
//| No state, no indicators and no trading APIs: callers pass prices  |
//| and caps in, so the rules can be unit tested without a terminal.  |
//+------------------------------------------------------------------+
#ifndef SIM_GRID_MQH
#define SIM_GRID_MQH

#include "SimTypes.mqh"
#include "SimValidate.mqh"

enum ENUM_SIM_GRID_SPACING
  {
   SIM_GRID_FIXED_POINTS = 0,
   SIM_GRID_ATR_MULTIPLE = 1
  };

struct SimGridPlan
  {
   bool              allowed;
   double            volume;
   string            reason;
  };

//--- Volume of one level before caps: base * multiplier^(level-1).
double SimGridLevelVolume(const double base_volume,const double multiplier,
                          const int level)
  {
   if(level<1)
      return(0.0);
   return(base_volume*MathPow(multiplier,(double)(level-1)));
  }

//--- Decides whether level `next_level` may open and with what volume.
//--- max_level_volume is applied first, then the exposure cap is checked.
SimGridPlan SimGridPlanAdd(const int next_level,const int max_levels,
                           const double base_volume,const double multiplier,
                           const double max_level_volume,
                           const double exposure,const double max_exposure)
  {
   SimGridPlan plan;
   plan.allowed=false;
   plan.volume=0.0;
   plan.reason="";

   if(next_level<1)
     {
      plan.reason="grid_level_invalid";
      return(plan);
     }
   if(max_levels<1 || next_level>max_levels)
     {
      plan.reason="max_grid_levels_reached";
      return(plan);
     }
   if(!SimIsFinite(base_volume) || base_volume<=0.0 ||
      !SimIsFinite(multiplier) || multiplier<1.0 ||
      !SimIsFinite(max_level_volume) || max_level_volume<=0.0)
     {
      plan.reason="grid_volume_invalid";
      return(plan);
     }

   double volume=SimGridLevelVolume(base_volume,multiplier,next_level);
   if(!SimIsFinite(volume) || volume<=0.0)
     {
      plan.reason="grid_volume_invalid";
      return(plan);
     }
   volume=MathMin(volume,max_level_volume);

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
   return(plan);
  }

//--- Price of grid level `level` measured from an anchor entry.
double SimGridLevelPrice(const ENUM_SIM_SIDE side,const double anchor,
                         const double spacing,const int level)
  {
   if(side==SIM_SIDE_NONE || !SimIsFinite(anchor) || anchor<=0.0 ||
      !SimIsFinite(spacing) || spacing<=0.0 || level<0)
      return(0.0);
   if(side==SIM_SIDE_BUY)
      return(anchor-spacing*(double)level);
   return(anchor+spacing*(double)level);
  }

//--- Next level entry after last_entry, one spacing against the position.
double SimGridNextLevelPrice(const ENUM_SIM_SIDE side,const double last_entry,
                             const double spacing)
  {
   return(SimGridLevelPrice(side,last_entry,spacing,1));
  }

//--- BUY grid adds when bid falls one spacing below last entry; SELL grid
//--- adds when ask rises one spacing above it.
bool SimGridTriggered(const ENUM_SIM_SIDE side,const double last_entry,
                      const double spacing,const double bid,const double ask)
  {
   if(side==SIM_SIDE_NONE || !SimIsFinite(last_entry) || last_entry<=0.0 ||
      !SimIsFinite(spacing) || spacing<=0.0)
      return(false);
   if(side==SIM_SIDE_BUY)
      return(SimIsFinite(bid) && bid<=last_entry-spacing);
   return(SimIsFinite(ask) && ask>=last_entry+spacing);
  }

//--- Basket target/stop measured from the volume-weighted average entry.
bool SimGridTargetHit(const ENUM_SIM_SIDE side,const double average_entry,
                      const double distance,const double bid,const double ask)
  {
   if(side==SIM_SIDE_NONE || !SimIsFinite(average_entry) || average_entry<=0.0 ||
      !SimIsFinite(distance) || distance<=0.0)
      return(false);
   if(side==SIM_SIDE_BUY)
      return(SimIsFinite(bid) && bid>=average_entry+distance);
   return(SimIsFinite(ask) && ask<=average_entry-distance);
  }

bool SimGridStopHit(const ENUM_SIM_SIDE side,const double average_entry,
                    const double distance,const double bid,const double ask)
  {
   if(side==SIM_SIDE_NONE || !SimIsFinite(average_entry) || average_entry<=0.0 ||
      !SimIsFinite(distance) || distance<=0.0)
      return(false);
   if(side==SIM_SIDE_BUY)
      return(SimIsFinite(bid) && bid<=average_entry-distance);
   return(SimIsFinite(ask) && ask>=average_entry+distance);
  }

#endif // SIM_GRID_MQH
