//+------------------------------------------------------------------+
//|                                TMFusionZonesContractTests.mq5    |
//|      MT5 EA & AI Lab - synthetic checks for the FZ contract      |
//|                                                                  |
//| Runs once. No file I/O, no market data, no account access, no    |
//| trading functions. Vectors: docs/indicators/tm-fusion-zones.md|
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Synthetic contract tests for TM Fusion Zones. No trading."

#include "../Include/PinePort/TMFusionZonesContract.mqh"

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

FzConfig BaseConfig()
  {
   FzConfig cfg;
   cfg.assetMode=FZ_ASSET_AUTO;
   cfg.customVolMult=1.0;
   cfg.ribbonType=FZ_MA_EMA;
   cfg.ribbonFast=20;
   cfg.ribbonSlow=50;
   cfg.ribbonFilter=true;
   cfg.zonePivotLen=7;
   cfg.zoneWidthAtr=0.5;
   cfg.zoneMax=10;
   cfg.structPivotLen=5;
   cfg.sweepOn=true;
   cfg.pdOn=true;
   cfg.setupPullback=true;
   cfg.setupSweep=true;
   cfg.setupRange=false;
   cfg.pullTol=0.4;
   cfg.sweepConfBars=3;
   cfg.mtfOn=true;
   cfg.mtfTf=FZ_HTF_H4;
   cfg.mtfLen=100;
   cfg.wTrend=25.0;
   cfg.wZone=25.0;
   cfg.wStruct=20.0;
   cfg.wCandle=15.0;
   cfg.wMtf=15.0;
   cfg.scrNoTrade=49;
   cfg.scoreMargin=8;
   cfg.slMode=FZ_SL_ZONE_SWING;
   cfg.tpMode=FZ_TP_OPPOSING;
   cfg.slAtrMul=1.5;
   cfg.slPadAtr=0.2;
   cfg.slMinAtr=0.5;
   cfg.slMaxAtr=3.5;
   cfg.rr1=1.0;
   cfg.rr2=2.0;
   cfg.rr3=3.0;
   cfg.rrMin=1.5;
   cfg.obstacleGate=true;
   cfg.coolBars=8;
   cfg.maxBars=0;
   cfg.effAsset=FZ_ASSET_CUSTOM;
   cfg.assetVolMult=1.0;
   FzNormalizeConfig(cfg);
   return(cfg);
  }

FzBar MkBar(const double openPx,const double highPx,const double lowPx,
            const double closePx,const double atr,const double maFast,
            const double maSlow)
  {
   FzBar bar;
   bar.time=0;
   bar.open=openPx;
   bar.high=highPx;
   bar.low=lowPx;
   bar.close=closePx;
   bar.tickSize=0.01;
   bar.atr=atr;
   bar.regime=FZ_REGIME_TRANSITIONAL;
   bar.maFast=maFast;
   bar.maSlow=maSlow;
   bar.htfEma=EMPTY_VALUE;
   bar.htfValid=false;
   bar.znPh=EMPTY_VALUE;
   bar.znPl=EMPTY_VALUE;
   bar.znPhValid=false;
   bar.znPlValid=false;
   bar.msPh=EMPTY_VALUE;
   bar.msPl=EMPTY_VALUE;
   bar.msPhValid=false;
   bar.msPlValid=false;
   return(bar);
  }

//--- A: clamp, ATR floor, asset profile
void RunA()
  {
   Record("A1",Near(FzClamp(-5.0,0.0,10.0),0.0),"clamp below low");
   Record("A2",Near(FzClamp(50.0,0.0,10.0),10.0),"clamp above high");
   Record("A3",Near(FzClamp(5.0,0.0,10.0),5.0),"clamp inside");

   Record("A4",Near(FzAtrSafe(0.5,0.1),0.5) &&
          Near(FzAtrSafe(0.1,0.1),0.2) &&
          FzIsNa(FzAtrSafe(EMPTY_VALUE,0.1)),
          StringFormat("a=%.3f b=%.3f na=%d",
                       FzAtrSafe(0.5,0.1),FzAtrSafe(0.1,0.1),
                       (int)FzIsNa(FzAtrSafe(EMPTY_VALUE,0.1))));

   Record("A5",FzResolveAsset(FZ_ASSET_AUTO,"XAUUSD")==FZ_ASSET_XAU &&
          FzResolveAsset(FZ_ASSET_AUTO,"GOLD")==FZ_ASSET_XAU &&
          FzResolveAsset(FZ_ASSET_AUTO,"BTCUSD")==FZ_ASSET_BTC &&
          Near(FzAssetVolMult(FZ_ASSET_BTC,1.0),1.25) &&
          Near(FzAssetVolMult(FZ_ASSET_CUSTOM,1.4),1.4),
          "asset auto-detect and multipliers");
  }

