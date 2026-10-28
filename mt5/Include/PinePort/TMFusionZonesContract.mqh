//+------------------------------------------------------------------+
//|                                     TMFusionZonesContract.mqh    |
//|     MT5 EA & AI Lab - PinePort buffer contract and pure logic    |
//|                                                                  |
//| No file I/O, no account access, no trading functions.            |
//| Contract: docs/indicators/tm-fusion-zones.md                  |
//+------------------------------------------------------------------+
#ifndef TMFUSIONZONES_CONTRACT_MQH
#define TMFUSIONZONES_CONTRACT_MQH

#define FZ_CONTRACT_VERSION  "1.0.0"
#define FZ_PLOT_BUFFERS      10
#define FZ_CONTRACT_BUFFERS  23
#define FZ_TOTAL_BUFFERS     33
#define FZ_ZONE_CAP          64
#define FZ_INF               1e9
#define FZ_HTF_MAX_BARS      5000

enum ENUM_FZ_MA
  {
   FZ_MA_EMA = 0,
   FZ_MA_SMA = 1,
   FZ_MA_HMA = 2
  };

enum ENUM_FZ_SL_MODE
  {
   FZ_SL_ZONE_SWING = 0,
   FZ_SL_ATR        = 1
  };

enum ENUM_FZ_TP_MODE
  {
   FZ_TP_OPPOSING = 0,
   FZ_TP_FIXED_RR = 1
  };

enum ENUM_FZ_ASSET
  {
   FZ_ASSET_AUTO         = 0,
   FZ_ASSET_XAU          = 1,
   FZ_ASSET_BTC          = 2,
   FZ_ASSET_ETH          = 3,
   FZ_ASSET_CRYPTO_OTHER = 4,
   FZ_ASSET_CUSTOM       = 5
  };

enum ENUM_FZ_HTF
  {
   FZ_HTF_H1 = 0,
   FZ_HTF_H4 = 1,
   FZ_HTF_D1 = 2,
   FZ_HTF_W1 = 3
  };

enum ENUM_FZ_SETUP
  {
   FZ_SETUP_NONE     = 0,
   FZ_SETUP_PULLBACK = 1,
   FZ_SETUP_SWEEP    = 2,
   FZ_SETUP_RANGE    = 3
  };

enum ENUM_FZ_BLOCK
  {
   FZ_BLOCK_NONE           = 0,
   FZ_BLOCK_OPPOSING_ZONE  = 1,
   FZ_BLOCK_RR_MIN         = 2,
   FZ_BLOCK_COOLDOWN       = 3,
   FZ_BLOCK_SCORE_MARGIN   = 4,
   FZ_BLOCK_SCORE_NOTRADE  = 5,
   FZ_BLOCK_OPPOSITE_WON   = 6
  };

enum ENUM_FZ_REGIME
  {
   FZ_REGIME_RANGE        = 0,
   FZ_REGIME_TRANSITIONAL = 1,
   FZ_REGIME_TRENDING     = 2
  };

enum ENUM_FZ_BUFFER
  {
   FZ_BUF_SIGNAL_LONG  = 10,
   FZ_BUF_SIGNAL_SHORT = 11,
   FZ_BUF_SCORE_LONG   = 12,
   FZ_BUF_SCORE_SHORT  = 13,
   FZ_BUF_SETUP_LONG   = 14,
   FZ_BUF_SETUP_SHORT  = 15,
   FZ_BUF_ENTRY        = 16,
   FZ_BUF_SL           = 17,
   FZ_BUF_TP1          = 18,
   FZ_BUF_TP2          = 19,
   FZ_BUF_TP3          = 20,
   FZ_BUF_POS_SIDE     = 21,
   FZ_BUF_HIT_TP1      = 22,
   FZ_BUF_HIT_TP2      = 23,
   FZ_BUF_HIT_TP3      = 24,
   FZ_BUF_HIT_SL       = 25,
   FZ_BUF_HTF_EMA      = 26,
   FZ_BUF_ATR          = 27,
   FZ_BUF_REGIME       = 28,
   FZ_BUF_IN_DEMAND    = 29,
   FZ_BUF_IN_SUPPLY    = 30,
   FZ_BUF_BLOCK_LONG   = 31,
   FZ_BUF_BLOCK_SHORT  = 32
  };

struct FzConfig
  {
   ENUM_FZ_ASSET   assetMode;
   double          customVolMult;
   ENUM_FZ_MA      ribbonType;
   int             ribbonFast;
   int             ribbonSlow;
   bool            ribbonFilter;
   int             zonePivotLen;
   double          zoneWidthAtr;
   int             zoneMax;
   int             structPivotLen;
   bool            sweepOn;
   bool            pdOn;
   bool            setupPullback;
   bool            setupSweep;
   bool            setupRange;
   double          pullTol;
   int             sweepConfBars;
   bool            mtfOn;
   ENUM_FZ_HTF     mtfTf;
   int             mtfLen;
   double          wTrend;
   double          wZone;
   double          wStruct;
   double          wCandle;
   double          wMtf;
   int             scrNoTrade;
   int             scoreMargin;
   ENUM_FZ_SL_MODE slMode;
   ENUM_FZ_TP_MODE tpMode;
   double          slAtrMul;
   double          slPadAtr;
   double          slMinAtr;
   double          slMaxAtr;
   double          rr1;
   double          rr2;
   double          rr3;
   double          rrMin;
   bool            obstacleGate;
   int             coolBars;
   int             maxBars;
   //--- Derived at init (not user inputs)
   int             effAsset;
   double          assetVolMult;
  };

struct FzZone
  {
   double top;
   double bot;
   int    side;
   int    touches;
   bool   broken;
   int    startBar;
  };

struct FzEngineState
  {
   FzZone zones[FZ_ZONE_CAP];
   int    zoneCount;

   bool   hasSwH;
   bool   hasSwL;
   bool   hasPrevSwH;
   bool   hasPrevSwL;
   double swH;
   double swL;
   int    swHBar;
   int    swLBar;
   double prevSwH;
   double prevSwL;
   int    msTrend;

   bool   hasDay;
   double curDayH;
   double curDayL;
   bool   hasPdh;
   bool   hasPdl;
   double pdh;
   double pdl;

   bool   hasPrev;
   datetime prevTime;
   double prevOpen;
   double prevHigh;
   double prevLow;
   double prevClose;

   bool   hasPrevMa;
   double prevMaFast;
   double prevMaSlow;
   double prevSpread;

   int    lastBullSweepBar;
   int    lastBearSweepBar;
   int    lastSignalBar;

   int    posSide;
   int    posBar;
   double posEntry;
   double posSl;
   double posTp1;
   double posTp2;
   double posTp3;
   bool   posTp1Hit;
   bool   posTp2Hit;
   bool   posTp3Hit;
   int    posScore;
   int    posSetup;

   int    cntSignals;
   int    cntWins;
   int    cntLosses;
   int    cntLongs;
   int    cntShorts;
  };

struct FzBar
  {
   datetime time;
   double   open;
   double   high;
   double   low;
   double   close;
   double   tickSize;
   double   atr;
   int      regime;
   double   maFast;
   double   maSlow;
   double   htfEma;
   bool     htfValid;
   double   znPh;
   double   znPl;
   bool     znPhValid;
   bool     znPlValid;
   double   msPh;
   double   msPl;
   bool     msPhValid;
   bool     msPlValid;
  };

