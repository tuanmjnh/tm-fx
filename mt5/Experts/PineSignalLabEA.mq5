//+------------------------------------------------------------------+
//|                                             PineSignalLabEA.mq5 |
//|        MT5 EA & AI Lab - Wonderwhales signal-only logger         |
//|                                                                  |
//| Reads the PinePort Wonderwhales indicator at shift=1 (closed bar)|
//| and writes one event per new signal. It never opens, closes,     |
//| modifies or cancels orders and never accesses account data.      |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Signal-only Wonderwhales logger. No trading functions."
#property strict

#include "../Include/LabLogger.mqh"
#include "../Include/PinePort/WonderwhalesContract.mqh"

input ENUM_WW_MODE InpMode          = WW_MODE_SAR; // Signal mode
input double       InpPsarStart     = 0.02;        // PSAR initial acceleration
input double       InpPsarInc       = 0.02;        // PSAR increment
input double       InpPsarMax       = 0.20;        // PSAR maximum acceleration
input int          InpFastEma       = 20;          // Fast EMA period
input int          InpSlowEma       = 50;          // Slow EMA period
input int          InpEma200        = 200;         // EMA200 period (display)
input int          InpAtrLen        = 14;          // ATR period
input double       InpMinAtrPct     = 0.5;         // Minimum ATR as % of price
input int          InpVolMaLen      = 20;          // Volume MA period
input int          InpRsiLen        = 14;          // RSI period (display)
input int          InpBbLen         = 20;          // Bollinger period (display)
input double       InpBbMult        = 2.0;         // Bollinger deviation
input int          InpWarmupBars    = 300;         // Closed bars required before logging
input string       InpOutputFile    = "pine_signal_log.csv"; // CSV in MQL5/Files
input bool         InpLogDebug      = false;       // Log per-tick debug lines

CLabLogger g_log("PineSignalLabEA",false);
WwConfig   g_cfg;
string     g_input_hash="";

int      g_handle=INVALID_HANDLE;
int      g_csv=INVALID_HANDLE;
datetime g_last_current_bar_time=0;
datetime g_last_csv_bar_time=0;
datetime g_ready_warn_bar=0;
bool     g_pending=false;
bool     g_warmup_warned=false;
long     g_tick_count=0;
long     g_signal_count=0;
long     g_buy_count=0;
long     g_sell_count=0;
long     g_skipped_count=0;

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

datetime LoadLastCsvBarTime(const string filename)
  {
   const int handle=FileOpen(filename,FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle==INVALID_HANDLE)
      return(0);

   datetime last=0;
   while(!FileIsEnding(handle))
     {
      const string line=FileReadString(handle);
      if(StringLen(line)==0)
         continue;
      string fields[];
      if(StringSplit(line,',',fields)<2)
         continue;
      const datetime bar_time=StringToTime(fields[1]);
      if(bar_time>0)
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
                      "detected_at,bar_open_time,confirmed_at,symbol,timeframe,mode,signal_id,side,sar_dir,psar,fast,slow,atr_pct,input_hash\r\n");
   return(true);
  }

void WriteCsv(const datetime detected_at,const datetime bar_open_time,
              const datetime confirmed_at,const string signal_id,const string side,
              const int sar_dir,const double psar,const double fast,const double slow,
              const double atr_pct)
  {
   if(g_csv==INVALID_HANDLE)
      return;

   const string line=StringFormat("%s,%s,%s,%s,%s,%s,%s,%s,%d,%s,%s,%s,%.10f,%s",
                                  TimeToString(detected_at,TIME_DATE|TIME_SECONDS),
                                  TimeToString(bar_open_time,TIME_DATE|TIME_SECONDS),
                                  TimeToString(confirmed_at,TIME_DATE|TIME_SECONDS),
                                  _Symbol,TimeframeName(_Period),WwModeName(g_cfg.mode),
                                  signal_id,side,sar_dir,
                                  PriceText(psar),
                                  PriceText(fast),
                                  PriceText(slow),
                                  atr_pct,g_input_hash);
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

   g_cfg.mode=InpMode;
   g_cfg.psar_start=InpPsarStart;
   g_cfg.psar_inc=InpPsarInc;
   g_cfg.psar_max=InpPsarMax;
   g_cfg.fast_ema=InpFastEma;
   g_cfg.slow_ema=InpSlowEma;
   g_cfg.ema200=InpEma200;
   g_cfg.atr_len=InpAtrLen;
   g_cfg.min_atr_pct=InpMinAtrPct;
   g_cfg.vol_ma_len=InpVolMaLen;
   g_cfg.rsi_len=InpRsiLen;
   g_cfg.bb_len=InpBbLen;
   g_cfg.bb_mult=InpBbMult;
   WwNormalizeConfig(g_cfg);

   g_input_hash=WwConfigHash(g_cfg,InpWarmupBars);

   g_handle=iCustom(_Symbol,_Period,"PinePort\\Wonderwhales",
                    InpMode,InpPsarStart,InpPsarInc,InpPsarMax,
                    InpFastEma,InpSlowEma,InpEma200,
                    InpAtrLen,InpMinAtrPct,
                    InpVolMaLen,InpRsiLen,InpBbLen,InpBbMult);
   if(g_handle==INVALID_HANDLE)
     {
      g_log.Error(StringFormat("event=indicator_create_failed error=%d action=stop",
                               GetLastError()));
      return(INIT_FAILED);
     }

   g_last_csv_bar_time=LoadLastCsvBarTime(InpOutputFile);
   if(!OpenCsv())
      g_csv=INVALID_HANDLE;

   datetime current_times[];
   if(CopyTime(_Symbol,_Period,0,1,current_times)!=1)
     {
      g_log.Error(StringFormat("event=copy_time_failed phase=init error=%d",GetLastError()));
      return(INIT_FAILED);
     }
   g_last_current_bar_time=current_times[0];

   g_log.Info(StringFormat(
                 "event=init mode=%s fast=%d slow=%d ema200=%d atr=%d min_atr_pct=%.3f vol=%d rsi=%d bb=%d/%.2f warmup=%d symbol=%s timeframe=%s digits=%d csv=%s resume_bar=%s input_hash=%s",
                 WwModeName(g_cfg.mode),g_cfg.fast_ema,g_cfg.slow_ema,g_cfg.ema200,
                 g_cfg.atr_len,g_cfg.min_atr_pct,g_cfg.vol_ma_len,g_cfg.rsi_len,
                 g_cfg.bb_len,g_cfg.bb_mult,InpWarmupBars,
                 _Symbol,TimeframeName(_Period),(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS),
                 InpOutputFile,
                 (g_last_csv_bar_time>0 ? TimeToString(g_last_csv_bar_time,TIME_DATE|TIME_SECONDS) : "none"),
                 g_input_hash));

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
   g_log.Info(StringFormat(
                 "event=deinit reason=%d ticks=%s signals=%s buy=%s sell=%s skipped=%s",
                 reason,IntegerToString(g_tick_count),IntegerToString(g_signal_count),
                 IntegerToString(g_buy_count),IntegerToString(g_sell_count),
                 IntegerToString(g_skipped_count)));
  }

