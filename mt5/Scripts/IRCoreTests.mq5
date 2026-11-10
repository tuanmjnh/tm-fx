//+------------------------------------------------------------------+
//|                                                  IRCoreTests.mq5  |
//|   Contract tests for the pure InfiniteRunner V2 modules.          |
//|                                                                    |
//| Run on a demo chart: Scripts > IRCoreTests. Expect a line          |
//|   TEST|RESULT|ALL_PASS|pass=N fail=0|ir=1                          |
//| No trading, no account access, no file I/O.                        |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Pure-logic contract tests for the InfiniteRunner V2 modules."

#include "../Include/InfiniteRunner/IRTypes.mqh"
#include "../Include/InfiniteRunner/IRDirection.mqh"
#include "../Include/InfiniteRunner/IRTrailing.mqh"
#include "../Include/InfiniteRunner/IRRisk.mqh"

int g_pass=0;
int g_fail=0;

void Check(const bool ok,const string name)
  {
   if(ok)
     {
      g_pass++;
      PrintFormat("TEST|PASS|%s",name);
     }
   else
     {
      g_fail++;
      PrintFormat("TEST|FAIL|%s",name);
     }
  }

bool Near(const double a,const double b,const double tol)
  {
   return(MathAbs(a-b)<=tol);
  }

void TestLossStreakGuard(void)
  {
   const datetime now=StringToTime("2026.03.02 12:00");
   datetime next=0;
   string reason="";

   //--- Disabled guard, or a streak below the limit, never blocks.
   Check(IRLossStreakDecide(9,0,240,now,0,next,reason)==IR_STREAK_ALLOW,
         "streak_disabled_allows");
   Check(IRLossStreakDecide(2,3,240,now,0,next,reason)==IR_STREAK_ALLOW,
         "streak_below_limit_allows");

   //--- Legacy escape hatch: no cooldown configured -> permanent block.
   next=0;
   const ENUM_IR_STREAK_ACTION legacy=
      IRLossStreakDecide(3,3,0,now,0,next,reason);
   Check(legacy==IR_STREAK_BLOCK && StringFind(reason,"loss_streak|")==0 &&
         reason!="" && next==0,"streak_legacy_permanent_lock");

   //--- First breach arms the cooldown for cooldown_minutes.
   next=0;
   reason="";
   const ENUM_IR_STREAK_ACTION armed=
      IRLossStreakDecide(3,3,240,now,0,next,reason);
   Check(armed==IR_STREAK_BLOCK && StringFind(reason,"loss_streak_armed|")==0 &&
         next==now+240*60,"streak_arms_cooldown_on_first_breach");

   //--- While the cooldown runs the guard blocks and keeps the same deadline.
   const datetime until=now+100;
   next=0;
   reason="";
   const ENUM_IR_STREAK_ACTION waiting=
      IRLossStreakDecide(3,3,240,now,until,next,reason);
   Check(waiting==IR_STREAK_BLOCK &&
         StringFind(reason,"loss_streak_cooldown|")==0 && next==until,
         "streak_blocks_while_cooldown_runs");

   //--- Cooldown served -> recover (clear the streak) and clear the deadline.
   next=99;
   reason="x";
   const ENUM_IR_STREAK_ACTION recovered=
      IRLossStreakDecide(3,3,240,now,now-1,next,reason);
   Check(recovered==IR_STREAK_RECOVER && next==0 && reason=="",
         "streak_recovers_after_cooldown");

   //--- Exact boundary: now == cooldown_until counts as served.
   next=99;
   reason="x";
   const ENUM_IR_STREAK_ACTION boundary=
      IRLossStreakDecide(3,3,240,now,now,next,reason);
   Check(boundary==IR_STREAK_RECOVER && next==0,
         "streak_recovers_on_boundary");
  }

void TestStepTrailing(void)
  {
   string reason="";
   const double entry=2000.0;
   const double point=0.01;

   //--- Below the first trigger: no lock yet.
   Check(IRStepTrailCandidate(true,entry,2005.0,point,
                              1500.0,200.0,3000.0,1500.0,5000.0,3500.0,
                              reason)==0.0,"step_no_lock_below_trigger");

   //--- Profit at/above 1500 points locks the step-1 level (entry+200 pts).
   //--- Reference is placed one point past each trigger so the comparison is
   //--- not decided by float rounding at the boundary.
   Check(Near(IRStepTrailCandidate(true,entry,entry+1501.0*point,point,
                                   1500.0,200.0,3000.0,1500.0,5000.0,3500.0,
                                   reason),
              entry+200.0*point,1e-9),"step1_locks_entry_plus_200");

   //--- Higher tiers win: at 3000 points the lock is step-2 (1500 points).
   Check(Near(IRStepTrailCandidate(true,entry,entry+3001.0*point,point,
                                   1500.0,200.0,3000.0,1500.0,5000.0,3500.0,
                                   reason),
              entry+1500.0*point,1e-9),"step2_locks_entry_plus_1500");

   //--- And at 5000 points the lock is step-3 (3500 points).
   Check(Near(IRStepTrailCandidate(true,entry,entry+5001.0*point,point,
                                   1500.0,200.0,3000.0,1500.0,5000.0,3500.0,
                                   reason),
              entry+3500.0*point,1e-9),"step3_locks_entry_plus_3500");

   //--- SELL mirrors the lock below the entry.
   Check(Near(IRStepTrailCandidate(false,entry,entry-1501.0*point,point,
                                   1500.0,200.0,3000.0,1500.0,5000.0,3500.0,
                                   reason),
              entry-200.0*point,1e-9),"step_sell_locks_below_entry");
  }

