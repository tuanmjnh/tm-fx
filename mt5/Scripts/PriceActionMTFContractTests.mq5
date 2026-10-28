//+------------------------------------------------------------------+
//|                              PriceActionMTFContractTests.mq5     |
//|      MT5 EA & AI Lab - synthetic checks for the PA MTF contract  |
//|                                                                  |
//| Runs once. No file I/O, no market data, no account access, no    |
//| trading functions. Vectors: docs/indicators/price-action-mtf.md|
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Synthetic contract tests for Price Action MTF. No trading."

#include "../Include/PinePort/PriceActionMTFContract.mqh"

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
   return(PaIsEmpty(v));
  }

void ZeroWeights(PaConfig &cfg)
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

PaConfig BaseConfig()
  {
   PaConfig cfg;
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
   cfg.ibOn=true;
   cfg.dojiOn=true;
   cfg.dojiMax=0.10;
   cfg.soldOn=true;
   cfg.strongBody=0.50;
   cfg.volVetoOn=true;
   cfg.volVetoR=1.2;
   cfg.streakOn=true;
   cfg.streakMin=2;
   cfg.streakAdd=0.5;
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
   cfg.tpMode=PA_TP_R;
   cfg.tpMmFallback=true;
   cfg.regOn=true;
   cfg.regAdxTrend=25.0;
   cfg.regAdxChop=18.0;
   cfg.regBbwLen=100;
   cfg.regBbwSqueeze=20.0;
   cfg.regRangeEdge=0.35;
   cfg.patOn=true;
   cfg.patBandAtr=0.5;
   cfg.patMaxBars=200;
   cfg.hsRatio=1.2;
   cfg.cfOn=true;
   cfg.cfLevelTolAtr=0.5;
   cfg.cfRequire3=true;
   PaNormalizeConfig(cfg);
   return(cfg);
  }

//--- signal engine with all gates neutralised
PaConfig SignalConfig()
  {
   PaConfig cfg=BaseConfig();
   ZeroWeights(cfg);
   cfg.wTrend=1.0;
   cfg.slAtrMul=0.1;
   cfg.slPadAtr=0.0;
   cfg.slMinAtr=0.5;
   cfg.slMaxAtr=3.0;
   cfg.rr1=1.0;
   cfg.rr2=2.0;
   cfg.rr3=3.0;
   cfg.rrMin=0.0;
   cfg.cfOn=false;
   cfg.regOn=false;
   cfg.htfFilter=false;
   cfg.htfVetoOn=false;
   cfg.coolBars=0;
   cfg.maxDay=1000000;
   cfg.scrNoTrade=0;
   cfg.patOn=false;
   cfg.engulfOn=false;
   cfg.pinOn=false;
   cfg.dispOn=false;
   cfg.rejOn=false;
   cfg.ibOn=false;
   cfg.dojiOn=false;
   cfg.soldOn=false;
   cfg.streakOn=false;
   cfg.volVetoOn=false;
   cfg.tpMode=PA_TP_R;
   PaNormalizeConfig(cfg);
   return(cfg);
  }

PaBar MkBar(const double o,const double h,const double l,const double c,
            const datetime t=0)
  {
   PaBar bar;
   PaBarInit(bar);
   bar.time=t;
   bar.open=o;
   bar.high=h;
   bar.low=l;
   bar.close=c;
   bar.tickSize=0.01;
   return(bar);
  }

PaBar SignalBar(const double close,const datetime t=0)
  {
   PaBar bar=MkBar(close-0.5,close+0.5,close-0.5,close,t);
   bar.volume=10.0;
   bar.volMA=10.0;
   bar.volSma=10.0;
   bar.atr=2.0;
   bar.emaF=close-1.0;
   bar.emaM=close-2.0;
   bar.emaS=close-3.0;
   bar.swingLo=close;
   bar.swingHi=close;
   return(bar);
  }

void SeedPattern(PaEngineState &st,const int kind,const int dir,const double neck,
                 const int bBar)
  {
   PaPattern p;
   p.kind=kind;
   p.dir=dir;
   p.a=0.0;
   p.b=0.0;
   p.c=0.0;
   p.neck=neck;
   p.aBar=0;
   p.bBar=bBar;
   p.cBar=0;
   p.broken=false;
   p.brkBar=0;
   st.pats[0]=p;
   st.patCount=1;
  }

//+------------------------------------------------------------------+
//| A: math / time                                                   |
//+------------------------------------------------------------------+
void RunA()
  {
   Record("A1",Near(PaClamp(1.5,0,1),1.0) && Near(PaClamp(-1.0,0,1),0.0)
          && Near(PaClamp(0.4,0,1),0.4),"clamp");
   Record("A2",PaInWindow(1140,1020,120) && !PaInWindow(120,1020,120)
          && PaInWindow(119,1020,120),"asia window wraps midnight");
   Record("A3",PaInWindow(120,120,600) && PaInWindow(599,120,600)
          && !PaInWindow(600,120,600),"london window");
   Record("A4",PaInWindow(0,480,480) && PaInWindow(720,480,480)
          && PaInWindow(1439,480,480),"start==end means all day");
   Record("A5",PaIsNewServerDay(D'2024.01.01 23:59',D'2024.01.02 00:00')
          && PaIsNewServerWeek(D'2024.01.07 23:00',D'2024.01.08 00:00'),
          "day and week rollover");
  }

