//+------------------------------------------------------------------+
//|                          TMIndicator2ContractTests.mq5           |
//|    MT5 EA & AI Lab - synthetic checks for the TM Indicator 2     |
//|    contract. Runs once. No file I/O, no market data, no account  |
//|    access, no trading functions.                                 |
//|    Vectors: docs/indicators/tm-indicator-2.md §12 (155)       |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Synthetic contract tests for TM Indicator 2. No trading."

#include "../Include/PinePort/TMIndicator2Contract.mqh"

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

bool Near(const double a,const double b)
  {
   return(MathAbs(a-b)<=1e-6);
  }

bool NearT(const double a,const double b,const double tol)
  {
   return(MathAbs(a-b)<=tol);
  }

bool EmptyD(const double v)
  {
   return(TM2IsEmpty(v));
  }

//+------------------------------------------------------------------+
//| Default configuration (contract §3.2)                            |
//+------------------------------------------------------------------+
TM2Config Cfg()
  {
   TM2Config c;
   ZeroMemory(c);
   c.srvOffsetMin=180;
   c.mktOffsetMin=-300;
   c.maxBars=0;
   c.btcSymbol="BTCUSD";
   c.assetIsCrypto=false;
   c.assetMode=TM2_ASSET_AUTO;
   c.cryptoSessNeutral=true;
   c.weekendFilter=true;
   c.btcLeaderOn=true;
   c.btcImpulseAtr=1.5;
   c.entryMode=TM2_ENTRY_AUTO;
   c.limitSource=TM2_LIMIT_FVG50;
   c.limitCancelBars=5;
   c.limitCancelOnTp1=true;
   c.modeFilterOn=true;
   c.modeAOn=true;
   c.modeBOn=true;
   c.modeCOn=false;
   c.modeSweepBars=3;
   c.modePullTol=0.35;
   c.modeRangeTol=0.35;
   c.autoBeOn=true;
   c.beOffsetAtr=0.05;
   c.trailOn=true;
   c.trailDistAtr=1.5;
   c.timeDecayOn=true;
   c.stagnantBars=15;
   c.maxHoldBars=300;
   c.gateRegime=true;
   c.gateObstacle=true;
   c.gateOverext=true;
   c.gateCircuit=true;
   c.gateRisk=true;
   c.adxTrending=22.0;
   c.adxChop=18.0;
   c.bbwLen=100;
   c.bbwSqueezePct=20.0;
   c.obstacleBuffer=0.7;
   c.maxExtAtr=2.2;
   c.maxCandleAtr=2.5;
   c.msSwingLen=5;
   c.msBosOn=true;
   c.msChochOn=true;
   c.msMssOn=true;
   c.msRetestOn=true;
   c.msRetestBars=10;
   c.msRetestTolAtr=0.5;
   c.msFailOn=true;
   c.msFailBars=5;
   c.msContOn=true;
   c.msPullOn=true;
   c.liqPdOn=true;
   c.liqPwOn=false;
   c.liqSessOn=true;
   c.srWidthAtr=0.5;
   c.srMax=8;
   c.fvgMinAtr=0.3;
   c.fvgMax=20;
   c.fvgLife=100;
   c.obMax=15;
   c.obLife=150;
   c.emaFast=20;
   c.emaMid=50;
   c.emaSlow=200;
   c.atrLen=14;
   c.rsiLen=14;
   c.rsiOb=70.0;
   c.rsiOs=30.0;
   c.macdFast=12;
   c.macdSlow=26;
   c.macdSignal=9;
   c.dmiLen=14;
   c.ctxTf=PERIOD_D1;
   c.ctxLen=200;
   c.setupTf=PERIOD_H1;
   c.setupLen=50;
   c.htfFilter=true;
   c.htfVetoOn=true;
   c.volMaLen=20;
   c.volSpikeR=2.2;
   c.volRVH=1.8;
   c.volRH=1.2;
   c.volRN=0.8;
   c.volRL=0.4;
   c.rvMin=1.2;
   c.wTrend=15.0;
   c.wStruct=15.0;
   c.wLiq=12.0;
   c.wLoc=8.0;
   c.wSr=10.0;
   c.wCandle=10.0;
   c.wVol=8.0;
   c.wMom=7.0;
   c.wSess=4.0;
   c.wMtf=4.0;
   c.scrNoTrade=49;
   c.scrWeak=64;
   c.scrSetup=74;
   c.scrStrong=84;
   c.minQuality=TM2_MINQ_SETUP;
   c.scoreMargin=8;
   c.ablation=TM2_ABL_E;
   c.slAtrMul=1.5;
   c.slPadAtr=0.2;
   c.slMinAtr=0.5;
   c.slMaxAtr=3.0;
   c.rr1=1.0;
   c.rr2=2.0;
   c.rr3=3.0;
   c.rrMin=1.5;
   c.maxDay=4;
   c.coolBars=8;
   c.riskEquity=10000.0;
   c.riskPct=1.0;
   c.riskMaxLev=20.0;
   c.riskMmr=0.005;
   c.riskFeeSlipPct=0.08;
   c.riskMaxLosses=3;
   return(c);
  }

//+------------------------------------------------------------------+
//| Neutral bar; every price field explicitly set                    |
//+------------------------------------------------------------------+
TM2Bar BaseBar()
  {
   TM2Bar b;
   ZeroMemory(b);
   b.time=D'2024.01.03 12:00';
   b.open=100.0;
   b.high=101.0;
   b.low=99.0;
   b.close=100.0;
   b.vol=100;
   b.volMA=100.0;
   b.volSma20=100.0;
   b.mintick=0.01;
   b.prevOpen=99.0;
   b.prevClose=99.5;
   b.prevHigh=101.0;
   b.prevLow=98.0;
   b.high2=EMPTY_VALUE;
   b.low2=EMPTY_VALUE;
   b.atr=10.0;
   b.atrPct=1.0;
   b.atrSafe=10.0;
   b.emaF=99.0;
   b.emaM=98.0;
   b.emaS=97.0;
   b.rsi=50.0;
   b.macdHist=0.0;
   b.macdPrevHist=0.0;
   b.diPlus=20.0;
   b.diMinus=20.0;
   b.adx=EMPTY_VALUE;
   b.slope20=0.0;
   b.bbMid=100.0;
   b.bbUp=101.0;
   b.bbLo=99.0;
   b.bbWidth=2.0;
   b.bbWidthMA=2.0;
   b.bbwPct=50.0;
   b.isSqueeze=false;
   b.bbExpand=false;
   b.pivH=EMPTY_VALUE;
   b.pivL=EMPTY_VALUE;
   b.srPivH=EMPTY_VALUE;
   b.srPivL=EMPTY_VALUE;
   b.swingHi=EMPTY_VALUE;
   b.swingLo=EMPTY_VALUE;
   b.ctxEma=100.0;
   b.setupEma=100.0;
   b.ctxOk=true;
   b.setupOk=true;
   b.ctxDir=0;
   b.setupDir=0;
   b.mtfHierOk=true;
   b.sessName=TM2_SESS_NONE;
   b.sessHi=EMPTY_VALUE;
   b.sessLo=EMPTY_VALUE;
   b.pdh=EMPTY_VALUE;
   b.pdl=EMPTY_VALUE;
   b.pwh=EMPTY_VALUE;
   b.pwl=EMPTY_VALUE;
   b.hasPd=false;
   b.hasPw=false;
   b.isOverext=false;
   b.btcClose=0.0;
   b.btcEma=0.0;
   b.btcRsi=50.0;
   b.btcAtr=0.0;
   b.btcOk=false;
   b.btcNeed=false;
   b.isCrypto=false;
   b.isWeekend=false;
   b.weekendBlocked=false;
   return(b);
  }

//+------------------------------------------------------------------+
//| Signal bar used by the O/P sections                              |
//+------------------------------------------------------------------+
TM2Bar SignalBar()
  {
   TM2Bar b=BaseBar();
   b.open=99.0;
   b.close=100.0;
   b.high=102.0;
   b.low=98.0;
   b.prevOpen=98.5;
   b.prevClose=99.0;
   b.emaF=99.0;
   b.emaM=98.0;
   b.emaS=97.0;
   b.slope20=0.05;
   b.adx=EMPTY_VALUE;
   b.rsi=50.0;
   b.macdHist=0.0;
   b.macdPrevHist=0.0;
   b.ctxDir=1;
   b.setupDir=1;
   b.mtfHierOk=true;
   return(b);
  }

TM2Config SignalCfg()
  {
   TM2Config c=Cfg();
   c.gateRegime=false;
   c.gateObstacle=false;
   c.gateOverext=false;
   c.gateCircuit=false;
   c.gateRisk=false;
   c.htfFilter=false;
   c.htfVetoOn=false;
   c.modeFilterOn=false;
   c.modeCOn=false;
   c.entryMode=TM2_ENTRY_MARKET;
   c.coolBars=0;
   c.wTrend=0.0;
   c.wStruct=0.0;
   c.wLiq=0.0;
   c.wLoc=0.0;
   c.wSr=0.0;
   c.wCandle=0.0;
   c.wVol=0.0;
   c.wMom=0.0;
   c.wSess=0.0;
   c.wMtf=1.0;
   return(c);
  }

void NewState(TM2EngineState &st)
  {
   ZeroMemory(st);
   TM2StateInit(st);
  }

void Step(const TM2Config &cfg,TM2EngineState &st,TM2Bar &b,const int idx,TM2BarOut &out)
  {
   ZeroMemory(out);
   TM2EngineStep(cfg,st,b,idx,out);
  }

TM2ModeInput ModeIn()
  {
   TM2ModeInput m;
   ZeroMemory(m);
   m.regimeCode=0;
   m.regimeDir=0;
   m.ctxDir=0;
   m.setupDir=0;
   m.dir=0;
   m.open=100.0;
   m.close=100.0;
   m.high=101.0;
   m.low=99.0;
   m.emaF=100.0;
   m.atrSafe=10.0;
   m.fvgBullPx=EMPTY_VALUE;
   m.fvgBearPx=EMPTY_VALUE;
   m.obBullPx=EMPTY_VALUE;
   m.obBearPx=EMPTY_VALUE;
   m.sweepAgeBull=999999;
   m.sweepAgeBear=999999;
   m.sweepBullPx=EMPTY_VALUE;
   m.sweepBearPx=EMPTY_VALUE;
   m.nearestRes=EMPTY_VALUE;
   m.nearestSup=EMPTY_VALUE;
   m.modeAOn=true;
   m.modeBOn=true;
   m.modeCOn=false;
   m.modeSweepBars=3;
   m.modePullTol=0.35;
   m.modeRangeTol=0.35;
   return(m);
  }

double PineVolScore(const bool expand,const bool squeeze)
  {
// Pine tm_volScore (dead code in v2.1, kept here as the documented formula)
   return(expand ? 1.0 : (squeeze ? -1.0 : 0.0));
  }

//+------------------------------------------------------------------+
//| A. Math / config / time (6)                                      |
//+------------------------------------------------------------------+
void RunA()
  {
   Record("A1",Near(TM2Clamp(1.5,0,1),1.0) && Near(TM2Clamp(-1.0,0,1),0.0) &&
          Near(TM2Clamp(0.4,0,1),0.4),"clamp");

   const datetime t=D'2024.01.03 12:00';
   Record("A2",TM2LocalMinute(t,180,-300)==240,"local minute");

   Record("A3",TM2SessionName(1080)==TM2_SESS_ASIA &&
          TM2SessionName(180)==TM2_SESS_LONDON &&
          TM2SessionName(480)==TM2_SESS_LONDON_NY &&
          TM2SessionName(720)==TM2_SESS_NY &&
          TM2SessionName(960)==TM2_SESS_NONE,"session map");

   Record("A4",TM2IsNewServerDay(D'2024.01.02 23:59',D'2024.01.03 00:00') &&
          !TM2IsNewServerDay(D'2024.01.03 01:00',D'2024.01.03 23:00') &&
          TM2IsNewServerWeek(D'2024.01.07 23:00',D'2024.01.08 00:00') &&
          !TM2IsNewServerWeek(D'2024.01.08 00:00',D'2024.01.09 00:00'),"day/week");

   TM2EngineState st;
   NewState(st);
   for(int i=0; i<51; i++)
      TM2PushEvent(st,TM2_EVT_SWEEP,1,i,D'2024.01.03 00:00',(double)i);
   Record("A5",st.evtCount==50 && st.evt[0].srcBar==1 && st.evt[49].srcBar==50,
          "ring 50");

   TM2Config cfg=Cfg();
   const string canon=TM2ConfigCanonical(cfg);
   int semis=0;
   for(int i=0; i<StringLen(canon); i++)
      if(StringGetCharacter(canon,i)==';')
         semis++;
   const uint h1=TM2Fnv1a("a");
   const uint h2=TM2Fnv1a("foobar");
   Record("A6",h1==(uint)0xE40C292C && h2==(uint)0xBF9CF968 && semis==119 &&
          StringFind(canon,"version=1.0.0;srvOffsetMin=180;mktOffsetMin=-300;")==0,
          "fnv/canonical");
  }

