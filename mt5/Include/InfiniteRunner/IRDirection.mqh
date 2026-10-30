//+------------------------------------------------------------------+
//|                                                 IRDirection.mqh  |
//|      InfiniteRunner V2 - pure direction engine on CLOSED bars    |
//|                                                                  |
//| No trading, account or network API. Every value is passed in by  |
//| the caller so the exact same code runs in the tester, on a demo  |
//| chart and in future logic tests. Decisions never use bar 0.      |
//+------------------------------------------------------------------+
#ifndef IR_DIRECTION_MQH
#define IR_DIRECTION_MQH

#include "IRTypes.mqh"

//--- EMA value series handed to the engine: index 0 = shift 1 (last CLOSED
//--- bar), index 1 = shift 2, ... index (slope_bars) = older anchor. The
//--- EA copies with CopyBuffer(handle, 0, 1, slope_bars+1, array) which is
//--- exactly closed-bar data; the engine asserts the size it needs.
#define IR_MIN_SERIES 2

//--- Signed slope over `bars` closed steps: value now minus value `bars` ago.
double IRDirSlope(const double &values[],const int bars)
  {
   if(bars<=0)
      return(0.0);
   if(ArraySize(values)<bars+1)
      return(0.0);
   return(values[0]-values[bars]);
  }

//--- Direction context from one timeframe: bullish / bearish / unstable.
//--- Bullish: fast above slow on the last closed bar AND the fast EMA slope
//--- is positive AND the slow EMA slope has not rolled down by more than the
//--- tolerance. Bearish is the mirror image. Anything else: no opinion.
bool IRBullishAlign(const double &fast[],const double &slow[],
                    const int slope_bars,const double point,
                    const double slow_tol_points,string &reason)
  {
   if(ArraySize(fast)<slope_bars+1 || ArraySize(slow)<slope_bars+1)
     {
      reason="series_too_short";
      return(false);
     }
   if(!(fast[0]>0.0) || !(slow[0]>0.0))
     {
      reason="ema_values_invalid";
      return(false);
     }
   const double fast_slope=IRDirSlope(fast,slope_bars);
   const double slow_slope=IRDirSlope(slow,slope_bars);
   const double slow_tol=slow_tol_points*point;
   if(!(fast[0]>slow[0]))
     {
      reason="fast_not_above_slow";
      return(false);
     }
   if(!(fast_slope>0.0))
     {
      reason="fast_slope_not_rising";
      return(false);
     }
   if(slow_slope < -slow_tol)
     {
      reason="slow_slope_rolling_down";
      return(false);
     }
   reason="bull_ok";
   return(true);
  }

bool IRBearishAlign(const double &fast[],const double &slow[],
                    const int slope_bars,const double point,
                    const double slow_tol_points,string &reason)
  {
   if(ArraySize(fast)<slope_bars+1 || ArraySize(slow)<slope_bars+1)
     {
      reason="series_too_short";
      return(false);
     }
   if(!(fast[0]>0.0) || !(slow[0]>0.0))
     {
      reason="ema_values_invalid";
      return(false);
     }
   const double fast_slope=IRDirSlope(fast,slope_bars);
   const double slow_slope=IRDirSlope(slow,slope_bars);
   const double slow_tol=slow_tol_points*point;
   if(!(fast[0]<slow[0]))
     {
      reason="fast_not_below_slow";
      return(false);
     }
   if(!(fast_slope<0.0))
     {
      reason="fast_slope_not_falling";
      return(false);
     }
   if(slow_slope > slow_tol)
     {
      reason="slow_slope_rolling_up";
      return(false);
     }
   reason="bear_ok";
   return(true);
  }

//--- M5 pullback-reclaim trigger (spec §4.3.4) from CLOSED bars only.
//--- BUY: previous closed bar close at/below (or within tolerance of) the
//--- fast EMA, the just-closed bar closes back above the fast EMA and above
//--- the slow EMA. SELL is the mirror image. Nothing else counts.
bool IRPullbackReclaimBuy(const double close_prev,const double close_last,
                          const double fast_prev,const double fast_last,
                          const double slow_last,const double point,
                          const double tol_points,string &reason)
  {
   const double tol=tol_points*point;
   if(!(fast_prev>0.0) || !(fast_last>0.0) || !(slow_last>0.0))
     {
      reason="ema_values_invalid";
      return(false);
     }
   if(!(close_prev<=fast_prev+tol))
     {
      reason="prev_bar_not_pullback";
      return(false);
     }
   if(!(close_last>fast_last))
     {
      reason="reclaim_missing";
      return(false);
     }
   if(!(close_last>slow_last))
     {
      reason="close_not_above_slow";
      return(false);
     }
   reason="buy_reclaim_ok";
   return(true);
  }

