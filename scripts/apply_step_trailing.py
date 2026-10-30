# Helper script to update InfiniteRunnerXAUV2DemoEA.mq5
with open('mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5', 'r', encoding='utf-8') as f:
    text = f.read()

target = """input group "Trailing"
input ENUM_IR_TRAIL_MODE InpTrailMode = IR_TRAIL_FIXED;
input int    InpTrailStartPts         = 3000;
input int    InpTrailDistancePts      = 2500;
input int    InpTrailStepPts          = 500;
input double InpTrailAtrMultiplier    = 2.0;
input double InpBreakEvenTriggerR     = 0.0;                      // 0 = off
input int    InpBreakEvenBufferPts    = 100;
input int    InpSafetyTpPoints        = 100000;                   // far mandatory TP"""

replacement = """input group "Trailing"
input ENUM_IR_TRAIL_MODE InpTrailMode = IR_TRAIL_FIXED;
input int    InpTrailStartPts         = 3000;
input int    InpTrailDistancePts      = 2500;
input int    InpTrailStepPts          = 500;
input double InpTrailAtrMultiplier    = 2.0;
input double InpBreakEvenTriggerR     = 0.0;                      // 0 = off
input int    InpBreakEvenBufferPts    = 100;
input int    InpSafetyTpPoints        = 100000;                   // far mandatory TP

input group "Step Trailing"
input bool   InpEnableStepTrailing    = true;                     // true = bat keo SL da tang theo nac loi nhuan
input double InpStep1_TriggerPoints   = 1500.0;                   // Dat loi nhuan nac 1 (1.5 USD vang)
input double InpStep1_LockPoints      = 200.0;                    // Khoa SL nac 1 (Hoa von + 0.2 USD bao ve phi)
input double InpStep2_TriggerPoints   = 3000.0;                   // Dat loi nhuan nac 2 (3.0 USD vang)
input double InpStep2_LockPoints      = 1500.0;                   // Khoa SL nac 2 (Bo tui +1.5 USD)
input double InpStep3_TriggerPoints   = 5000.0;                   // Dat loi nhuan nac 3 (5.0 USD vang)
input double InpStep3_LockPoints      = 3500.0;                   // Khoa SL nac 3 (Khoa chac +3.5 USD)"""

# Update inputs
text_norm = text.replace('\r\n', '\n')
target_norm = target.replace('\r\n', '\n')
if target_norm not in text_norm:
    raise ValueError("Target inputs block not found!")
text_norm = text_norm.replace(target_norm, replacement.replace('\r\n', '\n'), 1)

# Now update ManageTrailing to incorporate Step Trailing candidate
target_manage = """   //--- 2. Trailing candidates. Fixed mode: start after TrailStartPts of
   //---    profit (V1 parity). ATR mode: start after 1R of profit.
   if(!(candidate>0.0) && profit_units>0.0)"""

replacement_manage = """   //--- 1b. Step Trailing candidate (Nhat tien le / Tiered Locks)
   if(!(candidate>0.0) && InpEnableStepTrailing && profit_units>0.0)
     {
      string step_reason="";
      candidate=IRStepTrailCandidate(g_pos_is_buy,g_pos_entry,reference,g_point,
                                     InpStep1_TriggerPoints,InpStep1_LockPoints,
                                     InpStep2_TriggerPoints,InpStep2_LockPoints,
                                     InpStep3_TriggerPoints,InpStep3_LockPoints,
                                     step_reason);
      if(candidate>0.0)
         candidate_reason=step_reason;
     }

   //--- 2. Trailing candidates. Fixed mode: start after TrailStartPts of
   //---    profit (V1 parity). ATR mode: start after 1R of profit.
   if(!(candidate>0.0) && profit_units>0.0)"""

target_manage_norm = target_manage.replace('\r\n', '\n')
if target_manage_norm not in text_norm:
    raise ValueError("Target manage block not found!")
text_norm = text_norm.replace(target_manage_norm, replacement_manage.replace('\r\n', '\n'), 1)

with open('mt5/Experts/InfiniteRunnerXAUV2DemoEA.mq5', 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(text_norm)

print("Updated InfiniteRunnerXAUV2DemoEA.mq5 successfully!")
