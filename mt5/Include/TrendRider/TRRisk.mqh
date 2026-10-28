//+------------------------------------------------------------------+
//|                                                       TRRisk.mqh |
//|      PA_TrendRider_XAU_V1 - sizing and account-level guards       |
//|                                                                  |
//| Sizing uses the symbol's tick size, tick value and volume step.   |
//| It never calls an account or order API: every input is explicit,  |
//| so the arithmetic can be reproduced in a contract test.           |
//+------------------------------------------------------------------+
#ifndef TR_RISK_MQH
#define TR_RISK_MQH

#include "TRTypes.mqh"
#include "TRConfig.mqh"

struct TRSymbolSpec
  {
   double            point;
   double            tick_size;
   double            tick_value;
   double            volume_min;
   double            volume_max;
   double            volume_step;
   double            contract_size;
   double            stops_level_points;
   double            freeze_level_points;
  };

struct TRLotDecision
  {
   bool              ok;
   double            volume;
   double            expected_loss;
   double            loss_per_lot;
   double            risk_money;
   string            reason;
  };

struct TRGuardDecision
  {
   bool              allowed;
   string            reason;
  };

double TRRiskMoney(const double equity,const double risk_percent)
  {
   if(!TRIsFinitePositive(equity) || !TRIsFinitePositive(risk_percent))
      return(0.0);
   return(equity*risk_percent/100.0);
  }

//--- Account-currency loss of one lot over the stop distance.
double TRLossPerLot(const TRSymbolSpec &spec,const double entry,
                    const double sl)
  {
   if(!TRIsFinitePositive(entry) || !TRIsFinitePositive(sl) ||
      !TRIsFinitePositive(spec.tick_size) || !TRIsFinitePositive(spec.tick_value))
      return(0.0);
   const double distance=MathAbs(entry-sl);
   if(distance<=0.0)
      return(0.0);
   return(distance/spec.tick_size*spec.tick_value);
  }

bool TRSymbolSpecValid(const TRSymbolSpec &spec,string &error)
  {
   error="";
   if(!TRIsFinitePositive(spec.point) || !TRIsFinitePositive(spec.tick_size) ||
      !TRIsFinitePositive(spec.tick_value))
     {
      error="symbol_tick_metrics_invalid";
      return(false);
     }
   if(!TRIsFinitePositive(spec.volume_min) ||
      !TRIsFinitePositive(spec.volume_max) ||
      !TRIsFinitePositive(spec.volume_step) ||
      spec.volume_min>spec.volume_max)
     {
      error="symbol_volume_limits_invalid";
      return(false);
     }
   if(!TRIsFinitePositive(spec.contract_size))
     {
      error="symbol_contract_size_invalid";
      return(false);
     }
   if(spec.stops_level_points<0.0 || spec.freeze_level_points<0.0)
     {
      error="symbol_stop_levels_invalid";
      return(false);
     }
   return(true);
  }

//--- risk_money / loss_per_lot, rounded down to the volume step. The
//--- round-trip commission is added to the per-lot loss, so the budget
//--- covers both fills. A minimum lot that breaches the budget is
//--- rejected rather than rounded up.
TRLotDecision TRCalcLot(const TRConfig &cfg,const TRSymbolSpec &spec,
                        const double equity,const double entry,
                        const double sl)
  {
   TRLotDecision decision;
   decision.ok=false;
   decision.volume=0.0;
   decision.expected_loss=0.0;
   decision.loss_per_lot=0.0;
   decision.risk_money=TRRiskMoney(equity,cfg.risk_percent);
   decision.reason="";

   string error="";
   if(!TRSymbolSpecValid(spec,error))
     {
      decision.reason=error;
      return(decision);
     }
   if(decision.risk_money<=0.0)
     {
      decision.reason="risk_budget_invalid";
      return(decision);
     }

   const double loss_per_lot=TRLossPerLot(spec,entry,sl);
   if(loss_per_lot<=0.0)
     {
      decision.reason="loss_per_lot_invalid";
      return(decision);
     }

   const double round_trip_commission=2.0*cfg.commission_per_volume;
   const double total_per_lot=loss_per_lot+round_trip_commission;
   decision.loss_per_lot=total_per_lot;

   const double raw=decision.risk_money/total_per_lot;
   double volume=MathFloor(raw/spec.volume_step+1e-9)*spec.volume_step;
   volume=NormalizeDouble(volume,8);

   if(volume>spec.volume_max)
      volume=NormalizeDouble(spec.volume_max,8);

   if(volume<spec.volume_min)
     {
      decision.reason="min_volume_exceeds_risk";
      return(decision);
     }

   const double expected=NormalizeDouble(volume*total_per_lot,8);
   if(expected>decision.risk_money*(1.0+1e-9))
     {
      decision.reason="expected_loss_exceeds_budget";
      return(decision);
     }

   decision.ok=true;
   decision.volume=volume;
   decision.expected_loss=expected;
   return(decision);
  }

