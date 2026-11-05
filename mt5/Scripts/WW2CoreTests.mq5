//+------------------------------------------------------------------+
//|                                                 WW2CoreTests.mq5  |
//|   Contract tests for the pure Wonderwhales XAU 2-mode modules.     |
//|                                                                    |
//| Run on a demo chart: Scripts > WW2CoreTests. Expect a line         |
//|   TEST|RESULT|ALL_PASS|pass=N fail=0|ww2=1                         |
//| No trading, no account access, no file I/O.                        |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Pure-logic contract tests for the Wonderwhales XAU 2-mode modules."

#include "../Include/Wonderwhales/WW2Types.mqh"
#include "../Include/Wonderwhales/WW2RiskSizer.mqh"
#include "../Include/Wonderwhales/WW2Swing.mqh"
#include "../Include/Wonderwhales/WW2InitialStop.mqh"
#include "../Include/Wonderwhales/WW2RiskGuard.mqh"
#include "../Include/Wonderwhales/WW2TrailingCoordinator.mqh"
#include "../Include/Wonderwhales/WW2ScalpStrategy.mqh"
#include "../Include/Wonderwhales/WW2SwingStrategy.mqh"

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

void TestSizer(void)
  {
   double volume=0.0;
   string reason="";

   //--- A budget that cannot afford the minimum lot must be skipped
   //--- (loss_per_lot 200 -> min lot 0.01 would risk 2.0 > budget 1.0).
   const bool skip=Ww2SizeVolume(1.0,200.0,0.01,100.0,0.01,10.0,volume,reason);
   Check(!skip && volume==0.0,"sizer_min_lot_over_budget_skipped");

   //--- Risk 100 with a 10-per-lot loss and 0.01 step -> 10.0 lots, capped at 5.
   volume=0.0;
   const bool capped=Ww2SizeVolume(100.0,10.0,0.01,100.0,0.01,5.0,volume,reason);
   Check(capped && Near(volume,5.0,1e-9),"sizer_exposure_cap_applied");

   //--- Floor to the step, never round up.
   volume=0.0;
   const bool floored=Ww2SizeVolume(1.0,3.0,0.01,100.0,0.01,5.0,volume,reason);
   Check(floored && Near(volume,0.33,1e-9),"sizer_floors_to_step");
  }

void TestRiskGuard(void)
  {
   CWw2RiskGuard guard;
   string error="";
   Check(guard.Init(1.0,2.0,50.0,2,20,error),"guard_init");

   const datetime day1=StringToTime("2026.03.02 12:00");
   const datetime day2=StringToTime("2026.03.03 12:00");
   const datetime week2=StringToTime("2026.03.10 12:00");

   string reason="";
   const bool h0=guard.Refresh(1000.0,day1,reason);
   Check(!h0,"guard_no_halt_at_start");

   //--- Daily loss 1.5% breaches the 1.0% cap.
   const bool h1=guard.Refresh(985.0,day1,reason);
   string halt_reason="";
   Check(h1 && guard.Halted(halt_reason) &&
         StringFind(halt_reason,"daily_loss_limit_reached")==0,
         "guard_daily_loss_halts");

   //--- A new server day clears the daily lock.
   guard.Refresh(985.0,day2,reason);
   Check(!guard.Halted(halt_reason),"guard_daily_lock_clears_next_day");

   //--- Weekly: fresh guard, a 3% week breaches the 2% cap and clears next week.
   CWw2RiskGuard weekly;
   weekly.Init(0.0,2.0,100.0,0,0,error);
   weekly.Refresh(1000.0,day2,reason);
   weekly.Refresh(970.0,day2,reason);
   Check(weekly.Halted(halt_reason) &&
         StringFind(halt_reason,"weekly_loss_limit_reached")==0,
         "guard_weekly_loss_halts");
   weekly.Refresh(970.0,week2,reason);
   Check(!weekly.Halted(halt_reason),"guard_weekly_lock_clears_next_week");
  }

