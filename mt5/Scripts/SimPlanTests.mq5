//+------------------------------------------------------------------+
//|                                                  SimPlanTests.mq5 |
//|      MT5 EA Lab - synthetic checks for SimPlan plan rules         |
//|                                                                  |
//| Runs once. No market data, no file I/O, no account access and no  |
//| trading functions. Vectors: docs/reference/simulation.md.         |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Synthetic tests for SimPlan validation, side resolution and targets."
#property script_show_inputs

#include "../Include/Sim/SimPlan.mqh"

int g_pass=0;
int g_fail=0;

void Record(const string id,const bool ok,const string detail)
  {
   if(ok)
     {
      g_pass++;
      PrintFormat("TEST|%s|PASS",id);
      return;
     }
   g_fail++;
   PrintFormat("TEST|%s|FAIL|%s",id,detail);
  }

SimPlan MakePlan(const ENUM_SIM_SIDE side,const double entry,const double sl,
                 const double tp1,const double tp2=0.0,const double tp3=0.0)
  {
   SimPlan plan;
   plan.signal=true;
   plan.valid=true;
   plan.side=side;
   plan.entry=entry;
   plan.sl=sl;
   plan.tp1=tp1;
   plan.tp2=tp2;
   plan.tp3=tp3;
   return(plan);
  }

void RunResolve(void)
  {
   string reason="";
   Record("R1",SimPlanResolveSide(true,false,1,reason)==SIM_SIDE_BUY && reason=="",
          "long/dir1 reason="+reason);
   Record("R2",SimPlanResolveSide(false,true,-1,reason)==SIM_SIDE_SELL && reason=="",
          "short/dir-1 reason="+reason);
   Record("R3",SimPlanResolveSide(true,false,-1,reason)==SIM_SIDE_NONE &&
          reason=="direction_conflict","conflict reason="+reason);
   Record("R4",SimPlanResolveSide(false,true,1,reason)==SIM_SIDE_NONE &&
          reason=="direction_conflict","conflict reason="+reason);
   Record("R5",SimPlanResolveSide(true,false,0,reason)==SIM_SIDE_NONE &&
          reason=="direction_missing","missing reason="+reason);
   Record("R6",SimPlanResolveSide(true,true,1,reason)==SIM_SIDE_NONE &&
          reason=="ambiguous_signal","ambiguous reason="+reason);
   Record("R7",SimPlanResolveSide(false,false,0,reason)==SIM_SIDE_NONE &&
          reason=="no_signal","no_signal reason="+reason);
  }

void RunValidate(void)
  {
   const double point=0.001;
   SimPlan long_ok=MakePlan(SIM_SIDE_BUY,1.1000,1.0900,1.1200);
   SimPlan short_ok=MakePlan(SIM_SIDE_SELL,1.1000,1.1100,1.0800);

   Record("V1",SimPlanValidate(long_ok,0,point,5.0,5.0).accepted,"valid long");
   Record("V2",SimPlanValidate(short_ok,0,point,5.0,5.0).accepted,"valid short");

   SimPlan no_signal=long_ok;
   no_signal.signal=false;
   Record("V3",SimPlanValidate(no_signal,0,point,5.0,5.0).reason=="no_signal",
          "signal off");

   SimPlan invalid=long_ok;
   invalid.valid=false;
   Record("V4",SimPlanValidate(invalid,0,point,5.0,5.0).reason=="plan_invalid",
          "valid off");

   SimPlan no_side=long_ok;
   no_side.side=SIM_SIDE_NONE;
   Record("V5",SimPlanValidate(no_side,0,point,5.0,5.0).reason=="side_missing",
          "side none");

   Record("V6",SimPlanValidate(short_ok,1,point,5.0,5.0).reason=="side_filtered",
          "long-only filter");
   Record("V7",SimPlanValidate(long_ok,-1,point,5.0,5.0).reason=="side_filtered",
          "short-only filter");
   Record("V8",SimPlanValidate(long_ok,0,point,5.0,5.0).accepted,"filter both");

   SimPlan bad_entry=long_ok;
   bad_entry.entry=0.0;
   Record("V9",SimPlanValidate(bad_entry,0,point,5.0,5.0).reason=="entry_invalid",
          "entry zero");

   SimPlan bad_sl=long_ok;
   bad_sl.sl=0.0;
   Record("V10",SimPlanValidate(bad_sl,0,point,5.0,5.0).reason=="sl_missing",
          "sl zero");

   SimPlan sl_inside_long=MakePlan(SIM_SIDE_BUY,1.1000,1.1050,1.1200);
   Record("V11",SimPlanValidate(sl_inside_long,0,point,5.0,5.0).reason=="sl_not_below_entry",
          "long sl above entry");

   SimPlan sl_inside_short=MakePlan(SIM_SIDE_SELL,1.1000,1.0950,1.0800);
   Record("V12",SimPlanValidate(sl_inside_short,0,point,5.0,5.0).reason=="sl_not_above_entry",
          "short sl below entry");

   SimPlan tight_stop=MakePlan(SIM_SIDE_BUY,1.1000,1.0995,1.1200);
   Record("V13",SimPlanValidate(tight_stop,0,point,5.0,5.0).reason=="stop_too_close",
          "stop 0.5 point");

   SimPlan tp_inside_long=MakePlan(SIM_SIDE_BUY,1.1000,1.0900,1.0990);
   Record("V14",SimPlanValidate(tp_inside_long,0,point,5.0,5.0).reason=="tp_not_above_entry",
          "long tp below entry");

   SimPlan tp_inside_short=MakePlan(SIM_SIDE_SELL,1.1000,1.1100,1.1010);
   Record("V15",SimPlanValidate(tp_inside_short,0,point,5.0,5.0).reason=="tp_not_below_entry",
          "short tp above entry");

   SimPlan close_target=MakePlan(SIM_SIDE_BUY,1.1000,1.0900,1.1010);
   Record("V16",SimPlanValidate(close_target,0,point,5.0,20.0).reason=="target_too_close",
          "target 10 points < 20");

   SimPlan one_point_stop=MakePlan(SIM_SIDE_BUY,1.1000,1.0999,1.1200);
   Record("V17",SimPlanValidate(one_point_stop,0,point,0.0,5.0).accepted,
          "min stop 0 disables stop check");

   SimPlan far_second=MakePlan(SIM_SIDE_BUY,1.1000,1.0900,0.0,1.1300,1.1500);
   Record("V18",SimPlanValidate(far_second,0,point,5.0,30.0).accepted,
          "nearest valid target used");

   Record("V19",SimPlanValidate(long_ok,0,0.0,5.0,5.0).reason=="point_invalid",
          "point zero");
  }

