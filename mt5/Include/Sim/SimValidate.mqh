//+------------------------------------------------------------------+
//|                                                  SimValidate.mqh |
//|        MT5 EA Lab - input validation for simulation modules       |
//|                                                                  |
//| Every function returns false and fills error with a stable token. |
//| No market, account or trading API is touched.                     |
//+------------------------------------------------------------------+
#ifndef SIM_VALIDATE_MQH
#define SIM_VALIDATE_MQH

bool SimIsFinite(const double value)
  {
   return(MathIsValidNumber(value));
  }

bool SimValidatePrice(const double price,string &error)
  {
   if(!SimIsFinite(price) || price<=0.0)
     {
      error="price_must_be_finite_positive";
      return(false);
     }
   error="";
   return(true);
  }

bool SimValidateVolume(const double volume,string &error)
  {
   if(!SimIsFinite(volume) || volume<=0.0)
     {
      error="volume_must_be_finite_positive";
      return(false);
     }
   error="";
   return(true);
  }

bool SimValidateCommission(const double commission,string &error)
  {
   if(!SimIsFinite(commission) || commission<0.0)
     {
      error="commission_must_be_finite_non_negative";
      return(false);
     }
   error="";
   return(true);
  }

bool SimValidateInitialBalance(const double balance,string &error)
  {
   if(!SimIsFinite(balance) || balance<=0.0)
     {
      error="initial_balance_must_be_finite_positive";
      return(false);
     }
   error="";
   return(true);
  }

bool SimValidateLevels(const int levels,string &error)
  {
   if(levels<1 || levels>1000)
     {
      error="levels_must_be_between_1_and_1000";
      return(false);
     }
   error="";
   return(true);
  }

bool SimValidateMultiplier(const double multiplier,string &error)
  {
   if(!SimIsFinite(multiplier) || multiplier<1.0)
     {
      error="multiplier_must_be_finite_and_at_least_one";
      return(false);
     }
   error="";
   return(true);
  }

//--- Percentage in [0, 100]. Zero means "disabled" for a risk limit.
bool SimValidatePercent(const double percent,string &error)
  {
   if(!SimIsFinite(percent) || percent<0.0 || percent>100.0)
     {
      error="percent_must_be_finite_between_0_and_100";
      return(false);
     }
   error="";
   return(true);
  }

bool SimValidateSpreadPoints(const double points,string &error)
  {
   if(!SimIsFinite(points) || points<0.0)
     {
      error="spread_must_be_finite_non_negative";
      return(false);
     }
   error="";
   return(true);
  }

bool SimValidateWarmupBars(const int bars,string &error)
  {
   if(bars<0)
     {
      error="warmup_bars_must_be_non_negative";
      return(false);
     }
   error="";
   return(true);
  }

bool SimValidateSlippagePoints(const double points,string &error)
  {
   if(!SimIsFinite(points) || points<0.0)
     {
      error="slippage_must_be_finite_non_negative";
      return(false);
     }
   error="";
   return(true);
  }

bool SimValidatePoint(const double point,string &error)
  {
   if(!SimIsFinite(point) || point<=0.0)
     {
      error="point_must_be_finite_positive";
      return(false);
     }
   error="";
   return(true);
  }

//--- Generic finite check; token is supplied by the caller and must stay stable.
bool SimValidateFinite(const double value,const string token,string &error)
  {
   if(!SimIsFinite(value))
     {
      error=token;
      return(false);
     }
   error="";
   return(true);
  }

//--- Generic non-negative integer check; token is supplied by the caller.
bool SimValidateCount(const int value,const string token,string &error)
  {
   if(value<0)
     {
      error=token;
      return(false);
     }
   error="";
   return(true);
  }

#endif // SIM_VALIDATE_MQH
