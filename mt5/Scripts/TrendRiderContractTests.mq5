//+------------------------------------------------------------------+
//|                                     TrendRiderContractTests.mq5 |
//|      PA_TrendRider_XAU_V1 - synthetic contract tests              |
//|                                                                  |
//| Runs once. No market data, no file I/O, no account access and no  |
//| trading functions. It is compiled as a temporary EA wrapper for   |
//| the Strategy Tester; the source of truth is this script.          |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Synthetic tests for the TrendRider pure modules. No trading."
#property script_show_inputs

#include "../Include/TrendRider/TRTypes.mqh"
#include "../Include/TrendRider/TRConfig.mqh"
#include "../Include/TrendRider/TRSwing.mqh"
#include "../Include/TrendRider/TRStructure.mqh"
#include "../Include/TrendRider/TRTrend.mqh"
#include "../Include/TrendRider/TRPullback.mqh"
#include "../Include/TrendRider/TRSignal.mqh"
#include "../Include/TrendRider/TRAtr.mqh"
#include "../Include/TrendRider/TRRisk.mqh"
#include "../Include/TrendRider/TRTrailing.mqh"
#include "../Include/TrendRider/TRState.mqh"

int g_pass=0;
int g_fail=0;

void Record(const string id,const bool ok,const string detail)
  {
   if(ok)
     {
      g_pass++;
      PrintFormat("TEST|%s|PASS",id);
      return;
     }
   g_fail++;
   PrintFormat("TEST|%s|FAIL|%s",id,detail);
  }

bool Near(const double a,const double b,const double tolerance=1e-9)
  {
   return(MathAbs(a-b)<=tolerance);
  }

datetime T(const int index)
  {
   return((datetime)(1700000000+index*300));
  }

//--- Bars are always appended oldest-first.
void AppendBar(TRBar &bars[],const double open,const double high,
               const double low,const double close,const datetime time)
  {
   const int size=ArraySize(bars);
   ArrayResize(bars,size+1);
   bars[size].time=time;
   bars[size].open=open;
   bars[size].high=high;
   bars[size].low=low;
   bars[size].close=close;
  }

void AppendHighLow(TRBar &bars[],const double high,const double low,
                   const datetime time)
  {
   AppendBar(bars,low,high,low,(high+low)*0.5,time);
  }

TRSwingPoint MakeSwing(const bool is_high,const int index,const double price)
  {
   TRSwingPoint swing;
   swing.valid=true;
   swing.is_high=is_high;
   swing.index=index;
   swing.time=T(index);
   swing.confirm_index=index+2;
   swing.confirm_time=T(index+2);
   swing.price=price;
   return(swing);
  }

void PushSwing(TRSwingPoint &swings[],const TRSwingPoint &swing)
  {
   const int size=ArraySize(swings);
   ArrayResize(swings,size+1);
   swings[size]=swing;
  }

TRSymbolSpec TestSpec(void)
  {
   TRSymbolSpec spec;
   spec.point=0.001;
   spec.tick_size=0.001;
   spec.tick_value=0.1;
   spec.volume_min=0.01;
   spec.volume_max=100.0;
   spec.volume_step=0.01;
   spec.contract_size=100.0;
   spec.stops_level_points=0.0;
   spec.freeze_level_points=0.0;
   return(spec);
  }

