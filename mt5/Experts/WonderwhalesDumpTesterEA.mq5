//+------------------------------------------------------------------+
//|                                   WonderwhalesDumpTesterEA.mq5    |
//|   MT5 EA & AI Lab - read-only dumper for the cross-implementation |
//|   port check of the PinePort\\Wonderwhales indicator.             |
//|                                                                  |
//| For every CLOSED bar it writes the bar plus the indicator's       |
//| buffers (PSAR, direction, signal flags, EMAs, ATR%) to a CSV in   |
//| MQL5/Files, so an independent Python port can be run on the exact |
//| same bars and its output compared bar by bar.                     |
//|                                                                  |
//| Reads shift=1 only and never requires BarsCalculated == Bars():    |
//| inside the Strategy Tester Bars() also counts the history the      |
//| terminal preloads before FromDate, while the indicator only        |
//| calculates the tested range. It never trades, never reads account  |
//| data, and refuses to run outside the tester. No network.           |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Read-only tester utility: dumps bars + Wonderwhales buffers. No trading."

#include "../Include/PinePort/WonderwhalesContract.mqh"

input ENUM_WW_MODE InpMode          = WW_MODE_SAR_EMA; // Signal mode
input double       InpPsarStart     = 0.02;        // PSAR initial acceleration
input double       InpPsarInc       = 0.02;        // PSAR increment
input double       InpPsarMax       = 0.20;        // PSAR maximum acceleration
input int          InpFastEma       = 20;          // Fast EMA period
input int          InpSlowEma       = 50;          // Slow EMA period
input int          InpEma200        = 200;         // EMA200 period
input int          InpAtrLen        = 14;          // ATR period
input double       InpMinAtrPct     = 0.5;         // Minimum ATR as % of price
input int          InpVolMaLen      = 20;          // Volume MA period
input int          InpRsiLen        = 14;          // RSI period
input int          InpBbLen         = 20;          // Bollinger period
input double       InpBbMult        = 2.0;         // Bollinger deviation
input ENUM_WW_PSAR InpPsarEngine   = WW_PSAR_ISAR; // PSAR engine fed to the indicator
input string       InpOutputFile    = "sim_portref_dump.csv"; // CSV in MQL5/Files

int      g_handle=INVALID_HANDLE;
int      g_csv=INVALID_HANDLE;
datetime g_last_current_bar_time=0;
long     g_rows=0;
long     g_skipped=0;

string TimeframeName(const ENUM_TIMEFRAMES timeframe)
  {
   string name=EnumToString(timeframe);
   if(StringFind(name,"PERIOD_")==0)
      name=StringSubstr(name,7);
   return(name);
  }

string PriceText(const double price)
  {
   if(price==EMPTY_VALUE || !MathIsValidNumber(price))
      return("");
   return(DoubleToString(price,8));
  }

int OnInit()
  {
   //--- Fail closed: this utility must never run on a chart.
   if(!MQLInfoInteger(MQL_TESTER))
     {
      Print("WHD|ERROR|not_a_tester_run|action=stop");
      return(INIT_FAILED);
     }

   g_handle=iCustom(_Symbol,_Period,"PinePort\\Wonderwhales",
                    InpMode,InpPsarStart,InpPsarInc,InpPsarMax,
                    InpFastEma,InpSlowEma,InpEma200,
                    InpAtrLen,InpMinAtrPct,
                    InpVolMaLen,InpRsiLen,InpBbLen,InpBbMult,
                    InpPsarEngine);
   if(g_handle==INVALID_HANDLE)
     {
      PrintFormat("WHD|ERROR|indicator_create_failed|error=%d",GetLastError());
      return(INIT_FAILED);
     }

   g_csv=FileOpen(InpOutputFile,FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(g_csv==INVALID_HANDLE)
     {
      PrintFormat("WHD|ERROR|csv_open_failed|file=%s|error=%d",
                  InpOutputFile,GetLastError());
      return(INIT_FAILED);
     }
   FileWriteString(g_csv,
                   "bar_open_time,symbol,timeframe,open,high,low,close,tick_volume,"
                   "psar,sar_dir,buy_signal,sell_signal,fast,slow,atr_pct,"
                   "blocked_buy,blocked_sell\r\n");

   datetime current[];
   if(CopyTime(_Symbol,_Period,0,1,current)==1)
      g_last_current_bar_time=current[0];

   PrintFormat("WHD|INFO|init|mode=%s|symbol=%s|timeframe=%s|file=%s",
               WwModeName(InpMode),_Symbol,TimeframeName(_Period),InpOutputFile);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_csv!=INVALID_HANDLE)
     {
      FileClose(g_csv);
      g_csv=INVALID_HANDLE;
     }
   if(g_handle!=INVALID_HANDLE)
     {
      IndicatorRelease(g_handle);
      g_handle=INVALID_HANDLE;
     }
   PrintFormat("WHD|INFO|deinit|reason=%d|rows=%d|skipped=%d",
               reason,(int)g_rows,(int)g_skipped);
  }

