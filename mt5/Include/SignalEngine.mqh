//+------------------------------------------------------------------+
//|                                                 SignalEngine.mqh |
//|        MT5 EA & AI Lab - signal decisions without execution      |
//|                                                                  |
//| The engine consumes closed bars only and never places orders.    |
//| Input prices are chronological (index 0 = oldest closed bar).    |
//+------------------------------------------------------------------+
#ifndef LAB_SIGNAL_ENGINE_MQH
#define LAB_SIGNAL_ENGINE_MQH

#include "Indicators.mqh"

enum ENUM_LAB_SIGNAL
  {
   LAB_SIGNAL_UNKNOWN = 0,  // Could not evaluate the strategy
   LAB_SIGNAL_HOLD    = 1,  // Evaluated, no actionable signal
   LAB_SIGNAL_BUY     = 2,
   LAB_SIGNAL_SELL    = 3
  };

enum ENUM_LAB_REASON
  {
   LAB_REASON_OK = 0,
   LAB_REASON_INSUFFICIENT_HISTORY = 1,
   LAB_REASON_INVALID_CONFIG = 2,
   LAB_REASON_INVALID_INPUT = 3,
   LAB_REASON_INDICATOR_FAILED = 4,
   LAB_REASON_NO_CROSS = 5,
   LAB_REASON_LONG_DISABLED = 6,
   LAB_REASON_SHORT_DISABLED = 7
  };

struct LabSignalConfig
  {
   int               fast_period;
   int               slow_period;
   bool              allow_long;
   bool              allow_short;
  };

struct LabSignalResult
  {
   ENUM_LAB_SIGNAL   signal;
   ENUM_LAB_REASON   reason;
   double            fast_prev;
   double            slow_prev;
   double            fast_now;
   double            slow_now;
   int               bars_used;
  };

string LabSignalName(const ENUM_LAB_SIGNAL signal)
  {
   switch(signal)
     {
      case LAB_SIGNAL_HOLD: return("HOLD");
      case LAB_SIGNAL_BUY:  return("BUY");
      case LAB_SIGNAL_SELL: return("SELL");
      default:              return("UNKNOWN");
     }
  }

string LabReasonName(const ENUM_LAB_REASON reason)
  {
   switch(reason)
     {
      case LAB_REASON_OK:                   return("OK");
      case LAB_REASON_INSUFFICIENT_HISTORY: return("INSUFFICIENT_HISTORY");
      case LAB_REASON_INVALID_CONFIG:       return("INVALID_CONFIG");
      case LAB_REASON_INVALID_INPUT:        return("INVALID_INPUT");
      case LAB_REASON_INDICATOR_FAILED:     return("INDICATOR_FAILED");
      case LAB_REASON_NO_CROSS:             return("NO_CROSS");
      case LAB_REASON_LONG_DISABLED:        return("LONG_DISABLED");
      case LAB_REASON_SHORT_DISABLED:       return("SHORT_DISABLED");
      default:                              return("UNKNOWN_REASON");
     }
  }

bool LabValidateSignalConfig(const LabSignalConfig &config,string &error)
  {
   if(config.fast_period<=0)
     {
      error="fast_period_must_be_positive";
      return(false);
     }
   if(config.slow_period<=0)
     {
      error="slow_period_must_be_positive";
      return(false);
     }
   if(config.fast_period>=config.slow_period)
     {
      error="fast_period_must_be_lower_than_slow_period";
      return(false);
     }

   error="";
   return(true);
  }

void LabResetSignalResult(LabSignalResult &result)
  {
   result.signal=LAB_SIGNAL_UNKNOWN;
   result.reason=LAB_REASON_OK;
   result.fast_prev=0.0;
   result.slow_prev=0.0;
   result.fast_now=0.0;
   result.slow_now=0.0;
   result.bars_used=0;
  }

//--- Pure crossover decision. No indicator math, no data access.
//--- BUY  : fast was at or below slow, then crossed above.
//--- SELL : fast was at or above slow, then crossed below.
//--- HOLD : evaluated but no cross, or the direction is disabled.
//--- UNKNOWN: inputs are unusable, so no decision exists.
void LabEvaluateCrossover(const double fast_prev,const double slow_prev,
                          const double fast_now,const double slow_now,
                          const bool allow_long,const bool allow_short,
                          ENUM_LAB_SIGNAL &signal,ENUM_LAB_REASON &reason)
  {
   signal=LAB_SIGNAL_UNKNOWN;
   reason=LAB_REASON_OK;

   if(!LabIsUsableValue(fast_prev) || !LabIsUsableValue(slow_prev) ||
      !LabIsUsableValue(fast_now)  || !LabIsUsableValue(slow_now))
     {
      reason=LAB_REASON_INVALID_INPUT;
      return;
     }

   if(fast_prev<=slow_prev && fast_now>slow_now)
     {
      if(!allow_long)
        {
         signal=LAB_SIGNAL_HOLD;
         reason=LAB_REASON_LONG_DISABLED;
         return;
        }
      signal=LAB_SIGNAL_BUY;
      reason=LAB_REASON_OK;
      return;
     }

   if(fast_prev>=slow_prev && fast_now<slow_now)
     {
      if(!allow_short)
        {
         signal=LAB_SIGNAL_HOLD;
         reason=LAB_REASON_SHORT_DISABLED;
         return;
        }
      signal=LAB_SIGNAL_SELL;
      reason=LAB_REASON_OK;
      return;
     }

   signal=LAB_SIGNAL_HOLD;
   reason=LAB_REASON_NO_CROSS;
  }

//--- Evaluate an EMA crossover on chronological closed prices.
//--- The last element is the most recently closed bar; the current
//--- forming bar must not be included.
//--- Returns true when a decision (including HOLD) was produced.
bool LabEvaluateEmaCrossover(const double &closed_prices[],const int count,
                             const LabSignalConfig &config,
                             LabSignalResult &result)
  {
   LabResetSignalResult(result);

   string config_error="";
   if(!LabValidateSignalConfig(config,config_error))
     {
      result.reason=LAB_REASON_INVALID_CONFIG;
      return(false);
     }

   //--- One crossover needs fast/slow values on two consecutive closed bars.
   if(count<config.slow_period+1)
     {
      result.reason=LAB_REASON_INSUFFICIENT_HISTORY;
      return(false);
     }

   double fast[];
   double slow[];
   if(!LabComputeEma(closed_prices,count,config.fast_period,fast) ||
      !LabComputeEma(closed_prices,count,config.slow_period,slow))
     {
      result.reason=LAB_REASON_INDICATOR_FAILED;
      return(false);
     }

   const int last=count-1;
   result.fast_prev=fast[last-1];
   result.slow_prev=slow[last-1];
   result.fast_now=fast[last];
   result.slow_now=slow[last];
   result.bars_used=count;

   LabEvaluateCrossover(result.fast_prev,result.slow_prev,
                        result.fast_now,result.slow_now,
                        config.allow_long,config.allow_short,
                        result.signal,result.reason);

   return(result.signal!=LAB_SIGNAL_UNKNOWN);
  }

#endif // LAB_SIGNAL_ENGINE_MQH
