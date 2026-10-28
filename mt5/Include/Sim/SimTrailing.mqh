//+------------------------------------------------------------------+
//|                                                  SimTrailing.mqh |
//|        MT5 EA Lab - pure trailing-stop decision helpers           |
//|                                                                  |
//| No state, no indicators and no trading APIs: callers pass prices  |
//| in, so the rules can be unit tested without a terminal.           |
//+------------------------------------------------------------------+
#ifndef SIM_TRAILING_MQH
#define SIM_TRAILING_MQH

#include "SimTypes.mqh"

struct SimTrailingInputs
  {
   ENUM_SIM_SIDE     side;
   double            entry;
   double            old_sl;
   double            price;            // market price the stop trails behind
   double            distance;         // stop distance in price units
   double            breakeven_trigger;// profit needed to move SL to entry; 0 disables
   double            breakeven_offset; // extra protection beyond entry, >= 0
   double            min_stop;         // minimum distance from price
  };

struct SimTrailingResult
  {
   bool              accepted;
   double            candidate_sl;    // unchanged old_sl when rejected
   double            raw_candidate;   // price +/- distance before breakeven clamp
   string            reason;
  };

//--- Long: candidate below price. Short: candidate above price.
//--- Breakeven can only pull the candidate towards entry, never past it.
SimTrailingResult SimTrailingEvaluate(const SimTrailingInputs &in)
  {
   SimTrailingResult out;
   out.accepted=false;
   out.candidate_sl=in.old_sl;
   out.raw_candidate=0.0;
   out.reason="";

   if(in.side==SIM_SIDE_NONE || in.entry<=0.0 || in.price<=0.0 ||
      in.distance<=0.0 || in.breakeven_trigger<0.0 ||
      in.breakeven_offset<0.0 || in.min_stop<0.0)
     {
      out.reason="invalid_inputs";
      return(out);
     }

   double candidate=(in.side==SIM_SIDE_BUY ? in.price-in.distance
                                            : in.price+in.distance);
   out.raw_candidate=candidate;

   if(in.breakeven_trigger>0.0)
     {
      const double profit=(in.side==SIM_SIDE_BUY ? in.price-in.entry
                                                 : in.entry-in.price);
      if(profit>=in.breakeven_trigger)
        {
         if(in.side==SIM_SIDE_BUY)
            candidate=MathMax(candidate,in.entry+in.breakeven_offset);
         else
            candidate=MathMin(candidate,in.entry-in.breakeven_offset);
        }
     }

   if(in.side==SIM_SIDE_BUY)
     {
      if(candidate>in.price-in.min_stop)
        {
         out.reason="candidate_too_close";
         return(out);
        }
      if(candidate<=in.old_sl)
        {
         out.reason="not_improving";
         return(out);
        }
     }
   else
     {
      if(candidate<in.price+in.min_stop)
        {
         out.reason="candidate_too_close";
         return(out);
        }
      if(candidate>=in.old_sl)
        {
         out.reason="not_improving";
         return(out);
        }
     }

   out.accepted=true;
   out.candidate_sl=candidate;
   return(out);
  }

//--- Long stops are triggered by bid, short stops by ask.
bool SimStopHit(const ENUM_SIM_SIDE side,const double sl,
                const double bid,const double ask)
  {
   if(side==SIM_SIDE_BUY)
      return(bid<=sl);
   if(side==SIM_SIDE_SELL)
      return(ask>=sl);
   return(false);
  }

//--- Requested exit price for a stop. A gap fills at the worse market price;
//--- slippage is applied afterwards by the cost model.
double SimStopFillPrice(const ENUM_SIM_SIDE side,const double sl,
                        const double bid,const double ask)
  {
   if(side==SIM_SIDE_BUY)
      return(MathMin(bid,sl));
   if(side==SIM_SIDE_SELL)
      return(MathMax(ask,sl));
   return(0.0);
  }

bool SimStopGapped(const ENUM_SIM_SIDE side,const double sl,
                   const double fill,const double tolerance=0.0)
  {
   if(side==SIM_SIDE_BUY)
      return(fill<sl-tolerance);
   if(side==SIM_SIDE_SELL)
      return(fill>sl+tolerance);
   return(false);
  }

#endif // SIM_TRAILING_MQH
