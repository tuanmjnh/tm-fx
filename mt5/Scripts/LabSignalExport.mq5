//+------------------------------------------------------------------+
//|                                              LabSignalExport.mq5 |
//|        MT5 EA & AI Lab - export baseline signals for parity       |
//|                                                                  |
//| Reads a validated OHLCV CSV from Common\Files, re-evaluates the   |
//| baseline EMA crossover on every closed bar, and writes one CSV    |
//| row per bar. No trading, no account access, no market data.       |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Export EMA-crossover signals from a shared CSV fixture. No trading."
#property script_show_inputs
#property strict

#include "../Include/SignalEngine.mqh"

input string InpInputFile  = "parity_ema_cross.csv";     // Input CSV in Common\Files
input string InpOutputFile = "parity_signals_mql5.csv";  // Output CSV in Common\Files
input int    InpFastPeriod = 2;                         // Fast EMA period
input int    InpSlowPeriod = 3;                         // Slow EMA period
input bool   InpAllowLong  = true;                      // Allow BUY signals
input bool   InpAllowShort = true;                      // Allow SELL signals

//--- Trim ASCII whitespace from both ends of a copy.
string TrimCopy(const string value)
  {
   string copy=value;
   StringTrimLeft(copy);
   StringTrimRight(copy);
   return(copy);
  }

//--- Lowercase a copy; MQL5 StringToLower modifies its argument in place.
string LowerCopy(const string value)
  {
   string copy=value;
   StringToLower(copy);
   return(copy);
  }

//--- Locate a case-insensitive column name in a split header row.
bool FindColumn(const string &parts[],const int count,const string name,int &index)
  {
   const string wanted=LowerCopy(name);
   for(int i=0; i<count; i++)
     {
      if(LowerCopy(TrimCopy(parts[i]))==wanted)
        {
         index=i;
         return(true);
        }
     }
   index=-1;
   return(false);
  }

//--- Strip a UTF-8/UTF-16 byte-order mark read as ANSI characters.
string StripBom(const string value)
  {
   string copy=value;
   while(StringLen(copy)>0)
     {
      const ushort first=StringGetCharacter(copy,0);
      if(first==0xFEFF || first==0xEF || first==0xBB || first==0xBF)
         copy=StringSubstr(copy,1);
      else
         break;
     }
   return(copy);
  }

//--- Append a string to a dynamic array. Returns false if allocation fails.
bool AppendString(string &target[],const string value)
  {
   const int size=ArraySize(target);
   if(ArrayResize(target,size+1)!=size+1)
      return(false);
   target[size]=value;
   return(true);
  }