//+------------------------------------------------------------------+
//| B: series builders                                               |
//+------------------------------------------------------------------+
void RunB()
  {
   double src[];
   double out[];
   ArrayResize(src,4);
   src[0]=1.0; src[1]=2.0; src[2]=3.0; src[3]=4.0;
   PaBuildSma(src,4,3,out);
   Record("B1",Near(out[2],2.0) && Near(out[3],3.0),"sma len3");

   PaBuildEma(src,4,3,out);
   Record("B2",Near(out[2],2.0) && Near(out[3],3.0),"ema len3 seed+step");

   double src3[];
   ArrayResize(src3,3);
   src3[0]=10.0; src3[1]=20.0; src3[2]=30.0;
   PaBuildEma(src3,3,2,out);
   Record("B3",Near(out[1],15.0) && Near(out[2],25.0),"ema len2");

   PaBuildRma(src,4,3,out);
   Record("B4",Near(out[2],2.0) && Near(out[3],8.0/3.0),"rma len3");

   double h[],l[],c[];
   ArrayResize(h,3); ArrayResize(l,3); ArrayResize(c,3);
   h[0]=3.0; h[1]=4.0; h[2]=6.0;
   l[0]=1.0; l[1]=2.0; l[2]=2.0;
   c[0]=2.0; c[1]=3.0; c[2]=5.0;
   PaBuildAtr(h,l,c,3,2,out);
   Record("B5",Near(out[1],2.0) && Near(out[2],3.0),"atr len2 over TR 2,2,4");

   double rsiSrc[];
   ArrayResize(rsiSrc,4);
   rsiSrc[0]=1.0; rsiSrc[1]=2.0; rsiSrc[2]=3.0; rsiSrc[3]=2.0;
   PaBuildRsi(rsiSrc,4,2,out);
   Record("B6",Near(out[2],100.0) && Near(out[3],50.0),"rsi len2");

   double up10[];
   ArrayResize(up10,10);
   double dn10[];
   ArrayResize(dn10,10);
   for(int i=0; i<10; i++)
     {
      up10[i]=(double)(i+1);
      dn10[i]=(double)(10-i);
     }
   PaBuildMacdHist(up10,10,2,3,2,out);
   const bool macdUp=(out[9]>0.0);
   PaBuildMacdHist(dn10,10,2,3,2,out);
   Record("B7",macdUp && out[9]<0.0,"macd hist sign follows slope");

   double hi6[],lo6[],cl6[];
   ArrayResize(hi6,6); ArrayResize(lo6,6); ArrayResize(cl6,6);
   for(int i=0; i<6; i++)
     {
      hi6[i]=(double)(i+1);
      lo6[i]=(double)(i+1)-0.5;
      cl6[i]=(double)(i+1);
     }
   double diP[],diM[],adx[];
   PaBuildDmi(hi6,lo6,cl6,6,2,2,diP,diM,adx);
   Record("B8",diP[5]>diM[5] && adx[5]>20.0,"dmi rising series");

   double bb3[];
   ArrayResize(bb3,3);
   bb3[0]=1.0; bb3[1]=2.0; bb3[2]=3.0;
   double mid[],bbUp[],bbLo[];
   PaBuildBb(bb3,3,3,2.0,mid,bbUp,bbLo);
   const double width=(bbUp[2]-bbLo[2])/mid[2]*100.0;
   Record("B9",Near(mid[2],2.0) && Near(bbUp[2]-mid[2],2.0*0.8164966)
          && Near(width,163.29932),"bb population stdev");

   PaConfig cfg=SignalConfig();
   cfg.obvLen=2;
   PaEngineState st;
   PaStateInit(st);
   PaBarOut obvOut;
   double obvSlope[4];
   const double closes[4]={10.0,11.0,10.0,11.0};
   for(int i=0; i<4; i++)
     {
      PaBar bar=MkBar(closes[i],closes[i],closes[i],closes[i]);
      bar.atr=2.0;
      bar.volume=10.0;
      PaEngineStep(cfg,st,bar,i,obvOut);
      obvSlope[i]=obvOut.obvSlope;
     }
   Record("B10",Near(obvSlope[0],0.0) && Near(obvSlope[1],10.0)
          && Near(obvSlope[2],0.0) && Near(obvSlope[3],0.0),
          StringFormat("%.4f/%.4f/%.4f/%.4f",obvSlope[0],obvSlope[1],
                       obvSlope[2],obvSlope[3]));
  }

//+------------------------------------------------------------------+
//| C: pivots                                                        |
//+------------------------------------------------------------------+
void RunC()
  {
   double hi[];
   ArrayResize(hi,3);
   hi[0]=10.0; hi[1]=12.0; hi[2]=11.0;
   double value=0.0;
   const bool c1=PaPivotHighAt(hi,3,2,1,1,value);
   Record("C1",c1 && Near(value,12.0),"pivot high confirmed at bar 2");

   double plateau[];
   ArrayResize(plateau,4);
   plateau[0]=10.0; plateau[1]=12.0; plateau[2]=12.0; plateau[3]=11.0;
   const bool t1=PaPivotHighAt(plateau,4,2,1,1,value);
   const bool t2=PaPivotHighAt(plateau,4,3,1,1,value);
   Record("C2",!t1 && !t2,"plateau is not a strict pivot");

   Record("C3",c1 && Near(value,hi[1]) && (2-1)==1,"center bar c-right");

   double lo[];
   ArrayResize(lo,3);
   lo[0]=10.0; lo[1]=8.0; lo[2]=9.0;
   const bool c4=PaPivotLowAt(lo,3,2,1,1,value);
   Record("C4",c4 && Near(value,8.0),"pivot low confirmed at bar 2");

   double wide[];
   ArrayResize(wide,10);
   for(int i=0; i<10; i++)
      wide[i]=10.0;
   wide[0]=10.0; wide[1]=11.0; wide[2]=12.0; wide[3]=11.0;
   const bool zonePiv=PaPivotHighAt(wide,10,3,2,1,value);
   const bool structPiv=PaPivotHighAt(wide,10,7,5,5,value);
   Record("C5",zonePiv && !structPiv,"zone pivot left2/right1 differs from swing 5");
  }

//+------------------------------------------------------------------+
//| D: structure                                                     |
//+------------------------------------------------------------------+
void RunD()
  {
   PaConfig cfg=SignalConfig();
   PaEngineState st;
   PaBarOut out;
   PaBar bar;

   PaStateInit(st);
   st.trend=0;
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(100.0,101.0,99.5,101.0);
   bar.atr=2.0;
   bar.pivH=100.0;
   bar.pivHValid=true;
   PaEngineStep(cfg,st,bar,10,out);
   Record("D1",out.bosUp && !out.chochUp && out.trend==1
          && Near(st.brkLevel,100.0),"bos up");

   PaStateInit(st);
   st.trend=-1;
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(99.5,105.0,99.0,100.0);
   bar.atr=2.0;
   bar.pivH=105.0;
   bar.pivHValid=true;
   PaEngineStep(cfg,st,bar,10,out);
   Record("D2",out.chochUp && !out.bosUp && out.trend==1,"choch up");

   PaStateInit(st);
   st.trend=0;
   st.hasLastLow=true;
   st.lastLow=90.0;
   bar=MkBar(90.5,90.6,88.5,89.0);
   bar.atr=2.0;
   bar.pivL=89.5;
   bar.pivLValid=true;
   PaEngineStep(cfg,st,bar,10,out);
   Record("D3",out.bosDown && out.trend==-1 && Near(st.brkLevel,90.0),"bos down");

   PaStateInit(st);
   st.trend=0;
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(97.0,101.0,97.0,101.0);
   bar.atr=2.0;
   bar.pivH=100.0;
   bar.pivHValid=true;
   PaEngineStep(cfg,st,bar,10,out);
   Record("D4",out.bosUp && out.mssUp,"bos+displacement = mss");

   PaStateInit(st);
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(99.0,100.6,98.5,99.5);
   bar.atr=2.0;
   bar.pivH=101.0;
   bar.pivHValid=true;
   PaEngineStep(cfg,st,bar,10,out);
   const bool hh1=out.hh && !out.lh;
   PaStateInit(st);
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(99.0,99.4,98.0,98.5);
   bar.atr=2.0;
   bar.pivH=99.0;
   bar.pivHValid=true;
   PaEngineStep(cfg,st,bar,10,out);
   Record("D5",hh1 && out.lh && !out.hh,"higher high / lower high");

   PaStateInit(st);
   st.hasBrk=true;
   st.brkDir=1;
   st.brkBar=5;
   st.brkLevel=100.0;
   bar=MkBar(100.4,101.0,100.5,100.8);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,8,out);
   Record("D6",out.retestUp,"bull retest");

   PaStateInit(st);
   st.hasBrk=true;
   st.brkDir=-1;
   st.brkBar=5;
   st.brkLevel=100.0;
   bar=MkBar(99.8,100.7,99.5,100.5);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,7,out);
   Record("D7",out.failUp,"failed breakdown");

   PaStateInit(st);
   st.trend=1;
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(100.2,100.7,100.0,100.5);
   bar.atr=2.0;
   bar.emaM=100.2;
   bar.pivH=101.0;
   bar.pivHValid=true;
   PaEngineStep(cfg,st,bar,10,out);
   Record("D8",out.contUp && out.pullUp,"continuation + pullback");
  }