//--- B: MA factory
void RunB()
  {
   double src1[];
   ArrayResize(src1,4);
   src1[0]=1.0;
   src1[1]=2.0;
   src1[2]=3.0;
   src1[3]=4.0;
   Record("B1",Near(FzSmaAt(src1,4,3,2),3.5),"SMA of 3,4 must be 3.5");

   double src2[];
   ArrayResize(src2,4);
   src2[0]=1.0;
   src2[1]=2.0;
   src2[2]=3.0;
   src2[3]=4.0;
   Record("B2",Near(FzEmaAt(src2,4,2,3),2.0) && Near(FzEmaAt(src2,4,3,3),3.0),
          "EMA seed 2.0 then 3.0");

   double src3[];
   ArrayResize(src3,3);
   src3[0]=1.0;
   src3[1]=2.0;
   src3[2]=3.0;
   Record("B3",Near(FzWmaAt(src3,3,2,3),14.0/6.0),"WMA of 1,2,3 must be 2.333..");

   double flat[];
   ArrayResize(flat,40);
   for(int i=0; i<40; i++)
      flat[i]=1.0;
   double hma[];
   FzBuildMaSeries(flat,40,4,FZ_MA_HMA,hma);
   Record("B4",Near(hma[39],1.0),"HMA of a constant series must equal the constant");

   Record("B5",Near(FzMaAt(src1,4,3,3,FZ_MA_SMA),FzSmaAt(src1,4,3,3)) &&
          FzIsNa(FzMaAt(src1,4,1,3,FZ_MA_SMA)),
          "dispatch matches SMA; insufficient history is na");
  }

//--- C: RMA / TR / ATR / ADX / chop series
void RunC()
  {
   double src[];
   ArrayResize(src,5);
   src[0]=1.0;
   src[1]=2.0;
   src[2]=3.0;
   src[3]=4.0;
   src[4]=5.0;
   double rma[];
   FzBuildRmaSeries(src,5,3,rma);
   Record("C1",FzIsNa(rma[1]) && Near(rma[2],2.0) &&
          Near(rma[3],8.0/3.0) && Near(rma[4],31.0/9.0),
          StringFormat("r2=%.4f r3=%.4f r4=%.4f",rma[2],rma[3],rma[4]));

   Record("C2",Near(FzTr(false,10.0,8.0,0.0),2.0) &&
          Near(FzTr(true,10.0,8.0,7.0),3.0),
          "TR first bar is range; later bars include the previous close");

   double high1[],low1[],close1[];
   ArrayResize(high1,30);
   ArrayResize(low1,30);
   ArrayResize(close1,30);
   for(int i=0; i<30; i++)
     {
      high1[i]=101.0;
      low1[i]=99.0;
      close1[i]=100.0;
     }
   double atr[];
   FzBuildAtrSeries(high1,low1,close1,30,14,atr);
   Record("C3",Near(atr[13],2.0) && Near(atr[29],2.0),
          StringFormat("atr13=%.4f atr29=%.4f",atr[13],atr[29]));

   double high2[],low2[],close2[];
   ArrayResize(high2,40);
   ArrayResize(low2,40);
   ArrayResize(close2,40);
   for(int i=0; i<40; i++)
     {
      high2[i]=100.0+(double)i+1.0;
      low2[i]=100.0+(double)i;
      close2[i]=100.0+(double)i+1.0;
     }
   double adx[];
   FzBuildAdxSeries(high2,low2,close2,40,14,adx);
   Record("C4",FzIsNa(adx[25]) && Near(adx[26],100.0) && Near(adx[39],100.0),
          StringFormat("adx25 na=%d adx26=%.3f adx39=%.3f",
                       (int)FzIsNa(adx[25]),adx[26],adx[39]));

   double high3[],low3[],close3[];
   ArrayResize(high3,30);
   ArrayResize(low3,30);
   ArrayResize(close3,30);
   for(int i=0; i<30; i++)
     {
      high3[i]=100.0;
      low3[i]=100.0;
      close3[i]=100.0;
     }
   double chopFlat[];
   FzBuildChopSeries(high3,low3,close3,30,14,chopFlat);
   Record("C5",Near(chopFlat[29],50.0),
          "flat market must default chop to 50");

   double high4[],low4[],close4[];
   ArrayResize(high4,20);
   ArrayResize(low4,20);
   ArrayResize(close4,20);
   for(int i=0; i<20; i++)
     {
      high4[i]=(double)i;
      low4[i]=(double)i-1.0;
      close4[i]=(double)i;
     }
   double chop[];
   FzBuildChopSeries(high4,low4,close4,20,14,chop);
   Record("C6",Near(chop[13],0.0),
          StringFormat("chop13=%.6f expected 0",chop[13]));
  }

//--- D: regime classifier
void RunD()
  {
   Record("D1",FzRegime(23.0,56.0)==FZ_REGIME_TRENDING,
          "ADX 23 and chop 56 must be trending");
   Record("D2",FzRegime(20.0,58.0)==FZ_REGIME_RANGE,
          "chop 58 must be range");
   Record("D3",FzRegime(17.9,50.0)==FZ_REGIME_RANGE,
          "ADX below 18 must be range");
   Record("D4",FzRegime(20.0,57.0)==FZ_REGIME_TRANSITIONAL &&
          FzRegime(EMPTY_VALUE,50.0)==FZ_REGIME_TRANSITIONAL,
          "otherwise transitional, including missing ADX");
  }

FzBarOut Eval(const FzConfig &cfg,FzEngineState &st,const FzBar &bar,const int idx)
  {
   FzBarOut out;
   FzEngineStep(cfg,st,bar,idx,out);
   return(out);
  }

