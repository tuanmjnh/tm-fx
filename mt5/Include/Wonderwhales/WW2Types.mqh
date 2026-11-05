//+------------------------------------------------------------------+
//|                                                     WW2Types.mqh |
//|   Wonderwhales XAU 2-mode EA - shared types and pure helpers.     |
//|                                                                  |
//| No file I/O, no account access, no trading functions.             |
//| Contract: docs/10-bots/Wonderwhales_XAU_EA_2Mode_Spec_Vietnamese.md|
//+------------------------------------------------------------------+
#ifndef WW2_TYPES_MQH
#define WW2_TYPES_MQH

//--- Trading mode of the whole bot. Scalp and Swing are strategies inside
//--- one bot; a position stores the mode it was opened with.
enum ENUM_WW2_MODE
  {
   WW2_SIGNAL_ONLY = 0,  // Signal only (no orders)
   WW2_SCALP       = 1,  // Scalp M15/M5/M1
   WW2_SWING       = 2   // Swing W1/D1/H1
  };

string Ww2ModeName(const ENUM_WW2_MODE mode)
  {
   if(mode==WW2_SCALP)
      return("SCALP");
   if(mode==WW2_SWING)
      return("SWING");
   return("SIGNAL_ONLY");
  }

//--- One closed bar of the PinePort\\Wonderwhales indicator as read by the
//--- EA. The EA never recomputes these values.
struct Ww2Signal
  {
   bool   valid;
   bool   buy;
   bool   sell;
   int    sar_dir;
   double psar;
   double atr_pct;
   double fast_ema;
   double slow_ema;
   double ema200;
   double open;
   double close;
  };

//--- The single guarded position this bot may hold, including the mode it
//--- was opened with (management must not follow the current input mode).
struct Ww2Position
  {
   bool           have;
   ulong          ticket;
   bool           is_buy;
   double         volume;
   double         entry;
   double         initial_sl;   // R anchor; never overwritten by a trailed stop
   double         initial_r;
   double         current_sl;   // live intended stop; updated by the trail
   double         tp;
   datetime       open_time;
   ENUM_WW2_MODE  mode;
  };

void Ww2ResetPosition(Ww2Position &pos)
  {
   pos.have=false;
   pos.ticket=0;
   pos.is_buy=true;
   pos.volume=0.0;
   pos.entry=0.0;
   pos.initial_sl=0.0;
   pos.initial_r=0.0;
   pos.current_sl=0.0;
   pos.tp=0.0;
   pos.open_time=0;
   pos.mode=WW2_SIGNAL_ONLY;
  }

double Ww2RiskDistance(const Ww2Position &pos)
  {
   return(MathAbs(pos.entry-pos.initial_sl));
  }

//--- Realized R of a closed trade: money P&L over the initial risk in money
//--- (price distance * volume * contract size). Returns false when the
//--- anchor is unknown (e.g. an adopted position) so callers can print NA
//--- instead of inventing a zero.
bool Ww2RealizedR(const double pnl,const double volume,const double initial_r,
                  const double contract_size,double &r)
  {
   r=0.0;
   const double risk_money=initial_r*volume*contract_size;
   if(!(risk_money>0.0))
      return(false);
   r=pnl/risk_money;
   return(true);
  }

//--- Current R of the position, always measured from the stored initial SL.
double Ww2CurrentR(const Ww2Position &pos,const bool is_buy,const double bid,
                   const double ask)
  {
   const double risk=Ww2RiskDistance(pos);
   if(!(risk>0.0))
      return(0.0);
   return(is_buy ? (bid-pos.entry)/risk : (pos.entry-ask)/risk);
  }

#endif
//+------------------------------------------------------------------+