//+------------------------------------------------------------------+
//| E: patterns                                                      |
//+------------------------------------------------------------------+
void RunE()
  {
   PaConfig cfg=BaseConfig();
   PaEngineState st;
   PaBarOut out;
   PaBar bar;

   PaStateInit(st);
   st.hiPx[0]=100.0;
   st.hiBar[0]=5;
   st.hiCount=1;
   bar=MkBar(99.0,101.0,98.0,100.0);
   bar.atr=2.0;
   bar.pivH=100.5;
   bar.pivHValid=true;
   bar.pivNeckLow=99.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("E1",st.patCount==1 && st.pats[0].kind==PA_PAT_DT
          && st.pats[0].dir==-1,"double top");

   PaStateInit(st);
   SeedPattern(st,PA_PAT_DT,-1,99.0,5);
   st.hasPrev=true;
   st.pbOpen=98.5;
   st.pbHigh=100.0;
   st.pbLow=98.5;
   st.pbClose=99.5;
   bar=MkBar(99.0,99.5,98.0,98.5);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("E2",out.pattern==PA_PAT_DT && out.patternDir==-1
          && st.pats[0].broken,"double top break");

   PaStateInit(st);
   st.loPx[0]=100.0;
   st.loBar[0]=5;
   st.loCount=1;
   bar=MkBar(101.0,101.5,99.0,99.5);
   bar.atr=2.0;
   bar.pivL=100.5;
   bar.pivLValid=true;
   bar.pivNeckHigh=101.0;
   PaEngineStep(cfg,st,bar,10,out);
   const bool dbMade=(st.patCount==1 && st.pats[0].kind==PA_PAT_DB
                      && st.pats[0].dir==1);
   bar=MkBar(100.0,101.8,99.5,101.5);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,11,out);
   Record("E3",dbMade && out.pattern==PA_PAT_DB && out.patternDir==1
          && st.pats[0].broken,"double bottom + break");

   PaStateInit(st);
   st.hiPx[0]=95.0;
   st.hiBar[0]=1;
   st.hiPx[1]=100.0;
   st.hiBar[1]=5;
   st.hiCount=2;
   bar=MkBar(100.0,121.5,99.0,100.0);
   bar.atr=2.0;
   bar.pivH=121.0;
   bar.pivHValid=true;
   bar.pivNeckLow=99.0;
   PaEngineStep(cfg,st,bar,10,out);
   bool hstFound=false;
   for(int i=0; i<st.patCount; i++)
      if(st.pats[i].kind==PA_PAT_HST)
         hstFound=true;
   Record("E4",hstFound,"head and shoulders top");

   PaStateInit(st);
   st.loPx[0]=95.0;
   st.loBar[0]=1;
   st.loPx[1]=100.0;
   st.loBar[1]=5;
   st.loCount=2;
   bar=MkBar(92.0,93.0,82.5,90.0);
   bar.atr=2.0;
   bar.pivL=83.0;
   bar.pivLValid=true;
   bar.pivNeckHigh=90.0;
   PaEngineStep(cfg,st,bar,10,out);
   bool hsnFound=false;
   for(int i=0; i<st.patCount; i++)
      if(st.pats[i].kind==PA_PAT_HSN)
         hsnFound=true;
   Record("E5",hsnFound,"head and shoulders bottom");

   PaStateInit(st);
   SeedPattern(st,PA_PAT_HST,-1,90.0,5);
   st.hiPx[0]=100.0;
   st.hiBar[0]=1;
   st.hiPx[1]=105.0;
   st.hiBar[1]=5;
   st.hiCount=2;
   bar=MkBar(99.5,100.6,99.0,100.0);
   bar.atr=2.0;
   bar.pivH=100.4;
   bar.pivHValid=true;
   bar.pivNeckLow=95.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("E6",Near(st.pats[0].c,100.4) && st.pats[0].cBar==5,
          StringFormat("c=%.4f cBar=%d",st.pats[0].c,st.pats[0].cBar));

   double lows[];
   ArrayResize(lows,11);
   ArrayInitialize(lows,5.0);
   lows[5]=1.0;
   lows[6]=3.0;
   lows[7]=2.0;
   lows[8]=4.0;
   lows[9]=1.0;
   double highs[];
   ArrayResize(highs,11);
   ArrayInitialize(highs,5.0);
   highs[6]=2.0;
   highs[7]=3.0;
   highs[8]=1.0;
   Record("E7",Near(PaNeckMinLow(lows,11,5,9),2.0)
          && Near(PaNeckMaxHigh(highs,11,5,9),3.0),
          "neckline ignores endpoints");

   PaStateInit(st);
   SeedPattern(st,PA_PAT_DT,-1,110.0,5);
   st.hasPrev=true;
   st.pbOpen=111.0;
   st.pbHigh=111.0;
   st.pbLow=100.0;
   st.pbClose=111.0;
   bar=MkBar(105.0,106.0,99.0,100.0);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,10,out);
   const double h1=out.patternHeight;
   bar=MkBar(100.0,101.0,99.5,100.0);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,11,out);
   Record("E8",Near(h1,10.0) && Near(out.patternHeight,10.0),
          StringFormat("h1=%.4f h2=%.4f",h1,out.patternHeight));
  }