void TestBreakEvenAndMonotonic(void)
  {
   //--- BE triggers once the profit reaches trigger_r * initial_r.
   Check(Near(IRBreakEvenCandidate(true,2000.0,5.0,1.0,2005.0,100.0,0.01),
              2001.0,1e-9),"be_buy_fires_at_one_r");
   Check(Near(IRBreakEvenCandidate(false,2000.0,5.0,1.0,1995.0,100.0,0.01),
              1999.0,1e-9),"be_sell_fires_at_one_r");
   Check(IRBreakEvenCandidate(true,2000.0,5.0,1.0,2004.0,100.0,0.01)==0.0,
         "be_waits_below_trigger");

   //--- Monotonic guard: a BUY stop may only rise by the minimum step.
   Check(IRMonotonicBetter(true,1995.0,2000.0,0.5),"monotonic_buy_improves");
   Check(!IRMonotonicBetter(true,1995.0,1995.2,0.5),"monotonic_buy_rejects_tiny");
   Check(IRMonotonicBetter(false,2005.0,2000.0,0.5),"monotonic_sell_improves");
   Check(!IRMonotonicBetter(false,2005.0,2004.8,0.5),"monotonic_sell_rejects_tiny");

   //--- The initial stop must sit inside the configured band.
   string reason="";
   Check(IRStopDistanceAllowed(500.0,500.0,20000.0,reason),
         "band_accepts_min_edge");
   Check(!IRStopDistanceAllowed(400.0,500.0,20000.0,reason) &&
         StringFind(reason,"stop_too_tight")==0,"band_rejects_too_tight");
   Check(!IRStopDistanceAllowed(30000.0,500.0,20000.0,reason) &&
         StringFind(reason,"stop_too_wide")==0,"band_rejects_too_wide");
  }

void TestRegimeEntry(void)
  {
   //--- slope_bars-1 arrays, index 0 = last closed bar.
   const int n=6;
   const double point=0.001;
   const double tol=100.0;
   double hf[],hs[];
   ArrayResize(hf,n);
   ArrayResize(hs,n);
   for(int i=0;i<n;i++)
     {
      hf[i]=2010.0-i;   // fast above slow, fast rising
      hs[i]=2000.0-i;
     }
   IRDecision d;

   //--- bullish H1 + close above the channel high -> BUY.
   IRRegimeDecision(hf,hs,5,point,tol,2000.0,1990.0,2010.0,d);
   Check(d.decision==IR_DEC_BUY && d.is_buy,"regime_bull_breakout_buy");

   //--- bullish H1 but close inside the channel -> NO_TRADE.
   IRRegimeDecision(hf,hs,5,point,tol,2000.0,1990.0,1995.0,d);
   Check(d.decision==IR_DEC_NO_TRADE,"regime_bull_no_breakout");

   //--- bearish H1 + close below the channel low -> SELL.
   double bf[],bs[];
   ArrayResize(bf,n);
   ArrayResize(bs,n);
   for(int i=0;i<n;i++)
     {
      bf[i]=1990.0-i;   // fast below slow, fast falling
      bs[i]=2000.0-i;
     }
   IRRegimeDecision(bf,bs,5,point,tol,2005.0,1990.0,1980.0,d);
   Check(d.decision==IR_DEC_SELL && !d.is_buy,"regime_bear_breakout_sell");

   //--- flat H1 -> NO_TRADE.
   double ff[],fs2[];
   ArrayResize(ff,n);
   ArrayResize(fs2,n);
   for(int i=0;i<n;i++)
     {
      ff[i]=2000.0;
      fs2[i]=2000.0;
     }
   IRRegimeDecision(ff,fs2,5,point,tol,2005.0,1990.0,2010.0,d);
   Check(d.decision==IR_DEC_NO_TRADE && StringFind(d.reason,"h1_no_context")>=0,
         "regime_flat_no_context");

   //--- an invalid channel must not force a trade.
   IRRegimeDecision(hf,hs,5,point,tol,0.0,0.0,2010.0,d);
   Check(d.decision==IR_DEC_DATA_NOT_READY,"regime_channel_invalid");
  }

void OnStart(void)
  {
   g_pass=0;
   g_fail=0;
   TestLossStreakGuard();
   TestStepTrailing();
   TestBreakEvenAndMonotonic();
   TestRegimeEntry();
   if(g_fail==0)
      PrintFormat("TEST|RESULT|ALL_PASS|pass=%d fail=0|ir=1",g_pass);
   else
      PrintFormat("TEST|RESULT|FAILURES|pass=%d fail=%d|ir=1",g_pass,g_fail);
  }
//+------------------------------------------------------------------+
