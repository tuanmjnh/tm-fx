//+------------------------------------------------------------------+
//|                                        CloseDemoPosition.mq5    |
//+------------------------------------------------------------------|
//| Closes every position whose magic == 25006001 on the current     |
//| symbol. Used to clear a stray demo position left on the account  |
//| before a headless Strategy Tester run.                           |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property script_show_inputs

#include "../Include/Exec/ExecBroker.mqh"

void OnStart(void)
  {
   const long magic = 25006001;
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action    = TRADE_ACTION_DEAL;
      req.position  = ticket;
      req.symbol    = Symbol();
      req.deviation = 30;
      const double vol = PositionGetDouble(POSITION_VOLUME);
      const bool  is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      req.volume = vol;
      req.type    = is_buy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      req.price   = is_buy ? SymbolInfoDouble(Symbol(), SYMBOL_BID)
                           : SymbolInfoDouble(Symbol(), SYMBOL_ASK);

      if(OrderSend(req, res) && res.retcode == TRADE_RETCODE_DONE)
         closed++;
     }
   PrintFormat("CLOSE_DONE|closed=%d|magic=%d", closed, magic);
   Comment(StringFormat("CLOSE_DONE closed=%d", closed));
  }
//+------------------------------------------------------------------+