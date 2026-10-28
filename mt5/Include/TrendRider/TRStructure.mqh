//+------------------------------------------------------------------+
//|                                                  TRStructure.mqh |
//|      PA_TrendRider_XAU_V1 - BOS, CHoCH and protected swings       |
//|                                                                  |
//| A break is only accepted on a closed bar and only once per        |
//| broken swing, so a level cannot fire the same BOS on every tick.  |
//| CHoCH arms REVERSAL_WATCH and clears when the swing chain flips.  |
//+------------------------------------------------------------------+
#ifndef TR_STRUCTURE_MQH
#define TR_STRUCTURE_MQH

#include "TRTypes.mqh"
#include "TRConfig.mqh"
#include "TRSwing.mqh"

struct TRStructure
  {
   bool              has_high;
   bool              has_low;
   TRSwingPoint      last_high;
   TRSwingPoint      prev_high;
   TRSwingPoint      last_low;
   TRSwingPoint      prev_low;
   int               high_count;
   int               low_count;
  };

struct TRChainResult
  {
   ENUM_TR_DIRECTION direction;
   bool              valid;      // enough swings to classify
   bool              ranging;    // enough swings but no clean HH/HL chain
  };

struct TRStructureSnapshot
  {
   bool              valid;      // enough closed bars for a snapshot
   TRStructure       structure;
   TRChainResult     chain;
   ENUM_TR_EVENT     event;
   double            event_level;
   datetime          event_time;
   int               event_bar_index;
   bool              choch_active;
   ENUM_TR_DIRECTION choch_direction;
   int               bos_count;
   int               choch_count;
  };

void TRStructureClear(TRStructure &structure)
  {
   structure.has_high=false;
   structure.has_low=false;
   structure.last_high.valid=false;
   structure.prev_high.valid=false;
   structure.last_low.valid=false;
   structure.prev_low.valid=false;
   structure.high_count=0;
   structure.low_count=0;
  }

TRStructure TRBuildStructure(const TRSwingPoint &swings[])
  {
   TRStructure structure;
   TRStructureClear(structure);

   structure.last_high=TRLastSwingHigh(swings);
   structure.last_low=TRLastSwingLow(swings);
   structure.prev_high=TRPreviousSwing(swings,true);
   structure.prev_low=TRPreviousSwing(swings,false);
   structure.has_high=structure.last_high.valid;
   structure.has_low=structure.last_low.valid;

   const int count=ArraySize(swings);
   for(int i=0; i<count; i++)
     {
      if(!swings[i].valid)
         continue;
      if(swings[i].is_high)
         structure.high_count++;
      else
         structure.low_count++;
     }
   return(structure);
  }

//--- max(spread_price * multiplier, ATR * multiplier). Both terms are
//--- hypotheses from the specification, not market constants.
double TRBreakBuffer(const double atr,const double spread_price,
                     const TRConfig &cfg)
  {
   const double spread_term=(MathIsValidNumber(spread_price) && spread_price>0.0
                             ? spread_price*cfg.spread_buffer_multiplier : 0.0);
   const double atr_term=(MathIsValidNumber(atr) && atr>0.0
                          ? atr*cfg.atr_break_buffer_multiplier : 0.0);
   return(MathMax(spread_term,atr_term));
  }

//--- HH/HL versus LH/LL. A single swing is never enough: both highs and
//--- both lows must agree, otherwise the chain is RANGE or invalid.
TRChainResult TRChainFromStructure(const TRStructure &structure,
                                   const double min_delta)
  {
   TRChainResult result;
   result.direction=TR_DIR_UNKNOWN;
   result.valid=false;
   result.ranging=false;

   if(!structure.has_high || !structure.has_low ||
      !structure.prev_high.valid || !structure.prev_low.valid)
      return(result);

   const double delta=(MathIsValidNumber(min_delta) && min_delta>0.0
                       ? min_delta : 0.0);
   const bool higher_high=
      (structure.last_high.price>structure.prev_high.price+delta);
   const bool higher_low=
      (structure.last_low.price>structure.prev_low.price+delta);
   const bool lower_high=
      (structure.last_high.price<structure.prev_high.price-delta);
   const bool lower_low=
      (structure.last_low.price<structure.prev_low.price-delta);

   result.valid=true;
   if(higher_high && higher_low)
     {
      result.direction=TR_DIR_BULLISH;
      return(result);
     }
   if(lower_high && lower_low)
     {
      result.direction=TR_DIR_BEARISH;
      return(result);
     }
   result.ranging=true;
   return(result);
  }

