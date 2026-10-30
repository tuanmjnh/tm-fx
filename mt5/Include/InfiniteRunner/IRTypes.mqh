//+------------------------------------------------------------------+
//|                                                     IRTypes.mqh  |
//|      InfiniteRunner V2 - shared enums, reason codes, structs     |
//|                                                                  |
//| Pure data definitions for the InfiniteRunner_XAU_V2 lab port.    |
//| No trading, account or network API is used here.                 |
//+------------------------------------------------------------------+
#ifndef IR_TYPES_MQH
#define IR_TYPES_MQH

//--- Direction engine modes (spec §4.2). DIR_PA_MTF is declared but NOT
//--- implemented in V2.1: without swing/BOS/CHoCH tests it must not exist.
enum ENUM_IR_DIRECTION_MODE
  {
   IR_DIR_LEGACY_EMA = 0,   // V1 parity: opposite-EMA on closed bars, always in
   IR_DIR_EMA_MTF    = 1    // H1 context + M15 confirm + M5 pullback-reclaim
  };

//--- ATR usage flags for the volatility gate (pure input, no API).
enum ENUM_IR_SL_MODE
  {
   IR_SL_FIXED = 0,         // initial SL in points (V1 parity, tick-normalized)
   IR_SL_ATR   = 1          // initial SL = ATR(entry TF, closed) * multiplier
  };

enum ENUM_IR_TRAIL_MODE
  {
   IR_TRAIL_FIXED = 0,      // V1 parity: fixed start/distance/step
   IR_TRAIL_ATR   = 1       // distance = ATR(entry TF, closed) * multiplier
  };

enum ENUM_IR_LOT_MODE
  {
   IR_LOT_FIXED = 0,        // InpLots every entry (comparison baseline)
   IR_LOT_RISK  = 1         // risk % of equity at the initial stop
  };

//--- Normalized direction decisions (spec §4.1).
enum ENUM_IR_DECISION
  {
   IR_DEC_BUY = 0,
   IR_DEC_SELL = 1,
   IR_DEC_NO_TRADE = 2,
   IR_DEC_REVERSAL_WATCH = 3,
   IR_DEC_DATA_NOT_READY = 4,
   IR_DEC_RISK_BLOCKED = 5,
   IR_DEC_SPREAD_BLOCKED = 6,
   IR_DEC_VOLATILITY_BLOCKED = 7
  };

//--- Decision plus a machine-readable reason token. The reason text is a
//--- stable contract between the EA journal, the CSV and the docs.
struct IRDecision
  {
   ENUM_IR_DECISION  decision;
   string            reason;
   bool              is_buy;
  };

void IRClearDecision(IRDecision &decision)
  {
   decision.decision=IR_DEC_NO_TRADE;
   decision.reason="";
   decision.is_buy=false;
  }

string IRDecisionName(const ENUM_IR_DECISION decision)
  {
   switch(decision)
     {
      case IR_DEC_BUY:                 return("BUY_ALLOWED");
      case IR_DEC_SELL:                return("SELL_ALLOWED");
      case IR_DEC_NO_TRADE:            return("NO_TRADE");
      case IR_DEC_REVERSAL_WATCH:      return("REVERSAL_WATCH");
      case IR_DEC_DATA_NOT_READY:      return("DATA_NOT_READY");
      case IR_DEC_RISK_BLOCKED:        return("RISK_BLOCKED");
      case IR_DEC_SPREAD_BLOCKED:      return("SPREAD_BLOCKED");
      case IR_DEC_VOLATILITY_BLOCKED:  return("VOLATILITY_BLOCKED");
     }
   return("UNKNOWN");
  }

//--- Stable state-file version for InfiniteRunnerXAUV2DemoEA persistence.
#define IR_STATE_VERSION 1

#endif // IR_TYPES_MQH
