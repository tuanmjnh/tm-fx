//+------------------------------------------------------------------+
//|                                                    ExecGuard.mqh |
//|      Demo-only execution guards - pure, testable decision logic   |
//|                                                                  |
//| No trading, account or network API is called here. Every function |
//| takes explicit inputs so the contract suite can assert the guard  |
//| matrix without a terminal, an account or a broker.                |
//+------------------------------------------------------------------+
#ifndef EXEC_GUARD_MQH
#define EXEC_GUARD_MQH

//--- Stable reason tokens shared by the EA log, the contract tests and
//--- the static validator. Never reword them without updating all three.
enum ENUM_EXEC_BLOCK
  {
   EXEC_OK = 0,
   EXEC_BLOCK_NOT_DEMO = 1,
   EXEC_BLOCK_ACCOUNT_TRADE_DISABLED = 2,
   EXEC_BLOCK_TERMINAL_TRADE_DISABLED = 3,
   EXEC_BLOCK_SYMBOL_DENIED = 4,
   EXEC_BLOCK_SYMBOL_TRADE_DISABLED = 5,
   EXEC_BLOCK_SYMBOL_CLOSE_ONLY = 6,
   EXEC_BLOCK_KILL_SWITCH = 7,
   EXEC_BLOCK_DRY_RUN = 8,
   EXEC_BLOCK_TP_INVALID = 9,
   EXEC_BLOCK_STOP_TOO_CLOSE = 10,
   EXEC_BLOCK_RISK_BUDGET = 11,
   EXEC_BLOCK_MARGIN = 12
  };

string ExecBlockName(const ENUM_EXEC_BLOCK block)
  {
   switch(block)
     {
      case EXEC_OK:                           return("OK");
      case EXEC_BLOCK_NOT_DEMO:               return("not_demo_account");
      case EXEC_BLOCK_ACCOUNT_TRADE_DISABLED: return("account_trade_disabled");
      case EXEC_BLOCK_TERMINAL_TRADE_DISABLED:return("terminal_trade_disabled");
      case EXEC_BLOCK_SYMBOL_DENIED:          return("symbol_not_allowed");
      case EXEC_BLOCK_SYMBOL_TRADE_DISABLED:  return("symbol_trade_disabled");
      case EXEC_BLOCK_SYMBOL_CLOSE_ONLY:      return("symbol_close_only");
      case EXEC_BLOCK_KILL_SWITCH:            return("kill_switch_active");
      case EXEC_BLOCK_DRY_RUN:                return("dry_run");
      case EXEC_BLOCK_TP_INVALID:             return("take_profit_invalid");
      case EXEC_BLOCK_STOP_TOO_CLOSE:         return("stop_below_broker_level");
      case EXEC_BLOCK_RISK_BUDGET:            return("risk_budget_exceeded");
      case EXEC_BLOCK_MARGIN:                 return("free_margin_insufficient");
     }
   return("unknown");
  }

//--- Snapshot of the terminal/account facts the guard needs. The EA fills
//--- this from AccountInfo*/TerminalInfo*/MQLInfo*; the tests fill it by hand.
struct ExecAccountState
  {
   long              trade_mode;            // ACCOUNT_TRADE_MODE_*
   bool              account_trade_allowed; // ACCOUNT_TRADE_ALLOWED
   bool              terminal_trade_allowed;// TERMINAL_TRADE_ALLOWED
   bool              tester;                // MQL_TESTER
  };

//--- Demo or Strategy Tester only. A real/contest account is rejected; the
//--- tester path is allowed because it runs on a throwaway virtual account.
bool ExecContextAllowed(const ExecAccountState &state,ENUM_EXEC_BLOCK &block)
  {
   block=EXEC_OK;
   if(state.tester)
      return(true);
   if(state.trade_mode!=ACCOUNT_TRADE_MODE_DEMO)
     {
      block=EXEC_BLOCK_NOT_DEMO;
      return(false);
     }
   if(!state.account_trade_allowed)
     {
      block=EXEC_BLOCK_ACCOUNT_TRADE_DISABLED;
      return(false);
     }
   if(!state.terminal_trade_allowed)
     {
      block=EXEC_BLOCK_TERMINAL_TRADE_DISABLED;
      return(false);
     }
   return(true);
  }