//+------------------------------------------------------------------+
//| B. Regime (8)                                                    |
//+------------------------------------------------------------------+
void RunB()
  {
   TM2Config cfg=Cfg();
   int code=0;
   int dir=0;

   TM2ClassifyRegime(25.0,false,0.0,true,false,50.0,cfg,code,dir);
   Record("B1",code==1 && dir==1,"trend up");

   TM2ClassifyRegime(25.0,false,0.0,false,true,50.0,cfg,code,dir);
   Record("B2",code==1 && dir==-1,"trend down");

   TM2ClassifyRegime(25.0,true,0.02,true,false,50.0,cfg,code,dir);
   Record("B3",code==-1 && dir==0,"squeeze chop");

   TM2ClassifyRegime(25.0,true,0.20,true,false,50.0,cfg,code,dir);
   Record("B4",code==0 && dir==0,"squeeze range");

   TM2ClassifyRegime(17.0,false,0.0,false,false,50.0,cfg,code,dir);
   Record("B5",code==-1,"adx chop");

   TM2ClassifyRegime(18.0,false,0.0,false,false,50.0,cfg,code,dir);
   Record("B6",code==0,"adx 18 not chop");

   TM2ClassifyRegime(22.0,false,0.0,true,false,50.0,cfg,code,dir);
   Record("B7",code==1 && dir==1,"adx 22 trending");

   double w1[];
   double w0[];
   double wm[];
   TM2EffectiveWeights(cfg,1,w1);
   TM2EffectiveWeights(cfg,0,w0);
   TM2EffectiveWeights(cfg,-1,wm);
   double t1=0.0;
   double t0=0.0;
   double tm=0.0;
   for(int i=0; i<TM2_GROUP_COUNT; i++)
     {
      t1+=w1[i];
      t0+=w0[i];
      tm+=wm[i];
     }
   Record("B8",Near(t1,98.65) && Near(t0,95.2) && Near(tm,74.5) &&
          Near(PineVolScore(true,false),1.0) &&
          Near(PineVolScore(false,true),-1.0) &&
          Near(PineVolScore(false,false),0.0),"weights/volScore");
  }

//+------------------------------------------------------------------+
//| C. Candle / overextension (8)                                    |
//+------------------------------------------------------------------+
void RunC()
  {
   TM2Config cfg=Cfg();
   TM2EngineState st;
   TM2Bar b;
   TM2BarOut o;

   NewState(st);
   b=BaseBar();
   b.open=100.0;
   b.close=104.0;
   b.high=106.0;
   b.low=99.0;
   Step(cfg,st,b,0,o);
   Record("C1",o.cpBull==0.0 && o.cpBear==0.0 && !o.pinBull && !o.dispBull &&
          !o.rejBull && NearT(o.extCandle,0.7,1e-9),"candle dims");

   NewState(st);
   b=BaseBar();
   b.atr=2.0;
   b.open=100.0;
   b.close=104.0;
   b.high=105.0;
   b.low=99.0;
   Step(cfg,st,b,0,o);
   const bool dispOn=o.dispBull;
   NewState(st);
   b.high=105.2;
   Step(cfg,st,b,0,o);
   Record("C2",dispOn && !o.dispBull,"disp strict");

   NewState(st);
   b=BaseBar();
   b.atr=2.0;
   b.open=100.0;
   b.close=102.0;
   b.high=102.2;
   b.low=96.0;
   Step(cfg,st,b,0,o);
   const bool pinOn=o.pinBull;
   NewState(st);
   b.low=96.01;
   Step(cfg,st,b,0,o);
   Record("C3",pinOn && !o.pinBull,"pin strict");

   NewState(st);
   b=BaseBar();
   b.atr=10.0;
   b.prevOpen=105.0;
   b.prevClose=100.0;
   b.open=99.0;
   b.close=106.0;
   b.high=106.5;
   b.low=98.5;
   Step(cfg,st,b,0,o);
   const bool engOn=o.engBull;
   NewState(st);
   b.open=100.1;
   Step(cfg,st,b,0,o);
   Record("C4",engOn && !o.engBull,"engulf");

   NewState(st);
   b=BaseBar();
   b.atr=10.0;
   b.open=100.0;
   b.close=103.0;
   b.high=108.5;
   b.low=98.5;
   Step(cfg,st,b,0,o);
   const bool rejOn=o.rejBull;
   NewState(st);
   b.high=108.49;
   Step(cfg,st,b,0,o);
   Record("C5",rejOn && !o.rejBull,"rejection strict");

   const double cp1=TM2CandleScore(true,true,false,true,false,false,false,false);
   Record("C6",Near(cp1,2.8/3.0),"cp bull 2.8");

   const double cp2=TM2CandleScore(false,false,false,false,true,true,false,true);
   Record("C7",Near(cp2,-2.8/3.0),"cp bear 2.8");

   const double cp3=TM2CandleScore(true,false,false,false,true,false,false,false);
   Record("C8",Near(cp3,0.0) && Near(TM2ExtEma(2020.0,2000.0,10.0),2.0) &&
          TM2IsOverextended(2.3,0.0,2.2,2.6),"tie/ext");
  }

//+------------------------------------------------------------------+
//| D. Structure (10)                                                |
//+------------------------------------------------------------------+
void RunD()
  {
   TM2Config cfg=Cfg();
   TM2EngineState st;
   TM2Bar b;
   TM2BarOut o;

//--- D1
   NewState(st);
   st.trend=1;
   st.hasSwingHi=true;
   st.swingHi=100.0;
   st.hasPrevHigh=true;
   st.prevHigh=90.0;
   b=BaseBar();
   b.prevClose=99.0;
   b.close=101.0;
   Step(cfg,st,b,0,o);
   Record("D1",o.bosUp && !o.bosDown,"bos up");

//--- D2
   NewState(st);
   st.trend=0;
   st.hasSwingHi=true;
   st.swingHi=100.0;
   st.hasPrevHigh=true;
   st.prevHigh=90.0;
   b=BaseBar();
   b.prevClose=99.0;
   b.close=101.0;
   Step(cfg,st,b,0,o);
   Record("D2",!o.bosUp && !o.chochUp,"trend 0 no break");

//--- D3
   NewState(st);
   st.trend=-1;
   st.hasSwingHi=true;
   st.swingHi=100.0;
   st.hasPrevHigh=true;
   st.prevHigh=90.0;
   b=BaseBar();
   b.prevClose=99.0;
   b.close=101.0;
   Step(cfg,st,b,0,o);
   Record("D3",o.chochUp && !o.bosUp,"choch up");

//--- D4
   NewState(st);
   st.trend=-1;
   st.hasSwingLo=true;
   st.swingLo=90.0;
   st.hasPrevLow=true;
   st.prevLow=95.0;
   b=BaseBar();
   b.prevClose=91.0;
   b.close=89.0;
   b.low=88.0;
   Step(cfg,st,b,0,o);
   Record("D4",o.bosDown && !o.bosUp,"bos down");

//--- D5
   NewState(st);
   st.trend=1;
   st.hasSwingLo=true;
   st.swingLo=90.0;
   st.hasPrevLow=true;
   st.prevLow=95.0;
   b=BaseBar();
   b.prevClose=91.0;
   b.close=89.0;
   b.low=88.0;
   Step(cfg,st,b,0,o);
   Record("D5",o.chochDown && !o.bosDown,"choch down");

//--- D6
   NewState(st);
   st.trend=0;
   st.hasSwingLo=true;
   st.swingLo=90.0;
   st.hasPrevLow=true;
   st.prevLow=95.0;
   b=BaseBar();
   b.prevClose=91.0;
   b.close=89.0;
   b.low=88.0;
   Step(cfg,st,b,0,o);
   Record("D6",!o.bosDown && !o.chochDown,"trend 0 no break down");

//--- D7
   NewState(st);
   st.trend=-1;
   st.hasSwingHi=true;
   st.swingHi=100.0;
   st.hasPrevHigh=true;
   st.prevHigh=90.0;
   b=BaseBar();
   b.atr=2.0;
   b.prevOpen=98.5;
   b.prevClose=99.0;
   b.open=99.0;
   b.close=104.0;
   b.high=104.4;
   b.low=98.9;
   Step(cfg,st,b,0,o);
   const bool mssOn=o.mssUp;
   NewState(st);
   b.open=102.0;
   b.high=104.4;
   b.low=101.9;
   Step(cfg,st,b,0,o);
   Record("D7",mssOn && !o.mssUp,"mss needs displacement");

//--- D8
   NewState(st);
   st.trend=0;
   st.hasSwingHi=true;
   st.swingHi=100.0;
   st.hasSwingLo=true;
   st.swingLo=90.0;
   b=BaseBar();
   b.pivHOk=true;
   b.pivH=105.0;
   b.pivLOk=true;
   b.pivL=95.0;
   Step(cfg,st,b,0,o);
   const int upTrend=o.trend;
   NewState(st);
   st.trend=0;
   st.hasSwingHi=true;
   st.swingHi=100.0;
   st.hasSwingLo=true;
   st.swingLo=90.0;
   b=BaseBar();
   b.pivHOk=true;
   b.pivH=95.0;
   b.pivLOk=true;
   b.pivL=85.0;
   Step(cfg,st,b,0,o);
   const int dnTrend=o.trend;
   NewState(st);
   st.trend=0;
   st.hasSwingHi=true;
   st.swingHi=100.0;
   st.hasSwingLo=true;
   st.swingLo=90.0;
   b=BaseBar();
   b.pivHOk=true;
   b.pivH=105.0;
   b.pivLOk=true;
   b.pivL=85.0;
   Step(cfg,st,b,0,o);
   Record("D8",upTrend==1 && dnTrend==-1 && o.trend==0,"swing trend");

//--- D9
   NewState(st);
   st.hasBrk=true;
   st.brkBar=10;
   st.brkDir=1;
   st.brkLevel=100.0;
   b=BaseBar();
   b.atr=2.0;
   b.low=100.9;
   b.close=101.0;
   Step(cfg,st,b,12,o);
   const bool rt12=o.retestUp;
   NewState(st);
   st.hasBrk=true;
   st.brkBar=10;
   st.brkDir=1;
   st.brkLevel=100.0;
   b=BaseBar();
   b.atr=2.0;
   b.low=100.9;
   b.close=101.0;
   Step(cfg,st,b,10,o);
   const bool rt10=o.retestUp;
   NewState(st);
   st.hasBrk=true;
   st.brkBar=10;
   st.brkDir=1;
   st.brkLevel=100.0;
   b=BaseBar();
   b.atr=2.0;
   b.low=100.9;
   b.close=101.0;
   Step(cfg,st,b,21,o);
   Record("D9",rt12 && !rt10 && !o.retestUp,"retest window");

//--- D10
   NewState(st);
   st.hasBrk=true;
   st.brkBar=11;
   st.brkDir=1;
   st.brkLevel=100.0;
   b=BaseBar();
   b.atr=2.0;
   b.close=99.3;
   Step(cfg,st,b,12,o);
   const bool failOn=o.failUp;
   NewState(st);
   st.hasBrk=true;
   st.brkBar=11;
   st.brkDir=1;
   st.brkLevel=100.0;
   b=BaseBar();
   b.atr=2.0;
   b.close=99.4;
   Step(cfg,st,b,12,o);
   const bool failOff=!o.failUp;
   NewState(st);
   st.hasSwingHi=true;
   st.swingHi=100.0;
   b=BaseBar();
   b.atr=2.0;
   b.pivHOk=true;
   b.pivH=105.0;
   Step(cfg,st,b,0,o);
   const bool hh=o.hh;
   NewState(st);
   st.hasSwingHi=true;
   st.swingHi=100.0;
   b=BaseBar();
   b.atr=2.0;
   b.pivHOk=true;
   b.pivH=100.05;
   Step(cfg,st,b,0,o);
   Record("D10",failOn && failOff && hh && o.eqHi,"fail/hh/eq");
  }

