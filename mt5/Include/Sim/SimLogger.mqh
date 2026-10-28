//+------------------------------------------------------------------+
//|                                                   SimLogger.mqh |
//|        MT5 EA Lab - fixed-schema CSV logger for simulation runs   |
//|                                                                  |
//| Writes only local MQL5/Files output. No account data, no secrets, |
//| no network and no trading API.                                    |
//+------------------------------------------------------------------+
#ifndef SIM_LOGGER_MQH
#define SIM_LOGGER_MQH

#include "SimTypes.mqh"

#define SIM_LOG_HEADER "logged_at,bar_time,ea,version,config_hash,symbol,timeframe,event,side,price,volume,entry,sl,tp,exposure,equity,drawdown_pct,reason"

struct SimLogRecord
  {
   datetime          logged_at;
   datetime          bar_time;
   string            ea;
   string            version;
   string            config_hash;
   string            symbol;
   string            timeframe;
   string            event;
   ENUM_SIM_SIDE     side;
   double            price;
   double            volume;
   double            entry;
   double            sl;
   double            tp;
   double            exposure;
   double            equity;
   double            drawdown_pct;
   string            reason;
  };

void SimClearLogRecord(SimLogRecord &record)
  {
   record.logged_at=0;
   record.bar_time=0;
   record.ea="";
   record.version="";
   record.config_hash="";
   record.symbol="";
   record.timeframe="";
   record.event="";
   record.side=SIM_SIDE_NONE;
   record.price=0.0;
   record.volume=0.0;
   record.entry=0.0;
   record.sl=0.0;
   record.tp=0.0;
   record.exposure=0.0;
   record.equity=0.0;
   record.drawdown_pct=0.0;
   record.reason="";
  }

string SimFormatLogLine(const SimLogRecord &record)
  {
   return(StringFormat("%s,%s,%s,%s,%s,%s,%s,%s,%s,%.8f,%.4f,%.8f,%.8f,%.8f,%.4f,%.2f,%.4f,%s",
                       TimeToString(record.logged_at,TIME_DATE|TIME_SECONDS),
                       TimeToString(record.bar_time,TIME_DATE|TIME_SECONDS),
                       record.ea,
                       record.version,
                       record.config_hash,
                       record.symbol,
                       record.timeframe,
                       record.event,
                       SimSideName(record.side),
                       record.price,
                       record.volume,
                       record.entry,
                       record.sl,
                       record.tp,
                       record.exposure,
                       record.equity,
                       record.drawdown_pct,
                       record.reason));
  }

class CSimLogger
  {
private:
   int               m_handle;
   string            m_filename;

public:
                     CSimLogger(void)
     {
      m_handle=INVALID_HANDLE;
      m_filename="";
     }

                    ~CSimLogger()
     {
      Close();
     }

   bool              IsOpen(void) const
     {
      return(m_handle!=INVALID_HANDLE);
     }

   string            Filename(void) const
     {
      return(m_filename);
     }

   bool              Open(const string filename,string &error)
     {
      Close();
      if(StringLen(filename)==0)
        {
         error="logger_filename_empty";
         return(false);
        }

      m_handle=FileOpen(filename,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(m_handle==INVALID_HANDLE)
        {
         error=StringFormat("logger_open_failed error=%d",GetLastError());
         m_filename="";
         return(false);
        }

      m_filename=filename;
      FileSeek(m_handle,0,SEEK_END);
      if(FileTell(m_handle)==0)
         FileWriteString(m_handle,SIM_LOG_HEADER+"\r\n");
      FileFlush(m_handle);
      error="";
      return(true);
     }

   bool              Write(const SimLogRecord &record,string &error)
     {
      if(m_handle==INVALID_HANDLE)
        {
         error="logger_not_open";
         return(false);
        }
      FileWriteString(m_handle,SimFormatLogLine(record)+"\r\n");
      FileFlush(m_handle);
      error="";
      return(true);
     }

   void              Close(void)
     {
      if(m_handle!=INVALID_HANDLE)
        {
         FileClose(m_handle);
         m_handle=INVALID_HANDLE;
        }
     }
  };

#endif // SIM_LOGGER_MQH
