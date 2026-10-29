//+------------------------------------------------------------------+
//|                                                   ExecBroker.mqh |
//|      Demo-only order routing for PATrendRiderXAUv1DemoEA          |
//|                                                                  |
//| The only file that calls OrderSend/OrderCalcMargin. It never      |
//| reads credentials, never uses WebRequest/sockets and never opens  |
//| a connection: the terminal session is provided by the operator.   |
//| Callers must pass ExecGuard checks before any function here.      |
//+------------------------------------------------------------------+
#ifndef EXEC_BROKER_MQH
#define EXEC_BROKER_MQH

#include "ExecGuard.mqh"

#define EXEC_COMMENT_LIMIT 31

struct ExecFillResult
  {
   bool              ok;
   uint              retcode;
   ulong             order;
   ulong             deal;
   double            price;
   double            volume;
   string            message;
  };

struct ExecPositionInfo
  {
   bool              found;
   ulong             ticket;
   long              type;       // POSITION_TYPE_BUY / POSITION_TYPE_SELL
   double            volume;
   double            open_price;
   double            sl;
   double            tp;
   double            profit;
   datetime          open_time;
  };

string ExecRetcodeText(const uint retcode)
  {
   switch(retcode)
     {
      case TRADE_RETCODE_DONE:           return("done");
      case TRADE_RETCODE_DONE_PARTIAL:   return("done_partial");
      case TRADE_RETCODE_PLACED:         return("placed");
      case TRADE_RETCODE_REQUOTE:        return("requote");
      case TRADE_RETCODE_REJECT:         return("reject");
      case TRADE_RETCODE_INVALID:        return("invalid_request");
      case TRADE_RETCODE_INVALID_VOLUME: return("invalid_volume");
      case TRADE_RETCODE_INVALID_PRICE:  return("invalid_price");
      case TRADE_RETCODE_INVALID_STOPS:  return("invalid_stops");
      case TRADE_RETCODE_TRADE_DISABLED: return("trade_disabled");
      case TRADE_RETCODE_MARKET_CLOSED:  return("market_closed");
      case TRADE_RETCODE_NO_MONEY:       return("no_money");
      case TRADE_RETCODE_PRICE_CHANGED:  return("price_changed");
      case TRADE_RETCODE_PRICE_OFF:      return("price_off");
      case TRADE_RETCODE_INVALID_FILL:   return("invalid_filling");
      case TRADE_RETCODE_CONNECTION:     return("no_connection");
      case TRADE_RETCODE_LIMIT_VOLUME:   return("volume_limit");
      case TRADE_RETCODE_FROZEN:         return("frozen");
     }
   return(StringFormat("retcode_%u",retcode));
  }

bool ExecLastRetryable(const uint retcode)
  {
   return(retcode==TRADE_RETCODE_REQUOTE ||
          retcode==TRADE_RETCODE_PRICE_CHANGED ||
          retcode==TRADE_RETCODE_PRICE_OFF);
  }

string ExecComment(const string text)
  {
   string value=ExecTrim(text);
   if(StringLen(value)>EXEC_COMMENT_LIMIT)
      value=StringSubstr(value,0,EXEC_COMMENT_LIMIT);
   return(value);
  }

ENUM_ORDER_TYPE_FILLING ExecFillingMode(void)
  {
   const long modes=(long)SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((modes & (long)SYMBOL_FILLING_FOK)!=0)
      return(ORDER_FILLING_FOK);
   if((modes & (long)SYMBOL_FILLING_IOC)!=0)
      return(ORDER_FILLING_IOC);
   return(ORDER_FILLING_RETURN);
  }

void ExecClearResult(ExecFillResult &result)
  {
   result.ok=false;
   result.retcode=0;
   result.order=0;
   result.deal=0;
   result.price=0.0;
   result.volume=0.0;
   result.message="";
  }

double ExecAsk(void) { return(SymbolInfoDouble(_Symbol,SYMBOL_ASK)); }
double ExecBid(void) { return(SymbolInfoDouble(_Symbol,SYMBOL_BID)); }

//--- True when the result carries a fill or at least an accepted order.
bool ExecResultAccepted(const uint retcode)
  {
   return(retcode==TRADE_RETCODE_DONE ||
          retcode==TRADE_RETCODE_DONE_PARTIAL ||
          retcode==TRADE_RETCODE_PLACED);
  }