string ExecTrim(const string value)
  {
   string text=value;
   StringTrimLeft(text);
   StringTrimRight(text);
   return(text);
  }

//--- Prefix allow-list, comma separated. "XAUUSD" accepts "XAUUSDm" but not
//--- "XAUUSD.pro" or "EURUSDm"; the suffix must be plain letters/digits.
bool ExecSymbolAllowed(const string symbol,const string allowlist)
  {
   const string target=ExecTrim(symbol);
   if(StringLen(target)==0)
      return(false);

   string items[];
   const int count=StringSplit(allowlist,',',items);
   for(int i=0; i<count; i++)
     {
      const string prefix=ExecTrim(items[i]);
      if(StringLen(prefix)==0 || StringLen(prefix)>StringLen(target))
         continue;
      if(StringFind(target,prefix)!=0)
         continue;
      const string suffix=StringSubstr(target,StringLen(prefix));
      bool alnum=true;
      for(int j=0; j<StringLen(suffix); j++)
        {
         const ushort code=StringGetCharacter(suffix,j);
         const bool letter=((code>='a' && code<='z') ||
                            (code>='A' && code<='Z'));
         const bool digit=(code>='0' && code<='9');
         if(!letter && !digit)
           {
            alnum=false;
            break;
           }
        }
      if(alnum)
         return(true);
     }
   return(false);
  }

bool ExecSymbolTradable(const long trade_mode,ENUM_EXEC_BLOCK &block)
  {
   block=EXEC_OK;
   if(trade_mode==SYMBOL_TRADE_MODE_DISABLED)
     {
      block=EXEC_BLOCK_SYMBOL_TRADE_DISABLED;
      return(false);
     }
   if(trade_mode==SYMBOL_TRADE_MODE_CLOSEONLY)
     {
      block=EXEC_BLOCK_SYMBOL_CLOSE_ONLY;
      return(false);
     }
   return(true);
  }

//--- Mandatory take profit, expressed as a multiple of the initial risk.
double ExecTakeProfitPrice(const bool is_buy,const double entry,
                           const double sl,const double r_multiple)
  {
   if(!(entry>0.0) || !(sl>0.0) || !(r_multiple>0.0))
      return(0.0);
   const double risk=MathAbs(entry-sl);
   if(!(risk>0.0))
      return(0.0);
   return(is_buy ? entry+risk*r_multiple : entry-risk*r_multiple);
  }

bool ExecTakeProfitValid(const bool is_buy,const double entry,const double sl,
                         const double tp)
  {
   if(!(entry>0.0) || !(sl>0.0) || !(tp>0.0))
      return(false);
   if(is_buy)
      return(sl<entry && tp>entry);
   return(sl>entry && tp<entry);
  }

bool ExecStopsRespectBroker(const double entry,const double sl,const double tp,
                            const double point,const double stop_level_points)
  {
   if(!(point>0.0) || !(entry>0.0) || !(sl>0.0) || !(tp>0.0))
      return(false);
   if(stop_level_points<=0.0)
      return(true);
   const double minimum=stop_level_points*point;
   if(MathAbs(entry-sl)<minimum-1e-12)
      return(false);
   if(MathAbs(tp-entry)<minimum-1e-12)
      return(false);
   return(true);
  }

//--- Floor to the volume step; returns 0 when the result is below the
//--- broker minimum, so the caller rejects instead of rounding up.
double ExecNormalizeVolume(const double volume,const double volume_min,
                           const double volume_max,const double volume_step)
  {
   if(!(volume>0.0) || !(volume_min>0.0) || !(volume_step>0.0) ||
      volume_max<volume_min)
      return(0.0);
   double value=MathFloor(volume/volume_step+1e-9)*volume_step;
   value=NormalizeDouble(value,8);
   if(value>volume_max)
      value=NormalizeDouble(volume_max,8);
   if(value<volume_min)
      return(0.0);
   return(value);
  }

bool ExecRiskBudgetOk(const double expected_loss,const double risk_money,
                      const double tolerance=1e-9)
  {
   if(!(risk_money>0.0) || expected_loss<0.0 || !MathIsValidNumber(expected_loss))
      return(false);
   return(expected_loss<=risk_money*(1.0+tolerance));
  }

#endif // EXEC_GUARD_MQH