struct FzBarOut
  {
   bool   signalLong;
   bool   signalShort;
   bool   longSetupDetected;
   bool   shortSetupDetected;
   int    setupLong;
   int    setupShort;
   double scoreLong;
   double scoreShort;
   int    blockLong;
   int    blockShort;

   double slLong;
   double tp1Long;
   double tp2Long;
   double tp3Long;
   double slShort;
   double tp1Short;
   double tp2Short;
   double tp3Short;

   double entry;
   double sl;
   double tp1;
   double tp2;
   double tp3;
   int    posSide;
   bool   hitTp1;
   bool   hitTp2;
   bool   hitTp3;
   bool   hitSl;

   double htfEma;
   bool   htfValid;
   double atr;
   int    regime;
   bool   inDemand;
   bool   inSupply;
   double demandBot;
   double demandTop;
   double supplyTop;
   double supplyBot;

   bool   rbBull;
   bool   rbBear;
   bool   rbStrongBull;
   bool   rbStrongBear;
   bool   rbExpanding;
   bool   priceInRibbon;
   double rbTop;
   double rbBot;

   bool   bosBull;
   bool   bosBear;
   bool   chochBull;
   bool   chochBear;
   bool   swpBull;
   bool   swpBear;

   bool   candleBull;
   bool   candleBear;
   bool   pinBull;
   bool   pinBear;
   bool   engulfBull;
   bool   engulfBear;
   bool   momBull;
   bool   momBear;

   bool   htfBull;
   bool   htfBear;
   bool   coolOk;

   int    cntSignals;
   int    cntWins;
   int    cntLosses;
  };

bool FzIsNa(const double value)
  {
   return(value==EMPTY_VALUE || value==-EMPTY_VALUE || !MathIsValidNumber(value));
  }

double FzClamp(const double value,const double low,const double high)
  {
   if(FzIsNa(value))
      return(EMPTY_VALUE);
   return(MathMax(low,MathMin(high,value)));
  }

bool FzClampBool(const bool value)
  {
   return(value);
  }

int FzClampInt(const int value,const int low,const int high)
  {
   return((int)MathMax((double)low,MathMin((double)high,(double)value)));
  }

ENUM_TIMEFRAMES FzHtfPeriod(const int htf)
  {
   switch(htf)
     {
      case FZ_HTF_H1: return(PERIOD_H1);
      case FZ_HTF_D1: return(PERIOD_D1);
      case FZ_HTF_W1: return(PERIOD_W1);
     }
   return(PERIOD_H4);
  }

ENUM_TIMEFRAMES FzHtfPeriodEnum(const ENUM_FZ_HTF htf)
  {
   return(FzHtfPeriod((int)htf));
  }

int FzResolveAsset(const int mode,const string symbol)
  {
   if(mode!=FZ_ASSET_AUTO)
      return(mode);
   string sym=symbol;
   StringToUpper(sym);
   if(StringFind(sym,"XAU")>=0 || StringFind(sym,"GOLD")>=0)
      return(FZ_ASSET_XAU);
   if(StringFind(sym,"BTC")>=0)
      return(FZ_ASSET_BTC);
   if(StringFind(sym,"ETH")>=0)
      return(FZ_ASSET_ETH);
   return(FZ_ASSET_CUSTOM);
  }

double FzAssetVolMult(const int effAsset,const double customMult)
  {
   switch(effAsset)
     {
      case FZ_ASSET_XAU:          return(1.10);
      case FZ_ASSET_BTC:          return(1.25);
      case FZ_ASSET_ETH:          return(1.20);
      case FZ_ASSET_CRYPTO_OTHER: return(1.35);
      case FZ_ASSET_CUSTOM:       return(customMult);
     }
   return(1.0);
  }

double FzAtrSafe(const double atr,const double tickSize)
  {
   if(FzIsNa(atr))
      return(EMPTY_VALUE);
   const double floorPx=(tickSize>0.0 ? tickSize*2.0 : 0.0);
   return(MathMax(atr,floorPx));
  }

void FzNormalizeConfig(FzConfig &cfg)
  {
   cfg.customVolMult=FzClamp(cfg.customVolMult,0.5,3.0);
   cfg.ribbonFast=FzClampInt(cfg.ribbonFast,2,200);
   cfg.ribbonSlow=FzClampInt(cfg.ribbonSlow,5,500);
   cfg.zonePivotLen=FzClampInt(cfg.zonePivotLen,2,50);
   cfg.zoneWidthAtr=MathMax(0.1,cfg.zoneWidthAtr);
   cfg.zoneMax=FzClampInt(cfg.zoneMax,2,30);
   cfg.structPivotLen=FzClampInt(cfg.structPivotLen,2,20);
   cfg.pullTol=MathMax(0.1,cfg.pullTol);
   cfg.sweepConfBars=FzClampInt(cfg.sweepConfBars,1,10);
   cfg.mtfLen=FzClampInt(cfg.mtfLen,10,500);
   cfg.wTrend=MathMax(0.0,cfg.wTrend);
   cfg.wZone=MathMax(0.0,cfg.wZone);
   cfg.wStruct=MathMax(0.0,cfg.wStruct);
   cfg.wCandle=MathMax(0.0,cfg.wCandle);
   cfg.wMtf=MathMax(0.0,cfg.wMtf);
   cfg.scrNoTrade=FzClampInt(cfg.scrNoTrade,0,99);
   cfg.scoreMargin=FzClampInt(cfg.scoreMargin,0,50);
   cfg.slAtrMul=MathMax(0.5,cfg.slAtrMul);
   cfg.slPadAtr=MathMax(0.05,cfg.slPadAtr);
   cfg.slMinAtr=MathMax(0.2,cfg.slMinAtr);
   cfg.slMaxAtr=MathMax(1.0,cfg.slMaxAtr);
   cfg.rr1=MathMax(0.5,cfg.rr1);
   cfg.rr2=MathMax(1.0,cfg.rr2);
   cfg.rr3=MathMax(1.5,cfg.rr3);
   cfg.rrMin=MathMax(0.5,cfg.rrMin);
   cfg.coolBars=MathMax(0,cfg.coolBars);
   cfg.maxBars=MathMax(0,cfg.maxBars);
  }

string FzSetupName(const int setup)
  {
   switch(setup)
     {
      case FZ_SETUP_PULLBACK: return("PULLBACK");
      case FZ_SETUP_SWEEP:    return("SWEEP");
      case FZ_SETUP_RANGE:    return("RANGE");
     }
   return("NONE");
  }

string FzBlockName(const int block)
  {
   switch(block)
     {
      case FZ_BLOCK_OPPOSING_ZONE: return("OPPOSING_ZONE");
      case FZ_BLOCK_RR_MIN:        return("RR_MIN");
      case FZ_BLOCK_COOLDOWN:      return("COOLDOWN");
      case FZ_BLOCK_SCORE_MARGIN:  return("SCORE_MARGIN");
      case FZ_BLOCK_SCORE_NOTRADE: return("SCORE_NOTRADE");
      case FZ_BLOCK_OPPOSITE_WON:  return("OPPOSITE_WON");
     }
   return("NONE");
  }

string FzRegimeName(const int regime)
  {
   switch(regime)
     {
      case FZ_REGIME_RANGE:        return("RANGE");
      case FZ_REGIME_TRENDING:     return("TRENDING");
     }
   return("TRANSITIONAL");
  }

double FzSmaAt(const double &src[],const int total,const int end,const int len)
  {
   if(len<=0 || end<len-1 || end>=total)
      return(EMPTY_VALUE);
   double sum=0.0;
   for(int i=end-len+1; i<=end; i++)
     {
      if(FzIsNa(src[i]))
         return(EMPTY_VALUE);
      sum+=src[i];
     }
   return(sum/(double)len);
  }

double FzWmaAt(const double &src[],const int total,const int end,const int len)
  {
   if(len<=0 || end<len-1 || end>=total)
      return(EMPTY_VALUE);
   double sum=0.0;
   double wsum=0.0;
   for(int i=0; i<len; i++)
     {
      const double v=src[end-len+1+i];
      if(FzIsNa(v))
         return(EMPTY_VALUE);
      sum+=v;
      wsum+=v*(double)(i+1);
     }
   const double denom=(double)len*((double)len+1.0)*0.5;
   if(denom<=0.0)
      return(EMPTY_VALUE);
   return(wsum/denom);
  }

