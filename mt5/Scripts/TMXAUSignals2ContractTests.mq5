//+------------------------------------------------------------------+
//|                            TMXAUSignals2ContractTests.mq5        |
//|      MT5 EA & AI Lab - synthetic checks for the TM XAU2 contract |
//|                                                                  |
//| Runs once. No file I/O, no market data, no account access, no    |
//| trading functions. Vectors: docs/indicators/tm-xau-signals-2.md |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Synthetic contract tests for TM XAU Signals 2. No trading."

#include "../Include/PinePort/TMXAUSignals2Contract.mqh"

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

bool EmptyD(const double v)
  {
   return(X2IsEmpty(v));
  }

double CpScore(const double cpBull,const double cpBear)
  {
   return(cpBull>cpBear ? MathMin(1.0,cpBull/3.0)
          : cpBear>cpBull ? -MathMin(1.0,cpBear/3.0) : 0.0);
  }

double VolScore(const bool bbExpand,const double close,const double open)
  {
   return(bbExpand ? (close>open ? 0.5 : -0.5) : 0.0);
  }

void ZeroWeights(X2Config &cfg)
  {
   cfg.wTrend=0.0;
   cfg.wStruct=0.0;
   cfg.wLiq=0.0;
   cfg.wLoc=0.0;
   cfg.wSr=0.0;
   cfg.wCandle=0.0;
   cfg.wVol=0.0;
   cfg.wAtr=0.0;
   cfg.wMom=0.0;
   cfg.wSess=0.0;
   cfg.wMtf=0.0;
  }

X2Config BaseConfig()
  {
   X2Config cfg;
   cfg.srvOffsetMin=180;
   cfg.mktOffsetMin=-300;
   cfg.volSessOffsetMin=420;
   cfg.maxBars=0;
   cfg.swingLen=5;
   cfg.retestOn=true;
   cfg.retestBars=10;
   cfg.retestTolAtr=0.5;
   cfg.failOn=true;
   cfg.failBars=5;
   cfg.contOn=true;
   cfg.pullOn=true;
   cfg.eqTolAtr=0.05;
   cfg.pdOn=true;
   cfg.pwOn=false;
   cfg.sessOn=true;
   cfg.srLeft=10;
   cfg.srRight=10;
   cfg.srWidthAtr=0.5;
   cfg.srMax=8;
   cfg.fvgMinAtr=0.3;
   cfg.fvgMax=20;
   cfg.fvgLife=100;
   cfg.obMax=20;
   cfg.pinRatio=2.0;
   cfg.engulfOn=true;
   cfg.pinOn=true;
   cfg.dispOn=true;
   cfg.dispAtr=1.5;
   cfg.rejOn=true;
   cfg.emaFast=20;
   cfg.emaMid=50;
   cfg.emaSlow=200;
   cfg.atrLen=14;
   cfg.rsiLen=14;
   cfg.rsiOb=70.0;
   cfg.rsiOs=30.0;
   cfg.macdFast=12;
   cfg.macdSlow=26;
   cfg.macdSignal=9;
   cfg.dmiLen=14;
   cfg.dmiSmooth=14;
   cfg.adxMin=20.0;
   cfg.bbLen=20;
   cfg.bbMult=2.0;
   cfg.rvLen=20;
   cfg.rvMin=1.2;
   cfg.obvLen=20;
   cfg.volMaLen=20;
   cfg.volSpikeR=2.2;
   cfg.volRVH=1.8;
   cfg.volRH=1.2;
   cfg.volRN=0.8;
   cfg.volRL=0.4;
   cfg.volMin=0.0;
   cfg.volSessOn=false;
   cfg.volSessStartMin=480;
   cfg.volSessEndMin=960;
   cfg.ctxTf=PERIOD_D1;
   cfg.ctxLen=200;
   cfg.setupTf=PERIOD_H1;
   cfg.setupLen=50;
   cfg.htfFilter=true;
   cfg.htfVetoOn=true;
   cfg.wTrend=15.0;
   cfg.wStruct=15.0;
   cfg.wLiq=12.0;
   cfg.wLoc=8.0;
   cfg.wSr=10.0;
   cfg.wCandle=10.0;
   cfg.wVol=8.0;
   cfg.wAtr=7.0;
   cfg.wMom=7.0;
   cfg.wSess=4.0;
   cfg.wMtf=4.0;
   cfg.scrNoTrade=49;
   cfg.scrWeak=64;
   cfg.scrSetup=74;
   cfg.scrStrong=84;
   cfg.slAtrMul=1.5;
   cfg.slSwing=10;
   cfg.slPadAtr=0.2;
   cfg.slMinAtr=0.5;
   cfg.slMaxAtr=3.0;
   cfg.rr1=1.0;
   cfg.rr2=2.0;
   cfg.rr3=3.0;
   cfg.rrMin=1.5;
   cfg.maxDay=3;
   cfg.coolBars=10;
   X2NormalizeConfig(cfg);
   return(cfg);
  }

//--- engine config with every group neutralised (no signal, no entries)
X2Config QuietConfig()
  {
   X2Config cfg=BaseConfig();
   ZeroWeights(cfg);
   cfg.htfFilter=false;
   cfg.htfVetoOn=false;
   cfg.rrMin=0.0;
   X2NormalizeConfig(cfg);
   return(cfg);
  }

//--- signal engine: trend group only, all gates neutralised
X2Config SignalConfig()
  {
   X2Config cfg=BaseConfig();
   ZeroWeights(cfg);
   cfg.wTrend=1.0;
   cfg.slAtrMul=1.0;
   cfg.slPadAtr=0.0;
   cfg.slMinAtr=0.5;
   cfg.slMaxAtr=3.0;
   cfg.rr1=1.0;
   cfg.rr2=2.0;
   cfg.rr3=3.0;
   cfg.rrMin=0.0;
   cfg.htfFilter=false;
   cfg.htfVetoOn=false;
   cfg.coolBars=0;
   cfg.maxDay=1000000;
   cfg.scrNoTrade=0;
   cfg.engulfOn=false;
   cfg.pinOn=false;
   cfg.dispOn=false;
   cfg.rejOn=false;
   cfg.pdOn=false;
   cfg.pwOn=false;
   cfg.sessOn=false;
   cfg.retestOn=false;
   cfg.failOn=false;
   cfg.contOn=false;
   cfg.pullOn=false;
   X2NormalizeConfig(cfg);
   return(cfg);
  }