//--- E: ribbon direction / slope / proximity
void RunE()
  {
   const FzConfig cfg=BaseConfig();

   FzEngineState st1;
   FzStateInit(st1);
   FzBarOut out1=Eval(cfg,st1,MkBar(99.0,100.0,98.5,99.5,1.0,10.0,9.0),0);
   Record("E1",out1.rbBull && !out1.rbBear,"fast above slow must be bull");

   FzEngineState st2;
   FzStateInit(st2);
   Eval(cfg,st2,MkBar(99.0,100.0,98.5,99.5,1.0,10.0,11.0),0);
   FzBarOut out2=Eval(cfg,st2,MkBar(99.0,100.0,98.5,99.5,1.0,9.0,10.5),1);
   Record("E2",out2.rbBear && out2.rbStrongBear,
          "both MAs falling with fast below slow must be strong bear");

   FzEngineState st3;
   FzStateInit(st3);
   Eval(cfg,st3,MkBar(99.0,100.0,98.5,99.5,1.0,10.0,11.0),0);
   FzBarOut out3=Eval(cfg,st3,MkBar(99.0,100.0,98.5,99.5,1.0,9.0,10.5),1);
   Record("E3",out3.rbExpanding,"spread 1.0 -> 1.5 must expand");

   FzEngineState st4;
   FzStateInit(st4);
   FzBarOut out4=Eval(cfg,st4,MkBar(9.5,10.4,8.6,9.7,1.0,10.0,9.0),0);
   FzEngineState st5;
   FzStateInit(st5);
   FzBarOut out5=Eval(cfg,st5,MkBar(10.45,10.5,10.41,10.45,1.0,10.0,9.0),0);
   Record("E4",out4.priceInRibbon && !out5.priceInRibbon,
          "proximity includes both sides and excludes bars above top+tol");

   FzConfig cfgNoFilter=BaseConfig();
   cfgNoFilter.ribbonFilter=false;
   cfgNoFilter.setupSweep=false;
   cfgNoFilter.setupRange=false;
   cfgNoFilter.mtfOn=false;
   FzEngineState st6;
   FzStateInit(st6);
   FzBar noFilterBar=MkBar(9.3,10.1,9.2,10.0,1.0,9.0,10.0);
   FzBarOut out6=Eval(cfgNoFilter,st6,noFilterBar,0);
   Record("E5",out6.rbBear && Near(out6.rbTop,10.0) && Near(out6.rbBot,9.0) &&
          out6.setupLong==FZ_SETUP_PULLBACK,
          StringFormat("bullSetup=%d",out6.setupLong));
  }

//--- F: zone engine
void RunF()
  {
   FzEngineState st1;
   FzStateInit(st1);
   FzZoneRegister(st1,-1,100.0,1.0,0.5,0.25,0);
   Record("F1",st1.zoneCount==1 && st1.zones[0].side==-1 &&
          Near(st1.zones[0].top,100.25) && Near(st1.zones[0].bot,99.75) &&
          st1.zones[0].touches==1,
          "supply registration");

   FzEngineState st2;
   FzStateInit(st2);
   FzZoneRegister(st2,1,90.0,1.0,0.5,0.25,0);
   Record("F2",st2.zoneCount==1 && st2.zones[0].side==1 &&
          Near(st2.zones[0].top,90.25) && Near(st2.zones[0].bot,89.75),
          "demand registration");

   FzEngineState st3;
   FzStateInit(st3);
   FzZoneRegister(st3,-1,100.0,1.0,0.5,0.25,0);
   FzZoneRegister(st3,-1,100.4,1.0,0.5,0.25,0);
   Record("F3",st3.zoneCount==1 && Near(st3.zones[0].top,100.65) &&
          Near(st3.zones[0].bot,99.75) && st3.zones[0].touches==2,
          StringFormat("count=%d top=%.3f bot=%.3f t=%d",
                       st3.zoneCount,st3.zones[0].top,st3.zones[0].bot,
                       st3.zones[0].touches));

   FzEngineState st4;
   FzStateInit(st4);
   FzZoneRegister(st4,-1,100.0,1.0,0.5,0.25,0);
   FzZoneRegister(st4,-1,101.0,1.0,0.5,0.25,0);
   Record("F4",st4.zoneCount==2,"pivot outside width must create a second zone");

   FzEngineState st5;
   FzStateInit(st5);
   FzZoneRegister(st5,1,90.0,1.0,0.5,0.25,0);
   FzZoneUpdate(st5,90.2,89.9,89.0,90.1,90.0,true);
   FzZoneCleanup(st5,10);
   Record("F5",st5.zoneCount==0,"close below demand bottom must break it");

   FzEngineState st6;
   FzStateInit(st6);
   FzZoneRegister(st6,-1,100.0,1.0,0.5,0.25,0);
   FzZoneUpdate(st6,101.0,99.9,101.0,100.2,99.8,true);
   FzZoneCleanup(st6,10);
   Record("F6",st6.zoneCount==0,"close above supply top must break it");

   FzEngineState st7;
   FzStateInit(st7);
   FzZoneRegister(st7,1,90.0,1.0,0.5,0.25,0);
   FzZoneUpdate(st7,90.2,89.9,90.0,91.0,91.0,true);
   Record("F7",st7.zones[0].touches==2,
          StringFormat("touches=%d",st7.zones[0].touches));

   FzEngineState st8;
   FzStateInit(st8);
   FzZoneRegister(st8,1,90.0,1.0,0.5,0.25,0);
   FzZoneRegister(st8,1,91.0,1.0,0.5,0.25,1);
   FzZoneRegister(st8,1,92.0,1.0,0.5,0.25,2);
   FzZoneRegister(st8,1,93.0,1.0,0.5,0.25,3);
   FzZoneRegister(st8,1,94.0,1.0,0.5,0.25,4);
   FzZoneCleanup(st8,2);
   Record("F8",st8.zoneCount==2 && Near(st8.zones[0].bot,92.75) &&
          Near(st8.zones[1].bot,93.75),
          StringFormat("count=%d b0=%.3f b1=%.3f",
                       st8.zoneCount,st8.zones[0].bot,st8.zones[1].bot));

   FzEngineState st9;
   FzStateInit(st9);
   FzZoneRegister(st9,1,90.0,1.0,0.5,0.25,0);
   FzZoneRegister(st9,1,94.0,1.0,0.5,0.25,0);
   bool inDemand=false,inSupply=false;
   double demandBot=EMPTY_VALUE,demandTop=EMPTY_VALUE;
   double supplyTop=EMPTY_VALUE,supplyBot=EMPTY_VALUE;
   FzZoneInteract(st9,94.2,89.8,1.0,inDemand,inSupply,
                  demandBot,demandTop,supplyTop,supplyBot);

   FzEngineState st10;
   FzStateInit(st10);
   FzZoneRegister(st10,-1,100.0,1.0,0.5,0.25,0);
   FzZoneUpdate(st10,101.0,99.9,101.0,100.2,99.8,true);
   FzZoneCleanup(st10,10);
   bool inDemand2=false,inSupply2=false;
   double demandBot2=EMPTY_VALUE,demandTop2=EMPTY_VALUE;
   double supplyTop2=EMPTY_VALUE,supplyBot2=EMPTY_VALUE;
   FzZoneInteract(st10,101.0,99.9,1.0,inDemand2,inSupply2,
                  demandBot2,demandTop2,supplyTop2,supplyBot2);
   Record("F9",inDemand && Near(demandBot,93.75) && !inSupply2 && !inSupply,
          StringFormat("demandBot=%.3f supplyBroken=%d",demandBot,(int)inSupply));
  }