//+------------------------------------------------------------------+
//| F: liquidity / day / week / session                              |
//+------------------------------------------------------------------+
void RunF()
  {
   PaConfig cfg=SignalConfig();
   PaEngineState st;
   PaBarOut out;
   PaBar bar;

   PaStateInit(st);
   bar=MkBar(190.0,200.0,180.0,190.0,D'2024.01.02 12:00');
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,0,out);
   bar=MkBar(195.0,205.0,185.0,195.0,D'2024.01.03 12:00');
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,1,out);
   Record("F1",Near(out.pdh,200.0) && Near(out.pdl,180.0),"previous server day");

   PaStateInit(st);
   bar=MkBar(270.0,300.0,250.0,270.0,D'2024.01.07 12:00');
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,0,out);
   bar=MkBar(280.0,310.0,260.0,280.0,D'2024.01.08 10:00');
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,1,out);
   Record("F2",Near(out.pwh,300.0) && Near(out.pwl,250.0),"previous server week");

   PaStateInit(st);
   bar=MkBar(190.0,200.0,180.0,190.0,D'2024.01.02 02:00');
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,0,out);
   bar=MkBar(145.0,150.0,140.0,145.0,D'2024.01.02 11:00');
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,1,out);
   Record("F3",out.sessName==PA_SESS_LONDON && Near(out.sessHi,150.0)
          && Near(out.sessLo,140.0),"asia to london resets session range");

   PaStateInit(st);
   bar=MkBar(190.0,200.0,180.0,190.0,D'2024.01.02 02:00');
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,0,out);
   bar=MkBar(190.0,195.0,185.0,190.0,D'2024.01.02 23:30');
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,1,out);
   Record("F4",out.sessName==PA_SESS_NONE && Near(out.sessHi,200.0)
          && Near(out.sessLo,180.0),"outside session keeps range");

   PaStateInit(st);
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(100.0,100.06,99.5,99.9,D'2024.01.02 12:00');
   bar.atr=2.0;
   bar.pivH=100.05;
   bar.pivHValid=true;
   PaEngineStep(cfg,st,bar,10,out);
   const bool sweepA=out.sweepDown;
   PaStateInit(st);
   st.hasLastHigh=true;
   st.lastHigh=100.0;
   bar=MkBar(100.1,100.2,99.5,99.9,D'2024.01.02 12:00');
   bar.atr=2.0;
   bar.pivH=100.2;
   bar.pivHValid=true;
   PaEngineStep(cfg,st,bar,10,out);
   Record("F5",sweepA && !out.sweepDown,"equal highs sweep");

   PaStateInit(st);
   st.hasPd=true;
   st.pdh=110.0;
   st.pdl=100.0;
   bar=MkBar(100.4,100.8,99.0,100.5,D'2024.01.02 12:00');
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("F6",out.sweepUp,"pd low sweep");

   PaStateInit(st);
   bar=MkBar(180.0,200.0,160.0,180.0,D'2024.01.02 11:00');
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,0,out);
   bar=MkBar(190.0,205.0,150.0,190.0,D'2024.01.02 11:05');
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,1,out);
   Record("F7",!out.sweepUp,"session low already includes current bar");

   PaStateInit(st);
   st.hasSessHi=true;
   st.hasSessLo=true;
   st.sessHi=210.0;
   st.sessLo=190.0;
   st.sessPrev=PA_SESS_ASIA;
   bar=MkBar(190.5,192.0,189.0,191.0,D'2024.01.02 23:30');
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("F8",out.sweepUp,"outside session uses stale session low");
  }

//+------------------------------------------------------------------+
//| G: zones / FVG / OB                                              |
//+------------------------------------------------------------------+
void RunG()
  {
   PaEngineState st;
   PaStateInit(st);
   PaZoneAdd(st,100.0,1,2.0,0.5,8);
   Record("G1",st.srCount==1 && Near(st.sr[0].top,100.5)
          && Near(st.sr[0].bot,99.5) && st.sr[0].side==1,"zone geometry");

   PaZoneAdd(st,100.4,-1,2.0,0.5,8);
   Record("G2",st.srCount==1 && st.sr[0].side==1 && st.sr[0].touches==2,
          "merge keeps side and bumps touches");
   Record("G3",Near(st.sr[0].top,100.5) && Near(st.sr[0].bot,99.5),
          "merge keeps original bounds");

   PaStateInit(st);
   PaZoneAdd(st,100.0,1,2.0,0.5,2);
   PaZoneAdd(st,90.0,1,2.0,0.5,2);
   PaZoneAdd(st,80.0,1,2.0,0.5,2);
   Record("G4",st.srCount==2 && Near(st.sr[0].bot,89.5)
          && Near(st.sr[1].top,80.5),"srMax shifts oldest");

   PaStateInit(st);
   PaZoneAdd(st,100.0,1,2.0,0.5,8);
   const bool nearFalse=PaNearSupport(st,99.5-0.6-0.001,2.0);
   const bool nearTrue=PaNearSupport(st,99.5-0.6+0.001,2.0);
   Record("G5",!nearFalse && nearTrue,"support tolerance boundary");

   PaStateInit(st);
   PaZoneAdd(st,100.0,-1,2.0,0.5,8);
   Record("G6",PaNearResistance(st,100.2,2.0),"resistance band");

   PaConfig cfg=SignalConfig();
   PaBarOut out;
   PaBar bar;
   PaStateInit(st);
   st.hasPrev2=true;
   st.pb2High=100.0;
   st.pb2Low=90.0;
   bar=MkBar(100.5,101.0,100.7,101.0);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("G7",st.fvgCount==1 && Near(st.fvg[0].top,100.7)
          && Near(st.fvg[0].bot,100.0) && st.fvg[0].dir==1,"bull fvg");

   PaStateInit(st);
   PaPushFvg(st,101.0,100.0,5,1);
   bar=MkBar(100.0,100.2,99.0,99.5);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("G8",st.fvg[0].dead,"fvg invalidated by close");

   PaStateInit(st);
   st.hasPrev=true;
   st.pbOpen=99.0;
   st.pbHigh=99.0;
   st.pbLow=98.0;
   st.pbClose=98.0;
   bar=MkBar(98.0,101.0,98.0,101.0);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("G9",st.obCount==1 && Near(st.ob[0].top,99.0)
          && Near(st.ob[0].bot,98.0) && out.nearFvgBull,"order block near bull");
  }