void OnStart()
  {
   LabSignalConfig config;
   config.fast_period=InpFastPeriod;
   config.slow_period=InpSlowPeriod;
   config.allow_long =InpAllowLong;
   config.allow_short=InpAllowShort;

   string config_error="";
   if(!LabValidateSignalConfig(config,config_error))
     {
      PrintFormat("event=invalid_config error=%s fast_period=%d slow_period=%d",
                  config_error,InpFastPeriod,InpSlowPeriod);
      return;
     }

   if(!FileIsExist(InpInputFile,FILE_COMMON))
     {
      PrintFormat("event=input_missing file=%s folder=common_files",InpInputFile);
      return;
     }

   const int input_handle=FileOpen(InpInputFile,FILE_COMMON|FILE_READ|FILE_TXT|FILE_ANSI);
   if(input_handle==INVALID_HANDLE)
     {
      PrintFormat("event=input_open_failed file=%s error=%d",
                  InpInputFile,GetLastError());
      return;
     }

   string lines[];
   int line_count=0;
   while(!FileIsEnding(input_handle))
     {
      const string line=TrimCopy(FileReadString(input_handle));
      if(line=="")
         continue;
      if(!AppendString(lines,line))
        {
         FileClose(input_handle);
         PrintFormat("event=input_alloc_failed rows=%d",line_count);
         return;
        }
      line_count++;
     }
   FileClose(input_handle);

   if(line_count<2)
     {
      PrintFormat("event=input_empty file=%s lines=%d",InpInputFile,line_count);
      return;
     }

   const ushort comma=StringGetCharacter(",",0);

   string header[];
   int header_count=StringSplit(StripBom(lines[0]),comma,header);
   int timestamp_index=-1;
   int symbol_index=-1;
   int timeframe_index=-1;
   int close_index=-1;

   if(header_count<=0 ||
      !FindColumn(header,header_count,"timestamp",timestamp_index) ||
      !FindColumn(header,header_count,"symbol",symbol_index) ||
      !FindColumn(header,header_count,"timeframe",timeframe_index) ||
      !FindColumn(header,header_count,"close",close_index))
     {
      PrintFormat("event=header_invalid file=%s required=timestamp,symbol,timeframe,close",
                  InpInputFile);
      return;
     }

   int required_index=timestamp_index;
   if(symbol_index>required_index)
      required_index=symbol_index;
   if(timeframe_index>required_index)
      required_index=timeframe_index;
   if(close_index>required_index)
      required_index=close_index;

   string timestamps[];
   string symbols[];
   string timeframes[];
   double closes[];

   for(int row=1; row<line_count; row++)
     {
      string parts[];
      const int field_count=StringSplit(lines[row],comma,parts);
      if(field_count<=required_index)
        {
         PrintFormat("event=row_invalid line=%d fields=%d",row+1,field_count);
         return;
        }

      const string timestamp=TrimCopy(parts[timestamp_index]);
      const string symbol   =TrimCopy(parts[symbol_index]);
      const string timeframe=TrimCopy(parts[timeframe_index]);
      const double close    =StringToDouble(TrimCopy(parts[close_index]));

      if(timestamp=="" || symbol=="" || timeframe=="")
        {
         PrintFormat("event=row_invalid line=%d reason=empty_key",row+1);
         return;
        }
      if(!LabIsUsableValue(close))
        {
         PrintFormat("event=row_invalid line=%d reason=invalid_close value=%.12g",
                     row+1,close);
         return;
        }

      if(!AppendString(timestamps,timestamp) ||
         !AppendString(symbols,symbol) ||
         !AppendString(timeframes,timeframe))
        {
         PrintFormat("event=row_alloc_failed line=%d",row+1);
         return;
        }
      const int close_count=ArraySize(closes);
      if(ArrayResize(closes,close_count+1)!=close_count+1)
        {
         PrintFormat("event=row_alloc_failed line=%d",row+1);
         return;
        }
      closes[close_count]=close;
     }

   const int data_count=ArraySize(closes);
   if(data_count<config.slow_period+1)
     {
      PrintFormat("event=insufficient_rows rows=%d needed=%d",
                  data_count,config.slow_period+1);
      return;
     }

   string output_rows[];
   int buy_count=0;
   int sell_count=0;
   int hold_count=0;
   int unknown_count=0;

   for(int index=0; index<data_count; index++)
     {
      string signal_name="UNKNOWN";
      string reason_name=LabReasonName(LAB_REASON_INSUFFICIENT_HISTORY);
      string fast_prev="";
      string slow_prev="";
      string fast_now="";
      string slow_now="";

      if(index>=config.slow_period)
        {
         const int window_size=config.slow_period+1;
         double window[];
         if(ArrayResize(window,window_size)!=window_size)
           {
            PrintFormat("event=window_alloc_failed bar=%d",index);
            return;
           }
         for(int offset=0; offset<window_size; offset++)
            window[offset]=closes[index-config.slow_period+offset];

         LabSignalResult result;
         LabEvaluateEmaCrossover(window,window_size,config,result);
         signal_name=LabSignalName(result.signal);
         reason_name=LabReasonName(result.reason);
         if(result.bars_used>0)
           {
            fast_prev=DoubleToString(result.fast_prev,12);
            slow_prev=DoubleToString(result.slow_prev,12);
            fast_now =DoubleToString(result.fast_now,12);
            slow_now =DoubleToString(result.slow_now,12);
           }
        }

      if(signal_name=="BUY")
         buy_count++;
      else if(signal_name=="SELL")
         sell_count++;
      else if(signal_name=="HOLD")
         hold_count++;
      else
         unknown_count++;

      const string output_row=StringFormat("%s,%s,%s,%s,%s,%s,%s,%s,%s",
                                           timestamps[index],symbols[index],
                                           timeframes[index],signal_name,reason_name,
                                           fast_prev,slow_prev,fast_now,slow_now);
      if(!AppendString(output_rows,output_row))
        {
         PrintFormat("event=output_alloc_failed bar=%d",index);
         return;
        }
     }

   const int output_handle=FileOpen(InpOutputFile,FILE_COMMON|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(output_handle==INVALID_HANDLE)
     {
      PrintFormat("event=output_open_failed file=%s error=%d",
                  InpOutputFile,GetLastError());
      return;
     }

   FileWriteString(output_handle,
                   "timestamp,symbol,timeframe,signal,reason,fast_prev,slow_prev,fast,slow\r\n");
   for(int index=0; index<ArraySize(output_rows); index++)
      FileWriteString(output_handle,output_rows[index]+"\r\n");
   FileClose(output_handle);

   PrintFormat("event=export_done rows=%d buy=%d sell=%d hold=%d unknown=%d fast=%d slow=%d input=%s output=%s",
               data_count,buy_count,sell_count,hold_count,unknown_count,
               config.fast_period,config.slow_period,InpInputFile,InpOutputFile);
  }
//+------------------------------------------------------------------+