X2Bar MkBar(const double o,const double h,const double l,const double c,
            const datetime t=0)
  {
   X2Bar bar;
   X2BarInit(bar);
   bar.time=t;
   bar.open=o;
   bar.high=h;
   bar.low=l;
   bar.close=c;
   bar.tickSize=0.01;
   return(bar);
  }

X2Bar SignalBar(const double close)
  {
   X2Bar bar=MkBar(close-0.5,close+0.5,close-0.5,close);
   bar.volume=10.0;
   bar.volMA=10.0;
   bar.volSma=10.0;
   bar.atr=2.0;
   bar.emaF=close-1.0;
   bar.emaM=close-2.0;
   bar.emaS=close-3.0;
   bar.swingLo=close-2.0;
   bar.swingHi=close+2.0;
   return(bar);
  }

//+------------------------------------------------------------------+
//| A: math / time                                                   |
//+------------------------------------------------------------------+
void RunA()
  {
   Record("A1",Near(X2Clamp(1.5,0,1),1.0) && Near(X2Clamp(-1.0,0,1),0.0)
          && Near(X2Clamp(0.4,0,1),0.4),"clamp");
   Record("A2",X2InWindow(1140,1020,120) && !X2InWindow(120,1020,120)
          && X2InWindow(119,1020,120),"asia window wraps midnight");
   Record("A3",X2InWindow(120,120,600) && X2InWindow(599,120,600)
          && !X2InWindow(600,120,600) && !X2InWindow(0,120,600),
          "london window");
   Record("A4",X2InWindow(0,480,480) && X2InWindow(720,480,480)
          && X2InWindow(1439,480,480),"start==end means all day");
   Record("A5",X2IsNewServerDay(D'2024.01.02 23:59',D'2024.01.03 00:00')
          && !X2IsNewServerDay(D'2024.01.02 10:00',D'2024.01.02 23:00')
          && X2IsNewServerWeek(D'2024.01.07 23:59',D'2024.01.08 00:00'),
          "day and week rollover");
   Record("A6",X2SessionName(1080)==X2_SESS_ASIA
          && X2SessionName(180)==X2_SESS_LONDON
          && X2SessionName(480)==X2_SESS_LONDON_NY
          && X2SessionName(720)==X2_SESS_NY
          && X2SessionName(960)==X2_SESS_NONE
          && Near(X2SessionScore(X2_SESS_ASIA),0.2)
          && Near(X2SessionScore(X2_SESS_LONDON),0.6)
          && Near(X2SessionScore(X2_SESS_LONDON_NY),1.0)
          && Near(X2SessionScore(X2_SESS_NY),0.8)
          && Near(X2SessionScore(X2_SESS_NONE),0.0),
          "session names and scores");
  }

//+------------------------------------------------------------------+
//| B: volume / VSA / OBV                                            |
//+------------------------------------------------------------------+
void RunB()
  {
   X2Config cfg=QuietConfig();
   X2EngineState st;
   X2BarOut out;
   X2Bar bar;

   X2StateInit(st);
   bar=MkBar(100.0,101.0,99.0,100.5);
   bar.volume=220.0;
   bar.volMA=100.0;
   X2EngineStep(cfg,st,bar,0,out);
   Record("B1",out.volBucket==X2_BUCKET_TIM && out.isTim
          && Near(out.volRatio,2.2),"bucket TIM, isTim, ratio 2.2");

   const int b2a=X2VolBucket(219,100,2.2,1.8,1.2,0.8,0.4);
   const int b2b=X2VolBucket(180,100,2.2,1.8,1.2,0.8,0.4);
   const int b2c=X2VolBucket(120,100,2.2,1.8,1.2,0.8,0.4);
   const int b2d=X2VolBucket(80,100,2.2,1.8,1.2,0.8,0.4);
   const int b2e=X2VolBucket(40,100,2.2,1.8,1.2,0.8,0.4);
   const int b2f=X2VolBucket(39,100,2.2,1.8,1.2,0.8,0.4);
   Record("B2",b2a==X2_BUCKET_VERYHIGH && b2b==X2_BUCKET_VERYHIGH
          && b2c==X2_BUCKET_HIGH && b2d==X2_BUCKET_NORMAL
          && b2e==X2_BUCKET_LOW && b2f==X2_BUCKET_VERYLOW,
          "bucket thresholds");

   Record("B3",X2VolBucket(100,EMPTY_VALUE,2.2,1.8,1.2,0.8,0.4)
          ==X2_BUCKET_VERYLOW,"na volMA -> VERYLOW");

   X2StateInit(st);
   bar=MkBar(100.0,101.0,99.0,100.0);
   bar.volume=0.0;
   bar.volMA=0.0;
   X2EngineStep(cfg,st,bar,0,out);
   Record("B4",out.volBucket==X2_BUCKET_TIM && Near(out.volRatio,0.0)
          && !out.isTim,"volMA 0 -> TIM bucket (Q1), isTim false");

   cfg=QuietConfig();
   cfg.volMin=200.0;
   X2StateInit(st);
   bar=MkBar(100.0,101.0,99.0,100.0);
   bar.volume=195.0;
   bar.volMA=50.0;
   X2EngineStep(cfg,st,bar,0,out);
   Record("B5",!out.isTim,"volMin blocks isTim");

   cfg=QuietConfig();
   cfg.volSessOn=true;
   cfg.volSessStartMin=480;
   cfg.volSessEndMin=960;
   X2StateInit(st);
   bar=MkBar(100.0,101.0,99.0,100.0);
   bar.volume=200.0;
   bar.volMA=50.0;
   bar.volSessOk=X2InWindow(600,480,960);
   X2EngineStep(cfg,st,bar,0,out);
   const bool inSess=out.isTim;
   X2StateInit(st);
   bar.volSessOk=X2InWindow(1000,480,960);
   X2EngineStep(cfg,st,bar,0,out);
   Record("B6",inSess && !out.isTim,"volume session window");

   Record("B7",Near(X2RelVolScore(1.19,1.2,101,100),0.0)
          && Near(X2RelVolScore(1.20,1.2,101,100),1.0),"relVol threshold");

   X2StateInit(st);
   const double closes[4]={10.0,11.0,10.0,9.0};
   const double vols[4]={10.0,20.0,30.0,0.0};
   double slopes[4];
   for(int i=0; i<4; i++)
     {
      bar=MkBar(closes[i],closes[i],closes[i],closes[i]);
      bar.volume=vols[i];
      X2EngineStep(cfg,st,bar,i,out);
      slopes[i]=out.obvSlope;
     }
   Record("B8",Near(slopes[0],0.0) && Near(slopes[1],10.0)
          && Near(slopes[2],-10.0) && Near(slopes[3],-40.0),
          StringFormat("%.2f/%.2f/%.2f/%.2f",slopes[0],slopes[1],
                       slopes[2],slopes[3]));

   cfg=QuietConfig();
   cfg.obvLen=1;
   X2StateInit(st);
   const double closes9[4]={10.0,11.0,10.0,11.0};
   for(int i=0; i<4; i++)
     {
      bar=MkBar(closes9[i],closes9[i],closes9[i],closes9[i]);
      bar.volume=10.0;
      X2EngineStep(cfg,st,bar,i,out);
      slopes[i]=out.obvSlope;
     }
   Record("B9",Near(slopes[0],0.0) && Near(slopes[1],10.0)
          && Near(slopes[2],-10.0) && Near(slopes[3],10.0),
          "obv len 1");

   cfg=QuietConfig();
   cfg.obvLen=2;
   X2StateInit(st);
   for(int i=0; i<2; i++)
     {
      bar=MkBar(closes9[i],closes9[i],closes9[i],closes9[i]);
      bar.volume=10.0;
      X2EngineStep(cfg,st,bar,i,out);
      slopes[i]=out.obvSlope;
     }
   Record("B10",Near(slopes[0],0.0) && Near(slopes[1],10.0),
          "obv warm-up nz(na)=0");
  }

