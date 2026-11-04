//+------------------------------------------------------------------+
//|                                                 WW2RiskSizer.mqh |
//|   Position sizing from the money risked at the initial stop.      |
//|                                                                  |
//| Pure math: the caller passes the loss-per-lot computed with       |
//| ExecCalcProfit, this module never calls a trading function.       |
//| It never rounds the volume up: if the minimum lot would exceed    |
//| the risk budget the entry is skipped.                             |
//+------------------------------------------------------------------+
#ifndef WW2_RISK_SIZER_MQH
#define WW2_RISK_SIZER_MQH

bool Ww2SizeVolume(const double risk_money,const double loss_per_lot,
                   const double vol_min,const double vol_max,
                   const double vol_step,const double max_exposure,
                   double &volume,string &reason)
  {
   volume=0.0;
   if(!(vol_min>0.0) || !(vol_step>0.0) || vol_max<vol_min)
     {
      reason="volume_constraints_invalid";
      return(false);
     }
   if(!(risk_money>0.0))
     {
      reason="risk_budget_not_positive";
      return(false);
     }
   if(!(loss_per_lot>0.0))
     {
      reason="loss_per_lot_not_positive";
      return(false);
     }

   const double cap=MathMin(max_exposure,vol_max);
   if(cap<vol_min)
     {
      reason="exposure_cap_below_min_lot";
      return(false);
     }

   const double raw=risk_money/loss_per_lot;
   double floored=MathFloor(raw/vol_step+1e-9)*vol_step;
   floored=NormalizeDouble(floored,8);
   if(!(floored>=vol_min))
     {
      reason=StringFormat("min_lot_over_budget|min_lot_loss=%.2f|budget=%.2f",
                          loss_per_lot*vol_min,risk_money);
      return(false);
     }

   double final_volume=MathMin(floored,cap);
   final_volume=NormalizeDouble(MathFloor(final_volume/vol_step+1e-9)*vol_step,8);
   if(!(final_volume>=vol_min))
     {
      reason=StringFormat("min_lot_over_budget|min_lot_loss=%.2f|budget=%.2f",
                          loss_per_lot*vol_min,risk_money);
      return(false);
     }

   const double final_loss=loss_per_lot*final_volume;
   if(final_loss>risk_money+1e-6)
     {
      reason=StringFormat("final_risk_over_budget|loss=%.2f|budget=%.2f",
                          final_loss,risk_money);
      return(false);
     }

   volume=final_volume;
   reason=StringFormat("lots=%.4f|loss=%.2f|budget=%.2f",volume,final_loss,
                       risk_money);
   return(true);
  }

#endif
//+------------------------------------------------------------------+