//+------------------------------------------------------------------+
//| E. Liquidity / session (8)                                       |
//+------------------------------------------------------------------+
void RunE()
  {
   TM2Config cfg=Cfg();
   TM2EngineState st;
   TM2Bar b;
   TM2BarOut o;

//--- E1
   NewState(st);
   b=BaseBar();
   b.open=180.5;
   b.high=181.5;
   b.low=179.0;
   b.close=181.0;
   b.prevOpen=180.0;
   b.prevClose=180.2;
   b.pdl=180.0;
   Step(cfg,st,b,0,o);
   Record("E1",Near(o.gLiq,1.0) && o.evtKind==TM2_EVT_SWEEP && o.evtDir==1 &&
          Near(o.evtLevel,180.0) && Near(o.lastSweepBullPx,179.0),"pdl sweep");

//--- E2
   TM2Config cfgNoPw=Cfg();
   cfgNoPw.liqPwOn=false;
   NewState(st);
   b=BaseBar();
   b.open=180.5;
   b.high=181.5;
   b.low=179.0;
   b.close=181.0;
   b.prevClose=180.2;
   b.pwl=180.0;
   Step(cfgNoPw,st,b,0,o);
   const bool pwOff=Near(o.gLiq,0.0);
   TM2Config cfgPw=Cfg();
   cfgPw.liqPwOn=true;
   NewState(st);
   Step(cfgPw,st,b,0,o);
   Record("E2",pwOff && Near(o.gLiq,1.0),"pwl off/on");

//--- E3
   NewState(st);
   st.hasSessLo=true;
   st.sessLo=190.0;
   st.sessPrev=TM2_SESS_NONE;
   b=BaseBar();
   b.open=190.5;
   b.high=191.5;
   b.low=189.0;
   b.close=191.0;
   b.pdl=180.0;
   Step(cfg,st,b,0,o);
   const bool sessSweep=Near(o.gLiq,1.0) && Near(o.evtLevel,190.0);
   NewState(st);
   st.hasSessLo=true;
   st.sessLo=190.0;
   st.sessPrev=TM2_SESS_ASIA;
   b=BaseBar();
   b.open=190.5;
   b.high=191.5;
   b.low=189.0;
   b.close=191.0;
   b.sessName=TM2_SESS_ASIA;
   Step(cfg,st,b,0,o);
   Record("E3",sessSweep && Near(o.gLiq,0.0) && Near(o.sessLo,189.0),"session sweep");

//--- E4
   NewState(st);
   b=BaseBar();
   b.open=199.5;
   b.high=201.0;
   b.low=198.5;
   b.close=199.0;
   b.prevClose=200.2;
   b.pdh=200.0;
   Step(cfg,st,b,0,o);
   Record("E4",Near(o.gLiq,-1.0) && Near(o.evtLevel,200.0) && Near(o.lastSweepBearPx,201.0),
          "pdh sweep");

//--- E5
   NewState(st);
   st.hasSwingLo=true;
   st.swingLo=90.0;
   b=BaseBar();
   b.atr=40.0;
   b.atrSafe=40.0;
   b.pivLOk=true;
   b.pivL=89.0;
   b.low=88.5;
   b.open=90.5;
   b.close=91.0;
   b.prevClose=90.4;
   Step(cfg,st,b,0,o);
   const bool eqSweep=o.eqLo && Near(o.gLiq,1.0);
   NewState(st);
   st.hasSwingLo=true;
   st.swingLo=90.0;
   b=BaseBar();
   b.atr=40.0;
   b.atrSafe=40.0;
   b.pivLOk=true;
   b.pivL=89.0;
   b.low=88.5;
   b.open=90.5;
   b.close=89.5;
   b.prevClose=90.4;
   Step(cfg,st,b,0,o);
   Record("E5",eqSweep && Near(o.gLiq,0.0),"eq low sweep");

//--- E6
   NewState(st);
   b=BaseBar();
   b.sessName=TM2_SESS_ASIA;
   b.high=105.0;
   b.low=95.0;
   Step(cfg,st,b,0,o);
   const double h1=o.sessHi;
   const double l1=o.sessLo;
   b=BaseBar();
   b.sessName=TM2_SESS_LONDON;
   b.high=110.0;
   b.low=90.0;
   Step(cfg,st,b,1,o);
   const double h2=o.sessHi;
   const double l2=o.sessLo;
   b=BaseBar();
   b.sessName=TM2_SESS_NONE;
   b.high=120.0;
   b.low=80.0;
   Step(cfg,st,b,2,o);
   const double h3=o.sessHi;
   const double l3=o.sessLo;
   b=BaseBar();
   b.sessName=TM2_SESS_LONDON;
   b.high=100.0;
   b.low=96.0;
   Step(cfg,st,b,3,o);
   Record("E6",Near(h1,105.0) && Near(l1,95.0) && Near(h2,110.0) && Near(l2,90.0) &&
          Near(h3,110.0) && Near(l3,90.0) && Near(o.sessHi,110.0) && Near(o.sessLo,90.0),
          "session merge");

//--- E7
   Record("E7",TM2ModeBReady(true,2,3,true,true,100.0,95.0) &&
          !TM2ModeBReady(true,4,3,true,true,100.0,95.0),"sweep age");

//--- E8
   TM2Config cfgW=Cfg();
   Record("E8",TM2WeekendBlocked(cfgW,true,true,0.7,0.6) &&
          !TM2WeekendBlocked(cfgW,true,true,0.8,0.6) &&
          TM2WeekendBlocked(cfgW,true,true,0.8,0.6-1e-9) &&
          !TM2WeekendBlocked(cfgW,false,true,0.1,0.1),"weekend strict");
  }

//+------------------------------------------------------------------+
//| F. Zones / FVG / OB / obstacle (10)                              |
//+------------------------------------------------------------------+
void RunF()
  {
   TM2Config cfg=Cfg();
   TM2EngineState st;
   TM2Bar b;
   TM2BarOut o;

//--- F1
   NewState(st);
   TM2ZoneAdd(st,100.0,1,2.0,0.5,8);
   Record("F1",st.srCount==1 && Near(st.sr[0].top,100.5) && Near(st.sr[0].bot,99.5) &&
          st.sr[0].touches==1 && st.sr[0].side==1,"zone add");

//--- F2
   TM2ZoneAdd(st,100.9,1,2.0,0.5,8);
   Record("F2",st.srCount==1 && st.sr[0].touches==2 && Near(st.sr[0].top,100.5) &&
          Near(st.sr[0].bot,99.5),"zone merge");

//--- F3
   NewState(st);
   TM2ZoneAdd(st,100.0,1,2.0,0.5,8);
   TM2ZoneAdd(st,101.0,1,2.0,0.5,8);
   Record("F3",st.srCount==2,"zone no merge at width");

//--- F4
   NewState(st);
   TM2ZoneAdd(st,100.0,1,2.0,0.5,2);
   TM2ZoneAdd(st,200.0,1,2.0,0.5,2);
   TM2ZoneAdd(st,300.0,1,2.0,0.5,2);
   Record("F4",st.srCount==2 && Near(st.sr[0].top,200.5) && Near(st.sr[1].top,300.5),
          "zone cap");

//--- F5
   NewState(st);
   TM2ZoneAdd(st,100.0,1,2.0,0.5,8);
   Record("F5",TM2NearSupport(st,98.9,2.0) && !TM2NearSupport(st,98.89,2.0),"near support");

//--- F6
   NewState(st);
   TM2ZoneAdd(st,100.0,-1,2.0,0.5,8);
   Record("F6",TM2NearResistance(st,101.1,2.0) && !TM2NearResistance(st,101.11,2.0),
          "near resistance");

//--- F7
   NewState(st);
   b=BaseBar();
   b.atr=2.0;
   b.atrSafe=2.0;
   b.high2=100.0;
   b.low=101.0;
   b.high=102.0;
   b.open=100.5;
   b.close=101.0;
   b.prevClose=100.4;
   Step(cfg,st,b,0,o);
   const bool fvgOn=o.fvgCount==1 && Near(o.fvgBullPx,100.5) &&
                    Near(st.fvg[0].top,101.0) && Near(st.fvg[0].bot,100.0);
   NewState(st);
   b=BaseBar();
   b.atr=2.0;
   b.atrSafe=2.0;
   b.high2=100.0;
   b.low=100.59;
   b.high=102.0;
   b.open=100.5;
   b.close=100.59;
   b.prevClose=100.4;
   Step(cfg,st,b,0,o);
   Record("F7",fvgOn && o.fvgCount==0,"fvg min gap");

//--- F8
   NewState(st);
   st.fvgCount=1;
   st.fvg[0].top=101.0;
   st.fvg[0].bot=100.0;
   st.fvg[0].srcBar=0;
   st.fvg[0].side=1;
   st.fvg[0].dead=false;
   b=BaseBar();
   b.atr=2.0;
   b.atrSafe=2.0;
   b.low=100.5;
   b.high=101.0;
   b.close=100.8;
   Step(cfg,st,b,101,o);
   const bool ageDead=EmptyD(o.fvgBullPx) && o.fvgCount==1;
   NewState(st);
   st.fvgCount=1;
   st.fvg[0].top=101.0;
   st.fvg[0].bot=100.0;
   st.fvg[0].srcBar=0;
   st.fvg[0].side=1;
   st.fvg[0].dead=false;
   b=BaseBar();
   b.atr=2.0;
   b.atrSafe=2.0;
   b.low=100.0;
   b.high=101.0;
   b.close=100.5;
   Step(cfg,st,b,50,o);
   Record("F8",ageDead && EmptyD(o.fvgBullPx),"fvg dead rules");

//--- F9
   NewState(st);
   b=BaseBar();
   b.atr=2.0;
   b.atrSafe=2.0;
   b.prevOpen=100.0;
   b.prevClose=99.0;
   b.open=99.5;
   b.close=104.0;
   b.high=104.2;
   b.low=99.1;
   Step(cfg,st,b,10,o);
   const bool obMade=o.obCount==1 && Near(st.ob[0].top,100.0) &&
                     Near(st.ob[0].bot,99.0) && st.ob[0].srcBar==9 &&
                     Near(o.obBullPx,100.0);
   b=BaseBar();
   b.atr=2.0;
   b.atrSafe=2.0;
   b.open=100.0;
   b.close=100.0;
   b.high=101.0;
   b.low=99.0;
   Step(cfg,st,b,11,o);
   const bool obDead=EmptyD(o.obBullPx) && o.obCount==1;
   NewState(st);
   b=BaseBar();
   b.atr=2.0;
   b.atrSafe=2.0;
   b.prevOpen=100.0;
   b.prevClose=99.0;
   b.open=99.5;
   b.close=104.0;
   b.high=104.2;
   b.low=99.1;
   Step(cfg,st,b,10,o);
   b=BaseBar();
   b.atr=2.0;
   b.atrSafe=2.0;
   b.prevOpen=105.0;
   b.prevClose=104.0;
   b.open=104.2;
   b.close=108.5;
   b.high=108.7;
   b.low=104.1;
   Step(cfg,st,b,11,o);
   Record("F9",obMade && obDead && o.obCount==2 && Near(o.obBullPx,105.0),"ob top");

//--- F10
   NewState(st);
   st.srCount=2;
   st.sr[0].top=101.5;
   st.sr[0].bot=101.0;
   st.sr[0].side=-1;
   st.sr[0].broken=false;
   st.sr[1].top=99.0;
   st.sr[1].bot=98.5;
   st.sr[1].side=1;
   st.sr[1].broken=false;
   st.obCount=1;
   st.ob[0].top=101.0;
   st.ob[0].bot=100.5;
   st.ob[0].side=-1;
   st.ob[0].srcBar=1;
   st.ob[0].dead=false;
   st.fvgCount=1;
   st.fvg[0].top=200.0;
   st.fvg[0].bot=199.0;
   st.fvg[0].side=-1;
   st.fvg[0].srcBar=1;
   st.fvg[0].dead=false;
   b=BaseBar();
   b.close=100.0;
   b.atrSafe=2.0;
   b.pdh=100.2;
   b.hasPd=true;
   double res=EMPTY_VALUE;
   double sup=EMPTY_VALUE;
   TM2NearestLevels(b,st,res,sup);
   Record("F10",Near(res,100.5) && Near(sup,99.0),"nearest levels");
  }