//--- Stop distance must sit inside the configured ATR band and outside
//--- the broker's minimum stop level (points).
bool TRStopDistanceValid(const TRConfig &cfg,const TRSymbolSpec &spec,
                         const double entry,const double sl,
                         const double atr,string &reason)
  {
   reason="";
   if(!TRIsFinitePositive(entry) || !TRIsFinitePositive(sl) ||
      !TRIsFinitePositive(atr))
     {
      reason="stop_inputs_invalid";
      return(false);
     }
   const double distance=MathAbs(entry-sl);
   if(distance<=0.0)
     {
      reason="stop_distance_zero";
      return(false);
     }
   if(distance<cfg.min_sl_atr*atr)
     {
      reason="stop_too_tight";
      return(false);
     }
   if(distance>cfg.max_sl_atr*atr)
     {
      reason="stop_too_wide";
      return(false);
     }
   if(spec.stops_level_points>0.0 &&
      distance/spec.point<spec.stops_level_points)
     {
      reason="stop_below_broker_level";
      return(false);
     }
   return(true);
  }

long TRDayKey(const datetime now)
  {
   MqlDateTime dt;
   TimeToStruct(now,dt);
   return((long)dt.year*10000+(long)dt.mon*100+(long)dt.day);
  }

bool TRDailyLocked(const double equity,const double day_start_equity,
                   const double limit_pct)
  {
   if(limit_pct<=0.0 || !TRIsFinitePositive(day_start_equity))
      return(false);
   if(!MathIsValidNumber(equity))
      return(true);
   return(equity<=day_start_equity*(1.0-limit_pct/100.0));
  }

bool TRDrawdownLocked(const double equity,const double peak_equity,
                      const double limit_pct)
  {
   if(limit_pct<=0.0 || !TRIsFinitePositive(peak_equity))
      return(false);
   if(!MathIsValidNumber(equity))
      return(true);
   return(equity<=peak_equity*(1.0-limit_pct/100.0));
  }

bool TRStreakLocked(const int consecutive_losses,const int max_losses)
  {
   if(max_losses<=0)
      return(false);
   return(consecutive_losses>=max_losses);
  }

bool TRCooldownActive(const datetime now,const datetime cooldown_until)
  {
   if(cooldown_until<=0)
      return(false);
   return(now<cooldown_until);
  }