//+------------------------------------------------------------------+
//| A. Swing detector                                                |
//+------------------------------------------------------------------+
void RunSwing(void)
  {
   //--- S1/S3: one confirmed swing high with strict neighbours.
   TRBar bars[];
   const double highs[7]={10,11,12,13,12,11,10};
   const double lows[7]={9,9.5,10,10.5,11,11.5,12};
   for(int i=0; i<7; i++)
      AppendHighLow(bars,highs[i],lows[i],T(i));

   TRSwingPoint swings[];
   const int count=TRCollectSwings(bars,2,2,swings);
   bool has_high=false;
   bool has_low=false;
   for(int i=0; i<count; i++)
     {
      if(swings[i].is_high && swings[i].index==3)
        {
         has_high=true;
         Record("S1",Near(swings[i].price,13.0) &&
                Near((double)swings[i].confirm_index,5.0),
                StringFormat("index=%d price=%.4f confirm=%d",
                             swings[i].index,swings[i].price,
                             swings[i].confirm_index));
        }
      if(!swings[i].is_high && swings[i].index==3)
         has_low=true;
     }
   Record("S1a",has_high && !has_low,
          StringFormat("count=%d has_high=%d has_low=%d",
                       count,(int)has_high,(int)has_low));

   //--- S2: with only one right bar the swing is not confirmed yet.
   TRBar short_bars[];
   for(int i=0; i<5; i++)
      AppendHighLow(short_bars,highs[i],lows[i],T(i));
   TRSwingPoint short_swings[];
   Record("S2",TRCollectSwings(short_bars,2,2,short_swings)==0,
          StringFormat("confirmed too early: %d",
                       ArraySize(short_swings)));

   //--- S4: equal highs are ties and must be rejected.
   TRBar tie[];
   const double tie_highs[7]={10,11,12,13,13,11,10};
   const double tie_lows[7]={9,9.5,10,10.5,10.6,11.5,12};
   for(int i=0; i<7; i++)
      AppendHighLow(tie,tie_highs[i],tie_lows[i],T(i));
   TRSwingPoint tie_swings[];
   Record("S4",TRCollectSwings(tie,2,2,tie_swings)==0,
          StringFormat("ties accepted: %d",ArraySize(tie_swings)));

   //--- S5: symmetric swing low.
   TRBar low_bars[];
   const double low_highs[7]={10,10.8,11,10.2,10.9,10.3,9.8};
   const double low_lows[7]={9,8,7,6,7,8,9};
   for(int i=0; i<7; i++)
      AppendHighLow(low_bars,low_highs[i],low_lows[i],T(i));
   TRSwingPoint low_swings[];
   const int low_count=TRCollectSwings(low_bars,2,2,low_swings);
   bool low_found=false;
   for(int i=0; i<low_count; i++)
      if(!low_swings[i].is_high && low_swings[i].index==3)
         low_found=Near(low_swings[i].price,6.0) &&
                   Near((double)low_swings[i].confirm_index,5.0);
   Record("S5",low_found,"swing low not detected");

   //--- S6: appending bars never changes a confirmed swing.
   datetime confirm_before=0;
   double price_before=0.0;
   for(int i=0; i<count; i++)
      if(swings[i].is_high && swings[i].index==3)
        {
         confirm_before=swings[i].confirm_time;
         price_before=swings[i].price;
        }
   AppendHighLow(bars,9.5,11.4,T(7));
   AppendHighLow(bars,9.0,11.8,T(8));
   TRSwingPoint after[];
   const int after_count=TRCollectSwings(bars,2,2,after);
   bool unchanged=false;
   for(int i=0; i<after_count; i++)
     {
      if(after[i].is_high && after[i].index==3)
         unchanged=(after[i].confirm_time==confirm_before &&
                    Near(after[i].price,price_before));
      if(after[i].is_high && after[i].index>3)
         unchanged=false;
     }
   Record("S6",unchanged,"confirmed swing changed after append");
  }