//--- G: structure, BOS, CHoCH, sweeps
void RunG()
  {
   double high1[];
   ArrayResize(high1,5);
   high1[0]=1.0;
   high1[1]=2.0;
   high1[2]=3.0;
   high1[3]=2.0;
   high1[4]=1.0;
   double value=EMPTY_VALUE;
   Record("G1",FzPivotHighAt(high1,5,4,2,value) && Near(value,3.0),
          "strict pivot high at center 2");

   double high2[];
   ArrayResize(high2,5);
   high2[0]=1.0;
   high2[1]=2.0;
   high2[2]=3.0;
   high2[3]=3.0;
   high2[4]=1.0;
   Record("G2",!FzPivotHighAt(high2,5,4,2,value),
          "equal right neighbour must reject the pivot");

   const FzConfig cfg=BaseConfig();

   FzEngineState st3;
   FzStateInit(st3);
   st3.hasSwH=true;
   st3.swH=10.0;
   st3.hasPrev=true;
   st3.prevClose=10.0;
   st3.prevHigh=10.5;
   st3.prevLow=9.5;
   FzBarOut out3=Eval(cfg,st3,MkBar(10.3,11.2,10.2,11.0,1.0,0.0,0.0),1);
   Record("G3",out3.bosBull && !out3.bosBear,"close through swing high must be BOS bull");

   FzEngineState st4;
   FzStateInit(st4);
   st4.hasSwH=true;
   st4.swH=10.0;
   st4.msTrend=-1;
   st4.hasPrev=true;
   st4.prevClose=10.0;
   st4.prevHigh=10.5;
   st4.prevLow=9.5;
   FzBarOut out4=Eval(cfg,st4,MkBar(10.3,11.2,10.2,11.0,1.0,0.0,0.0),1);
   Record("G4",out4.bosBull && out4.chochBull && st4.msTrend==1,
          "BOS against a bearish trend must flag CHoCH bull");

   FzEngineState st5;
   FzStateInit(st5);
   st5.hasSwL=true;
   st5.swL=10.0;
   FzBarOut out5=Eval(cfg,st5,MkBar(10.4,10.6,9.5,10.5,1.0,0.0,0.0),1);

   FzConfig cfgOff=BaseConfig();
   cfgOff.sweepOn=false;
   cfgOff.pdOn=false;
   FzEngineState st6;
   FzStateInit(st6);
   st6.hasSwL=true;
   st6.swL=10.0;
   FzBarOut out6=Eval(cfgOff,st6,MkBar(10.4,10.6,9.5,10.5,1.0,0.0,0.0),1);

   FzConfig cfgPd=BaseConfig();
   cfgPd.sweepOn=false;
   cfgPd.pdOn=true;
   FzEngineState st7;
   FzStateInit(st7);
   st7.hasPdl=true;
   st7.pdl=10.0;
   FzBarOut out7=Eval(cfgPd,st7,MkBar(10.4,10.6,9.5,10.5,1.0,0.0,0.0),1);
   Record("G5",out5.swpBull && !out6.swpBull && out7.swpBull,
          StringFormat("swing=%d off=%d pd=%d",
                       (int)out5.swpBull,(int)out6.swpBull,(int)out7.swpBull));
  }

//--- H: candles
void RunH()
  {
   const FzConfig cfg=BaseConfig();

   FzEngineState st1;
   FzStateInit(st1);
   FzBarOut out1=Eval(cfg,st1,MkBar(100.0,101.2,98.0,101.0,1.0,0.0,0.0),0);
   Record("H1",out1.pinBull && !out1.pinBear,"long lower wick must be a bull pin");

   FzEngineState st2;
   FzStateInit(st2);
   FzBarOut out2=Eval(cfg,st2,MkBar(101.0,103.0,99.8,100.0,1.0,0.0,0.0),0);
   Record("H2",out2.pinBear && !out2.pinBull,"long upper wick must be a bear pin");

   FzEngineState st3;
   FzStateInit(st3);
   st3.hasPrev=true;
   st3.prevOpen=102.0;
   st3.prevClose=100.0;
   st3.prevHigh=102.5;
   st3.prevLow=99.5;
   FzBarOut out3=Eval(cfg,st3,MkBar(99.5,103.0,99.0,102.5,1.0,0.0,0.0),1);
   Record("H3",out3.engulfBull,"open <= prev close and close >= prev open must engulf");

   FzEngineState st4;
   FzStateInit(st4);
   FzBarOut out4=Eval(cfg,st4,MkBar(100.0,101.0,100.0,101.0,1.0,0.0,0.0),0);
   FzEngineState st5;
   FzStateInit(st5);
   FzBarOut out5=Eval(cfg,st5,MkBar(100.0,100.0,100.0,100.0,1.0,0.0,0.0),0);
   Record("H4",out4.momBull && !out5.candleBull && !out5.candleBear,
          StringFormat("mom=%d flatBull=%d",(int)out4.momBull,(int)out5.candleBull));
  }

