//+------------------------------------------------------------------+
//|                                                       TRState.mqh |
//|      PA_TrendRider_XAU_V1 - EA state machine and persistence      |
//|                                                                  |
//| Protective states (daily lock, drawdown lock, safe mode) can only |
//| be left through explicit transitions, never by an entry signal.   |
//+------------------------------------------------------------------+
#ifndef TR_STATE_MQH
#define TR_STATE_MQH

#include "TRTypes.mqh"

class TRStateMachine
  {
private:
   ENUM_TR_STATE     m_state;
   int               m_transition_count;

   bool              IsAllowed(const ENUM_TR_STATE from,const ENUM_TR_STATE to) const
     {
      if(from==to)
         return(true);
      switch(from)
        {
         case TR_STATE_INITIALIZING:
            return(to==TR_STATE_READY || to==TR_STATE_ERROR_SAFE_MODE);
         case TR_STATE_READY:
            return(to==TR_STATE_WAITING_FOR_SETUP || to==TR_STATE_DAILY_LOCKED ||
                   to==TR_STATE_DRAWDOWN_LOCKED || to==TR_STATE_COOLDOWN ||
                   to==TR_STATE_ERROR_SAFE_MODE);
         case TR_STATE_WAITING_FOR_SETUP:
            return(to==TR_STATE_ENTRY_REQUESTED || to==TR_STATE_REVERSAL_WATCH ||
                   to==TR_STATE_COOLDOWN || to==TR_STATE_DAILY_LOCKED ||
                   to==TR_STATE_DRAWDOWN_LOCKED || to==TR_STATE_ERROR_SAFE_MODE);
         case TR_STATE_ENTRY_REQUESTED:
            return(to==TR_STATE_POSITION_OPEN || to==TR_STATE_WAITING_FOR_SETUP ||
                   to==TR_STATE_ERROR_SAFE_MODE);
         case TR_STATE_POSITION_OPEN:
            return(to==TR_STATE_REVERSAL_WATCH || to==TR_STATE_CLOSE_FOR_REVERSAL ||
                   to==TR_STATE_WAITING_FOR_SETUP || to==TR_STATE_COOLDOWN ||
                   to==TR_STATE_DAILY_LOCKED || to==TR_STATE_DRAWDOWN_LOCKED ||
                   to==TR_STATE_ERROR_SAFE_MODE);
         case TR_STATE_REVERSAL_WATCH:
            return(to==TR_STATE_CLOSE_FOR_REVERSAL || to==TR_STATE_WAITING_FOR_SETUP ||
                   to==TR_STATE_COOLDOWN || to==TR_STATE_DAILY_LOCKED ||
                   to==TR_STATE_DRAWDOWN_LOCKED || to==TR_STATE_ERROR_SAFE_MODE);
         case TR_STATE_CLOSE_FOR_REVERSAL:
            return(to==TR_STATE_WAITING_FOR_SETUP || to==TR_STATE_REVERSAL_WATCH ||
                   to==TR_STATE_ERROR_SAFE_MODE);
         case TR_STATE_COOLDOWN:
            return(to==TR_STATE_WAITING_FOR_SETUP || to==TR_STATE_DAILY_LOCKED ||
                   to==TR_STATE_DRAWDOWN_LOCKED || to==TR_STATE_ERROR_SAFE_MODE);
         case TR_STATE_DAILY_LOCKED:
            return(to==TR_STATE_WAITING_FOR_SETUP || to==TR_STATE_DRAWDOWN_LOCKED ||
                   to==TR_STATE_ERROR_SAFE_MODE);
         case TR_STATE_DRAWDOWN_LOCKED:
            return(to==TR_STATE_READY || to==TR_STATE_WAITING_FOR_SETUP ||
                   to==TR_STATE_ERROR_SAFE_MODE);
         case TR_STATE_ERROR_SAFE_MODE:
            return(to==TR_STATE_READY);
         default:
            return(false);
        }
     }

public:
   TRStateMachine(void)
     {
      m_state=TR_STATE_INITIALIZING;
      m_transition_count=0;
     }

   ENUM_TR_STATE State(void) const { return(m_state); }
   int TransitionCount(void) const { return(m_transition_count); }

   bool Transition(const ENUM_TR_STATE next,string &error)
     {
      error="";
      if(!IsAllowed(m_state,next))
        {
         error="invalid_transition|from="+TRStateName(m_state)+
               "|to="+TRStateName(next);
         return(false);
        }
      if(next!=m_state)
        {
         m_state=next;
         m_transition_count++;
        }
      return(true);
     }

   //--- Used after a manual drawdown reset; starts a fresh wait state.
   bool ManualReset(string &error)
     {
      if(m_state==TR_STATE_DRAWDOWN_LOCKED || m_state==TR_STATE_ERROR_SAFE_MODE)
        {
         m_state=TR_STATE_WAITING_FOR_SETUP;
         m_transition_count++;
         error="";
         return(true);
        }
      error="manual_reset_not_applicable|state="+TRStateName(m_state);
      return(false);
     }

   string Serialize(void) const
     {
      return("state="+TRStateName(m_state)+";transitions="+
             IntegerToString(m_transition_count));
     }

   bool Deserialize(const string text)
     {
      if(StringLen(text)==0)
         return(false);
      string parts[];
      const int count=StringSplit(text,';',parts);
      bool have_state=false;
      ENUM_TR_STATE parsed=TR_STATE_INITIALIZING;
      int transitions=m_transition_count;

      for(int i=0; i<count; i++)
        {
         string pair[];
         if(StringSplit(parts[i],'=',pair)!=2)
            continue;
         if(pair[0]=="state")
           {
            if(!TRStateFromText(pair[1],parsed))
               return(false);
            have_state=true;
           }
         else if(pair[0]=="transitions")
            transitions=(int)StringToInteger(pair[1]);
        }
      if(!have_state)
         return(false);

      m_state=parsed;
      m_transition_count=transitions;
      return(true);
     }

   static bool TRStateFromText(const string text,ENUM_TR_STATE &state)
     {
      if(text=="INITIALIZING")        { state=TR_STATE_INITIALIZING; return(true); }
      if(text=="READY")               { state=TR_STATE_READY; return(true); }
      if(text=="WAITING_FOR_SETUP")   { state=TR_STATE_WAITING_FOR_SETUP; return(true); }
      if(text=="ENTRY_REQUESTED")     { state=TR_STATE_ENTRY_REQUESTED; return(true); }
      if(text=="POSITION_OPEN")       { state=TR_STATE_POSITION_OPEN; return(true); }
      if(text=="REVERSAL_WATCH")      { state=TR_STATE_REVERSAL_WATCH; return(true); }
      if(text=="CLOSE_FOR_REVERSAL")  { state=TR_STATE_CLOSE_FOR_REVERSAL; return(true); }
      if(text=="COOLDOWN")            { state=TR_STATE_COOLDOWN; return(true); }
      if(text=="DAILY_LOCKED")        { state=TR_STATE_DAILY_LOCKED; return(true); }
      if(text=="DRAWDOWN_LOCKED")     { state=TR_STATE_DRAWDOWN_LOCKED; return(true); }
      if(text=="ERROR_SAFE_MODE")     { state=TR_STATE_ERROR_SAFE_MODE; return(true); }
      return(false);
     }
  };

#endif // TR_STATE_MQH