//+------------------------------------------------------------------+
//| B. Structure: buffer, BOS, CHoCH                                 |
//+------------------------------------------------------------------+
void RunStructure(void)
  {
   const TRConfig cfg=TRConfigDefault();

   //--- B1: break buffer is max of the two hypotheses, strict break.
   const double buffer=TRBreakBuffer(2.0,0.2,cfg);
   Record("B1",Near(buffer,0.4) &&
          !TRIsBosBull(10.4,10.0,buffer) &&
          TRIsBosBull(10.4001,10.0,buffer),
          StringFormat("buffer=%.6f",buffer));

   //--- B2: structure exposes last/previous swings in order.
   TRSwingPoint swings[];
   PushSwing(swings,MakeSwing(false,1,8.0));
   PushSwing(swings,MakeSwing(true,2,10.0));
   PushSwing(swings,MakeSwing(false,3,9.0));
   PushSwing(swings,MakeSwing(true,4,12.0));
   const TRStructure structure=TRBuildStructure(swings);
   const TRChainResult chain=TRChainFromStructure(structure,0.0);
   Record("B2",structure.has_high && structure.has_low &&
          Near(structure.last_high.price,12.0) &&
          Near(structure.prev_high.price,10.0) &&
          Near(structure.last_low.price,9.0) &&
          Near(structure.prev_low.price,8.0) &&
          structure.high_count==2 && structure.low_count==2,
          "structure ordering");

   //--- B3: mixed swings are RANGE, not a trend.
   TRSwingPoint mixed[];
   PushSwing(mixed,MakeSwing(false,1,9.0));
   PushSwing(mixed,MakeSwing(true,2,12.0));
   PushSwing(mixed,MakeSwing(false,3,9.5));
   PushSwing(mixed,MakeSwing(true,4,11.5));
   const TRChainResult range_chain=
      TRChainFromStructure(TRBuildStructure(mixed),0.0);
   Record("B3",range_chain.valid && range_chain.ranging &&
          range_chain.direction==TR_DIR_UNKNOWN,
          "mixed swings classified as trend");

   //--- B4: one BOS per broken swing, never twice on the same bar.
   TRBar bos_bars[];
   const double bos_highs[7]={10,11,12,13,12,11,14};
   const double bos_lows[7]={9,9.5,10,10.5,11,11.5,13.5};
   for(int i=0; i<7; i++)
      AppendBar(bos_bars,bos_lows[i],bos_highs[i],bos_lows[i],
                (i==6 ? 14.0 : bos_highs[i]),T(i));
   TRStructureEngine engine;
   TRStructureSnapshot snap=engine.Update(bos_bars,cfg,0.5,0.05);
   Record("B4",snap.valid && snap.event==TR_EVENT_BOS_BULL &&
          Near(snap.event_level,13.0) && engine.BosCount()==1,
          StringFormat("event=%s level=%.4f count=%d",
                       TREventName(snap.event),snap.event_level,
                       engine.BosCount()));
   snap=engine.Update(bos_bars,cfg,0.5,0.05);
   Record("B5",snap.event==TR_EVENT_NONE && engine.BosCount()==1,
          StringFormat("same bar repeated event=%s count=%d",
                       TREventName(snap.event),engine.BosCount()));

   //--- B6/B7: CHoCH after a bullish chain, and the warning persists.
   //--- Every swing needs `left` bars to its left, so the first low
   //--- sits at index 2, not 1.
   TRBar choch[];
   const double ch_highs[11]={9.5,9.7,8.9,10,11,10.5,10,10.8,12,10.5,8.9};
   const double ch_lows[11]={8.5,8.3,8.0,9.2,9.3,9.5,9.0,9.3,9.6,9.2,8.0};
   for(int i=0; i<11; i++)
      AppendBar(choch,ch_lows[i],ch_highs[i],ch_lows[i],
                (i==10 ? 8.0 : ch_highs[i]),T(i));
   TRStructureEngine choch_engine;
   const TRStructureSnapshot cs=choch_engine.Update(choch,cfg,0.5,0.01);
   Record("B6",cs.valid && cs.event==TR_EVENT_CHOCH_BEAR &&
          cs.choch_active && cs.choch_direction==TR_DIR_BEARISH &&
          Near(cs.event_level,9.0) && choch_engine.ChochCount()==1,
          StringFormat("event=%s active=%d level=%.4f",
                       TREventName(cs.event),(int)cs.choch_active,
                       cs.event_level));
   const TRStructureSnapshot cs2=choch_engine.Update(choch,cfg,0.5,0.01);
   Record("B7",cs2.event==TR_EVENT_NONE && choch_engine.ChochCount()==1 &&
          choch_engine.ChochActive(),
          "CHoCH repeated on the same bar");

   //--- B8: protected swing predicates.
   const bool bear_break=TRIsChochBear(structure,8.7,0.2);
   const bool bear_hold=TRIsChochBear(structure,8.9,0.2);
   Record("B8",bear_break && !bear_hold,"CHoCH threshold mismatch");

   //--- B9: the same swing must not fire a second BOS when the rolling
   //--- window shifts its array index. Dedupe is by swing time.
   TRBar shifted[];
   for(int i=1; i<7; i++)
      AppendBar(shifted,bos_lows[i],bos_highs[i],bos_lows[i],
                (i==6 ? 14.0 : bos_highs[i]),T(i));
   AppendBar(shifted,14.0,14.2,14.0,14.2,T(7));
   const TRStructureSnapshot shifted_snap=engine.Update(shifted,cfg,0.5,0.05);
   Record("B9",shifted_snap.event==TR_EVENT_NONE && engine.BosCount()==1,
          StringFormat("window shift event=%s count=%d",
                       TREventName(shifted_snap.event),engine.BosCount()));
  }

//+------------------------------------------------------------------+
//| C. Bias and regime priority                                      |
//+------------------------------------------------------------------+
void RunTrend(void)
  {
   TRChainResult bull;
   bull.direction=TR_DIR_BULLISH;
   bull.valid=true;
   bull.ranging=false;
   TRChainResult bear;
   bear.direction=TR_DIR_BEARISH;
   bear.valid=true;
   bear.ranging=false;
   TRChainResult range;
   range.direction=TR_DIR_UNKNOWN;
   range.valid=true;
   range.ranging=true;
   TRChainResult unknown;
   unknown.direction=TR_DIR_UNKNOWN;
   unknown.valid=false;
   unknown.ranging=false;

   const TRBiasResult aligned=TRMergeBias(bull,bull);
   const TRBiasResult conflict=TRMergeBias(bull,bear);
   const TRBiasResult missing=TRMergeBias(unknown,bull);
   const TRBiasResult both_range=TRMergeBias(range,range);

   Record("T1",aligned.valid && aligned.direction==TR_DIR_BULLISH &&
          aligned.reason=="aligned_bullish","aligned bull");
   Record("T2",!conflict.valid && conflict.conflict &&
          conflict.direction==TR_DIR_UNKNOWN &&
          conflict.reason=="timeframe_conflict","conflict not detected");
   Record("T3",!missing.valid && missing.reason=="insufficient_structure",
          "missing data accepted");
   Record("T4",both_range.valid && both_range.ranging &&
          !both_range.conflict,"range merge");

   Record("T5",TRResolveRegime(aligned,false,false,false,true,true)==
          TR_REGIME_RISK_LOCKED,"risk priority");
   Record("T6",TRResolveRegime(aligned,false,true,true,false,true)==
          TR_REGIME_SPREAD_BLOCKED,"spread priority");
   Record("T7",TRResolveRegime(aligned,true,true,false,false,true)==
          TR_REGIME_VOLATILITY_HIGH,"volatility priority");
   Record("T8",TRResolveRegime(aligned,true,false,false,false,true)==
          TR_REGIME_REVERSAL_WATCH,"reversal priority");
   Record("T9",TRResolveRegime(aligned,false,false,false,false,true)==
          TR_REGIME_TREND_UP,"trend regime");
   Record("T10",TRResolveRegime(aligned,false,false,false,false,false)==
          TR_REGIME_UNKNOWN,"data error priority");
  }

