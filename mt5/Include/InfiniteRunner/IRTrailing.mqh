//+------------------------------------------------------------------+
//|                                                 IRTrailing.mqh   |
//|    InfiniteRunner V2 - pure SL/BE/trailing candidate math        |
//|                                                                  |
//| No trading API. Candidates are computed from values the caller   |
//| supplies (tick size, broker stop level, ATR). The EA still runs  |
//| ExecGuard broker checks before sending any modify request.       |
//| Invariants (spec §6.3): BUY SL never decreases, SELL SL never    |
//| increases, SL is tick-normalized, and a candidate that violates  |
//| the broker's minimum stop distance is refused, not clamped.      |
//+------------------------------------------------------------------+
#ifndef IR_TRAILING_MQH
#define IR_TRAILING_MQH

//--- Round a price onto the symbol's tick-size grid.
double IRNormalizePrice(const double price,const double tick_size,
                        const int digits)
  {
   if(!(tick_size>0.0))
      return(NormalizeDouble(price,digits));
   return(NormalizeDouble(MathRound(price/tick_size)*tick_size,digits));
  }

//--- Monotonic guard: only accept a candidate that strictly improves
//--- protection by at least `min_step_price`, or that sets an SL where there
//--- was none. A missing old SL counts as unprotected, so any valid
//--- protective candidate is an improvement.
bool IRMonotonicBetter(const bool is_buy,const double current_sl,
                       const double candidate,const double min_step_price)
  {
   if(!(candidate>0.0))
      return(false);
   if(!(current_sl>0.0))
      return(true);
   if(is_buy)
      return(candidate>=current_sl+min_step_price);
   return(candidate<=current_sl-min_step_price);
  }

//--- Break-even candidate from the ORIGINAL initial-risk distance R
//--- (never recomputed from a trailing SL): entry moved to entry plus a
//--- buffer in the direction of profit.
double IRBreakEvenCandidate(const bool is_buy,const double entry,
                            const double initial_r,const double trigger_r,
                            const double profit_price,
                            const double buffer_points,const double point)
  {
   if(!(initial_r>0.0) || !(trigger_r>0.0) || !(point>0.0))
      return(0.0);
   const double profit_units=(is_buy ? profit_price-entry : entry-profit_price);
   if(!(profit_units>=initial_r*trigger_r))
      return(0.0);
   const double buffer=buffer_points*point;
   if(is_buy)
      return((entry+buffer)>0.0 ? entry+buffer : 0.0);
   return((entry-buffer)>0.0 ? entry-buffer : 0.0);
  }

//--- Fixed-distance trailing candidate (V1 parity): reference is the price
//--- the trailing follows (bid for BUY, ask for SELL).
double IRFixedTrailCandidate(const bool is_buy,const double reference,
                             const double distance_points,const double point)
  {
   if(!(reference>0.0) || !(distance_points>0.0) || !(point>0.0))
      return(0.0);
   const double distance=distance_points*point;
   if(is_buy)
      return((reference-distance)>0.0 ? reference-distance : 0.0);
   return(reference+distance);
  }

//--- ATR trailing candidate: distance is a price value taken from the ATR of
//--- the last CLOSED bar so results are reproducible in the tester.
double IRAtrTrailCandidate(const bool is_buy,const double reference,
                           const double atr_last,const double multiplier)
  {
   if(!(reference>0.0) || !(atr_last>0.0) || !(multiplier>0.0))
      return(0.0);
   const double distance=atr_last*multiplier;
   if(is_buy)
      return((reference-distance)>0.0 ? reference-distance : 0.0);
   return(reference+distance);
  }

//--- Clamp a stop distance in points between the configured minimum and
//--- maximum. Stops outside this band are refused by the caller, never
//--- silently replaced by an arbitrary value.
bool IRStopDistanceAllowed(const double stop_points,const double min_points,
                           const double max_points,string &reason)
  {
   if(!(min_points>0.0) || !(max_points>0.0) || !(max_points>=min_points))
     {
      reason="stop_band_invalid";
      return(false);
     }
   if(stop_points<min_points)
     {
      reason=StringFormat("stop_too_tight|points=%.1f|min=%.1f",
                          stop_points,min_points);
      return(false);
     }
   if(stop_points>max_points)
     {
      reason=StringFormat("stop_too_wide|points=%.1f|max=%.1f",
                          stop_points,max_points);
      return(false);
     }
   return(true);
  }

