//+------------------------------------------------------------------+
//|                                       PineMultiSignalLabEA.mq5   |
//|        MT5 EA & AI Lab - multi-source signal-only logger         |
//|                                                                  |
//| Reads the PinePort indicators at shift=1 (closed bar) and writes |
//| one CSV row per signal. It never opens, closes, modifies or      |
//| cancels orders and never accesses account data.                  |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Signal-only multi-indicator logger. No trading functions."
#property strict

#include "../Include/LabLogger.mqh"
#include "../Include/PinePort/WonderwhalesContract.mqh"
#include "../Include/PinePort/LongKacoVSAContract.mqh"
#include "../Include/PinePort/TMFusionZonesContract.mqh"
#include "../Include/PinePort/PriceActionMTFContract.mqh"
#include "../Include/PinePort/TMXAUSignals2Contract.mqh"
#include "../Include/PinePort/TMIndicator2Contract.mqh"

enum ENUM_MSL_SOURCE
  {
   MSL_WW=0,
   MSL_LK=1,
   MSL_FZ=2,
   MSL_PA=3,
   MSL_X2=4,
   MSL_TM2=5,
   MSL_COUNT=6
  };

input bool   InpEnableWw     = true;  // Read PinePort Wonderwhales
input bool   InpEnableLk     = false; // Read PinePort LongKacoVSA
input bool   InpEnableFz     = false; // Read PinePort TMFusionZones
input bool   InpEnablePa     = false; // Read PinePort PriceActionMTF
input bool   InpEnableX2     = false; // Read PinePort TMXAUSignals2
input bool   InpEnableTm2    = false; // Read PinePort TMIndicator2
input int    InpWarmupBars   = 300;   // Closed bars required before logging
input string InpOutputFile   = "pine_multi_signal_log.csv"; // CSV in MQL5/Files
input bool   InpLogDebug     = false; // Log per-tick debug lines

struct MslSignal
  {
   bool              has;
   string            side;
   double            dir;
   double            score;
   double            entry;
   double            sl;
   double            tp1;
   double            tp2;
   double            tp3;
   string            reason;

   void Reset(void)
     {
      has=false;
      side="";
      dir=EMPTY_VALUE;
      score=EMPTY_VALUE;
      entry=EMPTY_VALUE;
      sl=EMPTY_VALUE;
      tp1=EMPTY_VALUE;
      tp2=EMPTY_VALUE;
      tp3=EMPTY_VALUE;
      reason="";
     }
  };

CLabLogger g_log("PineMultiSignalLabEA",false);

int      g_handle[MSL_COUNT];
bool     g_enabled[MSL_COUNT];
bool     g_failed[MSL_COUNT];
datetime g_last_csv_bar[MSL_COUNT];
int      g_csv=INVALID_HANDLE;
datetime g_last_current_bar_time=0;
datetime g_ready_warn_bar=0;
bool     g_pending=false;
bool     g_warmup_warned=false;
long     g_tick_count=0;
long     g_signal_count=0;
long     g_skipped_count=0;

string SourceName(const int source)
  {
   switch(source)
     {
      case MSL_WW:  return("Wonderwhales");
      case MSL_LK:  return("LongKacoVSA");
      case MSL_FZ:  return("TMFusionZones");
      case MSL_PA:  return("PriceActionMTF");
      case MSL_X2:  return("TMXAUSignals2");
      case MSL_TM2: return("TMIndicator2");
     }
   return("unknown");
  }

string SourceTag(const int source)
  {
   switch(source)
     {
      case MSL_WW:  return("WW");
      case MSL_LK:  return("LK");
      case MSL_FZ:  return("FZ");
      case MSL_PA:  return("PA");
      case MSL_X2:  return("X2");
      case MSL_TM2: return("TM2");
     }
   return("UNKNOWN");
  }

string SourceVersion(const int source)
  {
   switch(source)
     {
      case MSL_WW:  return(WW_CONTRACT_VERSION);
      case MSL_LK:  return(LK_CONTRACT_VERSION);
      case MSL_FZ:  return(FZ_CONTRACT_VERSION);
      case MSL_PA:  return(PA_CONTRACT_VERSION);
      case MSL_X2:  return(X2_CONTRACT_VERSION);
      case MSL_TM2: return(TM2_CONTRACT_VERSION);
     }
   return("0.0.0");
  }

string SourcePath(const int source)
  {
   switch(source)
     {
      case MSL_WW:  return("PinePort\\Wonderwhales");
      case MSL_LK:  return("PinePort\\LongKacoVSA");
      case MSL_FZ:  return("PinePort\\TMFusionZones");
      case MSL_PA:  return("PinePort\\PriceActionMTF");
      case MSL_X2:  return("PinePort\\TMXAUSignals2");
      case MSL_TM2: return("PinePort\\TMIndicator2");
     }
   return("");
  }

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