//+------------------------------------------------------------------+
//| D. Retest zone and confirmation candle                           |
//+------------------------------------------------------------------+
void RunPullback(void)
  {
   const TRConfig cfg=TRConfigDefault();
   const TRRetestZone zone=TRBuildRetestZone(SIM_SIDE_BUY,10.0,T(0),0,2.0,
                                             cfg.retest_zone_atr);
   Record("P1",zone.valid && Near(zone.low,9.5) && Near(zone.high,10.5),
          StringFormat("zone %.4f..%.4f",zone.low,zone.high));

   TRBar touched[];
   AppendBar(touched,10.6,10.8,10.4,10.7,T(1));
   TRBar untouched[];
   AppendBar(untouched,10.8,10.9,10.6,10.8,T(1));
   Record("P2",TRZoneTouched(zone,touched,0,0) &&
          !TRZoneTouched(zone,untouched,0,0),"zone touch");

   Record("P3",TRZoneInvalidated(zone,9.4,0.05) &&
          !TRZoneInvalidated(zone,9.5,0.05),"zone invalidation");

   TRBar confirm_buy;
   confirm_buy.time=T(1);
   confirm_buy.open=10.0;
   confirm_buy.high=10.7;
   confirm_buy.low=9.9;
   confirm_buy.close=10.6;
   TRBar confirm_sell;
   confirm_sell.time=T(1);
   confirm_sell.open=10.7;
   confirm_sell.high=10.8;
   confirm_sell.low=10.0;
   confirm_sell.close=10.1;
   TRBar flat;
   flat.time=T(1);
   flat.open=10.0;
   flat.high=10.0;
   flat.low=10.0;
   flat.close=10.0;
   Record("P4",TRIsConfirmationCandle(confirm_buy,SIM_SIDE_BUY,1.0,cfg) &&
          TRIsConfirmationCandle(confirm_sell,SIM_SIDE_SELL,1.0,cfg) &&
          !TRIsConfirmationCandle(confirm_sell,SIM_SIDE_BUY,1.0,cfg) &&
          !TRIsConfirmationCandle(flat,SIM_SIDE_BUY,1.0,cfg),
          "confirmation candle");

   TRBar sequence[];
   AppendBar(sequence,10.3,10.8,10.2,10.7,T(1));
   AppendBar(sequence,10.2,10.9,10.1,10.8,T(2));
   const TRPullbackResult ok=TREvaluatePullback(zone,sequence,0,1.0,0.1,cfg);
   Record("P5",ok.ok && ok.touched && ok.confirm_index==1 &&
          ok.reason=="OK",StringFormat("pullback reason=%s",ok.reason));

   TRBar broken[];
   AppendBar(broken,9.6,9.8,9.3,9.3,T(1));
   AppendBar(broken,9.4,9.8,9.2,9.7,T(2));
   const TRPullbackResult bad=TREvaluatePullback(zone,broken,0,1.0,0.1,cfg);
   Record("P6",!bad.ok && bad.invalidated && bad.reason=="ZONE_INVALIDATED",
          StringFormat("broken zone reason=%s",bad.reason));
  }

//+------------------------------------------------------------------+
//| E. Signal engine reason codes                                    |
//+------------------------------------------------------------------+
void BuildSignalBars(TRBar &bars[])
  {
   ArrayResize(bars,0);
   AppendBar(bars,10.3,10.8,10.2,10.7,T(1));
   AppendBar(bars,10.2,10.9,10.1,10.8,T(2));
  }

