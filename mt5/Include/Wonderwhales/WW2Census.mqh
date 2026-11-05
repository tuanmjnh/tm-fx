//+------------------------------------------------------------------+
//|                                                    WW2Census.mqh |
//|   Diagnostic signal census: one row per evaluated chart bar.      |
//|                                                                  |
//| Answers "why so few trades" with data: every row records whether  |
//| the bias, the setup and the trigger gate of the active mode       |
//| passed, and the reason the chain stopped. Enabled by InpDebug;    |
//| never a trading call, never the 18-column journal.                |
//+------------------------------------------------------------------+
#ifndef WW2_CENSUS_MQH
#define WW2_CENSUS_MQH

#include "WW2Types.mqh"

//--- Aggregate counters printed at deinit and in the journal SUMMARY row.
struct Ww2CensusStats
  {
   int bars;              // evaluated chart bars
   int signal;            // all three gates passed (an entry was attempted)
   int bias_invalid;      // bias timeframe unreadable
   int no_bias;           // bias timeframe readable but flat
   int setup_invalid;     // setup timeframe unreadable
   int no_setup;          // setup did not agree (PSAR flip / EMA alignment)
   int trigger_invalid;   // trigger timeframe unreadable
   int no_trigger;        // setup agreed but the trigger bar did not confirm
   int other;             // reason not classified (defensive)
  };

void Ww2CensusReset(Ww2CensusStats &s)
  {
   s.bars=0;
   s.signal=0;
   s.bias_invalid=0;
   s.no_bias=0;
   s.setup_invalid=0;
   s.no_setup=0;
   s.trigger_invalid=0;
   s.no_trigger=0;
   s.other=0;
  }

bool Ww2CensusOpen(const string file,int &handle)
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
                      "logged_at,bar_time,mode,bias_valid,bias_buy,bias_sell,"
                      "setup_valid,setup_buy,setup_sell,setup_align,"
                      "trigger_valid,trigger_buy,trigger_sell,signal,reason\r\n");
   FileSeek(handle,0,SEEK_END);
   return(true);
  }

void Ww2CensusWrite(const int handle,const datetime bar_time,
                    const ENUM_WW2_MODE mode,
                    const bool bias_valid,const bool bias_buy,const bool bias_sell,
                    const bool setup_valid,const bool setup_buy,const bool setup_sell,
                    const bool setup_align,const bool trigger_valid,
                    const bool trigger_buy,const bool trigger_sell,
                    const bool signal,const string reason)
  {
   if(handle==INVALID_HANDLE)
      return;
   FileWriteString(handle,StringFormat(
                      "%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s\r\n",
                      TimeToString(TimeCurrent()),TimeToString(bar_time),
                      Ww2ModeName(mode),
                      (int)bias_valid,(int)bias_buy,(int)bias_sell,
                      (int)setup_valid,(int)setup_buy,(int)setup_sell,
                      (int)setup_align,(int)trigger_valid,
                      (int)trigger_buy,(int)trigger_sell,
                      (int)signal,reason));
  }

//--- Bucket one reason string. Scalp and Swing use different names for the
//--- same stage, so both are mapped here.
void Ww2CensusCount(Ww2CensusStats &s,const string reason)
  {
   s.bars++;
   if(reason=="signal")
      s.signal++;
   else if(reason=="bias_invalid")
      s.bias_invalid++;
   else if(reason=="no_m15_bias" || reason=="no_w1_bias")
      s.no_bias++;
   else if(reason=="setup_invalid")
      s.setup_invalid++;
   else if(reason=="no_m5_flip" || reason=="no_d1_align")
      s.no_setup++;
   else if(reason=="trigger_invalid")
      s.trigger_invalid++;
   else if(reason=="no_m1_confirm" || reason=="no_h1_trigger")
      s.no_trigger++;
   else
      s.other++;
  }

string Ww2CensusSummary(const Ww2CensusStats &s)
  {
   return(StringFormat("census_bars=%d|census_signal=%d|census_bias_invalid=%d|"
                       "census_no_bias=%d|census_setup_invalid=%d|census_no_setup=%d|"
                       "census_trigger_invalid=%d|census_no_trigger=%d|census_other=%d",
                       s.bars,s.signal,s.bias_invalid,s.no_bias,s.setup_invalid,
                       s.no_setup,s.trigger_invalid,s.no_trigger,s.other));
  }

void Ww2CensusClose(const int handle)
  {
   if(handle!=INVALID_HANDLE)
      FileClose(handle);
  }

#endif
//+------------------------------------------------------------------+