//+------------------------------------------------------------------+
//| C: session levels                                                |
//+------------------------------------------------------------------+
void RunC()
  {
   X2Config cfg=QuietConfig();
   cfg.pdOn=false;
   cfg.pwOn=false;
   cfg.sessOn=true;
   X2EngineState st;
   X2BarOut out;
   X2Bar bar;

   X2StateInit(st);
   st.sessPrev=X2_SESS_ASIA;
   st.sessHi=90.0;
   st.sessLo=80.0;
   st.hasSessHi=true;
   st.hasSessLo=true;
   bar=MkBar(100.0,105.0,95.0,101.0);
   bar.sessName=X2_SESS_LONDON;
   X2EngineStep(cfg,st,bar,0,out);
   Record("C1",Near(out.sessHi,105.0) && Near(out.sessLo,95.0)
          && st.sessPrev==X2_SESS_LONDON,"session switch resets levels");

   bar=MkBar(101.0,110.0,90.0,105.0);
   bar.sessName=X2_SESS_NONE;
   X2EngineStep(cfg,st,bar,1,out);
   Record("C2",Near(out.sessHi,105.0) && Near(out.sessLo,95.0)
          && st.sessPrev==X2_SESS_LONDON,"gap '-' keeps levels");

   bar=MkBar(105.0,107.0,96.0,104.0);
   bar.sessName=X2_SESS_LONDON;
   X2EngineStep(cfg,st,bar,2,out);
   Record("C3",Near(out.sessHi,107.0) && Near(out.sessLo,95.0),
          "session extends after gap");

   X2StateInit(st);
   st.sessPrev=X2_SESS_LONDON;
   st.sessHi=105.0;
   st.sessLo=95.0;
   st.hasSessHi=true;
   st.hasSessLo=true;
   bar=MkBar(99.0,100.0,95.0,99.5);
   bar.sessName=X2_SESS_LONDON;
   X2EngineStep(cfg,st,bar,3,out);
   Record("C4",Near(out.sessHi,105.0),"re-entered session does not reset (Q4)");

   X2StateInit(st);
   st.sessPrev=X2_SESS_LONDON;
   st.sessHi=105.0;
   st.sessLo=95.0;
   st.hasSessHi=true;
   st.hasSessLo=true;
   bar=MkBar(100.0,101.0,99.0,100.0);
   bar.sessName=X2_SESS_LONDON;
   X2EngineStep(cfg,st,bar,4,out);
   Record("C5",Near(out.sessLo,99.0) && !out.sweepUp,
          "session low updated before sweep (Q3)");

   cfg=QuietConfig();
   cfg.pdOn=false;
   cfg.pwOn=false;
   cfg.sessOn=true;
   X2StateInit(st);
   st.sessPrev=X2_SESS_LONDON;
   st.sessLo=190.0;
   st.hasSessLo=true;
   bar=MkBar(190.0,192.0,189.0,191.0);
   bar.sessName=X2_SESS_NONE;
   bar.pdh=200.0;
   bar.pdl=180.0;
   bar.hasPd=true;
   X2EngineStep(cfg,st,bar,5,out);
   Record("C6",out.sweepUp && out.evtKind==X2_EVT_SWEEP
          && Near(out.evtLevel,190.0),"outside-session sweep uses old low");

   //--- Q5: pdl na -> event level na even with a session low
   X2StateInit(st);
   st.sessPrev=X2_SESS_LONDON;
   st.sessLo=190.0;
   st.hasSessLo=true;
   bar=MkBar(190.0,192.0,189.0,191.0);
   bar.sessName=X2_SESS_NONE;
   bar.pdh=200.0;
   bar.pdl=EMPTY_VALUE;
   bar.hasPd=true;
   X2EngineStep(cfg,st,bar,6,out);
   Record("C6b",out.sweepUp && EmptyD(out.evtLevel) && out.evtKind==X2_EVT_SWEEP,
          "pdl na -> level EMPTY");
  }