//+------------------------------------------------------------------+
//| G. Volume / VWAP / OBV (10)                                      |
//+------------------------------------------------------------------+
void RunG()
  {
   TM2Config cfg=Cfg();
   TM2EngineState st;
   TM2Bar b;
   TM2BarOut o;

//--- G1
   NewState(st);
   b=BaseBar();
   b.vol=221;
   b.volMA=100.0;
   b.volSma20=100.0;
   Step(cfg,st,b,0,o);
   Record("G1",Near(o.volRatio,2.21) && o.volBucket==TM2_BUCKET_TIM && o.isTim,"tim bucket");

//--- G2
   NewState(st);
   b=BaseBar();
   b.vol=219;
   b.volMA=100.0;
   b.volSma20=100.0;
   Step(cfg,st,b,0,o);
   Record("G2",Near(o.volRatio,2.19) && o.volBucket==TM2_BUCKET_VERYHIGH && !o.isTim,
          "just below tim");

//--- G3
   Record("G3",TM2VolBucket(180.0,100.0,2.2,1.8,1.2,0.8,0.4)==TM2_BUCKET_VERYHIGH,
          "very high boundary");

//--- G4
   NewState(st);
   b=BaseBar();
   b.vol=100;
   b.volMA=0.0;
   b.volSma20=0.0;
   Step(cfg,st,b,0,o);
   Record("G4",Near(o.volRatio,0.0) && o.volBucket==TM2_BUCKET_TIM && !o.isTim,
          "ma zero");

//--- G5
   NewState(st);
   b=BaseBar();
   b.vol=100;
   b.volMA=EMPTY_VALUE;
   b.volSma20=EMPTY_VALUE;
   Step(cfg,st,b,0,o);
   Record("G5",Near(o.volRatio,0.0) && o.volBucket==TM2_BUCKET_VERYLOW &&
          EmptyD(o.gVolume),"ma na");

//--- G6
   Record("G6",Near(TM2VolumeScore(false,1.19,1.2,101.0,100.0,0.0),0.0) &&
          Near(TM2VolumeScore(false,1.20,1.2,101.0,100.0,0.0),0.42),"relvol threshold");

//--- G7
   Record("G7",Near(TM2VolumeScore(true,2.0,1.2,101.0,100.0,1.0),1.0) &&
          Near(TM2VolumeScore(true,2.0,1.2,99.0,100.0,-1.0),-1.0) &&
          Near(TM2VolumeScore(false,1.2,1.2,101.0,100.0,0.0),0.42),"volume score");

//--- G8
   NewState(st);
   b=BaseBar();
   b.open=10.0;
   b.high=11.0;
   b.low=9.0;
   b.close=10.0;
   b.prevClose=10.0;
   b.vol=10;
   Step(cfg,st,b,0,o);
   const double obv0=o.obv;
   b=BaseBar();
   b.open=10.0;
   b.high=12.0;
   b.low=10.0;
   b.close=11.0;
   b.prevClose=10.0;
   b.vol=20;
   Step(cfg,st,b,1,o);
   const double obv1=o.obv;
   b=BaseBar();
   b.open=11.0;
   b.high=11.0;
   b.low=9.0;
   b.close=10.0;
   b.prevClose=11.0;
   b.vol=30;
   Step(cfg,st,b,2,o);
   const double obv2=o.obv;
   b=BaseBar();
   b.open=10.0;
   b.high=10.0;
   b.low=8.0;
   b.close=9.0;
   b.prevClose=10.0;
   b.vol=40;
   Step(cfg,st,b,3,o);
   Record("G8",Near(obv0,0.0) && Near(obv1,20.0) && Near(obv2,-10.0) &&
          Near(o.obv,-50.0) && Near(o.obvSlope,-50.0),"obv series");

//--- G9
   NewState(st);
   b=BaseBar();
   b.time=D'2024.01.03 10:00';
   b.high=101.0;
   b.low=99.0;
   b.close=100.0;
   b.open=100.0;
   b.vol=10;
   Step(cfg,st,b,0,o);
   const double v1=o.vwap;
   b=BaseBar();
   b.time=D'2024.01.03 10:05';
   b.high=103.0;
   b.low=101.0;
   b.close=102.0;
   b.open=102.0;
   b.prevClose=100.0;
   b.vol=30;
   Step(cfg,st,b,1,o);
   const double v2=o.vwap;
   b=BaseBar();
   b.time=D'2024.01.04 10:00';
   b.high=111.0;
   b.low=109.0;
   b.close=110.0;
   b.open=110.0;
   b.prevClose=102.0;
   b.vol=10;
   Step(cfg,st,b,2,o);
   Record("G9",Near(v1,100.0) && Near(v2,101.5) && Near(o.vwap,110.0),"vwap");

//--- G10
   Record("G10",Near(TM2VwapScore(true,101.0,100.0,2.0),0.5) &&
          NearT(TM2VwapScore(true,101.0,100.0,EMPTY_VALUE),1.0/1.01,1e-12) &&
          Near(TM2VwapScore(true,90.0,100.0,2.0),-1.0),"vwap score");
  }

//+------------------------------------------------------------------+
//| H. Indicators (9)                                                |
//+------------------------------------------------------------------+
void RunH()
  {
   TM2Config cfg=Cfg();
   TM2EngineState st;
   TM2Bar b;
   TM2BarOut o;

//--- H1
   Record("H1",Near(TM2RsiScore(25.0,30.0,70.0),1.0) &&
          Near(TM2RsiScore(75.0,30.0,70.0),-1.0) &&
          Near(TM2RsiScore(50.0,30.0,70.0),0.0) &&
          Near(TM2RsiScore(60.0,30.0,70.0),0.5),"rsi score");

//--- H2
   Record("H2",Near(TM2MacdScore(0.5,true,-0.2),1.0) &&
          Near(TM2MacdScore(0.3,true,0.1),1.0) &&
          Near(TM2MacdScore(0.1,true,0.3),0.5) &&
          Near(TM2MacdScore(-0.1,true,0.05),-1.0) &&
          Near(TM2MacdScore(-0.1,true,-0.3),-0.5),"macd score");

//--- H3
   Record("H3",Near(TM2MomScore(1.0,0.5),0.7) && Near(TM2MomScore(-1.0,-1.0),-1.0),
          "mom score");

//--- H4
   Record("H4",Near(TM2TrendScore(true,false,100.0,100.0),1.0) &&
          Near(TM2TrendScore(false,true,100.0,100.0),-1.0) &&
          Near(TM2TrendScore(false,false,101.0,100.0),0.4) &&
          Near(TM2TrendScore(false,false,99.0,100.0),-0.4) &&
          Near(TM2TrendScore(false,false,100.0,100.0),0.0),"trend score");

//--- H5
   NewState(st);
   b=BaseBar();
   b.close=103.0;
   b.open=102.0;
   b.high=103.2;
   b.low=101.8;
   b.emaF=102.0;
   b.emaM=100.0;
   b.emaS=98.0;
   b.slope20=0.2;
   Step(cfg,st,b,0,o);
   const bool slopeOn=o.emaBull && Near(o.emaSlope20,0.2);
   NewState(st);
   b.slope20=0.03;
   Step(cfg,st,b,0,o);
   Record("H5",slopeOn && !o.emaBull,"slope strict");

//--- H6
   NewState(st);
   b=BaseBar();
   b.close=110.0;
   b.open=109.0;
   b.high=110.5;
   b.low=108.5;
   b.emaF=105.0;
   b.emaM=100.0;
   b.emaS=95.0;
   b.slope20=0.2;
   Step(cfg,st,b,0,o);
   const bool upOn=o.emaBull && !o.emaBear;
   NewState(st);
   b.slope20=0.02;
   Step(cfg,st,b,0,o);
   Record("H6",upOn && !o.emaBull,"ema bull strict");

//--- H7
   Record("H7",Near(TM2ExtEma(2020.0,2000.0,10.0),2.0),"ext ema");

//--- H8
   Record("H8",Near(TM2ExtCandle(1124.0,1100.0,10.0),2.4) &&
          Near(TM2ExtCandle(1126.0,1100.0,10.0),2.6) &&
          !TM2IsOverextended(0.0,2.4,2.2,2.5) &&
          TM2IsOverextended(0.0,2.6,2.2,2.5),"ext candle");

//--- H9
   NewState(st);
   b=BaseBar();
   b.atrPct=0.5;
   Step(cfg,st,b,0,o);
   const bool pctOn=Near(o.atrPct,0.5);
   NewState(st);
   b.atrPct=0.0;
   Step(cfg,st,b,0,o);
   Record("H9",pctOn && Near(o.atrPct,0.0),"atr pct passthrough");
  }

//+------------------------------------------------------------------+
//| I. MTF / BTC / weekend (8)                                       |
//+------------------------------------------------------------------+
void RunI()
  {
   TM2Config cfg=Cfg();
   TM2EngineState st;
   TM2Bar b;
   TM2BarOut o;

//--- I1
   Record("I1",Near(TM2HtfBias(110.0,100.0,true),1.0) &&
          Near(TM2HtfBias(90.0,100.0,true),-1.0) &&
          Near(TM2HtfBias(100.0,100.0,true),0.0) &&
          Near(TM2HtfBias(110.0,100.0,false),0.0),"htf bias");

//--- I2
   Record("I2",TM2MtfHierarchyOk(900,3600,86400) &&
          !TM2MtfHierarchyOk(86400,3600,900) &&
          !TM2MtfHierarchyOk(3600,86400,900),"hierarchy");

//--- I3
   NewState(st);
   b=BaseBar();
   b.mtfHierOk=false;
   b.ctxDir=1;
   b.setupDir=1;
   Step(cfg,st,b,0,o);
   Record("I3",o.mtfCtxDir==0 && o.mtfSetupDir==0 && Near(o.mtfBias,0.0) &&
          Near(o.gMtf,0.0),"hierarchy dirs");

//--- I4
   NewState(st);
   b=BaseBar();
   b.ctxDir=1;
   b.setupDir=1;
   Step(cfg,st,b,0,o);
   const double bias1=o.mtfBias;
   const double gm1=o.gMtf;
   NewState(st);
   b=BaseBar();
   b.ctxDir=1;
   b.setupDir=-1;
   Step(cfg,st,b,0,o);
   const double bias0=o.mtfBias;
   NewState(st);
   b=BaseBar();
   b.ctxDir=-1;
   b.setupDir=-1;
   Step(cfg,st,b,0,o);
   Record("I4",Near(bias1,1.0) && Near(gm1,1.0) && Near(bias0,0.0) &&
          Near(o.mtfBias,-1.0),"mtf bias");

//--- I5
   TM2GateStatus gate;
   TM2Config cfgNoFilter=Cfg();
   cfgNoFilter.htfFilter=false;
   cfgNoFilter.htfVetoOn=false;
   NewState(st);
   b=BaseBar();
   b.setupDir=1;
   TM2EvaluateGates(cfgNoFilter,b,st,-1,gate);
   const bool filterOff=gate.mtfOk;
   TM2Config cfgFilter=Cfg();
   cfgFilter.htfVetoOn=false;
   NewState(st);
   b=BaseBar();
   b.setupDir=0;
   TM2EvaluateGates(cfgFilter,b,st,-1,gate);
   const bool setupZero=gate.mtfOk;
   NewState(st);
   b=BaseBar();
   b.setupDir=1;
   TM2EvaluateGates(cfgFilter,b,st,-1,gate);
   const bool mismatch=gate.mtfOk;
   NewState(st);
   b=BaseBar();
   b.setupDir=1;
   b.mtfHierOk=false;
   TM2EvaluateGates(cfgFilter,b,st,-1,gate);
   Record("I5",filterOff && setupZero && !mismatch && gate.mtfOk,"setup gate");

//--- I6
   NewState(st);
   b=BaseBar();
   b.ctxDir=-1;
   b.mtfHierOk=true;
   TM2Config cfgVeto=Cfg();
   TM2EvaluateGates(cfgVeto,b,st,1,gate);
   const bool vetoOn=gate.mtfOk;
   TM2Config cfgNoVeto=Cfg();
   cfgNoVeto.htfFilter=false;
   cfgNoVeto.htfVetoOn=false;
   NewState(st);
   b=BaseBar();
   b.ctxDir=-1;
   TM2EvaluateGates(cfgNoVeto,b,st,1,gate);
   const bool vetoOff=gate.mtfOk;
   NewState(st);
   b=BaseBar();
   b.ctxDir=0;
   TM2EvaluateGates(cfgFilter,b,st,1,gate);
   Record("I6",!vetoOn && vetoOff && gate.mtfOk,"ctx veto");

//--- I7
   TM2Config sig=SignalCfg();
   NewState(st);
   b=SignalBar();
   b.btcNeed=true;
   b.btcOk=true;
   b.btcClose=98.0;
   b.btcEma=100.0;
   b.btcAtr=1.0;
   b.btcRsi=31.0;
   Step(sig,st,b,0,o);
   Record("I7",o.btcDump && !o.btcPump && !o.gateBtc &&
          o.noTradeReason==TM2_R_BTC_DUMPING && !o.signal,"btc dump veto");

//--- I8
   TM2Config leaderOff=Cfg();
   leaderOff.btcLeaderOn=false;
   const bool needOff=!TM2NeedBtcLeader(leaderOff,"ETHUSDT");
   const bool needBtcSelf=!TM2NeedBtcLeader(cfg,"BTCUSD");
   const bool needAlt=TM2NeedBtcLeader(cfg,"ETHUSDT");
   TM2Config sig2=SignalCfg();
   NewState(st);
   b=SignalBar();
   b.btcNeed=false;
   b.btcOk=true;
   b.btcClose=90.0;
   b.btcEma=100.0;
   b.btcAtr=1.0;
   b.btcRsi=20.0;
   Step(sig2,st,b,0,o);
   const bool noLeaderDump=!o.btcDump && !o.btcPump && o.gateBtc;
   NewState(st);
   b=SignalBar();
   b.btcNeed=true;
   b.btcOk=false;
   Step(sig2,st,b,0,o);
   Record("I8",needOff && needBtcSelf && needAlt && noLeaderDump &&
          !o.btcDump && !o.btcPump,"btc neutral");
  }

