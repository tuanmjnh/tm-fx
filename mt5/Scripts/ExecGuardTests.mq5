//+------------------------------------------------------------------+
//|                                          ExecGuardTests.mq5      |
//|      Contract tests for the demo-only execution guards            |
//|                                                                  |
//| Pure arithmetic: no market data, no file I/O, no account access   |
//| and no trading functions. Run from MetaEditor's script editor or  |
//| compile with scripts/build-mql5.ps1; the output is authoritative. |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Synthetic tests for ExecGuard. No trading, no account access."
#property script_show_inputs

#include "../Include/Exec/ExecGuard.mqh"

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

ExecAccountState DemoAccount(void)
  {
   ExecAccountState state;
   state.trade_mode=ACCOUNT_TRADE_MODE_DEMO;
   state.account_trade_allowed=true;
   state.terminal_trade_allowed=true;
   state.tester=false;
   return(state);
  }

void RunContext(void)
  {
   ENUM_EXEC_BLOCK block=EXEC_OK;

   ExecAccountState demo=DemoAccount();
   Record("G1",ExecContextAllowed(demo,block) && block==EXEC_OK,
          "demo account rejected");

   ExecAccountState real=DemoAccount();
   real.trade_mode=ACCOUNT_TRADE_MODE_REAL;
   Record("G2",!ExecContextAllowed(real,block) &&
          block==EXEC_BLOCK_NOT_DEMO,"real account accepted");

   ExecAccountState contest=DemoAccount();
   contest.trade_mode=ACCOUNT_TRADE_MODE_CONTEST;
   Record("G3",!ExecContextAllowed(contest,block) &&
          block==EXEC_BLOCK_NOT_DEMO,"contest account accepted");

   ExecAccountState disabled_account=DemoAccount();
   disabled_account.account_trade_allowed=false;
   Record("G4",!ExecContextAllowed(disabled_account,block) &&
          block==EXEC_BLOCK_ACCOUNT_TRADE_DISABLED,"disabled account accepted");

   ExecAccountState disabled_terminal=DemoAccount();
   disabled_terminal.terminal_trade_allowed=false;
   Record("G5",!ExecContextAllowed(disabled_terminal,block) &&
          block==EXEC_BLOCK_TERMINAL_TRADE_DISABLED,
          "disabled terminal accepted");

   ExecAccountState tester=real;
   tester.tester=true;
   Record("G6",ExecContextAllowed(tester,block) && block==EXEC_OK,
          "tester account rejected");
  }

void RunSymbols(void)
  {
   Record("G7",ExecSymbolAllowed("XAUUSDm","XAUUSD"),"prefix match failed");
   Record("G8",ExecSymbolAllowed("XAUUSD","XAUUSD"),"exact match failed");
   Record("G9",ExecSymbolAllowed("XAUUSDm","EURUSD, XAUUSD"),"list match failed");
   Record("G10",!ExecSymbolAllowed("EURUSDm","XAUUSD"),"wrong symbol accepted");
   Record("G11",!ExecSymbolAllowed("XAUUSD.pro","XAUUSD"),
          "non-alnum suffix accepted");
   Record("G12",!ExecSymbolAllowed("XAUUSDm",""),"empty allow-list accepted");
   Record("G13",!ExecSymbolAllowed("","XAUUSD"),"empty symbol accepted");
   Record("G14",!ExecSymbolAllowed("XAUUSDm","XAUUSDm2"),
          "allow-list longer than symbol accepted");

   ENUM_EXEC_BLOCK block=EXEC_OK;
   Record("G15",!ExecSymbolTradable(SYMBOL_TRADE_MODE_DISABLED,block) &&
          block==EXEC_BLOCK_SYMBOL_TRADE_DISABLED,"disabled symbol accepted");
   Record("G16",!ExecSymbolTradable(SYMBOL_TRADE_MODE_CLOSEONLY,block) &&
          block==EXEC_BLOCK_SYMBOL_CLOSE_ONLY,"close-only symbol accepted");
   Record("G17",ExecSymbolTradable(SYMBOL_TRADE_MODE_FULL,block) &&
          block==EXEC_OK,"full symbol rejected");
  }

void RunTargets(void)
  {
   const double buy_tp=ExecTakeProfitPrice(true,2000.0,1990.0,3.0);
   Record("G18",Near(buy_tp,2030.0),"buy TP");
   const double sell_tp=ExecTakeProfitPrice(false,2000.0,2010.0,3.0);
   Record("G19",Near(sell_tp,1970.0),"sell TP");
   Record("G20",Near(ExecTakeProfitPrice(true,2000.0,1990.0,0.0),0.0),
          "zero R accepted");
   Record("G21",Below(ExecTakeProfitPrice(true,2000.0,2000.0,3.0),0.01),
          "zero risk produced a target");

   Record("G22",ExecTakeProfitValid(true,2000.0,1990.0,2030.0),"buy TP invalid");
   Record("G23",ExecTakeProfitValid(false,2000.0,2010.0,1970.0),
          "sell TP invalid");
   Record("G24",!ExecTakeProfitValid(true,2000.0,2010.0,2030.0),
          "buy TP accepted with SL above entry");
   Record("G25",!ExecTakeProfitValid(false,2000.0,1990.0,1970.0),
          "sell TP accepted with SL below entry");
   Record("G26",!ExecTakeProfitValid(true,2000.0,1990.0,1995.0),
          "TP inside entry accepted");
  }