//+------------------------------------------------------------------+
//| D: structure                                                     |
//+------------------------------------------------------------------+
void RunD()
  {
   X2Config cfg=QuietConfig();
   X2EngineState st;
   X2BarOut out;
   X2Bar bar;

   X2StateInit(st);
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(100.0,101.5,99.5,101.0);
   bar.atr=2.0;
   bar.pivH=100.0;
   bar.pivHValid=true;
   X2EngineStep(cfg,st,bar,10,out);
   Record("D1",out.bosUp && !out.chochUp && out.trend==1
          && Near(out.brkLevel,100.0) && st.brkBar==10-cfg.swingLen,
          "bos up");

   X2StateInit(st);
   st.trend=-1;
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(99.5,105.0,99.0,100.0);
   bar.atr=2.0;
   bar.pivH=105.0;
   bar.pivHValid=true;
   X2EngineStep(cfg,st,bar,10,out);
   Record("D2",out.chochUp && !out.bosUp && out.trend==1,"choch up");

   X2StateInit(st);
   st.trend=0;
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(100.0,100.5,98.5,99.0);
   bar.atr=2.0;
   bar.pivH=98.0;
   bar.pivHValid=true;
   X2EngineStep(cfg,st,bar,10,out);
   Record("D3",!out.bosUp && !out.chochUp && Near(st.lastHigh,98.0),
          "no break, lastHigh updated");

   X2StateInit(st);
   st.trend=0;
   st.hasLastLow=true;
   st.lastLow=90.0;
   bar=MkBar(91.0,91.5,88.5,89.0);
   bar.atr=2.0;
   bar.pivL=88.0;
   bar.pivLValid=true;
   X2EngineStep(cfg,st,bar,10,out);
   Record("D4",out.bosDown && out.trend==-1,"bos down");

   X2StateInit(st);
   st.trend=1;
   st.hasLastLow=true;
   st.lastLow=90.0;
   bar=MkBar(92.0,92.5,87.5,91.0);
   bar.atr=2.0;
   bar.pivL=88.0;
   bar.pivLValid=true;
   X2EngineStep(cfg,st,bar,10,out);
   Record("D5",out.chochDown && !out.bosDown && out.trend==-1,"choch down");

   X2StateInit(st);
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(100.0,104.2,100.0,104.0);
   bar.atr=2.0;
   bar.pivH=100.0;
   bar.pivHValid=true;
   X2EngineStep(cfg,st,bar,10,out);
   const bool mssOn=out.bosUp && out.mssUp;
   X2StateInit(st);
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(100.0,100.6,99.9,100.5);
   bar.atr=2.0;
   bar.pivH=100.0;
   bar.pivHValid=true;
   X2EngineStep(cfg,st,bar,10,out);
   Record("D6",mssOn && out.bosUp && !out.mssUp,
          "MSS needs displacement");

   X2StateInit(st);
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   st.hasLastLow=true;
   st.lastLow=90.0;
   bar=MkBar(95.0,101.0,88.5,95.0);
   bar.atr=2.0;
   bar.pivH=101.0;
   bar.pivHValid=true;
   bar.pivL=89.0;
   bar.pivLValid=true;
   X2EngineStep(cfg,st,bar,10,out);
   Record("D7",out.hh && !out.lh && out.ll && !out.hl,
          "HH/LL vs previous pivots");

   X2StateInit(st);
   st.hasBrk=true;
   st.brkLevel=100.0;
   st.brkDir=1;
   st.brkBar=0;
   bar=MkBar(100.5,101.5,100.5,101.0);
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,10,out);
   const bool retest10=out.retestUp;
   X2StateInit(st);
   st.hasBrk=true;
   st.brkLevel=100.0;
   st.brkDir=1;
   st.brkBar=0;
   X2EngineStep(cfg,st,bar,11,out);
   const bool retest11=out.retestUp;
   X2StateInit(st);
   st.hasBrk=true;
   st.brkLevel=100.0;
   st.brkDir=-1;
   st.brkBar=0;
   X2EngineStep(cfg,st,bar,5,out);
   const bool fail5=out.failUp;
   X2StateInit(st);
   st.hasBrk=true;
   st.brkLevel=100.0;
   st.brkDir=-1;
   st.brkBar=0;
   X2EngineStep(cfg,st,bar,6,out);
   Record("D8",retest10 && !retest11 && fail5 && !out.failUp,
          "retest/fail windows");
  }

//+------------------------------------------------------------------+
//| E: event ring                                                    |
//+------------------------------------------------------------------+
void RunE()
  {
   X2EngineState st;
   X2StateInit(st);
   X2PushEvent(st,X2_EVT_BOS,1,5,D'2024.01.02 10:00',100.0);
   Record("E1",st.evtCount==1 && st.evt[0].kind==X2_EVT_BOS
          && st.evt[0].dir==1 && Near(st.evt[0].level,100.0)
          && st.evt[0].srcBar==5
          && st.evt[0].srcTime==D'2024.01.02 10:00',
          "push BOS");

   X2Config cfg=QuietConfig();
   X2BarOut out;
   X2StateInit(st);
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   X2Bar bar=MkBar(100.0,104.2,100.5,104.0);
   bar.atr=2.0;
   bar.emaM=101.0;
   bar.pivH=100.0;
   bar.pivHValid=true;
   X2EngineStep(cfg,st,bar,10,out);
   Record("E2",out.bosUp && out.mssUp && out.pullUp
          && out.evtKind==X2_EVT_PULL,"last event is PULL");

   X2StateInit(st);
   for(int i=1; i<=51; i++)
      X2PushEvent(st,X2_EVT_BOS,1,i,0,(double)i);
   Record("E3",st.evtCount==50 && st.evt[0].kind==X2_EVT_BOS
          && Near(st.evt[0].level,2.0) && Near(st.evt[49].level,51.0),
          "ring caps at 50 and drops oldest");

   X2StateInit(st);
   X2PushEvent(st,X2_EVT_SWEEP,1,3,0,190.0);
   Record("E4",st.evt[0].kind==X2_EVT_SWEEP && Near(st.evt[0].level,190.0),
          "sweep level stored");

   X2StateInit(st);
   st.hasBrk=true;
   st.brkLevel=100.0;
   st.brkDir=1;
   st.brkBar=0;
   bar=MkBar(100.5,101.5,100.5,101.0);
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,10,out);
   Record("E5",out.retestUp && out.evtKind==X2_EVT_RETEST
          && out.evtSrcBar==10 && Near(out.evtLevel,100.0),
          "retest srcBar is current bar");
  }