//+------------------------------------------------------------------+
//| J. Group score (10)                                              |
//+------------------------------------------------------------------+
void RunJ()
  {
   TM2Config cfg=Cfg();
   TM2EngineState st;
   TM2Bar b;
   TM2BarOut o;

//--- J1
   NewState(st);
   st.trend=1;
   st.hasSwingHi=true;
   st.swingHi=100.0;
   st.hasPrevHigh=true;
   st.prevHigh=90.0;
   b=BaseBar();
   b.prevClose=99.0;
   b.close=101.0;
   Step(cfg,st,b,0,o);
   const double gBos=o.gStruct;
   NewState(st);
   st.trend=1;
   st.hasSwingLo=true;
   st.swingLo=90.0;
   st.hasPrevLow=true;
   st.prevLow=95.0;
   b=BaseBar();
   b.prevClose=91.0;
   b.close=89.0;
   b.low=88.0;
   Step(cfg,st,b,0,o);
   const double gChoch=o.gStruct;
   NewState(st);
   st.trend=1;
   b=BaseBar();
   Step(cfg,st,b,0,o);
   const double gTrend1=o.gStruct;
   NewState(st);
   st.trend=-1;
   b=BaseBar();
   Step(cfg,st,b,0,o);
   const double gTrendM1=o.gStruct;
   NewState(st);
   b=BaseBar();
   Step(cfg,st,b,0,o);
   Record("J1",Near(gBos,1.0) && Near(gChoch,-1.0) && Near(gTrend1,0.5) &&
          Near(gTrendM1,-0.5) && Near(o.gStruct,0.0),"struct group");

//--- J2
   NewState(st);
   b=BaseBar();
   b.open=180.5;
   b.high=181.5;
   b.low=179.0;
   b.close=181.0;
   b.prevClose=180.2;
   b.pdl=180.0;
   Step(cfg,st,b,0,o);
   const double gSweepBull=o.gLiq;
   NewState(st);
   b=BaseBar();
   b.open=199.5;
   b.high=201.0;
   b.low=198.5;
   b.close=199.0;
   b.prevClose=200.2;
   b.pdh=200.0;
   Step(cfg,st,b,0,o);
   const double gSweepBear=o.gLiq;
   NewState(st);
   st.hasBrk=true;
   st.brkBar=10;
   st.brkDir=1;
   st.brkLevel=100.0;
   b=BaseBar();
   b.atr=2.0;
   b.atrSafe=2.0;
   b.low=100.9;
   b.close=101.0;
   Step(cfg,st,b,12,o);
   const double gRetestBull=o.gLiq;
   NewState(st);
   st.hasBrk=true;
   st.brkBar=10;
   st.brkDir=-1;
   st.brkLevel=100.0;
   b=BaseBar();
   b.atr=2.0;
   b.atrSafe=2.0;
   b.high=99.9;
   b.close=99.0;
   b.low=98.0;
   Step(cfg,st,b,12,o);
   Record("J2",Near(gSweepBull,1.0) && Near(gSweepBear,-1.0) &&
          Near(gRetestBull,0.7) && Near(o.gLiq,-0.7),"liq group");

//--- J3
   NewState(st);
   st.srCount=1;
   st.sr[0].top=100.5;
   st.sr[0].bot=99.5;
   st.sr[0].side=1;
   st.sr[0].broken=false;
   b=BaseBar();
   b.low=99.0;
   b.high=101.0;
   b.close=100.0;
   Step(cfg,st,b,0,o);
   const double gNearSup=o.gSr;
   NewState(st);
   st.srCount=1;
   st.sr[0].top=100.5;
   st.sr[0].bot=99.5;
   st.sr[0].side=-1;
   st.sr[0].broken=false;
   Step(cfg,st,b,0,o);
   const double gNearRes=o.gSr;
   NewState(st);
   st.fvgCount=1;
   st.fvg[0].top=101.0;
   st.fvg[0].bot=100.0;
   st.fvg[0].side=1;
   st.fvg[0].srcBar=0;
   st.fvg[0].dead=false;
   b=BaseBar();
   b.low=100.2;
   b.high=101.0;
   b.close=100.5;
   Step(cfg,st,b,1,o);
   const double gFvgBull=o.gSr;
   NewState(st);
   st.fvgCount=1;
   st.fvg[0].top=101.0;
   st.fvg[0].bot=100.0;
   st.fvg[0].side=-1;
   st.fvg[0].srcBar=0;
   st.fvg[0].dead=false;
   b=BaseBar();
   b.low=100.2;
   b.high=100.8;
   b.close=100.5;
   Step(cfg,st,b,1,o);
   const double gFvgBear=o.gSr;
   NewState(st);
   b=BaseBar();
   Step(cfg,st,b,0,o);
   Record("J3",Near(gNearSup,1.0) && Near(gNearRes,-1.0) && Near(gFvgBull,0.8) &&
          Near(gFvgBear,-0.8) && Near(o.gSr,0.0),"sr group");

//--- J4
   NewState(st);
   b=BaseBar();
   Step(cfg,st,b,0,o);
   const double gNeutral=o.gSess;
   TM2Config cfgRaw=Cfg();
   cfgRaw.cryptoSessNeutral=false;
   NewState(st);
   b=BaseBar();
   b.open=100.0;
   b.close=101.0;
   Step(cfgRaw,st,b,0,o);
   const double gBull=o.gSess;
   NewState(st);
   b=BaseBar();
   b.open=100.0;
   b.close=99.0;
   Step(cfgRaw,st,b,0,o);
   Record("J4",Near(gNeutral,0.0) && Near(gBull,0.5) && Near(o.gSess,-0.5),"sess group");

//--- J5
   NewState(st);
   b=BaseBar();
   b.ctxDir=1;
   b.setupDir=1;
   Step(cfg,st,b,0,o);
   const double gm1=o.gMtf;
   NewState(st);
   b=BaseBar();
   b.ctxDir=1;
   b.setupDir=-1;
   Step(cfg,st,b,0,o);
   const double gm0=o.gMtf;
   NewState(st);
   b=BaseBar();
   b.ctxDir=-1;
   b.setupDir=-1;
   Step(cfg,st,b,0,o);
   Record("J5",Near(gm1,1.0) && Near(gm0,0.0) && Near(o.gMtf,-1.0),"mtf group");

//--- J6
   Record("J6",Near(TM2TrendScore(false,false,101.0,100.0),0.4) &&
          Near(TM2TrendScore(false,true,100.0,100.0),-1.0),"j6 trend");

//--- J7
   Record("J7",Near(TM2VwapScore(true,101.0,100.0,2.0),0.5) &&
          Near(TM2VwapScore(true,94.0,100.0,2.0),-1.0),"j7 vwap");

//--- J8
   Record("J8",Near(TM2CandleScore(true,true,false,true,false,false,false,false),2.8/3.0) &&
          Near(TM2CandleScore(false,false,false,false,true,true,false,true),-2.8/3.0),
          "j8 candle");

//--- J9
   Record("J9",Near(TM2VolumeScore(false,1.2,1.2,101.0,100.0,0.0),0.42) &&
          Near(TM2VolumeScore(true,2.0,1.2,99.0,100.0,-1.0),-1.0),"j9 volume");

//--- J10
   Record("J10",Near(TM2MomScore(1.0,0.5),0.7) &&
          Near(TM2MomScore(-1.0,-1.0),-1.0),"j10 mom");
  }

//+------------------------------------------------------------------+
//| K. Side score / direction / quality (10)                         |
//+------------------------------------------------------------------+
void RunK()
  {
   TM2Config cfg=Cfg();
   double g[TM2_GROUP_COUNT];
   double w[];
   TM2EffectiveWeights(cfg,0,w);
   TM2AblationAdjust(w,cfg.ablation);
   int lng=0;
   int sht=0;
   double tot=0.0;

//--- K1
   for(int i=0; i<TM2_GROUP_COUNT; i++)
      g[i]=1.0;
   g[TM2_G_SESS]=0.0;
   TM2SideScores(g,w,TM2_GROUP_COUNT,lng,sht,tot);
   Record("K1",lng==96 && sht==0 && MathAbs(lng-sht)==96 &&
          TM2DirectionCode(lng,sht,cfg.scrNoTrade,cfg.scoreMargin)==TM2_DIRCODE_OK &&
          TM2CandidateDir(lng,sht,cfg.scrNoTrade)==1 &&
          TM2ScoreLevel(lng,cfg.scrNoTrade,cfg.scrWeak,cfg.scrSetup,cfg.scrStrong)==4,
          "long 96");

//--- K2
   for(int i=0; i<TM2_GROUP_COUNT; i++)
      g[i]=-1.0;
   g[TM2_G_SESS]=0.0;
   TM2SideScores(g,w,TM2_GROUP_COUNT,lng,sht,tot);
   Record("K2",lng==0 && sht==96 && TM2CandidateDir(lng,sht,cfg.scrNoTrade)==-1,
          "short 96");

//--- K3
   for(int i=0; i<TM2_GROUP_COUNT; i++)
      g[i]=1.0;
   g[TM2_G_SESS]=0.5;
   TM2SideScores(g,w,TM2_GROUP_COUNT,lng,sht,tot);
   Record("K3",lng==98,"long 98 with sess");

//--- K4
   for(int i=0; i<TM2_GROUP_COUNT; i++)
      g[i]=0.0;
   TM2SideScores(g,w,TM2_GROUP_COUNT,lng,sht,tot);
   Record("K4",lng==0 && sht==0 &&
          TM2DirectionCode(lng,sht,cfg.scrNoTrade,cfg.scoreMargin)==TM2_DIRCODE_NONE &&
          TM2ScoreBlock(TM2_DIRCODE_NONE,0,false)==TM2_R_NO_DIRECTION &&
          TM2ScoreLevel(0,cfg.scrNoTrade,cfg.scrWeak,cfg.scrSetup,cfg.scrStrong)==TM2_Q_NOTRADE,
          "flat");

//--- K5
   Record("K5",TM2DirectionCode(60,55,49,8)==TM2_DIRCODE_AMBIG &&
          TM2ScoreBlock(TM2_DIRCODE_AMBIG,0,true)==TM2_R_AMBIGUOUS,"ambiguous");

//--- K6
   Record("K6",TM2DirectionCode(60,52,49,8)==TM2_DIRCODE_OK &&
          TM2CandidateDir(60,52,49)==1,"gap 8 ok");

//--- K7
   Record("K7",TM2DirectionCode(49,45,49,8)==TM2_DIRCODE_NONE,"both below no-trade");

//--- K8
   Record("K8",TM2DirectionCode(65,65,49,8)==TM2_DIRCODE_AMBIG,"equal scores");

//--- K9
   Record("K9",TM2ScoreLevel(49,49,64,74,84)==0 &&
          TM2ScoreLevel(50,49,64,74,84)==1 &&
          TM2ScoreLevel(64,49,64,74,84)==1 &&
          TM2ScoreLevel(65,49,64,74,84)==2 &&
          TM2ScoreLevel(74,49,64,74,84)==2 &&
          TM2ScoreLevel(75,49,64,74,84)==3 &&
          TM2ScoreLevel(84,49,64,74,84)==3 &&
          TM2ScoreLevel(85,49,64,74,84)==4,"score levels");

//--- K10
   const int minReq=TM2MinLevel(TM2_MINQ_SETUP);
   const int ql=TM2ScoreLevel(60,cfg.scrNoTrade,cfg.scrWeak,cfg.scrSetup,cfg.scrStrong);
   Record("K10",minReq==2 && ql<minReq &&
          TM2ScoreBlock(TM2_DIRCODE_OK,1,ql>=minReq)==TM2_R_BLOCK_SCORE_LONG &&
          TM2ScoreBlock(TM2_DIRCODE_OK,-1,ql>=minReq)==TM2_R_BLOCK_SCORE_SHORT &&
          TM2ScoreBlock(TM2_DIRCODE_AMBIG,0,true)==TM2_R_AMBIGUOUS,"score block");
  }

