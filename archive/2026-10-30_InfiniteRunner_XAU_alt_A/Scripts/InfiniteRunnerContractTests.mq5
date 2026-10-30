//+------------------------------------------------------------------+
//|                                 InfiniteRunnerContractTests.mq5  |
//|      Synthetic checks for InfiniteRunner v2 engines.              |
//|      No market, account, file or order APIs.                      |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property script_show_inputs

#include "../Include/InfiniteRunner/IRTypes.mqh"
#include "../Include/InfiniteRunner/IRMarket.mqh"
#include "../Include/InfiniteRunner/IRDirection.mqh"
#include "../Include/InfiniteRunner/IRRisk.mqh"
#include "../Include/InfiniteRunner/IRTrailing.mqh"

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

bool Near(const double a,const double b,const double tolerance=1e-9)
  {
   return(MathAbs(a-b)<=tolerance);
  }

IREmaSnap Snap(const double fast,const double slow,const double fast_prev,
               const double slow_prev,const double close_now,
               const double close_prev,const double fast_slope,
               const double slow_slope)
  {
   IREmaSnap s;
   s.ready=true;
   s.fast=fast;
   s.slow=slow;
   s.fast_prev=fast_prev;
   s.slow_prev=slow_prev;
   s.close=close_now;
   s.close_prev=close_prev;
   s.fast_slope=fast_slope;
   s.slow_slope=slow_slope;
   return(s);
  }

void RunDirection(void)
  {
   IREmaSnap empty;
   empty.ready=false;
   IREmaSnap bull=Snap(2000,1990,1998,1989,2001,1995,1.0,0.2);
   IREmaSnap bear=Snap(1990,2000,1992,2001,1988,1996,-1.0,-0.2);
   IREmaSnap buy_reclaim=Snap(2000,1990,2000,1990,2002,1998,0.4,0.1);
   IREmaSnap sell_reclaim=Snap(1990,2000,1990,2000,1987,1992,-0.4,-0.1);
   IREmaSnap no_reclaim=Snap(2000,1990,2000,1990,2002,2005,0.4,0.1);

   IRDirectionResult r=IREvaluateDirection(IR_DIR_EMA_MTF,bull,bull,buy_reclaim,
                                           bull,0.0,0.5,1.0);
   Record("D1",r.decision==IR_BUY_ALLOWED && r.reason=="ema_mtf_buy",
          "aligned buy got "+r.reason);

   r=IREvaluateDirection(IR_DIR_EMA_MTF,bear,bear,sell_reclaim,bear,0.0,0.5,1.0);
   Record("D2",r.decision==IR_SELL_ALLOWED && r.reason=="ema_mtf_sell",
          "aligned sell got "+r.reason);

   r=IREvaluateDirection(IR_DIR_EMA_MTF,bull,bear,buy_reclaim,bull,0.0,0.5,1.0);
   Record("D3",r.decision==IR_NO_TRADE && r.reason=="h1_m15_conflict",
          "conflict got "+r.reason);

   r=IREvaluateDirection(IR_DIR_EMA_MTF,empty,bull,buy_reclaim,bull,0.0,0.5,1.0);
   Record("D4",r.decision==IR_DATA_NOT_READY,IRDecisionName(r.decision));

   r=IREvaluateDirection(IR_DIR_EMA_MTF,bull,bull,no_reclaim,bull,0.0,0.5,1.0);
   Record("D5",r.decision==IR_NO_TRADE && r.reason=="m5_buy_trigger_missing",
          r.reason);

   r=IREvaluateDirection(IR_DIR_PA_MTF,bull,bull,buy_reclaim,bull,0.0,0.5,1.0);
   Record("D6",r.decision==IR_NO_TRADE && r.reason=="pa_mode_not_implemented",
          r.reason);

   r=IREvaluateDirection(IR_DIR_LEGACY_EMA,empty,empty,empty,bull,0.0,0.5,1.0);
   Record("D7",r.decision==IR_BUY_ALLOWED && r.reason=="legacy_closed_ema",
          r.reason);

   Record("D8",IRBuyReclaim(buy_reclaim,1.0) && !IRBuyReclaim(no_reclaim,1.0),
          "reclaim helper");
   Record("D9",!IREmaSnapValid(empty),"empty snap not valid");
  }