bool IRPullbackReclaimSell(const double close_prev,const double close_last,
                           const double fast_prev,const double fast_last,
                           const double slow_last,const double point,
                           const double tol_points,string &reason)
  {
   const double tol=tol_points*point;
   if(!(fast_prev>0.0) || !(fast_last>0.0) || !(slow_last>0.0))
     {
      reason="ema_values_invalid";
      return(false);
     }
   if(!(close_prev>=fast_prev-tol))
     {
      reason="prev_bar_not_pullback";
      return(false);
     }
   if(!(close_last<fast_last))
     {
      reason="reclaim_missing";
      return(false);
     }
   if(!(close_last<slow_last))
     {
      reason="close_not_below_slow";
      return(false);
     }
   reason="sell_reclaim_ok";
   return(true);
  }

//+------------------------------------------------------------------+
//| DIR_LEGACY_EMA - V1 parity, corrected to closed bars             |
//| V1 read EMA of the running bar (shift 0). Here the caller passes |
//| shift 1 / shift 2 values, so semantics match V1 but without the  |
//| repaint. Legacy never says NO_TRADE (that is its documented      |
//| weakness: it fires on every flat bar too).                       |
//+------------------------------------------------------------------+
void IRLegacyDecision(const double fast_last,const double slow_last,
                      IRDecision &decision)
  {
   IRClearDecision(decision);
   if(!(fast_last>0.0) || !(slow_last>0.0))
     {
      decision.decision=IR_DEC_DATA_NOT_READY;
      decision.reason="ema_values_invalid";
      return;
     }
   if(fast_last>=slow_last)
     {
      decision.decision=IR_DEC_BUY;
      decision.is_buy=true;
      decision.reason="legacy|fast>=slow|closed_bar";
     }
   else
     {
      decision.decision=IR_DEC_SELL;
      decision.is_buy=false;
      decision.reason="legacy|fast<slow|closed_bar";
     }
  }