void TestTrailing(void)
  {
   Ww2StopInput in;
   in.allow_arm=true;
   in.is_buy=true;
   in.entry=2000.0;
   in.initial_sl=1990.0;
   in.current_sl=1995.0;
   in.bid=2020.0;
   in.ask=2020.2;
   in.point=0.01;
   in.min_step_points=50.0;
   in.be_trigger_r=1.0;
   in.be_buffer_points=0.0;
   in.trail_trigger_r=1.3;
   in.have_structure=true;
   in.structure_sl=1998.0;
   in.enable_psar=false;
   in.psar=0.0;
   in.enable_atr=false;
   in.atr_distance=0.0;
   in.enable_step=false;
   in.step_points=0.0;

   string reason="";
   const double best=Ww2BestStop(in,reason);
   Check(Near(best,2000.0,1e-9) && best<in.bid && best>in.current_sl,
         "trail_picks_best_and_tightens");

   //--- The only candidate is below the current stop: nothing must change.
   Ww2StopInput loosen=in;
   loosen.be_trigger_r=5.0;          // BE not armed at r=2.0
   loosen.trail_trigger_r=1.3;
   loosen.structure_sl=1992.0;       // worse than the 1995 stop
   const double none=Ww2BestStop(loosen,reason);
   Check(none==0.0,"trail_never_loosens");

   //--- A management bar that did not close in the position's direction must
   //--- arm nothing, even above the trigger.
   Ww2StopInput no_arm=in;
   no_arm.allow_arm=false;
   Check(Ww2BestStop(no_arm,reason)==0.0,"trail_requires_closed_bar_agreement");

   //--- R always from the initial SL, even after the stop moved.
   Ww2Position pos;
   Ww2ResetPosition(pos);
   pos.entry=2000.0;
   pos.initial_sl=1990.0;
   pos.is_buy=true;
   const double r=Ww2CurrentR(pos,true,2020.0,2020.2);
   Check(Near(r,2.0,1e-9),"r_measured_from_initial_sl");

   //--- The live stop trailing up to break-even must not move R: R is anchored
   //--- to initial_sl, never to current_sl.
   pos.current_sl=2000.0;
   const double r2=Ww2CurrentR(pos,true,2020.0,2020.2);
   Check(Near(r2,2.0,1e-9),"r_ignores_trailed_stop");
  }

void TestSwing(void)
  {
   double low[];
   ArrayResize(low,7);
   low[0]=10.0;
   low[1]=9.0;
   low[2]=8.0;
   low[3]=5.0;
   low[4]=8.0;
   low[5]=9.0;
   low[6]=10.0;
   ArraySetAsSeries(low,true);
   int shift=-1;
   double price=0.0;
   const bool found=Ww2FindSwingLow(low,1,100,2,shift,price);
   Check(found && shift==3 && Near(price,5.0,1e-9),"swing_finds_confirmed_low");

   //--- Stop distance: swing + buffer with an ATR fallback.
   const double dist=Ww2ScalpStopDistance(true,2000.0,1.0,1990.0,true,0.2,1.2);
   Check(Near(dist,10.0+0.2*(2000.0*0.01),1e-9),"stop_swing_plus_atr_buffer");
   const double fallback=Ww2ScalpStopDistance(true,2000.0,1.0,0.0,false,0.2,1.2);
   Check(Near(fallback,1.2*(2000.0*0.01),1e-9),"stop_atr_fallback");
  }