TRSignalContext BaseSignalContext(const TRBar &bars[])
  {
   TRSignalContext ctx;
   ctx.enabled=true;
   ctx.data_ok=true;
   ctx.bias.valid=true;
   ctx.bias.direction=TR_DIR_BULLISH;
   ctx.bias.ranging=false;
   ctx.bias.conflict=false;
   ctx.bias.reason="aligned_bullish";
   ctx.reversal_watch=false;
   ctx.volatility_high=false;
   ctx.spread_blocked=false;
   ctx.risk_locked=false;
   ctx.has_bos=true;
   ctx.bos_side=SIM_SIDE_BUY;
   ctx.bos_level=10.0;
   ctx.bos_time=T(0);
   ctx.pullback_start_index=0;
   ctx.entry_count=ArraySize(bars);
   ctx.atr=1.0;
   ctx.spread_price=0.05;
   return(ctx);
  }

void RunSignal(void)
  {
   const TRConfig cfg=TRConfigDefault();
   TRBar bars[];
   BuildSignalBars(bars);
   TRSignalContext ctx=BaseSignalContext(bars);

   TRSignalDecision ok=TREvaluateSignal(cfg,ctx,bars);
   Record("G1",ok.entry && ok.side==SIM_SIDE_BUY &&
          StringFind(ok.reason,"SIGNAL_OK")>=0 && ok.bars_since_bos==2,
          StringFormat("entry=%d reason=%s age=%d",(int)ok.entry,
                       ok.reason,ok.bars_since_bos));

   ctx.enabled=false;
   Record("G2",StringFind(TREvaluateSignal(cfg,ctx,bars).reason,
                          "reason=disabled")>=0,"disabled");
   ctx=BaseSignalContext(bars);
   ctx.bias.valid=false;
   Record("G3",StringFind(TREvaluateSignal(cfg,ctx,bars).reason,
                          "reason=bias_unknown")>=0,"bias unknown");
   ctx=BaseSignalContext(bars);
   ctx.bias.conflict=true;
   Record("G4",StringFind(TREvaluateSignal(cfg,ctx,bars).reason,
                          "reason=timeframe_conflict")>=0,"conflict");
   ctx=BaseSignalContext(bars);
   ctx.reversal_watch=true;
   Record("G5",StringFind(TREvaluateSignal(cfg,ctx,bars).reason,
                          "reason=reversal_watch")>=0,"reversal watch");
   ctx=BaseSignalContext(bars);
   ctx.has_bos=false;
   Record("G6",StringFind(TREvaluateSignal(cfg,ctx,bars).reason,
                          "reason=no_bos")>=0,"no BOS");
   ctx=BaseSignalContext(bars);
   ctx.spread_blocked=true;
   Record("G7",StringFind(TREvaluateSignal(cfg,ctx,bars).reason,
                          "reason=spread_blocked")>=0,"spread block");
   ctx=BaseSignalContext(bars);
   ctx.volatility_high=true;
   Record("G8",StringFind(TREvaluateSignal(cfg,ctx,bars).reason,
                          "reason=volatility_high")>=0,"volatility block");
   ctx=BaseSignalContext(bars);
   ctx.risk_locked=true;
   Record("G9",StringFind(TREvaluateSignal(cfg,ctx,bars).reason,
                          "reason=risk_locked")>=0,"risk block");

   //--- G10: BOS older than max_signal_age_bars is dropped.
   TRBar long_bars[];
   for(int i=0; i<12; i++)
      AppendBar(long_bars,10.3,10.8,10.2,10.7,T(i));
   ctx=BaseSignalContext(long_bars);
   Record("G10",StringFind(TREvaluateSignal(cfg,ctx,long_bars).reason,
                           "reason=bos_too_old")>=0,"stale BOS");

   //--- G11: last bar closed against the trade, no confirmation.
   TRBar no_confirm[];
   AppendBar(no_confirm,10.3,10.8,10.2,10.7,T(1));
   AppendBar(no_confirm,10.8,10.9,10.1,10.2,T(2));
   ctx=BaseSignalContext(no_confirm);
   Record("G11",StringFind(TREvaluateSignal(cfg,ctx,no_confirm).reason,
                           "reason=NO_CONFIRMATION")>=0,
          "bearish close confirmed a buy");

   //--- G12: no bar after the BOS event.
   ctx=BaseSignalContext(bars);
   ctx.pullback_start_index=2;
   Record("G12",StringFind(TREvaluateSignal(cfg,ctx,bars).reason,
                           "reason=no_pullback")>=0,"no post-BOS bar");
  }