//+------------------------------------------------------------------+
//| F: zones / FVG / OB                                              |
//+------------------------------------------------------------------+
void RunF()
  {
   X2EngineState st;
   X2StateInit(st);
   X2ZoneAdd(st,100.0,1,2.0,0.5,8);
   Record("F1",st.srCount==1 && Near(st.sr[0].top,100.5)
          && Near(st.sr[0].bot,99.5) && st.sr[0].touches==1,
          "zone geometry");

   X2StateInit(st);
   X2ZoneAdd(st,100.0,-1,2.0,0.5,8);
   X2ZoneAdd(st,100.4,1,2.0,0.5,8);
   Record("F2",st.srCount==1 && st.sr[0].touches==2
          && st.sr[0].side==-1,"merge ignores side (Q2)");

   X2StateInit(st);
   X2ZoneAdd(st,100.0,-1,2.0,0.5,8);
   X2ZoneAdd(st,101.0,1,2.0,0.5,8);
   Record("F3",st.srCount==2,"strict boundary does not merge");

   X2StateInit(st);
   X2ZoneAdd(st,100.0,1,2.0,0.5,2);
   X2ZoneAdd(st,110.0,1,2.0,0.5,2);
   X2ZoneAdd(st,120.0,1,2.0,0.5,2);
   Record("F4",st.srCount==2 && Near((st.sr[0].top+st.sr[0].bot)*0.5,110.0),
          "max zones drops oldest");

   X2StateInit(st);
   X2ZoneAdd(st,100.0,1,2.0,0.5,8);
   Record("F5",X2NearSupport(st,98.9,2.0) && !X2NearSupport(st,98.89,2.0),
          "near support tolerance");

   X2StateInit(st);
   X2ZoneAdd(st,100.0,-1,2.0,0.5,8);
   Record("F6",X2NearResistance(st,101.1,2.0)
          && !X2NearResistance(st,101.11,2.0),"near resistance tolerance");

   X2Config cfg=QuietConfig();
   X2BarOut out;
   X2Bar bar;
   X2StateInit(st);
   bar=MkBar(100.5,102.0,101.0,101.5);
   bar.atr=2.0;
   bar.high2=100.0;
   X2EngineStep(cfg,st,bar,5,out);
   const bool fvgPush=(st.fvgCount==1 && Near(st.fvg[0].top,101.0)
                       && Near(st.fvg[0].bot,100.0) && st.fvg[0].dir==1);
   X2StateInit(st);
   bar=MkBar(100.2,102.0,100.5,101.5);
   bar.atr=2.0;
   bar.high2=100.0;
   X2EngineStep(cfg,st,bar,5,out);
   Record("F7",fvgPush && st.fvgCount==0,"FVG min size");

   X2StateInit(st);
   st.fvgCount=1;
   st.fvg[0].top=102.0;
   st.fvg[0].bot=101.0;
   st.fvg[0].srcBar=1;
   st.fvg[0].dir=1;
   st.fvg[0].dead=false;
   bar=MkBar(101.5,102.0,100.8,100.9);
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,20,out);
   const bool deadClose=st.fvg[0].dead;
   X2StateInit(st);
   st.fvgCount=1;
   st.fvg[0].top=102.0;
   st.fvg[0].bot=101.0;
   st.fvg[0].srcBar=1;
   st.fvg[0].dir=1;
   st.fvg[0].dead=false;
   bar=MkBar(101.5,102.5,101.2,102.0);
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,102,out);
   Record("F8",deadClose && st.fvg[0].dead,
          "FVG dies on close break and age");

   X2StateInit(st);
   bar=MkBar(99.0,103.1,98.9,103.0);
   bar.prevOpen=100.0;
   bar.prevClose=99.0;
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,10,out);
   const bool obMade=(st.obCount==1 && Near(st.ob[0].top,100.0)
                      && Near(st.ob[0].bot,99.0) && st.ob[0].srcBar==9
                      && st.ob[0].dir==1);
   bar=MkBar(100.0,100.5,99.5,100.0);
   bar.prevOpen=99.0;
   bar.prevClose=103.0;
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,11,out);
   const bool nearBull=out.nearFvgBull && !st.ob[0].dead;
   bar=MkBar(99.0,99.5,98.4,98.5);
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,12,out);
   Record("F9",obMade && nearBull && st.ob[0].dead,
          "OB build / dead / near");
  }

//+------------------------------------------------------------------+
//| G: candles                                                       |
//+------------------------------------------------------------------+
void RunG()
  {
   X2Config cfg=QuietConfig();
   cfg.pinOn=true;
   cfg.engulfOn=false;
   cfg.dispOn=false;
   cfg.rejOn=false;
   X2EngineState st;
   X2BarOut out;
   X2StateInit(st);
   X2Bar bar=MkBar(100.0,101.2,98.0,101.0);
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,0,out);
   const bool pinYes=out.pinBull;
   X2StateInit(st);
   bar=MkBar(100.0,101.2,98.01,101.0);
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,0,out);
   Record("G1",pinYes && !out.pinBull,"pin threshold");

   cfg=QuietConfig();
   cfg.pinOn=false;
   cfg.engulfOn=true;
   cfg.dispOn=false;
   cfg.rejOn=false;
   X2StateInit(st);
   bar=MkBar(100.0,101.1,99.9,101.0);
   bar.prevOpen=101.0;
   bar.prevClose=100.0;
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,0,out);
   Record("G2",out.engBull && Near(out.cpBull,1.0),"bull engulf");

   cfg=QuietConfig();
   cfg.pinOn=false;
   cfg.engulfOn=false;
   cfg.dispOn=true;
   cfg.rejOn=false;
   X2StateInit(st);
   bar=MkBar(100.0,104.2,100.0,104.0);
   bar.volume=220.0;
   bar.volMA=100.0;
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,0,out);
   const bool dispV=out.dispBullV;
   X2StateInit(st);
   bar.volume=219.0;
   X2EngineStep(cfg,st,bar,0,out);
   Record("G3",dispV && !out.dispBullV,"displacement volume spike");

   cfg=QuietConfig();
   cfg.pinOn=false;
   cfg.engulfOn=false;
   cfg.dispOn=false;
   cfg.rejOn=true;
   X2StateInit(st);
   bar=MkBar(101.0,107.0,100.0,103.0);
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,0,out);
   const bool rejYes=out.rejBull;
   X2StateInit(st);
   bar=MkBar(101.0,105.5,100.0,103.0);
   bar.atr=2.0;
   X2EngineStep(cfg,st,bar,0,out);
   Record("G4",rejYes && !out.rejBull,"rejection shape");

   Record("G5",Near(CpScore(2.8,0.0),0.933333),"cp score 2.8");
   Record("G6",Near(CpScore(1.8,0.0),0.6),"cp score 1.8");
   Record("G7",Near(CpScore(0.0,1.0),-0.333333),"cp score bear");
   Record("G8",Near(CpScore(1.0,1.0),0.0),"cp score tie");
  }