//--- I: MTF mapping and bias
void RunI()
  {
   datetime closeTimes[];
   ArrayResize(closeTimes,3);
   closeTimes[0]=100;
   closeTimes[1]=200;
   closeTimes[2]=300;
   Record("I1",FzMapHtfIndex(closeTimes,3,200)==1,
          "boundary close time must map to the just-closed bar");
   Record("I2",FzMapHtfIndex(closeTimes,3,250)==1,
          "between closes must map to the previous bar");

   const FzConfig cfg=BaseConfig();

   FzEngineState st3;
   FzStateInit(st3);
   FzBarOut out3=Eval(cfg,st3,MkBar(100.0,101.0,99.0,100.0,1.0,0.0,0.0),0);
   Record("I3",FzMapHtfIndex(closeTimes,3,50)==-1 &&
          out3.htfBull && out3.htfBear,
          "before the first close maps to -1 and missing MTF allows both directions");

   FzBar bar4=MkBar(100.0,101.0,99.0,100.0,1.0,0.0,0.0);
   bar4.htfEma=100.0;
   bar4.htfValid=true;
   FzEngineState st4;
   FzStateInit(st4);
   FzBarOut out4=Eval(cfg,st4,bar4,0);
   Record("I4",out4.htfValid && out4.htfBull && out4.htfBear,
          "close equal to HTF EMA must allow both directions");

   FzBar bar5=MkBar(100.0,101.0,99.0,100.0,1.0,0.0,0.0);
   bar5.htfEma=EMPTY_VALUE;
   bar5.htfValid=true;
   FzEngineState st5;
   FzStateInit(st5);
   FzBarOut out5=Eval(cfg,st5,bar5,0);
   Record("I5",out5.htfBull && out5.htfBear && FzIsNa(out5.htfEma),
          "valid flag with missing EMA must fall back to both directions");
  }

//--- J: setups and priority
void RunJ()
  {
   FzConfig cfg=BaseConfig();
   cfg.mtfOn=false;
   cfg.setupSweep=false;
   cfg.setupRange=false;

   FzEngineState st1;
   FzStateInit(st1);
   FzBarOut out1=Eval(cfg,st1,MkBar(9.5,9.7,9.1,9.6,1.0,10.0,9.0),0);
   Record("J1",out1.longSetupDetected && out1.setupLong==FZ_SETUP_PULLBACK,
          StringFormat("setup=%d",out1.setupLong));

   FzEngineState st2;
   FzStateInit(st2);
   FzBarOut out2=Eval(cfg,st2,MkBar(10.4,10.6,9.8,9.9,1.0,9.0,10.0),0);
   Record("J2",out2.shortSetupDetected && out2.setupShort==FZ_SETUP_PULLBACK,
          StringFormat("setup=%d",out2.setupShort));

   FzConfig cfgSweep=BaseConfig();
   cfgSweep.mtfOn=false;
   cfgSweep.setupPullback=false;
   cfgSweep.setupRange=false;

   FzEngineState st3;
   FzStateInit(st3);
   st3.hasSwL=true;
   st3.swL=10.0;
   FzBarOut out3=Eval(cfgSweep,st3,MkBar(10.2,10.8,9.5,10.5,1.0,0.0,0.0),0);
   Record("J3",out3.longSetupDetected && out3.setupLong==FZ_SETUP_SWEEP,
          StringFormat("setup=%d",out3.setupLong));

   FzEngineState st4;
   FzStateInit(st4);
   st4.hasSwL=true;
   st4.swL=10.0;
   st4.lastBullSweepBar=0;
   FzBarOut out4=Eval(cfgSweep,st4,MkBar(10.3,10.6,10.2,10.5,1.0,9.0,10.0),5);
   Record("J4",out4.setupLong!=FZ_SETUP_SWEEP,
          StringFormat("setup=%d",out4.setupLong));

   FzConfig cfgRange=BaseConfig();
   cfgRange.mtfOn=false;
   cfgRange.setupSweep=false;
   cfgRange.setupRange=true;

   FzBar rangeBar=MkBar(89.6,90.6,89.4,90.5,1.0,10.0,9.0);
   rangeBar.regime=FZ_REGIME_RANGE;

   FzEngineState st5;
   FzStateInit(st5);
   st5.zones[0].top=91.0;
   st5.zones[0].bot=89.0;
   st5.zones[0].side=1;
   st5.zones[0].touches=1;
   st5.zones[0].broken=false;
   st5.zones[0].startBar=0;
   st5.zoneCount=1;
   FzBarOut out5=Eval(cfgRange,st5,rangeBar,0);

   FzEngineState st6;
   FzStateInit(st6);
   st6.zones[0].top=91.0;
   st6.zones[0].bot=89.0;
   st6.zones[0].side=1;
   st6.zones[0].touches=1;
   st6.zones[0].broken=false;
   st6.zones[0].startBar=0;
   st6.zoneCount=1;
   FzBar bearBar=MkBar(89.6,90.6,89.4,90.5,1.0,8.0,10.0);
   bearBar.regime=FZ_REGIME_RANGE;
   FzBarOut out6=Eval(cfgRange,st6,bearBar,0);
   Record("J5",out5.setupLong==FZ_SETUP_PULLBACK && out5.inDemand &&
          out6.setupLong==FZ_SETUP_RANGE && out6.inDemand,
          StringFormat("pull=%d range=%d",out5.setupLong,out6.setupLong));
  }