double FzEmaStep(const double prev,const double src,const int len)
  {
   if(len<=1)
      return(src);
   const double alpha=2.0/((double)len+1.0);
   return(alpha*src+(1.0-alpha)*prev);
  }

double FzEmaAt(const double &src[],const int total,const int end,const int len)
  {
   if(len<=0 || end<len-1 || end>=total)
      return(EMPTY_VALUE);
   double value=FzSmaAt(src,total,len-1,len);
   if(FzIsNa(value))
      return(EMPTY_VALUE);
   for(int i=len; i<=end; i++)
     {
      if(FzIsNa(src[i]))
         return(EMPTY_VALUE);
      value=FzEmaStep(value,src[i],len);
     }
   return(value);
  }

void FzBuildWmaSeries(const double &src[],const int total,const int len,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   for(int j=0; j<total; j++)
      out[j]=FzWmaAt(src,total,j,len);
  }

void FzBuildMaSeries(const double &src[],const int total,const int len,
                     const int maType,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(len<=0)
      return;
   if(maType==FZ_MA_SMA)
     {
      for(int j=0; j<total; j++)
         out[j]=FzSmaAt(src,total,j,len);
      return;
     }
   if(maType==FZ_MA_EMA)
     {
      double value=EMPTY_VALUE;
      for(int j=0; j<total; j++)
        {
         if(j<len-1)
            continue;
         if(j==len-1)
           {
            value=FzSmaAt(src,total,j,len);
           }
         else
           {
            if(FzIsNa(value) || FzIsNa(src[j]))
               value=EMPTY_VALUE;
            else
               value=FzEmaStep(value,src[j],len);
           }
         out[j]=value;
        }
      return;
     }
   int half=len/2;
   if(half<1)
      half=1;
   int w=(int)MathRound(MathSqrt((double)len));
   if(w<1)
      w=1;
   double halfArr[];
   double fullArr[];
   double combo[];
   FzBuildWmaSeries(src,total,half,halfArr);
   FzBuildWmaSeries(src,total,len,fullArr);
   ArrayResize(combo,total);
   ArrayInitialize(combo,EMPTY_VALUE);
   for(int j=0; j<total; j++)
     {
      if(!FzIsNa(halfArr[j]) && !FzIsNa(fullArr[j]))
         combo[j]=2.0*halfArr[j]-fullArr[j];
     }
   for(int j=0; j<total; j++)
      out[j]=FzWmaAt(combo,total,j,w);
  }

double FzMaAt(const double &src[],const int total,const int end,
              const int len,const int maType)
  {
   if(maType==FZ_MA_SMA)
      return(FzSmaAt(src,total,end,len));
   if(maType==FZ_MA_HMA)
     {
      double out[];
      FzBuildMaSeries(src,total,len,FZ_MA_HMA,out);
      if(end<0 || end>=total)
         return(EMPTY_VALUE);
      return(out[end]);
     }
   return(FzEmaAt(src,total,end,len));
  }

bool FzPivotHighAt(const double &high[],const int total,const int bar,
                   const int len,double &out)
  {
   out=EMPTY_VALUE;
   if(len<1 || bar<len || bar>=total)
      return(false);
   const int center=bar-len;
   if(center-len<0)
      return(false);
   const double value=high[center];
   for(int k=1; k<=len; k++)
     {
      if(high[center-k]>=value)
         return(false);
      if(high[center+k]>=value)
         return(false);
     }
   out=value;
   return(true);
  }

bool FzPivotLowAt(const double &low[],const int total,const int bar,
                  const int len,double &out)
  {
   out=EMPTY_VALUE;
   if(len<1 || bar<len || bar>=total)
      return(false);
   const int center=bar-len;
   if(center-len<0)
      return(false);
   const double value=low[center];
   for(int k=1; k<=len; k++)
     {
      if(low[center-k]<=value)
         return(false);
      if(low[center+k]<=value)
         return(false);
     }
   out=value;
   return(true);
  }

double FzTr(const bool hasPrev,const double high,const double low,const double prevClose)
  {
   const double range=high-low;
   if(!hasPrev)
      return(range);
   return(MathMax(range,MathMax(MathAbs(high-prevClose),MathAbs(low-prevClose))));
  }

void FzBuildRmaSeries(const double &src[],const int total,const int len,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(len<=0 || total<=0)
      return;
   for(int j=len-1; j<total; j++)
     {
      if(j==len-1)
        {
         out[j]=FzSmaAt(src,total,j,len);
         continue;
        }
      if(FzIsNa(out[j-1]) || FzIsNa(src[j]))
         continue;
      out[j]=(((double)(len-1))*out[j-1]+src[j])/(double)len;
     }
  }

void FzBuildAtrSeries(const double &high[],const double &low[],const double &close[],
                      const int total,const int len,double &out[])
  {
   if(total<=0)
     {
      ArrayResize(out,0);
      return;
     }
   double tr[];
   ArrayResize(tr,total);
   for(int j=0; j<total; j++)
      tr[j]=FzTr(j>0,high[j],low[j],(j>0 ? close[j-1] : close[j]));
   FzBuildRmaSeries(tr,total,len,out);
  }

void FzBuildAdxSeries(const double &high[],const double &low[],const double &close[],
                      const int total,const int len,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0 || len<=1)
      return;
   double tr[],dmPos[],dmNeg[];
   ArrayResize(tr,total);
   ArrayResize(dmPos,total);
   ArrayResize(dmNeg,total);
   for(int j=0; j<total; j++)
     {
      tr[j]=FzTr(j>0,high[j],low[j],(j>0 ? close[j-1] : close[j]));
      double pos=0.0;
      double neg=0.0;
      if(j>0)
        {
         const double chgHigh=high[j]-high[j-1];
         const double chgLow=low[j]-low[j-1];
         const double down=-chgLow;
         if(chgHigh>0.0 && chgHigh>down)
            pos=MathMax(chgHigh,0.0);
         if(down>0.0 && down>chgHigh)
            neg=MathMax(down,0.0);
        }
      dmPos[j]=pos;
      dmNeg[j]=neg;
     }
   double trSm[],rmaPos[],rmaNeg[];
   FzBuildRmaSeries(tr,total,len,trSm);
   FzBuildRmaSeries(dmPos,total,len,rmaPos);
   FzBuildRmaSeries(dmNeg,total,len,rmaNeg);
   double dx[];
   ArrayResize(dx,total);
   ArrayInitialize(dx,EMPTY_VALUE);
   for(int j=0; j<total; j++)
     {
      if(FzIsNa(trSm[j]) || FzIsNa(rmaPos[j]) || FzIsNa(rmaNeg[j]))
         continue;
      double diPos=0.0;
      double diNeg=0.0;
      if(trSm[j]>0.0)
        {
         diPos=100.0*rmaPos[j]/trSm[j];
         diNeg=100.0*rmaNeg[j]/trSm[j];
        }
      const double sum=diPos+diNeg;
      dx[j]=(sum>0.0 ? 100.0*MathAbs(diPos-diNeg)/sum : 0.0);
     }
   FzBuildRmaSeries(dx,total,len,out);
  }

void FzBuildChopSeries(const double &high[],const double &low[],const double &close[],
                       const int total,const int len,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,50.0);
   if(total<=0 || len<=1)
      return;
   double tr[];
   ArrayResize(tr,total);
   for(int j=0; j<total; j++)
      tr[j]=FzTr(j>0,high[j],low[j],(j>0 ? close[j-1] : close[j]));
   const double logLen=MathLog10((double)len);
   for(int j=len-1; j<total; j++)
     {
      double sumTr=0.0;
      double maxHi=high[j-len+1];
      double minLo=low[j-len+1];
      for(int i=j-len+1; i<=j; i++)
        {
         sumTr+=tr[i];
         if(high[i]>maxHi)
            maxHi=high[i];
         if(low[i]<minLo)
            minLo=low[i];
        }
      const double diff=maxHi-minLo;
      out[j]=50.0;
      if(diff>0.0 && sumTr>0.0 && logLen>0.0)
         out[j]=100.0*(MathLog10(sumTr/diff)/logLen);
     }
  }