//+------------------------------------------------------------------+
//| H: candles                                                       |
//+------------------------------------------------------------------+
void RunH()
  {
   PaConfig cfg;
   PaEngineState st;
   PaBarOut out;
   PaBar bar;

   cfg=SignalConfig();
   cfg.pinOn=true;
   PaStateInit(st);
   bar=MkBar(100.0,100.6,98.5,100.5);
   bar.atr=2.0;
   bar.volume=12.0;
   bar.volMA=10.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("H1",Near(out.candleScore,1.0/3.0),"bull pin");

   cfg=SignalConfig();
   cfg.engulfOn=true;
   PaStateInit(st);
   st.hasPrev=true;
   st.pbOpen=101.0;
   st.pbHigh=101.0;
   st.pbLow=99.0;
   st.pbClose=99.0;
   bar=MkBar(99.0,102.0,99.0,102.0);
   bar.atr=2.0;
   bar.volume=12.0;
   bar.volMA=10.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("H2",Near(out.candleScore,1.0/3.0),"bull engulf");

   cfg=SignalConfig();
   cfg.dispOn=true;
   PaStateInit(st);
   bar=MkBar(98.0,101.0,98.0,101.0);
   bar.atr=2.0;
   bar.volume=22.0;
   bar.volMA=10.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("H3",Near(out.candleScore,0.4),"displacement + volume");

   cfg=SignalConfig();
   cfg.rejOn=true;
   PaStateInit(st);
   bar=MkBar(97.0,100.0,96.5,97.5);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("H4",Near(out.candleScore,0.8/3.0),"bull rejection");

   cfg=SignalConfig();
   cfg.ibOn=true;
   PaStateInit(st);
   st.hasPrev=true;
   st.pbOpen=103.0;
   st.pbHigh=104.0;
   st.pbLow=96.0;
   st.pbClose=103.0;
   st.hasPrev2=true;
   st.pb2Open=100.0;
   st.pb2High=105.0;
   st.pb2Low=95.0;
   st.pb2Close=100.0;
   bar=MkBar(104.0,104.6,103.5,104.5);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("H5",Near(out.candleScore,0.8/3.0),"inside bar break");

   cfg=SignalConfig();
   cfg.dojiOn=true;
   PaStateInit(st);
   bar=MkBar(100.0,101.0,99.0,100.01);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("H6",Near(out.candleScore,0.5/3.0),"doji leaning bull");

   cfg=SignalConfig();
   cfg.soldOn=true;
   PaStateInit(st);
   st.hasPrev=true;
   st.pbOpen=102.0;
   st.pbHigh=104.0;
   st.pbLow=102.0;
   st.pbClose=104.0;
   st.hasPrev2=true;
   st.pb2Open=100.0;
   st.pb2High=102.0;
   st.pb2Low=100.0;
   st.pb2Close=102.0;
   bar=MkBar(104.0,106.0,104.0,106.0);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("H7",Near(out.candleScore,0.4),"three soldiers");

   cfg=SignalConfig();
   cfg.pinOn=true;
   cfg.volVetoOn=true;
   cfg.volVetoR=1.2;
   PaStateInit(st);
   bar=MkBar(100.0,100.6,98.5,100.5);
   bar.atr=2.0;
   bar.volume=10.0;
   bar.volMA=10.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("H8",Near(out.candleScore,0.4/3.0),"volume veto scales pin");

   cfg=SignalConfig();
   cfg.engulfOn=true;
   cfg.streakOn=true;
   cfg.streakMin=2;
   cfg.streakAdd=0.5;
   PaStateInit(st);
   st.hasPrev=true;
   st.pbOpen=101.0;
   st.pbHigh=101.0;
   st.pbLow=99.0;
   st.pbClose=99.0;
   bar=MkBar(98.5,101.5,98.5,101.5);
   bar.atr=2.0;
   bar.volume=12.0;
   bar.volMA=10.0;
   PaEngineStep(cfg,st,bar,10,out);
   const double h9a=out.candleScore;
   bar=MkBar(102.0,102.0,98.0,98.0);
   bar.atr=2.0;
   bar.volume=12.0;
   bar.volMA=10.0;
   PaEngineStep(cfg,st,bar,11,out);
   Record("H9",Near(h9a,1.0/3.0) && Near(out.candleScore,-0.5),
          StringFormat("first=%.4f second=%.4f",h9a,out.candleScore));

   cfg=SignalConfig();
   cfg.pinOn=true;
   cfg.dispOn=true;
   PaStateInit(st);
   bar=MkBar(100.0,103.0,94.0,103.0);
   bar.atr=2.0;
   bar.volume=22.0;
   bar.volMA=10.0;
   PaEngineStep(cfg,st,bar,10,out);
   const double h10a=out.candleScore;

   cfg=SignalConfig();
   cfg.engulfOn=true;
   cfg.dispOn=true;
   cfg.streakOn=true;
   cfg.streakMin=2;
   cfg.streakAdd=2.0;
   PaStateInit(st);
   st.engulfStreak=1;
   st.hasPrev=true;
   st.pbOpen=100.0;
   st.pbHigh=100.0;
   st.pbLow=99.0;
   st.pbClose=99.0;
   bar=MkBar(98.0,103.0,98.0,103.0);
   bar.atr=2.0;
   bar.volume=22.0;
   bar.volMA=10.0;
   PaEngineStep(cfg,st,bar,11,out);
   Record("H10",Near(h10a,2.2/3.0) && Near(out.candleScore,1.0),
          StringFormat("a=%.4f cap=%.4f",h10a,out.candleScore));
  }

//+------------------------------------------------------------------+
//| I: indicator scores                                              |
//+------------------------------------------------------------------+
void RunI()
  {
   Record("I1",Near(PaRsiScore(25.0,30.0,70.0),1.0)
          && Near(PaRsiScore(75.0,30.0,70.0),-1.0)
          && Near(PaRsiScore(50.0,30.0,70.0),0.0),"rsi score");

   Record("I2",Near(PaMacdScore(1.0,true,-0.1),1.0)
          && Near(PaMacdScore(1.0,true,0.1),0.5),"macd score");

   Record("I3",Near(PaDmiScore(19.0,1.0,0.0,20.0),0.0)
          && Near(PaDmiScore(25.0,1.0,0.0,20.0),1.0),"dmi score");

   Record("I4",Near(PaMomScore(1.0,0.5,1.0),0.8333333),"momentum average");

   Record("I5",Near(PaAtrRegime(13.0,10.0),1.0)
          && Near(PaAtrRegime(12.0,10.0),0.5)
          && Near(PaAtrRegime(7.0,10.0),0.0),"atr regime score");

   PaConfig cfg=BaseConfig();
   ZeroWeights(cfg);
   cfg.wAtr=1.0;
   PaEngineState st;
   PaStateInit(st);
   PaBar bar=MkBar(100.0,100.0,99.0,99.5,D'2024.01.02 23:30');
   bar.atr=5.0;
   bar.atrMA=10.0;
   bar.bbWidth=2.0;
   bar.bbWidthMA=1.0;
   bar.swingHi=99.5;
   bar.swingLo=99.5;
   PaBarOut out;
   PaEngineStep(cfg,st,bar,10,out);
   Record("I6",out.score100==38,StringFormat("score=%d",out.score100));

   Record("I7",Near(PaVolumeScore(1.0,1.0,1.0),1.0),"volume score");

   Record("I8",Near(PaLocationScore(1.0,0.4),0.7),"location score");

   cfg=SignalConfig();
   PaStateInit(st);
   bar=SignalBar(100.0,D'2024.01.02 23:30');
   PaEngineStep(cfg,st,bar,10,out);
   const bool i9a=(out.score100==100 && out.dir==1);

   cfg=BaseConfig();
   PaStateInit(st);
   bar=MkBar(100.0,100.0,100.0,100.0,D'2024.01.02 23:30');
   bar.atr=1.0;
   bar.atrMA=10.0;
   bar.emaF=101.0;
   bar.emaM=100.0;
   bar.emaS=99.0;
   bar.swingLo=100.0;
   bar.swingHi=100.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("I9",i9a && out.score100==58 && out.dir==1,
          StringFormat("a=%d b=%d",i9a ? 100 : -1,out.score100));
  }