//+------------------------------------------------------------------+
//| F. Sizing and account-level guards                               |
//+------------------------------------------------------------------+
void RunRisk(void)
  {
   TRConfig cfg=TRConfigDefault();
   const TRSymbolSpec spec=TestSpec();

   Record("R1",Near(TRRiskMoney(1000.0,0.25),2.5),"risk money");
   Record("R2",Near(TRLossPerLot(spec,2000.0,1990.0),1000.0),
          StringFormat("loss/lot=%.4f",TRLossPerLot(spec,2000.0,1990.0)));

   TRLotDecision lot=TRCalcLot(cfg,spec,1000.0,2000.0,1999.9);
   Record("R3",lot.ok && Near(lot.volume,0.25) && Near(lot.expected_loss,2.5),
          StringFormat("ok=%d vol=%.4f loss=%.4f reason=%s",
                       (int)lot.ok,lot.volume,lot.expected_loss,lot.reason));

   lot=TRCalcLot(cfg,spec,1020.0,2000.0,1999.9);
   Record("R4",lot.ok && Near(lot.volume,0.25) && Near(lot.expected_loss,2.5),
          StringFormat("round down vol=%.4f loss=%.4f",
                       lot.volume,lot.expected_loss));

   lot=TRCalcLot(cfg,spec,1000.0,2000.0,1990.0);
   Record("R5",!lot.ok && lot.reason=="min_volume_exceeds_risk",
          StringFormat("ok=%d reason=%s",(int)lot.ok,lot.reason));

   cfg.commission_per_volume=1.0;
   lot=TRCalcLot(cfg,spec,1000.0,2000.0,1999.9);
   Record("R6",lot.ok && Near(lot.volume,0.2) && Near(lot.expected_loss,2.4),
          StringFormat("commission vol=%.4f loss=%.4f",
                       lot.volume,lot.expected_loss));
   cfg=TRConfigDefault();

   cfg.risk_percent=50.0;
   lot=TRCalcLot(cfg,spec,100000.0,2000.0,1999.9);
   Record("R7",lot.ok && Near(lot.volume,100.0) &&
          Near(lot.expected_loss,1000.0),
          StringFormat("clamp vol=%.4f loss=%.4f",lot.volume,
                       lot.expected_loss));
   cfg=TRConfigDefault();

   string reason="";
   Record("R8",TRStopDistanceValid(cfg,spec,2000.0,1995.0,2.0,reason) &&
          !TRStopDistanceValid(cfg,spec,2000.0,1999.5,2.0,reason) &&
          !TRStopDistanceValid(cfg,spec,2000.0,1991.0,2.0,reason),
          "stop distance band");

   //--- Distance 0.15 sits above the 0.1 ATR floor but below 200 points.
   TRSymbolSpec tight=spec;
   tight.stops_level_points=200.0;
   Record("R9",!TRStopDistanceValid(cfg,tight,2000.0,1999.85,0.2,reason) &&
          reason=="stop_below_broker_level",
          "broker stop level ignored, reason="+reason);

   Record("R10",TRDailyLocked(990.0,1000.0,1.0) &&
          !TRDailyLocked(990.1,1000.0,1.0),"daily lock");
   Record("R11",TRDrawdownLocked(920.0,1000.0,8.0) &&
          !TRDrawdownLocked(921.0,1000.0,8.0),"drawdown lock");
   Record("R12",TRStreakLocked(3,3) && !TRStreakLocked(2,3),
          "streak lock");
  }

void RunLedger(void)
  {
   TRConfig cfg=TRConfigDefault();
   const datetime start=(datetime)1700000000;

   TRRiskLedger ledger;
   Record("R13",ledger.Init(1000.0,start) &&
          Near(ledger.DayStartEquity(),1000.0) &&
          Near(ledger.PeakEquity(),1000.0),"ledger init");

   for(int i=0; i<3; i++)
      ledger.OnTradeClosed(-10.0,start+i*60,cfg);
   const TRGuardDecision cooldown=ledger.EntryBlock(1000.0,start+300,cfg);
   Record("R14",!cooldown.allowed && cooldown.reason=="cooldown" &&
          ledger.ConsecutiveLosses()==3,"cooldown not armed");

   //--- Third loss at start+120 arms 30 minutes, i.e. until start+1920.
   const TRGuardDecision expired=ledger.EntryBlock(1000.0,
                                                   start+1920,cfg);
   Record("R15",expired.allowed && ledger.ConsecutiveLosses()==0,
          StringFormat("allowed=%d streak=%d reason=%s",
                       (int)expired.allowed,ledger.ConsecutiveLosses(),
                       expired.reason));

   //--- Daily lock resets with the server day; drawdown lock is sticky.
   TRRiskLedger day;
   day.Init(1000.0,start);
   day.UpdateEquity(985.0,start,cfg);
   const TRGuardDecision daily=day.EntryBlock(985.0,start,cfg);
   const datetime next_day=start+86400;
   day.UpdateEquity(985.0,next_day,cfg);
   const TRGuardDecision reopened=day.EntryBlock(985.0,next_day,cfg);
   Record("R16",!daily.allowed && daily.reason=="daily_loss_lock" &&
          reopened.allowed,"daily lock did not reset");

   TRRiskLedger dd;
   dd.Init(1000.0,start);
   dd.UpdateEquity(900.0,start,cfg);
   dd.UpdateEquity(1000.0,start+86400,cfg);
   const TRGuardDecision locked=dd.EntryBlock(1000.0,start+86400,cfg);
   Record("R17",!locked.allowed && locked.reason=="drawdown_locked",
          "drawdown lock not sticky");
   dd.ManualResetDrawdown(1000.0);
   const TRGuardDecision reset=dd.EntryBlock(1000.0,start+86401,cfg);
   Record("R18",reset.allowed,"manual drawdown reset");

   TRRiskLedger saved;
   saved.Init(1000.0,start);
   saved.OnTradeClosed(-5.0,start+60,cfg);
   saved.UpdateEquity(900.0,start+120,cfg);
   const string text=saved.Serialize();
   TRRiskLedger loaded;
   const bool parsed=loaded.Deserialize(text);
   Record("R19",parsed && loaded.DrawdownLockedFlag() &&
          loaded.ConsecutiveLosses()==1 &&
          Near(loaded.PeakEquity(),1000.0) &&
          loaded.Serialize()==text,
          StringFormat("serialize/parse: %s",text));
  }