//+------------------------------------------------------------------+
//| L. Entry modes (10)                                              |
//+------------------------------------------------------------------+
void RunL()
  {
   TM2Config cfg=Cfg();
   TM2ModeInput in;
   int modeDir=0;
   int activeMode=TM2_MODE_NONE;

//--- L1
   in=ModeIn();
   in.regimeCode=1;
   in.regimeDir=1;
   in.ctxDir=0;
   in.setupDir=0;
   in.open=100.0;
   in.close=101.0;
   in.low=99.0;
   in.high=102.0;
   in.emaF=100.0;
   in.atrSafe=10.0;
   TM2SelectMode(in,modeDir,activeMode);
   Record("L1",modeDir==1 && activeMode==TM2_MODE_A,"mode A long");

//--- L2
   in.ctxDir=-1;
   TM2SelectMode(in,modeDir,activeMode);
   Record("L2",modeDir==0 && activeMode==TM2_MODE_NONE,"mode A mtf");

//--- L3
   in=ModeIn();
   in.regimeCode=1;
   in.regimeDir=1;
   in.open=104.0;
   in.close=104.5;
   in.low=104.0;
   in.high=105.0;
   in.emaF=100.0;
   in.atrSafe=10.0;
   TM2SelectMode(in,modeDir,activeMode);
   Record("L3",modeDir==0 && !TM2ModeAPull(true,104.0,105.0,100.0,3.5,
                                         false,EMPTY_VALUE,false,EMPTY_VALUE),"no pullback");

//--- L4
   in=ModeIn();
   in.regimeCode=0;
   in.hasSweepBullPx=true;
   in.sweepBullPx=95.0;
   in.sweepAgeBull=2;
   in.confirmBull=true;
   in.close=100.0;
   in.open=99.0;
   in.low=99.0;
   in.high=101.0;
   TM2SelectMode(in,modeDir,activeMode);
   Record("L4",modeDir==1 && activeMode==TM2_MODE_B,"mode B long");

//--- L5
   in.sweepAgeBull=4;
   TM2SelectMode(in,modeDir,activeMode);
   Record("L5",modeDir==0,"mode B window");

//--- L6
   Record("L6",TM2ModeBInvalid(true,2,3,true,93.9,95.0,10.0) &&
          !TM2ModeBInvalid(true,2,3,true,94.0,95.0,10.0),"mode B invalid");

//--- L7
   in=ModeIn();
   in.regimeCode=0;
   in.modeCOn=true;
   in.hasRes=true;
   in.nearestRes=110.0;
   in.hasSup=true;
   in.nearestSup=90.0;
   in.open=90.5;
   in.close=91.0;
   in.low=90.0;
   in.high=91.5;
   in.confirmBull=true;
   TM2SelectMode(in,modeDir,activeMode);
   const bool cOn=modeDir==1 && activeMode==TM2_MODE_C;
   in.modeCOn=false;
   TM2SelectMode(in,modeDir,activeMode);
   Record("L7",cOn && modeDir==0,"mode C toggle");

//--- L8
   in=ModeIn();
   in.regimeCode=1;
   in.regimeDir=1;
   in.ctxDir=1;
   in.setupDir=1;
   in.open=100.0;
   in.close=101.0;
   in.low=99.0;
   in.high=102.0;
   in.emaF=100.0;
   in.hasSweepBullPx=true;
   in.sweepBullPx=95.0;
   in.sweepAgeBull=2;
   in.confirmBull=true;
   TM2SelectMode(in,modeDir,activeMode);
   Record("L8",modeDir==1 && activeMode==TM2_MODE_A,"mode A priority");

//--- L9
   TM2Config sig=SignalCfg();
   sig.modeFilterOn=true;
   TM2EngineState st;
   TM2Bar b;
   TM2BarOut o;
   NewState(st);
   b=SignalBar();
   b.adx=25.0;
   b.low=95.0;
   b.pdl=96.0;
   b.ctxDir=-1;
   b.setupDir=-1;
   Step(sig,st,b,0,o);
   const bool gateOff=o.modeDir==1 && o.dir==-1 && !o.modeGateOk;
   sig.modeFilterOn=false;
   NewState(st);
   Step(sig,st,b,0,o);
   Record("L9",gateOff && o.modeGateOk,"mode gate");

//--- L10
   in=ModeIn();
   in.regimeCode=1;
   in.regimeDir=1;
   in.open=100.0;
   in.close=101.0;
   in.low=99.0;
   in.high=102.0;
   in.emaF=100.0;
   const int rA=TM2ModeReason(in,true,TM2_MODE_A);
   in=ModeIn();
   in.regimeCode=0;
   in.hasSweepBullPx=true;
   in.sweepBullPx=95.0;
   in.sweepAgeBull=2;
   in.open=93.5;
   in.close=93.0;
   in.low=92.0;
   in.high=94.0;
   in.emaF=100.0;
   const int rInv=TM2ModeReason(in,true,TM2_MODE_NONE);
   in=ModeIn();
   in.regimeCode=0;
   in.low=99.0;
   in.high=101.0;
   in.close=100.0;
   in.open=100.0;
   in.emaF=100.0;
   const int rWait=TM2ModeReason(in,true,TM2_MODE_NONE);
   in=ModeIn();
   in.regimeCode=0;
   in.open=104.0;
   in.close=104.5;
   in.low=104.0;
   in.high=105.0;
   in.emaF=EMPTY_VALUE;
   const int rNone=TM2ModeReason(in,true,TM2_MODE_NONE);
   Record("L10",rA==TM2_R_MODE_A_PULLBACK && rInv==TM2_R_MODE_INVALIDATED &&
          rWait==TM2_R_WAIT_CONFIRMATION && rNone==TM2_R_NO_SETUP &&
          TM2ModeReason(in,false,TM2_MODE_NONE)==TM2_R_OK,"mode reasons");
  }

//+------------------------------------------------------------------+
//| M. Gates / eligibility (10)                                      |
//+------------------------------------------------------------------+
void RunM()
  {
   TM2Config cfg=Cfg();
   TM2GateStatus gate;
   TM2EngineState st;
   TM2Bar b;

//--- M1
   NewState(st);
   b=BaseBar();
   b.adx=17.0;
   TM2EvaluateGates(cfg,b,st,1,gate);
   const bool chopBlock=!gate.regimeOk;
   TM2Config cfgNoRegime=Cfg();
   cfgNoRegime.gateRegime=false;
   NewState(st);
   TM2EvaluateGates(cfgNoRegime,b,st,1,gate);
   Record("M1",chopBlock && gate.regimeOk,"regime gate");

//--- M2
   TM2Config cfgRange=Cfg();
   cfgRange.gateObstacle=false;
   NewState(st);
   st.srCount=2;
   st.sr[0].top=110.5;
   st.sr[0].bot=110.0;
   st.sr[0].side=-1;
   st.sr[0].broken=false;
   st.sr[1].top=90.0;
   st.sr[1].bot=89.5;
   st.sr[1].side=1;
   st.sr[1].broken=false;
   b=BaseBar();
   b.adx=20.0;
   b.open=100.0;
   b.close=101.0;
   b.high=102.0;
   b.low=99.0;
   TM2EvaluateGates(cfgRange,b,st,1,gate);
   const bool aboveMid=!gate.regimeOk;
   b.close=99.0;
   TM2EvaluateGates(cfgRange,b,st,1,gate);
   const bool belowMid=gate.regimeOk;
   NewState(st);
   st.srCount=1;
   st.sr[0].top=110.5;
   st.sr[0].bot=110.0;
   st.sr[0].side=-1;
   st.sr[0].broken=false;
   TM2EvaluateGates(cfgRange,b,st,1,gate);
   Record("M2",aboveMid && belowMid && gate.regimeOk,"range midpoint");

//--- M3
   TM2Config cfgMtf=Cfg();
   cfgMtf.htfVetoOn=false;
   NewState(st);
   b=SignalBar();
   b.adx=25.0;
   b.ctxDir=0;
   b.setupDir=1;
   TM2EvaluateGates(cfgMtf,b,st,-1,gate);
   Record("M3",!gate.mtfOk && gate.topReason==TM2_R_BLOCK_MTF,"mtf gate");

//--- M4
   TM2Config cfgVeto=Cfg();
   cfgVeto.htfVetoOn=true;
   NewState(st);
   b=SignalBar();
   b.ctxDir=-1;
   b.setupDir=0;
   TM2EvaluateGates(cfgVeto,b,st,1,gate);
   Record("M4",!gate.mtfOk,"ctx veto gate");

//--- M5
   Record("M5",TM2ObstacleBlocked(true,true,10.0,15.0,0.7) &&
          !TM2ObstacleBlocked(true,true,10.5,15.0,0.7) &&
          !TM2ObstacleBlocked(true,false,0.0,15.0,0.7),"obstacle strict");

//--- M6
   TM2Config cfgExt=Cfg();
   NewState(st);
   b=BaseBar();
   b.isOverext=true;
   cfgExt.entryMode=TM2_ENTRY_MARKET;
   TM2EvaluateGates(cfgExt,b,st,1,gate);
   const bool marketBlock=!gate.overextOk;
   cfgExt.entryMode=TM2_ENTRY_AUTO;
   TM2EvaluateGates(cfgExt,b,st,1,gate);
   const bool autoPass=gate.overextOk;
   cfgExt.entryMode=TM2_ENTRY_LIMIT_STRICT;
   TM2EvaluateGates(cfgExt,b,st,1,gate);
   Record("M6",marketBlock && autoPass && gate.overextOk,"overext by mode");

//--- M7
   NewState(st);
   b=BaseBar();
   b.weekendBlocked=true;
   TM2EvaluateGates(cfg,b,st,1,gate);
   Record("M7",!gate.circuitOk && gate.topReason==TM2_R_BLOCK_LIQUIDITY,
          "weekend circuit");

//--- M8
   NewState(st);
   b=BaseBar();
   b.btcNeed=true;
   b.btcOk=true;
   b.btcClose=98.0;
   b.btcEma=100.0;
   b.btcAtr=1.0;
   b.btcRsi=31.0;
   TM2EvaluateGates(cfg,b,st,1,gate);
   Record("M8",!gate.btcOk && gate.topReason==TM2_R_BTC_DUMPING,"btc gate");

//--- M9
   NewState(st);
   b=SignalBar();
   b.adx=17.0;
   b.ctxDir=0;
   b.setupDir=1;
   TM2EvaluateGates(cfg,b,st,-1,gate);
   Record("M9",!gate.regimeOk && !gate.mtfOk && gate.topReason==TM2_R_BLOCK_REGIME &&
          gate.blockMask==(TM2_MASK_REGIME|TM2_MASK_MTF),"mask both");

//--- M10
   NewState(st);
   b=BaseBar();
   TM2EvaluateGates(cfg,b,st,1,gate);
   Record("M10",gate.allPassed && gate.topReason==TM2_R_OK && gate.blockMask==0,
          "all pass");
  }