void RunTargets(void)
  {
   SimPlan plan=MakePlan(SIM_SIDE_BUY,1.1000,1.0900,1.1200,1.1400,1.1600);
   Record("T1",SimPlanTargetPrice(plan,SIM_PLAN_TARGET_TP1)==1.1200,"tp1 mode");
   Record("T2",SimPlanTargetPrice(plan,SIM_PLAN_TARGET_TP3)==1.1600,"tp3 mode");
   Record("T3",SimPlanTargetPrice(plan,SIM_PLAN_TARGET_NONE)==0.0,"none mode");

   SimPlan no_tp3=MakePlan(SIM_SIDE_BUY,1.1000,1.0900,1.1200,1.1400);
   Record("T4",SimPlanTargetPrice(no_tp3,SIM_PLAN_TARGET_TP3)==1.1400,
          "tp3 mode falls back to tp2");

   SimPlan only_tp1=MakePlan(SIM_SIDE_BUY,1.1000,1.0900,1.1200);
   Record("T5",SimPlanTargetPrice(only_tp1,SIM_PLAN_TARGET_TP3)==1.1200,
          "tp3 mode falls back to tp1");

   SimPlan no_side=MakePlan(SIM_SIDE_NONE,1.1000,1.0900,1.1200);
   Record("T6",SimPlanTargetPrice(no_side,SIM_PLAN_TARGET_TP1)==0.0,"side none");

   Record("T7",SimPlanTargetHit(SIM_SIDE_BUY,1.1200,1.1210,1.1215),"buy target hit");
   Record("T8",!SimPlanTargetHit(SIM_SIDE_BUY,1.1200,1.1190,1.1195),"buy target not hit");
   Record("T9",SimPlanTargetHit(SIM_SIDE_SELL,1.0800,1.0795,1.0800),"sell target hit");
   Record("T10",!SimPlanTargetHit(SIM_SIDE_SELL,1.0800,1.0810,1.0815),"sell target not hit");
   Record("T11",!SimPlanTargetHit(SIM_SIDE_BUY,0.0,1.2000,1.2005),"target zero");
   Record("T12",SimPlanTargetFill(1.1200)==1.1200,"fill equals target");
   Record("T13",SimPlanTargetFill(0.0)==0.0,"fill zero target");
  }

void OnStart(void)
  {
   PrintFormat("TEST|BEGIN|suite=sim_plan|version=1.00");
   RunResolve();
   RunValidate();
   RunTargets();
   if(g_fail==0)
      PrintFormat("TEST|RESULT|ALL_PASS|pass=%d fail=%d|suite=sim_plan",g_pass,g_fail);
   else
      PrintFormat("TEST|RESULT|FAIL|pass=%d fail=%d|suite=sim_plan",g_pass,g_fail);
  }
