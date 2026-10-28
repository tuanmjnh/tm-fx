//+------------------------------------------------------------------+
//|                                                 SimRiskGuard.mqh |
//|        MT5 EA Lab - shared hard caps for simulated strategies     |
//|                                                                  |
//| The guard only decides. It never opens, closes or modifies a      |
//| position and never touches account, order or broker APIs.         |
//| Percent limits are evaluated on simulated equity and 0 disables   |
//| the corresponding limit. Daily loss and drawdown breaches always  |
//| halt the guard; other caps halt only when halt_on_breach is true. |
//+------------------------------------------------------------------+
#ifndef SIM_RISK_GUARD_MQH
#define SIM_RISK_GUARD_MQH

#include "SimTypes.mqh"
#include "SimValidate.mqh"

enum ENUM_SIM_RISK_STATE
  {
   SIM_RISK_ACTIVE  = 0,
   SIM_RISK_BLOCKED = 1,
   SIM_RISK_HALTED  = 2
  };

string SimRiskStateName(const ENUM_SIM_RISK_STATE state)
  {
   switch(state)
     {
      case SIM_RISK_ACTIVE:  return("ACTIVE");
      case SIM_RISK_BLOCKED: return("BLOCKED");
      case SIM_RISK_HALTED:  return("HALTED");
      default:               return("UNKNOWN");
     }
  }

struct SimRiskLimits
  {
   double            max_spread_points;
   int               max_virtual_positions;
   int               max_grid_levels;      // 0 = grid not used by this EA
   int               max_dca_adds;         // 0 = check disabled; the DCA EA blocks adds itself
   double            max_virtual_exposure; // 0 = disabled
   double            max_daily_loss_pct;   // 0 = disabled
   double            max_drawdown_pct;     // 0 = disabled
   int               cooldown_bars;
   bool              require_valid_price;
   bool              kill_switch;
   bool              halt_on_breach;
  };

SimRiskLimits SimRiskLimitsDefault(void)
  {
   SimRiskLimits l;
   l.max_spread_points=50.0;
   l.max_virtual_positions=1;
   l.max_grid_levels=0;
   l.max_dca_adds=0;
   l.max_virtual_exposure=1.0;
   l.max_daily_loss_pct=2.0;
   l.max_drawdown_pct=5.0;
   l.cooldown_bars=0;
   l.require_valid_price=true;
   l.kill_switch=false;
   l.halt_on_breach=false;
   return(l);
  }

struct SimRiskContext
  {
   double            spread_points;
   bool              price_valid;
   int               open_positions;
   int               grid_levels;
   int               dca_adds;
   double            exposure;           // existing virtual exposure
   double            volume_to_add;      // volume of the candidate entry
   double            equity;             // simulated equity now
   double            day_start_equity;   // simulated equity at day start
   double            peak_equity;        // simulated peak equity
   datetime          bar_time;           // bar of the candidate entry
  };

struct SimRiskDecision
  {
   bool              allowed;
   ENUM_SIM_RISK_STATE state;
   string            reason;
  };

struct SimRiskSnapshot
  {
   ENUM_SIM_RISK_STATE state;
   int               blocked_count;
   datetime          last_entry_bar;
   string            halt_reason;
  };

