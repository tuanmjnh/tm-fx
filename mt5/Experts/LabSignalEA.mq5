//+------------------------------------------------------------------+
//|                                                 LabSignalEA.mq5 |
//|        MT5 EA & AI Lab - signal-only research logger (Phase 1)  |
//|                                                                  |
//| This EA never opens, closes, modifies or cancels orders.         |
//| It only validates market data and logs one line per closed bar.  |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Signal-only lab EA. Logs new closed bars; no trading functions."
#property strict

#include "../Include/LabLogger.mqh"
#include "../Include/SignalEngine.mqh"

input bool InpLogEveryTick      = false; // Log every tick at DEBUG level (noisy)
input bool InpValidateClosedBar = true;  // Validate OHLC of the last closed bar
input int  InpFastPeriod        = 8;     // Fast EMA period (closed bars only)
input int  InpSlowPeriod        = 21;    // Slow EMA period (closed bars only)
input bool InpAllowLong         = true;  // Allow BUY signals
input bool InpAllowShort        = true;  // Allow SELL signals

CLabLogger      g_log("LabSignalEA",false);
LabSignalConfig g_signal_config;

datetime g_last_current_bar_time = 0;
datetime g_last_rates_warn_bar   = 0;
long     g_tick_count            = 0;
long     g_closed_bar_count      = 0;
long     g_invalid_bar_count     = 0;
bool     g_copy_time_error_seen  = false;

//--- Convert a timeframe enum to the short label used in logs.
string TimeframeName(const ENUM_TIMEFRAMES timeframe)
  {
   switch(timeframe)
     {
      case PERIOD_M1:  return("M1");
      case PERIOD_M2:  return("M2");
      case PERIOD_M3:  return("M3");
      case PERIOD_M4:  return("M4");
      case PERIOD_M5:  return("M5");
      case PERIOD_M6:  return("M6");
      case PERIOD_M10: return("M10");
      case PERIOD_M12: return("M12");
      case PERIOD_M15: return("M15");
      case PERIOD_M20: return("M20");
      case PERIOD_M30: return("M30");
      case PERIOD_H1:  return("H1");
      case PERIOD_H2:  return("H2");
      case PERIOD_H3:  return("H3");
      case PERIOD_H4:  return("H4");
      case PERIOD_H6:  return("H6");
      case PERIOD_H8:  return("H8");
      case PERIOD_H12: return("H12");
      case PERIOD_D1:  return("D1");
      case PERIOD_W1:  return("W1");
      case PERIOD_MN1: return("MN1");
      default:         return(EnumToString(timeframe));
     }
  }

//--- Human-readable deinitialization reason.
string DeinitReasonName(const int reason)
  {
   switch(reason)
     {
      case REASON_PROGRAM:     return("program");
      case REASON_REMOVE:      return("remove");
      case REASON_RECOMPILE:   return("recompile");
      case REASON_CHARTCHANGE: return("chart_change");
      case REASON_CHARTCLOSE:  return("chart_close");
      case REASON_PARAMETERS:  return("parameters");
      case REASON_ACCOUNT:     return("account");
      case REASON_TEMPLATE:    return("template");
      case REASON_INITFAILED:  return("init_failed");
      case REASON_CLOSE:       return("close");
      default:                 return("unknown");
     }
  }

//--- A usable price is finite and strictly positive.
bool IsUsablePrice(const double price)
  {
   return(MathIsValidNumber(price) && price>0.0);
  }

//--- Validate OHLC consistency. Returns false with a reason code.
bool ValidateBar(const MqlRates &bar,string &reason)
  {
   if(!IsUsablePrice(bar.open) || !IsUsablePrice(bar.high) ||
      !IsUsablePrice(bar.low)  || !IsUsablePrice(bar.close))
     {
      reason="non_finite_or_non_positive_price";
      return(false);
     }

   const double highest_body=MathMax(bar.open,MathMax(bar.close,bar.low));
   const double lowest_body =MathMin(bar.open,MathMin(bar.close,bar.high));

   if(bar.high+1e-12<highest_body)
     {
      reason="high_below_open_close_or_low";
      return(false);
     }

   if(bar.low-1e-12>lowest_body)
     {
      reason="low_above_open_close_or_high";
      return(false);
     }

   return(true);
  }