string ScoreText(const double score)
  {
   if(score==EMPTY_VALUE || !MathIsValidNumber(score))
      return("");
   return(DoubleToString(score,4));
  }

string MslHash(const string text)
  {
   uint hash=2166136261;
   for(int i=0;i<StringLen(text);i++)
     {
      hash^=(uint)StringGetCharacter(text,i);
      hash*=16777619;
     }
   return(StringFormat("%08X",hash));
  }

string InputHash(const int source)
  {
   return(MslHash(SourceName(source)+"|"+SourceVersion(source)+"|indicator-defaults"));
  }

bool CopyOne(const int handle,const int index,double &value)
  {
   double buffer[];
   if(CopyBuffer(handle,index,1,1,buffer)!=1)
      return(false);
   value=buffer[0];
   return(true);
  }

bool CopySignalFlag(const int handle,const int index,bool &flag)
  {
   double value=0.0;
   if(!CopyOne(handle,index,value))
      return(false);
   flag=(value==1.0);
   return(true);
  }

bool SourceReady(const int handle,const datetime bar_open_time)
  {
   const int rates_total=(int)Bars(_Symbol,_Period);
   if(rates_total<=0 || BarsCalculated(handle)<rates_total)
     {
      if(g_ready_warn_bar!=bar_open_time)
        {
         g_log.Warn(StringFormat(
                       "event=indicator_not_ready bar_open=%s calculated=%d rates_total=%d action=retry",
                       TimeToString(bar_open_time,TIME_DATE|TIME_MINUTES),
                       BarsCalculated(handle),rates_total));
         g_ready_warn_bar=bar_open_time;
        }
      return(false);
     }
   return(true);
  }

bool ReadWw(MslSignal &e)
  {
   bool buy=false;
   bool sell=false;
   double dir=EMPTY_VALUE;
   if(!CopySignalFlag(g_handle[MSL_WW],WW_BUF_BUY_SIGNAL,buy) ||
      !CopySignalFlag(g_handle[MSL_WW],WW_BUF_SELL_SIGNAL,sell) ||
      !CopyOne(g_handle[MSL_WW],WW_BUF_SAR_DIR,dir))
      return(false);

   if(buy && sell)
     {
      g_log.Error("event=invalid_signal source=WW reason=BOTH_SIDES action=ignore");
      return(true);
     }
   if(!buy && !sell)
      return(true);

   e.has=true;
   e.side=(buy ? "BUY" : "SELL");
   e.dir=dir;
   return(true);
  }

bool ReadLk(MslSignal &e)
  {
   bool filled=false;
   double dir=EMPTY_VALUE;
   if(!CopySignalFlag(g_handle[MSL_LK],LK_BUF_FILL,filled) ||
      !CopyOne(g_handle[MSL_LK],LK_BUF_DIR,dir))
      return(false);
   if(!filled || dir==0.0)
      return(true);

   e.has=true;
   e.side=(dir>0.0 ? "BUY" : "SELL");
   e.dir=dir;
   if(!CopyOne(g_handle[MSL_LK],LK_BUF_ENTRY,e.entry))
      e.entry=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_LK],LK_BUF_SL,e.sl))
      e.sl=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_LK],LK_BUF_TP,e.tp1))
      e.tp1=EMPTY_VALUE;
   double event=0.0;
   if(CopyOne(g_handle[MSL_LK],LK_BUF_LAST_EVENT,event))
      e.reason=StringFormat("EVENT_%d",(int)event);
   return(true);
  }

bool ReadFz(MslSignal &e)
  {
   bool longSignal=false;
   bool shortSignal=false;
   if(!CopySignalFlag(g_handle[MSL_FZ],FZ_BUF_SIGNAL_LONG,longSignal) ||
      !CopySignalFlag(g_handle[MSL_FZ],FZ_BUF_SIGNAL_SHORT,shortSignal))
      return(false);
   if(longSignal && shortSignal)
     {
      g_log.Error("event=invalid_signal source=FZ reason=BOTH_SIDES action=ignore");
      return(true);
     }
   if(!longSignal && !shortSignal)
      return(true);

   const bool isLong=longSignal;
   e.has=true;
   e.side=(isLong ? "BUY" : "SELL");
   e.dir=(isLong ? 1.0 : -1.0);
   if(!CopyOne(g_handle[MSL_FZ],isLong ? FZ_BUF_SCORE_LONG : FZ_BUF_SCORE_SHORT,e.score))
      e.score=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_FZ],FZ_BUF_ENTRY,e.entry))
      e.entry=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_FZ],FZ_BUF_SL,e.sl))
      e.sl=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_FZ],FZ_BUF_TP1,e.tp1))
      e.tp1=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_FZ],FZ_BUF_TP2,e.tp2))
      e.tp2=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_FZ],FZ_BUF_TP3,e.tp3))
      e.tp3=EMPTY_VALUE;
   return(true);
  }

