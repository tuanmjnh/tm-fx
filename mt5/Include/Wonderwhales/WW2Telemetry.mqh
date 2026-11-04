//+------------------------------------------------------------------+
//|                                                  WW2Telemetry.mqh |
//|   Separate telemetry CSV for fields the 18-column journal does not |
//|   carry (R, MAE/MFE, trailing reason, per-timeframe EMA/PSAR/ATR). |
//|                                                                  |
//| File I/O only. Never the journal schema; never a trading call.     |
//+------------------------------------------------------------------+
#ifndef WW2_TELEMETRY_MQH
#define WW2_TELEMETRY_MQH

#include "WW2Types.mqh"

string Ww2CsvSafe(const string value)
  {
   string out=value;
   StringReplace(out,",",";");
   StringReplace(out,"\r"," ");
   StringReplace(out,"\n"," ");
   return(out);
  }

bool Ww2TelemetryOpen(const string file,int &handle)
  {
   handle=INVALID_HANDLE;
   if(StringLen(file)==0)
      return(false);
   const bool fresh=!FileIsExist(file);
   handle=FileOpen(file,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(handle==INVALID_HANDLE)
      return(false);
   if(fresh)
      FileWriteString(handle,
                      "logged_at,bar_time,ticket,mode,r,sl,trail_reason,"
                      "ema_fast,ema_slow,ema200,atr_pct,sar_dir\r\n");
   FileSeek(handle,0,SEEK_END);
   return(true);
  }

void Ww2TelemetryWrite(const int handle,const datetime bar_time,
                       const ulong ticket,const ENUM_WW2_MODE mode,
                       const double r,const double sl,const string trail_reason,
                       const double ema_fast,const double ema_slow,
                       const double ema200,const double atr_pct,
                       const int sar_dir)
  {
   if(handle==INVALID_HANDLE)
      return;
   const string line=StringFormat(
                        "%s,%s,%d,%s,%.4f,%.5f,%s,%.5f,%.5f,%.5f,%.4f,%d\r\n",
                        TimeToString(TimeCurrent()),TimeToString(bar_time),
                        (int)ticket,Ww2ModeName(mode),r,sl,
                        Ww2CsvSafe(trail_reason),ema_fast,ema_slow,ema200,
                        atr_pct,sar_dir);
   FileWriteString(handle,line);
  }

void Ww2TelemetryClose(const int handle)
  {
   if(handle!=INVALID_HANDLE)
      FileClose(handle);
  }

#endif
//+------------------------------------------------------------------+