int FzMapHtfIndex(const datetime &htfCloseTime[],const int count,const datetime chartCloseTime)
  {
   int found=-1;
   for(int k=0; k<count; k++)
     {
      if(htfCloseTime[k]<=chartCloseTime)
         found=k;
      else
         break;
     }
   return(found);
  }

int FzRegime(const double adx,const double chop)
  {
   const bool adxOk=!FzIsNa(adx);
   if(adxOk && adx>=23.0 && chop<=56.0)
      return(FZ_REGIME_TRENDING);
   if(chop>=58.0 || (adxOk && adx<18.0))
      return(FZ_REGIME_RANGE);
   return(FZ_REGIME_TRANSITIONAL);
  }

bool FzIsNewServerDay(const datetime prevTime,const datetime curTime)
  {
   MqlDateTime prevDt;
   MqlDateTime curDt;
   TimeToStruct(prevTime,prevDt);
   TimeToStruct(curTime,curDt);
   return(prevDt.year!=curDt.year || prevDt.day_of_year!=curDt.day_of_year);
  }

bool FzIsNewDayForBar(const datetime prevTime,const datetime curTime,const bool hasPrev)
  {
   if(!hasPrev)
      return(false);
   return(FzIsNewServerDay(prevTime,curTime));
  }

void FzZoneRegister(FzEngineState &st,const int side,const double pivot,
                    const double atr,const double widthAtr,
                    const double halfWidth,const int startBar)
  {
   for(int i=0; i<st.zoneCount; i++)
     {
      if(st.zones[i].broken || st.zones[i].side!=side)
         continue;
      const double mid=(st.zones[i].top+st.zones[i].bot)*0.5;
      if(MathAbs(mid-pivot)<=(atr*widthAtr))
        {
         st.zones[i].top=MathMax(st.zones[i].top,pivot+halfWidth);
         st.zones[i].bot=MathMin(st.zones[i].bot,pivot-halfWidth);
         st.zones[i].touches+=1;
         return;
        }
     }
   if(st.zoneCount>=FZ_ZONE_CAP)
      return;
   st.zones[st.zoneCount].top=pivot+halfWidth;
   st.zones[st.zoneCount].bot=pivot-halfWidth;
   st.zones[st.zoneCount].side=side;
   st.zones[st.zoneCount].touches=1;
   st.zones[st.zoneCount].broken=false;
   st.zones[st.zoneCount].startBar=startBar;
   st.zoneCount+=1;
  }

void FzZoneUpdate(FzEngineState &st,const double high,const double low,
                  const double close,const double prevHigh,const double prevLow,
                  const bool hasPrev)
  {
   for(int i=0; i<st.zoneCount; i++)
     {
      if(st.zones[i].broken)
         continue;
      if(st.zones[i].side==1)
        {
         if(close<st.zones[i].bot)
           {
            st.zones[i].broken=true;
           }
         else if(low<=st.zones[i].top && high>=st.zones[i].bot)
           {
            if(hasPrev && prevLow>st.zones[i].top)
               st.zones[i].touches+=1;
           }
        }
      else
        {
         if(close>st.zones[i].top)
           {
            st.zones[i].broken=true;
           }
         else if(high>=st.zones[i].bot && low<=st.zones[i].top)
           {
            if(hasPrev && prevHigh<st.zones[i].bot)
               st.zones[i].touches+=1;
           }
        }
     }
  }

void FzZoneCleanup(FzEngineState &st,const int maxZones)
  {
   int write=0;
   for(int i=0; i<st.zoneCount; i++)
     {
      if(!st.zones[i].broken)
        {
         if(write!=i)
            st.zones[write]=st.zones[i];
         write+=1;
        }
     }
   st.zoneCount=write;
   while(st.zoneCount>maxZones && st.zoneCount>0)
     {
      for(int i=1; i<st.zoneCount; i++)
         st.zones[i-1]=st.zones[i];
      st.zoneCount-=1;
     }
  }

void FzZoneInteract(const FzEngineState &st,const double high,const double low,
                    const double atr,bool &inDemand,bool &inSupply,
                    double &demandBot,double &demandTop,
                    double &supplyTop,double &supplyBot)
  {
   inDemand=false;
   inSupply=false;
   demandBot=EMPTY_VALUE;
   demandTop=EMPTY_VALUE;
   supplyTop=EMPTY_VALUE;
   supplyBot=EMPTY_VALUE;
   if(FzIsNa(atr) || atr<=0.0)
      return;
   for(int i=0; i<st.zoneCount; i++)
     {
      if(st.zones[i].broken)
         continue;
      if(st.zones[i].side==1)
        {
         if(low<=st.zones[i].top+atr*0.2 && high>=st.zones[i].bot-atr*0.2)
           {
            inDemand=true;
            demandBot=st.zones[i].bot;
            demandTop=st.zones[i].top;
           }
        }
      else
        {
         if(high>=st.zones[i].bot-atr*0.2 && low<=st.zones[i].top+atr*0.2)
           {
            inSupply=true;
            supplyTop=st.zones[i].top;
            supplyBot=st.zones[i].bot;
           }
        }
     }
  }

bool FzNearestOpposingLevel(const FzEngineState &st,const bool isLong,
                            const double close,double &level,double &dist)
  {
   double best=FZ_INF;
   double found=EMPTY_VALUE;
   bool has=false;
   for(int i=0; i<st.zoneCount; i++)
     {
      if(st.zones[i].broken)
         continue;
      if(isLong && st.zones[i].side==-1 && st.zones[i].bot>close)
        {
         const double d=st.zones[i].bot-close;
         if(d<best)
           {
            best=d;
            found=st.zones[i].bot;
            has=true;
           }
        }
      else if(!isLong && st.zones[i].side==1 && st.zones[i].top<close)
        {
         const double d=close-st.zones[i].top;
         if(d<best)
           {
            best=d;
            found=st.zones[i].top;
            has=true;
           }
        }
     }
   level=found;
   dist=(has ? best : FZ_INF);
   return(has);
  }

double FzScoreLong(const FzConfig &cfg,const bool strongBull,const bool bull,
                   const bool inDemand,const bool priceInRibbon,const bool chochBull,
                   const bool swpBull,const bool bosBull,const bool engulfOrPin,
                   const bool candleBull,const bool htfBull)
  {
   const double trendFact=strongBull ? 1.0 : (bull ? 0.75 : 0.0);
   const double zoneFact=inDemand ? 1.0 : (priceInRibbon ? 0.70 : 0.0);
   const double structFact=chochBull ? 1.0 : (swpBull ? 0.90 : (bosBull ? 0.75 : 0.0));
   const double candleFact=engulfOrPin ? 1.0 : (candleBull ? 0.70 : 0.0);
   const double mtfFact=htfBull ? 1.0 : 0.0;
   const double sumW=cfg.wTrend+cfg.wZone+cfg.wStruct+cfg.wCandle+cfg.wMtf;
   if(sumW<=0.0)
      return(0.0);
   const double raw=trendFact*cfg.wTrend+zoneFact*cfg.wZone+structFact*cfg.wStruct
                    +candleFact*cfg.wCandle+mtfFact*cfg.wMtf;
   return(MathRound((raw/sumW)*100.0));
  }