bool ReadPa(MslSignal &e)
  {
   bool longSignal=false;
   bool shortSignal=false;
   if(!CopySignalFlag(g_handle[MSL_PA],PA_BUF_SIG_LONG,longSignal) ||
      !CopySignalFlag(g_handle[MSL_PA],PA_BUF_SIG_SHORT,shortSignal))
      return(false);
   if(longSignal && shortSignal)
     {
      g_log.Error("event=invalid_signal source=PA reason=BOTH_SIDES action=ignore");
      return(true);
     }
   if(!longSignal && !shortSignal)
      return(true);

   const bool isLong=longSignal;
   e.has=true;
   e.side=(isLong ? "BUY" : "SELL");
   e.dir=(isLong ? 1.0 : -1.0);
   if(!CopyOne(g_handle[MSL_PA],PA_BUF_SCORE100,e.score))
      e.score=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_PA],PA_BUF_ENTRY,e.entry))
      e.entry=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_PA],PA_BUF_SL,e.sl))
      e.sl=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_PA],PA_BUF_TP1,e.tp1))
      e.tp1=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_PA],PA_BUF_TP2,e.tp2))
      e.tp2=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_PA],PA_BUF_TP3,e.tp3))
      e.tp3=EMPTY_VALUE;
   double block=0.0;
   if(CopyOne(g_handle[MSL_PA],PA_BUF_BLOCK,block) && block>0.0)
      e.reason=StringFormat("BLOCK_%d",(int)block);
   return(true);
  }

bool ReadX2(MslSignal &e)
  {
   bool signal=false;
   double dir=EMPTY_VALUE;
   if(!CopySignalFlag(g_handle[MSL_X2],X2_BUF_SIG,signal) ||
      !CopyOne(g_handle[MSL_X2],X2_BUF_DIR,dir))
      return(false);
   if(!signal || dir==0.0)
      return(true);

   e.has=true;
   e.side=(dir>0.0 ? "BUY" : "SELL");
   e.dir=dir;
   if(!CopyOne(g_handle[MSL_X2],X2_BUF_SCORE100,e.score))
      e.score=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_X2],X2_BUF_ENTRY,e.entry))
      e.entry=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_X2],X2_BUF_SL,e.sl))
      e.sl=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_X2],X2_BUF_TP1,e.tp1))
      e.tp1=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_X2],X2_BUF_TP2,e.tp2))
      e.tp2=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_X2],X2_BUF_TP3,e.tp3))
      e.tp3=EMPTY_VALUE;
   double block=0.0;
   if(CopyOne(g_handle[MSL_X2],X2_BUF_BLOCK,block) && block>0.0)
      e.reason=StringFormat("BLOCK_%d",(int)block);
   return(true);
  }

bool ReadTm2(MslSignal &e)
  {
   bool signal=false;
   double dir=EMPTY_VALUE;
   if(!CopySignalFlag(g_handle[MSL_TM2],TM2_BUF_SIGNAL,signal) ||
      !CopyOne(g_handle[MSL_TM2],TM2_BUF_DIR,dir))
      return(false);
   if(!signal || dir==0.0)
      return(true);

   e.has=true;
   e.side=(dir>0.0 ? "BUY" : "SELL");
   e.dir=dir;
   if(!CopyOne(g_handle[MSL_TM2],TM2_BUF_SCORE100,e.score))
      e.score=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_TM2],TM2_BUF_ENTRY,e.entry))
      e.entry=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_TM2],TM2_BUF_SL,e.sl))
      e.sl=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_TM2],TM2_BUF_TP1,e.tp1))
      e.tp1=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_TM2],TM2_BUF_TP2,e.tp2))
      e.tp2=EMPTY_VALUE;
   if(!CopyOne(g_handle[MSL_TM2],TM2_BUF_TP3,e.tp3))
      e.tp3=EMPTY_VALUE;
   double reason=0.0;
   if(CopyOne(g_handle[MSL_TM2],TM2_BUF_NO_TRADE_REASON,reason) && reason>0.0)
      e.reason=StringFormat("REASON_%d",(int)reason);
   return(true);
  }

