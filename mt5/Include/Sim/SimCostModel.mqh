//+------------------------------------------------------------------+
//|                                                 SimCostModel.mqh |
//|        MT5 EA Lab - explicit simulation cost assumptions          |
//|                                                                  |
//| All costs are modelled, not observed. No account, broker or       |
//| trading API is used. Spread and slippage are expressed in points; |
//| commission and swap are amounts in account currency.              |
//+------------------------------------------------------------------+
#ifndef SIM_COST_MODEL_MQH
#define SIM_COST_MODEL_MQH

#include "SimTypes.mqh"
#include "SimValidate.mqh"

struct SimCostAssumptions
  {
   double            point;                  // price units per point
   double            commission_per_volume;  // account currency per 1.0 volume per fill
   double            slippage_points;        // adverse points applied to every fill
   double            swap_per_volume_day;    // signed: negative = debit, positive = credit
  };

SimCostAssumptions SimCostAssumptionsDefault(void)
  {
   SimCostAssumptions a;
   a.point=0.00001;
   a.commission_per_volume=0.0;
   a.slippage_points=0.0;
   a.swap_per_volume_day=0.0;
   return(a);
  }

class CSimCostModel
  {
private:
   SimCostAssumptions m_assumptions;
   bool              m_initialized;

public:
                     CSimCostModel(void)
     {
      m_assumptions=SimCostAssumptionsDefault();
      m_initialized=false;
     }

   bool              Init(const SimCostAssumptions &assumptions,string &error)
     {
      if(!SimValidatePoint(assumptions.point,error))
        {
         m_initialized=false;
         return(false);
        }
      if(!SimValidateCommission(assumptions.commission_per_volume,error))
        {
         m_initialized=false;
         return(false);
        }
      if(!SimValidateSlippagePoints(assumptions.slippage_points,error))
        {
         m_initialized=false;
         return(false);
        }
      if(!SimValidateFinite(assumptions.swap_per_volume_day,
                            "swap_must_be_finite",error))
        {
         m_initialized=false;
         return(false);
        }

      m_assumptions=assumptions;
      m_initialized=true;
      error="";
      return(true);
     }

   bool              IsInitialized(void) const
     {
      return(m_initialized);
     }

   void              Assumptions(SimCostAssumptions &out) const
     {
      out=m_assumptions;
     }

   double            Point(void) const
     {
      return(m_assumptions.point);
     }

   double            Commission(const double volume) const
     {
      if(!m_initialized || volume<=0.0)
         return(0.0);
      return(m_assumptions.commission_per_volume*volume);
     }

   double            SpreadPrice(const double spread_points) const
     {
      if(!m_initialized || spread_points<=0.0)
         return(0.0);
      return(spread_points*m_assumptions.point);
     }

   //--- Money value of the modelled spread for a fill.
   double            SpreadCost(const double volume,const double spread_points) const
     {
      if(!m_initialized || volume<=0.0)
         return(0.0);
      return(SpreadPrice(spread_points)*volume);
     }

   //--- Signed swap for holding volume for whole days.
   double            Swap(const double volume,const int days) const
     {
      if(!m_initialized || volume<=0.0 || days<=0)
         return(0.0);
      return(m_assumptions.swap_per_volume_day*(double)days*volume);
     }

   double            TotalCost(const double volume,const double spread_points,
                               const int swap_days) const
     {
      return(SpreadCost(volume,spread_points)+Commission(volume)+
             Swap(volume,swap_days));
     }

   //--- Adverse fill: BUY pays more, SELL receives less.
   //--- extra_points is caller-supplied (for example the observed spread).
   double            FillPrice(const ENUM_SIM_SIDE side,const double requested,
                               const double extra_points=0.0) const
     {
      if(!m_initialized || !SimIsFinite(requested) || requested<=0.0)
         return(0.0);
      if(side==SIM_SIDE_NONE)
         return(0.0);

      double adverse_points=m_assumptions.slippage_points;
      if(SimIsFinite(extra_points) && extra_points>0.0)
         adverse_points+=extra_points;

      const double offset=adverse_points*m_assumptions.point;
      if(side==SIM_SIDE_BUY)
         return(requested+offset);
      return(requested-offset);
     }

   //--- Canonical text for the config fingerprint.
   string            Fingerprint(void) const
     {
      return(SimFormatFingerprintPart("cost.point",m_assumptions.point,8)+
             SimFormatFingerprintPart("cost.commission",
                                      m_assumptions.commission_per_volume,6)+
             SimFormatFingerprintPart("cost.slippage",
                                      m_assumptions.slippage_points,4)+
             SimFormatFingerprintPart("cost.swap",
                                      m_assumptions.swap_per_volume_day,6));
     }
  };

#endif // SIM_COST_MODEL_MQH
