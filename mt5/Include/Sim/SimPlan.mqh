//+------------------------------------------------------------------+
//|                                                      SimPlan.mqh |
//|        MT5 EA Lab - pure validation for indicator trade plans     |
//|                                                                  |
//| Pure helpers only: no indicator handles, no positions, no trading |
//| API. Callers pass buffer values in, so every rule can be unit     |
//| tested without a terminal.                                        |
//+------------------------------------------------------------------+
#ifndef SIM_PLAN_MQH
#define SIM_PLAN_MQH

#include "SimTypes.mqh"
#include "SimValidate.mqh"

enum ENUM_SIM_PLAN_TARGET
  {
   SIM_PLAN_TARGET_TP1 = 0,   // first target
   SIM_PLAN_TARGET_TP3 = 1,   // furthest valid target
   SIM_PLAN_TARGET_NONE = 2   // stop only, no take-profit
  };

string SimPlanTargetName(const ENUM_SIM_PLAN_TARGET target)
  {
   switch(target)
     {
      case SIM_PLAN_TARGET_TP1:  return("TP1");
      case SIM_PLAN_TARGET_TP3:  return("TP3");
      default:                   return("NONE");
     }
  }

struct SimPlan
  {
   bool              signal;     // indicator edge signal on the closed bar
   bool              valid;      // indicator PLAN_VALID on the signal bar
   ENUM_SIM_SIDE     side;       // resolved by the EA from signal + direction
   double            entry;      // reference entry, not the simulated fill
   double            sl;
   double            tp1;
   double            tp2;
   double            tp3;
  };

struct SimPlanCheck
  {
   bool              accepted;
   string            reason;
  };

SimPlanCheck SimPlanCheckResult(const bool accepted,const string reason)
  {
   SimPlanCheck out;
   out.accepted=accepted;
   out.reason=reason;
   return(out);
  }

//--- Resolves the trade side from the indicator's edge signal and direction.
//--- Long-only / short-only filters mirror the simulation EAs (1 / -1 / 0).
ENUM_SIM_SIDE SimPlanResolveSide(const bool signal_long,const bool signal_short,
                                 const int direction,string &reason)
  {
   reason="";
   if(signal_long && signal_short)
     {
      reason="ambiguous_signal";
      return(SIM_SIDE_NONE);
     }
   if(!signal_long && !signal_short)
     {
      reason="no_signal";
      return(SIM_SIDE_NONE);
     }

   const ENUM_SIM_SIDE side=(signal_long ? SIM_SIDE_BUY : SIM_SIDE_SELL);
   if(direction!=1 && direction!=-1)
     {
      reason="direction_missing";
      return(SIM_SIDE_NONE);
     }
   if((side==SIM_SIDE_BUY && direction!=1) ||
      (side==SIM_SIDE_SELL && direction!=-1))
     {
      reason="direction_conflict";
      return(SIM_SIDE_NONE);
     }
   return(side);
  }

//--- Validates a plan before a virtual entry. Tokens are stable and logged.
SimPlanCheck SimPlanValidate(const SimPlan &plan,const int side_filter,
                             const double point,const double min_stop_points,
                             const double min_target_points)
  {
   if(!plan.signal)
      return(SimPlanCheckResult(false,"no_signal"));
   if(!plan.valid)
      return(SimPlanCheckResult(false,"plan_invalid"));
   if(plan.side==SIM_SIDE_NONE)
      return(SimPlanCheckResult(false,"side_missing"));
   if(side_filter==1 && plan.side!=SIM_SIDE_BUY)
      return(SimPlanCheckResult(false,"side_filtered"));
   if(side_filter==-1 && plan.side!=SIM_SIDE_SELL)
      return(SimPlanCheckResult(false,"side_filtered"));
   if(!SimIsFinite(point) || point<=0.0)
      return(SimPlanCheckResult(false,"point_invalid"));
   if(!SimIsFinite(min_stop_points) || min_stop_points<0.0)
      return(SimPlanCheckResult(false,"min_stop_invalid"));
   if(!SimIsFinite(min_target_points) || min_target_points<0.0)
      return(SimPlanCheckResult(false,"min_target_invalid"));

   if(!SimIsFinite(plan.entry) || plan.entry<=0.0)
      return(SimPlanCheckResult(false,"entry_invalid"));
   if(!SimIsFinite(plan.sl) || plan.sl<=0.0)
      return(SimPlanCheckResult(false,"sl_missing"));

   const bool is_long=(plan.side==SIM_SIDE_BUY);
   if(is_long && plan.sl>=plan.entry)
      return(SimPlanCheckResult(false,"sl_not_below_entry"));
   if(!is_long && plan.sl<=plan.entry)
      return(SimPlanCheckResult(false,"sl_not_above_entry"));

   const double tolerance=1e-9;
   const double stop_distance=MathAbs(plan.entry-plan.sl);
   if(stop_distance+tolerance<min_stop_points*point)
      return(SimPlanCheckResult(false,"stop_too_close"));

   if(!SimIsFinite(plan.tp1) || !SimIsFinite(plan.tp2) || !SimIsFinite(plan.tp3))
      return(SimPlanCheckResult(false,"tp_not_finite"));

   double targets[3];
   targets[0]=plan.tp1;
   targets[1]=plan.tp2;
   targets[2]=plan.tp3;

   double nearest=0.0;
   for(int i=0; i<3; i++)
     {
      if(targets[i]<=0.0)
         continue;
      if(is_long && targets[i]<=plan.entry)
         return(SimPlanCheckResult(false,"tp_not_above_entry"));
      if(!is_long && targets[i]>=plan.entry)
         return(SimPlanCheckResult(false,"tp_not_below_entry"));
      if(nearest==0.0)
         nearest=targets[i];
      else
         nearest=(is_long ? MathMin(nearest,targets[i]) : MathMax(nearest,targets[i]));
     }

   //--- binary rounding of price differences can land just below an exact
   //--- threshold, so the boundary itself must pass the check
   if(nearest>0.0 && MathAbs(nearest-plan.entry)+tolerance<min_target_points*point)
      return(SimPlanCheckResult(false,"target_too_close"));

   return(SimPlanCheckResult(true,""));
  }

//--- Chosen take-profit for the configured mode. 0 means "no target".
double SimPlanTargetPrice(const SimPlan &plan,const ENUM_SIM_PLAN_TARGET mode)
  {
   if(mode==SIM_PLAN_TARGET_NONE || plan.side==SIM_SIDE_NONE)
      return(0.0);
   if(mode==SIM_PLAN_TARGET_TP1)
      return(plan.tp1>0.0 ? plan.tp1 : 0.0);

   if(plan.tp3>0.0)
      return(plan.tp3);
   if(plan.tp2>0.0)
      return(plan.tp2);
   return(plan.tp1>0.0 ? plan.tp1 : 0.0);
  }

//--- Buy targets are hit by bid, sell targets by ask.
bool SimPlanTargetHit(const ENUM_SIM_SIDE side,const double target,
                      const double bid,const double ask)
  {
   if(target<=0.0)
      return(false);
   if(side==SIM_SIDE_BUY)
      return(bid>=target);
   if(side==SIM_SIDE_SELL)
      return(ask<=target);
   return(false);
  }

//--- Target fills never credit a favourable gap: the fill is the target.
double SimPlanTargetFill(const double target)
  {
   return(SimIsFinite(target) && target>0.0 ? target : 0.0);
  }

#endif // SIM_PLAN_MQH