bool ExecOpenMarket(const bool is_buy,const double volume,const double sl,
                    const double tp,const int deviation_points,const long magic,
                    const string comment,ExecFillResult &result)
  {
   ExecClearResult(result);

   for(int attempt=0; attempt<2; attempt++)
     {
      const double price=(is_buy ? ExecAsk() : ExecBid());
      if(!(price>0.0))
        {
         result.message="quote_invalid";
         return(false);
        }

      MqlTradeRequest request;
      MqlTradeResult answer;
      ZeroMemory(request);
      ZeroMemory(answer);

      request.action=TRADE_ACTION_DEAL;
      request.symbol=_Symbol;
      request.volume=NormalizeDouble(volume,8);
      request.type=(is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      request.price=NormalizeDouble(price,_Digits);
      request.sl=NormalizeDouble(sl,_Digits);
      request.tp=NormalizeDouble(tp,_Digits);
      request.deviation=(ulong)MathMax(deviation_points,0);
      request.magic=(ulong)magic;
      request.comment=ExecComment(comment);
      request.type_filling=ExecFillingMode();
      request.type_time=ORDER_TIME_GTC;

      const bool sent=OrderSend(request,answer);
      result.retcode=answer.retcode;
      if(sent && ExecResultAccepted(answer.retcode))
        {
         result.ok=true;
         result.order=answer.order;
         result.deal=answer.deal;
         result.price=(answer.price>0.0 ? answer.price : price);
         result.volume=(answer.volume>0.0 ? answer.volume : volume);
         result.message="ok|"+ExecRetcodeText(answer.retcode);
         return(true);
        }
      if(!sent && !ExecLastRetryable(answer.retcode))
        {
         result.message="send_failed|"+ExecRetcodeText(answer.retcode);
         return(false);
        }
      if(sent && !ExecLastRetryable(answer.retcode))
        {
         result.message="rejected|"+ExecRetcodeText(answer.retcode);
         return(false);
        }
     }

   result.message="retry_exhausted|"+ExecRetcodeText(result.retcode);
   return(false);
  }

bool ExecModifyStops(const ulong position_ticket,const double sl,const double tp,
                     ExecFillResult &result)
  {
   ExecClearResult(result);

   MqlTradeRequest request;
   MqlTradeResult answer;
   ZeroMemory(request);
   ZeroMemory(answer);

   request.action=TRADE_ACTION_SLTP;
   request.symbol=_Symbol;
   request.position=position_ticket;
   request.sl=NormalizeDouble(sl,_Digits);
   request.tp=NormalizeDouble(tp,_Digits);

   const bool sent=OrderSend(request,answer);
   result.retcode=answer.retcode;
   if(sent && ExecResultAccepted(answer.retcode))
     {
      result.ok=true;
      result.order=answer.order;
      result.price=(answer.price>0.0 ? answer.price : 0.0);
      result.message="ok|"+ExecRetcodeText(answer.retcode);
      return(true);
     }
   result.message=(sent ? "rejected|" : "send_failed|")+
                  ExecRetcodeText(answer.retcode);
   return(false);
  }

bool ExecClosePosition(const ulong position_ticket,const bool is_buy_position,
                       const double volume,const int deviation_points,
                       const long magic,const string comment,
                       ExecFillResult &result)
  {
   ExecClearResult(result);

   for(int attempt=0; attempt<2; attempt++)
     {
      const double price=(is_buy_position ? ExecBid() : ExecAsk());
      if(!(price>0.0))
        {
         result.message="quote_invalid";
         return(false);
        }

      MqlTradeRequest request;
      MqlTradeResult answer;
      ZeroMemory(request);
      ZeroMemory(answer);

      request.action=TRADE_ACTION_DEAL;
      request.symbol=_Symbol;
      request.position=position_ticket;
      request.volume=NormalizeDouble(volume,8);
      request.type=(is_buy_position ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
      request.price=NormalizeDouble(price,_Digits);
      request.deviation=(ulong)MathMax(deviation_points,0);
      request.magic=(ulong)magic;
      request.comment=ExecComment(comment);
      request.type_filling=ExecFillingMode();
      request.type_time=ORDER_TIME_GTC;

      const bool sent=OrderSend(request,answer);
      result.retcode=answer.retcode;
      if(sent && ExecResultAccepted(answer.retcode))
        {
         result.ok=true;
         result.order=answer.order;
         result.deal=answer.deal;
         result.price=(answer.price>0.0 ? answer.price : price);
         result.volume=(answer.volume>0.0 ? answer.volume : volume);
         result.message="ok|"+ExecRetcodeText(answer.retcode);
         return(true);
        }
      if(!sent && !ExecLastRetryable(answer.retcode))
        {
         result.message="send_failed|"+ExecRetcodeText(answer.retcode);
         return(false);
        }
      if(sent && !ExecLastRetryable(answer.retcode))
        {
         result.message="rejected|"+ExecRetcodeText(answer.retcode);
         return(false);
        }
     }

   result.message="retry_exhausted|"+ExecRetcodeText(result.retcode);
   return(false);
  }

bool ExecFindOwnPosition(const long magic,ExecPositionInfo &info)
  {
   info.found=false;
   info.ticket=0;
   info.type=0;
   info.volume=0.0;
   info.open_price=0.0;
   info.sl=0.0;
   info.tp=0.0;
   info.profit=0.0;
   info.open_time=0;

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

      info.found=true;
      info.ticket=ticket;
      info.type=PositionGetInteger(POSITION_TYPE);
      info.volume=PositionGetDouble(POSITION_VOLUME);
      info.open_price=PositionGetDouble(POSITION_PRICE_OPEN);
      info.sl=PositionGetDouble(POSITION_SL);
      info.tp=PositionGetDouble(POSITION_TP);
      info.profit=PositionGetDouble(POSITION_PROFIT);
      info.open_time=(datetime)PositionGetInteger(POSITION_TIME);
      return(true);
     }
   return(false);
  }

//--- Net P/L of every deal that belongs to one position (profit+swap+commission).
bool ExecClosedPnl(const ulong position_id,const datetime from,double &pnl,
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
      if((ulong)HistoryDealGetInteger(ticket,DEAL_POSITION_ID)!=position_id)
         continue;
      pnl+=HistoryDealGetDouble(ticket,DEAL_PROFIT);
      pnl+=HistoryDealGetDouble(ticket,DEAL_SWAP);
      pnl+=HistoryDealGetDouble(ticket,DEAL_COMMISSION);
      deals++;
     }
   pnl=NormalizeDouble(pnl,2);
   return(deals>0);
  }

bool ExecMarginRequired(const bool is_buy,const double volume,const double price,
                        double &margin)
  {
   margin=0.0;
   if(!(volume>0.0) || !(price>0.0))
      return(false);
   return(OrderCalcMargin(is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,
                          volume,price,margin));
  }

#endif // EXEC_BROKER_MQH
