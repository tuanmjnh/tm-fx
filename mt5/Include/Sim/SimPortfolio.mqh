//+------------------------------------------------------------------+
//|                                                SimPortfolio.mqh |
//|        MT5 EA Lab - in-memory virtual positions and P&L           |
//|                                                                  |
//| Simulation only. No order, position, account or broker API is     |
//| used. P&L assumes contract size 1: one volume unit earns one      |
//| quote-currency unit per one price unit of favourable movement.    |
//| Commission is a total amount per fill, not per volume.            |
//+------------------------------------------------------------------+
#ifndef SIM_PORTFOLIO_MQH
#define SIM_PORTFOLIO_MQH

#include "SimTypes.mqh"
#include "SimValidate.mqh"

struct SimPosition
  {
   ENUM_SIM_SIDE     side;
   double            volume;
   double            entry;
  };

struct SimPortfolioSnapshot
  {
   bool              initialized;
   int               open_positions;
   double            net_volume;
   double            exposure;
   double            average_entry;
   double            unrealized_pnl;
   double            balance;
   double            realized_pnl;
   double            equity;
   double            peak_equity;
   double            max_drawdown_pct;
  };

class CSimPortfolio
  {
private:
   SimPosition       m_positions[];
   double            m_initial_balance;
   double            m_balance;
   double            m_realized;
   double            m_peak_equity;
   double            m_max_drawdown_pct;
   bool              m_initialized;

   void              UpdatePeak(const double equity)
     {
      if(equity>m_peak_equity)
         m_peak_equity=equity;
      if(m_peak_equity>0.0)
        {
         const double drawdown=(m_peak_equity-equity)/m_peak_equity*100.0;
         if(drawdown>m_max_drawdown_pct)
            m_max_drawdown_pct=drawdown;
        }
     }

public:
                     CSimPortfolio(void)
     {
      Reset();
     }

   void              Reset(void)
     {
      ArrayFree(m_positions);
      m_initial_balance=0.0;
      m_balance=0.0;
      m_realized=0.0;
      m_peak_equity=0.0;
      m_max_drawdown_pct=0.0;
      m_initialized=false;
     }

   bool              Init(const double initial_balance,string &error)
     {
      Reset();
      if(!SimValidateInitialBalance(initial_balance,error))
         return(false);

      m_initial_balance=initial_balance;
      m_balance=initial_balance;
      m_peak_equity=initial_balance;
      m_initialized=true;
      error="";
      return(true);
     }

   bool              IsInitialized(void) const
     {
      return(m_initialized);
     }

   int               OpenPositions(void) const
     {
      return(ArraySize(m_positions));
     }

   double            InitialBalance(void) const
     {
      return(m_initial_balance);
     }

   double            Balance(void) const
     {
      return(m_balance);
     }

   double            RealizedPnl(void) const
     {
      return(m_realized);
     }

   double            PeakEquity(void) const
     {
      return(m_peak_equity);
     }

   double            MaxDrawdownPct(void) const
     {
      return(m_max_drawdown_pct);
     }

   double            Exposure(void) const
     {
      double total=0.0;
      const int count=ArraySize(m_positions);
      for(int i=0; i<count; i++)
         total+=m_positions[i].volume;
      return(total);
     }

   double            NetVolume(void) const
     {
      double total=0.0;
      const int count=ArraySize(m_positions);
      for(int i=0; i<count; i++)
         total+=(int)m_positions[i].side*m_positions[i].volume;
      return(total);
     }

   double            AverageEntry(void) const
     {
      double weighted=0.0;
      double volume=0.0;
      const int count=ArraySize(m_positions);
      for(int i=0; i<count; i++)
        {
         weighted+=m_positions[i].entry*m_positions[i].volume;
         volume+=m_positions[i].volume;
        }
      if(volume<=0.0)
         return(0.0);
      return(weighted/volume);
     }

   double            MinEntry(void) const
     {
      const int count=ArraySize(m_positions);
      if(count<=0)
         return(0.0);
      double value=m_positions[0].entry;
      for(int i=1; i<count; i++)
         value=MathMin(value,m_positions[i].entry);
      return(value);
     }

   double            MaxEntry(void) const
     {
      const int count=ArraySize(m_positions);
      if(count<=0)
         return(0.0);
      double value=m_positions[0].entry;
      for(int i=1; i<count; i++)
         value=MathMax(value,m_positions[i].entry);
      return(value);
     }

   double            UnrealizedPnl(const double price) const
     {
      if(!SimIsFinite(price) || price<=0.0)
         return(0.0);

      double total=0.0;
      const int count=ArraySize(m_positions);
      for(int i=0; i<count; i++)
         total+=(int)m_positions[i].side*(price-m_positions[i].entry)*m_positions[i].volume;
      return(total);
     }

   double            Equity(const double price)
     {
      if(!m_initialized)
         return(0.0);
      const double equity=m_balance+UnrealizedPnl(price);
      UpdatePeak(equity);
      return(equity);
     }

   bool              Open(const ENUM_SIM_SIDE side,const double price,
                          const double volume,const double commission,
                          string &error)
     {
      if(!m_initialized)
        {
         error="portfolio_not_initialized";
         return(false);
        }
      if(side==SIM_SIDE_NONE)
        {
         error="side_must_not_be_none";
         return(false);
        }
      if(!SimValidatePrice(price,error))
         return(false);
      if(!SimValidateVolume(volume,error))
         return(false);
      if(!SimValidateCommission(commission,error))
         return(false);

      const int count=ArraySize(m_positions);
      if(count>0 && m_positions[0].side!=side)
        {
         error="opposite_side_not_allowed";
         return(false);
        }

      if(ArrayResize(m_positions,count+1)!=count+1)
        {
         error="portfolio_resize_failed";
         return(false);
        }
      m_positions[count].side=side;
      m_positions[count].volume=volume;
      m_positions[count].entry=price;

      m_realized-=commission;
      m_balance=m_initial_balance+m_realized;
      UpdatePeak(m_balance+UnrealizedPnl(price));
      error="";
      return(true);
     }

   //--- Closes every virtual position at price. commission is a total.
   bool              CloseAll(const double price,const double commission,
                              string &error,double &realized_delta)
     {
      realized_delta=0.0;
      if(!m_initialized)
        {
         error="portfolio_not_initialized";
         return(false);
        }
      if(!SimValidatePrice(price,error))
         return(false);
      if(!SimValidateCommission(commission,error))
         return(false);

      const int count=ArraySize(m_positions);
      if(count<=0)
        {
         error="no_open_positions";
         return(false);
        }

      double gross=0.0;
      for(int i=0; i<count; i++)
         gross+=(int)m_positions[i].side*(price-m_positions[i].entry)*m_positions[i].volume;

      realized_delta=gross-commission;
      m_realized+=realized_delta;
      m_balance=m_initial_balance+m_realized;
      ArrayFree(m_positions);
      UpdatePeak(m_balance);
      error="";
      return(true);
     }

   //--- Closes the positions whose side-adjusted profit per volume at price
   //--- is at least min_profit_per_volume, and keeps the rest. commission is
   //--- charged per volume of the closed positions only.
   bool              CloseProfitableAtLeast(const double price,
                                            const double min_profit_per_volume,
                                            const double commission_per_volume,
                                            string &error,double &realized_delta,
                                            int &closed_count)
     {
      realized_delta=0.0;
      closed_count=0;
      if(!m_initialized)
        {
         error="portfolio_not_initialized";
         return(false);
        }
      if(!SimValidatePrice(price,error))
         return(false);
      if(!SimValidateCommission(commission_per_volume,error))
         return(false);
      if(!SimIsFinite(min_profit_per_volume))
        {
         error="min_profit_must_be_finite";
         return(false);
        }

      const int count=ArraySize(m_positions);
      if(count<=0)
        {
         error="no_open_positions";
         return(false);
        }

      SimPosition keep[];
      double gross=0.0;
      double closed_volume=0.0;
      for(int i=0; i<count; i++)
        {
         const double profit=(int)m_positions[i].side*(price-m_positions[i].entry);
         if(profit>=min_profit_per_volume)
           {
            gross+=profit*m_positions[i].volume;
            closed_volume+=m_positions[i].volume;
            closed_count++;
           }
         else
           {
            const int k=ArraySize(keep);
            if(ArrayResize(keep,k+1)!=k+1)
              {
               error="portfolio_resize_failed";
               return(false);
              }
            keep[k]=m_positions[i];
           }
        }
      if(closed_count<=0)
        {
         error="no_matching_positions";
         return(false);
        }

      const int keep_count=ArraySize(keep);
      if(ArrayResize(m_positions,keep_count)!=keep_count)
        {
         error="portfolio_resize_failed";
         return(false);
        }
      if(keep_count>0)
        {
         if(ArrayCopy(m_positions,keep,0,0,keep_count)!=keep_count)
           {
            error="portfolio_copy_failed";
            return(false);
           }
        }

      realized_delta=gross-commission_per_volume*closed_volume;
      m_realized+=realized_delta;
      m_balance=m_initial_balance+m_realized;
      UpdatePeak(m_balance+UnrealizedPnl(price));
      error="";
      return(true);
     }

   bool              Snapshot(const double price,SimPortfolioSnapshot &out)
     {
      out.initialized=m_initialized;
      out.open_positions=OpenPositions();
      out.net_volume=NetVolume();
      out.exposure=Exposure();
      out.average_entry=AverageEntry();
      out.unrealized_pnl=UnrealizedPnl(price);
      out.balance=m_balance;
      out.realized_pnl=m_realized;
      out.equity=(m_initialized ? Equity(price) : 0.0);
      out.peak_equity=m_peak_equity;
      out.max_drawdown_pct=m_max_drawdown_pct;
      return(m_initialized);
     }
  };

#endif // SIM_PORTFOLIO_MQH