//--- K: scoring
void RunK()
  {
   const FzConfig cfg=BaseConfig();
   Record("K1",Near(FzScoreLong(cfg,true,true,true,true,true,true,true,true,true,true),100.0),
          "all long factors true must score 100");

   Record("K2",Near(FzScoreLong(cfg,false,true,true,true,false,false,true,true,true,false),74.0),
          StringFormat("score=%.1f",FzScoreLong(cfg,false,true,true,true,false,false,true,true,true,false)));

   Record("K3",Near(FzScoreLong(cfg,true,true,true,true,true,true,true,true,true,false),85.0),
          "missing MTF factor must drop 15 points");

   FzConfig zero=BaseConfig();
   zero.wTrend=0.0;
   zero.wZone=0.0;
   zero.wStruct=0.0;
   zero.wCandle=0.0;
   zero.wMtf=0.0;
   Record("K4",Near(FzScoreShort(zero,true,true,true,true,true,true,true,true,true,true),0.0),
          "zero total weight must score 0");

   FzConfig half=BaseConfig();
   half.wTrend=1.0;
   half.wZone=1.0;
   half.wStruct=0.0;
   half.wCandle=0.0;
   half.wMtf=0.0;
   Record("K5",Near(FzScoreLong(half,true,false,false,true,false,false,false,false,false,false),85.0),
          StringFormat("score=%.1f expected 85",
                       FzScoreLong(half,true,false,false,true,false,false,false,false,false,false)));
  }

//--- L: risk engine
void RunL()
  {
   const FzConfig cfg=BaseConfig();

   double sl=EMPTY_VALUE,tp1=EMPTY_VALUE,tp2=EMPTY_VALUE,tp3=EMPTY_VALUE,rd=EMPTY_VALUE;
   const bool ok1=FzRiskLong(cfg,100.0,1.0,1.0,true,98.0,false,EMPTY_VALUE,
                             false,EMPTY_VALUE,sl,tp1,tp2,tp3,rd);
   Record("L1",ok1 && Near(sl,97.8) && Near(rd,2.2) && Near(tp1,102.2) &&
          Near(tp2,104.4) && Near(tp3,106.6),
          StringFormat("sl=%.3f rd=%.3f tp1=%.3f",sl,rd,tp1));

   sl=EMPTY_VALUE;
   tp1=EMPTY_VALUE;
   tp2=EMPTY_VALUE;
   tp3=EMPTY_VALUE;
   rd=EMPTY_VALUE;
   const bool ok2=FzRiskLong(cfg,100.0,1.0,1.0,false,EMPTY_VALUE,true,97.0,
                             false,EMPTY_VALUE,sl,tp1,tp2,tp3,rd);
   Record("L2",ok2 && Near(sl,96.8) && Near(rd,3.2),
          StringFormat("sl=%.3f rd=%.3f",sl,rd));

   sl=EMPTY_VALUE;
   tp1=EMPTY_VALUE;
   tp2=EMPTY_VALUE;
   tp3=EMPTY_VALUE;
   rd=EMPTY_VALUE;
   const bool ok3=FzRiskLong(cfg,100.0,1.0,1.0,false,EMPTY_VALUE,false,EMPTY_VALUE,
                             false,EMPTY_VALUE,sl,tp1,tp2,tp3,rd);
   Record("L3",ok3 && Near(sl,98.3) && Near(rd,1.7),
          StringFormat("sl=%.3f rd=%.3f",sl,rd));

   sl=EMPTY_VALUE;
   tp1=EMPTY_VALUE;
   tp2=EMPTY_VALUE;
   tp3=EMPTY_VALUE;
   rd=EMPTY_VALUE;
   FzRiskLong(cfg,100.0,1.0,1.0,false,EMPTY_VALUE,true,99.9,
              false,EMPTY_VALUE,sl,tp1,tp2,tp3,rd);
   Record("L4",Near(rd,0.5) && Near(sl,99.5),
          StringFormat("raw clamp low rd=%.3f sl=%.3f",rd,sl));

   sl=EMPTY_VALUE;
   tp1=EMPTY_VALUE;
   tp2=EMPTY_VALUE;
   tp3=EMPTY_VALUE;
   rd=EMPTY_VALUE;
   FzRiskLong(cfg,100.0,1.0,1.0,true,90.0,false,EMPTY_VALUE,
              false,EMPTY_VALUE,sl,tp1,tp2,tp3,rd);
   Record("L5",Near(rd,3.5) && Near(sl,96.5),
          StringFormat("raw clamp high rd=%.3f sl=%.3f",rd,sl));

   sl=EMPTY_VALUE;
   tp1=EMPTY_VALUE;
   tp2=EMPTY_VALUE;
   tp3=EMPTY_VALUE;
   rd=EMPTY_VALUE;
   FzRiskLong(cfg,100.0,1.0,1.0,true,98.0,false,EMPTY_VALUE,
              true,102.5,sl,tp1,tp2,tp3,rd);
   Record("L6",Near(tp1,102.2) && Near(tp2,102.5) && Near(tp3,104.7),
          StringFormat("tp1=%.3f tp2=%.3f tp3=%.3f",tp1,tp2,tp3));

   FzConfig fixed=BaseConfig();
   fixed.tpMode=FZ_TP_FIXED_RR;
   sl=EMPTY_VALUE;
   tp1=EMPTY_VALUE;
   tp2=EMPTY_VALUE;
   tp3=EMPTY_VALUE;
   rd=EMPTY_VALUE;
   const bool ok7=FzRiskShort(fixed,100.0,1.0,1.0,true,102.0,false,EMPTY_VALUE,
                              true,101.0,sl,tp1,tp2,tp3,rd);
   Record("L7",ok7 && Near(sl,102.2) && Near(rd,2.2) &&
          Near(tp1,97.8) && Near(tp2,95.6) && Near(tp3,93.4),
          StringFormat("sl=%.3f tp1=%.3f tp2=%.3f",sl,tp1,tp2));
  }

