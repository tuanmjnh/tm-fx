//+------------------------------------------------------------------+
//|                                                     TRSignal.mqh |
//|      PA_TrendRider_XAU_V1 - entry decision with reason codes      |
//|                                                                  |
//| The engine only decides; it never touches money, lots or files.   |
//| Every rejection carries a stable reason code for the CSV log.     |
//+------------------------------------------------------------------+
#ifndef TR_SIGNAL_MQH
#define TR_SIGNAL_MQH

#include "TRTypes.mqh"
#include "TRConfig.mqh"
#include "TRStructure.mqh"
#include "TRTrend.mqh"
#include "TRPullback.mqh"

struct TRSignalContext
  {
   bool              enabled;
   bool              data_ok;
   TRBiasResult      bias;
   bool              reversal_watch;
   bool              volatility_high;
   bool              spread_blocked;
   bool              risk_locked;
   bool              has_bos;
   ENUM_SIM_SIDE     bos_side;
   double            bos_level;
   datetime          bos_time;
   int               pullback_start_index;
   int               entry_count;
   double            atr;
   double            spread_price;
  };

struct TRSignalDecision
  {
   bool              entry;
   ENUM_SIM_SIDE     side;
   string            reason;
   double            zone_low;
   double            zone_high;
   double            confirm_close;
   int               confirm_index;
   int               bars_since_bos;
  };

void TRSignalClear(TRSignalDecision &decision)
  {
   decision.entry=false;
   decision.side=SIM_SIDE_NONE;
   decision.reason="";
   decision.zone_low=0.0;
   decision.zone_high=0.0;
   decision.confirm_close=0.0;
   decision.confirm_index=-1;
   decision.bars_since_bos=-1;
  }

void TRSignalBlock(TRSignalDecision &decision,const string reason)
  {
   TRSignalClear(decision);
   decision.reason="ENTRY_BLOCKED|reason="+reason;
  }

TRSignalDecision TREvaluateSignal(const TRConfig &cfg,
                                  const TRSignalContext &ctx,
                                  const TRBar &bars[])
  {
   TRSignalDecision decision;
   TRSignalClear(decision);
   decision.reason="ENTRY_BLOCKED|reason=no_setup";

   if(!ctx.enabled)
     {
      TRSignalBlock(decision,"disabled");
      return(decision);
     }
   if(!ctx.data_ok)
     {
      TRSignalBlock(decision,"data_invalid");
      return(decision);
     }
   if(ctx.risk_locked)
     {
      TRSignalBlock(decision,"risk_locked");
      return(decision);
     }
   if(ctx.spread_blocked)
     {
      TRSignalBlock(decision,"spread_blocked");
      return(decision);
     }
   if(ctx.volatility_high)
     {
      TRSignalBlock(decision,"volatility_high");
      return(decision);
     }
   if(ctx.reversal_watch)
     {
      TRSignalBlock(decision,"reversal_watch");
      return(decision);
     }
   if(!ctx.bias.valid)
     {
      TRSignalBlock(decision,"bias_unknown");
      return(decision);
     }
   if(ctx.bias.conflict)
     {
      TRSignalBlock(decision,"timeframe_conflict");
      return(decision);
     }
   if(ctx.bias.ranging || ctx.bias.direction==TR_DIR_UNKNOWN)
     {
      TRSignalBlock(decision,"regime_range");
      return(decision);
     }
   if(!ctx.has_bos || ctx.bos_side==SIM_SIDE_NONE)
     {
      TRSignalBlock(decision,"no_bos");
      return(decision);
     }
   if(TRSideToDirection(ctx.bos_side)!=ctx.bias.direction)
     {
      TRSignalBlock(decision,"bos_against_bias");
      return(decision);
     }
   if(ctx.pullback_start_index<0 || ctx.pullback_start_index>=ctx.entry_count)
     {
      TRSignalBlock(decision,"no_pullback");
      return(decision);
     }

   decision.bars_since_bos=ctx.entry_count-ctx.pullback_start_index;
   if(decision.bars_since_bos>cfg.max_signal_age_bars)
     {
      TRSignalBlock(decision,"bos_too_old");
      decision.bars_since_bos=ctx.entry_count-ctx.pullback_start_index;
      return(decision);
     }

   const TRRetestZone zone=TRBuildRetestZone(ctx.bos_side,ctx.bos_level,
                                             ctx.bos_time,
                                             ctx.pullback_start_index,
                                             ctx.atr,cfg.retest_zone_atr);
   if(!zone.valid)
     {
      TRSignalBlock(decision,"zone_invalid");
      return(decision);
     }
   decision.zone_low=zone.low;
   decision.zone_high=zone.high;

   const double buffer=TRBreakBuffer(ctx.atr,ctx.spread_price,cfg);
   const TRPullbackResult pullback=TREvaluatePullback(zone,bars,
                                                      ctx.pullback_start_index,
                                                      ctx.atr,buffer,cfg);
   if(!pullback.ok)
     {
      TRSignalBlock(decision,pullback.reason);
      decision.zone_low=zone.low;
      decision.zone_high=zone.high;
      return(decision);
     }

   decision.entry=true;
   decision.side=ctx.bos_side;
   decision.reason="SIGNAL_OK|zone_touch|confirmation_candle";
   decision.confirm_close=bars[pullback.confirm_index].close;
   decision.confirm_index=pullback.confirm_index;
   return(decision);
  }

//--- Index of the first entry bar that opened strictly after `after`.
//--- Returns -1 when no such bar exists; used to measure signal age.
int TRFirstIndexAfter(const TRBar &bars[],const datetime after)
  {
   const int count=ArraySize(bars);
   for(int i=0; i<count; i++)
      if(bars[i].time>after)
         return(i);
   return(-1);
  }

#endif // TR_SIGNAL_MQH