//--- Append the just-closed bar (shift 1) with its indicator values.
void AppendClosedBar(void)
  {
   MqlRates rate[];
   ArraySetAsSeries(rate,true);
   if(CopyRates(_Symbol,_Period,1,1,rate)!=1)
      return;

   double psar[],dir[],buy[],sell[],fast[],slow[],atr[],blk_buy[],blk_sell[];
   ArraySetAsSeries(psar,true);
   ArraySetAsSeries(dir,true);
   ArraySetAsSeries(buy,true);
   ArraySetAsSeries(sell,true);
   ArraySetAsSeries(fast,true);
   ArraySetAsSeries(slow,true);
   ArraySetAsSeries(atr,true);
   ArraySetAsSeries(blk_buy,true);
   ArraySetAsSeries(blk_sell,true);

   //--- If the indicator has not computed this bar yet, skip it rather than
   //--- writing a bogus row; the comparison skips the warm-up region anyway.
   if(CopyBuffer(g_handle,WW_BUF_BUY_SIGNAL,1,1,buy)!=1 ||
      CopyBuffer(g_handle,WW_BUF_SELL_SIGNAL,1,1,sell)!=1 ||
      CopyBuffer(g_handle,WW_BUF_SAR_DIR,1,1,dir)!=1 ||
      CopyBuffer(g_handle,WW_BUF_PSAR,1,1,psar)!=1 ||
      CopyBuffer(g_handle,WW_BUF_FAST_EMA,1,1,fast)!=1 ||
      CopyBuffer(g_handle,WW_BUF_SLOW_EMA,1,1,slow)!=1 ||
      CopyBuffer(g_handle,WW_BUF_ATR_PCT,1,1,atr)!=1 ||
      CopyBuffer(g_handle,WW_BUF_BLOCKED_BUY,1,1,blk_buy)!=1 ||
      CopyBuffer(g_handle,WW_BUF_BLOCKED_SELL,1,1,blk_sell)!=1)
     {
      g_skipped++;
      return;
     }

   FileWriteString(g_csv,StringFormat("%s,%s,%s,%s,%s,%s,%s,%d,%s,%d,%.0f,%.0f,%s,%s,%.10f,%.0f,%.0f\r\n",
                    TimeToString(rate[0].time,TIME_DATE|TIME_SECONDS),
                    _Symbol,TimeframeName(_Period),
                    DoubleToString(rate[0].open,8),
                    DoubleToString(rate[0].high,8),
                    DoubleToString(rate[0].low,8),
                    DoubleToString(rate[0].close,8),
                    (int)rate[0].tick_volume,
                    PriceText(psar[0]),(int)dir[0],
                    buy[0],sell[0],
                    PriceText(fast[0]),PriceText(slow[0]),atr[0],
                    blk_buy[0],blk_sell[0]));
   g_rows++;
   //--- Periodic flush keeps I/O low on a long range; FileClose flushes the rest.
   if((g_rows % 100)==0)
      FileFlush(g_csv);
  }

void OnTick()
  {
   datetime current[];
   if(CopyTime(_Symbol,_Period,0,1,current)!=1)
      return;

   if(current[0]!=g_last_current_bar_time)
     {
      g_last_current_bar_time=current[0];
      AppendClosedBar();
     }
  }
//+------------------------------------------------------------------+