void TestStrategies(void)
  {
   Ww2Signal m15,m5,m1;
   m15.valid=true;
   m15.fast_ema=2010.0;
   m15.slow_ema=2000.0;
   m15.ema200=1990.0;
   m15.close=2015.0;
   m5.valid=true;
   m5.buy=true;
   m5.fast_ema=2005.0;
   m5.slow_ema=2000.0;
   m1.valid=true;
   m1.buy=false;

   bool is_buy=false;
   Check(!Ww2ScalpEntry(m15,m5,m1,is_buy),"scalp_blocks_without_trigger");
   m1.buy=true;
   Check(Ww2ScalpEntry(m15,m5,m1,is_buy) && is_buy,"scalp_enters_with_bias_and_trigger");

   Ww2Signal w1,d1,h1;
   w1.valid=true;
   w1.fast_ema=2010.0;
   w1.slow_ema=2000.0;
   w1.close=2005.0;
   d1.valid=true;
   d1.fast_ema=2005.0;
   d1.slow_ema=2000.0;
   h1.valid=true;
   h1.buy=true;
   bool swing_buy=false;
   Check(Ww2SwingEntry(w1,d1,h1,swing_buy) && swing_buy,"swing_enters_with_aligned_bias");
   d1.fast_ema=1999.0;
   d1.slow_ema=2000.0;
   Check(!Ww2SwingEntry(w1,d1,h1,swing_buy),"swing_blocks_on_conflict");

   //--- Census gate reasons: every stage of the AND chain must be visible on
   //--- its own, otherwise the diagnostic CSV cannot answer "why no trade".
   Ww2ScalpGates sg;
   m1.buy=false;
   Check(!Ww2ScalpEvaluate(m15,m5,m1,sg) && sg.reason=="no_m1_confirm",
         "scalp_census_no_m1_confirm");
   m1.buy=true;
   Check(Ww2ScalpEvaluate(m15,m5,m1,sg) && sg.reason=="signal" && sg.is_buy,
         "scalp_census_signal");

   Ww2Signal flat=m15;
   flat.fast_ema=1999.0;
   flat.slow_ema=2000.0;
   flat.close=1995.0;
   Check(!Ww2ScalpEvaluate(flat,m5,m1,sg) && sg.reason=="no_m15_bias",
         "scalp_census_no_bias");

   Ww2Signal no_flip=m5;
   no_flip.buy=false;
   Check(!Ww2ScalpEvaluate(m15,no_flip,m1,sg) && sg.reason=="no_m5_flip",
         "scalp_census_no_setup");

   Ww2Signal no_align=m5;
   no_align.fast_ema=1999.0;
   no_align.slow_ema=2000.0;
   Check(!Ww2ScalpEvaluate(m15,no_align,m1,sg) && sg.reason=="no_m5_flip",
         "scalp_census_no_setup_align");

   Ww2Signal bad_trigger=m1;
   bad_trigger.valid=false;
   Check(!Ww2ScalpEvaluate(m15,m5,bad_trigger,sg) && sg.reason=="trigger_invalid",
         "scalp_census_trigger_invalid");

   Ww2Signal bad_bias=m15;
   bad_bias.valid=false;
   Check(!Ww2ScalpEvaluate(bad_bias,m5,m1,sg) && sg.reason=="bias_invalid",
         "scalp_census_bias_invalid");

   Ww2SwingGates wg;
   d1.fast_ema=2005.0;
   d1.slow_ema=2000.0;
   h1.buy=false;
   h1.sell=false;
   Check(!Ww2SwingEvaluate(w1,d1,h1,wg) && wg.reason=="no_h1_trigger",
         "swing_census_no_trigger");
   h1.buy=true;
   Check(Ww2SwingEvaluate(w1,d1,h1,wg) && wg.reason=="signal" && wg.is_buy,
         "swing_census_signal");
   d1.fast_ema=1999.0;
   Check(!Ww2SwingEvaluate(w1,d1,h1,wg) && wg.reason=="no_d1_align",
         "swing_census_no_d1_align");
   Ww2Signal flat_w1=w1;
   flat_w1.fast_ema=1999.0;
   flat_w1.slow_ema=2000.0;
   flat_w1.close=2005.0;
   Check(!Ww2SwingEvaluate(flat_w1,d1,h1,wg) && wg.reason=="no_w1_bias",
         "swing_census_no_bias");
  }

void OnStart(void)
  {
   g_pass=0;
   g_fail=0;
   TestSizer();
   TestRiskGuard();
   TestTrailing();
   TestSwing();
   TestStrategies();
   if(g_fail==0)
      PrintFormat("TEST|RESULT|ALL_PASS|pass=%d fail=0|ww2=1",g_pass);
   else
      PrintFormat("TEST|RESULT|FAILURES|pass=%d fail=%d|ww2=1",g_pass,g_fail);
  }
//+------------------------------------------------------------------+