double FzScoreShort(const FzConfig &cfg,const bool strongBear,const bool bear,
                    const bool inSupply,const bool priceInRibbon,const bool chochBear,
                    const bool swpBear,const bool bosBear,const bool engulfOrPin,
                    const bool candleBear,const bool htfBear)
  {
   const double trendFact=strongBear ? 1.0 : (bear ? 0.75 : 0.0);
   const double zoneFact=inSupply ? 1.0 : (priceInRibbon ? 0.70 : 0.0);
   const double structFact=chochBear ? 1.0 : (swpBear ? 0.90 : (bosBear ? 0.75 : 0.0));
   const double candleFact=engulfOrPin ? 1.0 : (candleBear ? 0.70 : 0.0);
   const double mtfFact=htfBear ? 1.0 : 0.0;
   const double sumW=cfg.wTrend+cfg.wZone+cfg.wStruct+cfg.wCandle+cfg.wMtf;
   if(sumW<=0.0)
      return(0.0);
   const double raw=trendFact*cfg.wTrend+zoneFact*cfg.wZone+structFact*cfg.wStruct
                    +candleFact*cfg.wCandle+mtfFact*cfg.wMtf;
   return(MathRound((raw/sumW)*100.0));
  }

bool FzRiskLong(const FzConfig &cfg,const double closePrice,const double atr,
                const double assetMult,const bool hasDemand,const double demandBot,
                const bool hasSwing,const double swL,const bool hasOpp,
                const double oppLevel,double &sl,double &tp1,double &tp2,
                double &tp3,double &riskDist)
  {
   sl=EMPTY_VALUE;
   tp1=EMPTY_VALUE;
   tp2=EMPTY_VALUE;
   tp3=EMPTY_VALUE;
   riskDist=EMPTY_VALUE;
   if(FzIsNa(atr) || atr<=0.0)
      return(false);
   double rawSl;
   if(hasDemand && !FzIsNa(demandBot))
      rawSl=demandBot;
   else if(hasSwing && !FzIsNa(swL))
      rawSl=swL;
   else
      rawSl=closePrice-cfg.slAtrMul*atr;
   if(cfg.slMode==FZ_SL_ZONE_SWING)
      sl=rawSl-cfg.slPadAtr*atr*assetMult;
   else
      sl=closePrice-cfg.slAtrMul*atr*assetMult;
   const double rd=FzClamp(closePrice-sl,cfg.slMinAtr*atr,cfg.slMaxAtr*atr);
   if(FzIsNa(rd))
      return(false);
   sl=closePrice-rd;
   riskDist=rd;
   tp1=closePrice+rd*cfg.rr1;
   tp2=closePrice+rd*cfg.rr2;
   tp3=closePrice+rd*cfg.rr3;
   if(cfg.tpMode==FZ_TP_OPPOSING && hasOpp && !FzIsNa(oppLevel)
      && oppLevel>(closePrice+rd*0.8))
     {
      tp1=MathMin(closePrice+rd*cfg.rr1,oppLevel);
      tp2=oppLevel;
      tp3=oppLevel+rd;
     }
   return(true);
  }

bool FzRiskShort(const FzConfig &cfg,const double closePrice,const double atr,
                 const double assetMult,const bool hasSupply,const double supplyTop,
                 const bool hasSwing,const double swH,const bool hasOpp,
                 const double oppLevel,double &sl,double &tp1,double &tp2,
                 double &tp3,double &riskDist)
  {
   sl=EMPTY_VALUE;
   tp1=EMPTY_VALUE;
   tp2=EMPTY_VALUE;
   tp3=EMPTY_VALUE;
   riskDist=EMPTY_VALUE;
   if(FzIsNa(atr) || atr<=0.0)
      return(false);
   double rawSl;
   if(hasSupply && !FzIsNa(supplyTop))
      rawSl=supplyTop;
   else if(hasSwing && !FzIsNa(swH))
      rawSl=swH;
   else
      rawSl=closePrice+cfg.slAtrMul*atr;
   if(cfg.slMode==FZ_SL_ZONE_SWING)
      sl=rawSl+cfg.slPadAtr*atr*assetMult;
   else
      sl=closePrice+cfg.slAtrMul*atr*assetMult;
   const double rd=FzClamp(sl-closePrice,cfg.slMinAtr*atr,cfg.slMaxAtr*atr);
   if(FzIsNa(rd))
      return(false);
   sl=closePrice+rd;
   riskDist=rd;
   tp1=closePrice-rd*cfg.rr1;
   tp2=closePrice-rd*cfg.rr2;
   tp3=closePrice-rd*cfg.rr3;
   if(cfg.tpMode==FZ_TP_OPPOSING && hasOpp && !FzIsNa(oppLevel)
      && oppLevel<(closePrice-rd*0.8))
     {
      tp1=MathMax(closePrice-rd*cfg.rr1,oppLevel);
      tp2=oppLevel;
      tp3=oppLevel-rd;
     }
   return(true);
  }

void FzGates(const FzConfig &cfg,const double closePrice,
             const double tp1Long,const double tp1Short,
             const bool hasSupply,const double distSupply,
             const bool hasDemand,const double distDemand,
             const bool longSetup,const bool shortSetup,
             const double longScore,const double shortScore,
             const bool coolOk,int &blockLong,int &blockShort)
  {
   blockLong=FZ_BLOCK_NONE;
   blockShort=FZ_BLOCK_NONE;
   if(cfg.obstacleGate)
     {
      if(hasSupply && !FzIsNa(tp1Long) && distSupply<(tp1Long-closePrice)*0.92)
         blockLong=FZ_BLOCK_OPPOSING_ZONE;
      if(hasDemand && !FzIsNa(tp1Short) && distDemand<(closePrice-tp1Short)*0.92)
         blockShort=FZ_BLOCK_OPPOSING_ZONE;
     }
   if(cfg.rr2<cfg.rrMin)
     {
      if(blockLong==FZ_BLOCK_NONE)
         blockLong=FZ_BLOCK_RR_MIN;
      if(blockShort==FZ_BLOCK_NONE)
         blockShort=FZ_BLOCK_RR_MIN;
     }
   if(!coolOk)
     {
      if(blockLong==FZ_BLOCK_NONE)
         blockLong=FZ_BLOCK_COOLDOWN;
      if(blockShort==FZ_BLOCK_NONE)
         blockShort=FZ_BLOCK_COOLDOWN;
     }
   if(longSetup && shortSetup)
     {
      if(MathAbs(longScore-shortScore)<(double)cfg.scoreMargin)
        {
         if(blockLong==FZ_BLOCK_NONE)
            blockLong=FZ_BLOCK_SCORE_MARGIN;
         if(blockShort==FZ_BLOCK_NONE)
            blockShort=FZ_BLOCK_SCORE_MARGIN;
        }
     }
   if(longScore<=(double)cfg.scrNoTrade && blockLong==FZ_BLOCK_NONE)
      blockLong=FZ_BLOCK_SCORE_NOTRADE;
   if(shortScore<=(double)cfg.scrNoTrade && blockShort==FZ_BLOCK_NONE)
      blockShort=FZ_BLOCK_SCORE_NOTRADE;
  }

void FzEligibility(const FzConfig &cfg,const bool isConfirmed,
                   const bool longSetup,const bool shortSetup,
                   const double longScore,const double shortScore,
                   int &blockLong,int &blockShort,
                   bool &sigLong,bool &sigShort)
  {
   sigLong=(longSetup && longScore>(double)cfg.scrNoTrade
            && blockLong==FZ_BLOCK_NONE && isConfirmed);
   sigShort=(shortSetup && shortScore>(double)cfg.scrNoTrade
             && blockShort==FZ_BLOCK_NONE && isConfirmed);
   if(sigLong && sigShort)
     {
      if(longScore>=shortScore)
        {
         sigShort=false;
         blockShort=FZ_BLOCK_OPPOSITE_WON;
        }
      else
        {
         sigLong=false;
         blockLong=FZ_BLOCK_OPPOSITE_WON;
        }
     }
  }

