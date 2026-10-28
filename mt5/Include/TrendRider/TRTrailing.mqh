//+------------------------------------------------------------------+
//|                                                   TRTrailing.mqh |
//|      PA_TrendRider_XAU_V1 - breakeven and trailing stop rules     |
//|                                                                  |
//| R is measured against the initial stop and is never recomputed    |
//| after the stop moves. Updates are monotonic: a candidate that is  |
//| not strictly better than the current stop is rejected.            |
//+------------------------------------------------------------------+
#ifndef TR_TRAILING_MQH
#define TR_TRAILING_MQH

#include "TRTypes.mqh"

struct TRTrailingInput
  {
   ENUM_SIM_SIDE     side;
   double            entry;
   double            sl;
   double            price;            // bid for BUY, ask for SELL
   double            initial_risk;     // initial stop distance, fixed at entry
   double            atr;
   double            structure_level;  // last opposing swing, 0 disables
   bool              use_structure;
   double            min_stop;         // minimum distance from price
   double            break_even_r;
   double            trail_start_r;
   double            trail_atr_mult;
  };

struct TRTrailingDecision
  {
   bool              update;
   double            new_sl;
   double            profit_r;
   string            reason;
  };

TRTrailingDecision TRTrailingEvaluate(const TRTrailingInput &in)
  {
   TRTrailingDecision out;
   out.update=false;
   out.new_sl=in.sl;
   out.profit_r=0.0;
   out.reason="HOLD";

   if(in.side==SIM_SIDE_NONE || !TRIsFinitePositive(in.entry) ||
      !TRIsFinitePositive(in.sl) || !TRIsFinitePositive(in.price) ||
      !TRIsFinitePositive(in.initial_risk) || in.atr<0.0 ||
      in.min_stop<0.0 || !TRIsFinitePositive(in.break_even_r) ||
      in.trail_start_r<in.break_even_r ||
      !TRIsFinitePositive(in.trail_atr_mult))
     {
      out.reason="INVALID_INPUTS";
      return(out);
     }

   const double profit=(in.side==SIM_SIDE_BUY ? in.price-in.entry
                                               : in.entry-in.price);
   out.profit_r=profit/in.initial_risk;
   if(profit<=0.0)
     {
      out.reason="HOLD_NO_PROFIT";
      return(out);
     }

   const bool is_buy=(in.side==SIM_SIDE_BUY);
   double candidate=in.sl;
   string reason="HOLD";

   if(out.profit_r>=in.break_even_r)
     {
      candidate=(is_buy ? MathMax(candidate,in.entry)
                        : MathMin(candidate,in.entry));
      reason="BREAK_EVEN";
     }

   if(out.profit_r>=in.trail_start_r)
     {
      if(in.atr>0.0)
        {
         const double atr_candidate=(is_buy
                                     ? in.price-in.atr*in.trail_atr_mult
                                     : in.price+in.atr*in.trail_atr_mult);
         const bool improves=(is_buy ? atr_candidate>candidate
                                     : atr_candidate<candidate);
         if(improves)
           {
            candidate=atr_candidate;
            reason="TRAIL_ATR";
           }
        }
      if(in.use_structure && TRIsFinitePositive(in.structure_level))
        {
         const bool improves=(is_buy ? in.structure_level>candidate
                                     : in.structure_level<candidate);
         if(improves)
           {
            candidate=in.structure_level;
            reason="TRAIL_STRUCTURE";
           }
        }
     }

   const bool better=(is_buy ? candidate>in.sl+1e-12
                             : candidate<in.sl-1e-12);
   if(!better)
     {
      out.reason="HOLD_NOT_IMPROVING";
      return(out);
     }

   if(in.min_stop>0.0)
     {
      if(is_buy && candidate>in.price-in.min_stop)
        {
         out.reason="TRAIL_TOO_CLOSE";
         return(out);
        }
      if(!is_buy && candidate<in.price+in.min_stop)
        {
         out.reason="TRAIL_TOO_CLOSE";
         return(out);
        }
     }

   out.update=true;
   out.new_sl=candidate;
   out.reason=reason;
   return(out);
  }

#endif // TR_TRAILING_MQH
