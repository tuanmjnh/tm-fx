//+------------------------------------------------------------------+
//|                                                      IRRisk.mqh  |
//|   InfiniteRunner V2 - pure loss-streak circuit-breaker decision  |
//|                                                                  |
//| No trading, account or file API. The EA keeps the counters and   |
//| calls this to decide whether a loss streak must block entries    |
//| now, arm a recovery cooldown, or has recovered.                  |
//|                                                                  |
//| Why a cooldown is needed: the streak counter only clears on a    |
//| WINNING trade, so a permanent block is a dead end - with no      |
//| entries there is never a win, and the guard never releases. The  |
//| cooldown guarantees the bot can trade again.                     |
//+------------------------------------------------------------------+
#ifndef IR_RISK_MQH
#define IR_RISK_MQH

//--- What the loss-streak guard wants the caller to do now.
enum ENUM_IR_STREAK_ACTION
  {
   IR_STREAK_ALLOW   = 0,   // streak below the limit: trade normally
   IR_STREAK_BLOCK   = 1,   // entries blocked (cooldown running, or legacy lock)
   IR_STREAK_RECOVER = 2    // cooldown served: clear the streak and resume
  };

//--- Decide the loss-streak guard action.
//---   streak            current consecutive-loss count
//---   limit             InpMaxConsecutiveLosses (0 = guard disabled)
//---   cooldown_minutes  InpLossStreakCooldownMinutes (0 = legacy permanent lock)
//---   now               TimeCurrent()
//---   cooldown_until     armed cooldown end (0 = none)
//--- Outputs:
//---   new_cooldown_until  cooldown to store (0 clears it; unchanged otherwise)
//---   reason              stable machine-readable token for the journal
ENUM_IR_STREAK_ACTION IRLossStreakDecide(const int streak,const int limit,
                                         const int cooldown_minutes,
                                         const datetime now,
                                         const datetime cooldown_until,
                                         datetime &new_cooldown_until,
                                         string &reason)
  {
   new_cooldown_until=cooldown_until;
   reason="";
   if(limit<=0 || streak<limit)
      return(IR_STREAK_ALLOW);

   //--- Legacy behaviour: no cooldown configured -> permanent block. Kept as an
   //--- explicit escape hatch, but it is a dead end (see the header note).
   if(cooldown_minutes<=0)
     {
      reason=StringFormat("loss_streak|count=%d|limit=%d",streak,limit);
      return(IR_STREAK_BLOCK);
     }

   //--- Arm the cooldown the first time the streak reaches the limit.
   if(cooldown_until<=0)
     {
      new_cooldown_until=now+(datetime)cooldown_minutes*60;
      reason=StringFormat("loss_streak_armed|count=%d|limit=%d|until=%s",
                          streak,limit,TimeToString(new_cooldown_until));
      return(IR_STREAK_BLOCK);
     }

   //--- Cooldown still running.
   if(now<cooldown_until)
     {
      reason=StringFormat("loss_streak_cooldown|until=%s",
                          TimeToString(cooldown_until));
      return(IR_STREAK_BLOCK);
     }

   //--- Cooldown served: clear the streak (and the cooldown) and resume.
   new_cooldown_until=0;
   return(IR_STREAK_RECOVER);
  }

#endif // IR_RISK_MQH