void FzStateInit(FzEngineState &st)
  {
   st.zoneCount=0;
   st.hasSwH=false;
   st.hasSwL=false;
   st.hasPrevSwH=false;
   st.hasPrevSwL=false;
   st.swH=EMPTY_VALUE;
   st.swL=EMPTY_VALUE;
   st.swHBar=0;
   st.swLBar=0;
   st.prevSwH=EMPTY_VALUE;
   st.prevSwL=EMPTY_VALUE;
   st.msTrend=0;
   st.hasDay=false;
   st.curDayH=EMPTY_VALUE;
   st.curDayL=EMPTY_VALUE;
   st.hasPdh=false;
   st.hasPdl=false;
   st.pdh=EMPTY_VALUE;
   st.pdl=EMPTY_VALUE;
   st.hasPrev=false;
   st.prevTime=0;
   st.prevOpen=EMPTY_VALUE;
   st.prevHigh=EMPTY_VALUE;
   st.prevLow=EMPTY_VALUE;
   st.prevClose=EMPTY_VALUE;
   st.hasPrevMa=false;
   st.prevMaFast=EMPTY_VALUE;
   st.prevMaSlow=EMPTY_VALUE;
   st.prevSpread=EMPTY_VALUE;
   st.lastBullSweepBar=-1;
   st.lastBearSweepBar=-1;
   st.lastSignalBar=-999;
   st.posSide=0;
   st.posBar=0;
   st.posEntry=EMPTY_VALUE;
   st.posSl=EMPTY_VALUE;
   st.posTp1=EMPTY_VALUE;
   st.posTp2=EMPTY_VALUE;
   st.posTp3=EMPTY_VALUE;
   st.posTp1Hit=false;
   st.posTp2Hit=false;
   st.posTp3Hit=false;
   st.posScore=0;
   st.posSetup=FZ_SETUP_NONE;
   st.cntSignals=0;
   st.cntWins=0;
   st.cntLosses=0;
   st.cntLongs=0;
   st.cntShorts=0;
  }

void FzBarOutReset(FzBarOut &out)
  {
   out.signalLong=false;
   out.signalShort=false;
   out.longSetupDetected=false;
   out.shortSetupDetected=false;
   out.setupLong=FZ_SETUP_NONE;
   out.setupShort=FZ_SETUP_NONE;
   out.scoreLong=0.0;
   out.scoreShort=0.0;
   out.blockLong=FZ_BLOCK_NONE;
   out.blockShort=FZ_BLOCK_NONE;
   out.slLong=EMPTY_VALUE;
   out.tp1Long=EMPTY_VALUE;
   out.tp2Long=EMPTY_VALUE;
   out.tp3Long=EMPTY_VALUE;
   out.slShort=EMPTY_VALUE;
   out.tp1Short=EMPTY_VALUE;
   out.tp2Short=EMPTY_VALUE;
   out.tp3Short=EMPTY_VALUE;
   out.entry=EMPTY_VALUE;
   out.sl=EMPTY_VALUE;
   out.tp1=EMPTY_VALUE;
   out.tp2=EMPTY_VALUE;
   out.tp3=EMPTY_VALUE;
   out.posSide=0;
   out.hitTp1=false;
   out.hitTp2=false;
   out.hitTp3=false;
   out.hitSl=false;
   out.htfEma=EMPTY_VALUE;
   out.htfValid=false;
   out.atr=EMPTY_VALUE;
   out.regime=FZ_REGIME_TRANSITIONAL;
   out.inDemand=false;
   out.inSupply=false;
   out.demandBot=EMPTY_VALUE;
   out.demandTop=EMPTY_VALUE;
   out.supplyTop=EMPTY_VALUE;
   out.supplyBot=EMPTY_VALUE;
   out.rbBull=false;
   out.rbBear=false;
   out.rbStrongBull=false;
   out.rbStrongBear=false;
   out.rbExpanding=false;
   out.priceInRibbon=false;
   out.rbTop=EMPTY_VALUE;
   out.rbBot=EMPTY_VALUE;
   out.bosBull=false;
   out.bosBear=false;
   out.chochBull=false;
   out.chochBear=false;
   out.swpBull=false;
   out.swpBear=false;
   out.candleBull=false;
   out.candleBear=false;
   out.pinBull=false;
   out.pinBear=false;
   out.engulfBull=false;
   out.engulfBear=false;
   out.momBull=false;
   out.momBear=false;
   out.htfBull=false;
   out.htfBear=false;
   out.coolOk=false;
   out.cntSignals=0;
   out.cntWins=0;
   out.cntLosses=0;
  }

void FzStateStep(FzEngineState &st,const int barIndex,const FzBar &bar,
                 const bool sigLong,const bool sigShort,
                 const double slL,const double tp1L,const double tp2L,const double tp3L,
                 const int scoreL,const int setupL,
                 const double slS,const double tp1S,const double tp2S,const double tp3S,
                 const int scoreS,const int setupS,
                 FzBarOut &out)
  {
   out.hitTp1=false;
   out.hitTp2=false;
   out.hitTp3=false;
   out.hitSl=false;

   if(st.posSide==1)
     {
      if(!st.posTp1Hit && !FzIsNa(st.posTp1) && bar.high>=st.posTp1)
        {
         st.posTp1Hit=true;
         out.hitTp1=true;
        }
      if(!st.posTp2Hit && !FzIsNa(st.posTp2) && bar.high>=st.posTp2)
        {
         st.posTp2Hit=true;
         out.hitTp2=true;
        }
      if(!st.posTp3Hit && !FzIsNa(st.posTp3) && bar.high>=st.posTp3)
        {
         st.posTp3Hit=true;
         out.hitTp3=true;
         st.posSide=0;
         st.cntWins+=1;
        }
      if(!FzIsNa(st.posSl) && bar.low<=st.posSl && st.posSide!=0)
        {
         out.hitSl=true;
         st.posSide=0;
         if(st.posTp1Hit)
            st.cntWins+=1;
         else
            st.cntLosses+=1;
        }
     }
   else if(st.posSide==-1)
     {
      if(!st.posTp1Hit && !FzIsNa(st.posTp1) && bar.low<=st.posTp1)
        {
         st.posTp1Hit=true;
         out.hitTp1=true;
        }
      if(!st.posTp2Hit && !FzIsNa(st.posTp2) && bar.low<=st.posTp2)
        {
         st.posTp2Hit=true;
         out.hitTp2=true;
        }
      if(!st.posTp3Hit && !FzIsNa(st.posTp3) && bar.low<=st.posTp3)
        {
         st.posTp3Hit=true;
         out.hitTp3=true;
         st.posSide=0;
         st.cntWins+=1;
        }
      if(!FzIsNa(st.posSl) && bar.high>=st.posSl && st.posSide!=0)
        {
         out.hitSl=true;
         st.posSide=0;
         if(st.posTp1Hit)
            st.cntWins+=1;
         else
            st.cntLosses+=1;
        }
     }

   if(sigLong)
     {
      st.posSide=1;
      st.posBar=barIndex;
      st.posEntry=bar.close;
      st.posSl=slL;
      st.posTp1=tp1L;
      st.posTp2=tp2L;
      st.posTp3=tp3L;
      st.posTp1Hit=false;
      st.posTp2Hit=false;
      st.posTp3Hit=false;
      st.posScore=scoreL;
      st.posSetup=setupL;
      st.cntSignals+=1;
      st.cntLongs+=1;
     }
   else if(sigShort)
     {
      st.posSide=-1;
      st.posBar=barIndex;
      st.posEntry=bar.close;
      st.posSl=slS;
      st.posTp1=tp1S;
      st.posTp2=tp2S;
      st.posTp3=tp3S;
      st.posTp1Hit=false;
      st.posTp2Hit=false;
      st.posTp3Hit=false;
      st.posScore=scoreS;
      st.posSetup=setupS;
      st.cntSignals+=1;
      st.cntShorts+=1;
     }

   out.posSide=st.posSide;
   out.entry=st.posEntry;
   out.sl=st.posSl;
   out.tp1=st.posTp1;
   out.tp2=st.posTp2;
   out.tp3=st.posTp3;
   out.cntSignals=st.cntSignals;
   out.cntWins=st.cntWins;
   out.cntLosses=st.cntLosses;
  }

