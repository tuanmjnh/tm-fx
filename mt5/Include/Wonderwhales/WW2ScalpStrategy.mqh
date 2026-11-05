//+------------------------------------------------------------------+
//|                                             WW2ScalpStrategy.mqh |
//|   Scalp M15 bias / M5 setup / M1 trigger on closed bars.          |
//|                                                                  |
//| Pure: takes indicator values, returns a decision. No I/O, no       |
//| account access, no trading calls, never recomputes the indicator.  |
//+------------------------------------------------------------------+
#ifndef WW2_SCALP_STRATEGY_MQH
#define WW2_SCALP_STRATEGY_MQH

#include "WW2Types.mqh"

//--- M15 trend filter: EMA20/EMA50 plus the close against EMA200.
bool Ww2ScalpBias(const Ww2Signal &m15,bool &bias_buy,bool &bias_sell)
  {
   bias_buy=false;
   bias_sell=false;
   if(!m15.valid)
      return(false);
   if(m15.fast_ema>m15.slow_ema && m15.close>m15.ema200)
      bias_buy=true;
   if(m15.fast_ema<m15.slow_ema && m15.close<m15.ema200)
      bias_sell=true;
   return(bias_buy || bias_sell);
  }

//--- Per-gate detail of the Scalp AND chain. The EA's diagnostic census
//--- (InpDebug) records one of these per evaluated bar, so "why so few trades"
//--- can be answered with data instead of guessing.
struct Ww2ScalpGates
  {
   bool   bias_valid;      // M15 bars readable
   bool   bias_buy;        // M15 bias is long
   bool   bias_sell;       // M15 bias is short
   bool   setup_valid;     // M5 bars readable
   bool   setup_buy;       // M5 PSAR/EMA signal is long
   bool   setup_sell;      // M5 PSAR/EMA signal is short
   bool   setup_align;     // M5 fast/slow EMA agrees with the bias side
   bool   sar_ok;          // M5 SAR direction still agrees (quality filter)
   bool   trigger_valid;   // M1 bars readable
   bool   trigger_buy;     // M1 confirmation is long
   bool   trigger_sell;    // M1 confirmation is short
   bool   is_buy;          // side when reason == "signal"
   string reason;          // signal|bias_invalid|no_m15_bias|setup_invalid|
                           // no_m5_flip|no_sar_agree|trigger_invalid|no_m1_confirm
  };

void Ww2ResetScalpGates(Ww2ScalpGates &g)
  {
   g.bias_valid=false;
   g.bias_buy=false;
   g.bias_sell=false;
   g.setup_valid=false;
   g.setup_buy=false;
   g.setup_sell=false;
   g.setup_align=false;
   g.sar_ok=true;
   g.trigger_valid=false;
   g.trigger_buy=false;
   g.trigger_sell=false;
   g.is_buy=false;
   g.reason="none";
  }

//--- M5 setup (PSAR flip agreeing with the M15 bias and its own EMAs) plus an
//--- M1 confirmation on the closed bar, reported gate by gate.
//---
//--- `sar_agree` is the optional quality filter (task H): true by default so
//--- every existing caller keeps the original behaviour. The EA computes it
//--- from the CURRENT M5 bar, which catches a trend that already flipped back
//--- since the (possibly older) setup bar fired.
bool Ww2ScalpEvaluate(const Ww2Signal &m15,const Ww2Signal &m5,
                      const Ww2Signal &m1,Ww2ScalpGates &g,
                      const bool sar_agree=true)
  {
   Ww2ResetScalpGates(g);
   g.bias_valid=m15.valid;
   g.setup_valid=m5.valid;
   g.trigger_valid=m1.valid;
   g.sar_ok=sar_agree;

   if(!m15.valid)
     {
      g.reason="bias_invalid";
      return(false);
     }
   if(!Ww2ScalpBias(m15,g.bias_buy,g.bias_sell))
     {
      g.reason="no_m15_bias";
      return(false);
     }
   if(!m5.valid)
     {
      g.reason="setup_invalid";
      return(false);
     }
   if(!m1.valid)
     {
      g.reason="trigger_invalid";
      return(false);
     }

   g.setup_buy=m5.buy;
   g.setup_sell=m5.sell;
   g.trigger_buy=m1.buy;
   g.trigger_sell=m1.sell;

   if(g.bias_buy)
     {
      g.setup_align=(m5.fast_ema>=m5.slow_ema);
      if(m5.buy && g.setup_align)
        {
         if(!g.sar_ok)
           {
            g.reason="no_sar_agree";
            return(false);
           }
         if(m1.buy)
           {
            g.is_buy=true;
            g.reason="signal";
            return(true);
           }
         g.reason="no_m1_confirm";
         return(false);
        }
      g.reason="no_m5_flip";
      return(false);
     }

   //--- bias_sell (Ww2ScalpBias never sets both sides at once).
   g.setup_align=(m5.fast_ema<=m5.slow_ema);
   if(m5.sell && g.setup_align)
     {
      if(!g.sar_ok)
        {
         g.reason="no_sar_agree";
         return(false);
        }
      if(m1.sell)
        {
         g.is_buy=false;
         g.reason="signal";
         return(true);
        }
      g.reason="no_m1_confirm";
      return(false);
     }
   g.reason="no_m5_flip";
   return(false);
  }

//--- Decision-only wrapper kept for the entry path and the core tests.
bool Ww2ScalpEntry(const Ww2Signal &m15,const Ww2Signal &m5,
                   const Ww2Signal &m1,bool &is_buy,
                   const bool sar_agree=true)
  {
   Ww2ScalpGates g;
   const bool ok=Ww2ScalpEvaluate(m15,m5,m1,g,sar_agree);
   is_buy=(ok ? g.is_buy : false);
   return(ok);
  }

#endif
//+------------------------------------------------------------------+