void ProcessPendingBar(void)
  {
   datetime closed_times[];
   if(CopyTime(_Symbol,_Period,1,1,closed_times)!=1)
      return;

   const datetime bar_open_time=closed_times[0];
   if(g_last_csv_bar_time>0 && bar_open_time<=g_last_csv_bar_time)
     {
      g_pending=false;
      g_skipped_count++;
      return;
     }

   const int rates_total=(int)Bars(_Symbol,_Period);
   if(rates_total<=0 || BarsCalculated(g_handle)<rates_total)
     {
      if(g_ready_warn_bar!=bar_open_time)
        {
         g_log.Warn(StringFormat(
                       "event=indicator_not_ready bar_open=%s calculated=%d rates_total=%d action=retry",
                       TimeToString(bar_open_time,TIME_DATE|TIME_MINUTES),
                       BarsCalculated(g_handle),rates_total));
         g_ready_warn_bar=bar_open_time;
        }
      return;
     }

   double buy[],sell[],dir[],psar[],fast[],slow[],atr_pct[];
   if(CopyBuffer(g_handle,WW_BUF_BUY_SIGNAL,1,1,buy)!=1 ||
      CopyBuffer(g_handle,WW_BUF_SELL_SIGNAL,1,1,sell)!=1 ||
      CopyBuffer(g_handle,WW_BUF_SAR_DIR,1,1,dir)!=1 ||
      CopyBuffer(g_handle,WW_BUF_PSAR,1,1,psar)!=1 ||
      CopyBuffer(g_handle,WW_BUF_FAST_EMA,1,1,fast)!=1 ||
      CopyBuffer(g_handle,WW_BUF_SLOW_EMA,1,1,slow)!=1 ||
      CopyBuffer(g_handle,WW_BUF_ATR_PCT,1,1,atr_pct)!=1)
     {
      if(g_ready_warn_bar!=bar_open_time)
        {
         g_log.Warn(StringFormat(
                       "event=buffer_copy_failed bar_open=%s error=%d action=retry",
                       TimeToString(bar_open_time,TIME_DATE|TIME_MINUTES),GetLastError()));
         g_ready_warn_bar=bar_open_time;
        }
      return;
     }

   g_pending=false;

   const bool is_buy=(buy[0]==1.0);
   const bool is_sell=(sell[0]==1.0);

   if(is_buy && is_sell)
     {
      g_log.Error(StringFormat(
                     "event=invalid_signal reason=BOTH_SIDES bar_open=%s action=ignore",
                     TimeToString(bar_open_time,TIME_DATE|TIME_MINUTES)));
      return;
     }

   if(!is_buy && !is_sell)
      return;

   const string side=(is_buy ? "BUY" : "SELL");
   const string signal_id=WwSignalId(g_cfg.mode,is_buy);
   const datetime confirmed_at=bar_open_time+PeriodSeconds(_Period);
   const datetime detected_at=TimeCurrent();

   WriteCsv(detected_at,bar_open_time,confirmed_at,signal_id,side,
            (int)dir[0],psar[0],fast[0],slow[0],atr_pct[0]);

   g_signal_count++;
   if(is_buy)
      g_buy_count++;
   else
      g_sell_count++;
   g_last_csv_bar_time=bar_open_time;

   g_log.Info(StringFormat(
                 "event=signal signal_id=%s side=%s symbol=%s timeframe=%s bar_open=%s confirmed_at=%s detected_at=%s sar_dir=%d psar=%s fast=%s slow=%s atr_pct=%.4f input_hash=%s",
                 signal_id,side,_Symbol,TimeframeName(_Period),
                 TimeToString(bar_open_time,TIME_DATE|TIME_SECONDS),
                 TimeToString(confirmed_at,TIME_DATE|TIME_SECONDS),
                 TimeToString(detected_at,TIME_DATE|TIME_SECONDS),
                 (int)dir[0],PriceText(psar[0]),
                 PriceText(fast[0]),PriceText(slow[0]),
                 atr_pct[0],g_input_hash));
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