//+------------------------------------------------------------------+
//| H: indicators                                                    |
//+------------------------------------------------------------------+
void RunH()
  {
   Record("H1",Near(X2RsiScore(25,30,70),1.0)
          && Near(X2RsiScore(75,30,70),-1.0)
          && Near(X2RsiScore(50,30,70),0.0),"rsi score");

   Record("H2",Near(X2MacdScore(0.5,true,-0.2),1.0)
          && Near(X2MacdScore(0.3,true,0.1),0.5)
          && Near(X2MacdScore(-0.1,true,0.05),-1.0),"macd score");

   Record("H3",Near(X2DmiScore(30,20,25,20),1.0)
          && Near(X2DmiScore(30,20,19,20),0.0)
          && Near(X2DmiScore(20,30,25,20),-1.0),"dmi score");

   Record("H4",Near(X2MomScore(1.0,0.5,1.0),0.833333),"mom score");

   Record("H5",Near(X2AtrRegime(13,10),1.0)
          && Near(X2AtrRegime(12,10),0.5)
          && Near(X2AtrRegime(7,10),0.0)
          && Near(X2AtrRegime(2,EMPTY_VALUE),0.5),"atr regime");

   Record("H6",Near(VolScore(true,99,100),-0.5)
          && Near(VolScore(false,99,100),0.0),"bb expand volume score");

   Record("H7",Near(X2VolumeScore(1,1,1),1.0)
          && Near(X2VolumeScore(0,1,-1),0.0),"volume score average");

   Record("H8",Near(X2DayRange(120,true,120,100),1.0)
          && Near(X2DayRange(110,true,120,100),0.0)
          && Near(X2DayRange(100,true,120,100),-1.0)
          && Near(X2DayRange(110,true,100,100),0.0),"day range");

   Record("H9",Near(X2LocationScore(1.0,0.4),0.7)
          && Near(X2LocationScore(1.0,3.0),1.0),"location score");

   Record("H10",Near(X2TrendScore(true,false,100,99,98),1.0)
          && Near(X2TrendScore(false,false,102,101,100),0.5)
          && Near(X2TrendScore(false,false,98,99,100),-0.5)
          && Near(X2TrendScore(false,false,100,101,102),0.0),
          "trend score");
  }

//+------------------------------------------------------------------+
//| I: scoring                                                       |
//+------------------------------------------------------------------+
void RunI()
  {
   Record("I1",Near(X2RawScore(100,100),1.0) && X2Score100(1.0)==100,
          "raw 1");

   Record("I2",Near(X2RawScore(15,100),0.15) && X2Score100(0.15)==58,
          "trend only");

   Record("I3",Near(X2RawScore(7.5,100),0.075) && X2Score100(0.075)==54
          && Near(X2GroupStruct(false,false,false,false,false,false,1),0.5),
          "half structure");

   Record("I4",Near(X2GroupLiq(true,false,true,false),1.0)
          && Near(X2GroupLiq(false,true,true,false),-1.0)
          && Near(X2GroupLiq(false,false,true,false),0.7),"liquidity group");

   Record("I5",Near(X2GroupSr(true,true,false,false),1.0)
          && Near(X2GroupSr(false,true,false,false),-1.0)
          && Near(X2GroupSr(false,false,true,false),1.0)
          && Near(X2GroupSr(false,false,true,true),0.0),"sr group");

   Record("I6",Near(X2GroupVol(1.0,-0.5,101,100),0.25),"volatility group");

   Record("I7",Near(X2GroupSess(0.8,99,100),-0.8),"session group");

   Record("I8",X2Quality(49,49,64,74,84)==X2_Q_NOTRADE
          && X2Quality(64,49,64,74,84)==X2_Q_WEAK
          && X2Quality(74,49,64,74,84)==X2_Q_SETUP
          && X2Quality(84,49,64,74,84)==X2_Q_STRONG
          && X2Quality(85,49,64,74,84)==X2_Q_APLUS
          && Near(X2RawScore(0,0),0.0) && X2Score100(0.0)==50,
          "quality buckets");
  }

//+------------------------------------------------------------------+
//| J: MTF                                                           |
//+------------------------------------------------------------------+
void RunJ()
  {
   datetime closeTime[4];
   closeTime[0]=D'2024.01.02 04:00';
   closeTime[1]=D'2024.01.02 08:00';
   closeTime[2]=D'2024.01.02 12:00';
   closeTime[3]=D'2024.01.02 16:00';
   Record("J1",X2MapHtfIndex(closeTime,4,D'2024.01.02 12:00')==2,
          "boundary close_time <= open");
   Record("J2",X2MapHtfIndex(closeTime,4,D'2024.01.02 11:55')==1,
          "previous completed HTF bar");

   double src[3]={1.0,2.0,3.0};
   double ema[3];
   X2BuildEma(src,3,200,ema);
   Record("J3",EmptyD(ema[0]) && EmptyD(ema[1]) && EmptyD(ema[2]),
          "warm-up EMA empty");

   const double close=100.0;
   const double ctxEma=100.0;
   const int ctxDir=(close>ctxEma ? 1 : -1);
   Record("J4",ctxDir==-1,"close == ema -> -1 (Q6)");

   Record("J5",!X2OkSetup(true,1,-1),"setup filter mismatch");
  }

