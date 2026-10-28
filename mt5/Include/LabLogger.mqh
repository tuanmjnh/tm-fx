//+------------------------------------------------------------------+
//|                                                   LabLogger.mqh |
//|              MT5 EA & AI Lab - research-only structured logging |
//+------------------------------------------------------------------+
#ifndef LAB_LOGGER_MQH
#define LAB_LOGGER_MQH

// Writes one structured line per event to the MT5 Experts journal.
// No file I/O and no account information are used.
class CLabLogger
  {
private:
   string            m_context;
   bool              m_debug_enabled;

   void              Emit(const string level,const string message) const
     {
      PrintFormat("LAB|%s|%s|%s|%s",
                  TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
                  level,
                  m_context,
                  message);
     }

public:
                     CLabLogger(const string context="lab",
                                const bool debug_enabled=false)
     {
      m_context=context;
      m_debug_enabled=debug_enabled;
     }

   void              Info(const string message) const
     {
      Emit("INFO",message);
     }

   void              Warn(const string message) const
     {
      Emit("WARN",message);
     }

   void              Error(const string message) const
     {
      Emit("ERROR",message);
     }

   void              Debug(const string message) const
     {
      if(m_debug_enabled)
         Emit("DEBUG",message);
     }

   bool              DebugEnabled(void) const
     {
      return(m_debug_enabled);
     }

   void              SetDebugEnabled(const bool enabled)
     {
      m_debug_enabled=enabled;
     }
  };

#endif // LAB_LOGGER_MQH
