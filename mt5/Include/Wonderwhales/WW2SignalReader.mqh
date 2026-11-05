//+------------------------------------------------------------------+
//|                                              WW2SignalReader.mqh |
//|   Reads the PinePort\\Wonderwhales buffers through the contract.  |
//|                                                                  |
//| It never recomputes PSAR/EMA/ATR: values come from the indicator  |
//| handle created by the EA. No account or trading calls.            |
//+------------------------------------------------------------------+
#ifndef WW2_SIGNAL_READER_MQH
#define WW2_SIGNAL_READER_MQH

#include "WW2Types.mqh"
#include "../PinePort/WonderwhalesContract.mqh"

//--- True when the indicator has finished calculating enough bars.
bool Ww2IndicatorReady(const int handle,const int min_bars)
  {
   if(handle==INVALID_HANDLE)
      return(false);
   return(BarsCalculated(handle)>=min_bars);
  }

//--- Reads one closed bar (shift>=1) of the indicator. Returns false when a
//--- buffer is unavailable or holds EMPTY_VALUE / a non-finite value.
bool Ww2ReadSignal(const int handle,const string symbol,
                   const ENUM_TIMEFRAMES tf,const int shift,Ww2Signal &out)
  {
   out.valid=false;
   out.buy=false;
   out.sell=false;
   out.sar_dir=0;
   out.psar=0.0;
   out.atr_pct=0.0;
   out.fast_ema=0.0;
   out.slow_ema=0.0;
   out.ema200=0.0;
   out.open=0.0;
   out.close=0.0;

   if(handle==INVALID_HANDLE)
      return(false);

   double buy_buf[],sell_buf[],dir_buf[],psar_buf[];
   double atr_buf[],fast_buf[],slow_buf[],e200_buf[];
   ArraySetAsSeries(buy_buf,true);
   ArraySetAsSeries(sell_buf,true);
   ArraySetAsSeries(dir_buf,true);
   ArraySetAsSeries(psar_buf,true);
   ArraySetAsSeries(atr_buf,true);
   ArraySetAsSeries(fast_buf,true);
   ArraySetAsSeries(slow_buf,true);
   ArraySetAsSeries(e200_buf,true);

   if(CopyBuffer(handle,WW_BUF_BUY_SIGNAL,shift,1,buy_buf)<1)
      return(false);
   if(CopyBuffer(handle,WW_BUF_SELL_SIGNAL,shift,1,sell_buf)<1)
      return(false);
   if(CopyBuffer(handle,WW_BUF_SAR_DIR,shift,1,dir_buf)<1)
      return(false);
   if(CopyBuffer(handle,WW_BUF_PSAR,shift,1,psar_buf)<1)
      return(false);
   if(CopyBuffer(handle,WW_BUF_ATR_PCT,shift,1,atr_buf)<1)
      return(false);
   if(CopyBuffer(handle,WW_BUF_FAST_EMA,shift,1,fast_buf)<1)
      return(false);
   if(CopyBuffer(handle,WW_BUF_SLOW_EMA,shift,1,slow_buf)<1)
      return(false);
   if(CopyBuffer(handle,WW_BUF_EMA200,shift,1,e200_buf)<1)
      return(false);

   if(buy_buf[0]==EMPTY_VALUE || sell_buf[0]==EMPTY_VALUE ||
      psar_buf[0]==EMPTY_VALUE || atr_buf[0]==EMPTY_VALUE ||
      fast_buf[0]==EMPTY_VALUE || slow_buf[0]==EMPTY_VALUE ||
      e200_buf[0]==EMPTY_VALUE)
      return(false);

   if(!MathIsValidNumber(buy_buf[0]) || !MathIsValidNumber(sell_buf[0]) ||
      !MathIsValidNumber(psar_buf[0]) || !MathIsValidNumber(atr_buf[0]) ||
      !MathIsValidNumber(fast_buf[0]) || !MathIsValidNumber(slow_buf[0]) ||
      !MathIsValidNumber(e200_buf[0]))
      return(false);

   out.buy=(buy_buf[0]>0.5);
   out.sell=(sell_buf[0]>0.5);
   out.sar_dir=(int)dir_buf[0];
   out.psar=psar_buf[0];
   out.atr_pct=atr_buf[0];
   out.fast_ema=fast_buf[0];
   out.slow_ema=slow_buf[0];
   out.ema200=e200_buf[0];
   out.open=iOpen(symbol,tf,shift);
   out.close=iClose(symbol,tf,shift);
   out.valid=(out.close>0.0 && out.open>0.0);
   return(out.valid);
  }

//--- Reads a timeframe over a window of closed bars and merges it into one
//--- decision input: the most recent bar in the window that fired wins.
//---
//--- Why: the indicator emits BUY/SELL on the single bar where the flip
//--- happens. Reading shift=1 only therefore demands the event on the very last
//--- closed bar: for the M1 trigger that is 1 of the 5 M1 bars inside an M5
//--- setup bar, which the 2026-11-05 census showed removed 98.88% of setups.
//--- Used for both the setup window and the trigger window, so the pure
//--- evaluators keep their single-signal contract.
//--- The shift-1 read still has to succeed: a broken indicator must stay
//--- "setup_invalid"/"trigger_invalid", not silently become a permissive state.
bool Ww2ReadSignalWindow(const int handle,const string symbol,
                         const ENUM_TIMEFRAMES tf,const int window,
                         Ww2Signal &out)
  {
   if(!Ww2ReadSignal(handle,symbol,tf,1,out))
      return(false);
   if(window<=1)
      return(true);

   const int limit=(window>1000 ? 1000 : window);
   for(int shift=2;shift<=limit;shift++)
     {
      Ww2Signal candidate;
      if(!Ww2ReadSignal(handle,symbol,tf,shift,candidate))
         break;               // ran out of history; keep what we have
      if(candidate.buy || candidate.sell)
        {
         out=candidate;       // most recent firing bar wins
         return(true);
        }
     }
   return(true);
  }

#endif
//+------------------------------------------------------------------+
