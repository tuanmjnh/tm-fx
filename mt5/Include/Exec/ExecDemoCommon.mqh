//+------------------------------------------------------------------+
//|                                              ExecDemoCommon.mqh  |
//|   Shared demo-execution helpers for the basket bots (Grid / DCA)  |
//|                                                                  |
//| ADR 0004: every bot may send real orders on a DEMO account. This  |
//| file never calls OrderSend. All order routing goes through        |
//| ExecBroker.mqh so a single file stays the only order-send point.  |
//| It reads positions/history/market data only; it never touches     |
//| credentials, WebRequest or sockets.                               |
//+------------------------------------------------------------------+
#ifndef EXEC_DEMO_COMMON_MQH
#define EXEC_DEMO_COMMON_MQH

#include "ExecBroker.mqh"

//--- Read-only view of the basket one magic owns on _Symbol.
struct ExecDemoBasket
  {
   int               count;          // number of open legs
   double            volume;         // total volume
   double            average_entry;  // volume-weighted entry
   double            min_entry;      // lowest leg entry (buy basket tracking)
   double            max_entry;      // highest leg entry (sell basket tracking)
   long              side;           // POSITION_TYPE_BUY / POSITION_TYPE_SELL, -1 empty
   double            floating_pnl;   // sum of POSITION_PROFIT
   datetime          first_time;     // open time of the oldest leg
   double            sl;             // basket stop read back from the legs
   double            tp;             // basket target read back from the legs
  };

void ExecDemoBasketReset(ExecDemoBasket &basket)
  {
   basket.count=0;
   basket.volume=0.0;
   basket.average_entry=0.0;
   basket.min_entry=0.0;
   basket.max_entry=0.0;
   basket.side=-1;
   basket.floating_pnl=0.0;
   basket.first_time=0;
   basket.sl=0.0;
   basket.tp=0.0;
  }

//--- Aggregates every position of this magic on _Symbol. Mixed sides are
//--- impossible for these bots; if one is found the basket is reported with
//--- side=-2 so the caller refuses to manage it.
bool ExecDemoBasketRead(const long magic,ExecDemoBasket &basket)
  {
   ExecDemoBasketReset(basket);

   const int total=PositionsTotal();
   for(int i=0; i<total; i++)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=magic)
         continue;

      const double volume=PositionGetDouble(POSITION_VOLUME);
      const double price=PositionGetDouble(POSITION_PRICE_OPEN);
      const long type=PositionGetInteger(POSITION_TYPE);
      const datetime open_time=(datetime)PositionGetInteger(POSITION_TIME);
      const double sl=PositionGetDouble(POSITION_SL);
      const double tp=PositionGetDouble(POSITION_TP);

      if(volume<=0.0 || price<=0.0)
         continue;

      if(basket.count==0)
        {
         basket.side=type;
         basket.min_entry=price;
         basket.max_entry=price;
         basket.first_time=open_time;
         basket.sl=sl;
         basket.tp=tp;
        }
      else
        {
         if(basket.side!=type)
            basket.side=-2;
         basket.min_entry=MathMin(basket.min_entry,price);
         basket.max_entry=MathMax(basket.max_entry,price);
         basket.first_time=MathMin(basket.first_time,open_time);
         if(sl>0.0 && (basket.sl<=0.0 || (type==POSITION_TYPE_BUY ? sl<basket.sl
                                                                  : sl>basket.sl)))
            basket.sl=sl;
        }

      basket.count++;
      basket.volume+=volume;
      basket.average_entry+=price*volume;
      basket.floating_pnl+=PositionGetDouble(POSITION_PROFIT)+
                           PositionGetDouble(POSITION_SWAP);
     }

   if(basket.count==0)
      return(true);
   basket.volume=NormalizeDouble(basket.volume,8);
   basket.average_entry=NormalizeDouble(basket.average_entry/basket.volume,_Digits);
   basket.floating_pnl=NormalizeDouble(basket.floating_pnl,2);
   return(true);
  }

//--- Closes every leg of the basket by market order through ExecBroker.
bool ExecDemoBasketClose(const long magic,const int deviation_points,
                         const string comment,int &closed,int &failed)
  {
   closed=0;
   failed=0;

   //--- Snapshot the tickets first: closing mutates the position list.
   ulong tickets[];
   ArrayResize(tickets,0);
   const int total=PositionsTotal();
   for(int i=0; i<total; i++)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=magic)
         continue;
      const int size=ArraySize(tickets);
      ArrayResize(tickets,size+1);
      tickets[size]=ticket;
     }

   for(int i=0; i<ArraySize(tickets); i++)
     {
      if(!PositionSelectByTicket(tickets[i]))
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=magic)
         continue;

      const bool is_buy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      const double volume=PositionGetDouble(POSITION_VOLUME);
      ExecFillResult fill;
      if(ExecClosePosition(tickets[i],is_buy,volume,deviation_points,magic,
                           comment,fill))
         closed++;
      else
         failed++;
     }
   return(failed==0);
  }