//--- Candidate respects both the configured distance band at the current
//--- reference price and the broker's minimum stop level.
bool IRCandidateStopsValid(const bool is_buy,const bool is_initial,
                           const double reference,const double candidate_sl,
                           const double point,const double broker_stop_points,
                           const double min_points,const double max_points,
                           string &reason)
  {
   if(!(candidate_sl>0.0))
     {
      reason="candidate_sl_missing";
      return(false);
     }
   const double distance=IRStopDistance(is_buy,reference,candidate_sl,point);
   if(!(distance>0.0))
     {
      reason="candidate_distance_invalid";
      return(false);
     }
   //--- Initial SL must sit in the configured band; trail candidates only
   //--- need to clear the broker level (the band would fight protection).
   if(is_initial)
     {
      const double dist_points=distance/point;
      if(!IRStopDistanceAllowed(dist_points,min_points,max_points,reason))
         return(false);
     }
   const double min_level=broker_stop_points*point;
   if(distance<min_level)
     {
      reason=StringFormat("candidate_vs_broker_level|distance=%.8f|min=%.8f",
                          distance,min_level);
      return(false);
     }
   //--- Sl/TP on the right side of the market at all.
   if(is_buy && !(candidate_sl<reference) )
     {
      reason="candidate_sl_on_wrong_side";
      return(false);
     }
   if(!is_buy && !(candidate_sl>reference))
     {
      reason="candidate_sl_on_wrong_side";
      return(false);
     }
   return(true);
  }

//--- Helper: positive price distance by side (buy: ref - sl; sell: sl - ref).
double IRStopDistance(const bool is_buy,const double reference,
                      const double sl,const double point)
  {
   if(!(reference>0.0) || !(sl>0.0) || !(point>0.0))
      return(0.0);
   const double distance=(is_buy ? reference-sl : sl-reference);
   return((distance>0.0) ? distance : 0.0);
  }

//--- Safety TP price: a far mandatory take profit so every order carries
//--- SL and TP (ADR 0004) while the strategy still exits on the trailing SL.
double IRSafetyTpPrice(const bool is_buy,const double entry,
                       const double tp_points,const double point,
                       const int digits)
  {
   if(!(entry>0.0) || !(tp_points>0.0) || !(point>0.0))
      return(0.0);
   const double tp=(is_buy ? entry+tp_points*point
                           : entry-tp_points*point);
   if(!(tp>0.0))
      return(0.0);
   return(NormalizeDouble(tp,digits));
  }

//--- Step-trailing candidate (Tiered / Step Trailing for scalping/quick harvest):
//--- Checks 3 configured profit trigger levels and returns the highest corresponding lock level.
//--- Returns 0.0 if profit has not reached any trigger level.
double IRStepTrailCandidate(const bool is_buy,const double entry,
                            const double reference,const double point,
                            const double trig1_pts,const double lock1_pts,
                            const double trig2_pts,const double lock2_pts,
                            const double trig3_pts,const double lock3_pts,
                            string &step_reason)
  {
   if(!(entry>0.0) || !(reference>0.0) || !(point>0.0))
      return(0.0);
   const double profit_pts=(is_buy ? reference-entry : entry-reference)/point;
   if(profit_pts<=0.0)
      return(0.0);

   double lock_pts=0.0;
   //--- Check from highest tier to lowest tier
   if(trig3_pts>0.0 && profit_pts>=trig3_pts)
     {
      lock_pts=lock3_pts;
      step_reason=StringFormat("step3_locked|profit=%.0f|lock=%.0f",profit_pts,lock_pts);
     }
   else if(trig2_pts>0.0 && profit_pts>=trig2_pts)
     {
      lock_pts=lock2_pts;
      step_reason=StringFormat("step2_locked|profit=%.0f|lock=%.0f",profit_pts,lock_pts);
     }
   else if(trig1_pts>0.0 && profit_pts>=trig1_pts)
     {
      lock_pts=lock1_pts;
      step_reason=StringFormat("step1_locked|profit=%.0f|lock=%.0f",profit_pts,lock_pts);
     }
   else
      return(0.0);

   const double sl_distance=lock_pts*point;
   if(is_buy)
      return(entry+sl_distance);
   return(entry-sl_distance);
  }

#endif // IR_TRAILING_MQH
