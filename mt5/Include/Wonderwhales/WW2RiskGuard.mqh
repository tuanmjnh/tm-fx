//+------------------------------------------------------------------+
//|                                                 WW2RiskGuard.mqh |
//|   Daily / weekly / drawdown / streak risk ledger for the 2-mode   |
//|   EA.                                                             |
//|                                                                  |
//| The caller passes equity and time in; the guard holds no account  |
//| reference and never calls a trading function. Weekly loss has no   |
//| equivalent in SimRiskGuard, so it is budgeted here.               |
//+------------------------------------------------------------------+
#ifndef WW2_RISK_GUARD_MQH
#define WW2_RISK_GUARD_MQH

class CWw2RiskGuard
  {
private:
   double            m_daily_pct;
   double            m_weekly_pct;
   double            m_dd_pct;
   int               m_max_losses;
   int               m_cooldown_minutes;

   double            m_peak_equity;
   double            m_day_start_equity;
   double            m_week_start_equity;
   long              m_day_key;
   long              m_week_key;
   int               m_streak_losses;
   datetime          m_block_until;
   bool              m_halted;
   string            m_halt_reason;
   bool              m_initialized;

   long DayKey(const datetime now) const
     {
      MqlDateTime dt;
      TimeToStruct(now,dt);
      return((long)dt.year*10000+(long)dt.mon*100+(long)dt.day);
     }

   long WeekKey(const datetime now) const
     {
      MqlDateTime dt;
      TimeToStruct(now,dt);
      //--- ISO-ish week bucket: year * 100 + week-of-year.
      return((long)dt.year*100+(long)((dt.day_of_year/7)+1));
     }

public:
   CWw2RiskGuard(void)
     {
      m_daily_pct=0.0;
      m_weekly_pct=0.0;
      m_dd_pct=0.0;
      m_max_losses=0;
      m_cooldown_minutes=0;
      m_peak_equity=0.0;
      m_day_start_equity=0.0;
      m_week_start_equity=0.0;
      m_day_key=0;
      m_week_key=0;
      m_streak_losses=0;
      m_block_until=0;
      m_halted=false;
      m_halt_reason="";
      m_initialized=false;
     }

   bool Init(const double daily_pct,const double weekly_pct,const double dd_pct,
             const int max_losses,const int cooldown_minutes,string &error)
     {
      error="";
      if(daily_pct<0.0 || daily_pct>100.0)
        {
         error="daily_pct_out_of_range";
         return(false);
        }
      if(weekly_pct<0.0 || weekly_pct>100.0)
        {
         error="weekly_pct_out_of_range";
         return(false);
        }
      if(dd_pct<0.0 || dd_pct>100.0)
        {
         error="dd_pct_out_of_range";
         return(false);
        }
      if(max_losses<0 || cooldown_minutes<0)
        {
         error="loss_limits_negative";
         return(false);
        }
      m_daily_pct=daily_pct;
      m_weekly_pct=weekly_pct;
      m_dd_pct=dd_pct;
      m_max_losses=max_losses;
      m_cooldown_minutes=cooldown_minutes;
      m_initialized=true;
      return(true);
     }

   bool Initialized(void) const { return(m_initialized); }

   double DrawdownPct(void) const
     {
      if(!(m_peak_equity>0.0))
         return(0.0);
      //--- The caller refreshes peak with the live equity, so the current
      //--- equity is 0 here unless the last Refresh lowered it.
      return(0.0);
     }

   double DailyLossPct(const double equity) const
     {
      if(!(m_day_start_equity>0.0) || equity>=m_day_start_equity)
         return(0.0);
      return((m_day_start_equity-equity)/m_day_start_equity*100.0);
     }

   double WeeklyLossPct(const double equity) const
     {
      if(!(m_week_start_equity>0.0) || equity>=m_week_start_equity)
         return(0.0);
      return((m_week_start_equity-equity)/m_week_start_equity*100.0);
     }

   double PeakEquity(void) const { return(m_peak_equity); }
   double DayStartEquity(void) const { return(m_day_start_equity); }
   double WeekStartEquity(void) const { return(m_week_start_equity); }
   long DayKeyValue(void) const { return(m_day_key); }
   long WeekKeyValue(void) const { return(m_week_key); }
   int StreakLosses(void) const { return(m_streak_losses); }
   bool Halted(string &reason) const
     {
      reason=m_halt_reason;
      return(m_halted);
     }

   //--- Update peak equity, roll the day/week budget and raise a halt when a
   //--- loss cap is breached. Returns true when a NEW halt was raised.
   bool Refresh(const double equity,const datetime now,string &reason)
     {
      reason="";
      if(!m_initialized)
         return(false);
      if(equity>m_peak_equity)
         m_peak_equity=equity;

      const long dk=DayKey(now);
      if(dk!=m_day_key)
        {
         m_day_key=dk;
         m_day_start_equity=equity;
         if(m_halted && StringFind(m_halt_reason,"daily_loss_limit_reached")==0)
           {
            m_halted=false;
            m_halt_reason="";
           }
        }
      const long wk=WeekKey(now);
      if(wk!=m_week_key)
        {
         m_week_key=wk;
         m_week_start_equity=equity;
         if(m_halted && StringFind(m_halt_reason,"weekly_loss_limit_reached")==0)
           {
            m_halted=false;
            m_halt_reason="";
           }
        }
      if(m_day_start_equity<=0.0)
         m_day_start_equity=equity;
      if(m_week_start_equity<=0.0)
         m_week_start_equity=equity;

      if(!m_halted && m_daily_pct>0.0 && DailyLossPct(equity)>=m_daily_pct)
        {
         m_halted=true;
         m_halt_reason=StringFormat("daily_loss_limit_reached|loss=%.2f%%",
                                    DailyLossPct(equity));
         reason=m_halt_reason;
         return(true);
        }
      if(!m_halted && m_weekly_pct>0.0 && WeeklyLossPct(equity)>=m_weekly_pct)
        {
         m_halted=true;
         m_halt_reason=StringFormat("weekly_loss_limit_reached|loss=%.2f%%",
                                    WeeklyLossPct(equity));
         reason=m_halt_reason;
         return(true);
        }
      if(!m_halted && m_dd_pct>0.0 && m_peak_equity>0.0 &&
         (m_peak_equity-equity)/m_peak_equity*100.0>=m_dd_pct)
        {
         m_halted=true;
         m_halt_reason=StringFormat("max_drawdown_reached|dd=%.2f%%",
                                    (m_peak_equity-equity)/m_peak_equity*100.0);
         reason=m_halt_reason;
         return(true);
        }
      return(false);
     }

   bool EntryAllowed(const datetime now,const double spread_points,
                     const double sl_points,const double max_spread_points,
                     const double max_spread_ratio_pct,string &reason)
     {
      reason="";
      if(m_halted)
        {
         reason="halted|"+m_halt_reason;
         return(false);
        }
      if(m_block_until>now)
        {
         reason=StringFormat("consecutive_loss_cooldown|until=%s",
                             TimeToString(m_block_until));
         return(false);
        }
      if(max_spread_points>0.0 && spread_points>max_spread_points)
        {
         reason=StringFormat("spread_exceeded|spread=%.1f|max=%.1f",
                             spread_points,max_spread_points);
         return(false);
        }
      if(max_spread_ratio_pct>0.0 && sl_points>0.0 &&
         (spread_points/sl_points*100.0)>max_spread_ratio_pct)
        {
         reason=StringFormat("spread_over_sl|ratio=%.2f%%|max=%.2f%%",
                             spread_points/sl_points*100.0,max_spread_ratio_pct);
         return(false);
        }
      return(true);
     }

   void RecordEntry(const datetime now)
     {
      //--- Reserved for future exposure accounting; kept for symmetry with
      //--- the close path.
     }

   void RecordClosed(const double pnl_money,const datetime now)
     {
      if(pnl_money<0.0)
        {
         m_streak_losses++;
         if(m_max_losses>0 && m_streak_losses>=m_max_losses &&
            m_cooldown_minutes>0)
            m_block_until=now+m_cooldown_minutes*60;
        }
      else if(pnl_money>0.0)
        {
         m_streak_losses=0;
         m_block_until=0;
        }
     }

   void ForceHalt(const string reason)
     {
      if(m_halted)
         return;
      m_halted=true;
      m_halt_reason=reason;
     }

   void Reset(void)
     {
      m_peak_equity=0.0;
      m_day_start_equity=0.0;
      m_week_start_equity=0.0;
      m_day_key=0;
      m_week_key=0;
      m_streak_losses=0;
      m_block_until=0;
      m_halted=false;
      m_halt_reason="";
     }

   string Fingerprint(void) const
     {
      return(StringFormat("ww2risk.daily=%.2f|weekly=%.2f|dd=%.2f|losses=%d|cool=%d",
                          m_daily_pct,m_weekly_pct,m_dd_pct,m_max_losses,
                          m_cooldown_minutes));
     }

   void Save(string &out)
     {
      out="";
      out+=StringFormat("risk_peak_equity=%.8f\r\n",m_peak_equity);
      out+=StringFormat("risk_day_start_equity=%.8f\r\n",m_day_start_equity);
      out+=StringFormat("risk_week_start_equity=%.8f\r\n",m_week_start_equity);
      out+="risk_day_key="+IntegerToString(m_day_key)+"\r\n";
      out+="risk_week_key="+IntegerToString(m_week_key)+"\r\n";
      out+="risk_streak_losses="+IntegerToString(m_streak_losses)+"\r\n";
      out+="risk_block_until="+IntegerToString((long)m_block_until)+"\r\n";
      out+="risk_halted="+string(m_halted ? "1" : "0")+"\r\n";
      out+="risk_halt_reason="+m_halt_reason+"\r\n";
     }

   //--- Parses only its own keys from a state text; returns true when the
   //--- risk section was present.
   bool Load(const string &text)
     {
      bool seen=false;
      int start=0;
      const int len=StringLen(text);
      while(start<len)
        {
         int nl=StringFind(text,"\n",start);
         if(nl<0)
            nl=len;
         string line=StringSubstr(text,start,nl-start);
         StringReplace(line,"\r","");
         const int eq=StringFind(line,"=");
         if(eq>0)
           {
            const string key=StringSubstr(line,0,eq);
            const string value=StringSubstr(line,eq+1);
            if(key=="risk_peak_equity")
              {
               m_peak_equity=StringToDouble(value);
               seen=true;
              }
            else if(key=="risk_day_start_equity")
               m_day_start_equity=StringToDouble(value);
            else if(key=="risk_week_start_equity")
               m_week_start_equity=StringToDouble(value);
            else if(key=="risk_day_key")
               m_day_key=StringToInteger(value);
            else if(key=="risk_week_key")
               m_week_key=StringToInteger(value);
            else if(key=="risk_streak_losses")
               m_streak_losses=(int)StringToInteger(value);
            else if(key=="risk_block_until")
               m_block_until=(datetime)StringToInteger(value);
            else if(key=="risk_halted")
               m_halted=(value=="1");
            else if(key=="risk_halt_reason")
               m_halt_reason=value;
           }
         start=nl+1;
        }
      return(seen);
     }
  };

#endif
//+------------------------------------------------------------------+