bool ReadSource(const int source,MslSignal &e)
  {
   e.Reset();
   switch(source)
     {
      case MSL_WW:  return(ReadWw(e));
      case MSL_LK:  return(ReadLk(e));
      case MSL_FZ:  return(ReadFz(e));
      case MSL_PA:  return(ReadPa(e));
      case MSL_X2:  return(ReadX2(e));
      case MSL_TM2: return(ReadTm2(e));
     }
   return(false);
  }

datetime LoadLastCsvBarTime(const string filename,const int source)
  {
   const int handle=FileOpen(filename,FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle==INVALID_HANDLE)
      return(0);

   const string tag=SourceName(source);
   datetime last=0;
   bool first=true;
   while(!FileIsEnding(handle))
     {
      const string line=FileReadString(handle);
      if(first)
        {
         first=false;
         continue;
        }
      if(StringLen(line)==0)
         continue;
      string fields[];
      if(StringSplit(line,',',fields)<8)
         continue;
      if(fields[5]!=tag)
         continue;
      const datetime bar_time=StringToTime(fields[1]);
      if(bar_time>last)
         last=bar_time;
     }
   FileClose(handle);
   return(last);
  }

bool OpenCsv(void)
  {
   g_csv=FileOpen(InpOutputFile,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(g_csv==INVALID_HANDLE)
     {
      g_log.Error(StringFormat("event=csv_open_failed file=%s error=%d action=journal_only",
                               InpOutputFile,GetLastError()));
      return(false);
     }

   FileSeek(g_csv,0,SEEK_END);
   if(FileTell(g_csv)==0)
      FileWriteString(g_csv,
                      "detected_at,bar_open_time,confirmed_at,symbol,timeframe,source,contract_version,signal_id,side,dir,score,entry,sl,tp1,tp2,tp3,reason,input_hash\r\n");
   return(true);
  }

void WriteCsv(const int source,const datetime detected_at,const datetime bar_open_time,
              const datetime confirmed_at,const MslSignal &e)
  {
   if(g_csv==INVALID_HANDLE)
      return;

   const string signal_id=SourceTag(source)+"_"+e.side;
   const string line=StringFormat("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s",
                                  TimeToString(detected_at,TIME_DATE|TIME_SECONDS),
                                  TimeToString(bar_open_time,TIME_DATE|TIME_SECONDS),
                                  TimeToString(confirmed_at,TIME_DATE|TIME_SECONDS),
                                  _Symbol,TimeframeName(_Period),
                                  SourceName(source),SourceVersion(source),
                                  signal_id,e.side,
                                  (e.dir==EMPTY_VALUE ? "" : IntegerToString((int)e.dir)),
                                  ScoreText(e.score),
                                  PriceText(e.entry),PriceText(e.sl),
                                  PriceText(e.tp1),PriceText(e.tp2),PriceText(e.tp3),
                                  e.reason,InputHash(source));
   FileWriteString(g_csv,line+"\r\n");
   FileFlush(g_csv);
  }

int OnInit()
  {
   if(InpWarmupBars<0)
     {
      g_log.Error(StringFormat("event=invalid_config warmup_bars=%d",InpWarmupBars));
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_log.SetDebugEnabled(InpLogDebug);

   g_enabled[MSL_WW]=InpEnableWw;
   g_enabled[MSL_LK]=InpEnableLk;
   g_enabled[MSL_FZ]=InpEnableFz;
   g_enabled[MSL_PA]=InpEnablePa;
   g_enabled[MSL_X2]=InpEnableX2;
   g_enabled[MSL_TM2]=InpEnableTm2;

   for(int i=0;i<MSL_COUNT;i++)
     {
      g_handle[i]=INVALID_HANDLE;
      g_failed[i]=false;
      g_last_csv_bar[i]=0;
     }

   for(int i=0;i<MSL_COUNT;i++)
     {
      if(!g_enabled[i])
         continue;
      g_handle[i]=iCustom(_Symbol,_Period,SourcePath(i));
      if(g_handle[i]==INVALID_HANDLE)
        {
         g_log.Error(StringFormat("event=indicator_create_failed source=%s error=%d action=skip",
                                  SourceName(i),GetLastError()));
         g_failed[i]=true;
        }
     }

   for(int i=0;i<MSL_COUNT;i++)
     {
      if(g_enabled[i] && !g_failed[i])
         g_last_csv_bar[i]=LoadLastCsvBarTime(InpOutputFile,i);
     }

   if(!OpenCsv())
      g_csv=INVALID_HANDLE;

   datetime current_times[];
   if(CopyTime(_Symbol,_Period,0,1,current_times)!=1)
     {
      g_log.Error(StringFormat("event=copy_time_failed phase=init error=%d",GetLastError()));
      return(INIT_FAILED);
     }
   g_last_current_bar_time=current_times[0];

   string enabled="";
   for(int i=0;i<MSL_COUNT;i++)
     {
      if(g_enabled[i] && !g_failed[i])
         enabled+=(StringLen(enabled)>0 ? "/" : "")+SourceName(i);
     }
   if(StringLen(enabled)==0)
      enabled="none";

   g_log.Info(StringFormat(
                 "event=init sources=%s warmup=%d symbol=%s timeframe=%s csv=%s",
                 enabled,InpWarmupBars,_Symbol,TimeframeName(_Period),InpOutputFile));

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_csv!=INVALID_HANDLE)
     {
      FileClose(g_csv);
      g_csv=INVALID_HANDLE;
     }
   for(int i=0;i<MSL_COUNT;i++)
     {
      if(g_handle[i]!=INVALID_HANDLE)
        {
         IndicatorRelease(g_handle[i]);
         g_handle[i]=INVALID_HANDLE;
        }
     }
   g_log.Info(StringFormat(
                 "event=deinit reason=%d ticks=%s signals=%s skipped=%s",
                 reason,IntegerToString(g_tick_count),IntegerToString(g_signal_count),
                 IntegerToString(g_skipped_count)));
  }

void ProcessPendingBar(void)
  {
   datetime closed_times[];
   if(CopyTime(_Symbol,_Period,1,1,closed_times)!=1)
      return;

   const datetime bar_open_time=closed_times[0];
   const datetime confirmed_at=bar_open_time+PeriodSeconds(_Period);
   g_pending=false;

   for(int i=0;i<MSL_COUNT;i++)
     {
      if(!g_enabled[i] || g_failed[i] || g_handle[i]==INVALID_HANDLE)
         continue;

      if(bar_open_time<=g_last_csv_bar[i])
        {
         g_skipped_count++;
         continue;
        }

      if(!SourceReady(g_handle[i],bar_open_time))
         continue;

      MslSignal signal;
      const bool read_ok=ReadSource(i,signal);
      if(!read_ok)
        {
         g_log.Warn(StringFormat(
                       "event=buffer_copy_failed source=%s bar_open=%s error=%d action=retry",
                       SourceName(i),TimeToString(bar_open_time,TIME_DATE|TIME_MINUTES),
                       GetLastError()));
         continue;
        }
      if(!signal.has)
         continue;

      const datetime detected_at=TimeCurrent();
      WriteCsv(i,detected_at,bar_open_time,confirmed_at,signal);
      g_last_csv_bar[i]=bar_open_time;
      g_signal_count++;

      g_log.Info(StringFormat(
                    "event=signal source=%s version=%s signal_id=%s side=%s symbol=%s timeframe=%s bar_open=%s confirmed_at=%s dir=%s score=%s entry=%s sl=%s tp1=%s reason=%s input_hash=%s",
                    SourceName(i),SourceVersion(i),
                    SourceTag(i)+"_"+signal.side,signal.side,_Symbol,
                    TimeframeName(_Period),
                    TimeToString(bar_open_time,TIME_DATE|TIME_SECONDS),
                    TimeToString(confirmed_at,TIME_DATE|TIME_SECONDS),
                    (signal.dir==EMPTY_VALUE ? "" : IntegerToString((int)signal.dir)),
                    ScoreText(signal.score),PriceText(signal.entry),PriceText(signal.sl),
                    PriceText(signal.tp1),signal.reason,InputHash(i)));
     }
  }

void OnTick()
  {
   g_tick_count++;

   if(g_log.DebugEnabled())
      g_log.Debug(StringFormat("event=tick symbol=%s time=%s",
                               _Symbol,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)));

   datetime current_times[];
   if(CopyTime(_Symbol,_Period,0,1,current_times)!=1)
      return;

   if(current_times[0]!=g_last_current_bar_time)
     {
      g_last_current_bar_time=current_times[0];
      g_pending=true;
     }

   if(!g_pending)
      return;

   if(Bars(_Symbol,_Period)<=InpWarmupBars+1)
     {
      if(!g_warmup_warned)
        {
         g_log.Warn(StringFormat(
                       "event=warmup_wait bars=%d required=%d action=wait",
                       (int)Bars(_Symbol,_Period),InpWarmupBars+2));
         g_warmup_warned=true;
        }
      return;
     }

   ProcessPendingBar();
  }
//+------------------------------------------------------------------+