//--- M: gates and eligibility
void RunM()
  {
   const FzConfig cfg=BaseConfig();
   int blockLong=FZ_BLOCK_NONE;
   int blockShort=FZ_BLOCK_NONE;

   FzGates(cfg,100.0,102.0,98.0,true,1.5,false,FZ_INF,
           true,false,80.0,0.0,true,blockLong,blockShort);
   Record("M1",blockLong==FZ_BLOCK_OPPOSING_ZONE,
          StringFormat("blockLong=%d",blockLong));

   FzConfig rrCfg=BaseConfig();
   rrCfg.rr2=1.0;
   FzGates(rrCfg,100.0,102.0,98.0,false,FZ_INF,false,FZ_INF,
           true,false,80.0,80.0,true,blockLong,blockShort);
   Record("M2",blockLong==FZ_BLOCK_RR_MIN && blockShort==FZ_BLOCK_RR_MIN,
          StringFormat("long=%d short=%d",blockLong,blockShort));

   FzGates(cfg,100.0,102.0,98.0,false,FZ_INF,false,FZ_INF,
           true,false,80.0,80.0,false,blockLong,blockShort);
   const bool coolBlocked=(blockLong==FZ_BLOCK_COOLDOWN &&
                           blockShort==FZ_BLOCK_COOLDOWN);
   FzGates(cfg,100.0,102.0,98.0,false,FZ_INF,false,FZ_INF,
           true,false,80.0,80.0,true,blockLong,blockShort);
   Record("M3",coolBlocked && blockLong==FZ_BLOCK_NONE && blockShort==FZ_BLOCK_NONE,
          "cooldown must block only while coolOk is false");

   FzGates(cfg,100.0,102.0,98.0,false,FZ_INF,false,FZ_INF,
           true,true,60.0,66.0,true,blockLong,blockShort);
   Record("M4",blockLong==FZ_BLOCK_SCORE_MARGIN &&
          blockShort==FZ_BLOCK_SCORE_MARGIN,
          StringFormat("long=%d short=%d",blockLong,blockShort));

   FzGates(cfg,100.0,102.0,98.0,false,FZ_INF,false,FZ_INF,
           false,false,49.0,80.0,true,blockLong,blockShort);
   const bool lowBlocked=(blockLong==FZ_BLOCK_SCORE_NOTRADE);
   FzGates(cfg,100.0,102.0,98.0,false,FZ_INF,false,FZ_INF,
           false,false,50.0,80.0,true,blockLong,blockShort);
   Record("M5",lowBlocked && blockLong==FZ_BLOCK_NONE,
          "score at the threshold is blocked; one point above passes");

   FzConfig first=BaseConfig();
   first.rr2=1.0;
   FzGates(first,100.0,102.0,98.0,true,1.5,false,FZ_INF,
           true,false,80.0,80.0,false,blockLong,blockShort);
   Record("M6",blockLong==FZ_BLOCK_OPPOSING_ZONE,
          StringFormat("long=%d expected opposing-zone first",blockLong));

   bool sigLong=false,sigShort=false;
   blockLong=FZ_BLOCK_NONE;
   blockShort=FZ_BLOCK_NONE;
   FzEligibility(cfg,true,true,true,70.0,70.0,blockLong,blockShort,sigLong,sigShort);
   const bool tieLong=sigLong && !sigShort && blockShort==FZ_BLOCK_OPPOSITE_WON;
   blockLong=FZ_BLOCK_NONE;
   blockShort=FZ_BLOCK_NONE;
   FzEligibility(cfg,true,true,true,60.0,70.0,blockLong,blockShort,sigLong,sigShort);
   Record("M7",tieLong && !sigLong && sigShort && blockLong==FZ_BLOCK_OPPOSITE_WON,
          "ties go long; otherwise the higher score wins");
  }