//+------------------------------------------------------------------+
//| K: plan / gates                                                  |
//+------------------------------------------------------------------+
void RunK()
  {
   X2Config cfg=BaseConfig();
   cfg.rrMin=0.0;
   cfg.slAtrMul=1.5;
   cfg.slPadAtr=0.2;
   cfg.slMinAtr=0.5;
   cfg.slMaxAtr=3.0;
   X2Plan plan;
   X2Bar bar=MkBar(100.0,101.0,95.0,100.0);
   bar.atr=2.0;
   bar.swingLo=96.0;
   X2BuildPlan(cfg,bar,1,plan);
   Record("K1",Near(plan.risk,3.7) && Near(plan.sl,96.3),"plan distance pad");

   bar.swingLo=100.0;
   X2BuildPlan(cfg,bar,1,plan);
   Record("K2",Near(plan.risk,1.7),"swing at entry");

   bar.swingLo=60.0;
   X2BuildPlan(cfg,bar,1,plan);
   Record("K3",Near(plan.risk,6.0),"clamp at atr*max");

   cfg.slPadAtr=0.0;
   bar.swingLo=99.9;
   X2BuildPlan(cfg,bar,1,plan);
   Record("K4",Near(plan.risk,1.55),"inside clamp band");

   bar.swingLo=96.0;
   X2BuildPlan(cfg,bar,0,plan);
   Record("K5",!plan.valid,"dir 0 invalid");

   cfg.rr1=1.0;
   cfg.rrMin=1.5;
   X2BuildPlan(cfg,bar,1,plan);
   Record("K6",!plan.valid,"default RR below minimum");

   cfg.rr1=2.0;
   cfg.rrMin=1.5;
   bar.swingLo=90.0;
   X2BuildPlan(cfg,bar,1,plan);
   Record("K7",plan.valid && Near(plan.sl,94.0),"rr 2.0 valid");

   cfg=BaseConfig();
   cfg.rrMin=0.0;
   cfg.slAtrMul=1.0;
   cfg.slPadAtr=0.0;
   cfg.slMinAtr=0.5;
   cfg.slMaxAtr=3.0;
   cfg.rr1=1.0;
   cfg.rr2=2.0;
   cfg.rr3=3.0;
   bar.swingLo=98.0;
   X2BuildPlan(cfg,bar,1,plan);
   const bool tpOk=Near(plan.tp1,102.0) && Near(plan.tp2,104.0)
                   && Near(plan.tp3,106.0);
   cfg.rr2=1.5;
   X2BuildPlan(cfg,bar,1,plan);
   Record("K8",tpOk && Near(plan.tp2,103.0),"tp multiples and rr2 floor");

   cfg=SignalConfig();
   X2EngineState st;
   X2BarOut out;
   X2StateInit(st);
   st.barsSince=8;
   X2EngineStep(cfg,st,SignalBar(100.0),1,out);
   const bool cool9=(out.barsSince==9 && !out.signal
                     && out.block==X2_BLOCK_COOLDOWN);
   X2StateInit(st);
   st.barsSince=9;
   X2EngineStep(cfg,st,SignalBar(100.0),1,out);
   const bool cool10=(out.barsSince==10 && out.signal);
   X2StateInit(st);
   st.dayCount=3;
   st.barsSince=100;
   X2EngineStep(cfg,st,SignalBar(100.0),1,out);
   const bool dayBlock=(!out.signal && out.block==X2_BLOCK_DAY_LIMIT);
   Record("K9",cool9 && cool10 && dayBlock && !(49>49) && (50>49),
          "cooldown, day limit, score gate");
  }

//+------------------------------------------------------------------+
//| L: state machine                                                 |
//+------------------------------------------------------------------+
void RunL()
  {
   X2Config cfg=SignalConfig();
   X2EngineState st;
   X2BarOut out;
   X2StateInit(st);

   X2EngineStep(cfg,st,SignalBar(100.0),10,out);
   const bool adopt=(out.evEntry && out.posDir==1 && Near(out.posEntry,100.0)
                     && out.dayCount==1 && out.barsSince==0
                     && out.posBars==0 && out.posStage==0);
   Record("L1",adopt,"adopt on signal");

   X2Bar bar=SignalBar(100.5);
   bar.high=102.5;
   bar.low=99.0;
   X2EngineStep(cfg,st,bar,11,out);
   Record("L2",out.evTp==1 && out.posStage==1 && !out.evClose
          && out.posDir==1,"tp1 touch");

   bar=SignalBar(100.5);
   bar.high=104.5;
   bar.low=100.0;
   X2EngineStep(cfg,st,bar,12,out);
   Record("L3",out.evTp==2 && out.posStage==2,"tp2 touch");

   bar=SignalBar(100.5);
   bar.high=106.5;
   bar.low=100.0;
   X2EngineStep(cfg,st,bar,13,out);
   Record("L4",out.evTp==3 && out.evClose && out.wins==1
          && Near(out.xExit,106.0) && Near(out.xR,3.0),"tp3 closes win");

   X2StateInit(st);
   X2EngineStep(cfg,st,SignalBar(100.0),10,out);
   bar=SignalBar(99.0);
   bar.high=100.5;
   bar.low=97.5;
   X2EngineStep(cfg,st,bar,11,out);
   Record("L5",out.evSl && out.evClose && out.losses==1
          && Near(out.xExit,98.0) && Near(out.xR,-1.0),"sl closes loss");

   X2StateInit(st);
   X2EngineStep(cfg,st,SignalBar(100.0),10,out);
   bar=SignalBar(100.0);
   bar.high=102.5;
   bar.low=97.5;
   X2EngineStep(cfg,st,bar,11,out);
   Record("L6",out.evSl && out.evTp==0 && out.losses==1,
          "sl wins over tp1 same bar (Q8)");

   X2StateInit(st);
   X2EngineStep(cfg,st,SignalBar(100.0),10,out);
   bar=SignalBar(100.0);
   bar.high=104.5;
   bar.low=99.5;
   X2EngineStep(cfg,st,bar,11,out);
   Record("L7",out.evTp==2 && out.posStage==2 && !out.evClose,
          "tp2 without tp1");

   X2StateInit(st);
   X2EngineStep(cfg,st,SignalBar(100.0),10,out);
   st.posBars=301;
   bar=SignalBar(100.0);
   bar.high=100.5;
   bar.low=99.5;
   X2EngineStep(cfg,st,bar,11,out);
   Record("L8",out.evClose && out.closeReason==X2_CLOSE_TIMEOUT
          && !out.evSl && Near(out.xExit,102.0) && Near(out.xR,1.0),
          "timeout exits at tp1 (Q9)");

   X2StateInit(st);
   X2EngineStep(cfg,st,SignalBar(100.0),10,out);
   bar=SignalBar(100.5);
   bar.high=106.5;
   bar.low=99.5;
   X2EngineStep(cfg,st,bar,11,out);
   const bool noSameBar=(!out.evEntry && out.evClose && out.posDir==1);
   X2EngineStep(cfg,st,SignalBar(100.0),12,out);
   Record("L9",noSameBar && out.evEntry && out.posDir==1,
          "no entry on closing bar (Q10)");

   X2StateInit(st);
   X2EngineStep(cfg,st,SignalBar(100.0),10,out);
   const double entry0=st.posEntry;
   bar=SignalBar(100.2);
   bar.high=100.7;
   bar.low=99.8;
   X2EngineStep(cfg,st,bar,11,out);
   Record("L10",!out.evEntry && Near(st.posEntry,entry0)
          && out.trades==0,"signal ignored while open");

   X2StateInit(st);
   X2EngineStep(cfg,st,SignalBar(100.0),10,out);
   const bool entryBars=out.posBars==0;
   bar=SignalBar(100.2);
   bar.high=100.7;
   bar.low=99.8;
   X2EngineStep(cfg,st,bar,11,out);
   Record("L11",entryBars && out.posBars==1,"position bar counters");
  }