//--- Persistent account-level ledger. Daily lock resets on the next
//--- server day; the drawdown lock is sticky until a manual reset.
class TRRiskLedger
  {
private:
   long              m_day_key;
   double            m_day_start_equity;
   double            m_peak_equity;
   int               m_consecutive_losses;
   datetime          m_cooldown_until;
   bool              m_drawdown_locked;
   bool              m_initialized;
   int               m_daily_blocks;
   int               m_drawdown_blocks;
   int               m_cooldown_blocks;

   void              Reset(void)
     {
      m_day_key=0;
      m_day_start_equity=0.0;
      m_peak_equity=0.0;
      m_consecutive_losses=0;
      m_cooldown_until=0;
      m_drawdown_locked=false;
      m_initialized=false;
      m_daily_blocks=0;
      m_drawdown_blocks=0;
      m_cooldown_blocks=0;
     }

public:
   TRRiskLedger(void) { Reset(); }

   bool Init(const double equity,const datetime now)
     {
      Reset();
      if(!TRIsFinitePositive(equity))
         return(false);
      m_day_key=TRDayKey(now);
      m_day_start_equity=equity;
      m_peak_equity=equity;
      m_initialized=true;
      return(true);
     }

   bool IsInitialized(void) const { return(m_initialized); }
   double DayStartEquity(void) const { return(m_day_start_equity); }
   double PeakEquity(void) const { return(m_peak_equity); }
   int ConsecutiveLosses(void) const { return(m_consecutive_losses); }
   datetime CooldownUntil(void) const { return(m_cooldown_until); }
   bool DrawdownLockedFlag(void) const { return(m_drawdown_locked); }
   int DailyBlocks(void) const { return(m_daily_blocks); }
   int DrawdownBlocks(void) const { return(m_drawdown_blocks); }
   int CooldownBlocks(void) const { return(m_cooldown_blocks); }

   //--- Rolls the day at the server midnight and tracks the equity peak.
   void UpdateEquity(const double equity,const datetime now,const TRConfig &cfg)
     {
      if(!m_initialized || !MathIsValidNumber(equity) || equity<=0.0)
         return;
      const long key=TRDayKey(now);
      if(key!=m_day_key)
        {
         m_day_key=key;
         m_day_start_equity=equity;
        }
      if(equity>m_peak_equity)
         m_peak_equity=equity;
      if(!m_drawdown_locked &&
         TRDrawdownLocked(equity,m_peak_equity,cfg.max_drawdown_pct))
         m_drawdown_locked=true;
     }

   //--- Called once per fully closed trade with net P/L.
   void OnTradeClosed(const double net_pnl,const datetime now,const TRConfig &cfg)
     {
      if(!m_initialized)
         return;
      if(net_pnl<0.0)
        {
         m_consecutive_losses++;
         if(TRStreakLocked(m_consecutive_losses,cfg.max_consecutive_losses))
            m_cooldown_until=now+(datetime)(cfg.cooldown_minutes*60);
        }
      else if(net_pnl>0.0)
        {
         m_consecutive_losses=0;
         m_cooldown_until=0;
        }
     }

   TRGuardDecision EntryBlock(const double equity,const datetime now,
                              const TRConfig &cfg)
     {
      TRGuardDecision decision;
      decision.allowed=false;
      decision.reason="";

      if(!m_initialized)
        {
         decision.reason="ledger_not_initialized";
         return(decision);
        }
      if(m_drawdown_locked)
        {
         m_drawdown_blocks++;
         decision.reason="drawdown_locked";
         return(decision);
        }
      if(TRDailyLocked(equity,m_day_start_equity,cfg.daily_loss_limit_pct))
        {
         m_daily_blocks++;
         decision.reason="daily_loss_lock";
         return(decision);
        }
      if(TRCooldownActive(now,m_cooldown_until))
        {
         m_cooldown_blocks++;
         decision.reason="cooldown";
         return(decision);
        }
      if(m_cooldown_until>0 && now>=m_cooldown_until)
        {
         m_cooldown_until=0;
         m_consecutive_losses=0;
        }
      decision.allowed=true;
      return(decision);
     }

   //--- Explicit operator action after reviewing a drawdown lock.
   void ManualResetDrawdown(const double equity)
     {
      m_drawdown_locked=false;
      if(TRIsFinitePositive(equity))
         m_peak_equity=equity;
     }

   string Serialize(void) const
     {
      return(StringFormat("day_key=%I64d;day_start=%.8f;peak=%.8f;"+
                          "streak=%d;cooldown_until=%I64d;dd_locked=%d",
                          m_day_key,m_day_start_equity,m_peak_equity,
                          m_consecutive_losses,(long)m_cooldown_until,
                          (m_drawdown_locked ? 1 : 0)));
     }

   bool Deserialize(const string text)
     {
      if(StringLen(text)==0)
         return(false);
      string parts[];
      const int count=StringSplit(text,';',parts);
      if(count<6)
         return(false);

      long day_key=0;
      double day_start=0.0;
      double peak=0.0;
      int streak=0;
      long cooldown=0;
      int locked=0;
      bool have_day=false,have_start=false,have_peak=false;
      bool have_streak=false,have_cooldown=false,have_locked=false;

      for(int i=0; i<count; i++)
        {
         string pair[];
         if(StringSplit(parts[i],'=',pair)!=2)
            continue;
         const string key=pair[0];
         if(key=="day_key")
           {
            day_key=(long)StringToInteger(pair[1]);
            have_day=true;
           }
         else if(key=="day_start")
           {
            day_start=StringToDouble(pair[1]);
            have_start=true;
           }
         else if(key=="peak")
           {
            peak=StringToDouble(pair[1]);
            have_peak=true;
           }
         else if(key=="streak")
           {
            streak=(int)StringToInteger(pair[1]);
            have_streak=true;
           }
         else if(key=="cooldown_until")
           {
            cooldown=(long)StringToInteger(pair[1]);
            have_cooldown=true;
           }
         else if(key=="dd_locked")
           {
            locked=(int)StringToInteger(pair[1]);
            have_locked=true;
           }
        }

      if(!have_day || !have_start || !have_peak || !have_streak ||
         !have_cooldown || !have_locked)
         return(false);
      if(!TRIsFinitePositive(day_start) || !TRIsFinitePositive(peak))
         return(false);
      if(streak<0 || cooldown<0)
         return(false);

      m_day_key=day_key;
      m_day_start_equity=day_start;
      m_peak_equity=peak;
      m_consecutive_losses=streak;
      m_cooldown_until=(datetime)cooldown;
      m_drawdown_locked=(locked!=0);
      m_initialized=true;
      return(true);
     }
  };

#endif // TR_RISK_MQH
