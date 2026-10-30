//+------------------------------------------------------------------+
//|                                          InfiniteRunner_XAU.mq5  |
//|        Chiến lược: Luôn chạy 1 lệnh, TP = 0, Kéo SL liên tục     |
//+------------------------------------------------------------------+
#property copyright "Open Source"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//--- Thông số đầu vào (Đã chuẩn hóa cho XAUUSDm 3 chữ số thập phân: 1000 points = 1 USD giá Vàng)
input group "=== Quản lý vốn & Vào lệnh ==="
input double   InpLots          = 0.01;      // Khối lượng vào lệnh (Lot)
input int      InpFastEMA       = 21;        // Chu kỳ EMA nhanh (xác định hướng vào lệnh)
input int      InpSlowEMA       = 50;        // Chu kỳ EMA chậm
input int      InpMaxSpread     = 300;       // Spread tối đa cho phép (Points)

input group "=== Thiết lập Gồng Dương & Kéo SL (Points) ==="
input int      InpInitialSL     = 5000;      // SL ban đầu khi mới mở lệnh (5000 pts = 5 giá Vàng)
input int      InpTrailStart    = 3000;      // Bắt đầu kéo SL khi lãi đạt (3000 pts = 3 giá Vàng)
input int      InpTrailDistance = 2500;      // Khoảng cách SL bám đuổi theo giá (2500 pts = 2.5 giá)
input int      InpTrailStep     = 500;       // Bước nhảy tối thiểu mỗi lần dời SL (500 pts = 0.5 giá)
input ulong    InpMagicNumber   = 888999;    // Magic Number nhận diện bot

int handleFastEMA, handleSlowEMA;

//+------------------------------------------------------------------+
//| Khởi tạo EA                                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(50);

   handleFastEMA = iMA(_Symbol, _Period, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleSlowEMA = iMA(_Symbol, _Period, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);

   if(handleFastEMA == INVALID_HANDLE || handleSlowEMA == INVALID_HANDLE)
      return(INIT_FAILED);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Giải phóng bộ nhớ khi tắt EA                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleFastEMA);
   IndicatorRelease(handleSlowEMA);
}

//+------------------------------------------------------------------+
//| Xử lý trên từng nhịp giá (Tick)                                  |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Kiểm tra xem bot đang có lệnh nào mở trên cặp hiện tại không
   int myPositions = CountMyPositions();

   // 2. Nếu ĐANG CÓ LỆNH -> Chỉ tập trung gồng dương và kéo SL liên tục
   if(myPositions > 0)
   {
      ManageTrailingStop();
      return;
   }

   // 3. Nếu CHƯA CÓ LỆNH (vừa khởi động hoặc lệnh cũ vừa chạm SL) -> Mở ngay 1 lệnh mới
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpread) return; // Tránh vào lệnh lúc giãn spread quá mạnh

   double fastMA[], slowMA[];
   ArraySetAsSeries(fastMA, true);
   ArraySetAsSeries(slowMA, true);

   if(CopyBuffer(handleFastEMA, 0, 0, 2, fastMA) < 2) return;
   if(CopyBuffer(handleSlowEMA, 0, 0, 2, slowMA) < 2) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Xác định hướng theo EMA: EMA nhanh nằm trên EMA chậm -> BUY, ngược lại -> SELL
   // Lưu ý: Tham số TakeProfit truyền vào là 0.0 (Không giới hạn TP - Gồng dương vô cực)
   if(fastMA[0] >= slowMA[0])
   {
      double sl = NormalizeDouble(ask - InpInitialSL * _Point, _Digits);
      trade.Buy(InpLots, _Symbol, ask, sl, 0.0, "InfiniteRunner Buy");
   }
   else
   {
      double sl = NormalizeDouble(bid + InpInitialSL * _Point, _Digits);
      trade.Sell(InpLots, _Symbol, bid, sl, 0.0, "InfiniteRunner Sell");
   }
}

//+------------------------------------------------------------------+
//| Đếm số lệnh hiện tại của riêng Bot                               |
//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Hàm tự động dời Stop Loss đuổi theo giá (Trailing Stop)          |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      long   type      = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(type == POSITION_TYPE_BUY)
      {
         // Kiểm tra xem lệnh Buy đã lãi vượt mức kích hoạt Trailing chưa
         if(bid - openPrice >= InpTrailStart * _Point)
         {
            double newSL = NormalizeDouble(bid - InpTrailDistance * _Point, _Digits);
            // Chỉ dời SL lên cao hơn mức SL cũ ít nhất 1 khoảng bằng InpTrailStep
            if(newSL > currentSL + InpTrailStep * _Point || currentSL == 0)
            {
               trade.PositionModify(ticket, newSL, currentTP);
            }
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         // Kiểm tra xem lệnh Sell đã lãi vượt mức kích hoạt Trailing chưa
         if(openPrice - ask >= InpTrailStart * _Point)
         {
            double newSL = NormalizeDouble(ask + InpTrailDistance * _Point, _Digits);
            // Chỉ kéo SL xuống thấp hơn mức SL cũ ít nhất 1 khoảng bằng InpTrailStep
            if(newSL < currentSL - InpTrailStep * _Point || currentSL == 0)
            {
               trade.PositionModify(ticket, newSL, currentTP);
            }
         }
      }
   }
}