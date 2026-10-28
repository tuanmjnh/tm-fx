//+------------------------------------------------------------------+
//|                                                      TRTrend.mqh |
//|      PA_TrendRider_XAU_V1 - H1/M15 bias and regime priority       |
//|                                                                  |
//| H1 gives context, M15 confirms structure. The merge is strict:    |
//| a conflict or missing data yields UNKNOWN and no new entry.       |
//+------------------------------------------------------------------+
#ifndef TR_TREND_MQH
#define TR_TREND_MQH

#include "TRTypes.mqh"
#include "TRStructure.mqh"

struct TRBiasResult
  {
   ENUM_TR_DIRECTION direction;
   bool              valid;
   bool              ranging;
   bool              conflict;
   string            reason;
  };

TRBiasResult TRMergeBias(const TRChainResult &h1,const TRChainResult &m15)
  {
   TRBiasResult bias;
   bias.direction=TR_DIR_UNKNOWN;
   bias.valid=false;
   bias.ranging=false;
   bias.conflict=false;
   bias.reason="";

   if(!h1.valid || !m15.valid)
     {
      bias.reason="insufficient_structure";
      return(bias);
     }
   if(h1.direction==TR_DIR_BULLISH && m15.direction==TR_DIR_BULLISH)
     {
      bias.direction=TR_DIR_BULLISH;
      bias.valid=true;
      bias.reason="aligned_bullish";
      return(bias);
     }
   if(h1.direction==TR_DIR_BEARISH && m15.direction==TR_DIR_BEARISH)
     {
      bias.direction=TR_DIR_BEARISH;
      bias.valid=true;
      bias.reason="aligned_bearish";
      return(bias);
     }
   if(h1.ranging && m15.ranging)
     {
      bias.valid=true;
      bias.ranging=true;
      bias.reason="range_both";
      return(bias);
     }
   bias.conflict=true;
   bias.reason="timeframe_conflict";
   return(bias);
  }

//--- Priority 1..5: risk lock, spread/volatility, reversal watch,
//--- trend, entry. Protective states cannot be overwritten by a signal.
ENUM_TR_REGIME TRResolveRegime(const TRBiasResult &bias,
                               const bool reversal_watch,
                               const bool volatility_high,
                               const bool spread_blocked,
                               const bool risk_locked,
                               const bool data_ok)
  {
   if(!data_ok)
      return(TR_REGIME_UNKNOWN);
   if(risk_locked)
      return(TR_REGIME_RISK_LOCKED);
   if(spread_blocked)
      return(TR_REGIME_SPREAD_BLOCKED);
   if(volatility_high)
      return(TR_REGIME_VOLATILITY_HIGH);
   if(reversal_watch)
      return(TR_REGIME_REVERSAL_WATCH);
   if(bias.valid && bias.direction==TR_DIR_BULLISH)
      return(TR_REGIME_TREND_UP);
   if(bias.valid && bias.direction==TR_DIR_BEARISH)
      return(TR_REGIME_TREND_DOWN);
   return(TR_REGIME_RANGE);
  }

#endif // TR_TREND_MQH
