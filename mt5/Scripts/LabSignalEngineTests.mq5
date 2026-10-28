//+------------------------------------------------------------------+
//|                                        LabSignalEngineTests.mq5 |
//|      Deterministic checks for Indicators.mqh / SignalEngine.mqh |
//|                                                                  |
//| Run manually on any chart. This script never trades and never    |
//| reads account data. Results are printed to the Experts journal.  |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Self-checks for the signal engine. No trading."
#property script_show_inputs

#include "../Include/Indicators.mqh"
#include "../Include/SignalEngine.mqh"

int g_pass=0;
int g_fail=0;

void CheckTrue(const string name,const bool condition)
  {
   if(condition)
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

void CheckNear(const string name,const double actual,const double expected,
               const double tolerance=1e-9)
  {
   const bool ok=MathIsValidNumber(actual) && MathAbs(actual-expected)<=tolerance;
   if(!ok)
      PrintFormat("TEST|DETAIL|%s actual=%.12f expected=%.12f",name,actual,expected);
   CheckTrue(name,ok);
  }

void CheckSignal(const string name,const ENUM_LAB_SIGNAL actual,
                 const ENUM_LAB_SIGNAL expected)
  {
   if(actual!=expected)
      PrintFormat("TEST|DETAIL|%s actual=%s expected=%s",
                  name,LabSignalName(actual),LabSignalName(expected));
   CheckTrue(name,actual==expected);
  }

void CheckReason(const string name,const ENUM_LAB_REASON actual,
                 const ENUM_LAB_REASON expected)
  {
   if(actual!=expected)
      PrintFormat("TEST|DETAIL|%s actual=%s expected=%s",
                  name,LabReasonName(actual),LabReasonName(expected));
   CheckTrue(name,actual==expected);
  }

LabSignalConfig MakeConfig(const int fast_period,const int slow_period,
                           const bool allow_long=true,
                           const bool allow_short=true)
  {
   LabSignalConfig config;
   config.fast_period=fast_period;
   config.slow_period=slow_period;
   config.allow_long=allow_long;
   config.allow_short=allow_short;
   return(config);
  }

void TestIndicators()
  {
   double values[5]={1.0,2.0,3.0,4.0,5.0};
   double out[];

   CheckTrue("sma_computes",LabComputeSma(values,5,3,out));
   CheckNear("sma_seed",out[2],2.0);
   CheckNear("sma_mid",out[3],3.0);
   CheckNear("sma_last",out[4],4.0);
   CheckTrue("sma_rejects_short_input",!LabComputeSma(values,2,3,out));
   CheckTrue("sma_rejects_zero_period",!LabComputeSma(values,5,0,out));

   CheckTrue("ema_computes",LabComputeEma(values,5,3,out));
   CheckNear("ema_seed",out[2],2.0);
   CheckNear("ema_mid",out[3],3.0);
   CheckNear("ema_last",out[4],4.0);
   CheckTrue("ema_rejects_short_input",!LabComputeEma(values,2,3,out));

   double with_zero[3]={1.0,0.0,2.0};
   CheckTrue("ema_rejects_non_positive",!LabComputeEma(with_zero,3,2,out));
  }

void TestCrossoverDecisions()
  {
   ENUM_LAB_SIGNAL signal=LAB_SIGNAL_UNKNOWN;
   ENUM_LAB_REASON reason=LAB_REASON_OK;

   LabEvaluateCrossover(1.0,2.0,3.0,2.5,true,true,signal,reason);
   CheckSignal("crossover_buy",signal,LAB_SIGNAL_BUY);
   CheckReason("crossover_buy_reason",reason,LAB_REASON_OK);

   LabEvaluateCrossover(3.0,2.0,1.0,1.5,true,true,signal,reason);
   CheckSignal("crossover_sell",signal,LAB_SIGNAL_SELL);

   LabEvaluateCrossover(3.0,2.0,4.0,2.5,true,true,signal,reason);
   CheckSignal("crossover_hold",signal,LAB_SIGNAL_HOLD);
   CheckReason("crossover_hold_reason",reason,LAB_REASON_NO_CROSS);

   LabEvaluateCrossover(1.0,2.0,3.0,2.5,false,true,signal,reason);
   CheckSignal("crossover_long_disabled",signal,LAB_SIGNAL_HOLD);
   CheckReason("crossover_long_disabled_reason",reason,LAB_REASON_LONG_DISABLED);

   LabEvaluateCrossover(3.0,2.0,1.0,1.5,true,false,signal,reason);
   CheckSignal("crossover_short_disabled",signal,LAB_SIGNAL_HOLD);
   CheckReason("crossover_short_disabled_reason",reason,LAB_REASON_SHORT_DISABLED);

   LabEvaluateCrossover(-1.0,2.0,3.0,2.5,true,true,signal,reason);
   CheckSignal("crossover_invalid_input",signal,LAB_SIGNAL_UNKNOWN);
   CheckReason("crossover_invalid_input_reason",reason,LAB_REASON_INVALID_INPUT);
  }

void TestEmaCrossoverEngine()
  {
   //--- BUY: fast crosses above slow on the last bar of the slow+1 window.
   double buy_prices[4]={1.10,1.09,1.05,1.12};
   LabSignalResult result;
   LabSignalConfig config=MakeConfig(2,3);
   CheckTrue("engine_buy_evaluated",
             LabEvaluateEmaCrossover(buy_prices,4,config,result));
   CheckSignal("engine_buy_signal",result.signal,LAB_SIGNAL_BUY);
   CheckReason("engine_buy_reason",result.reason,LAB_REASON_OK);
   CheckNear("engine_buy_fast_prev",result.fast_prev,1.065);
   CheckNear("engine_buy_slow_prev",result.slow_prev,1.08);
   CheckNear("engine_buy_fast_now",result.fast_now,1.101666666667,1e-9);
   CheckNear("engine_buy_slow_now",result.slow_now,1.10);
   CheckTrue("engine_buy_bars_used",result.bars_used==4);

   //--- SELL: fast crosses below slow on the last bar of the slow+1 window.
   double sell_prices[4]={1.05,1.06,1.12,1.00};
   CheckTrue("engine_sell_evaluated",
             LabEvaluateEmaCrossover(sell_prices,4,config,result));
   CheckSignal("engine_sell_signal",result.signal,LAB_SIGNAL_SELL);
   CheckNear("engine_sell_fast_prev",result.fast_prev,1.098333333333,1e-9);
   CheckNear("engine_sell_slow_prev",result.slow_prev,1.076666666667,1e-9);
   CheckNear("engine_sell_fast_now",result.fast_now,1.032777777778,1e-9);
   CheckNear("engine_sell_slow_now",result.slow_now,1.038333333333,1e-9);

   //--- HOLD: both bars stay below.
   double hold_prices[4]={1.10,1.09,1.08,1.07};
   CheckTrue("engine_hold_evaluated",
             LabEvaluateEmaCrossover(hold_prices,4,config,result));
   CheckSignal("engine_hold_signal",result.signal,LAB_SIGNAL_HOLD);
   CheckReason("engine_hold_reason",result.reason,LAB_REASON_NO_CROSS);

   //--- Determinism: the same input must produce identical output.
   LabSignalResult second;
   LabEvaluateEmaCrossover(buy_prices,4,config,result);
   LabEvaluateEmaCrossover(buy_prices,4,config,second);
   CheckTrue("engine_deterministic_signal",result.signal==second.signal);
   CheckTrue("engine_deterministic_reason",result.reason==second.reason);
   CheckNear("engine_deterministic_fast",result.fast_now,second.fast_now);
   CheckNear("engine_deterministic_slow",result.slow_now,second.slow_now);

   //--- Insufficient history is UNKNOWN, never HOLD.
   double short_prices[3]={1.10,1.09,1.05};
   CheckTrue("engine_insufficient_not_evaluated",
             !LabEvaluateEmaCrossover(short_prices,3,config,result));
   CheckSignal("engine_insufficient_signal",result.signal,LAB_SIGNAL_UNKNOWN);
   CheckReason("engine_insufficient_reason",result.reason,
               LAB_REASON_INSUFFICIENT_HISTORY);

   //--- Invalid config is rejected before any computation.
   LabSignalConfig bad=MakeConfig(3,3);
   CheckTrue("engine_invalid_config_not_evaluated",
             !LabEvaluateEmaCrossover(buy_prices,4,bad,result));
   CheckSignal("engine_invalid_config_signal",result.signal,LAB_SIGNAL_UNKNOWN);
   CheckReason("engine_invalid_config_reason",result.reason,
               LAB_REASON_INVALID_CONFIG);

   //--- A zero close invalidates the series instead of producing a signal.
   double zero_prices[4]={1.10,1.09,1.05,0.0};
   CheckTrue("engine_invalid_price_not_evaluated",
             !LabEvaluateEmaCrossover(zero_prices,4,config,result));
   CheckSignal("engine_invalid_price_signal",result.signal,LAB_SIGNAL_UNKNOWN);
   CheckReason("engine_invalid_price_reason",result.reason,
               LAB_REASON_INDICATOR_FAILED);
  }

void OnStart()
  {
   PrintFormat("TEST|START|suite=signal_engine build=%d",
               (int)TerminalInfoInteger(TERMINAL_BUILD));

   TestIndicators();
   TestCrossoverDecisions();
   TestEmaCrossoverEngine();

   PrintFormat("TEST|SUMMARY|pass=%d fail=%d",g_pass,g_fail);
   if(g_fail==0)
      Print("TEST|RESULT|ALL_PASS");
   else
      Print("TEST|RESULT|FAILURES");
  }
//+------------------------------------------------------------------+