void FzEngineStep(const FzConfig &cfg,FzEngineState &st,const FzBar &bar,
                  const int barIndex,FzBarOut &out)
  {
   FzBarOutReset(out);

   const double atr=bar.atr;
   const bool atrOk=!FzIsNa(atr) && atr>0.0;
   out.atr=atr;
   out.regime=bar.regime;
   out.htfEma=(bar.htfValid ? bar.htfEma : EMPTY_VALUE);
   out.htfValid=bar.htfValid;

   //--- Zones
   if(atrOk && bar.znPhValid)
      FzZoneRegister(st,-1,bar.znPh,atr,cfg.zoneWidthAtr,
                     atr*cfg.zoneWidthAtr*0.5,barIndex-cfg.zonePivotLen);
   if(atrOk && bar.znPlValid)
      FzZoneRegister(st,1,bar.znPl,atr,cfg.zoneWidthAtr,
                     atr*cfg.zoneWidthAtr*0.5,barIndex-cfg.zonePivotLen);
   FzZoneUpdate(st,bar.high,bar.low,bar.close,st.prevHigh,st.prevLow,st.hasPrev);
   FzZoneCleanup(st,cfg.zoneMax);
   FzZoneInteract(st,bar.high,bar.low,atr,out.inDemand,out.inSupply,
                  out.demandBot,out.demandTop,out.supplyTop,out.supplyBot);

   //--- Structure
   if(bar.msPhValid)
     {
      st.prevSwH=st.swH;
      st.hasPrevSwH=st.hasSwH;
      st.swH=bar.msPh;
      st.swHBar=barIndex-cfg.structPivotLen;
      st.hasSwH=true;
     }
   if(bar.msPlValid)
     {
      st.prevSwL=st.swL;
      st.hasPrevSwL=st.hasSwL;
      st.swL=bar.msPl;
      st.swLBar=barIndex-cfg.structPivotLen;
      st.hasSwL=true;
     }

   out.bosBull=(st.hasSwH && st.hasPrev && bar.close>st.swH && st.prevClose<=st.swH);
   out.bosBear=(st.hasSwL && st.hasPrev && bar.close<st.swL && st.prevClose>=st.swL);
   if(out.bosBull)
     {
      if(st.msTrend==-1)
         out.chochBull=true;
      st.msTrend=1;
     }
   if(out.bosBear)
     {
      if(st.msTrend==1)
         out.chochBear=true;
      st.msTrend=-1;
     }

   const bool swpBullSw=(cfg.sweepOn && st.hasSwL && bar.low<st.swL && bar.close>st.swL);
   const bool swpBearSw=(cfg.sweepOn && st.hasSwH && bar.high>st.swH && bar.close<st.swH);

   if(!st.hasDay)
     {
      st.curDayH=bar.high;
      st.curDayL=bar.low;
      st.hasDay=true;
     }
   else if(FzIsNewDayForBar(st.prevTime,bar.time,st.hasPrev))
     {
      st.pdh=st.curDayH;
      st.pdl=st.curDayL;
      st.hasPdh=true;
      st.hasPdl=true;
      st.curDayH=bar.high;
      st.curDayL=bar.low;
     }
   else
     {
      st.curDayH=MathMax(st.curDayH,bar.high);
      st.curDayL=MathMin(st.curDayL,bar.low);
     }

   const bool swpBullPd=(cfg.pdOn && st.hasPdl && bar.low<st.pdl && bar.close>st.pdl);
   const bool swpBearPd=(cfg.pdOn && st.hasPdh && bar.high>st.pdh && bar.close<st.pdh);
   out.swpBull=(swpBullSw || swpBullPd);
   out.swpBear=(swpBearSw || swpBearPd);
   if(out.swpBull)
      st.lastBullSweepBar=barIndex;
   if(out.swpBear)
      st.lastBearSweepBar=barIndex;

   //--- Candles
   const double body=MathAbs(bar.close-bar.open);
   const double tick=(bar.tickSize>0.0 ? bar.tickSize : 0.0);
   const double range=MathMax(bar.high-bar.low,tick);
   const double upperWick=bar.high-MathMax(bar.close,bar.open);
   const double lowerWick=MathMin(bar.close,bar.open)-bar.low;
   out.pinBull=(lowerWick>=2.0*body && bar.close>=(bar.low+0.5*range));
   out.pinBear=(upperWick>=2.0*body && bar.close<=(bar.high-0.5*range));
   out.engulfBull=(st.hasPrev && bar.close>bar.open && st.prevClose<st.prevOpen
                   && bar.close>=st.prevOpen && bar.open<=st.prevClose);
   out.engulfBear=(st.hasPrev && bar.close<bar.open && st.prevClose>st.prevOpen
                   && bar.close<=st.prevOpen && bar.open>=st.prevClose);
   out.momBull=(bar.close>bar.open && body>=0.55*range);
   out.momBear=(bar.close<bar.open && body>=0.55*range);
   out.candleBull=(out.pinBull || out.engulfBull || out.momBull);
   out.candleBear=(out.pinBear || out.engulfBear || out.momBear);

   //--- MTF
   const bool htfValid=(bar.htfValid && !FzIsNa(bar.htfEma));
   out.htfBull=(!cfg.mtfOn || !htfValid || bar.close>=bar.htfEma);
   out.htfBear=(!cfg.mtfOn || !htfValid || bar.close<=bar.htfEma);

   //--- Ribbon
   const bool maOk=(!FzIsNa(bar.maFast) && !FzIsNa(bar.maSlow));
   out.rbBull=(maOk && bar.maFast>bar.maSlow);
   out.rbBear=(maOk && bar.maFast<bar.maSlow);
   bool fastUp=false,slowUp=false,fastDn=false,slowDn=false;
   if(maOk && st.hasPrevMa)
     {
      fastUp=(bar.maFast>st.prevMaFast);
      slowUp=(bar.maSlow>st.prevMaSlow);
      fastDn=(bar.maFast<st.prevMaFast);
      slowDn=(bar.maSlow<st.prevMaSlow);
     }
   out.rbStrongBull=(out.rbBull && fastUp && slowUp);
   out.rbStrongBear=(out.rbBear && fastDn && slowDn);
   if(maOk)
     {
      out.rbTop=MathMax(bar.maFast,bar.maSlow);
      out.rbBot=MathMin(bar.maFast,bar.maSlow);
      if(st.hasPrevMa)
         out.rbExpanding=(MathAbs(bar.maFast-bar.maSlow)>st.prevSpread);
     }
   if(maOk && atrOk)
     {
      const double tol=cfg.pullTol*atr;
      out.priceInRibbon=(bar.low<=out.rbTop+tol && bar.high>=out.rbBot-tol);
     }

   const bool trendLongOk=(!cfg.ribbonFilter || out.rbBull);
   const bool trendShortOk=(!cfg.ribbonFilter || out.rbBear);

   //--- Setups
   const bool s1Long=(cfg.setupPullback && trendLongOk && out.htfBull
                      && (out.priceInRibbon || out.inDemand) && out.candleBull
                      && maOk && bar.close>=out.rbBot);
   const bool s1Short=(cfg.setupPullback && trendShortOk && out.htfBear
                       && (out.priceInRibbon || out.inSupply) && out.candleBear
                       && maOk && bar.close<=out.rbTop);
   const int sinceBull=(st.lastBullSweepBar>=0 ? barIndex-st.lastBullSweepBar : -1);
   const int sinceBear=(st.lastBearSweepBar>=0 ? barIndex-st.lastBearSweepBar : -1);
   const bool winBull=(sinceBull>=0 && sinceBull<=cfg.sweepConfBars);
   const bool winBear=(sinceBear>=0 && sinceBear<=cfg.sweepConfBars);
   const bool s2Long=(cfg.setupSweep && winBull
                      && (out.swpBull || out.candleBull)
                      && (bar.close>bar.open || out.pinBull));
   const bool s2Short=(cfg.setupSweep && winBear
                       && (out.swpBear || out.candleBear)
                       && (bar.close<bar.open || out.pinBear));
   const bool s3Long=(cfg.setupRange && (bar.regime==FZ_REGIME_RANGE)
                      && out.inDemand && out.candleBull);
   const bool s3Short=(cfg.setupRange && (bar.regime==FZ_REGIME_RANGE)
                       && out.inSupply && out.candleBear);

   if(s2Long)
     {
      out.longSetupDetected=true;
      out.setupLong=FZ_SETUP_SWEEP;
     }
   else if(s1Long)
     {
      out.longSetupDetected=true;
      out.setupLong=FZ_SETUP_PULLBACK;
     }
   else if(s3Long)
     {
      out.longSetupDetected=true;
      out.setupLong=FZ_SETUP_RANGE;
     }

   if(s2Short)
     {
      out.shortSetupDetected=true;
      out.setupShort=FZ_SETUP_SWEEP;
     }
   else if(s1Short)
     {
      out.shortSetupDetected=true;
      out.setupShort=FZ_SETUP_PULLBACK;
     }
   else if(s3Short)
     {
      out.shortSetupDetected=true;
      out.setupShort=FZ_SETUP_RANGE;
     }

   //--- Scores
   const bool engulfOrPinBull=(out.engulfBull || out.pinBull);
   const bool engulfOrPinBear=(out.engulfBear || out.pinBear);
   out.scoreLong=FzScoreLong(cfg,out.rbStrongBull,out.rbBull,out.inDemand,
                             out.priceInRibbon,out.chochBull,out.swpBull,
                             out.bosBull,engulfOrPinBull,out.candleBull,out.htfBull);
   out.scoreShort=FzScoreShort(cfg,out.rbStrongBear,out.rbBear,out.inSupply,
                               out.priceInRibbon,out.chochBear,out.swpBear,
                               out.bosBear,engulfOrPinBear,out.candleBear,out.htfBear);

   //--- Risk
   double oppLongLevel=EMPTY_VALUE;
   double oppLongDist=FZ_INF;
   const bool hasOppLong=FzNearestOpposingLevel(st,true,bar.close,oppLongLevel,oppLongDist);
   double oppShortLevel=EMPTY_VALUE;
   double oppShortDist=FZ_INF;
   const bool hasOppShort=FzNearestOpposingLevel(st,false,bar.close,oppShortLevel,oppShortDist);

   const bool hasDemand=(out.inDemand && !FzIsNa(out.demandBot));
   const bool hasSupply=(out.inSupply && !FzIsNa(out.supplyTop));
   double longRiskDist=EMPTY_VALUE;
   FzRiskLong(cfg,bar.close,atr,cfg.assetVolMult,
              hasDemand,out.demandBot,st.hasSwL,st.swL,
              hasOppLong,oppLongLevel,
              out.slLong,out.tp1Long,out.tp2Long,out.tp3Long,longRiskDist);
   double shortRiskDist=EMPTY_VALUE;
   FzRiskShort(cfg,bar.close,atr,cfg.assetVolMult,
               hasSupply,out.supplyTop,st.hasSwH,st.swH,
               hasOppShort,oppShortLevel,
               out.slShort,out.tp1Short,out.tp2Short,out.tp3Short,shortRiskDist);

   //--- Gates and eligibility
   out.coolOk=((barIndex-st.lastSignalBar)>=cfg.coolBars);
   FzGates(cfg,bar.close,out.tp1Long,out.tp1Short,
           hasOppLong,oppLongDist,hasOppShort,oppShortDist,
           out.longSetupDetected,out.shortSetupDetected,
           out.scoreLong,out.scoreShort,out.coolOk,
           out.blockLong,out.blockShort);
   FzEligibility(cfg,true,out.longSetupDetected,out.shortSetupDetected,
                 out.scoreLong,out.scoreShort,out.blockLong,out.blockShort,
                 out.signalLong,out.signalShort);
   if(out.signalLong || out.signalShort)
      st.lastSignalBar=barIndex;

   //--- State machine
   FzStateStep(st,barIndex,bar,out.signalLong,out.signalShort,
               out.slLong,out.tp1Long,out.tp2Long,out.tp3Long,
               (int)out.scoreLong,out.setupLong,
               out.slShort,out.tp1Short,out.tp2Short,out.tp3Short,
               (int)out.scoreShort,out.setupShort,out);

   //--- Previous bar snapshot
   st.prevOpen=bar.open;
   st.prevHigh=bar.high;
   st.prevLow=bar.low;
   st.prevClose=bar.close;
   st.prevTime=bar.time;
   st.hasPrev=true;
   if(maOk)
     {
      st.prevMaFast=bar.maFast;
      st.prevMaSlow=bar.maSlow;
      st.prevSpread=MathAbs(bar.maFast-bar.maSlow);
      st.hasPrevMa=true;
     }
   else
     {
      st.hasPrevMa=false;
      st.prevSpread=EMPTY_VALUE;
     }
  }