//--- N: state machine
void RunN()
  {
   const double slL=98.0;
   const double tp1L=101.0;
   const double tp2L=103.0;
   const double tp3L=105.0;

   FzEngineState st1;
   FzStateInit(st1);
   FzBarOut out1;
   FzStateStep(st1,0,MkBar(100.0,100.0,99.0,100.0,1.0,0.0,0.0),true,false,
               slL,tp1L,tp2L,tp3L,80,FZ_SETUP_PULLBACK,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out1);
   FzStateStep(st1,1,MkBar(100.0,101.1,99.5,100.5,1.0,0.0,0.0),false,false,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out1);
   Record("N1",out1.hitTp1 && !out1.hitTp2 && out1.posSide==1,
          "bar above TP1 must set the TP1 edge");

   FzEngineState st2;
   FzStateInit(st2);
   FzBarOut out2;
   FzStateStep(st2,0,MkBar(100.0,100.0,99.0,100.0,1.0,0.0,0.0),true,false,
               slL,tp1L,tp2L,tp3L,80,FZ_SETUP_PULLBACK,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out2);
   FzStateStep(st2,1,MkBar(100.0,103.1,99.5,101.0,1.0,0.0,0.0),false,false,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out2);
   Record("N2",out2.hitTp1 && out2.hitTp2 && !out2.hitTp3 && st2.posSide==1,
          "bar above TP2 must set TP1 and TP2");

   FzEngineState st3;
   FzStateInit(st3);
   FzBarOut out3;
   FzStateStep(st3,0,MkBar(100.0,100.0,99.0,100.0,1.0,0.0,0.0),true,false,
               slL,tp1L,tp2L,tp3L,80,FZ_SETUP_PULLBACK,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out3);
   FzStateStep(st3,1,MkBar(100.0,105.1,99.5,102.0,1.0,0.0,0.0),false,false,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out3);
   Record("N3",out3.hitTp3 && st3.posSide==0 && st3.cntWins==1,
          StringFormat("side=%d wins=%d",st3.posSide,st3.cntWins));

   FzEngineState st4;
   FzStateInit(st4);
   FzBarOut out4;
   FzStateStep(st4,0,MkBar(100.0,100.0,99.0,100.0,1.0,0.0,0.0),true,false,
               slL,tp1L,tp2L,tp3L,80,FZ_SETUP_PULLBACK,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out4);
   FzStateStep(st4,1,MkBar(99.5,100.5,97.9,98.5,1.0,0.0,0.0),false,false,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out4);
   Record("N4",out4.hitSl && !out4.hitTp1 && st4.cntLosses==1,
          StringFormat("losses=%d",st4.cntLosses));

   FzEngineState st5;
   FzStateInit(st5);
   FzBarOut out5;
   FzStateStep(st5,0,MkBar(100.0,100.0,99.0,100.0,1.0,0.0,0.0),true,false,
               slL,tp1L,tp2L,tp3L,80,FZ_SETUP_PULLBACK,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out5);
   FzStateStep(st5,1,MkBar(100.0,101.5,99.5,100.5,1.0,0.0,0.0),false,false,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out5);
   FzStateStep(st5,2,MkBar(100.0,100.2,97.5,98.0,1.0,0.0,0.0),false,false,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out5);
   Record("N5",st5.cntWins==1 && st5.cntLosses==0,
          StringFormat("wins=%d losses=%d",st5.cntWins,st5.cntLosses));

   FzEngineState st6;
   FzStateInit(st6);
   FzBarOut out6;
   FzStateStep(st6,0,MkBar(100.0,100.0,99.0,100.0,1.0,0.0,0.0),true,false,
               slL,tp1L,tp2L,tp3L,80,FZ_SETUP_PULLBACK,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out6);
   FzStateStep(st6,1,MkBar(100.0,105.5,97.5,102.0,1.0,0.0,0.0),false,false,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out6);
   Record("N6",out6.hitTp3 && !out6.hitSl && st6.cntWins==1,
          "TP3 must win over a same-bar SL");

   FzEngineState st7;
   FzStateInit(st7);
   FzBarOut out7;
   FzStateStep(st7,0,MkBar(100.0,100.0,99.0,100.0,1.0,0.0,0.0),true,false,
               slL,tp1L,tp2L,tp3L,80,FZ_SETUP_PULLBACK,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out7);
   FzStateStep(st7,1,MkBar(100.0,101.5,97.5,99.0,1.0,0.0,0.0),false,false,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out7);
   Record("N7",out7.hitTp1 && out7.hitSl && st7.cntWins==1 && st7.cntLosses==0,
          "TP1 plus SL on one bar counts as a win");

   FzEngineState st8;
   FzStateInit(st8);
   FzBarOut out8;
   FzStateStep(st8,0,MkBar(100.0,200.0,0.0,100.0,1.0,0.0,0.0),true,false,
               slL,tp1L,tp2L,tp3L,80,FZ_SETUP_PULLBACK,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,out8);
   const bool entryBarClean=!out8.hitTp1 && !out8.hitSl && st8.posSide==1;
   FzStateStep(st8,1,MkBar(100.0,100.5,99.5,100.0,1.0,0.0,0.0),false,true,
               EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,EMPTY_VALUE,0,FZ_SETUP_NONE,
               102.0,99.0,98.0,97.0,60,FZ_SETUP_SWEEP,out8);
   Record("N8",entryBarClean && st8.posSide==-1 && st8.cntLongs==1 &&
          st8.cntShorts==1 && st8.cntWins==0 && st8.cntLosses==0,
          StringFormat("side=%d L=%d S=%d W=%d Ls=%d",
                       st8.posSide,st8.cntLongs,st8.cntShorts,
                       st8.cntWins,st8.cntLosses));
  }

//--- O: config hash
void RunO()
  {
   const FzConfig cfg=BaseConfig();
   const string h0=FzConfigHash(cfg);
   FzConfig copy=BaseConfig();
   Record("O1",StringLen(h0)==8 && h0==FzConfigHash(copy),
          StringFormat("h0=%s",h0));

   FzConfig changed=BaseConfig();
   changed.rr2=2.5;
   Record("O2",h0!=FzConfigHash(changed),
          StringFormat("h0=%s h1=%s",h0,FzConfigHash(changed)));
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
               g_pass,g_fail,FZ_CONTRACT_VERSION);
  }
//+------------------------------------------------------------------+