class CSimRiskGuard
  {
private:
   SimRiskLimits     m_limits;
   ENUM_SIM_RISK_STATE m_state;
   datetime          m_last_entry_bar;
   string            m_halt_reason;
   int               m_blocked_count;
   int               m_timeframe_seconds;
   bool              m_initialized;

   SimRiskDecision   Decision(const bool allowed,const ENUM_SIM_RISK_STATE state,
                              const string reason)
     {
      SimRiskDecision d;
      d.allowed=allowed;
      d.state=state;
      d.reason=reason;
      return(d);
     }

   SimRiskDecision   Allow(void)
     {
      return(Decision(true,SIM_RISK_ACTIVE,""));
     }

   SimRiskDecision   Block(const string reason)
     {
      m_blocked_count++;
      if(m_limits.halt_on_breach)
        {
         m_state=SIM_RISK_HALTED;
         m_halt_reason=reason;
         return(Decision(false,SIM_RISK_HALTED,reason));
        }
      return(Decision(false,SIM_RISK_BLOCKED,reason));
     }

   SimRiskDecision   Halt(const string reason)
     {
      m_blocked_count++;
      m_state=SIM_RISK_HALTED;
      m_halt_reason=reason;
      return(Decision(false,SIM_RISK_HALTED,reason));
     }

public:
                     CSimRiskGuard(void)
     {
      m_limits=SimRiskLimitsDefault();
      m_state=SIM_RISK_HALTED;
      m_last_entry_bar=0;
      m_halt_reason="risk_guard_not_initialized";
      m_blocked_count=0;
      m_timeframe_seconds=0;
      m_initialized=false;
     }

   bool              Init(const SimRiskLimits &limits,const int timeframe_seconds,
                          string &error)
     {
      if(!SimValidateSpreadPoints(limits.max_spread_points,error))
         return(false);
      if(!SimValidateCount(limits.max_virtual_positions,
                           "max_virtual_positions_must_be_non_negative",error))
         return(false);
      if(!SimValidateCount(limits.max_grid_levels,
                           "max_grid_levels_must_be_non_negative",error))
         return(false);
      if(!SimValidateCount(limits.max_dca_adds,
                           "max_dca_adds_must_be_non_negative",error))
         return(false);
      if(!SimValidateCount(limits.cooldown_bars,
                           "cooldown_bars_must_be_non_negative",error))
         return(false);
      if(!SimIsFinite(limits.max_virtual_exposure) || limits.max_virtual_exposure<0.0)
        {
         error="max_virtual_exposure_must_be_finite_non_negative";
         return(false);
        }
      if(!SimValidatePercent(limits.max_daily_loss_pct,error))
        {
         error="max_daily_loss_pct_must_be_between_0_and_100";
         return(false);
        }
      if(!SimValidatePercent(limits.max_drawdown_pct,error))
        {
         error="max_drawdown_pct_must_be_between_0_and_100";
         return(false);
        }
      if(timeframe_seconds<1)
        {
         error="timeframe_seconds_must_be_positive";
         return(false);
        }

      m_limits=limits;
      m_timeframe_seconds=timeframe_seconds;
      m_state=SIM_RISK_ACTIVE;
      m_last_entry_bar=0;
      m_halt_reason="";
      m_blocked_count=0;
      m_initialized=true;
      if(limits.kill_switch)
         ForceHalt("kill_switch_active");
      error="";
      return(true);
     }

   bool              IsInitialized(void) const
     {
      return(m_initialized);
     }

   SimRiskDecision   Evaluate(const SimRiskContext &ctx)
     {
      if(!m_initialized)
         return(Halt("risk_guard_not_initialized"));
      if(m_limits.kill_switch)
         return(Halt("kill_switch_active"));
      if(m_state==SIM_RISK_HALTED)
         return(Halt(m_halt_reason));

      if(m_limits.require_valid_price && !ctx.price_valid)
         return(Block("price_invalid"));

      //--- Hard halts: evaluated on simulated equity, independent of caps.
      if(m_limits.max_daily_loss_pct>0.0)
        {
         if(!SimIsFinite(ctx.day_start_equity) || ctx.day_start_equity<=0.0)
            return(Halt("day_start_equity_invalid"));
         const double loss_pct=(ctx.day_start_equity-ctx.equity)/
                               ctx.day_start_equity*100.0;
         if(loss_pct>=m_limits.max_daily_loss_pct)
            return(Halt("daily_loss_limit_reached"));
        }
      if(m_limits.max_drawdown_pct>0.0)
        {
         if(!SimIsFinite(ctx.peak_equity) || ctx.peak_equity<=0.0)
            return(Halt("peak_equity_invalid"));
         const double drawdown_pct=(ctx.peak_equity-ctx.equity)/
                                   ctx.peak_equity*100.0;
         if(drawdown_pct>=m_limits.max_drawdown_pct)
            return(Halt("max_drawdown_reached"));
        }

      if(m_limits.max_spread_points>0.0 &&
         ctx.spread_points>m_limits.max_spread_points)
         return(Block("spread_exceeded"));

      if(m_limits.cooldown_bars>0 && m_last_entry_bar>0)
        {
         const long elapsed=(long)(ctx.bar_time-m_last_entry_bar);
         const long required=(long)m_limits.cooldown_bars*
                             (long)m_timeframe_seconds;
         if(elapsed<required)
            return(Block("cooldown_active"));
        }

      if(ctx.open_positions>=m_limits.max_virtual_positions)
         return(Block("max_virtual_positions_reached"));
      if(m_limits.max_grid_levels>0 &&
         ctx.grid_levels>=m_limits.max_grid_levels)
         return(Block("max_grid_levels_reached"));
      if(m_limits.max_dca_adds>0 &&
         ctx.dca_adds>=m_limits.max_dca_adds)
         return(Block("max_dca_adds_reached"));

      if(m_limits.max_virtual_exposure>0.0)
        {
         if(!SimIsFinite(ctx.volume_to_add) || ctx.volume_to_add<=0.0)
            return(Block("volume_to_add_invalid"));
         if(!SimIsFinite(ctx.exposure) || ctx.exposure<0.0)
            return(Block("exposure_invalid"));
         if(ctx.exposure+ctx.volume_to_add>m_limits.max_virtual_exposure)
            return(Block("max_virtual_exposure_reached"));
        }

      return(Allow());
     }

   void              RecordEntry(const datetime bar_time)
     {
      m_last_entry_bar=bar_time;
     }

   void              ForceHalt(const string reason)
     {
      m_state=SIM_RISK_HALTED;
      m_halt_reason=reason;
     }

   //--- Disabling the switch does not resume a halted guard; call Reset.
   void              SetKillSwitch(const bool enabled)
     {
      m_limits.kill_switch=enabled;
      if(enabled)
         ForceHalt("kill_switch_active");
     }

   void              Reset(void)
     {
      m_state=(m_initialized ? SIM_RISK_ACTIVE : SIM_RISK_HALTED);
      m_last_entry_bar=0;
      m_halt_reason=(m_initialized ? "" : "risk_guard_not_initialized");
      m_blocked_count=0;
     }

   ENUM_SIM_RISK_STATE State(void) const
     {
      return(m_state);
     }

   string            HaltReason(void) const
     {
      return(m_halt_reason);
     }

   int               BlockedCount(void) const
     {
      return(m_blocked_count);
     }

   SimRiskLimits     Limits(void) const
     {
      return(m_limits);
     }

   void              Snapshot(SimRiskSnapshot &out) const
     {
      out.state=m_state;
      out.blocked_count=m_blocked_count;
      out.last_entry_bar=m_last_entry_bar;
      out.halt_reason=m_halt_reason;
     }

   //--- Canonical text for the config fingerprint.
   string            Fingerprint(void) const
     {
      return(SimFormatFingerprintPart("risk.spread",m_limits.max_spread_points,4)+
             SimFormatFingerprintPartInt("risk.positions",
                                         m_limits.max_virtual_positions)+
             SimFormatFingerprintPartInt("risk.grid",m_limits.max_grid_levels)+
             SimFormatFingerprintPartInt("risk.dca",m_limits.max_dca_adds)+
             SimFormatFingerprintPart("risk.exposure",
                                      m_limits.max_virtual_exposure,4)+
             SimFormatFingerprintPart("risk.daily_loss",
                                      m_limits.max_daily_loss_pct,4)+
             SimFormatFingerprintPart("risk.drawdown",
                                      m_limits.max_drawdown_pct,4)+
             SimFormatFingerprintPartInt("risk.cooldown",m_limits.cooldown_bars)+
             SimFormatFingerprintPartInt("risk.require_price",
                                         (m_limits.require_valid_price ? 1 : 0))+
             SimFormatFingerprintPartInt("risk.halt_on_breach",
                                         (m_limits.halt_on_breach ? 1 : 0))+
             SimFormatFingerprintPartInt("risk.tf_seconds",m_timeframe_seconds));
     }
  };

#endif // SIM_RISK_GUARD_MQH
