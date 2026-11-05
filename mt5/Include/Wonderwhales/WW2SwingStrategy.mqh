//+------------------------------------------------------------------+
//|                                             WW2SwingStrategy.mqh |
//|   Swing W1 bias / D1 agreement / H1 PSAR trigger on closed bars.  |
//|                                                                  |
//| Pure: takes indicator values, returns a decision. No I/O, no       |
//| account access, no trading calls, never recomputes the indicator.  |
//+------------------------------------------------------------------+
#ifndef WW2_SWING_STRATEGY_MQH
#define WW2_SWING_STRATEGY_MQH

#include "WW2Types.mqh"

//--- Per-gate detail of the Swing AND chain for the diagnostic census.
struct Ww2SwingGates
  {
   bool   bias_valid;      // W1 bars readable
   bool   bias_buy;        // W1 EMA trend is long
   bool   bias_sell;       // W1 EMA trend is short
   bool   setup_valid;     // D1 bars readable
   bool   setup_buy;       // D1 EMA agrees long
   bool   setup_sell;      // D1 EMA agrees short
   bool   setup_align;     // D1 agrees with the W1 side
   bool   trigger_valid;   // H1 bars readable
   bool   trigger_buy;     // H1 PSAR trigger is long
   bool   trigger_sell;    // H1 PSAR trigger is short
   bool   is_buy;          // side when reason == "signal"
   string reason;          // signal|bias_invalid|no_w1_bias|setup_invalid|
                           // no_d1_align|trigger_invalid|no_h1_trigger
  };

void Ww2ResetSwingGates(Ww2SwingGates &g)
  {
   g.bias_valid=false;
   g.bias_buy=false;
   g.bias_sell=false;
   g.setup_valid=false;
   g.setup_buy=false;
   g.setup_sell=false;
   g.setup_align=false;
   g.trigger_valid=false;
   g.trigger_buy=false;
   g.trigger_sell=false;
   g.is_buy=false;
   g.reason="none";
  }

bool Ww2SwingEvaluate(const Ww2Signal &w1,const Ww2Signal &d1,
                      const Ww2Signal &h1,Ww2SwingGates &g)
  {
   Ww2ResetSwingGates(g);
   g.bias_valid=w1.valid;
   g.setup_valid=d1.valid;
   g.trigger_valid=h1.valid;

   if(!w1.valid)
     {
      g.reason="bias_invalid";
      return(false);
     }

   g.bias_buy=(w1.fast_ema>w1.slow_ema && w1.close>=w1.slow_ema);
   g.bias_sell=(w1.fast_ema<w1.slow_ema && w1.close<=w1.slow_ema);
   if(!(g.bias_buy || g.bias_sell))
     {
      g.reason="no_w1_bias";
      return(false);
     }
   if(!d1.valid)
     {
      g.reason="setup_invalid";
      return(false);
     }
   if(!h1.valid)
     {
      g.reason="trigger_invalid";
      return(false);
     }

   g.setup_buy=(d1.fast_ema>d1.slow_ema);
   g.setup_sell=(d1.fast_ema<d1.slow_ema);
   g.trigger_buy=h1.buy;
   g.trigger_sell=h1.sell;

   //--- W1 and D1 must not conflict; EMA200 is a preference, not a veto.
   if(g.bias_buy)
     {
      g.setup_align=g.setup_buy;
      if(g.setup_buy)
        {
         if(h1.buy)
           {
            g.is_buy=true;
            g.reason="signal";
            return(true);
           }
         g.reason="no_h1_trigger";
         return(false);
        }
      g.reason="no_d1_align";
      return(false);
     }

   g.setup_align=g.setup_sell;
   if(g.setup_sell)
     {
      if(h1.sell)
        {
         g.is_buy=false;
         g.reason="signal";
         return(true);
        }
      g.reason="no_h1_trigger";
      return(false);
     }
   g.reason="no_d1_align";
   return(false);
  }

//--- Decision-only wrapper kept for the entry path and the core tests.
bool Ww2SwingEntry(const Ww2Signal &w1,const Ww2Signal &d1,
                   const Ww2Signal &h1,bool &is_buy)
  {
   Ww2SwingGates g;
   const bool ok=Ww2SwingEvaluate(w1,d1,h1,g);
   is_buy=(ok ? g.is_buy : false);
   return(ok);
  }

#endif
//+------------------------------------------------------------------+