int OnInit()
  {
   g_log.SetDebugEnabled(InpLogEveryTick);

   g_signal_config.fast_period=InpFastPeriod;
   g_signal_config.slow_period=InpSlowPeriod;
   g_signal_config.allow_long =InpAllowLong;
   g_signal_config.allow_short=InpAllowShort;

   string config_error="";
   if(!LabValidateSignalConfig(g_signal_config,config_error))
     {
      g_log.Error(StringFormat(
                    "event=invalid_config error=%s fast_period=%d slow_period=%d",
                    config_error,InpFastPeriod,InpSlowPeriod));
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_log.Info(StringFormat(
                 "event=signal_config fast_period=%d slow_period=%d allow_long=%d allow_short=%d warmup_bars=%d",
                 InpFastPeriod,InpSlowPeriod,
                 (int)InpAllowLong,(int)InpAllowShort,
                 InpSlowPeriod+1));

   const int    bars      =(int)Bars(_Symbol,_Period);
   const int    digits    =(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const double point     =SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   const double tick_size =SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

   g_log.Info(StringFormat(
                 "event=init symbol=%s timeframe=%s digits=%d point=%.10g tick_size=%.10g bars=%d tester=%d build=%d",
                 _Symbol,TimeframeName(_Period),digits,point,tick_size,bars,
                 (int)MQLInfoInteger(MQL_TESTER),
                 (int)TerminalInfoInteger(TERMINAL_BUILD)));

   if(!SymbolInfoInteger(_Symbol,SYMBOL_SELECT))
      g_log.Warn(StringFormat("event=symbol_not_selected symbol=%s",_Symbol));

   if(bars<=0)
     {
      g_log.Warn(StringFormat(
                    "event=history_unavailable symbol=%s timeframe=%s bars=0 action=wait_for_history",
                    _Symbol,TimeframeName(_Period)));
      return(INIT_SUCCEEDED);
     }

   datetime current_times[];
   if(CopyTime(_Symbol,_Period,0,1,current_times)!=1)
     {
      g_log.Error(StringFormat(
                     "event=copy_time_failed phase=init symbol=%s timeframe=%s error=%d",
                     _Symbol,TimeframeName(_Period),GetLastError()));
      return(INIT_FAILED);
     }

   g_last_current_bar_time=current_times[0];
   g_log.Info(StringFormat(
                 "event=init_ok last_bar_open=%s server_time=%s utc_time=%s",
                 TimeToString(g_last_current_bar_time,TIME_DATE|TIME_MINUTES),
                 TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
                 TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS)));

   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   g_tick_count++;

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   if(g_log.DebugEnabled())
     {
      const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      g_log.Debug(StringFormat("event=tick symbol=%s bid=%s ask=%s",
                               _Symbol,
                               DoubleToString(bid,digits),
                               DoubleToString(ask,digits)));
     }

   datetime current_times[];
   if(CopyTime(_Symbol,_Period,0,1,current_times)!=1)
     {
      if(!g_copy_time_error_seen)
        {
         g_log.Warn(StringFormat(
                       "event=copy_time_failed phase=tick symbol=%s timeframe=%s error=%d action=retry",
                       _Symbol,TimeframeName(_Period),GetLastError()));
         g_copy_time_error_seen=true;
        }
      return;
     }
   g_copy_time_error_seen=false;

   if(current_times[0]==g_last_current_bar_time)
      return;

   //--- Copy only closed bars: shift 1 never includes the forming bar.
   const int needed=g_signal_config.slow_period+1;
   MqlRates closed_rates[];
   ArraySetAsSeries(closed_rates,true);
   const int copied=CopyRates(_Symbol,_Period,1,needed,closed_rates);

   if(copied<1)
     {
      if(g_last_rates_warn_bar!=current_times[0])
        {
         g_log.Warn(StringFormat(
                       "event=copy_rates_failed symbol=%s timeframe=%s copied=%d error=%d action=retry",
                       _Symbol,TimeframeName(_Period),copied,GetLastError()));
         g_last_rates_warn_bar=current_times[0];
        }
      g_last_current_bar_time=current_times[0];
      return;
     }

   const MqlRates closed_bar=closed_rates[0];
   string reason="";

   if(InpValidateClosedBar && !ValidateBar(closed_bar,reason))
     {
      g_invalid_bar_count++;
      g_log.Error(StringFormat(
                     "event=bar_invalid symbol=%s timeframe=%s bar_open=%s reason=%s open=%s high=%s low=%s close=%s",
                     _Symbol,TimeframeName(_Period),
                     TimeToString(closed_bar.time,TIME_DATE|TIME_MINUTES),
                     reason,
                     DoubleToString(closed_bar.open,digits),
                     DoubleToString(closed_bar.high,digits),
                     DoubleToString(closed_bar.low,digits),
                     DoubleToString(closed_bar.close,digits)));
      g_last_current_bar_time=current_times[0];
      return;
     }

   g_closed_bar_count++;

   g_log.Info(StringFormat(
                 "event=new_bar symbol=%s timeframe=%s bar_open=%s open=%s high=%s low=%s close=%s tick_volume=%s spread_points=%d real_volume=%s bars=%d",
                 _Symbol,TimeframeName(_Period),
                 TimeToString(closed_bar.time,TIME_DATE|TIME_MINUTES),
                 DoubleToString(closed_bar.open,digits),
                 DoubleToString(closed_bar.high,digits),
                 DoubleToString(closed_bar.low,digits),
                 DoubleToString(closed_bar.close,digits),
                 IntegerToString((long)closed_bar.tick_volume),
                 (int)closed_bar.spread,
                 IntegerToString((long)closed_bar.real_volume),
                 (int)Bars(_Symbol,_Period)));

   if(copied<needed)
     {
      g_log.Warn(StringFormat(
                    "event=signal signal=%s reason=%s symbol=%s timeframe=%s bar_open=%s history=%d needed=%d",
                    LabSignalName(LAB_SIGNAL_UNKNOWN),
                    LabReasonName(LAB_REASON_INSUFFICIENT_HISTORY),
                    _Symbol,TimeframeName(_Period),
                    TimeToString(closed_bar.time,TIME_DATE|TIME_MINUTES),
                    copied,needed));
      g_last_current_bar_time=current_times[0];
      return;
     }

   //--- Build a chronological close series ending at the last closed bar.
   double prices[];
   if(ArrayResize(prices,needed)!=needed)
     {
      g_log.Error(StringFormat(
                    "event=signal_skipped reason=ARRAY_RESIZE_FAILED needed=%d",needed));
      g_last_current_bar_time=current_times[0];
      return;
     }

   for(int i=0; i<needed; i++)
      prices[i]=closed_rates[needed-1-i].close;

   LabSignalResult result;
   const bool evaluated=LabEvaluateEmaCrossover(prices,needed,g_signal_config,result);

   if(!evaluated)
      g_log.Warn(StringFormat(
                    "event=signal signal=%s reason=%s symbol=%s timeframe=%s bar_open=%s history=%d needed=%d",
                    LabSignalName(result.signal),LabReasonName(result.reason),
                    _Symbol,TimeframeName(_Period),
                    TimeToString(closed_bar.time,TIME_DATE|TIME_MINUTES),
                    copied,needed));
   else
      g_log.Info(StringFormat(
                    "event=signal signal=%s reason=%s symbol=%s timeframe=%s bar_open=%s fast_prev=%s slow_prev=%s fast=%s slow=%s history=%d",
                    LabSignalName(result.signal),LabReasonName(result.reason),
                    _Symbol,TimeframeName(_Period),
                    TimeToString(closed_bar.time,TIME_DATE|TIME_MINUTES),
                    DoubleToString(result.fast_prev,digits),
                    DoubleToString(result.slow_prev,digits),
                    DoubleToString(result.fast_now,digits),
                    DoubleToString(result.slow_now,digits),
                    result.bars_used));

   g_last_current_bar_time=current_times[0];
  }

void OnDeinit(const int reason)
  {
   g_log.Info(StringFormat(
                 "event=deinit reason=%d reason_name=%s ticks=%s closed_bars=%s invalid_bars=%s",
                 reason,DeinitReasonName(reason),
                 IntegerToString(g_tick_count),
                 IntegerToString(g_closed_bar_count),
                 IntegerToString(g_invalid_bar_count)));
  }
//+------------------------------------------------------------------+
