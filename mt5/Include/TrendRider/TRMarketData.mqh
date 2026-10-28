//+------------------------------------------------------------------+
//|                                                TRMarketData.mqh |
//|      PA_TrendRider_XAU_V1 - closed-bar and symbol-spec loading    |
//|                                                                  |
//| Reads prices and symbol metrics only. No account, order, broker   |
//| or credential API is used; the EA stays simulation-only.          |
//+------------------------------------------------------------------+
#ifndef TR_MARKET_DATA_MQH
#define TR_MARKET_DATA_MQH

#include "TRTypes.mqh"
#include "TRRisk.mqh"

//--- Copies `count` closed bars, excluding the forming bar, oldest-first.
bool TRLoadClosedBars(const ENUM_TIMEFRAMES timeframe,const int count,
                      TRBar &bars[])
  {
   ArrayResize(bars,0);
   if(count<2)
      return(false);

   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   const int copied=CopyRates(_Symbol,timeframe,1,count,rates);
   if(copied<2)
      return(false);

   //--- rates[0] is the latest closed bar; bars[] must end on it.
   ArrayResize(bars,copied);
   for(int i=0; i<copied; i++)
     {
      const int src=copied-1-i;
      bars[i].time=rates[src].time;
      bars[i].open=rates[src].open;
      bars[i].high=rates[src].high;
      bars[i].low=rates[src].low;
      bars[i].close=rates[src].close;
      if(bars[i].high<bars[i].low || bars[i].close<=0.0)
        {
         ArrayResize(bars,0);
         return(false);
        }
     }
   return(true);
  }

bool TRLoadSymbolSpec(TRSymbolSpec &spec,string &error)
  {
   spec.point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   spec.tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   spec.tick_value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   spec.volume_min=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   spec.volume_max=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   spec.volume_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   spec.contract_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   spec.stops_level_points=(double)SymbolInfoInteger(_Symbol,
                                                     SYMBOL_TRADE_STOPS_LEVEL);
   spec.freeze_level_points=(double)SymbolInfoInteger(_Symbol,
                                                      SYMBOL_TRADE_FREEZE_LEVEL);

   if(spec.tick_size<=0.0 && spec.point>0.0)
      spec.tick_size=spec.point;
   return(TRSymbolSpecValid(spec,error));
  }

double TRSpreadPoints(const double bid,const double ask,const double point)
  {
   if(!TRIsFinitePositive(point) || !TRIsFinitePositive(bid) ||
      !TRIsFinitePositive(ask) || ask<bid)
      return(-1.0);
   return((ask-bid)/point);
  }

#endif // TR_MARKET_DATA_MQH