//+------------------------------------------------------------------+
//| G. Trailing stop                                                 |
//+------------------------------------------------------------------+
TRTrailingInput BaseTrailing(const ENUM_SIM_SIDE side)
  {
   TRTrailingInput in;
   in.side=side;
   in.entry=2000.0;
   in.sl=(side==SIM_SIDE_BUY ? 1990.0 : 2010.0);
   in.price=(side==SIM_SIDE_BUY ? 2011.0 : 1989.0);
   in.initial_risk=10.0;
   in.atr=2.0;
   in.structure_level=0.0;
   in.use_structure=false;
   in.min_stop=0.5;
   in.break_even_r=1.0;
   in.trail_start_r=1.5;
   in.trail_atr_mult=1.2;
   return(in);
  }

void RunTrailing(void)
  {
   TRTrailingInput in=BaseTrailing(SIM_SIDE_BUY);
   TRTrailingDecision out=TRTrailingEvaluate(in);
   Record("L1",out.update && out.reason=="BREAK_EVEN" &&
          Near(out.new_sl,2000.0) && Near(out.profit_r,1.1),
          StringFormat("reason=%s sl=%.4f r=%.4f",out.reason,out.new_sl,
                       out.profit_r));

   in.price=2016.0;
   out=TRTrailingEvaluate(in);
   Record("L2",out.update && out.reason=="TRAIL_ATR" &&
          Near(out.new_sl,2013.6),
          StringFormat("reason=%s sl=%.4f",out.reason,out.new_sl));

   in.price=2015.0;
   in.sl=2014.0;
   out=TRTrailingEvaluate(in);
   Record("L3",!out.update && out.reason=="HOLD_NOT_IMPROVING",
          StringFormat("reason=%s sl=%.4f",out.reason,out.new_sl));

   in=BaseTrailing(SIM_SIDE_BUY);
   in.price=2015.4;
   in.min_stop=3.0;
   out=TRTrailingEvaluate(in);
   Record("L4",!out.update && out.reason=="TRAIL_TOO_CLOSE",
          StringFormat("reason=%s sl=%.4f",out.reason,out.new_sl));

   in=BaseTrailing(SIM_SIDE_BUY);
   in.price=2020.0;
   in.atr=1.0;
   in.use_structure=true;
   in.structure_level=2019.5;
   out=TRTrailingEvaluate(in);
   Record("L5",out.update && out.reason=="TRAIL_STRUCTURE" &&
          Near(out.new_sl,2019.5),
          StringFormat("reason=%s sl=%.4f",out.reason,out.new_sl));

   in=BaseTrailing(SIM_SIDE_SELL);
   in.price=1984.0;
   out=TRTrailingEvaluate(in);
   Record("L6",out.update && out.reason=="TRAIL_ATR" &&
          Near(out.new_sl,1986.4),
          StringFormat("reason=%s sl=%.4f",out.reason,out.new_sl));
  }