//+------------------------------------------------------------------+
//| N. Plan / risk / sizing (12)                                     |
//+------------------------------------------------------------------+
void RunN()
  {
   TM2Config cfg=Cfg();
   TM2EngineState st;
   TM2Bar b;
   TM2Plan p;

//--- N1
   NewState(st);
   st.hasSwingLo=true;
   st.swingLo=1985.0;
   b=BaseBar();
   b.open=1999.0;
   b.high=2001.0;
   b.low=1995.0;
   b.close=2000.0;
   b.atr=10.0;
   b.atrSafe=10.0;
   b.mintick=0.01;
   TM2BuildPlan(cfg,b,st,1,p);
   Record("N1",p.valid && Near(p.risk,16.0) && Near(p.sl,1984.0) &&
          Near(p.tp1,2016.0) && Near(p.tp2,2032.0) && Near(p.tp3,2048.0) &&
          NearT(p.posSize,6.25,1e-9) && NearT(p.notional,12500.0,1e-6) &&
          NearT(p.effLev,1.25,1e-9) && NearT(p.marginReq,625.0,1e-9) &&
          NearT(p.liqPrice,410.0,1e-6),"plan basic");

//--- N2
   TM2Config cfgRR=Cfg();
   cfgRR.rr1=2.0;
   cfgRR.rr2=2.0;
   cfgRR.rr3=3.0;
   TM2BuildPlan(cfgRR,b,st,1,p);
   Record("N2",Near(p.evalRR,2.5) && Near(p.tp1,2032.0) && Near(p.tp2,2040.0) &&
          Near(p.tp3,2056.0),"rr cascade");

//--- N3
   TM2Config cfgMin=Cfg();
   cfgMin.slAtrMul=0.1;
   cfgMin.slPadAtr=0.0;
   NewState(st);
   st.hasSwingLo=true;
   st.swingLo=2000.0;
   TM2BuildPlan(cfgMin,b,st,1,p);
   Record("N3",Near(p.risk,5.0),"clamp min");

//--- N4
   TM2Config cfgPad=Cfg();
   cfgPad.slPadAtr=0.0;
   NewState(st);
   st.hasSwingLo=true;
   st.swingLo=1900.0;
   TM2BuildPlan(cfgPad,b,st,1,p);
   Record("N4",Near(p.risk,30.0),"clamp max");

//--- N5
   NewState(st);
   b=BaseBar();
   b.open=1999.0;
   b.high=2010.0;
   b.low=1999.0;
   b.close=2000.0;
   b.atr=10.0;
   b.atrSafe=10.0;
   b.mintick=0.01;
   TM2BuildPlan(cfg,b,st,0,p);
   Record("N5",!p.valid && p.reason==TM2_R_NO_DIRECTION && Near(p.risk,13.5) &&
          Near(p.sl,2000.0) && Near(p.tp1,2000.0) && Near(p.tp2,2000.0) &&
          Near(p.tp3,2000.0) && EmptyD(p.liqPrice),"no direction plan");

//--- N6
   NewState(st);
   b=BaseBar();
   b.close=2000.0;
   b.atr=EMPTY_VALUE;
   b.atrSafe=EMPTY_VALUE;
   TM2BuildPlan(cfg,b,st,1,p);
   Record("N6",!p.valid && p.reason==TM2_R_BLOCK_NO_ATR && Near(p.entry,2000.0) &&
          EmptyD(p.sl) && EmptyD(p.tp1) && EmptyD(p.tp2) && EmptyD(p.tp3) &&
          EmptyD(p.risk) && EmptyD(p.liqPrice),"no atr plan");

//--- N7
   TM2Config cfgFee=Cfg();
   cfgFee.riskFeeSlipPct=0.5;
   NewState(st);
   st.hasSwingLo=true;
   st.swingLo=1985.0;
   b=BaseBar();
   b.high=2001.0;
   b.low=1995.0;
   b.close=2000.0;
   b.atr=10.0;
   b.atrSafe=10.0;
   b.mintick=0.01;
   TM2BuildPlan(cfgFee,b,st,1,p);
   Record("N7",!p.valid && p.reason==TM2_R_BLOCK_NET_RR &&
          NearT(p.netRR,0.846154,1e-6),"net rr block");

//--- N8
   TM2Config cfgLev=Cfg();
   cfgLev.riskEquity=10000.0;
   cfgLev.riskPct=10.0;
   cfgLev.slAtrMul=0.75;
   cfgLev.slPadAtr=0.0;
   NewState(st);
   st.hasSwingLo=true;
   st.swingLo=1999.25;
   b=BaseBar();
   b.high=2001.0;
   b.low=1999.0;
   b.close=2000.0;
   b.atr=1.0;
   b.atrSafe=1.0;
   b.mintick=0.01;
   TM2BuildPlan(cfgLev,b,st,1,p);
   Record("N8",!p.valid && p.reason==TM2_R_BLOCK_MAX_LEV &&
          NearT(p.risk,0.75,1e-9) && NearT(p.effLev,266.6667,1e-3),"max leverage");

//--- N9
   TM2Config cfgLiq=Cfg();
   cfgLiq.riskEquity=10000.0;
   cfgLiq.riskPct=10.0;
   cfgLiq.riskMmr=0.05;
   cfgLiq.riskMaxLev=20.0;
   NewState(st);
   st.hasSwingLo=true;
   st.swingLo=1997.0;
   b=BaseBar();
   b.high=2005.0;
   b.low=1990.0;
   b.close=2000.0;
   b.atr=10.0;
   b.atrSafe=10.0;
   b.mintick=0.01;
   TM2BuildPlan(cfgLiq,b,st,1,p);
   Record("N9",!p.valid && p.reason==TM2_R_BLOCK_LIQUIDATION &&
          NearT(p.risk,10.0,1e-9) && NearT(p.effLev,20.0,1e-9) &&
          NearT(p.liqPrice,2000.0,1e-6),"liquidation");

//--- N10
   TM2Config cfgNoFee=Cfg();
   cfgNoFee.riskFeeSlipPct=0.0;
   NewState(st);
   st.hasSwingLo=true;
   st.swingLo=1985.0;
   b=BaseBar();
   b.high=2001.0;
   b.low=1995.0;
   b.close=2000.0;
   b.atr=10.0;
   b.atrSafe=10.0;
   b.mintick=0.01;
   TM2BuildPlan(cfgNoFee,b,st,1,p);
   const double net0=p.netRR;
   TM2Config cfgFee08=Cfg();
   TM2BuildPlan(cfgFee08,b,st,1,p);
   Record("N10",NearT(net0,2.0,1e-9) && NearT(p.netRR,1.727273,1e-6),"net rr fees");

//--- N11
   NewState(st);
   TM2Config cfgMkt=Cfg();
   cfgMkt.entryMode=TM2_ENTRY_MARKET;
   TM2BuildPlan(cfgMkt,b,st,1,p);
   const bool marketOk=p.orderType==TM2_ORDER_MARKET && Near(p.entry,2000.0);
   TM2Config cfgAuto=Cfg();
   cfgAuto.entryMode=TM2_ENTRY_AUTO;
   NewState(st);
   st.fvgCount=1;
   st.fvg[0].top=1991.0;
   st.fvg[0].bot=1989.0;
   st.fvg[0].side=1;
   st.fvg[0].srcBar=1;
   st.fvg[0].dead=false;
   b.isOverext=true;
   TM2BuildPlan(cfgAuto,b,st,1,p);
   const bool limitFvg=p.orderType==TM2_ORDER_LIMIT && Near(p.limit,1990.0) &&
                      Near(p.entry,1990.0);
   NewState(st);
   st.fvgCount=1;
   st.fvg[0].top=2006.0;
   st.fvg[0].bot=2004.0;
   st.fvg[0].side=1;
   st.fvg[0].srcBar=1;
   st.fvg[0].dead=false;
   TM2BuildPlan(cfgAuto,b,st,1,p);
   Record("N11",marketOk && limitFvg && p.orderType==TM2_ORDER_LIMIT &&
          NearT(p.limit,1999.99,1e-6) && NearT(p.entry,1999.99,1e-6),"order type");

//--- N12
   NewState(st);
   b=BaseBar();
   b.close=2000.0;
   b.atr=EMPTY_VALUE;
   b.atrSafe=EMPTY_VALUE;
   TM2BuildPlan(cfg,b,st,0,p);
   const int rAtr=p.reason;
   NewState(st);
   b=BaseBar();
   b.close=2000.0;
   b.atr=10.0;
   b.atrSafe=10.0;
   TM2BuildPlan(cfg,b,st,0,p);
   const int rDir=p.reason;
   TM2Config cfgRrMin=Cfg();
   cfgRrMin.rrMin=5.0;
   NewState(st);
   st.hasSwingLo=true;
   st.swingLo=1985.0;
   b.high=2001.0;
   b.low=1995.0;
   b.close=2000.0;
   b.atr=10.0;
   b.atrSafe=10.0;
   b.mintick=0.01;
   TM2BuildPlan(cfgRrMin,b,st,1,p);
   const int rRr=p.reason;
   TM2BuildPlan(cfgFee,b,st,1,p);
   Record("N12",rAtr==TM2_R_BLOCK_NO_ATR && rDir==TM2_R_NO_DIRECTION &&
          rRr==TM2_R_BLOCK_RR && p.reason==TM2_R_BLOCK_NET_RR,"plan priority");
  }

//+------------------------------------------------------------------+
//| O. State machine (16)                                            |
//+------------------------------------------------------------------+
void SetPos(TM2EngineState &st,const int stage,const double entry,const double sl,
            const double tp1,const double tp2,const double tp3,const double risk,
            const int bars,const int bar)
  {
   st.posStage=stage;
   st.posDir=1;
   st.posEntry=entry;
   st.posLimit=entry;
   st.posSl=sl;
   st.posTp1=tp1;
   st.posTp2=tp2;
   st.posTp3=tp3;
   st.posRisk=risk;
   st.posBars=bars;
   st.posBar=bar;
   st.posOrderType=TM2_ORDER_MARKET;
   st.posMaxFavR=0.0;
  }