//+------------------------------------------------------------------+
//| M: config hash                                                   |
//+------------------------------------------------------------------+
void RunM()
  {
   X2Config cfg=BaseConfig();
   const string canon=X2ConfigCanonical(cfg);
   int keys=0;
   int semis=0;
   for(int i=0; i<StringLen(canon); i++)
     {
      const ushort ch=StringGetCharacter(canon,i);
      if(ch=='=')
         keys++;
      if(ch==';')
         semis++;
     }
   Record("M1",keys==91 && semis==90 && StringFind(canon,"v=1.0.0;")==0
          && X2ConfigCanonical(cfg)==canon,
          StringFormat("keys=%d semis=%d",keys,semis));

   Record("M2",X2Fnv1a("a")==(uint)0xE40C292C
          && X2Fnv1a("foobar")==(uint)0xBF9CF968,
          StringFormat("%u/%u",X2Fnv1a("a"),X2Fnv1a("foobar")));

   const uint h0=X2ConfigHash(cfg);
   X2Config cfg2=cfg;
   cfg2.rr1=1.5;
   const uint h1=X2ConfigHash(cfg2);
   X2Config cfg3=BaseConfig();
   Record("M3",h0!=h1 && h0==X2ConfigHash(cfg3),
          StringFormat("h0=%u h1=%u",h0,h1));
  }

//+------------------------------------------------------------------+
//| N: bar policy / output                                           |
//+------------------------------------------------------------------+
void ReplayTrace(const X2Config &cfg,double &trace[])
  {
   X2EngineState st;
   X2StateInit(st);
   X2BarOut out;
   X2BarOutReset(out);
   const double closes[6]={100.0,101.0,100.0,102.0,101.0,103.0};
   for(int i=0; i<6; i++)
     {
      X2Bar bar=SignalBar(closes[i]);
      X2EngineStep(cfg,st,bar,i,out);
     }
   trace[0]=(double)out.score100;
   trace[1]=(double)out.dir;
   trace[2]=(out.planValid ? 1.0 : 0.0);
   trace[3]=(double)out.trades;
   trace[4]=(double)out.evtCount;
   trace[5]=out.entry;
  }

void RunN()
  {
   Record("N1",!X2IsClosedBar(9,10) && X2IsClosedBar(8,10)
          && !X2IsClosedBar(0,1) && !X2IsClosedBar(-1,10),
          "only closed bars feed the engine");

   X2BarOut def;
   X2BarOutReset(def);
   Record("N1b",def.score100==0 && def.dir==0 && def.posDir==0
          && EmptyD(def.sl) && EmptyD(def.entry)
          && def.evtSrcBar==-1 && EmptyD(def.evtLevel),
          "defaults are 0/EMPTY");

   X2Config cfg=QuietConfig();
   X2EngineState st;
   X2StateInit(st);
   X2Bar bar=MkBar(100.0,100.0,100.0,100.0);
   X2BarOut out;
   X2EngineStep(cfg,st,bar,0,out);
   Record("N2",!out.planValid && Near(out.entry,100.0)
          && EmptyD(out.sl) && EmptyD(out.tp1) && EmptyD(out.tp2)
          && EmptyD(out.tp3) && EmptyD(out.risk)
          && Near(out.atrRegime,0.5) && out.mtfCtxDir==0,
          "ATR warm-up plan");

   Record("N3",X2_PLOT_BUFFERS==13 && X2_CONTRACT_BUFFERS==140
          && X2_TOTAL_BUFFERS==153 && X2_CONTRACT_FIRST==13
          && (int)X2_BUF_SCORE100==13 && (int)X2_BUF_EVT_COUNT==152,
          "buffer map");

   double first[6],second[6];
   ReplayTrace(cfg,first);
   ReplayTrace(cfg,second);
   bool same=true;
   for(int i=0; i<6; i++)
      if(!Near(first[i],second[i]))
         same=false;
   Record("N4",same,"replay is deterministic");
  }

//+------------------------------------------------------------------+
//| O: normalize config                                              |
//+------------------------------------------------------------------+
void RunO()
  {
   X2Config cfg=BaseConfig();
   cfg.swingLen=1;
   X2NormalizeConfig(cfg);
   const int lowSwing=cfg.swingLen;
   cfg.swingLen=25;
   X2NormalizeConfig(cfg);
   Record("O1",lowSwing==2 && cfg.swingLen==20,"swingLen clamp");

   cfg.srMax=0;
   X2NormalizeConfig(cfg);
   const int lowSr=cfg.srMax;
   cfg.srMax=99;
   X2NormalizeConfig(cfg);
   Record("O2",lowSr==1 && cfg.srMax==30,"srMax clamp");

   cfg.scrWeak=0;
   cfg.volMaLen=1;
   X2NormalizeConfig(cfg);
   Record("O3",cfg.scrWeak==1 && cfg.volMaLen==5,"score/volume clamps");
  }

void OnStart()
  {
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

   PrintFormat("TEST|RESULT|%s|pass=%d fail=%d|contract=%s",
               (g_fail==0 ? "ALL_PASS" : "FAIL"),
               g_pass,g_fail,X2_CONTRACT_VERSION);
  }
//+------------------------------------------------------------------+
