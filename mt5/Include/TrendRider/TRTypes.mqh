//+------------------------------------------------------------------+
//|                                                      TRTypes.mqh |
//|      PA_TrendRider_XAU_V1 - shared simulation-only types          |
//|                                                                  |
//| Pure data types and names. No trading, account or broker APIs.    |
//+------------------------------------------------------------------+
#ifndef TR_TYPES_MQH
#define TR_TYPES_MQH

#include "../Sim/SimTypes.mqh"

//--- Direction of a confirmed structure sequence.
enum ENUM_TR_DIRECTION
  {
   TR_DIR_UNKNOWN = 0,
   TR_DIR_BULLISH = 1,
   TR_DIR_BEARISH = -1
  };

//--- Market regime, ordered by the priority used to block entries.
enum ENUM_TR_REGIME
  {
   TR_REGIME_UNKNOWN = 0,
   TR_REGIME_TREND_UP = 1,
   TR_REGIME_TREND_DOWN = 2,
   TR_REGIME_RANGE = 3,
   TR_REGIME_REVERSAL_WATCH = 4,
   TR_REGIME_VOLATILITY_HIGH = 5,
   TR_REGIME_SPREAD_BLOCKED = 6,
   TR_REGIME_RISK_LOCKED = 7
  };

//--- EA state machine states.
enum ENUM_TR_STATE
  {
   TR_STATE_INITIALIZING = 0,
   TR_STATE_READY = 1,
   TR_STATE_WAITING_FOR_SETUP = 2,
   TR_STATE_ENTRY_REQUESTED = 3,
   TR_STATE_POSITION_OPEN = 4,
   TR_STATE_REVERSAL_WATCH = 5,
   TR_STATE_CLOSE_FOR_REVERSAL = 6,
   TR_STATE_COOLDOWN = 7,
   TR_STATE_DAILY_LOCKED = 8,
   TR_STATE_DRAWDOWN_LOCKED = 9,
   TR_STATE_ERROR_SAFE_MODE = 10
  };

//--- Structure events emitted on a closed bar.
enum ENUM_TR_EVENT
  {
   TR_EVENT_NONE = 0,
   TR_EVENT_BOS_BULL = 1,
   TR_EVENT_BOS_BEAR = 2,
   TR_EVENT_CHOCH_BULL = 3,
   TR_EVENT_CHOCH_BEAR = 4
  };

//--- One closed candle. Bars are always passed oldest-first.
struct TRBar
  {
   datetime          time;
   double            open;
   double            high;
   double            low;
   double            close;
  };

//--- A confirmed fractal swing. valid=false when no swing exists yet.
struct TRSwingPoint
  {
   bool              valid;
   bool              is_high;
   int               index;         // bar index inside the supplied array
   datetime          time;          // swing bar open time
   int               confirm_index;  // index of the right-hand confirming bar
   datetime          confirm_time;  // close time of the confirming bar
   double            price;
  };

string TRDirectionName(const ENUM_TR_DIRECTION direction)
  {
   switch(direction)
     {
      case TR_DIR_BULLISH: return("BULLISH");
      case TR_DIR_BEARISH: return("BEARISH");
      default:             return("UNKNOWN");
     }
  }

string TRRegimeName(const ENUM_TR_REGIME regime)
  {
   switch(regime)
     {
      case TR_REGIME_TREND_UP:        return("TREND_UP");
      case TR_REGIME_TREND_DOWN:      return("TREND_DOWN");
      case TR_REGIME_RANGE:           return("RANGE");
      case TR_REGIME_REVERSAL_WATCH:  return("REVERSAL_WATCH");
      case TR_REGIME_VOLATILITY_HIGH: return("VOLATILITY_HIGH");
      case TR_REGIME_SPREAD_BLOCKED:  return("SPREAD_BLOCKED");
      case TR_REGIME_RISK_LOCKED:     return("RISK_LOCKED");
      default:                        return("UNKNOWN");
     }
  }

string TRStateName(const ENUM_TR_STATE state)
  {
   switch(state)
     {
      case TR_STATE_READY:              return("READY");
      case TR_STATE_WAITING_FOR_SETUP:  return("WAITING_FOR_SETUP");
      case TR_STATE_ENTRY_REQUESTED:    return("ENTRY_REQUESTED");
      case TR_STATE_POSITION_OPEN:      return("POSITION_OPEN");
      case TR_STATE_REVERSAL_WATCH:     return("REVERSAL_WATCH");
      case TR_STATE_CLOSE_FOR_REVERSAL: return("CLOSE_FOR_REVERSAL");
      case TR_STATE_COOLDOWN:           return("COOLDOWN");
      case TR_STATE_DAILY_LOCKED:       return("DAILY_LOCKED");
      case TR_STATE_DRAWDOWN_LOCKED:    return("DRAWDOWN_LOCKED");
      case TR_STATE_ERROR_SAFE_MODE:    return("ERROR_SAFE_MODE");
      default:                          return("INITIALIZING");
     }
  }

string TREventName(const ENUM_TR_EVENT event)
  {
   switch(event)
     {
      case TR_EVENT_BOS_BULL:   return("BOS_BULL");
      case TR_EVENT_BOS_BEAR:   return("BOS_BEAR");
      case TR_EVENT_CHOCH_BULL: return("CHOCH_BULL");
      case TR_EVENT_CHOCH_BEAR: return("CHOCH_BEAR");
      default:                  return("NONE");
     }
  }

ENUM_SIM_SIDE TRDirectionToSide(const ENUM_TR_DIRECTION direction)
  {
   if(direction==TR_DIR_BULLISH)
      return(SIM_SIDE_BUY);
   if(direction==TR_DIR_BEARISH)
      return(SIM_SIDE_SELL);
   return(SIM_SIDE_NONE);
  }

ENUM_TR_DIRECTION TRSideToDirection(const ENUM_SIM_SIDE side)
  {
   if(side==SIM_SIDE_BUY)
      return(TR_DIR_BULLISH);
   if(side==SIM_SIDE_SELL)
      return(TR_DIR_BEARISH);
   return(TR_DIR_UNKNOWN);
  }

bool TRIsFinitePositive(const double value)
  {
   return(MathIsValidNumber(value) && value>0.0);
  }

#endif // TR_TYPES_MQH