bool Below(const double value,const double limit)
  {
   return(value<limit);
  }

void RunStops(void)
  {
   const double point=0.001;
   Record("G27",ExecStopsRespectBroker(2000.0,1990.0,2030.0,point,0.0),
          "no broker level rejected");
   Record("G28",!ExecStopsRespectBroker(2000.0,1999.9,2030.0,point,200.0),
          "stop inside broker level accepted");
   Record("G29",!ExecStopsRespectBroker(2000.0,1990.0,2000.1,point,200.0),
          "target inside broker level accepted");
   Record("G30",ExecStopsRespectBroker(2000.0,1990.0,2030.0,point,200.0),
          "valid stops rejected");
  }

void RunVolumes(void)
  {
   Record("G31",Near(ExecNormalizeVolume(0.0375,0.01,10.0,0.01),0.03),
          "floor to step");
   Record("G32",Near(ExecNormalizeVolume(0.005,0.01,10.0,0.01),0.0),
          "below minimum accepted");
   Record("G33",Near(ExecNormalizeVolume(50.0,0.01,5.0,0.01),5.0),
          "max volume not capped");
   Record("G34",Near(ExecNormalizeVolume(0.01,0.01,10.0,0.01),0.01),
          "minimum volume rejected");
  }

void RunBudget(void)
  {
   Record("G35",ExecRiskBudgetOk(10.0,12.5),"loss inside budget rejected");
   Record("G36",!ExecRiskBudgetOk(13.0,12.5),"loss over budget accepted");
   Record("G37",!ExecRiskBudgetOk(1.0,0.0),"zero budget accepted");
   Record("G38",ExecRiskBudgetOk(0.0,12.5),"zero loss rejected");
  }

void RunNames(void)
  {
   Record("G39",ExecBlockName(EXEC_OK)=="OK","ok token changed");
   Record("G40",ExecBlockName(EXEC_BLOCK_NOT_DEMO)=="not_demo_account",
          "not-demo token changed");
   Record("G41",ExecBlockName(EXEC_BLOCK_ACCOUNT_TRADE_DISABLED)==
          "account_trade_disabled","account token changed");
   Record("G42",ExecBlockName(EXEC_BLOCK_TERMINAL_TRADE_DISABLED)==
          "terminal_trade_disabled","terminal token changed");
   Record("G43",ExecBlockName(EXEC_BLOCK_SYMBOL_DENIED)=="symbol_not_allowed",
          "symbol token changed");
   Record("G44",ExecBlockName(EXEC_BLOCK_SYMBOL_TRADE_DISABLED)==
          "symbol_trade_disabled","symbol trade token changed");
   Record("G45",ExecBlockName(EXEC_BLOCK_SYMBOL_CLOSE_ONLY)=="symbol_close_only",
          "close-only token changed");
   Record("G46",ExecBlockName(EXEC_BLOCK_KILL_SWITCH)=="kill_switch_active",
          "kill switch token changed");
   Record("G47",ExecBlockName(EXEC_BLOCK_DRY_RUN)=="dry_run",
          "dry-run token changed");
   Record("G48",ExecBlockName(EXEC_BLOCK_TP_INVALID)=="take_profit_invalid",
          "take-profit token changed");
   Record("G49",ExecBlockName(EXEC_BLOCK_STOP_TOO_CLOSE)==
          "stop_below_broker_level","stop token changed");
   Record("G50",ExecBlockName(EXEC_BLOCK_RISK_BUDGET)=="risk_budget_exceeded",
          "risk token changed");
   Record("G51",ExecBlockName(EXEC_BLOCK_MARGIN)=="free_margin_insufficient",
          "margin token changed");
  }

void RunAllTests(void)
  {
   g_pass=0;
   g_fail=0;
   PrintFormat("TEST|BEGIN|suite=execguard|version=1.00");
   RunContext();
   RunSymbols();
   RunTargets();
   RunStops();
   RunVolumes();
   RunBudget();
   RunNames();
   if(g_fail==0)
      PrintFormat("TEST|RESULT|ALL_PASS|pass=%d fail=%d|suite=execguard",
                  g_pass,g_fail);
   else
      PrintFormat("TEST|RESULT|FAIL|pass=%d fail=%d|suite=execguard",
                  g_pass,g_fail);
  }

void OnStart(void)
  {
   RunAllTests();
  }
