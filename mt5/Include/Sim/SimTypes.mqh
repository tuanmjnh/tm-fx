//+------------------------------------------------------------------+
//|                                                     SimTypes.mqh |
//|        MT5 EA Lab - shared simulation-only types and helpers      |
//|                                                                  |
//| No trading, account, broker or file APIs are declared here.       |
//+------------------------------------------------------------------+
#ifndef SIM_TYPES_MQH
#define SIM_TYPES_MQH

//--- Virtual position direction. Volume is always positive.
enum ENUM_SIM_SIDE
  {
   SIM_SIDE_NONE = 0,
   SIM_SIDE_BUY  = 1,
   SIM_SIDE_SELL = -1
  };

string SimSideName(const ENUM_SIM_SIDE side)
  {
   switch(side)
     {
      case SIM_SIDE_BUY:  return("BUY");
      case SIM_SIDE_SELL: return("SELL");
      default:            return("NONE");
     }
  }

//--- FNV-1a 32-bit. Used for config fingerprints, not for security.
uint SimFnv1a32(const string text)
  {
   uint hash=2166136261; // 0x811C9DC5
   const int length=StringLen(text);
   for(int i=0; i<length; i++)
     {
      hash^=(uint)StringGetCharacter(text,i);
      hash*=16777619; // 0x01000193
     }
   return(hash);
  }

string SimHashString(const string text)
  {
   return(StringFormat("%08X",SimFnv1a32(text)));
  }

//--- Canonical text for config hashing: fixed order, fixed precision.
string SimFormatFingerprintPart(const string key,const double value,const int decimals=6)
  {
   return(key+"="+DoubleToString(value,decimals)+";");
  }

string SimFormatFingerprintPartInt(const string key,const long value)
  {
   return(key+"="+IntegerToString(value)+";");
  }

string SimFormatFingerprintPartText(const string key,const string value)
  {
   return(key+"="+value+";");
  }

#endif // SIM_TYPES_MQH