//+------------------------------------------------------------------+
//| J: MTF                                                           |
//+------------------------------------------------------------------+
void RunJ()
  {
   datetime htf[3];
   htf[0]=D'2024.01.02 08:00';
   htf[1]=D'2024.01.02 12:00';
   htf[2]=D'2024.01.02 16:00';
   Record("J1",PaMapHtfIndex(htf,3,D'2024.01.02 12:00')==1,"close time boundary");
   Record("J2",PaMapHtfIndex(htf,3,D'2024.01.02 11:55')==0,"before close time");

   double src[],outEma[];
   ArrayResize(src,2);
   src[0]=1.0;
   src[1]=2.0;
   PaBuildEma(src,2,5,outEma);
   Record("J3",EmptyD(outEma[0]) && EmptyD(outEma[1]),"short htf history");

   PaConfig cfg=SignalConfig();
   PaEngineState st;
   PaStateInit(st);
   PaBar bar=SignalBar(100.0,D'2024.01.02 23:30');
   bar.htfCtxEma=100.0;
   bar.htfCtxValid=true;
   PaBarOut out;
   PaEngineStep(cfg,st,bar,10,out);
   Record("J4",out.mtfCtxDir==-1,"close equal to ctx ema is bearish");

   cfg=SignalConfig();
   ZeroWeights(cfg);
   cfg.wTrend=60.0;
   cfg.wStruct=40.0;
   cfg.htfFilter=true;
   cfg.htfVetoOn=false;
   cfg.scrNoTrade=0;
   cfg.coolBars=0;
   cfg.maxDay=1000000;
   cfg.cfOn=false;
   cfg.regOn=false;
   PaStateInit(st);
   st.trend=1;
   bar=MkBar(100.2,100.4,99.8,100.0);
   bar.atr=2.0;
   bar.emaF=99.0;
   bar.emaM=100.0;
   bar.emaS=101.0;
   bar.htfSetupEma=99.0;
   bar.htfSetupValid=true;
   bar.swingHi=100.0;
   bar.swingLo=100.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("J5",out.dir==-1 && out.mtfSetupDir==1
          && out.block==PA_BLOCK_MTF_FILTER,"setup filter blocks opposite");

   cfg.htfFilter=false;
   cfg.htfVetoOn=true;
   PaStateInit(st);
   st.trend=1;
   bar.htfCtxEma=99.0;
   bar.htfCtxValid=true;
   bar.htfSetupValid=false;
   PaEngineStep(cfg,st,bar,10,out);
   Record("J6",out.dir==-1 && out.htfVeto
          && out.block==PA_BLOCK_HTF_VETO,"context veto");

   cfg=SignalConfig();
   ZeroWeights(cfg);
   cfg.wMtf=1.0;
   cfg.htfFilter=false;
   PaStateInit(st);
   bar=SignalBar(100.0,D'2024.01.02 23:30');
   bar.htfSetupEma=101.0;
   bar.htfSetupValid=true;
   PaEngineStep(cfg,st,bar,10,out);
   Record("J7",out.mtfCtxDir==0 && out.mtfSetupDir==-1
          && out.score100==25 && out.sigShort && out.block==PA_BLOCK_NONE,
          StringFormat("score=%d dir=%d",out.score100,out.dir));

   cfg=SignalConfig();
   cfg.htfFilter=true;
   cfg.htfVetoOn=true;
   PaStateInit(st);
   bar=SignalBar(100.0,D'2024.01.02 23:30');
   PaEngineStep(cfg,st,bar,10,out);
   Record("J8",out.mtfCtxDir==0 && out.mtfSetupDir==0
          && out.sigLong && out.block==PA_BLOCK_NONE,"neutral htf passes");
  }

//+------------------------------------------------------------------+
//| K: regime / confluence                                           |
//+------------------------------------------------------------------+
void RunK()
  {
   Record("K1",PaRegime(true,26.0,false,100.0,99.0,2.0,25.0,18.0)==PA_REG_TRENDING,
          "trending");
   Record("K2",PaRegime(true,17.0,false,100.0,99.0,2.0,25.0,18.0)==PA_REG_CHOPPY,
          "choppy by adx");
   Record("K3",PaRegime(true,20.0,true,100.0,100.1,2.0,25.0,18.0)==PA_REG_CHOPPY,
          "choppy by squeeze");
   Record("K4",PaRegime(true,20.0,false,100.0,99.0,2.0,25.0,18.0)==PA_REG_RANGING,
          "ranging");

   PaConfig cfg=SignalConfig();
   cfg.regOn=true;
   cfg.regAdxTrend=25.0;
   cfg.regAdxChop=18.0;
   cfg.regBbwSqueeze=20.0;
   cfg.regRangeEdge=0.35;
   PaEngineState st;
   PaStateInit(st);
   PaZoneAdd(st,100.0,1,2.0,0.5,8);
   PaBar bar=MkBar(100.0,100.4,99.292,100.2,D'2024.01.02 23:30');
   bar.atr=2.0;
   bar.adx=20.0;
   bar.emaF=101.0;
   bar.emaM=100.0;
   bar.emaS=99.0;
   bar.swingLo=100.2;
   bar.swingHi=100.2;
   PaBarOut out;
   PaEngineStep(cfg,st,bar,10,out);
   const bool k5a=(out.sigLong && out.block==PA_BLOCK_NONE);

   PaStateInit(st);
   PaZoneAdd(st,100.0,1,2.0,0.5,8);
   bar=MkBar(100.0,100.4,99.288,100.2,D'2024.01.02 23:30');
   bar.atr=2.0;
   bar.adx=20.0;
   bar.emaF=101.0;
   bar.emaM=100.0;
   bar.emaS=99.0;
   bar.swingLo=100.2;
   bar.swingHi=100.2;
   PaEngineStep(cfg,st,bar,10,out);
   Record("K5",k5a && out.block==PA_BLOCK_REGIME,"range edge 0.104 vs 0.106 atr");

   cfg=SignalConfig();
   PaStateInit(st);
   bar=SignalBar(100.0,D'2024.01.02 23:30');
   bar.htfCtxEma=99.0;
   bar.htfCtxValid=true;
   PaEngineStep(cfg,st,bar,10,out);
   Record("K6",out.dir==1 && out.cf1,"confluence trend");

   cfg=SignalConfig();
   ZeroWeights(cfg);
   cfg.wTrend=1.0;
   cfg.cfOn=true;
   cfg.cfRequire3=true;
   cfg.cfLevelTolAtr=0.5;
   PaStateInit(st);
   PaZoneAdd(st,100.0,1,2.0,0.5,8);
   bar=MkBar(100.9,101.2,100.8,101.0,D'2024.01.02 23:30');
   bar.atr=2.0;
   bar.emaF=101.5;
   bar.emaM=101.0;
   bar.emaS=100.5;
   bar.htfCtxEma=99.0;
   bar.htfCtxValid=true;
   bar.swingLo=101.0;
   bar.swingHi=101.0;
   PaEngineStep(cfg,st,bar,10,out);
   const bool k7a=(out.cf1 && out.cf2 && !out.cf3
                   && out.confluence==2 && out.block==PA_BLOCK_CONFLUENCE);

   PaStateInit(st);
   PaZoneAdd(st,100.0,1,2.0,0.5,8);
   bar=MkBar(101.4,101.5,101.4,101.5,D'2024.01.02 23:30');
   bar.atr=2.0;
   bar.emaF=101.5;
   bar.emaM=101.0;
   bar.emaS=100.5;
   bar.htfCtxEma=99.0;
   bar.htfCtxValid=true;
   bar.swingLo=101.0;
   bar.swingHi=101.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("K7",k7a && !out.cf2,"confluence 2 of 3 requires all three");
  }

