//+------------------------------------------------------------------+
//|                                        WW2TrailingCoordinator.mqh |
//|   Collects every SL candidate and returns the best protective one. |
//|                                                                  |
//| Rules: R is always measured from the stored initial SL; the chosen |
//| stop must only tighten (BUY higher, SELL lower) by at least the    |
//| minimum step; broker stop/freeze limits are applied by the caller. |
//+------------------------------------------------------------------+
#ifndef WW2_TRAILING_COORDINATOR_MQH
#define WW2_TRAILING_COORDINATOR_MQH

struct Ww2StopInput
  {
   //--- The management bar must close in the position's direction before any
   //--- break-even/trailing candidate may arm (spec §2.1/§2.2).
   bool   allow_arm;
   bool   is_buy;
   double entry;
   double initial_sl;
   double current_sl;
   double bid;
   double ask;
   double point;
   double min_step_points;
   double be_trigger_r;
   double be_buffer_points;
   double trail_trigger_r;
   bool   have_structure;
   double structure_sl;
   bool   enable_psar;
   double psar;
   bool   enable_atr;
   double atr_distance;
   bool   enable_step;
   double step_points;
  };

double Ww2StopR(const Ww2StopInput &in)
  {
   const double risk=MathAbs(in.entry-in.initial_sl);
   if(!(risk>0.0))
      return(0.0);
   const double px=(in.is_buy ? in.bid : in.ask);
   return(in.is_buy ? (px-in.entry)/risk : (in.entry-px)/risk);
  }

//--- Returns the best new SL, or 0.0 when no candidate tightens the stop by
//--- the minimum step. `reason` names the winning candidate.
double Ww2BestStop(const Ww2StopInput &in,string &reason)
  {
   reason="";
   if(!in.allow_arm)
      return(0.0);
   const double risk=MathAbs(in.entry-in.initial_sl);
   if(!(risk>0.0))
      return(0.0);

   const double r=Ww2StopR(in);
   const double current=(in.current_sl>0.0 ? in.current_sl : in.initial_sl);

   double cand[8];
   string label[8];
   int n=0;

   if(r>=in.be_trigger_r)
     {
      cand[n]=(in.is_buy ? in.entry+in.be_buffer_points*in.point
                         : in.entry-in.be_buffer_points*in.point);
      label[n]="BE";
      n++;
     }
   if(r>=in.trail_trigger_r)
     {
      if(in.have_structure && in.structure_sl>0.0)
        {
         cand[n]=in.structure_sl;
         label[n]="STRUCTURE";
         n++;
        }
      if(in.enable_psar && in.psar>0.0)
        {
         cand[n]=in.psar;
         label[n]="PSAR";
         n++;
        }
      if(in.enable_atr && in.atr_distance>0.0)
        {
         cand[n]=(in.is_buy ? in.bid-in.atr_distance
                            : in.ask+in.atr_distance);
         label[n]="ATR";
         n++;
        }
      if(in.enable_step && in.step_points>0.0 && in.current_sl>0.0)
        {
         cand[n]=(in.is_buy ? in.current_sl+in.step_points*in.point
                            : in.current_sl-in.step_points*in.point);
         label[n]="STEP";
         n++;
        }
     }

   double chosen=0.0;
   string chosen_label="";
   for(int i=0;i<n;i++)
     {
      const double c=cand[i];
      if(in.is_buy)
        {
         if(!(c<in.bid))
            continue;
         if(!(c>current+in.min_step_points*in.point))
            continue;
         if(chosen==0.0 || c>chosen)
           {
            chosen=c;
            chosen_label=label[i];
           }
        }
      else
        {
         if(!(c>in.ask))
            continue;
         if(!(c<current-in.min_step_points*in.point))
            continue;
         if(chosen==0.0 || c<chosen)
           {
            chosen=c;
            chosen_label=label[i];
           }
        }
     }

   if(chosen==0.0)
      return(0.0);
   reason=chosen_label;
   return(chosen);
  }

#endif
//+------------------------------------------------------------------+