//+------------------------------------------------------------------+
//| H. State machine                                                 |
//+------------------------------------------------------------------+
void RunState(void)
  {
   TRStateMachine machine;
   string error="";
   const bool ready=machine.Transition(TR_STATE_READY,error);
   const bool waiting=machine.Transition(TR_STATE_WAITING_FOR_SETUP,error);
   const bool requested=machine.Transition(TR_STATE_ENTRY_REQUESTED,error);
   const bool open=machine.Transition(TR_STATE_POSITION_OPEN,error);
   const bool reversal=machine.Transition(TR_STATE_REVERSAL_WATCH,error);
   const bool closing=machine.Transition(TR_STATE_CLOSE_FOR_REVERSAL,error);
   const bool back=machine.Transition(TR_STATE_WAITING_FOR_SETUP,error);
   Record("M1",ready && waiting && requested && open && reversal &&
          closing && back && machine.State()==TR_STATE_WAITING_FOR_SETUP,
          "happy path transitions");

   TRStateMachine invalid;
   const bool bad=invalid.Transition(TR_STATE_POSITION_OPEN,error);
   Record("M2",!bad && error!="","invalid transition accepted");

   TRStateMachine locked;
   locked.Transition(TR_STATE_READY,error);
   locked.Transition(TR_STATE_DRAWDOWN_LOCKED,error);
   Record("M3",!locked.Transition(TR_STATE_POSITION_OPEN,error) &&
          locked.State()==TR_STATE_DRAWDOWN_LOCKED,"lock bypassed");
   Record("M4",locked.ManualReset(error) &&
          locked.State()==TR_STATE_WAITING_FOR_SETUP,"manual reset");

   const string text=locked.Serialize();
   TRStateMachine loaded;
   Record("M5",loaded.Deserialize(text) &&
          loaded.State()==TR_STATE_WAITING_FOR_SETUP &&
          loaded.Serialize()==text,
          StringFormat("state serialize: %s",text));
  }

//+------------------------------------------------------------------+
//| I. ATR helpers                                                   |
//+------------------------------------------------------------------+
void RunAtr(void)
  {
   TRBar bars[];
   AppendBar(bars,10.0,10.0,10.0,10.0,T(0));
   AppendBar(bars,10.0,12.0,10.0,11.0,T(1));
   AppendBar(bars,11.0,13.0,10.5,12.0,T(2));
   AppendBar(bars,12.0,12.0,9.5,10.0,T(3));

   double atr=0.0;
   Record("A1",TRAtr(bars,2,atr) && Near(atr,2.5),
          StringFormat("atr=%.4f",atr));

   TRBar median_bars[];
   AppendBar(median_bars,10.0,10.0,10.0,10.0,T(0));
   AppendBar(median_bars,10.0,11.0,10.0,11.0,T(1));
   AppendBar(median_bars,11.0,12.5,10.5,12.0,T(2));
   AppendBar(median_bars,12.0,15.0,12.0,13.0,T(3));
   double median=0.0;
   Record("A2",TRAtrMedian(median_bars,1,3,median) && Near(median,2.0),
          StringFormat("median=%.4f",median));

   Record("A3",!TRVolatilityAbnormal(3.0,2.0,2.5) &&
          TRVolatilityAbnormal(5.1,2.0,2.5),"volatility ratio");

   const TRConfig cfg=TRConfigDefault();
   string error="";
   Record("A4",TRConfigValidate(cfg,error),"default config: "+error);
   TRConfig bad=cfg;
   bad.swing_left=0;
   Record("A5",!TRConfigValidate(bad,error),"swing_left accepted");
   bad=cfg;
   bad.trailing_start_r=0.5;
   Record("A6",!TRConfigValidate(bad,error),"trailing before BE accepted");
   bad=cfg;
   bad.confirmation_close_zone=0.5;
   Record("A7",!TRConfigValidate(bad,error),"close zone accepted");
   bad=cfg;
   bad.risk_percent=0.0;
   Record("A8",!TRConfigValidate(bad,error),"zero risk accepted");

   const string hash_a=TRConfigFingerprint(cfg);
   TRConfig changed=cfg;
   changed.risk_percent=0.5;
   Record("A9",StringLen(hash_a)==8 &&
          hash_a!=TRConfigFingerprint(changed) &&
          hash_a==TRConfigFingerprint(cfg),"fingerprint");
  }

//+------------------------------------------------------------------+
//| Runner                                                           |
//+------------------------------------------------------------------+
void RunAllTests(void)
  {
   g_pass=0;
   g_fail=0;
   PrintFormat("TEST|BEGIN|suite=trendrider|version=1.00");
   RunSwing();
   RunStructure();
   RunTrend();
   RunPullback();
   RunSignal();
   RunRisk();
   RunLedger();
   RunTrailing();
   RunState();
   RunAtr();
   if(g_fail==0)
      PrintFormat("TEST|RESULT|ALL_PASS|pass=%d fail=%d|suite=trendrider",
                  g_pass,g_fail);
   else
      PrintFormat("TEST|RESULT|FAIL|pass=%d fail=%d|suite=trendrider",
                  g_pass,g_fail);
  }

void OnStart(void)
  {
   RunAllTests();
  }