//+------------------------------------------------------------------+
//| L: plan                                                          |
//+------------------------------------------------------------------+
void RunL()
  {
   PaConfig cfg=BaseConfig();
   PaBar bar=MkBar(100.0,100.0,100.0,100.0);
   bar.atr=2.0;
   bar.swingLo=96.0;
   bar.swingHi=96.0;
   PaPlan plan;

   const double d1=PaPlanDistance(2.0,100.0,96.0,1,1.5,0.2,0.5,3.0);
   PaBuildPlan(cfg,bar,1,false,EMPTY_VALUE,false,EMPTY_VALUE,0.0,plan);
   Record("L1",Near(d1,3.7) && Near(plan.sl,96.3) && Near(plan.risk,3.7),
          StringFormat("d=%.4f sl=%.4f",d1,plan.sl));

   const double d2=PaPlanDistance(1.0,100.0,100.0,1,1.0,0.2,0.8,3.0);
   Record("L2",Near(d2,0.8),"clamped to min atr");

   const double d3=PaPlanDistance(2.0,100.0,50.0,1,1.5,0.2,0.5,3.0);
   Record("L3",Near(d3,6.0),"clamped to max atr");

   cfg.rrMin=0.0;
   PaBuildPlan(cfg,bar,0,false,EMPTY_VALUE,false,EMPTY_VALUE,0.0,plan);
   Record("L4",!plan.valid && Near(plan.entry,100.0),"dir 0 is invalid");

   cfg.rr1=1.0;
   cfg.rrMin=1.5;
   PaBuildPlan(cfg,bar,1,false,EMPTY_VALUE,false,EMPTY_VALUE,0.0,plan);
   const bool l5=!plan.valid && Near(plan.rr1,1.0);
   cfg.rr1=2.0;
   PaBuildPlan(cfg,bar,1,false,EMPTY_VALUE,false,EMPTY_VALUE,0.0,plan);
   Record("L5",l5,"rr1 below rrMin invalidates");
   Record("L6",plan.valid && Near(plan.rr1,2.0),"rr1 above rrMin is valid");

   cfg=BaseConfig();
   cfg.tpMode=PA_TP_R;
   cfg.slAtrMul=2.0;
   cfg.slPadAtr=0.0;
   bar.atr=2.0;
   bar.swingLo=100.0;
   PaBuildPlan(cfg,bar,1,false,EMPTY_VALUE,false,EMPTY_VALUE,0.0,plan);
   Record("L7",Near(plan.risk,2.0) && Near(plan.tp1,102.0)
          && Near(plan.tp2,104.0) && Near(plan.tp3,106.0),"R mode targets");

   cfg.tpMode=PA_TP_MM;
   PaBuildPlan(cfg,bar,1,false,EMPTY_VALUE,false,EMPTY_VALUE,6.0,plan);
   Record("L8",Near(plan.tp1,103.0) && Near(plan.tp2,106.0)
          && Near(plan.tp3,109.0),"MM mode patHeight");

   PaBuildPlan(cfg,bar,1,true,10.0,true,6.0,0.0,plan);
   const bool l9a=(Near(plan.tp1,102.0) && Near(plan.tp2,104.0)
                   && Near(plan.tp3,106.0));
   cfg.slAtrMul=0.5;
   PaBuildPlan(cfg,bar,1,false,EMPTY_VALUE,false,EMPTY_VALUE,0.0,plan);
   const bool l9b=(Near(plan.risk,1.0) && Near(plan.tp1,101.0)
                   && Near(plan.tp2,102.0) && Near(plan.tp3,103.0));
   Record("L9",l9a && l9b,"MM range and R fallback");

   cfg=BaseConfig();
   cfg.tpMode=PA_TP_MM;
   cfg.tpMmFallback=false;
   cfg.rrMin=0.0;
   PaBuildPlan(cfg,bar,1,false,EMPTY_VALUE,false,EMPTY_VALUE,0.0,plan);
   Record("L10",plan.valid && EmptyD(plan.tp1) && EmptyD(plan.tp2)
          && EmptyD(plan.tp3),"MM without fallback leaves targets empty");
  }

//+------------------------------------------------------------------+
//| M: state machine                                                 |
//+------------------------------------------------------------------+
void RunM()
  {
   PaConfig cfg=SignalConfig();
   PaEngineState st;
   PaBarOut out;
   PaBar bar;

   PaStateInit(st);
   bar=SignalBar(104.0);
   PaEngineStep(cfg,st,bar,0,out);
   const bool m1=(out.sigLong && out.evEntry && out.posDir==1
                  && Near(out.posEntry,104.0) && out.dayCount==1
                  && out.barsSince==0);
   Record("M1",m1,"entry adopts plan");

   bar=MkBar(104.2,105.2,104.0,104.5);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,1,out);
   const bool m2=(out.evTp1 && out.posStage==1 && !out.evClose);
   Record("M2",m2,"tp1 stage");

   bar=MkBar(105.5,106.2,104.5,106.0);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,2,out);
   const bool m3=(out.evTp2 && out.posStage==2 && !out.evClose);
   Record("M3",m3,"tp2 stage");

   bar=MkBar(106.5,107.1,106.0,107.0);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,3,out);
   Record("M4",out.evTp3 && out.evClose && out.closeReason==PA_CLOSE_TP3
          && out.wins==1 && out.trades==1 && Near(st.xExit,107.0),"tp3 win");

   PaStateInit(st);
   bar=SignalBar(104.0);
   PaEngineStep(cfg,st,bar,0,out);
   bar=MkBar(103.5,104.5,102.5,103.5);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,1,out);
   Record("M5",out.evSl && out.evClose && out.closeReason==PA_CLOSE_SL
          && out.losses==1 && out.trades==1 && Near(st.xExit,103.0),"stop loss");

   PaStateInit(st);
   bar=SignalBar(104.0);
   PaEngineStep(cfg,st,bar,0,out);
   bar=MkBar(104.0,105.5,102.5,104.8);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,1,out);
   Record("M6",out.evSl && !out.evTp1 && out.posStage==0 && out.losses==1,
          "sl wins over tp1 on the same bar");

   PaStateInit(st);
   bar=SignalBar(104.0);
   PaEngineStep(cfg,st,bar,0,out);
   st.posBars=301;
   bar=MkBar(104.0,104.4,103.6,104.0);
   bar.atr=2.0;
   PaEngineStep(cfg,st,bar,1,out);
   Record("M7",out.evClose && out.closeReason==PA_CLOSE_TIMEOUT
          && out.trades==1 && out.wins==0 && out.losses==0,"timeout closes");
   Record("M8",Near(st.xExit,105.0),"timeout exit reports tp1");

   PaStateInit(st);
   bar=SignalBar(104.0);
   PaEngineStep(cfg,st,bar,0,out);
   bar=SignalBar(103.5);
   bar.high=104.5;
   bar.low=102.5;
   PaEngineStep(cfg,st,bar,1,out);
   const bool m9a=(out.evClose && !out.evEntry && out.trades==1);
   bar=SignalBar(103.7);
   PaEngineStep(cfg,st,bar,2,out);
   Record("M9",m9a && out.evEntry && out.posDir==1 && out.trades==1,
          "exit bar cannot re-enter, next bar can");

   PaStateInit(st);
   bar=SignalBar(104.0);
   PaEngineStep(cfg,st,bar,0,out);
   bar=SignalBar(104.0);
   bar.high=104.4;
   bar.low=103.6;
   PaEngineStep(cfg,st,bar,1,out);
   Record("M10",!out.evEntry && out.posDir==1 && Near(out.posEntry,104.0)
          && Near(out.posSl,103.0) && Near(out.posTp1,105.0)
          && out.trades==0 && out.wins==0 && out.losses==0,
          "signal ignored while a position is open");
  }