//+------------------------------------------------------------------+
//| DIR_EMA_MTF - H1 context + M15 confirmation + M5 trigger          |
//| All series are closed-bar only. Conflicts or missing data never  |
//| force a trade: the caller gets NO_TRADE / REVERSAL_WATCH.        |
//+------------------------------------------------------------------+
void IRMtfDecision(const double &h1_fast[],const double &h1_slow[],
                   const double &m15_fast[],const double &m15_slow[],
                   const double close_m5_prev,const double close_m5_last,
                   const double m5_fast_prev,const double m5_fast_last,
                   const double m5_slow_last,
                   const int slope_bars,const double point,
                   const double slow_tol_points,const double pullback_tol_points,
                   IRDecision &decision)
  {
   IRClearDecision(decision);

   string h1_reason="";
   string m15_reason="";
   const int need=slope_bars+1;
   if(ArraySize(h1_fast)<need || ArraySize(h1_slow)<need ||
      ArraySize(m15_fast)<need || ArraySize(m15_slow)<need)
     {
      decision.decision=IR_DEC_DATA_NOT_READY;
      decision.reason="data|series_too_short";
      return;
     }

   string h1_bull_reason="", h1_bear_reason="";
   string m15_bull_reason="", m15_bear_reason="";
   const bool h1_bull=IRBullishAlign(h1_fast,h1_slow,slope_bars,point,
                                     slow_tol_points,h1_bull_reason);
   const bool h1_bear=IRBearishAlign(h1_fast,h1_slow,slope_bars,point,
                                     slow_tol_points,h1_bear_reason);
   const bool m15_bull=IRBullishAlign(m15_fast,m15_slow,slope_bars,point,
                                      slow_tol_points,m15_bull_reason);
   const bool m15_bear=IRBearishAlign(m15_fast,m15_slow,slope_bars,point,
                                      slow_tol_points,m15_bear_reason);
   h1_reason=(h1_bull ? "bull_ok" : (h1_bear ? "bear_ok" : h1_bull_reason+";"+h1_bear_reason));
   m15_reason=(m15_bull ? "bull_ok" : (m15_bear ? "bear_ok" : m15_bull_reason+";"+m15_bear_reason));

   if(!h1_bull && !h1_bear)
     {
      decision.decision=IR_DEC_REVERSAL_WATCH;
      decision.reason="mtf|h1_unstable|"+h1_reason;
      return;
     }
   if(h1_bull && !m15_bull)
     {
      if(m15_bear)
        {
         decision.decision=IR_DEC_NO_TRADE;
         decision.reason="mtf|h1_bull_vs_m15_bear_conflict";
        }
      else
         {
         decision.decision=IR_DEC_NO_TRADE;
         decision.reason="mtf|"+m15_reason;
        }
      return;
     }
   if(h1_bear && !m15_bear)
     {
      if(m15_bull)
        {
         decision.decision=IR_DEC_NO_TRADE;
         decision.reason="mtf|h1_bear_vs_m15_bull_conflict";
        }
      else
        {
         decision.decision=IR_DEC_NO_TRADE;
         decision.reason="mtf|"+m15_reason;
        }
      return;
     }

   if(h1_bull && m15_bull)
     {
      string trig_reason="";
      if(IRPullbackReclaimBuy(close_m5_prev,close_m5_last,m5_fast_prev,
                              m5_fast_last,m5_slow_last,point,
                              pullback_tol_points,trig_reason))
        {
         decision.decision=IR_DEC_BUY;
         decision.is_buy=true;
         decision.reason="mtf|h1_bull|m15_bull|"+trig_reason;
        }
      else
        {
         decision.decision=IR_DEC_NO_TRADE;
         decision.reason="mtf|h1_bull|m15_bull|"+trig_reason;
        }
      return;
     }

   string trig_reason="";
   if(IRPullbackReclaimSell(close_m5_prev,close_m5_last,m5_fast_prev,
                            m5_fast_last,m5_slow_last,point,
                            pullback_tol_points,trig_reason))
     {
      decision.decision=IR_DEC_SELL;
      decision.is_buy=false;
      decision.reason="mtf|h1_bear|m15_bear|"+trig_reason;
     }
   else
     {
      decision.decision=IR_DEC_NO_TRADE;
      decision.reason="mtf|h1_bear|m15_bear|"+trig_reason;
     }
  }

//--- Volatility gate: ATR of the just-closed bar against the mean ATR of a
//--- longer window, both closed bars. `cap_ratio` <= 0 disables the gate.
bool IRVolatilityBlocked(const double atr_last,const double atr_baseline,
                         const double cap_ratio,string &reason)
  {
   if(!(cap_ratio>0.0))
      return(false);
   if(!(atr_last>0.0) || !(atr_baseline>0.0))
     {
      reason="atr_data_invalid";
      return(true);
     }
   if(atr_baseline*cap_ratio<atr_last)
     {
      reason=StringFormat("atr_spiked|atr=%.8f|baseline=%.8f|cap=%.2f",
                          atr_last,atr_baseline,cap_ratio);
      return(true);
     }
   return(false);
  }

//--- Spread gate in absolute points and optionally relative to ATR.
bool IRSpreadBlocked(const double spread_points,const double max_points,
                     const double atr_last,const double max_atr_ratio,
                     const double point,string &reason)
  {
   if(!(max_points>0.0))
     {
      reason="spread_limit_not_configured";
      return(true);
     }
   if(spread_points>max_points)
     {
      reason=StringFormat("spread_wide|spread=%.1f|max=%.1f",
                          spread_points,max_points);
      return(true);
     }
   if(max_atr_ratio>0.0 && atr_last>0.0 &&
      spread_points*point>atr_last*max_atr_ratio)
     {
      reason=StringFormat("spread_vs_atr|spread=%.1f|ratio_cap=%.2f",
                          spread_points,max_atr_ratio);
      return(true);
     }
   return(false);
  }

#endif // IR_DIRECTION_MQH