void RunRisk(void)
  {
   IRSymbolSpec spec;
   spec.point=0.001;
   spec.tick_size=0.001;
   spec.tick_value=0.1;
   spec.volume_min=0.01;
   spec.volume_max=5.0;
   spec.volume_step=0.01;
   spec.stops_level_points=0.0;
   spec.freeze_level_points=0.0;

   IRLotDecision lot=IRCalcLot(IR_LOT_RISK_PERCENT,10000.0,0.25,0.01,1.0,
                               250.0,spec);
   Record("R1",lot.ok && Near(lot.volume,0.10,1e-8),
          StringFormat("vol=%.4f reason=%s",lot.volume,lot.reason));

   lot=IRCalcLot(IR_LOT_RISK_PERCENT,10000.0,0.01,0.01,1.0,250.0,spec);
   Record("R2",!lot.ok && lot.reason=="min_volume_exceeds_risk",lot.reason);

   lot=IRCalcLot(IR_LOT_FIXED,10000.0,0.25,0.03,1.0,100.0,spec);
   Record("R3",lot.ok && Near(lot.volume,0.03,1e-8),
          StringFormat("fixed=%.4f",lot.volume));

   Record("R4",IRDailyLossLocked(9900.0,10000.0,1.0) &&
          !IRDailyLossLocked(9901.0,10000.0,1.0),"daily lock");
   Record("R5",IRDrawdownLocked(9200.0,10000.0,8.0) &&
          !IRDrawdownLocked(9210.0,10000.0,8.0),"dd lock");
   Record("R6",IRCooldownActive(1000,700,5) &&
          !IRCooldownActive(1000,700,4),"cooldown 5min");
   Record("R7",IRSpreadBlocked(700,600,0.7,4.0,0.25),"spread points");
   Record("R8",IRVolatilityBlocked(5.0,1.0,2.5) &&
          !IRVolatilityBlocked(2.0,1.0,2.5),"atr regime");

   string reason="";
   Record("R9",IRStopDistanceOk(2000.0,1990.0,5.0,0.5,4.0,0.001,0.0,reason),
          reason);
   Record("R10",!IRStopDistanceOk(2000.0,1999.8,5.0,0.5,4.0,0.001,0.0,reason) &&
          reason=="stop_too_tight",reason);
  }

void RunTrailing(void)
  {
   IRTrailInput in;
   in.side=SIM_SIDE_BUY;
   in.mode=IR_TRAIL_FIXED_DISTANCE;
   in.entry=2000.0;
   in.sl=1990.0;
   in.price=2010.0;
   in.initial_risk=10.0;
   in.atr=2.0;
   in.structure_level=2004.0;
   in.min_stop=0.5;
   in.tick_size=0.001;
   in.trail_step=0.5;
   in.trail_distance=5.0;
   in.trail_start_r=1.5;
   in.break_even_r=1.0;
   in.break_even_buffer=0.0;
   in.trail_atr_mult=1.2;

   IRTrailDecision out=IRTrailingEvaluate(in);
   Record("T1",out.update && out.new_sl>in.sl && out.reason=="TRAIL_FIXED",
          out.reason+StringFormat(" sl=%.4f",out.new_sl));

   in.price=2005.0;
   out=IRTrailingEvaluate(in);
   Record("T2",out.update && Near(out.new_sl,2000.0,1e-9) &&
          out.reason=="BREAK_EVEN",out.reason);

   in.price=1995.0;
   out=IRTrailingEvaluate(in);
   Record("T3",!out.update && out.reason=="HOLD_NO_PROFIT",out.reason);

   in.price=2010.0;
   in.sl=0.0;
   out=IRTrailingEvaluate(in);
   Record("T4",!out.update && out.reason=="SL_MISSING",out.reason);

   in.sl=2006.0;
   in.price=2010.0;
   in.mode=IR_TRAIL_FIXED_DISTANCE;
   out=IRTrailingEvaluate(in);
   Record("T5",!out.update || out.new_sl>=in.sl,"buy never lowers sl");

   in.side=SIM_SIDE_SELL;
   in.entry=2000.0;
   in.sl=2010.0;
   in.price=1990.0;
   in.initial_risk=10.0;
   in.mode=IR_TRAIL_FIXED_DISTANCE;
   out=IRTrailingEvaluate(in);
   Record("T6",out.update && out.new_sl<in.sl,"sell trail lowers sl");

   Record("T7",IRSlImproves(true,2001.0,2000.0,0.5) &&
          !IRSlImproves(true,2000.2,2000.0,0.5),"buy step");
   Record("T8",IRSlImproves(false,1999.0,2000.0,0.5) &&
          !IRSlImproves(false,1999.8,2000.0,0.5),"sell step");
  }

void RunMarket(void)
  {
   double low[]={10,9,8,9,10,11};
   double high[]={12,13,14,13,12,11};
   Record("M1",IRSwingLow(low,2,2,2) && IRLastConfirmedSwingLow(low,2,2)==8.0,
          "swing low");
   Record("M2",IRSwingHigh(high,2,2,2) && IRLastConfirmedSwingHigh(high,2,2)==14.0,
          "swing high");
   Record("M3",IRSessionOpen(D'2026.01.01 10:00:00',true,7,21) &&
          !IRSessionOpen(D'2026.01.01 03:00:00',true,7,21),"session");
   Record("M4",IRSignalId("XAUUSDm",1000,SIM_SIDE_BUY)=="XAUUSDm|1000|BUY",
          "signal id");
  }

void OnStart(void)
  {
   RunDirection();
   RunRisk();
   RunTrailing();
   RunMarket();
   PrintFormat("TEST|RESULT|%s|pass=%d|fail=%d",
               (g_fail==0 ? "ALL_PASS" : "FAIL"),g_pass,g_fail);
  }