//+------------------------------------------------------------------+
//| N: gates                                                         |
//+------------------------------------------------------------------+
void RunN()
  {
   PaConfig cfg=SignalConfig();
   PaEngineState st;
   PaBarOut out;
   PaBar bar;

   cfg.coolBars=10;
   PaStateInit(st);
   st.barsSince=8;
   bar=SignalBar(104.0);
   PaEngineStep(cfg,st,bar,0,out);
   Record("N1",out.block==PA_BLOCK_COOLDOWN && !out.sigLong,"cooldown 9<10");

   PaStateInit(st);
   st.barsSince=9;
   bar=SignalBar(104.0);
   PaEngineStep(cfg,st,bar,0,out);
   Record("N1b",out.sigLong && out.block==PA_BLOCK_NONE,"cooldown 10 passes");

   cfg=SignalConfig();
   cfg.coolBars=10;
   cfg.maxDay=3;
   PaStateInit(st);
   st.barsSince=999999;
   st.dayCount=3;
   bar=SignalBar(104.0);
   PaEngineStep(cfg,st,bar,0,out);
   Record("N2",out.block==PA_BLOCK_DAY_LIMIT && !out.sigLong,"day limit");

   cfg=SignalConfig();
   cfg.maxDay=3;
   PaStateInit(st);
   st.dayCount=3;
   st.hasDay=true;
   st.dayStamp=(int)PaDayIndex(D'2024.01.02 12:00');
   st.curDayHi=100.0;
   st.curDayLo=100.0;
   bar=SignalBar(104.0,D'2024.01.03 12:00');
   PaEngineStep(cfg,st,bar,0,out);
   Record("N3",out.evEntry && out.dayCount==1 && out.block==PA_BLOCK_NONE,
          "new server day resets the counter before the gate");

   cfg=SignalConfig();
   cfg.maxDay=3;
   cfg.coolBars=10;
   PaStateInit(st);
   st.barsSince=0;
   st.dayCount=3;
   bar=MkBar(100.0,100.0,100.0,100.0);
   PaEngineStep(cfg,st,bar,0,out);
   Record("N4",out.block==PA_BLOCK_PLAN_INVALID,"plan invalid outranks gates");

   cfg=SignalConfig();
   cfg.scrNoTrade=49;
   PaStateInit(st);
   st.hasPrev=true;
   st.pbOpen=11.0;
   st.pbHigh=11.0;
   st.pbLow=11.0;
   st.pbClose=11.0;
   st.hasDay=true;
   st.hasPd=true;
   st.pdh=12.0;
   st.pdl=10.0;
   st.curDayHi=12.0;
   st.curDayLo=10.0;
   st.dayStamp=(int)PaDayIndex(D'2024.01.02 23:30');
   st.vwapStamp=(int)PaDayIndex(D'2024.01.02 23:30');
   st.vwapPV=110.0;
   st.vwapVol=10.0;
   st.hasVwap=true;
   bar=MkBar(10.5,10.6,9.8,10.0,D'2024.01.02 23:30');
   bar.atr=2.0;
   bar.volume=10.0;
   bar.swingHi=10.0;
   bar.swingLo=10.0;
   ZeroWeights(cfg);
   cfg.wTrend=100.0;
   cfg.wLoc=2.0;
   PaEngineStep(cfg,st,bar,10,out);
   const bool n5a=(out.score100==49 && out.block==PA_BLOCK_SCORE);

   PaStateInit(st);
   st.hasPrev=true;
   st.pbOpen=11.0;
   st.pbHigh=11.0;
   st.pbLow=11.0;
   st.pbClose=11.0;
   st.hasDay=true;
   st.hasPd=true;
   st.pdh=12.0;
   st.pdl=10.0;
   st.curDayHi=12.0;
   st.curDayLo=10.0;
   st.dayStamp=(int)PaDayIndex(D'2024.01.02 23:30');
   st.vwapStamp=(int)PaDayIndex(D'2024.01.02 23:30');
   st.vwapPV=110.0;
   st.vwapVol=10.0;
   st.hasVwap=true;
   bar=MkBar(10.5,10.6,9.8,10.0,D'2024.01.02 23:30');
   bar.atr=2.0;
   bar.volume=10.0;
   bar.swingHi=10.0;
   bar.swingLo=10.0;
   ZeroWeights(cfg);
   cfg.wTrend=100.0;
   cfg.wLoc=1.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("N5",n5a && out.score100==50 && out.sigShort,
          StringFormat("a=%d/%d b=%d",n5a ? 49 : -1,out.block,out.score100));
  }

//+------------------------------------------------------------------+
//| O: canonical config and hash                                     |
//+------------------------------------------------------------------+
void RunO()
  {
   PaConfig cfg=BaseConfig();
   string canon=PaConfigCanonical(cfg);
   string parts[];
   const int count=StringSplit(canon,(ushort)';',parts);
   Record("O1",count==116 && parts[0]=="v=1.0.0"
          && parts[115]=="cfRequire3=1"
          && canon==PaConfigCanonical(BaseConfig()),
          StringFormat("count=%d last=%s",count,parts[count-1]));

   Record("O2",PaFnv1a("a")==(uint)0xE40C292C
          && PaFnv1a("foobar")==(uint)0xBF9CF968,
          StringFormat("a=%u fb=%u",PaFnv1a("a"),PaFnv1a("foobar")));

   const uint h0=PaConfigHash(cfg);
   const uint h1=PaConfigHash(BaseConfig());
   PaConfig changed=BaseConfig();
   changed.wTrend=changed.wTrend+1.0;
   const uint h2=PaConfigHash(changed);
   Record("O3",h0==h1 && h0!=h2,StringFormat("h0=%u h2=%u",h0,h2));
  }

//+------------------------------------------------------------------+
//| P: output / bar policy                                           |
//+------------------------------------------------------------------+
void RunP()
  {
   Record("P1",!PaIsClosedBar(9,10) && PaIsClosedBar(8,10)
          && !PaIsClosedBar(0,1) && !PaIsClosedBar(-1,10),
          "only closed bars feed the engine");

   PaConfig cfg=BaseConfig();
   PaEngineState st;
   PaStateInit(st);
   PaBar bar=MkBar(100.0,100.0,100.0,100.0,D'2024.01.02 23:30');
   PaBarOut out;
   PaEngineStep(cfg,st,bar,10,out);
   Record("P2",out.score100==51 && !out.planValid && Near(out.entry,100.0)
          && EmptyD(out.sl) && EmptyD(out.tp1) && EmptyD(out.tp2)
          && EmptyD(out.tp3),StringFormat("score=%d",out.score100));

   PaStateInit(st);
   bar=MkBar(100.0,101.0,99.0,100.0,D'2024.01.02 23:30');
   bar.atr=2.0;
   bar.volume=1000.0;
   PaEngineStep(cfg,st,bar,10,out);
   Record("P3",out.volBucket==PA_BUCKET_VERYLOW && Near(out.volRatio,0.0),
          StringFormat("bucket=%d ratio=%.4f",out.volBucket,out.volRatio));

   Record("P4",PA_PLOT_BUFFERS==12 && PA_CONTRACT_FIRST==12
          && PA_CONTRACT_BUFFERS==95 && PA_TOTAL_BUFFERS==107
          && (int)PA_BUF_SCORE100==12 && (int)PA_BUF_LAST_LOW==106,
          "buffer map");
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
   RunP();

   PrintFormat("TEST|RESULT|%s|pass=%d fail=%d|contract=%s",
               (g_fail==0 ? "ALL_PASS" : "FAIL"),
               g_pass,g_fail,PA_CONTRACT_VERSION);
  }
//+------------------------------------------------------------------+
