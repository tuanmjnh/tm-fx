//+------------------------------------------------------------------+
//|                                              ExecDemoProbe.mq5   |
//|      One-shot proof that a live demo broker accepts the guarded   |
//|      order path of ExecBroker.mqh                                 |
//|                                                                  |
//| ExecGuardTests proves the guard matrix and the Strategy Tester    |
//| proves the order code, but ExecContextAllowed short-circuits on   |
//| MQL_TESTER, so neither shows that a real demo server fills the    |
//| request. This script sends exactly one market order with          |
//| mandatory SL/TP through ExecBroker.mqh and closes it immediately. |
//|                                                                  |
//| It refuses to run in the Strategy Tester (that would be the very  |
//| false evidence it exists to avoid), refuses real/contest          |
//| accounts, refuses while the kill switch file is present and       |
//| sends nothing until InpConfirm is set by hand.                    |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Demo-only single order probe. Sends nothing unless InpConfirm=true."
#property script_show_inputs

#include "../Include/Exec/ExecBroker.mqh"

input group "Confirmation"
input bool   InpConfirm            = false;    // true = actually send one demo order
input group "Order"
input double InpVolume             = 0.01;     // fixed probe volume
input int    InpStopPoints         = 3000;     // SL distance in points
input double InpTakeProfitR        = 1.0;      // TP = entry +/- SL distance * R
input int    InpMaxSlippagePoints  = 30;       // deviation for market orders
input long   InpMagicNumber        = 25002002; // probe magic, never the EA's
input string InpComment            = "ExecDemoProbe";
input group "Scope"
input string InpAllowedSymbols     = "XAUUSD"; // prefix allow-list
input string InpKillSwitchFile     = "PA_TREND_RIDER_DEMO_STOP.txt";

void Fail(const string stage,const string detail)
  {
   PrintFormat("PROBE|FAIL|%s|%s",stage,detail);
  }

void Step(const string detail)
  {
   PrintFormat("PROBE|%s",detail);
  }