//--- Pushes one basket-wide SL/TP onto every leg. Stops are absolute prices,
//--- identical on all legs, so the basket stops as a unit at the broker too.
bool ExecDemoBasketSetStops(const long magic,const double sl,const double tp,
                            const int deviation_points,int &updated,int &failed)
  {
   updated=0;
   failed=0;
   if(deviation_points<0)
      return(false);

   ulong tickets[];
   ArrayResize(tickets,0);
   const int total=PositionsTotal();
   for(int i=0; i<total; i++)
     {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=magic)
         continue;
      const int size=ArraySize(tickets);
      ArrayResize(tickets,size+1);
      tickets[size]=ticket;
     }

   for(int i=0; i<ArraySize(tickets); i++)
     {
      if(!PositionSelectByTicket(tickets[i]))
         continue;
      const double current_sl=PositionGetDouble(POSITION_SL);
      const double current_tp=PositionGetDouble(POSITION_TP);
      if(MathAbs(current_sl-sl)<_Point*0.5 && MathAbs(current_tp-tp)<_Point*0.5)
        {
         updated++;
         continue;
        }
      ExecFillResult fill;
      if(ExecModifyStops(tickets[i],sl,tp,fill))
         updated++;
      else
         failed++;
     }
   return(failed==0);
  }

//+------------------------------------------------------------------+
//| Sizing and risk money                                             |
//+------------------------------------------------------------------+
//--- Account-currency value of one point for one lot.
double ExecDemoValuePerPoint(void)
  {
   const double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   const double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   const double tick_value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(!(point>0.0) || !(tick_size>0.0) || !(tick_value>0.0))
      return(0.0);
   return(tick_value*point/tick_size);
  }

//--- Money lost if the whole basket is stopped out at the given distance.
double ExecDemoBasketLossMoney(const double volume,const double stop_points)
  {
   const double value_per_point=ExecDemoValuePerPoint();
   if(!(volume>0.0) || !(stop_points>0.0) || !(value_per_point>0.0))
      return(0.0);
   return(volume*stop_points*value_per_point);
  }

//--- Basket stop / target price built from the average entry.
double ExecDemoStopPrice(const bool is_buy,const double average_entry,
                         const double stop_points)
  {
   const double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(!(average_entry>0.0) || !(stop_points>0.0) || !(point>0.0))
      return(0.0);
   const double price=(is_buy ? average_entry-stop_points*point
                              : average_entry+stop_points*point);
   return(NormalizeDouble(price,_Digits));
  }

double ExecDemoTargetPrice(const bool is_buy,const double average_entry,
                           const double target_points)
  {
   const double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(!(average_entry>0.0) || !(target_points>0.0) || !(point>0.0))
      return(0.0);
   const double price=(is_buy ? average_entry+target_points*point
                              : average_entry-target_points*point);
   return(NormalizeDouble(price,_Digits));
  }

//--- Broker stop level check for an absolute SL/TP pair. `reference` is the
//--- market price the order will fill at (ask for buy, bid for sell).
bool ExecDemoStopsBrokerOk(const bool is_buy,const double reference,
                           const double sl,const double tp)
  {
   const double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   const double stop_level=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   return(ExecStopsRespectBroker(reference,sl,tp,point,stop_level) &&
          ExecTakeProfitValid(is_buy,reference,sl,tp));
  }

//--- Freezes a basket that would breach the broker's minimum stop distance,
//--- instead of sending an order the broker will reject.
bool ExecDemoBasketStopsValid(const bool is_buy,const double reference,
                              const double sl,const double tp)
  {
   if(!(sl>0.0) || !(tp>0.0))
      return(false);
   return(ExecDemoStopsBrokerOk(is_buy,reference,sl,tp));
  }

//+------------------------------------------------------------------+
//| Small shared utilities                                            |
//+------------------------------------------------------------------+
bool ExecDemoKillSwitchPresent(const string file)
  {
   return(StringLen(ExecTrim(file))>0 && FileIsExist(ExecTrim(file)));
  }

//--- Realised money for one magic on _Symbol since `from`.
bool ExecDemoHistoryPnl(const long magic,const datetime from,double &pnl,
                        int &deals)
  {
   pnl=0.0;
   deals=0;
   if(!HistorySelect(from,TimeCurrent()+60))
      return(false);

   const int total=HistoryDealsTotal();
   for(int i=0; i<total; i++)
     {
      const ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0)
         continue;
      if((long)HistoryDealGetInteger(ticket,DEAL_MAGIC)!=magic)
         continue;
      if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=_Symbol)
         continue;
      pnl+=HistoryDealGetDouble(ticket,DEAL_PROFIT);
      pnl+=HistoryDealGetDouble(ticket,DEAL_SWAP);
      pnl+=HistoryDealGetDouble(ticket,DEAL_COMMISSION);
      deals++;
     }
   pnl=NormalizeDouble(pnl,2);
   return(deals>0);
  }

#endif // EXEC_DEMO_COMMON_MQH
