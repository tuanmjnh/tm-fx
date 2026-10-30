//+------------------------------------------------------------------+
//|                                                        IRRisk.mqh |
//|      Sizing and lock arithmetic. Inputs are explicit; no APIs.    |
//+------------------------------------------------------------------+
#ifndef IR_RISK_MQH
#define IR_RISK_MQH

#include "IRTypes.mqh"

double IRRiskMoney(const double equity,const double risk_percent)
  {
   if(!IRIsFinitePositive(equity) || !IRIsFinitePositive(risk_percent))
      return(0.0);
   return(equity*risk_percent/100.0);
  }

double IRNormalizeVolume(const double volume,const double volume_min,
                         const double volume_max,const double volume_step)
  {
   if(!(volume>0.0) || !(volume_min>0.0) || !(volume_step>0.0) ||
      volume_max<volume_min)
      return(0.0);
   double value=MathFloor(volume/volume_step+1e-9)*volume_step;
   value=NormalizeDouble(value,8);
   if(value>volume_max)
      value=NormalizeDouble(volume_max,8);
   if(value<volume_min)
      return(0.0);
   return(value);
  }

IRLotDecision IRCalcLot(const ENUM_IR_LOT_MODE mode,const double equity,
                        const double risk_percent,const double fixed_lot,
                        const double max_lots,const double loss_per_lot,
                        const IRSymbolSpec &spec)
  {
   IRLotDecision decision;
   decision.ok=false;
   decision.volume=0.0;
   decision.expected_loss=0.0;
   decision.loss_per_lot=loss_per_lot;
   decision.risk_money=IRRiskMoney(equity,risk_percent);
   decision.reason="";

   if(!IRIsFinitePositive(spec.volume_min) ||
      !IRIsFinitePositive(spec.volume_step) ||
      spec.volume_max<spec.volume_min)
     {
      decision.reason="symbol_volume_limits_invalid";
      return(decision);
     }
   if(!IRIsFinitePositive(loss_per_lot))
     {
      decision.reason="loss_per_lot_invalid";
      return(decision);
     }

   double raw=0.0;
   if(mode==IR_LOT_FIXED)
     {
      if(!IRIsFinitePositive(fixed_lot))
        {
         decision.reason="fixed_lot_invalid";
         return(decision);
        }
      raw=fixed_lot;
      decision.risk_money=NormalizeDouble(fixed_lot*loss_per_lot,8);
     }
   else
     {
      if(!(decision.risk_money>0.0))
        {
         decision.reason="risk_budget_invalid";
         return(decision);
        }
      raw=decision.risk_money/loss_per_lot;
     }

   if(IRIsFinitePositive(max_lots) && raw>max_lots)
      raw=max_lots;

   double volume=IRNormalizeVolume(raw,spec.volume_min,spec.volume_max,
                                   spec.volume_step);
   if(volume<=0.0)
     {
      decision.reason="min_volume_exceeds_risk";
      return(decision);
     }

   const double expected=NormalizeDouble(volume*loss_per_lot,8);
   if(mode==IR_LOT_RISK_PERCENT &&
      expected>decision.risk_money*(1.0+1e-9))
     {
      decision.reason="expected_loss_exceeds_budget";
      return(decision);
     }

   decision.ok=true;
   decision.volume=volume;
   decision.expected_loss=expected;
   return(decision);
  }

bool IRDailyLossLocked(const double equity,const double day_start_equity,
                       const double max_daily_loss_pct)
  {
   if(!(max_daily_loss_pct>0.0) || !(day_start_equity>0.0) || !(equity>=0.0))
      return(false);
   const double loss=(day_start_equity-equity)/day_start_equity*100.0;
   return(loss>=max_daily_loss_pct);
  }

bool IRDrawdownLocked(const double equity,const double peak_equity,
                      const double max_dd_pct)
  {
   if(!(max_dd_pct>0.0) || !(peak_equity>0.0) || !(equity>=0.0))
      return(false);
   if(equity>=peak_equity)
      return(false);
   return(((peak_equity-equity)/peak_equity*100.0)>=max_dd_pct);
  }

bool IRCooldownActive(const datetime now,const datetime last_exit,
                      const int cooldown_minutes)
  {
   if(cooldown_minutes<=0 || last_exit<=0)
      return(false);
   return(now<last_exit+(datetime)cooldown_minutes*60);
  }

bool IRSpreadBlocked(const double spread_points,const double max_spread_points,
                     const double spread_price,const double atr,
                     const double max_spread_atr_ratio)
  {
   if(max_spread_points>0.0 && spread_points>max_spread_points)
      return(true);
   if(max_spread_atr_ratio>0.0 && atr>0.0 &&
      spread_price>atr*max_spread_atr_ratio)
      return(true);
   return(false);
  }

bool IRVolatilityBlocked(const double atr,const double atr_baseline,
                         const double abnormal_ratio)
  {
   if(!(abnormal_ratio>0.0) || !(atr_baseline>0.0) || !(atr>0.0))
      return(false);
   return(atr>=atr_baseline*abnormal_ratio);
  }

bool IRStopDistanceOk(const double entry,const double sl,const double atr,
                      const double min_atr,const double max_atr,
                      const double point,const double stops_level_points,
                      string &reason)
  {
   reason="";
   if(!IRIsFinitePositive(entry) || !IRIsFinitePositive(sl))
     {
      reason="stop_inputs_invalid";
      return(false);
     }
   const double distance=MathAbs(entry-sl);
   if(!(distance>0.0))
     {
      reason="stop_distance_zero";
      return(false);
     }
   if(IRIsFinitePositive(atr) && min_atr>0.0 && distance<min_atr*atr)
     {
      reason="stop_too_tight";
      return(false);
     }
   if(IRIsFinitePositive(atr) && max_atr>0.0 && distance>max_atr*atr)
     {
      reason="stop_too_wide";
      return(false);
     }
   if(point>0.0 && stops_level_points>0.0 &&
      distance/point<stops_level_points)
     {
      reason="stop_below_broker_level";
      return(false);
     }
   return(true);
  }

#endif // IR_RISK_MQH