int Run(void)
  {
   if(MQLInfoInteger(MQL_TESTER))
     {
      Fail("scope","runs_in_tester_is_the_evidence_we_do_not_want");
      return(1);
     }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Fail("scope","algo_trading_disabled_for_this_program");
      return(1);
     }
   if(!(InpVolume>0.0) || InpStopPoints<=0 || !(InpTakeProfitR>0.0) ||
      StringLen(InpComment)==0)
     {
      Fail("input","volume_points_or_r_non_positive");
      return(1);
     }

   ExecAccountState state;
   state.trade_mode=AccountInfoInteger(ACCOUNT_TRADE_MODE);
   state.account_trade_allowed=(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)!=0);
   state.terminal_trade_allowed=(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0);
   state.tester=false;

   ENUM_EXEC_BLOCK block=EXEC_OK;
   if(!ExecContextAllowed(state,block))
     {
      Fail("context",ExecBlockName(block));
      return(1);
     }
   if(!ExecSymbolAllowed(_Symbol,InpAllowedSymbols))
     {
      Fail("symbol",StringFormat("not_allowed|%s|allowlist=%s",
                                 _Symbol,InpAllowedSymbols));
      return(1);
     }
   if(!ExecSymbolTradable((long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE),block))
     {
      Fail("symbol",ExecBlockName(block));
      return(1);
     }
   if(StringLen(InpKillSwitchFile)>0 && FileIsExist(InpKillSwitchFile))
     {
      Fail("kill_switch","file_present|"+InpKillSwitchFile);
      return(1);
     }

   const double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   const double volume_min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   const double volume_max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   const double volume_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   const double stops_level=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   if(!(point>0.0))
     {
      Fail("symbol","point_not_positive");
      return(1);
     }

   const double volume=ExecNormalizeVolume(InpVolume,volume_min,volume_max,
                                           volume_step);
   if(!(volume>0.0))
     {
      Fail("volume",StringFormat("requested_outside_broker_bounds|requested=%.2f|min=%.2f|step=%.2f",
                                 InpVolume,volume_min,volume_step));
      return(1);
     }

   //--- Never stack a probe on top of a position that is still ours.
   ExecPositionInfo leftover;
   if(ExecFindOwnPosition(InpMagicNumber,leftover))
     {
      ExecFillResult cleanup;
      const bool closed=ExecClosePosition(leftover.ticket,
                                          leftover.type==POSITION_TYPE_BUY,
                                          leftover.volume,InpMaxSlippagePoints,
                                          InpMagicNumber,"ProbeCleanup",
                                          cleanup);
      Fail("precondition",StringFormat("own_position_exists|ticket=%I64u|cleanup=%s|%s",
                                       leftover.ticket,(closed ? "ok" : "failed"),
                                       cleanup.message));
      return(closed ? 2 : 3);
     }

   Step(StringFormat("READY|symbol=%s|digits=%d|volume=%.2f|magic=%I64d|stops_level=%.0f|confirm=%d",
                     _Symbol,_Digits,volume,InpMagicNumber,stops_level,
                     (InpConfirm ? 1 : 0)));

   if(!InpConfirm)
     {
      Step("DRY|all_guards_pass|no_order_sent|set_InpConfirm_to_send");
      return(0);
     }

   const bool is_buy=true;
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   const double sl_distance=(double)InpStopPoints*point;
   const double sl=NormalizeDouble(ask-sl_distance,_Digits);
   const double tp=ExecTakeProfitPrice(is_buy,ask,sl,InpTakeProfitR);
   if(!ExecTakeProfitValid(is_buy,ask,sl,tp))
     {
      Fail("stops",StringFormat("invalid_take_profit|ask=%.2f|sl=%.2f|tp=%.2f",
                                ask,sl,tp));
      return(1);
     }
   if(!ExecStopsRespectBroker(ask,sl,tp,point,stops_level))
     {
      Fail("stops",StringFormat("below_broker_level|stops_level=%.0f",stops_level));
      return(1);
     }

   double margin=0.0;
   if(!ExecMarginRequired(is_buy,volume,ask,margin))
     {
      Fail("margin","calc_failed");
      return(1);
     }
   Step(StringFormat("MARGIN|required=%.2f|free=%.2f",margin,
                     AccountInfoDouble(ACCOUNT_MARGIN_FREE)));

   ExecFillResult open;
   if(!ExecOpenMarket(is_buy,volume,sl,tp,InpMaxSlippagePoints,InpMagicNumber,
                      InpComment,open))
     {
      Fail("open",StringFormat("retcode=%u|%s",open.retcode,open.message));
      return(4);
     }
   Step(StringFormat("OPEN|order=%I64u|deal=%I64u|price=%.2f|volume=%.2f|sl=%.2f|tp=%.2f|%s",
                     open.order,open.deal,open.price,open.volume,sl,tp,
                     open.message));

   ExecPositionInfo position;
   if(!ExecFindOwnPosition(InpMagicNumber,position))
     {
      Fail("sync",StringFormat("position_not_found_after_fill|order=%I64u",
                               open.order));
      return(5);
     }
   Step(StringFormat("POSITION|ticket=%I64u|open=%.2f|sl=%.2f|tp=%.2f|volume=%.2f",
                     position.ticket,position.open_price,position.sl,
                     position.tp,position.volume));

   ExecFillResult close;
   if(!ExecClosePosition(position.ticket,position.type==POSITION_TYPE_BUY,
                         position.volume,InpMaxSlippagePoints,InpMagicNumber,
                         "ProbeClose",close))
     {
      Fail("close",StringFormat("retcode=%u|%s|ticket=%I64u",close.retcode,
                                close.message,position.ticket));
      return(6);
     }
   Step(StringFormat("CLOSE|order=%I64u|deal=%I64u|price=%.2f|%s",
                     close.order,close.deal,close.price,close.message));

   double pnl=0.0;
   int deals=0;
   ExecClosedPnl(position.ticket,(datetime)(TimeCurrent()-60),pnl,deals);
   Step(StringFormat("DONE|position=%I64u|deals=%d|pnl=%.2f|balance=%.2f",
                     position.ticket,deals,pnl,
                     AccountInfoDouble(ACCOUNT_BALANCE)));
   return(0);
  }

void OnStart(void)
  {
   Run();
  }
//+------------------------------------------------------------------+
