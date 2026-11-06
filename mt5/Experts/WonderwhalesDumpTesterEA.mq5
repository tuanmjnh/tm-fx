//+------------------------------------------------------------------+
//|                                   WonderwhalesDumpTesterEA.mq5    |
//|   MT5 EA & AI Lab - read-only dumper for the cross-implementation |
//|   port check of the PinePort\\Wonderwhales indicator.             |
//|                                                                  |
//| For every bar it writes the bar plus the indicator's buffers      |
//| (PSAR, direction, signal flags, EMAs, ATR%) to a CSV in           |
//| MQL5/Files, so an independent Python port can be run on the exact |
//| same bars and its output compared bar by bar.                     |
//|                                                                  |
//| The preloaded history is dumped once at the first tick, because    |
//| the indicator's PSAR recurrence starts at ITS first bar and a      |
//| comparison only makes sense when both sides start at the same bar. |
//| Reads shift-independent absolute indices; never requires           |
//| BarsCalculated == Bars(). It never trades, never reads account     |
//| data, and refuses to run outside the tester. No network.           |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.10"
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
bool     g_dumped_preload=false;
datetime g_last_written_time=0;
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

   PrintFormat("WHD|INFO|init|mode=%s|psar_engine=%s|symbol=%s|timeframe=%s|file=%s",
               WwModeName(InpMode),
               (InpPsarEngine==WW_PSAR_ISAR ? "ISAR" : "BUILTIN"),
               _Symbol,TimeframeName(_Period),InpOutputFile);
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

//--- Copy one buffer aligned to `total` bars, oldest first. Returns the number
//--- of values obtained and, in `offset`, the index of the first row they cover
//--- (blank before that). A shorter indicator series therefore stays aligned.
int CopyAligned(const int buffer_index,const int total,double &values[],
                int &offset)
  {
   offset=0;
   ArraySetAsSeries(values,false);
   const int got=CopyBuffer(g_handle,buffer_index,0,total,values);
   if(got<=0)
      return(0);
   offset=total-got;
   if(offset<0)
      offset=0;
   return(got);
  }

//--- Write the whole series up to (and excluding) the forming bar.
void DumpPreload(void)
  {
   const int total=Bars(_Symbol,_Period);
   if(total<2)
      return;

   MqlRates rate[];
   ArraySetAsSeries(rate,false);
   if(CopyRates(_Symbol,_Period,0,total,rate)!=total)
      return;

   double psar[],dir[],buy[],sell[],fast[],slow[],atr[],blk_buy[],blk_sell[];
   int o_psar,o_dir,o_buy,o_sell,o_fast,o_slow,o_atr,o_bb,o_bs;
   const int n_psar=CopyAligned(WW_BUF_PSAR,total,psar,o_psar);
   const int n_dir=CopyAligned(WW_BUF_SAR_DIR,total,dir,o_dir);
   const int n_buy=CopyAligned(WW_BUF_BUY_SIGNAL,total,buy,o_buy);
   const int n_sell=CopyAligned(WW_BUF_SELL_SIGNAL,total,sell,o_sell);
   const int n_fast=CopyAligned(WW_BUF_FAST_EMA,total,fast,o_fast);
   const int n_slow=CopyAligned(WW_BUF_SLOW_EMA,total,slow,o_slow);
   const int n_atr=CopyAligned(WW_BUF_ATR_PCT,total,atr,o_atr);
   const int n_bb=CopyAligned(WW_BUF_BLOCKED_BUY,total,blk_buy,o_bb);
   const int n_bs=CopyAligned(WW_BUF_BLOCKED_SELL,total,blk_sell,o_bs);

   const string tf=TimeframeName(_Period);
   for(int i=0; i<total-1; i++)          // exclude the forming bar
     {
      const string psar_text=(n_psar>0 && i>=o_psar ? PriceText(psar[i-o_psar]) : "");
      const string dir_text=(n_dir>0 && i>=o_dir ? IntegerToString((int)dir[i-o_dir]) : "");
      const string buy_text=(n_buy>0 && i>=o_buy ? StringFormat("%.0f",buy[i-o_buy]) : "");
      const string sell_text=(n_sell>0 && i>=o_sell ? StringFormat("%.0f",sell[i-o_sell]) : "");
      const string fast_text=(n_fast>0 && i>=o_fast ? PriceText(fast[i-o_fast]) : "");
      const string slow_text=(n_slow>0 && i>=o_slow ? PriceText(slow[i-o_slow]) : "");
      const string atr_text=(n_atr>0 && i>=o_atr ? StringFormat("%.10f",atr[i-o_atr]) : "");
      const string bb_text=(n_bb>0 && i>=o_bb ? StringFormat("%.0f",blk_buy[i-o_bb]) : "");
      const string bs_text=(n_bs>0 && i>=o_bs ? StringFormat("%.0f",blk_sell[i-o_bs]) : "");

      FileWriteString(g_csv,StringFormat("%s,%s,%s,%s,%s,%s,%s,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s\r\n",
                       TimeToString(rate[i].time,TIME_DATE|TIME_SECONDS),
                       _Symbol,tf,
                       DoubleToString(rate[i].open,8),
                       DoubleToString(rate[i].high,8),
                       DoubleToString(rate[i].low,8),
                       DoubleToString(rate[i].close,8),
                       (int)rate[i].tick_volume,
                       psar_text,dir_text,buy_text,sell_text,fast_text,slow_text,
                       atr_text,bb_text,bs_text));
      g_rows++;
      g_last_written_time=rate[i].time;
     }
   FileFlush(g_csv);
  }

//--- Append one closed bar (shift 1) with its indicator values.
void AppendClosedBar(void)
  {
   MqlRates rate[];
   ArraySetAsSeries(rate,true);
   if(CopyRates(_Symbol,_Period,1,1,rate)!=1)
      return;
   if(rate[0].time<=g_last_written_time)   // already covered by the preload dump
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
   g_last_written_time=rate[0].time;
   //--- Periodic flush keeps I/O low on a long range; FileClose flushes the rest.
   if((g_rows % 100)==0)
      FileFlush(g_csv);
  }

void OnTick()
  {
   if(!g_dumped_preload)
     {
      DumpPreload();
      g_dumped_preload=true;
      return;
     }

   static datetime last_current=0;
   datetime current[];
   if(CopyTime(_Symbol,_Period,0,1,current)!=1)
      return;

   if(current[0]!=last_current)
     {
      last_current=current[0];
      AppendClosedBar();
     }
  }
//+------------------------------------------------------------------+