void RunO()
  {
   TM2Config sig=SignalCfg();
   TM2EngineState st;
   TM2Bar b;
   TM2BarOut o;

//--- O1
   NewState(st);
   b=SignalBar();
   Step(sig,st,b,0,o);
   Record("O1",o.signal && o.evEntry && o.posStage==TM2_STAGE_OPEN &&
          Near(o.posEntry,100.0) && o.posBars==0 && o.dayCount==1 &&
          o.barsSince==0 && o.filledN==1 && Near(o.posSl,90.5) &&
          Near(o.posTp1,109.5),"market entry");

//--- O2
   TM2Config lim=SignalCfg();
   lim.entryMode=TM2_ENTRY_LIMIT_STRICT;
   NewState(st);
   b=SignalBar();
   Step(lim,st,b,0,o);
   Record("O2",o.evPending && o.posStage==TM2_STAGE_PENDING &&
          Near(o.posLimit,99.0) && o.posOrderType==TM2_ORDER_LIMIT &&
          o.pendingN==1 && o.filledN==0 && o.dayCount==1,"limit pending");

//--- O3
   b=SignalBar();
   b.low=98.5;
   b.high=102.0;
   b.close=100.0;
   Step(lim,st,b,1,o);
   Record("O3",o.evFilled && o.posStage==TM2_STAGE_OPEN && Near(o.posEntry,99.0) &&
          o.posBar==1 && o.posBars==1 && o.filledN==1 && o.pendingN==1,"limit fill");

//--- O4
   NewState(st);
   SetPos(st,TM2_STAGE_PENDING,100.0,90.0,110.0,120.0,130.0,10.0,4,-1);
   st.posLimit=90.0;
   b=BaseBar();
   b.open=100.0;
   b.close=100.0;
   b.high=105.0;
   b.low=100.0;
   Step(lim,st,b,20,o);
   const bool cancelT=o.evCancel && o.cancelReason==TM2_X_CANCEL_TIMEOUT &&
                       st.needReset && o.posStage==TM2_STAGE_PENDING;
   Step(lim,st,b,21,o);
   Record("O4",cancelT && o.posStage==TM2_STAGE_IDLE && !o.signal,"cancel timeout");

//--- O5
   NewState(st);
   SetPos(st,TM2_STAGE_PENDING,100.0,90.0,110.0,120.0,130.0,10.0,0,-1);
   st.posLimit=90.0;
   b=BaseBar();
   b.open=100.0;
   b.close=100.0;
   b.high=111.0;
   b.low=100.0;
   Step(lim,st,b,20,o);
   Record("O5",o.evCancel && o.cancelReason==TM2_X_CANCEL_MISSED &&
          o.posStage==TM2_STAGE_PENDING,"cancel missed");

//--- O6
   NewState(st);
   SetPos(st,TM2_STAGE_PENDING,100.0,90.0,110.0,120.0,130.0,10.0,0,-1);
   st.posLimit=100.0;
   b=BaseBar();
   b.atr=10.0;
   b.atrSafe=10.0;
   b.open=100.0;
   b.close=100.0;
   b.high=111.0;
   b.low=90.0;
   Step(lim,st,b,1,o);
   Record("O6",o.evFilled && o.evSl && o.evTp==0 && Near(o.xR,-1.0) &&
          o.posStage==TM2_STAGE_OPEN,"fill bar SL wins");

//--- O7
   NewState(st);
   SetPos(st,TM2_STAGE_OPEN,100.0,90.0,110.0,120.0,130.0,10.0,0,0);
   b=BaseBar();
   b.atr=10.0;
   b.atrSafe=10.0;
   b.open=100.0;
   b.close=105.0;
   b.high=110.5;
   b.low=95.0;
   Step(sig,st,b,1,o);
   Record("O7",o.posStage==TM2_STAGE_TP1_BE && o.evTp==1 && o.evBe &&
          Near(o.posSl,100.5) && o.tp1Hits==1,"tp1 be");

//--- O8
   NewState(st);
   SetPos(st,TM2_STAGE_TP1_BE,100.0,110.0,110.0,120.0,130.0,10.0,5,0);
   b=BaseBar();
   b.atr=10.0;
   b.atrSafe=10.0;
   b.open=110.0;
   b.close=118.0;
   b.high=121.0;
   b.low=111.0;
   b.prevHigh=130.0;
   Step(sig,st,b,1,o);
   Record("O8",o.posStage==TM2_STAGE_TP2_TRAIL && o.evTp==2 && o.evTrail &&
          Near(o.posSl,115.0),"tp2 trail");

//--- O9
   NewState(st);
   SetPos(st,TM2_STAGE_TP2_TRAIL,100.0,115.0,110.0,120.0,130.0,10.0,6,0);
   b=BaseBar();
   b.atr=10.0;
   b.atrSafe=10.0;
   b.open=120.0;
   b.close=128.0;
   b.high=131.0;
   b.low=116.0;
   Step(sig,st,b,1,o);
   Record("O9",o.evTp==3 && o.evClose && Near(o.xR,1.8) && o.netWins==1 &&
          st.needReset && o.posStage==TM2_STAGE_TP2_TRAIL,"tp3 close");

//--- O10
   NewState(st);
   SetPos(st,TM2_STAGE_OPEN,100.0,90.0,110.0,120.0,130.0,10.0,0,0);
   b=BaseBar();
   b.atr=10.0;
   b.atrSafe=10.0;
   b.open=95.0;
   b.close=89.0;
   b.high=101.0;
   b.low=89.0;
   Step(sig,st,b,1,o);
   Record("O10",o.evSl && Near(o.xR,-1.0) && o.fullLosses==1 && o.consecLosses==1,
          "sl close");

//--- O11
   NewState(st);
   SetPos(st,TM2_STAGE_TP1_BE,100.0,100.5,110.0,120.0,130.0,10.0,2,0);
   b=BaseBar();
   b.atr=10.0;
   b.atrSafe=10.0;
   b.open=101.0;
   b.close=100.0;
   b.high=101.0;
   b.low=100.0;
   Step(sig,st,b,1,o);
   Record("O11",o.evClose && NearT(o.xR,0.3984,1e-9) && o.beSaves==1 &&
          o.netWins==1 && o.consecLosses==0,"breakeven");

//--- O12
   NewState(st);
   SetPos(st,TM2_STAGE_TP2_TRAIL,100.0,115.0,110.0,120.0,130.0,10.0,4,0);
   b=BaseBar();
   b.atr=10.0;
   b.atrSafe=10.0;
   b.open=116.0;
   b.close=114.0;
   b.high=116.0;
   b.low=114.0;
   Step(sig,st,b,1,o);
   Record("O12",o.evClose && NearT(o.xR,1.1984,1e-9) && o.netWins==1,"trail close");

//--- O13
   NewState(st);
   SetPos(st,TM2_STAGE_OPEN,100.0,90.0,110.0,120.0,130.0,10.0,0,0);
   b=BaseBar();
   b.atr=10.0;
   b.atrSafe=10.0;
   b.open=100.0;
   b.close=100.0;
   b.high=111.0;
   b.low=89.0;
   Step(sig,st,b,1,o);
   Record("O13",o.evTp==0 && o.evSl && Near(o.xR,-1.0),"sl beats tp");

//--- O14
   NewState(st);
   SetPos(st,TM2_STAGE_OPEN,2000.0,1990.0,2016.0,2032.0,2048.0,16.0,14,0);
   st.posMaxFavR=0.2;
   b=BaseBar();
   b.atr=10.0;
   b.atrSafe=10.0;
   b.adx=21.0;
   b.open=1997.0;
   b.close=1996.0;
   b.high=1998.0;
   b.low=1995.0;
   Step(sig,st,b,1,o);
   Record("O14",o.evDecay && o.evClose && NearT(o.xR,-0.25,1e-9) && o.decays==1 &&
          st.needReset,"time decay");

//--- O15
   NewState(st);
   SetPos(st,TM2_STAGE_OPEN,100.0,90.0,120.0,130.0,140.0,10.0,0,0);
   b=SignalBar();
   b.low=89.0;
   Step(sig,st,b,1,o);
   const bool noSameBar=!o.evEntry && o.trades==1 && o.posStage==TM2_STAGE_OPEN;
   b=SignalBar();
   b.low=98.0;
   Step(sig,st,b,2,o);
   const bool noResetBarEntry=!o.signal && !o.evEntry && o.posStage==TM2_STAGE_IDLE;
   Step(sig,st,b,3,o);
   Record("O15",noSameBar && noResetBarEntry && o.evEntry &&
          o.posStage==TM2_STAGE_OPEN,"reset timing");

//--- O16
   NewState(st);
   b=SignalBar();
   Step(sig,st,b,0,o);
   const int market0=o.posBars;
   b=SignalBar();
   b.low=98.5;
   b.high=101.0;
   Step(sig,st,b,1,o);
   const int market1=o.posBars;
   NewState(st);
   b=SignalBar();
   Step(lim,st,b,0,o);
   const int pend0=o.posBars;
   b=SignalBar();
   b.low=98.5;
   b.high=101.0;
   Step(lim,st,b,1,o);
   Record("O16",market0==0 && market1==1 && pend0==0 && o.posBars==1 && o.evFilled,
          "pos bars");
  }

//+------------------------------------------------------------------+
//| P. Output / bar policy / config (10)                             |
//+------------------------------------------------------------------+
void RunP()
  {
   TM2Config cfg=Cfg();
   TM2EngineState st;
   TM2Bar b;
   TM2BarOut o;

//--- P1
   Record("P1",!TM2IsClosedBar(9,10) && TM2IsClosedBar(8,10),"closed bar guard");

//--- P2
   NewState(st);
   b=BaseBar();
   b.atr=EMPTY_VALUE;
   b.atrSafe=EMPTY_VALUE;
   b.rsi=EMPTY_VALUE;
   b.macdHist=EMPTY_VALUE;
   Step(cfg,st,b,0,o);
   Record("P2",EmptyD(o.longScore) && EmptyD(o.score100) &&
          o.directionCode==TM2_DIRCODE_NONE && !o.planValid &&
          o.planReason==TM2_R_BLOCK_NO_ATR,"warmup");

//--- P3
   const TM2Config sig=SignalCfg();
   TM2Bar b1=SignalBar();
   TM2Bar b2=SignalBar();
   b2.low=99.5;
   b2.high=101.0;
   TM2Bar b3=SignalBar();
   b3.high=110.0;
   TM2EngineState s1;
   TM2EngineState s2;
   TM2BarOut o1;
   TM2BarOut o2;
   NewState(s1);
   Step(sig,s1,b1,0,o1);
   Step(sig,s1,b2,1,o1);
   Step(sig,s1,b3,2,o1);
   NewState(s2);
   Step(sig,s2,b1,0,o2);
   Step(sig,s2,b2,1,o2);
   Step(sig,s2,b3,2,o2);
   Record("P3",Near(o1.longScore,o2.longScore) && Near(o1.score100,o2.score100) &&
          Near(o1.entry,o2.entry) && o1.posStage==o2.posStage &&
          o1.posBars==o2.posBars && o1.evTp==o2.evTp &&
          o1.trades==o2.trades && o1.dayCount==o2.dayCount,"replay deterministic");

//--- P4
   Record("P4",TM2_PLOT_BUFFERS==16 && TM2_CONTRACT_BUFFERS==226 &&
          TM2_TOTAL_BUFFERS==242 && TM2_CONTRACT_FIRST==16 &&
          TM2_BUF_LONG_SCORE==16 && TM2_MAX_SR==20 && TM2_MAX_FVG==50 &&
          TM2_MAX_OB==30 && TM2_MAX_EVT==50,"buffer map");

//--- P5
   NewState(st);
   b=BaseBar();
   Step(cfg,st,b,0,o);
   Record("P5",EmptyD(o.pdh) && EmptyD(o.pdl) && EmptyD(o.pwh) && EmptyD(o.pwl) &&
          o.fvgCount==0 && o.evtKind==TM2_EVT_NONE && o.evtCount==0 &&
          EmptyD(o.sessHi) && EmptyD(o.sessLo) && !o.signal && !o.planValid,"na output");

//--- P6
   NewState(st);
   b=BaseBar();
   Step(cfg,st,b,0,o);
   NewState(st);
   TM2Plan p;
   b=SignalBar();
   TM2BuildPlan(cfg,b,st,1,p);
   Record("P6",Near(o.gSess,0.0) && !cfg.modeCOn && cfg.modeFilterOn && p.valid &&
          p.evalRR>=cfg.rrMin,"default config");

//--- P7
   TM2Config cfgNorm=Cfg();
   cfgNorm.msSwingLen=1;
   cfgNorm.srMax=0;
   cfgNorm.fvgMax=0;
   cfgNorm.maxDay=0;
   TM2NormalizeConfig(cfgNorm);
   const bool loOk=cfgNorm.msSwingLen==2 && cfgNorm.srMax==1 &&
                   cfgNorm.fvgMax==1 && cfgNorm.maxDay==1;
   cfgNorm.msSwingLen=25;
   cfgNorm.srMax=99;
   cfgNorm.fvgMax=99;
   TM2NormalizeConfig(cfgNorm);
   Record("P7",loOk && cfgNorm.msSwingLen==20 && cfgNorm.srMax==20 &&
          cfgNorm.fvgMax==50 && cfgNorm.maxDay==1,"normalize clamps");

//--- P8
   Record("P8",TM2_X_CANCEL_TIMEOUT==9 && TM2_X_CANCEL_MISSED==10 &&
          TM2_X_NONE==0 && TM2_X_SL==1 && TM2_X_TIMEOUT==8,"close reasons");

//--- P9
   NewState(st);
   TM2PushEvent(st,TM2_EVT_SWEEP,1,1,D'2024.01.03 00:00',100.0);
   TM2PushEvent(st,TM2_EVT_SWEEP,1,1,D'2024.01.03 00:00',100.0);
   const bool noDedupe=st.evtCount==2;
   for(int i=0; i<60; i++)
      TM2PushEvent(st,TM2_EVT_BOS,-1,i,D'2024.01.03 00:00',(double)i);
   Record("P9",noDedupe && st.evtCount==50 &&
          TM2_EVT_NONE==0 && TM2_EVT_BOS==1 && TM2_EVT_CHOCH==2 &&
          TM2_EVT_MSS==3 && TM2_EVT_SWEEP==4,"event ring");

//--- P10
   NewState(st);
   st.trend=1;
   st.hasSwingHi=true;
   st.swingHi=100.0;
   st.hasPrevHigh=true;
   st.prevHigh=90.0;
   b=BaseBar();
   b.time=D'2024.02.05 14:30';
   b.prevClose=99.0;
   b.close=101.0;
   Step(cfg,st,b,5,o);
   Record("P10",o.evtCount==1 && o.evtSrcBar==5 &&
          o.evtSrcTime==D'2024.02.05 14:30' && Near(o.evtLevel,100.0) &&
          o.evtKind==TM2_EVT_BOS,"event stamp");
  }

//+------------------------------------------------------------------+
//| Entry point (runs once, prints one summary line)                 |
//+------------------------------------------------------------------+
void OnStart()
  {
   PrintFormat("TEST|BEGIN|contract=%s|buffers=%d/%d",
               TM2_CONTRACT_VERSION,TM2_CONTRACT_BUFFERS,TM2_TOTAL_BUFFERS);
   RunA();
   RunB();
   RunC();
   RunD();
   RunE();
   RunF();
   RunG();
   RunH();
   RunI();
   RunJ();
   RunK();
   RunL();
   RunM();
   RunN();
   RunO();
   RunP();
   const string verdict=(g_fail==0 ? "ALL_PASS" : "FAIL");
   PrintFormat("TEST|RESULT|%s|pass=%d fail=%d|contract=%s",
               verdict,g_pass,g_fail,TM2_CONTRACT_VERSION);
  }