string FzConfigCanonical(const FzConfig &cfg)
  {
   return(StringFormat("v=%s|am=%d|cm=%.6f|eff=%d|avm=%.6f|rt=%d|rf=%d|rs=%d|rfl=%d|zl=%d|zw=%.6f|zm=%d|sl=%d|sw=%d|pd=%d|sp=%d|ss=%d|sr=%d|pt=%.6f|sc=%d|mo=%d|mt=%d|ml=%d|wt=%.6f|wz=%.6f|ws=%.6f|wc=%.6f|wm=%.6f|nt=%d|mg=%d|sm=%d|tm=%d|sa=%.6f|spa=%.6f|smi=%.6f|sma=%.6f|r1=%.6f|r2=%.6f|r3=%.6f|rm=%.6f|og=%d|cb=%d",
                       FZ_CONTRACT_VERSION,
                       (int)cfg.assetMode,cfg.customVolMult,cfg.effAsset,cfg.assetVolMult,
                       (int)cfg.ribbonType,cfg.ribbonFast,cfg.ribbonSlow,(int)cfg.ribbonFilter,
                       cfg.zonePivotLen,cfg.zoneWidthAtr,cfg.zoneMax,
                       cfg.structPivotLen,(int)cfg.sweepOn,(int)cfg.pdOn,
                       (int)cfg.setupPullback,(int)cfg.setupSweep,(int)cfg.setupRange,
                       cfg.pullTol,cfg.sweepConfBars,(int)cfg.mtfOn,(int)cfg.mtfTf,cfg.mtfLen,
                       cfg.wTrend,cfg.wZone,cfg.wStruct,cfg.wCandle,cfg.wMtf,
                       cfg.scrNoTrade,cfg.scoreMargin,
                       (int)cfg.slMode,(int)cfg.tpMode,
                       cfg.slAtrMul,cfg.slPadAtr,cfg.slMinAtr,cfg.slMaxAtr,
                       cfg.rr1,cfg.rr2,cfg.rr3,cfg.rrMin,(int)cfg.obstacleGate,cfg.coolBars));
  }

string FzConfigHash(const FzConfig &cfg)
  {
   const string canonical=FzConfigCanonical(cfg);
   uint hash=(uint)2166136261;
   for(int i=0; i<StringLen(canonical); i++)
     {
      hash^=(uint)(StringGetCharacter(canonical,i)&0xFF);
      hash=(uint)(hash*(uint)16777619);
     }
   return(StringFormat("%08X",(int)hash));
  }

#endif // TMFUSIONZONES_CONTRACT_MQH