bool TRIsBosBull(const double close,const double swing_high,
                 const double buffer)
  {
   return(swing_high>0.0 && close>swing_high+buffer);
  }

bool TRIsBosBear(const double close,const double swing_low,
                 const double buffer)
  {
   return(swing_low>0.0 && close<swing_low-buffer);
  }

//--- Break of the swing that protects a bullish (last low) or bearish
//--- (last high) structure.
bool TRIsChochBear(const TRStructure &structure,const double close,
                   const double buffer)
  {
   return(structure.has_low && close<structure.last_low.price-buffer);
  }

bool TRIsChochBull(const TRStructure &structure,const double close,
                   const double buffer)
  {
   return(structure.has_high && close>structure.last_high.price+buffer);
  }

class TRStructureEngine
  {
private:
   bool              m_initialized;
   datetime          m_last_update_bar;
   datetime          m_broken_high_time;
   datetime          m_broken_low_time;
   bool              m_choch_active;
   ENUM_TR_DIRECTION m_choch_direction;
   double            m_choch_level;
   datetime          m_choch_time;
   int               m_bos_count;
   int               m_choch_count;

public:
   TRStructureEngine(void)
     {
      Init();
     }

   void Init(void)
     {
      m_initialized=true;
      m_last_update_bar=0;
      m_broken_high_time=0;
      m_broken_low_time=0;
      m_choch_active=false;
      m_choch_direction=TR_DIR_UNKNOWN;
      m_choch_level=0.0;
      m_choch_time=0;
      m_bos_count=0;
      m_choch_count=0;
     }

   void Reset(void)
     {
      Init();
     }

   bool ChochActive(void) const { return(m_choch_active); }
   ENUM_TR_DIRECTION ChochDirection(void) const { return(m_choch_direction); }
   double ChochLevel(void) const { return(m_choch_level); }
   datetime ChochTime(void) const { return(m_choch_time); }
   int BosCount(void) const { return(m_bos_count); }
   int ChochCount(void) const { return(m_choch_count); }

   //--- Updates on the latest closed bar. Returns event=NONE when the
   //--- same bar is re-evaluated or when no new break exists.
   TRStructureSnapshot Update(const TRBar &bars[],const TRConfig &cfg,
                              const double atr,const double spread_price)
     {
      TRStructureSnapshot snapshot;
      snapshot.valid=false;
      snapshot.event=TR_EVENT_NONE;
      snapshot.event_level=0.0;
      snapshot.event_time=0;
      snapshot.event_bar_index=-1;
      snapshot.choch_active=m_choch_active;
      snapshot.choch_direction=m_choch_direction;
      snapshot.bos_count=m_bos_count;
      snapshot.choch_count=m_choch_count;
      TRStructureClear(snapshot.structure);
      snapshot.chain.direction=TR_DIR_UNKNOWN;
      snapshot.chain.valid=false;
      snapshot.chain.ranging=false;

      const int count=ArraySize(bars);
      if(count<(cfg.swing_left+cfg.swing_right+1))
         return(snapshot);

      snapshot.valid=true;
      TRSwingPoint swings[];
      TRCollectSwings(bars,cfg.swing_left,cfg.swing_right,swings);
      snapshot.structure=TRBuildStructure(swings);
      snapshot.chain=TRChainFromStructure(
                        snapshot.structure,
                        (MathIsValidNumber(atr) ? atr*cfg.trend_min_delta_atr : 0.0));

      const datetime bar_time=bars[count-1].time;
      if(bar_time==m_last_update_bar)
        {
         snapshot.choch_active=m_choch_active;
         snapshot.choch_direction=m_choch_direction;
         return(snapshot);
        }
      m_last_update_bar=bar_time;

      const double close=bars[count-1].close;
      const double buffer=TRBreakBuffer(atr,spread_price,cfg);

      //--- CHoCH first: it outranks a continuation event on the same bar.
      if(snapshot.chain.valid && !snapshot.chain.ranging)
        {
         if(snapshot.chain.direction==TR_DIR_BULLISH &&
            TRIsChochBear(snapshot.structure,close,buffer))
           {
            if(!m_choch_active || m_choch_direction!=TR_DIR_BEARISH)
              {
               m_choch_active=true;
               m_choch_direction=TR_DIR_BEARISH;
               m_choch_level=snapshot.structure.last_low.price;
               m_choch_time=bar_time;
               m_choch_count++;
               snapshot.event=TR_EVENT_CHOCH_BEAR;
               snapshot.event_level=m_choch_level;
               snapshot.event_time=bar_time;
               snapshot.event_bar_index=count-1;
              }
           }
         else if(snapshot.chain.direction==TR_DIR_BEARISH &&
                 TRIsChochBull(snapshot.structure,close,buffer))
           {
            if(!m_choch_active || m_choch_direction!=TR_DIR_BULLISH)
              {
               m_choch_active=true;
               m_choch_direction=TR_DIR_BULLISH;
               m_choch_level=snapshot.structure.last_high.price;
               m_choch_time=bar_time;
               m_choch_count++;
               snapshot.event=TR_EVENT_CHOCH_BULL;
               snapshot.event_level=m_choch_level;
               snapshot.event_time=bar_time;
               snapshot.event_bar_index=count-1;
              }
           }
        }

      //--- The warning is resolved when the chain itself flips.
      if(m_choch_active && snapshot.chain.valid && !snapshot.chain.ranging &&
         snapshot.chain.direction==m_choch_direction &&
         snapshot.event==TR_EVENT_NONE)
        {
         m_choch_active=false;
         m_choch_direction=TR_DIR_UNKNOWN;
        }

      //--- BOS: one break per swing, only when CHoCH did not fire first.
      //--- Dedupe uses the swing time, not its array index: indexes shift
      //--- as the rolling window advances, times do not.
      if(snapshot.event==TR_EVENT_NONE)
        {
         if(snapshot.structure.has_high &&
            snapshot.structure.last_high.time!=m_broken_high_time &&
            TRIsBosBull(close,snapshot.structure.last_high.price,buffer))
           {
            m_broken_high_time=snapshot.structure.last_high.time;
            m_bos_count++;
            snapshot.event=TR_EVENT_BOS_BULL;
            snapshot.event_level=snapshot.structure.last_high.price;
            snapshot.event_time=bar_time;
            snapshot.event_bar_index=count-1;
           }
         else if(snapshot.structure.has_low &&
                 snapshot.structure.last_low.time!=m_broken_low_time &&
                 TRIsBosBear(close,snapshot.structure.last_low.price,buffer))
           {
            m_broken_low_time=snapshot.structure.last_low.time;
            m_bos_count++;
            snapshot.event=TR_EVENT_BOS_BEAR;
            snapshot.event_level=snapshot.structure.last_low.price;
            snapshot.event_time=bar_time;
            snapshot.event_bar_index=count-1;
           }
        }

      snapshot.choch_active=m_choch_active;
      snapshot.choch_direction=m_choch_direction;
      snapshot.bos_count=m_bos_count;
      snapshot.choch_count=m_choch_count;
      return(snapshot);
     }
  };

#endif // TR_STRUCTURE_MQH
