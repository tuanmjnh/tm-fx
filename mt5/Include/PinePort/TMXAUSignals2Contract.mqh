//+------------------------------------------------------------------+
//|                                  TMXAUSignals2Contract.mqh       |
//|     MT5 EA & AI Lab - PinePort buffer contract and pure logic    |
//|                                                                  |
//| Port of "TM XAU Signals 2" (Pine v6) to MQL5. Simulation-only    |
//| research module: no file I/O, no account access, no trading.     |
//| Contract: docs/indicators/tm-xau-signals-2.md                   |
//+------------------------------------------------------------------+
#ifndef TMXAUSIGNALS2_CONTRACT_MQH
#define TMXAUSIGNALS2_CONTRACT_MQH

#define X2_CONTRACT_VERSION  "1.0.0"
#define X2_PLOT_BUFFERS      13
#define X2_CONTRACT_BUFFERS  140
#define X2_TOTAL_BUFFERS     153
#define X2_CONTRACT_FIRST    13
#define X2_MAX_SR            30
#define X2_MAX_FVG           50
#define X2_MAX_OB            50
#define X2_MAX_EVT           50
#define X2_OBV_MAX           202

enum ENUM_X2_QUALITY
  {
   X2_Q_NOTRADE = 0,
   X2_Q_WEAK    = 1,
   X2_Q_SETUP   = 2,
   X2_Q_STRONG  = 3,
   X2_Q_APLUS   = 4
  };

enum ENUM_X2_BUCKET
  {
   X2_BUCKET_VERYLOW  = 0,
   X2_BUCKET_LOW      = 1,
   X2_BUCKET_NORMAL   = 2,
   X2_BUCKET_HIGH     = 3,
   X2_BUCKET_VERYHIGH = 4,
   X2_BUCKET_TIM      = 5
  };

enum ENUM_X2_SESSION
  {
   X2_SESS_NONE      = 0,
   X2_SESS_ASIA      = 1,
   X2_SESS_LONDON    = 2,
   X2_SESS_NY        = 3,
   X2_SESS_LONDON_NY = 4
  };

enum ENUM_X2_CLOSE
  {
   X2_CLOSE_NONE    = 0,
   X2_CLOSE_SL      = 1,
   X2_CLOSE_TP3     = 2,
   X2_CLOSE_TIMEOUT = 3
  };

enum ENUM_X2_BLOCK
  {
   X2_BLOCK_NONE         = 0,
   X2_BLOCK_PLAN_INVALID = 1,
   X2_BLOCK_MTF_FILTER   = 2,
   X2_BLOCK_HTF_VETO     = 3,
   X2_BLOCK_COOLDOWN     = 4,
   X2_BLOCK_DAY_LIMIT    = 5,
   X2_BLOCK_SCORE        = 6,
   X2_BLOCK_DIR          = 7
  };

enum ENUM_X2_EVENT
  {
   X2_EVT_NONE    = 0,
   X2_EVT_BOS     = 1,
   X2_EVT_CHOCH   = 2,
   X2_EVT_MSS     = 3,
   X2_EVT_RETEST  = 4,
   X2_EVT_FAILBRK = 5,
   X2_EVT_CONT    = 6,
   X2_EVT_PULL    = 7,
   X2_EVT_SWEEP   = 8
  };

enum ENUM_X2_BUFFER
  {
   X2_BUF_SCORE100        = 13,
   X2_BUF_DIR             = 14,
   X2_BUF_QUALITY         = 15,
   X2_BUF_RAW_SCORE       = 16,
   X2_BUF_G_TREND         = 17,
   X2_BUF_G_STRUCT        = 18,
   X2_BUF_G_LIQ           = 19,
   X2_BUF_G_LOC           = 20,
   X2_BUF_G_SR            = 21,
   X2_BUF_G_CANDLE        = 22,
   X2_BUF_G_VOLUME        = 23,
   X2_BUF_G_VOL           = 24,
   X2_BUF_G_MOM           = 25,
   X2_BUF_G_SESS          = 26,
   X2_BUF_G_MTF           = 27,
   X2_BUF_PLAN_VALID      = 28,
   X2_BUF_ENTRY           = 29,
   X2_BUF_SL              = 30,
   X2_BUF_TP1             = 31,
   X2_BUF_TP2             = 32,
   X2_BUF_TP3             = 33,
   X2_BUF_RISK            = 34,
   X2_BUF_SIG             = 35,
   X2_BUF_BLOCK           = 36,
   X2_BUF_EV_ENTRY        = 37,
   X2_BUF_EV_TP           = 38,
   X2_BUF_EV_SL           = 39,
   X2_BUF_EV_CLOSE        = 40,
   X2_BUF_CLOSE_REASON    = 41,
   X2_BUF_POS_DIR         = 42,
   X2_BUF_POS_ENTRY       = 43,
   X2_BUF_POS_SL          = 44,
   X2_BUF_POS_TP1         = 45,
   X2_BUF_POS_TP2         = 46,
   X2_BUF_POS_TP3         = 47,
   X2_BUF_POS_RISK        = 48,
   X2_BUF_POS_STAGE       = 49,
   X2_BUF_POS_BARS        = 50,
   X2_BUF_POS_BAR         = 51,
   X2_BUF_DAY_COUNT       = 52,
   X2_BUF_BARS_SINCE      = 53,
   X2_BUF_TRADES          = 54,
   X2_BUF_WINS            = 55,
   X2_BUF_LOSSES          = 56,
   X2_BUF_X_ENTRY         = 57,
   X2_BUF_X_SL            = 58,
   X2_BUF_X_DIR           = 59,
   X2_BUF_X_BAR           = 60,
   X2_BUF_X_EXIT          = 61,
   X2_BUF_X_R             = 62,
   X2_BUF_TREND           = 63,
   X2_BUF_BOS_UP          = 64,
   X2_BUF_BOS_DOWN        = 65,
   X2_BUF_CHOCH_UP        = 66,
   X2_BUF_CHOCH_DOWN      = 67,
   X2_BUF_MSS_UP          = 68,
   X2_BUF_MSS_DOWN        = 69,
   X2_BUF_RETEST_UP       = 70,
   X2_BUF_RETEST_DOWN     = 71,
   X2_BUF_FAIL_UP         = 72,
   X2_BUF_FAIL_DOWN       = 73,
   X2_BUF_SWEEP_UP        = 74,
   X2_BUF_SWEEP_DOWN      = 75,
   X2_BUF_HH              = 76,
   X2_BUF_HL              = 77,
   X2_BUF_LH              = 78,
   X2_BUF_LL              = 79,
   X2_BUF_CONT_UP         = 80,
   X2_BUF_CONT_DOWN       = 81,
   X2_BUF_PULL_UP         = 82,
   X2_BUF_PULL_DOWN       = 83,
   X2_BUF_EQ_HI           = 84,
   X2_BUF_EQ_LO           = 85,
   X2_BUF_BRK_LEVEL       = 86,
   X2_BUF_BRK_DIR         = 87,
   X2_BUF_CP_BULL         = 88,
   X2_BUF_CP_BEAR         = 89,
   X2_BUF_CANDLE_SCORE    = 90,
   X2_BUF_PIN_BULL        = 91,
   X2_BUF_PIN_BEAR        = 92,
   X2_BUF_ENG_BULL        = 93,
   X2_BUF_ENG_BEAR        = 94,
   X2_BUF_DISP_BULL       = 95,
   X2_BUF_DISP_BEAR       = 96,
   X2_BUF_DISP_BULL_V     = 97,
   X2_BUF_DISP_BEAR_V     = 98,
   X2_BUF_REJ_BULL        = 99,
   X2_BUF_REJ_BEAR        = 100,
   X2_BUF_ATR             = 101,
   X2_BUF_ATR_PCT         = 102,
   X2_BUF_ATR_MA          = 103,
   X2_BUF_ATR_REGIME      = 104,
   X2_BUF_RSI             = 105,
   X2_BUF_MACD_HIST       = 106,
   X2_BUF_ADX             = 107,
   X2_BUF_DI_PLUS         = 108,
   X2_BUF_DI_MINUS        = 109,
   X2_BUF_BB_WIDTH        = 110,
   X2_BUF_BB_WIDTH_MA     = 111,
   X2_BUF_BB_EXPAND       = 112,
   X2_BUF_VOL_RATIO       = 113,
   X2_BUF_VOL_BUCKET      = 114,
   X2_BUF_IS_TIM          = 115,
   X2_BUF_REL_VOL         = 116,
   X2_BUF_OBV_SLOPE       = 117,
   X2_BUF_VWAP            = 118,
   X2_BUF_PDH             = 119,
   X2_BUF_PDL             = 120,
   X2_BUF_PWH             = 121,
   X2_BUF_PWL             = 122,
   X2_BUF_DAY_RANGE       = 123,
   X2_BUF_LOCATION_SCORE  = 124,
   X2_BUF_VOLUME_SCORE    = 125,
   X2_BUF_MOM_SCORE       = 126,
   X2_BUF_TREND_SCORE     = 127,
   X2_BUF_SESS_SCORE      = 128,
   X2_BUF_SESS_NAME       = 129,
   X2_BUF_SESS_HI         = 130,
   X2_BUF_SESS_LO         = 131,
   X2_BUF_MTF_CTX_DIR     = 132,
   X2_BUF_MTF_SETUP_DIR   = 133,
   X2_BUF_OK_SETUP        = 134,
   X2_BUF_HTF_VETO        = 135,
   X2_BUF_SWING_LO        = 136,
   X2_BUF_SWING_HI        = 137,
   X2_BUF_LAST_HIGH       = 138,
   X2_BUF_LAST_LOW        = 139,
   X2_BUF_NEAR_SUPPORT    = 140,
   X2_BUF_NEAR_RESISTANCE = 141,
   X2_BUF_NEAR_FVG_BULL   = 142,
   X2_BUF_NEAR_FVG_BEAR   = 143,
   X2_BUF_SR_COUNT        = 144,
   X2_BUF_FVG_COUNT       = 145,
   X2_BUF_OB_COUNT        = 146,
   X2_BUF_EVT_KIND        = 147,
   X2_BUF_EVT_DIR         = 148,
   X2_BUF_EVT_SRC_BAR     = 149,
   X2_BUF_EVT_SRC_TIME    = 150,
   X2_BUF_EVT_LEVEL       = 151,
   X2_BUF_EVT_COUNT       = 152
  };

struct X2Config
  {
   //--- time (MQL5 only)
   int    srvOffsetMin;
   int    mktOffsetMin;
   int    volSessOffsetMin;
   int    maxBars;
   //--- logic (Pine 1:1)
   int    swingLen;
   bool   retestOn;
   int    retestBars;
   double retestTolAtr;
   bool   failOn;
   int    failBars;
   bool   contOn;
   bool   pullOn;
   double eqTolAtr;
   bool   pdOn;
   bool   pwOn;
   bool   sessOn;
   int    srLeft;
   int    srRight;
   double srWidthAtr;
   int    srMax;
   double fvgMinAtr;
   int    fvgMax;
   int    fvgLife;
   int    obMax;
   double pinRatio;
   bool   engulfOn;
   bool   pinOn;
   bool   dispOn;
   double dispAtr;
   bool   rejOn;
   int    emaFast;
   int    emaMid;
   int    emaSlow;
   int    atrLen;
   int    rsiLen;
   double rsiOb;
   double rsiOs;
   int    macdFast;
   int    macdSlow;
   int    macdSignal;
   int    dmiLen;
   int    dmiSmooth;
   double adxMin;
   int    bbLen;
   double bbMult;
   int    rvLen;
   double rvMin;
   int    obvLen;
   int    volMaLen;
   double volSpikeR;
   double volRVH;
   double volRH;
   double volRN;
   double volRL;
   double volMin;
   bool   volSessOn;
   int    volSessStartMin;
   int    volSessEndMin;
   ENUM_TIMEFRAMES ctxTf;
   int    ctxLen;
   ENUM_TIMEFRAMES setupTf;
   int    setupLen;
   bool   htfFilter;
   bool   htfVetoOn;
   double wTrend;
   double wStruct;
   double wLiq;
   double wLoc;
   double wSr;
   double wCandle;
   double wVol;
   double wAtr;
   double wMom;
   double wSess;
   double wMtf;
   int    scrNoTrade;
   int    scrWeak;
   int    scrSetup;
   int    scrStrong;
   double slAtrMul;
   int    slSwing;
   double slPadAtr;
   double slMinAtr;
   double slMaxAtr;
   double rr1;
   double rr2;
   double rr3;
   double rrMin;
   int    maxDay;
   int    coolBars;
  };

struct X2SrZone
  {
   double top;
   double bot;
   int    side;
   int    touches;
   bool   broken;
  };

struct X2Fvg
  {
   double top;
   double bot;
   int    srcBar;
   int    dir;
   bool   dead;
  };

struct X2Ob
  {
   double top;
   double bot;
   int    srcBar;
   int    dir;
   bool   dead;
  };

struct X2Event
  {
   int      kind;
   int      dir;
   int      srcBar;
   datetime srcTime;
   bool     confirmed;
   double   level;
  };

struct X2EngineState
  {
   //--- structure
   double lastHigh;
   double prevHigh;
   double lastLow;
   double prevLow;
   double brkLevel;
   int    lastHighBar;
   int    lastLowBar;
   int    trend;
   int    brkDir;
   int    brkBar;
   bool   hasLastHigh;
   bool   hasLastLow;
   bool   hasPrevHigh;
   bool   hasPrevLow;
   bool   hasBrk;
   //--- edge flags of the current bar
   bool   bosUp;
   bool   bosDown;
   bool   chochUp;
   bool   chochDown;
   bool   mssUp;
   bool   mssDown;
   bool   retestBull;
   bool   retestBear;
   bool   failBull;
   bool   failBear;
   bool   contBull;
   bool   contBear;
   bool   pullBull;
   bool   pullBear;
   bool   sweepBull;
   bool   sweepBear;
   bool   isHH;
   bool   isHL;
   bool   isLH;
   bool   isLL;
   bool   eqHi;
   bool   eqLo;
   //--- session
   double sessHi;
   double sessLo;
   int    sessPrev;
   bool   hasSessHi;
   bool   hasSessLo;
   //--- zones
   X2SrZone sr[X2_MAX_SR];
   int      srCount;
   X2Fvg    fvg[X2_MAX_FVG];
   int      fvgCount;
   X2Ob     ob[X2_MAX_OB];
   int      obCount;
   //--- OBV window
   double obv;
   double obvHist[X2_OBV_MAX];
   int    obvCount;
   int    obvBar;
   //--- day / week
   long   dayStamp;
   long   weekStamp;
   double curDayHi;
   double curDayLo;
   double curWeekHi;
   double curWeekLo;
   double pdh;
   double pdl;
   double pwh;
   double pwl;
   bool   hasPd;
   bool   hasPw;
   //--- VWAP
   long   vwapStamp;
   double vwapPV;
   double vwapVol;
   bool   hasVwap;
   //--- MACD previous bar
   double prevMacdHist;
   bool   hasPrevMacd;
   //--- gating
   int    dayCount;
   int    barsSince;
   //--- position
   int    posDir;
   int    posStage;
   int    posBar;
   int    posBars;
   double posEntry;
   double posSl;
   double posTp1;
   double posTp2;
   double posTp3;
   double posRisk;
   bool   needReset;
   //--- last closed trade
   double xEntry;
   double xSl;
   double xExit;
   double xR;
   int    xDir;
   int    xBar;
   //--- stats
   int    trades;
   int    wins;
   int    losses;
   //--- event ring
   X2Event evt[X2_MAX_EVT];
   int     evtCount;
   //--- outputs of the current bar
   bool   evEntry;
   bool   evSl;
   bool   evClose;
   int    evTp;
   int    closeReason;
  };

struct X2Bar
  {
   datetime time;
   double   open;
   double   high;
   double   low;
   double   close;
   double   volume;
   double   tickSize;
   double   prevOpen;
   double   prevClose;
   double   prevHigh;
   double   prevLow;
   double   high2;
   double   low2;
   double   atr;
   double   atrMA;
   double   volMA;
   double   volSma;
   double   emaF;
   double   emaM;
   double   emaS;
   double   rsi;
   double   macdHist;
   double   diPlus;
   double   diMinus;
   double   adx;
   double   bbMid;
   double   bbUp;
   double   bbLo;
   double   bbWidth;
   double   bbWidthMA;
   double   pivH;
   bool     pivHValid;
   double   pivL;
   bool     pivLValid;
   double   srPivH;
   bool     srPivHValid;
   double   srPivL;
   bool     srPivLValid;
   double   swingLo;
   double   swingHi;
   double   htfCtxEma;
   bool     htfCtxValid;
   double   htfSetupEma;
   bool     htfSetupValid;
   int      sessName;
   bool     volSessOk;
   long     dayStamp;
   double   vwap;
   double   pdh;
   double   pdl;
   double   pwh;
   double   pwl;
   bool     hasPd;
   bool     hasPw;
  };

struct X2Plan
  {
   bool   valid;
   int    dir;
   double entry;
   double sl;
   double tp1;
   double tp2;
   double tp3;
   double risk;
   double rr1;
  };

struct X2BarOut
  {
   int    score100;
   int    dir;
   int    quality;
   double rawScore;
   double gTrend;
   double gStruct;
   double gLiq;
   double gLoc;
   double gSr;
   double gCandle;
   double gVolume;
   double gVol;
   double gMom;
   double gSess;
   double gMtf;
   bool   planValid;
   double entry;
   double sl;
   double tp1;
   double tp2;
   double tp3;
   double risk;
   bool   signal;
   int    block;
   bool   evEntry;
   int    evTp;
   bool   evSl;
   bool   evClose;
   int    closeReason;
   int    posDir;
   double posEntry;
   double posSl;
   double posTp1;
   double posTp2;
   double posTp3;
   double posRisk;
   int    posStage;
   int    posBars;
   int    posBar;
   int    dayCount;
   int    barsSince;
   int    trades;
   int    wins;
   int    losses;
   double xEntry;
   double xSl;
   int    xDir;
   int    xBar;
   double xExit;
   double xR;
   int    trend;
   bool   bosUp;
   bool   bosDown;
   bool   chochUp;
   bool   chochDown;
   bool   mssUp;
   bool   mssDown;
   bool   retestUp;
   bool   retestDown;
   bool   failUp;
   bool   failDown;
   bool   sweepUp;
   bool   sweepDown;
   bool   hh;
   bool   hl;
   bool   lh;
   bool   ll;
   bool   contUp;
   bool   contDown;
   bool   pullUp;
   bool   pullDown;
   bool   eqHi;
   bool   eqLo;
   double brkLevel;
   int    brkDir;
   double cpBull;
   double cpBear;
   double candleScore;
   bool   pinBull;
   bool   pinBear;
   bool   engBull;
   bool   engBear;
   bool   dispBull;
   bool   dispBear;
   bool   dispBullV;
   bool   dispBearV;
   bool   rejBull;
   bool   rejBear;
   double atr;
   double atrPct;
   double atrMA;
   double atrRegime;
   double rsi;
   double macdHist;
   double adx;
   double diPlus;
   double diMinus;
   double bbWidth;
   double bbWidthMA;
   bool   bbExpand;
   double volRatio;
   int    volBucket;
   bool   isTim;
   double relVol;
   double obvSlope;
   double vwap;
   double pdh;
   double pdl;
   double pwh;
   double pwl;
   double dayRange;
   double locationScore;
   double volumeScore;
   double momScore;
   double trendScore;
   double sessScore;
   int    sessName;
   double sessHi;
   double sessLo;
   int    mtfCtxDir;
   int    mtfSetupDir;
   bool   okSetup;
   bool   htfVeto;
   double swingLo;
   double swingHi;
   double lastHigh;
   double lastLow;
   bool   nearSupport;
   bool   nearResistance;
   bool   nearFvgBull;
   bool   nearFvgBear;
   int    srCount;
   int    fvgCount;
   int    obCount;
   int    evtKind;
   int    evtDir;
   int    evtSrcBar;
   datetime evtSrcTime;
   double evtLevel;
   int    evtCount;
  };

//+------------------------------------------------------------------+
//| Math / time helpers                                              |
//+------------------------------------------------------------------+
bool X2IsEmpty(const double value)
  {
   return(value==EMPTY_VALUE || value==-EMPTY_VALUE || !MathIsValidNumber(value));
  }

double X2Clamp(const double value,const double low,const double high)
  {
   if(X2IsEmpty(value) || X2IsEmpty(low) || X2IsEmpty(high))
      return(EMPTY_VALUE);
   return(MathMax(low,MathMin(high,value)));
  }

int X2ClampInt(const int value,const int low,const int high)
  {
   return((int)MathMax((double)low,MathMin((double)high,(double)value)));
  }

double X2ClampMin(const double value,const double low)
  {
   if(X2IsEmpty(value))
      return(low);
   return(MathMax(low,value));
  }

int X2LocalMinute(const datetime serverTime,const int srvOffsetMin,
                  const int localOffsetMin)
  {
   long shifted=(long)serverTime+(long)(localOffsetMin-srvOffsetMin)*60;
   long sec=shifted%86400;
   if(sec<0)
      sec+=86400;
   return((int)(sec/60));
  }

bool X2InWindow(const int minute,const int startMin,const int endMin)
  {
   if(startMin==endMin)
      return(true);
   if(startMin<endMin)
      return(minute>=startMin && minute<endMin);
   return(minute>=startMin || minute<endMin);
  }

int X2SessionName(const int minute)
  {
   const bool asia=X2InWindow(minute,1020,120);
   const bool london=X2InWindow(minute,120,600);
   const bool ny=X2InWindow(minute,420,900);
   if(london && ny)
      return(X2_SESS_LONDON_NY);
   if(ny)
      return(X2_SESS_NY);
   if(london)
      return(X2_SESS_LONDON);
   if(asia)
      return(X2_SESS_ASIA);
   return(X2_SESS_NONE);
  }

double X2SessionScore(const int sessName)
  {
   switch(sessName)
     {
      case X2_SESS_LONDON_NY: return(1.0);
      case X2_SESS_NY:        return(0.8);
      case X2_SESS_LONDON:    return(0.6);
      case X2_SESS_ASIA:      return(0.2);
     }
   return(0.0);
  }

bool X2IsNewServerDay(const datetime prevTime,const datetime curTime)
  {
   MqlDateTime prevDt;
   MqlDateTime curDt;
   TimeToStruct(prevTime,prevDt);
   TimeToStruct(curTime,curDt);
   return(prevDt.year!=curDt.year || prevDt.day_of_year!=curDt.day_of_year);
  }

long X2DayIndex(const datetime t)
  {
   return((long)((long)t/86400));
  }

long X2WeekIndex(const datetime t)
  {
   const long days=(long)((long)t/86400);
   int wd=(int)((days+3)%7);
   if(wd<0)
      wd+=7;
   return(days-(long)wd);
  }

bool X2IsNewServerWeek(const datetime prevTime,const datetime curTime)
  {
   return(X2WeekIndex(prevTime)!=X2WeekIndex(curTime));
  }

bool X2IsClosedBar(const int bar,const int ratesTotal)
  {
   return(bar>=0 && ratesTotal>1 && bar<=ratesTotal-2);
  }

//+------------------------------------------------------------------+
//| Series builders (pass 1)                                         |
//+------------------------------------------------------------------+
double X2TrueRange(const bool hasPrev,const double high,const double low,
                   const double prevClose)
  {
   const double range=high-low;
   if(!hasPrev)
      return(range);
   return(MathMax(range,MathMax(MathAbs(high-prevClose),MathAbs(low-prevClose))));
  }

void X2BuildSma(const double &src[],const int total,const int len,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0 || len<=0 || ArraySize(src)<total)
      return;
   for(int j=len-1; j<total; j++)
     {
      double sum=0.0;
      bool ok=true;
      for(int i=j-len+1; i<=j; i++)
        {
         if(X2IsEmpty(src[i]))
           {
            ok=false;
            break;
           }
         sum+=src[i];
        }
      if(ok)
         out[j]=sum/(double)len;
     }
  }

void X2BuildEma(const double &src[],const int total,const int len,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0 || len<=0 || ArraySize(src)<total)
      return;
   if(len==1)
     {
      for(int j=0; j<total; j++)
         out[j]=src[j];
      return;
     }
   const double alpha=2.0/((double)len+1.0);
   double value=EMPTY_VALUE;
   for(int j=len-1; j<total; j++)
     {
      if(j==len-1)
        {
         double sum=0.0;
         bool ok=true;
         for(int i=0; i<len; i++)
           {
            if(X2IsEmpty(src[i]))
              {
               ok=false;
               break;
              }
            sum+=src[i];
           }
         value=(ok ? sum/(double)len : EMPTY_VALUE);
        }
      else
        {
         if(X2IsEmpty(value) || X2IsEmpty(src[j]))
            value=EMPTY_VALUE;
         else
            value=alpha*src[j]+(1.0-alpha)*value;
        }
      out[j]=value;
     }
  }

void X2BuildRma(const double &src[],const int total,const int len,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0 || len<=0 || ArraySize(src)<total)
      return;
   for(int j=len-1; j<total; j++)
     {
      if(j==len-1)
        {
         double sum=0.0;
         bool ok=true;
         for(int i=0; i<len; i++)
           {
            if(X2IsEmpty(src[i]))
              {
               ok=false;
               break;
              }
            sum+=src[i];
           }
         out[j]=(ok ? sum/(double)len : EMPTY_VALUE);
         continue;
        }
      if(X2IsEmpty(out[j-1]) || X2IsEmpty(src[j]))
         continue;
      out[j]=(((double)(len-1))*out[j-1]+src[j])/(double)len;
     }
  }

void X2BuildAtr(const double &high[],const double &low[],const double &close[],
                const int total,const int len,double &out[])
  {
   ArrayResize(out,0);
   if(total<=0 || ArraySize(high)<total || ArraySize(low)<total || ArraySize(close)<total)
      return;
   double tr[];
   ArrayResize(tr,total);
   for(int j=0; j<total; j++)
      tr[j]=X2TrueRange(j>0,high[j],low[j],(j>0 ? close[j-1] : close[j]));
   X2BuildRma(tr,total,len,out);
  }

void X2BuildRsi(const double &src[],const int total,const int len,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0 || len<=0 || ArraySize(src)<total || total<=len)
      return;
   double avgGain=EMPTY_VALUE;
   double avgLoss=EMPTY_VALUE;
   double gainSum=0.0;
   double lossSum=0.0;
   for(int j=1; j<total; j++)
     {
      if(X2IsEmpty(src[j]) || X2IsEmpty(src[j-1]))
         continue;
      const double delta=src[j]-src[j-1];
      const double gain=(delta>0.0 ? delta : 0.0);
      const double loss=(delta<0.0 ? -delta : 0.0);
      if(j<=len)
        {
         gainSum+=gain;
         lossSum+=loss;
         if(j==len)
           {
            avgGain=gainSum/(double)len;
            avgLoss=lossSum/(double)len;
           }
        }
      else
        {
         if(X2IsEmpty(avgGain) || X2IsEmpty(avgLoss))
            continue;
         avgGain=(((double)(len-1))*avgGain+gain)/(double)len;
         avgLoss=(((double)(len-1))*avgLoss+loss)/(double)len;
        }
      if(j>=len && !X2IsEmpty(avgGain) && !X2IsEmpty(avgLoss))
        {
         if(avgLoss<=0.0)
            out[j]=(avgGain>0.0 ? 100.0 : 50.0);
         else
           {
            const double rs=avgGain/avgLoss;
            out[j]=100.0-100.0/(1.0+rs);
           }
        }
     }
  }

void X2BuildMacdHist(const double &src[],const int total,const int fast,
                     const int slow,const int sig,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0 || fast<=0 || slow<=0 || sig<=0 || ArraySize(src)<total)
      return;
   double emaFast[];
   double emaSlow[];
   X2BuildEma(src,total,fast,emaFast);
   X2BuildEma(src,total,slow,emaSlow);
   double line[];
   ArrayResize(line,total);
   ArrayInitialize(line,EMPTY_VALUE);
   for(int j=0; j<total; j++)
     {
      if(!X2IsEmpty(emaFast[j]) && !X2IsEmpty(emaSlow[j]))
         line[j]=emaFast[j]-emaSlow[j];
     }
   double signal[];
   X2BuildEma(line,total,sig,signal);
   for(int j=0; j<total; j++)
     {
      if(!X2IsEmpty(line[j]) && !X2IsEmpty(signal[j]))
         out[j]=line[j]-signal[j];
     }
  }

void X2BuildDmi(const double &high[],const double &low[],const double &close[],
                const int total,const int len,const int smooth,
                double &diP[],double &diM[],double &adx[])
  {
   ArrayResize(diP,total);
   ArrayResize(diM,total);
   ArrayResize(adx,total);
   ArrayInitialize(diP,EMPTY_VALUE);
   ArrayInitialize(diM,EMPTY_VALUE);
   ArrayInitialize(adx,EMPTY_VALUE);
   if(total<=0 || len<=0 || smooth<=0
      || ArraySize(high)<total || ArraySize(low)<total || ArraySize(close)<total)
      return;
   double tr[];
   double dmPos[];
   double dmNeg[];
   ArrayResize(tr,total);
   ArrayResize(dmPos,total);
   ArrayResize(dmNeg,total);
   for(int j=0; j<total; j++)
     {
      tr[j]=X2TrueRange(j>0,high[j],low[j],(j>0 ? close[j-1] : close[j]));
      double pos=0.0;
      double neg=0.0;
      if(j>0)
        {
         const double chgHigh=high[j]-high[j-1];
         const double down=-1.0*(low[j]-low[j-1]);
         if(chgHigh>0.0 && chgHigh>down)
            pos=chgHigh;
         if(down>0.0 && down>chgHigh)
            neg=down;
        }
      dmPos[j]=pos;
      dmNeg[j]=neg;
     }
   double trSm[];
   double posSm[];
   double negSm[];
   X2BuildRma(tr,total,len,trSm);
   X2BuildRma(dmPos,total,len,posSm);
   X2BuildRma(dmNeg,total,len,negSm);
   double dx[];
   ArrayResize(dx,total);
   ArrayInitialize(dx,EMPTY_VALUE);
   for(int j=0; j<total; j++)
     {
      if(X2IsEmpty(trSm[j]) || X2IsEmpty(posSm[j]) || X2IsEmpty(negSm[j]))
         continue;
      double plus=0.0;
      double minus=0.0;
      if(trSm[j]>0.0)
        {
         plus=100.0*posSm[j]/trSm[j];
         minus=100.0*negSm[j]/trSm[j];
        }
      diP[j]=plus;
      diM[j]=minus;
      const double sum=plus+minus;
      dx[j]=(sum>0.0 ? 100.0*MathAbs(plus-minus)/sum : 0.0);
     }
   X2BuildRma(dx,total,smooth,adx);
  }

void X2BuildBb(const double &src[],const int total,const int len,const double mult,
               double &mid[],double &up[],double &lo[])
  {
   ArrayResize(mid,total);
   ArrayResize(up,total);
   ArrayResize(lo,total);
   ArrayInitialize(mid,EMPTY_VALUE);
   ArrayInitialize(up,EMPTY_VALUE);
   ArrayInitialize(lo,EMPTY_VALUE);
   if(total<=0 || len<=0 || ArraySize(src)<total)
      return;
   for(int j=len-1; j<total; j++)
     {
      double sum=0.0;
      bool ok=true;
      for(int i=j-len+1; i<=j; i++)
        {
         if(X2IsEmpty(src[i]))
           {
            ok=false;
            break;
           }
         sum+=src[i];
        }
      if(!ok)
         continue;
      const double mean=sum/(double)len;
      double var=0.0;
      for(int i=j-len+1; i<=j; i++)
        {
         const double d=src[i]-mean;
         var+=d*d;
        }
      const double sd=MathSqrt(var/(double)len);
      mid[j]=mean;
      up[j]=mean+mult*sd;
      lo[j]=mean-mult*sd;
     }
  }

void X2BuildVwap(const double &close[],const long &vol[],const datetime &t[],
                 const int total,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0 || ArraySize(close)<total || ArraySize(vol)<total || ArraySize(t)<total)
      return;
   long stamp=-1;
   double pv=0.0;
   double vv=0.0;
   for(int j=0; j<total; j++)
     {
      const long day=X2DayIndex(t[j]);
      if(day!=stamp)
        {
         stamp=day;
         pv=0.0;
         vv=0.0;
        }
      const double v=(double)vol[j];
      pv+=close[j]*v;
      vv+=v;
      out[j]=(vv>0.0 ? pv/vv : EMPTY_VALUE);
     }
  }

double X2RollingMin(const double &src[],const int total,const int end,const int len)
  {
   if(len<=0 || end<len-1 || end>=total || ArraySize(src)<total)
      return(EMPTY_VALUE);
   double best=EMPTY_VALUE;
   for(int i=end-len+1; i<=end; i++)
     {
      if(X2IsEmpty(src[i]))
         return(EMPTY_VALUE);
      if(X2IsEmpty(best) || src[i]<best)
         best=src[i];
     }
   return(best);
  }

double X2RollingMax(const double &src[],const int total,const int end,const int len)
  {
   if(len<=0 || end<len-1 || end>=total || ArraySize(src)<total)
      return(EMPTY_VALUE);
   double best=EMPTY_VALUE;
   for(int i=end-len+1; i<=end; i++)
     {
      if(X2IsEmpty(src[i]))
         return(EMPTY_VALUE);
      if(X2IsEmpty(best) || src[i]>best)
         best=src[i];
     }
   return(best);
  }

int X2MapHtfIndex(const datetime &htfCloseTime[],const int count,
                  const datetime chartOpenTime)
  {
   int found=-1;
   for(int k=0; k<count; k++)
     {
      if(htfCloseTime[k]<=chartOpenTime)
         found=k;
      else
         break;
     }
   return(found);
  }

//+------------------------------------------------------------------+
//| Pivots (strict both sides, confirmed at c, value at c-right)      |
//+------------------------------------------------------------------+
bool X2PivotHighAt(const double &high[],const int total,const int bar,
                   const int left,const int right,double &out)
  {
   out=EMPTY_VALUE;
   if(left<1 || right<1 || bar<right || bar>=total || ArraySize(high)<total)
      return(false);
   const int center=bar-right;
   if(center-left<0 || center+right>=total)
      return(false);
   const double value=high[center];
   for(int k=1; k<=left; k++)
     {
      if(high[center-k]>=value)
         return(false);
     }
   for(int k=1; k<=right; k++)
     {
      if(high[center+k]>=value)
         return(false);
     }
   out=value;
   return(true);
  }

bool X2PivotLowAt(const double &low[],const int total,const int bar,
                  const int left,const int right,double &out)
  {
   out=EMPTY_VALUE;
   if(left<1 || right<1 || bar<right || bar>=total || ArraySize(low)<total)
      return(false);
   const int center=bar-right;
   if(center-left<0 || center+right>=total)
      return(false);
   const double value=low[center];
   for(int k=1; k<=left; k++)
     {
      if(low[center-k]<=value)
         return(false);
     }
   for(int k=1; k<=right; k++)
     {
      if(low[center+k]<=value)
         return(false);
     }
   out=value;
   return(true);
  }

//+------------------------------------------------------------------+
//| Volume / candle scores                                           |
//+------------------------------------------------------------------+
int X2VolBucket(const double vol,const double volMA,const double rP,
                const double rVH,const double rH,const double rN,
                const double rL)
  {
   if(X2IsEmpty(volMA))
      return(X2_BUCKET_VERYLOW);
   if(vol>=volMA*rP)
      return(X2_BUCKET_TIM);
   if(vol>=volMA*rVH)
      return(X2_BUCKET_VERYHIGH);
   if(vol>=volMA*rH)
      return(X2_BUCKET_HIGH);
   if(vol>=volMA*rN)
      return(X2_BUCKET_NORMAL);
   if(vol>=volMA*rL)
      return(X2_BUCKET_LOW);
   return(X2_BUCKET_VERYLOW);
  }

double X2RelVolScore(const double relVol,const double rvMin,const double close,
                     const double open)
  {
   if(X2IsEmpty(relVol))
      return(0.0);
   if(relVol<rvMin)
      return(0.0);
   return(close>open ? 1.0 : close<open ? -1.0 : 0.0);
  }

double X2ObvScore(const double slope)
  {
   if(X2IsEmpty(slope))
      return(0.0);
   return(slope>0.0 ? 1.0 : slope<0.0 ? -1.0 : 0.0);
  }

double X2VsaScore(const bool isTim,const bool bull,const bool bear)
  {
   if(!isTim)
      return(0.0);
   return(bull ? 1.0 : bear ? -1.0 : 0.0);
  }

double X2VolumeScore(const double relVolScore,const double obvScore,
                     const double vsaScore)
  {
   return((relVolScore+obvScore+vsaScore)/3.0);
  }

double X2AtrRegime(const double atr,const double atrMA)
  {
   if(X2IsEmpty(atr) || X2IsEmpty(atrMA))
      return(0.5);
   if(atr>atrMA*1.2)
      return(1.0);
   if(atr<atrMA*0.8)
      return(0.0);
   return(0.5);
  }

double X2VolatilityScore(const double atrRegime,const bool bbExpand,
                         const double close,const double open)
  {
   const double volScore=(bbExpand ? (close>open ? 0.5 : -0.5) : 0.0);
   return(atrRegime*((close>=open) ? 1.0 : -1.0)*0.5+volScore*0.5);
  }

//+------------------------------------------------------------------+
//| Indicator / group scores                                         |
//+------------------------------------------------------------------+
double X2RsiScore(const double rsi,const double os,const double ob)
  {
   if(X2IsEmpty(rsi))
      return(0.0);
   return(rsi<os ? 1.0 : rsi>ob ? -1.0 : 0.0);
  }

double X2MacdScore(const double hist,const bool hasPrev,const double prevHist)
  {
   if(X2IsEmpty(hist))
      return(0.0);
   if(hist>0.0 && hasPrev && prevHist<=0.0)
      return(1.0);
   if(hist<0.0 && hasPrev && prevHist>=0.0)
      return(-1.0);
   return(hist>0.0 ? 0.5 : hist<0.0 ? -0.5 : 0.0);
  }

double X2DmiScore(const double diP,const double diM,const double adx,
                  const double adxMin)
  {
   if(X2IsEmpty(adx) || adx<adxMin)
      return(0.0);
   return(diP>diM ? 1.0 : -1.0);
  }

double X2MomScore(const double rsiScore,const double macdScore,const double dmiScore)
  {
   return((rsiScore+macdScore+dmiScore)/3.0);
  }

double X2TrendScore(const bool stackBull,const bool stackBear,const double close,
                    const double emaF,const double emaM)
  {
   if(stackBull)
      return(1.0);
   if(stackBear)
      return(-1.0);
   if(X2IsEmpty(close) || X2IsEmpty(emaF) || X2IsEmpty(emaM))
      return(0.0);
   if(close>emaF && emaF>emaM)
      return(0.5);
   if(close<emaF && emaF<emaM)
      return(-0.5);
   return(0.0);
  }

double X2DayRange(const double close,const bool hasPd,const double pdh,
                  const double pdl)
  {
   if(!hasPd || X2IsEmpty(pdh) || X2IsEmpty(pdl) || pdh<=pdl)
      return(0.0);
   return((close-pdl)/(pdh-pdl)*2.0-1.0);
  }

double X2LocationScore(const double vwapScore,const double dayRange)
  {
   return((vwapScore+X2Clamp(dayRange,-1.0,1.0))/2.0);
  }

double X2GroupStruct(const bool bosUp,const bool chochUp,const bool mssUp,
                     const bool bosDown,const bool chochDown,const bool mssDown,
                     const int trend)
  {
   if(bosUp || chochUp || mssUp)
      return(1.0);
   if(bosDown || chochDown || mssDown)
      return(-1.0);
   return((double)trend*0.5);
  }

double X2GroupLiq(const bool sweepBull,const bool sweepBear,const bool retestBull,
                  const bool retestBear)
  {
   if(sweepBull)
      return(1.0);
   if(sweepBear)
      return(-1.0);
   if(retestBull)
      return(0.7);
   if(retestBear)
      return(-0.7);
   return(0.0);
  }

double X2GroupSr(const bool nearSup,const bool nearRes,const bool nearFvgBull,
                 const bool nearFvgBear)
  {
   if(nearSup)
      return(1.0);
   if(nearRes)
      return(-1.0);
   if(nearFvgBull && !nearFvgBear)
      return(1.0);
   if(nearFvgBear && !nearFvgBull)
      return(-1.0);
   return(0.0);
  }

double X2GroupSess(const double sessScore,const double close,const double open)
  {
   return(sessScore*((close>=open) ? 1.0 : -1.0));
  }

double X2GroupVol(const double atrRegime,const double volScore,const double close,
                  const double open)
  {
   return(atrRegime*((close>=open) ? 1.0 : -1.0)*0.5+volScore*0.5);
  }

double X2RawScore(const double wSum,const double wTotal)
  {
   if(wTotal<=0.0)
      return(0.0);
   const double value=X2Clamp(wSum/wTotal,-1.0,1.0);
   return(X2IsEmpty(value) ? 0.0 : value);
  }

int X2Score100(const double raw)
  {
   if(X2IsEmpty(raw))
      return(50);
   return((int)MathRound(50.0+raw*50.0));
  }

int X2Quality(const int score100,const int noTrade,const int weak,
              const int setup,const int strong)
  {
   if(score100<=noTrade)
      return(X2_Q_NOTRADE);
   if(score100<=weak)
      return(X2_Q_WEAK);
   if(score100<=setup)
      return(X2_Q_SETUP);
   if(score100<=strong)
      return(X2_Q_STRONG);
   return(X2_Q_APLUS);
  }

bool X2OkSetup(const bool htfFilter,const int setupDir,const int dir)
  {
   return(!htfFilter || setupDir==0 || setupDir==dir);
  }

bool X2HtfVeto(const bool htfVetoOn,const int ctxDir,const int dir)
  {
   return(htfVetoOn && ctxDir!=0 && dir!=0 && ctxDir!=dir);
  }

//+------------------------------------------------------------------+
//| Zones / events                                                   |
//+------------------------------------------------------------------+
void X2ZoneAdd(X2EngineState &st,const double px,const int side,const double atr,
               const double width,const int maxZones)
  {
   if(X2IsEmpty(px) || X2IsEmpty(atr) || atr<=0.0 || width<=0.0)
      return;
   const double half=atr*width*0.5;
   for(int i=0; i<st.srCount; i++)
     {
      const double mid=(st.sr[i].top+st.sr[i].bot)*0.5;
      if(MathAbs(mid-px)<atr*width)
        {
         st.sr[i].touches+=1;
         return;
        }
     }
   if(st.srCount>=X2_MAX_SR)
     {
      for(int i=1; i<st.srCount; i++)
         st.sr[i-1]=st.sr[i];
      st.srCount=X2_MAX_SR-1;
     }
   st.sr[st.srCount].top=px+half;
   st.sr[st.srCount].bot=px-half;
   st.sr[st.srCount].side=side;
   st.sr[st.srCount].touches=1;
   st.sr[st.srCount].broken=false;
   st.srCount+=1;

   //--- remove zones marked broken (never set during replay; kept for parity)
   for(int i=st.srCount-1; i>=0; i--)
     {
      if(st.sr[i].broken)
        {
         for(int k=i+1; k<st.srCount; k++)
            st.sr[k-1]=st.sr[k];
         st.srCount-=1;
        }
     }
   while(st.srCount>maxZones && st.srCount>0)
     {
      for(int i=1; i<st.srCount; i++)
         st.sr[i-1]=st.sr[i];
      st.srCount-=1;
     }
  }

bool X2NearSupport(const X2EngineState &st,const double low,const double atrArg)
  {
   if(X2IsEmpty(atrArg))
      return(false);
   for(int i=0; i<st.srCount; i++)
     {
      if(st.sr[i].broken || st.sr[i].side!=1)
         continue;
      if(low>=st.sr[i].bot-atrArg*0.3 && low<=st.sr[i].top+atrArg*0.3)
         return(true);
     }
   return(false);
  }

bool X2NearResistance(const X2EngineState &st,const double high,const double atrArg)
  {
   if(X2IsEmpty(atrArg))
      return(false);
   for(int i=0; i<st.srCount; i++)
     {
      if(st.sr[i].broken || st.sr[i].side!=-1)
         continue;
      if(high>=st.sr[i].bot-atrArg*0.3 && high<=st.sr[i].top+atrArg*0.3)
         return(true);
     }
   return(false);
  }

void X2PushEvent(X2EngineState &st,const int kind,const int dir,const int srcBar,
                 const datetime srcTime,const double level)
  {
   if(st.evtCount>=X2_MAX_EVT)
     {
      for(int i=1; i<st.evtCount; i++)
         st.evt[i-1]=st.evt[i];
      st.evtCount=X2_MAX_EVT-1;
     }
   st.evt[st.evtCount].kind=kind;
   st.evt[st.evtCount].dir=dir;
   st.evt[st.evtCount].srcBar=srcBar;
   st.evt[st.evtCount].srcTime=srcTime;
   st.evt[st.evtCount].confirmed=true;
   st.evt[st.evtCount].level=level;
   st.evtCount+=1;
  }

//+------------------------------------------------------------------+
//| Plan builder (contract section 10.3)                             |
//+------------------------------------------------------------------+
void X2BuildPlan(const X2Config &cfg,const X2Bar &bar,const int dir,X2Plan &plan)
  {
   plan.valid=false;
   plan.dir=dir;
   plan.entry=bar.close;
   plan.sl=EMPTY_VALUE;
   plan.tp1=EMPTY_VALUE;
   plan.tp2=EMPTY_VALUE;
   plan.tp3=EMPTY_VALUE;
   plan.risk=EMPTY_VALUE;
   plan.rr1=cfg.rr1;

   const double atr=bar.atr;
   const bool atrOk=(!X2IsEmpty(atr) && atr>0.0);
   const double pad=atr*cfg.slPadAtr;
   double swing;
   if(dir==1)
      swing=(!X2IsEmpty(bar.swingLo) ? bar.swingLo : bar.low);
   else
      swing=(!X2IsEmpty(bar.swingHi) ? bar.swingHi : bar.high);

   double dist=EMPTY_VALUE;
   if(atrOk)
     {
      const double sDist=(dir==1 ? (bar.close-swing)+pad : (swing-bar.close)+pad);
      const double aDist=atr*cfg.slAtrMul;
      const double base=(aDist+sDist)*0.5;
      const double low=atr*cfg.slMinAtr;
      const double high=MathMax(atr*cfg.slMaxAtr,low);
      dist=X2Clamp(base,low,high);
     }

   double sl=EMPTY_VALUE;
   if(!X2IsEmpty(dist))
      sl=bar.close-(double)dir*dist;
   const double risk=dist;

   const double rr2=MathMax(cfg.rr2,cfg.rr1);
   const double rr3=MathMax(cfg.rr3,rr2);

   const bool dirOk=(dir!=0);
   const bool slOk=(!X2IsEmpty(dist) && dist>0.0
                    && (dir==1 ? sl<bar.close : sl>bar.close));
   const bool rrOk=(cfg.rrMin<=0.0 || cfg.rr1>=cfg.rrMin);
   plan.valid=(atrOk && dirOk && slOk && rrOk);
   plan.sl=sl;
   plan.risk=risk;

   if(!X2IsEmpty(risk))
     {
      plan.tp1=bar.close+(double)dir*cfg.rr1*risk;
      plan.tp2=bar.close+(double)dir*rr2*risk;
      plan.tp3=bar.close+(double)dir*rr3*risk;
     }
  }

//+------------------------------------------------------------------+
//| Init / reset                                                     |
//+------------------------------------------------------------------+
void X2StateInit(X2EngineState &st)
  {
   st.lastHigh=EMPTY_VALUE;
   st.prevHigh=EMPTY_VALUE;
   st.lastLow=EMPTY_VALUE;
   st.prevLow=EMPTY_VALUE;
   st.brkLevel=EMPTY_VALUE;
   st.lastHighBar=-1;
   st.lastLowBar=-1;
   st.trend=0;
   st.brkDir=0;
   st.brkBar=-1;
   st.hasLastHigh=false;
   st.hasLastLow=false;
   st.hasPrevHigh=false;
   st.hasPrevLow=false;
   st.hasBrk=false;

   st.bosUp=false;
   st.bosDown=false;
   st.chochUp=false;
   st.chochDown=false;
   st.mssUp=false;
   st.mssDown=false;
   st.retestBull=false;
   st.retestBear=false;
   st.failBull=false;
   st.failBear=false;
   st.contBull=false;
   st.contBear=false;
   st.pullBull=false;
   st.pullBear=false;
   st.sweepBull=false;
   st.sweepBear=false;
   st.isHH=false;
   st.isHL=false;
   st.isLH=false;
   st.isLL=false;
   st.eqHi=false;
   st.eqLo=false;

   st.sessHi=EMPTY_VALUE;
   st.sessLo=EMPTY_VALUE;
   st.sessPrev=X2_SESS_NONE;
   st.hasSessHi=false;
   st.hasSessLo=false;

   st.srCount=0;
   st.fvgCount=0;
   st.obCount=0;

   st.obv=0.0;
   st.obvCount=0;
   st.obvBar=-1;
   for(int i=0; i<X2_OBV_MAX; i++)
      st.obvHist[i]=0.0;

   st.dayStamp=-1;
   st.weekStamp=-1;
   st.curDayHi=EMPTY_VALUE;
   st.curDayLo=EMPTY_VALUE;
   st.curWeekHi=EMPTY_VALUE;
   st.curWeekLo=EMPTY_VALUE;
   st.pdh=EMPTY_VALUE;
   st.pdl=EMPTY_VALUE;
   st.pwh=EMPTY_VALUE;
   st.pwl=EMPTY_VALUE;
   st.hasPd=false;
   st.hasPw=false;

   st.vwapStamp=-1;
   st.vwapPV=0.0;
   st.vwapVol=0.0;
   st.hasVwap=false;

   st.prevMacdHist=EMPTY_VALUE;
   st.hasPrevMacd=false;

   st.dayCount=0;
   st.barsSince=999999;

   st.posDir=0;
   st.posStage=0;
   st.posBar=-1;
   st.posBars=0;
   st.posEntry=EMPTY_VALUE;
   st.posSl=EMPTY_VALUE;
   st.posTp1=EMPTY_VALUE;
   st.posTp2=EMPTY_VALUE;
   st.posTp3=EMPTY_VALUE;
   st.posRisk=EMPTY_VALUE;
   st.needReset=false;

   st.xEntry=EMPTY_VALUE;
   st.xSl=EMPTY_VALUE;
   st.xExit=EMPTY_VALUE;
   st.xR=EMPTY_VALUE;
   st.xDir=0;
   st.xBar=-1;

   st.trades=0;
   st.wins=0;
   st.losses=0;

   st.evtCount=0;

   st.evEntry=false;
   st.evSl=false;
   st.evClose=false;
   st.evTp=0;
   st.closeReason=X2_CLOSE_NONE;
  }

void X2BarInit(X2Bar &bar)
  {
   bar.time=0;
   bar.open=0.0;
   bar.high=0.0;
   bar.low=0.0;
   bar.close=0.0;
   bar.volume=0.0;
   bar.tickSize=0.0;
   bar.prevOpen=EMPTY_VALUE;
   bar.prevClose=EMPTY_VALUE;
   bar.prevHigh=EMPTY_VALUE;
   bar.prevLow=EMPTY_VALUE;
   bar.high2=EMPTY_VALUE;
   bar.low2=EMPTY_VALUE;
   bar.atr=EMPTY_VALUE;
   bar.atrMA=EMPTY_VALUE;
   bar.volMA=EMPTY_VALUE;
   bar.volSma=EMPTY_VALUE;
   bar.emaF=EMPTY_VALUE;
   bar.emaM=EMPTY_VALUE;
   bar.emaS=EMPTY_VALUE;
   bar.rsi=EMPTY_VALUE;
   bar.macdHist=EMPTY_VALUE;
   bar.diPlus=EMPTY_VALUE;
   bar.diMinus=EMPTY_VALUE;
   bar.adx=EMPTY_VALUE;
   bar.bbMid=EMPTY_VALUE;
   bar.bbUp=EMPTY_VALUE;
   bar.bbLo=EMPTY_VALUE;
   bar.bbWidth=EMPTY_VALUE;
   bar.bbWidthMA=EMPTY_VALUE;
   bar.pivH=EMPTY_VALUE;
   bar.pivHValid=false;
   bar.pivL=EMPTY_VALUE;
   bar.pivLValid=false;
   bar.srPivH=EMPTY_VALUE;
   bar.srPivHValid=false;
   bar.srPivL=EMPTY_VALUE;
   bar.srPivLValid=false;
   bar.swingLo=EMPTY_VALUE;
   bar.swingHi=EMPTY_VALUE;
   bar.htfCtxEma=EMPTY_VALUE;
   bar.htfCtxValid=false;
   bar.htfSetupEma=EMPTY_VALUE;
   bar.htfSetupValid=false;
   bar.sessName=X2_SESS_NONE;
   bar.volSessOk=true;
   bar.dayStamp=-1;
   bar.vwap=EMPTY_VALUE;
   bar.pdh=EMPTY_VALUE;
   bar.pdl=EMPTY_VALUE;
   bar.pwh=EMPTY_VALUE;
   bar.pwl=EMPTY_VALUE;
   bar.hasPd=false;
   bar.hasPw=false;
  }

void X2BarOutReset(X2BarOut &out)
  {
   out.score100=0;
   out.dir=0;
   out.quality=X2_Q_NOTRADE;
   out.rawScore=0.0;
   out.gTrend=0.0;
   out.gStruct=0.0;
   out.gLiq=0.0;
   out.gLoc=0.0;
   out.gSr=0.0;
   out.gCandle=0.0;
   out.gVolume=0.0;
   out.gVol=0.0;
   out.gMom=0.0;
   out.gSess=0.0;
   out.gMtf=0.0;
   out.planValid=false;
   out.entry=EMPTY_VALUE;
   out.sl=EMPTY_VALUE;
   out.tp1=EMPTY_VALUE;
   out.tp2=EMPTY_VALUE;
   out.tp3=EMPTY_VALUE;
   out.risk=EMPTY_VALUE;
   out.signal=false;
   out.block=X2_BLOCK_NONE;
   out.evEntry=false;
   out.evTp=0;
   out.evSl=false;
   out.evClose=false;
   out.closeReason=X2_CLOSE_NONE;
   out.posDir=0;
   out.posEntry=EMPTY_VALUE;
   out.posSl=EMPTY_VALUE;
   out.posTp1=EMPTY_VALUE;
   out.posTp2=EMPTY_VALUE;
   out.posTp3=EMPTY_VALUE;
   out.posRisk=EMPTY_VALUE;
   out.posStage=0;
   out.posBars=0;
   out.posBar=-1;
   out.dayCount=0;
   out.barsSince=0;
   out.trades=0;
   out.wins=0;
   out.losses=0;
   out.xEntry=EMPTY_VALUE;
   out.xSl=EMPTY_VALUE;
   out.xDir=0;
   out.xBar=-1;
   out.xExit=EMPTY_VALUE;
   out.xR=EMPTY_VALUE;
   out.trend=0;
   out.bosUp=false;
   out.bosDown=false;
   out.chochUp=false;
   out.chochDown=false;
   out.mssUp=false;
   out.mssDown=false;
   out.retestUp=false;
   out.retestDown=false;
   out.failUp=false;
   out.failDown=false;
   out.sweepUp=false;
   out.sweepDown=false;
   out.hh=false;
   out.hl=false;
   out.lh=false;
   out.ll=false;
   out.contUp=false;
   out.contDown=false;
   out.pullUp=false;
   out.pullDown=false;
   out.eqHi=false;
   out.eqLo=false;
   out.brkLevel=EMPTY_VALUE;
   out.brkDir=0;
   out.cpBull=0.0;
   out.cpBear=0.0;
   out.candleScore=0.0;
   out.pinBull=false;
   out.pinBear=false;
   out.engBull=false;
   out.engBear=false;
   out.dispBull=false;
   out.dispBear=false;
   out.dispBullV=false;
   out.dispBearV=false;
   out.rejBull=false;
   out.rejBear=false;
   out.atr=EMPTY_VALUE;
   out.atrPct=EMPTY_VALUE;
   out.atrMA=EMPTY_VALUE;
   out.atrRegime=0.5;
   out.rsi=EMPTY_VALUE;
   out.macdHist=EMPTY_VALUE;
   out.adx=EMPTY_VALUE;
   out.diPlus=EMPTY_VALUE;
   out.diMinus=EMPTY_VALUE;
   out.bbWidth=EMPTY_VALUE;
   out.bbWidthMA=EMPTY_VALUE;
   out.bbExpand=false;
   out.volRatio=0.0;
   out.volBucket=X2_BUCKET_VERYLOW;
   out.isTim=false;
   out.relVol=0.0;
   out.obvSlope=0.0;
   out.vwap=EMPTY_VALUE;
   out.pdh=EMPTY_VALUE;
   out.pdl=EMPTY_VALUE;
   out.pwh=EMPTY_VALUE;
   out.pwl=EMPTY_VALUE;
   out.dayRange=0.0;
   out.locationScore=0.0;
   out.volumeScore=0.0;
   out.momScore=0.0;
   out.trendScore=0.0;
   out.sessScore=0.0;
   out.sessName=X2_SESS_NONE;
   out.sessHi=EMPTY_VALUE;
   out.sessLo=EMPTY_VALUE;
   out.mtfCtxDir=0;
   out.mtfSetupDir=0;
   out.okSetup=true;
   out.htfVeto=false;
   out.swingLo=EMPTY_VALUE;
   out.swingHi=EMPTY_VALUE;
   out.lastHigh=EMPTY_VALUE;
   out.lastLow=EMPTY_VALUE;
   out.nearSupport=false;
   out.nearResistance=false;
   out.nearFvgBull=false;
   out.nearFvgBear=false;
   out.srCount=0;
   out.fvgCount=0;
   out.obCount=0;
   out.evtKind=X2_EVT_NONE;
   out.evtDir=0;
   out.evtSrcBar=-1;
   out.evtSrcTime=0;
   out.evtLevel=EMPTY_VALUE;
   out.evtCount=0;
  }

//+------------------------------------------------------------------+
//| Engine step (contract section 8, one closed bar)                  |
//+------------------------------------------------------------------+
void X2EngineStep(const X2Config &cfg,X2EngineState &st,const X2Bar &bar,
                  const int barIndex,X2BarOut &out)
  {
//--- 0. reset per-bar edge flags
   st.bosUp=false;
   st.bosDown=false;
   st.chochUp=false;
   st.chochDown=false;
   st.mssUp=false;
   st.mssDown=false;
   st.retestBull=false;
   st.retestBear=false;
   st.failBull=false;
   st.failBear=false;
   st.contBull=false;
   st.contBear=false;
   st.pullBull=false;
   st.pullBear=false;
   st.sweepBull=false;
   st.sweepBear=false;
   st.isHH=false;
   st.isHL=false;
   st.isLH=false;
   st.isLL=false;
   st.eqHi=false;
   st.eqLo=false;
   st.evEntry=false;
   st.evSl=false;
   st.evClose=false;
   st.evTp=0;
   st.closeReason=X2_CLOSE_NONE;

//--- L1: volume / OBV / candle metrics
   const double atr=bar.atr;
   const bool atrOk=(!X2IsEmpty(atr) && atr>0.0);
   const double vol=bar.volume;

   const bool volMaOk=(!X2IsEmpty(bar.volMA) && bar.volMA>0.0);
   const double volRatio=(volMaOk ? vol/bar.volMA : 0.0);
   const int volBucket=X2VolBucket(vol,bar.volMA,cfg.volSpikeR,cfg.volRVH,
                                   cfg.volRH,cfg.volRN,cfg.volRL);
   const bool isTimRaw=(volMaOk && vol>=bar.volMA*cfg.volSpikeR);
   const bool volEvtOk=((cfg.volMin<=0.0 || vol>=cfg.volMin) && bar.volSessOk);
   const bool isTim=(isTimRaw && volEvtOk);
   const bool volSmaOk=(!X2IsEmpty(bar.volSma) && bar.volSma>0.0);
   const double relVol=(volSmaOk ? vol/bar.volSma : 0.0);

   const bool hasPrev=(!X2IsEmpty(bar.prevClose));
   if(hasPrev)
     {
      if(bar.close>bar.prevClose)
         st.obv+=vol;
      else if(bar.close<bar.prevClose)
         st.obv-=vol;
     }
   if(st.obvBar!=barIndex)
     {
      if(st.obvCount>=X2_OBV_MAX)
        {
         for(int i=1; i<st.obvCount; i++)
            st.obvHist[i-1]=st.obvHist[i];
         st.obvCount=X2_OBV_MAX-1;
        }
      st.obvHist[st.obvCount]=st.obv;
      st.obvCount+=1;
      st.obvBar=barIndex;
     }
   while(st.obvCount>cfg.obvLen+2)
     {
      for(int i=1; i<st.obvCount; i++)
         st.obvHist[i-1]=st.obvHist[i];
      st.obvCount-=1;
     }
   const int obvLag=st.obvCount-1-cfg.obvLen;
   const double obvPrev=(obvLag>=0 ? st.obvHist[obvLag] : 0.0);
   const double obvSlope=st.obv-obvPrev;

   const double body=MathAbs(bar.close-bar.open);
   const double range=MathMax(bar.high-bar.low,bar.tickSize);
   const double hiWick=bar.high-MathMax(bar.close,bar.open);
   const double loWick=MathMin(bar.close,bar.open)-bar.low;
   const bool bullBar=(bar.close>bar.open);
   const bool bearBar=(bar.close<bar.open);
   const bool dispBull=(atrOk && body>=cfg.dispAtr*atr && hiWick<body*0.3);
   const bool dispBear=(atrOk && body>=cfg.dispAtr*atr && loWick<body*0.3);

//--- L2: structure
   if(bar.pivHValid)
     {
      const double newH=bar.pivH;
      const int newHBar=barIndex-cfg.swingLen;
      if(st.hasLastHigh)
        {
         if(st.trend<=0 && bar.close>st.lastHigh)
           {
            st.bosUp=true;
            st.trend=1;
            st.brkLevel=st.lastHigh;
            st.brkDir=1;
            st.brkBar=newHBar;
            st.hasBrk=true;
           }
         if(st.trend<0 && newH>st.lastHigh)
           {
            st.chochUp=true;
            st.trend=1;
            st.brkLevel=st.lastHigh;
            st.brkDir=1;
            st.brkBar=newHBar;
            st.hasBrk=true;
           }
         st.prevHigh=st.lastHigh;
         st.hasPrevHigh=true;
        }
      st.lastHigh=newH;
      st.lastHighBar=newHBar;
      st.hasLastHigh=true;
     }

   if(bar.pivLValid)
     {
      const double newL=bar.pivL;
      const int newLBar=barIndex-cfg.swingLen;
      if(st.hasLastLow)
        {
         if(st.trend>=0 && bar.close<st.lastLow)
           {
            st.bosDown=true;
            st.trend=-1;
            st.brkLevel=st.lastLow;
            st.brkDir=-1;
            st.brkBar=newLBar;
            st.hasBrk=true;
           }
         if(st.trend>0 && newL<st.lastLow)
           {
            st.chochDown=true;
            st.trend=-1;
            st.brkLevel=st.lastLow;
            st.brkDir=-1;
            st.brkBar=newLBar;
            st.hasBrk=true;
           }
         st.prevLow=st.lastLow;
         st.hasPrevLow=true;
        }
      st.lastLow=newL;
      st.lastLowBar=newLBar;
      st.hasLastLow=true;
     }

   if(st.bosUp && dispBull)
      st.mssUp=true;
   if(st.bosDown && dispBear)
      st.mssDown=true;
   if(st.chochUp && dispBull)
      st.mssUp=true;
   if(st.chochDown && dispBear)
      st.mssDown=true;

   st.isHH=(bar.pivHValid && st.hasPrevHigh && bar.pivH>st.prevHigh);
   st.isLH=(bar.pivHValid && st.hasPrevHigh && bar.pivH<st.prevHigh);
   st.isHL=(bar.pivLValid && st.hasPrevLow && bar.pivL>st.prevLow);
   st.isLL=(bar.pivLValid && st.hasPrevLow && bar.pivL<st.prevLow);

   const bool brkOk=(st.hasBrk && !X2IsEmpty(st.brkLevel) && st.brkBar>=0);

   st.retestBull=(cfg.retestOn && st.brkDir==1 && brkOk
                  && (barIndex-st.brkBar)<=cfg.retestBars
                  && atrOk && bar.low<=st.brkLevel+cfg.retestTolAtr*atr
                  && bar.close>st.brkLevel);
   st.retestBear=(cfg.retestOn && st.brkDir==-1 && brkOk
                  && (barIndex-st.brkBar)<=cfg.retestBars
                  && atrOk && bar.high>=st.brkLevel-cfg.retestTolAtr*atr
                  && bar.close<st.brkLevel);

   st.failBull=(cfg.failOn && st.brkDir==-1 && brkOk
                && (barIndex-st.brkBar)<=cfg.failBars
                && bar.close>st.brkLevel);
   st.failBear=(cfg.failOn && st.brkDir==1 && brkOk
                && (barIndex-st.brkBar)<=cfg.failBars
                && bar.close<st.brkLevel);

   st.contBull=(cfg.contOn && st.trend==1 && st.isHH);
   st.contBear=(cfg.contOn && st.trend==-1 && st.isLL);

   const bool emaMOk=(!X2IsEmpty(bar.emaM));
   st.pullBull=(cfg.pullOn && st.trend==1 && emaMOk
                && bar.low<=bar.emaM && bar.close>bar.emaM);
   st.pullBear=(cfg.pullOn && st.trend==-1 && emaMOk
                && bar.high>=bar.emaM && bar.close<bar.emaM);

   if(st.bosUp)
      X2PushEvent(st,X2_EVT_BOS,1,st.lastHighBar,bar.time,st.lastHigh);
   if(st.bosDown)
      X2PushEvent(st,X2_EVT_BOS,-1,st.lastLowBar,bar.time,st.lastLow);
   if(st.chochUp)
      X2PushEvent(st,X2_EVT_CHOCH,1,st.lastHighBar,bar.time,st.lastHigh);
   if(st.chochDown)
      X2PushEvent(st,X2_EVT_CHOCH,-1,st.lastLowBar,bar.time,st.lastLow);
   if(st.mssUp)
      X2PushEvent(st,X2_EVT_MSS,1,st.lastHighBar,bar.time,st.lastHigh);
   if(st.mssDown)
      X2PushEvent(st,X2_EVT_MSS,-1,st.lastLowBar,bar.time,st.lastLow);
   if(st.retestBull)
      X2PushEvent(st,X2_EVT_RETEST,1,barIndex,bar.time,st.brkLevel);
   if(st.retestBear)
      X2PushEvent(st,X2_EVT_RETEST,-1,barIndex,bar.time,st.brkLevel);
   if(st.failBull)
      X2PushEvent(st,X2_EVT_FAILBRK,1,barIndex,bar.time,st.brkLevel);
   if(st.failBear)
      X2PushEvent(st,X2_EVT_FAILBRK,-1,barIndex,bar.time,st.brkLevel);
   if(st.contBull)
      X2PushEvent(st,X2_EVT_CONT,1,st.lastHighBar,bar.time,st.lastHigh);
   if(st.contBear)
      X2PushEvent(st,X2_EVT_CONT,-1,st.lastLowBar,bar.time,st.lastLow);
   if(st.pullBull)
      X2PushEvent(st,X2_EVT_PULL,1,barIndex,bar.time,bar.emaM);
   if(st.pullBear)
      X2PushEvent(st,X2_EVT_PULL,-1,barIndex,bar.time,bar.emaM);

//--- L3: liquidity / PD / PW / session
   st.pdh=bar.pdh;
   st.pdl=bar.pdl;
   st.pwh=bar.pwh;
   st.pwl=bar.pwl;
   st.hasPd=bar.hasPd;
   st.hasPw=bar.hasPw;

   const int sessName=bar.sessName;
   const bool sessChanged=(sessName!=st.sessPrev);
   if(sessChanged && sessName!=X2_SESS_NONE)
     {
      st.sessHi=bar.high;
      st.sessLo=bar.low;
      st.hasSessHi=true;
      st.hasSessLo=true;
     }
   else if(sessName!=X2_SESS_NONE)
     {
      st.sessHi=MathMax((st.hasSessHi ? st.sessHi : bar.high),bar.high);
      st.sessLo=MathMin((st.hasSessLo ? st.sessLo : bar.low),bar.low);
      st.hasSessHi=true;
      st.hasSessLo=true;
     }
   if(sessName!=X2_SESS_NONE)
      st.sessPrev=sessName;

   const double eqThresh=(atrOk ? atr*cfg.eqTolAtr : EMPTY_VALUE);
   st.eqHi=(bar.pivHValid && st.hasPrevHigh && atrOk
            && MathAbs(bar.pivH-st.prevHigh)<=eqThresh);
   st.eqLo=(bar.pivLValid && st.hasPrevLow && atrOk
            && MathAbs(bar.pivL-st.prevLow)<=eqThresh);

   const bool hasPdl=(st.hasPd && !X2IsEmpty(st.pdl));
   const bool hasPdh=(st.hasPd && !X2IsEmpty(st.pdh));
   const bool hasPwl=(st.hasPw && !X2IsEmpty(st.pwl));
   const bool hasPwh=(st.hasPw && !X2IsEmpty(st.pwh));

   st.sweepBull=((cfg.pdOn && hasPdl && bar.low<st.pdl && bar.close>st.pdl)
                 || (cfg.pwOn && hasPwl && bar.low<st.pwl && bar.close>st.pwl)
                 || (cfg.sessOn && st.hasSessLo && bar.low<st.sessLo && bar.close>st.sessLo)
                 || (st.eqLo && st.hasPrevLow && bar.pivL<st.prevLow && bar.close>st.prevLow));
   st.sweepBear=((cfg.pdOn && hasPdh && bar.high>st.pdh && bar.close<st.pdh)
                 || (cfg.pwOn && hasPwh && bar.high>st.pwh && bar.close<st.pwh)
                 || (cfg.sessOn && st.hasSessHi && bar.high>st.sessHi && bar.close<st.sessHi)
                 || (st.eqHi && st.hasPrevHigh && bar.pivH>st.prevHigh && bar.close<st.prevHigh));

   if(st.sweepBull)
     {
      double level=EMPTY_VALUE;
      if(st.hasPd && hasPdl)
         level=MathMax(st.pdl,(st.hasSessLo ? st.sessLo : st.pdl));
      X2PushEvent(st,X2_EVT_SWEEP,1,barIndex,bar.time,level);
     }
   if(st.sweepBear)
     {
      double level=EMPTY_VALUE;
      if(st.hasPd && hasPdh)
         level=MathMin(st.pdh,(st.hasSessHi ? st.sessHi : st.pdh));
      X2PushEvent(st,X2_EVT_SWEEP,-1,barIndex,bar.time,level);
     }

//--- L4: zones
   if(bar.srPivHValid)
      X2ZoneAdd(st,bar.srPivH,-1,atr,cfg.srWidthAtr,cfg.srMax);
   if(bar.srPivLValid)
      X2ZoneAdd(st,bar.srPivL,1,atr,cfg.srWidthAtr,cfg.srMax);

   if(atrOk && !X2IsEmpty(bar.high2))
     {
      if(bar.low>bar.high2 && (bar.low-bar.high2)>=cfg.fvgMinAtr*atr)
        {
         if(st.fvgCount>=X2_MAX_FVG)
           {
            for(int i=1; i<st.fvgCount; i++)
               st.fvg[i-1]=st.fvg[i];
            st.fvgCount=X2_MAX_FVG-1;
           }
         st.fvg[st.fvgCount].top=bar.low;
         st.fvg[st.fvgCount].bot=bar.high2;
         st.fvg[st.fvgCount].srcBar=barIndex;
         st.fvg[st.fvgCount].dir=1;
         st.fvg[st.fvgCount].dead=false;
         st.fvgCount+=1;
        }
      if(bar.high<bar.low2 && (bar.low2-bar.high)>=cfg.fvgMinAtr*atr)
        {
         if(st.fvgCount>=X2_MAX_FVG)
           {
            for(int i=1; i<st.fvgCount; i++)
               st.fvg[i-1]=st.fvg[i];
            st.fvgCount=X2_MAX_FVG-1;
           }
         st.fvg[st.fvgCount].top=bar.low2;
         st.fvg[st.fvgCount].bot=bar.high;
         st.fvg[st.fvgCount].srcBar=barIndex;
         st.fvg[st.fvgCount].dir=-1;
         st.fvg[st.fvgCount].dead=false;
         st.fvgCount+=1;
        }
      if(st.fvgCount>cfg.fvgMax && st.fvgCount>0)
        {
         for(int i=1; i<st.fvgCount; i++)
            st.fvg[i-1]=st.fvg[i];
         st.fvgCount-=1;
        }
      for(int i=0; i<st.fvgCount; i++)
        {
         if(barIndex-st.fvg[i].srcBar>cfg.fvgLife)
            st.fvg[i].dead=true;
         if(st.fvg[i].dir==1 && bar.close<st.fvg[i].bot)
            st.fvg[i].dead=true;
         if(st.fvg[i].dir==-1 && bar.close>st.fvg[i].top)
            st.fvg[i].dead=true;
        }
     }

   if(dispBull && hasPrev && bar.prevClose<bar.prevOpen)
     {
      if(st.obCount>=X2_MAX_OB)
        {
         for(int i=1; i<st.obCount; i++)
            st.ob[i-1]=st.ob[i];
         st.obCount=X2_MAX_OB-1;
        }
      st.ob[st.obCount].top=MathMax(bar.prevOpen,bar.prevClose);
      st.ob[st.obCount].bot=MathMin(bar.prevOpen,bar.prevClose);
      st.ob[st.obCount].srcBar=barIndex-1;
      st.ob[st.obCount].dir=1;
      st.ob[st.obCount].dead=false;
      st.obCount+=1;
     }
   if(dispBear && hasPrev && bar.prevClose>bar.prevOpen)
     {
      if(st.obCount>=X2_MAX_OB)
        {
         for(int i=1; i<st.obCount; i++)
            st.ob[i-1]=st.ob[i];
         st.obCount=X2_MAX_OB-1;
        }
      st.ob[st.obCount].top=MathMax(bar.prevOpen,bar.prevClose);
      st.ob[st.obCount].bot=MathMin(bar.prevOpen,bar.prevClose);
      st.ob[st.obCount].srcBar=barIndex-1;
      st.ob[st.obCount].dir=-1;
      st.ob[st.obCount].dead=false;
      st.obCount+=1;
     }
   if(st.obCount>cfg.obMax && st.obCount>0)
     {
      for(int i=1; i<st.obCount; i++)
         st.ob[i-1]=st.ob[i];
      st.obCount-=1;
     }
   for(int i=0; i<st.obCount; i++)
     {
      if(st.ob[i].dir==1 && bar.close<st.ob[i].bot)
         st.ob[i].dead=true;
      if(st.ob[i].dir==-1 && bar.close>st.ob[i].top)
         st.ob[i].dead=true;
     }

   bool nearFvgBull=false;
   bool nearFvgBear=false;
   if(atrOk)
     {
      for(int i=0; i<st.fvgCount; i++)
        {
         if(st.fvg[i].dead)
            continue;
         if(bar.low>=st.fvg[i].bot-atr*0.3 && bar.low<=st.fvg[i].top+atr*0.3)
            nearFvgBull=true;
         if(bar.high>=st.fvg[i].bot-atr*0.3 && bar.high<=st.fvg[i].top+atr*0.3)
            nearFvgBear=true;
        }
      for(int i=0; i<st.obCount; i++)
        {
         if(st.ob[i].dead)
            continue;
         if(st.ob[i].dir==1 && bar.low>=st.ob[i].bot-atr*0.3
            && bar.low<=st.ob[i].top+atr*0.3)
            nearFvgBull=true;
         if(st.ob[i].dir==-1 && bar.high>=st.ob[i].bot-atr*0.3
            && bar.high<=st.ob[i].top+atr*0.3)
            nearFvgBear=true;
        }
     }

   const bool nearSupport=X2NearSupport(st,bar.low,atr);
   const bool nearResistance=X2NearResistance(st,bar.high,atr);

//--- L5: candles
   const double prevBody=(hasPrev ? MathAbs(bar.prevClose-bar.prevOpen) : EMPTY_VALUE);
   const bool bullPin=(bullBar && loWick>=cfg.pinRatio*body);
   const bool bearPin=(bearBar && hiWick>=cfg.pinRatio*body);
   const bool bullEng=(bullBar && hasPrev && bar.prevClose<bar.prevOpen
                       && bar.close>=bar.prevOpen && bar.open<=bar.prevClose
                       && body>=prevBody);
   const bool bearEng=(bearBar && hasPrev && bar.prevClose>bar.prevOpen
                       && bar.close<=bar.prevOpen && bar.open>=bar.prevClose
                       && body>=prevBody);
   const bool dispBullV=(dispBull && bullBar && volMaOk
                         && vol>=cfg.volSpikeR*bar.volMA);
   const bool dispBearV=(dispBear && bearBar && volMaOk
                         && vol>=cfg.volSpikeR*bar.volMA);
   const bool bullRej=(hiWick>=range*0.55 && loWick<=range*0.15 && bullBar);
   const bool bearRej=(loWick>=range*0.55 && hiWick<=range*0.15 && bearBar);

   double cpBull=0.0;
   double cpBear=0.0;
   if(cfg.pinOn)
     {
      cpBull+=(bullPin ? 1.0 : 0.0);
      cpBear+=(bearPin ? 1.0 : 0.0);
     }
   if(cfg.engulfOn)
     {
      cpBull+=(bullEng ? 1.0 : 0.0);
      cpBear+=(bearEng ? 1.0 : 0.0);
     }
   if(cfg.dispOn)
     {
      cpBull+=(dispBullV ? 1.2 : 0.0);
      cpBear+=(dispBearV ? 1.2 : 0.0);
     }
   if(cfg.rejOn)
     {
      cpBull+=(bullRej ? 0.8 : 0.0);
      cpBear+=(bearRej ? 0.8 : 0.0);
     }
   const double cpScore=(cpBull>cpBear ? MathMin(1.0,cpBull/3.0)
                         : cpBear>cpBull ? -MathMin(1.0,cpBear/3.0) : 0.0);

//--- L6: indicators / scores
   const double rsiScore=X2RsiScore(bar.rsi,cfg.rsiOs,cfg.rsiOb);
   const double macdScore=X2MacdScore(bar.macdHist,st.hasPrevMacd,st.prevMacdHist);
   const double dmiScore=X2DmiScore(bar.diPlus,bar.diMinus,bar.adx,cfg.adxMin);
   const double momScore=X2MomScore(rsiScore,macdScore,dmiScore);

   const double atrRegime=X2AtrRegime(atr,bar.atrMA);
   const bool bbExpand=(!X2IsEmpty(bar.bbWidth) && !X2IsEmpty(bar.bbWidthMA)
                        && bar.bbWidth>bar.bbWidthMA);
   const double volScore=(bbExpand ? (bar.close>bar.open ? 0.5 : -0.5) : 0.0);

   const double relVolScore=X2RelVolScore(relVol,cfg.rvMin,bar.close,bar.open);
   const double obvScore=X2ObvScore(obvSlope);
   const double vsaScore=X2VsaScore(isTim,bullBar,bearBar);
   const double volumeScore=X2VolumeScore(relVolScore,obvScore,vsaScore);

   const double vwapScore=(!X2IsEmpty(bar.vwap)
                           ? (bar.close>bar.vwap ? 1.0
                              : bar.close<bar.vwap ? -1.0 : 0.0) : 0.0);
   const double dayRange=X2DayRange(bar.close,bar.hasPd,bar.pdh,bar.pdl);
   const double locationScore=X2LocationScore(vwapScore,dayRange);

   const bool stackBull=(!X2IsEmpty(bar.emaF) && !X2IsEmpty(bar.emaM)
                         && !X2IsEmpty(bar.emaS)
                         && bar.emaF>bar.emaM && bar.emaM>bar.emaS);
   const bool stackBear=(!X2IsEmpty(bar.emaF) && !X2IsEmpty(bar.emaM)
                         && !X2IsEmpty(bar.emaS)
                         && bar.emaF<bar.emaM && bar.emaM<bar.emaS);
   const double trendScore=X2TrendScore(stackBull,stackBear,bar.close,
                                        bar.emaF,bar.emaM);

//--- L7: MTF
   const int ctxDir=(bar.htfCtxValid ? (bar.close>bar.htfCtxEma ? 1 : -1) : 0);
   const int setupDir=(bar.htfSetupValid ? (bar.close>bar.htfSetupEma ? 1 : -1) : 0);
   const double gMtfBias=((double)ctxDir+(double)setupDir)/2.0;

//--- L8: scoring
   const double gTrend=trendScore;
   const double gStruct=X2GroupStruct(st.bosUp,st.chochUp,st.mssUp,
                                      st.bosDown,st.chochDown,st.mssDown,st.trend);
   const double gLiq=X2GroupLiq(st.sweepBull,st.sweepBear,st.retestBull,
                                st.retestBear);
   const double gLoc=locationScore;
   const double gSr=X2GroupSr(nearSupport,nearResistance,nearFvgBull,nearFvgBear);
   const double gCandle=cpScore;
   const double gVolume=volumeScore;
   const double gVol=X2GroupVol(atrRegime,volScore,bar.close,bar.open);
   const double gMom=momScore;
   const double gSess=X2GroupSess(X2SessionScore(sessName),bar.close,bar.open);
   const double gMtf=gMtfBias;

   const double wTotal=cfg.wTrend+cfg.wStruct+cfg.wLiq+cfg.wLoc+cfg.wSr
                       +cfg.wCandle+cfg.wVol+cfg.wAtr+cfg.wMom+cfg.wSess+cfg.wMtf;
   const double wSum=cfg.wTrend*gTrend+cfg.wStruct*gStruct+cfg.wLiq*gLiq
                     +cfg.wLoc*gLoc+cfg.wSr*gSr+cfg.wCandle*gCandle
                     +cfg.wVol*gVolume+cfg.wAtr*gVol+cfg.wMom*gMom
                     +cfg.wSess*gSess+cfg.wMtf*gMtf;
   const double rawScore=X2RawScore(wSum,wTotal);
   const int score100=X2Score100(rawScore);
   const int dir=(rawScore>0.0 ? 1 : rawScore<0.0 ? -1 : 0);
   const int quality=X2Quality(score100,cfg.scrNoTrade,cfg.scrWeak,
                               cfg.scrSetup,cfg.scrStrong);

   const bool okSetup=X2OkSetup(cfg.htfFilter,setupDir,dir);
   const bool htfVeto=X2HtfVeto(cfg.htfVetoOn,ctxDir,dir);
   const bool okMtf=(okSetup && !htfVeto);

//--- L9: plan and gates
   X2Plan plan;
   X2BuildPlan(cfg,bar,dir,plan);

   const long dayIdx=X2DayIndex(bar.time);
   const bool newServerDay=(st.dayStamp>=0 && dayIdx!=st.dayStamp);
   st.dayStamp=dayIdx;
   st.weekStamp=X2WeekIndex(bar.time);

   if(newServerDay)
      st.dayCount=0;
   st.barsSince+=1;

   const bool okCool=(st.barsSince>=cfg.coolBars);
   const bool okDay=(st.dayCount<cfg.maxDay);
   const bool okScore=(score100>cfg.scrNoTrade);
   const bool okDir=(dir!=0);
   const bool okFilter=(okMtf && okCool && okDay && okScore && okDir);
   const bool signal=(plan.valid && okFilter);
   const bool sigLong=(signal && dir==1);
   const bool sigShort=(signal && dir==-1);

   int block=X2_BLOCK_NONE;
   if(!signal)
     {
      if(!plan.valid)
         block=X2_BLOCK_PLAN_INVALID;
      else if(!okSetup)
         block=X2_BLOCK_MTF_FILTER;
      else if(htfVeto)
         block=X2_BLOCK_HTF_VETO;
      else if(!okCool)
         block=X2_BLOCK_COOLDOWN;
      else if(!okDay)
         block=X2_BLOCK_DAY_LIMIT;
      else if(!okScore)
         block=X2_BLOCK_SCORE;
      else if(!okDir)
         block=X2_BLOCK_DIR;
     }

//--- L10: state machine
   if(st.needReset)
     {
      st.needReset=false;
      st.posDir=0;
      st.posBars=0;
      st.posStage=0;
      st.posEntry=EMPTY_VALUE;
      st.posSl=EMPTY_VALUE;
      st.posTp1=EMPTY_VALUE;
      st.posTp2=EMPTY_VALUE;
      st.posTp3=EMPTY_VALUE;
      st.posRisk=EMPTY_VALUE;
      st.posBar=-1;
     }

   if(st.posDir!=0)
     {
      const bool isUp=(st.posDir==1);
      const double t1=(st.posStage<1 ? st.posTp1 : EMPTY_VALUE);
      const double t2=(st.posStage<2 ? st.posTp2 : EMPTY_VALUE);
      const double t3=(st.posStage<3 ? st.posTp3 : EMPTY_VALUE);

      const bool hitSl=(!X2IsEmpty(st.posSl)
                        && (isUp ? bar.low<=st.posSl : bar.high>=st.posSl));
      const bool hit1=(!X2IsEmpty(t1) && (isUp ? bar.high>=t1 : bar.low<=t1));
      const bool hit2=(!X2IsEmpty(t2) && (isUp ? bar.high>=t2 : bar.low<=t2));
      const bool hit3=(!X2IsEmpty(t3) && (isUp ? bar.high>=t3 : bar.low<=t3));
      bool closed=false;

      if(hitSl && (hit1 || hit2 || hit3))
        {
         closed=true;
         st.evSl=true;
         st.evClose=true;
         st.closeReason=X2_CLOSE_SL;
         st.losses+=1;
        }
      else if(hitSl)
        {
         closed=true;
         st.evSl=true;
         st.evClose=true;
         st.closeReason=X2_CLOSE_SL;
         st.losses+=1;
        }
      else if(hit3)
        {
         st.evTp=3;
         st.posStage=3;
         closed=true;
         st.evClose=true;
         st.closeReason=X2_CLOSE_TP3;
         st.wins+=1;
        }
      else if(hit2)
        {
         st.evTp=2;
         st.posStage=2;
        }
      else if(hit1)
        {
         st.evTp=1;
         st.posStage=1;
        }

      if(!closed && st.posBars>300)
        {
         closed=true;
         st.evClose=true;
         st.closeReason=X2_CLOSE_TIMEOUT;
        }

      if(closed)
        {
         st.trades+=1;
         st.xEntry=st.posEntry;
         st.xSl=st.posSl;
         st.xDir=st.posDir;
         st.xBar=st.posBar;
         const double xExit=(st.evSl ? st.posSl
                             : st.evTp==3 ? st.posTp3
                             : st.evTp==2 ? st.posTp2 : st.posTp1);
         st.xExit=xExit;
         if(!X2IsEmpty(st.posRisk) && st.posRisk>0.0 && !X2IsEmpty(xExit))
            st.xR=(xExit-st.posEntry)*(double)st.posDir/st.posRisk;
         else
            st.xR=EMPTY_VALUE;
         st.needReset=true;
        }
     }

   if(signal && st.posDir==0)
     {
      st.posDir=plan.dir;
      st.posEntry=plan.entry;
      st.posSl=plan.sl;
      st.posTp1=plan.tp1;
      st.posTp2=plan.tp2;
      st.posTp3=plan.tp3;
      st.posRisk=plan.risk;
      st.posBars=0;
      st.posStage=0;
      st.posBar=barIndex;
      st.evEntry=true;
      st.dayCount+=1;
      st.barsSince=0;
     }

   if(st.posDir!=0 && !st.evEntry && !st.needReset)
      st.posBars+=1;

//--- VWAP accumulator kept in sync with bar (output uses pass-1 series)
   if(st.vwapStamp!=st.dayStamp)
     {
      st.vwapStamp=st.dayStamp;
      st.vwapPV=0.0;
      st.vwapVol=0.0;
     }
   st.vwapPV+=bar.close*bar.volume;
   st.vwapVol+=bar.volume;
   st.hasVwap=(st.vwapVol>0.0);

   //--- MACD previous-bar snapshot (next bar)
   if(!X2IsEmpty(bar.macdHist))
     {
      st.prevMacdHist=bar.macdHist;
      st.hasPrevMacd=true;
     }
   else
     {
      st.prevMacdHist=EMPTY_VALUE;
      st.hasPrevMacd=false;
     }

//--- outputs
   out.score100=score100;
   out.dir=dir;
   out.quality=quality;
   out.rawScore=rawScore;
   out.gTrend=gTrend;
   out.gStruct=gStruct;
   out.gLiq=gLiq;
   out.gLoc=gLoc;
   out.gSr=gSr;
   out.gCandle=gCandle;
   out.gVolume=gVolume;
   out.gVol=gVol;
   out.gMom=gMom;
   out.gSess=gSess;
   out.gMtf=gMtf;
   out.planValid=plan.valid;
   out.entry=plan.entry;
   out.sl=plan.sl;
   out.tp1=plan.tp1;
   out.tp2=plan.tp2;
   out.tp3=plan.tp3;
   out.risk=plan.risk;
   out.signal=signal;
   out.block=block;
   out.evEntry=st.evEntry;
   out.evTp=st.evTp;
   out.evSl=st.evSl;
   out.evClose=st.evClose;
   out.closeReason=st.closeReason;
   out.posDir=st.posDir;
   out.posEntry=st.posEntry;
   out.posSl=st.posSl;
   out.posTp1=st.posTp1;
   out.posTp2=st.posTp2;
   out.posTp3=st.posTp3;
   out.posRisk=st.posRisk;
   out.posStage=st.posStage;
   out.posBars=st.posBars;
   out.posBar=st.posBar;
   out.dayCount=st.dayCount;
   out.barsSince=st.barsSince;
   out.trades=st.trades;
   out.wins=st.wins;
   out.losses=st.losses;
   out.xEntry=st.xEntry;
   out.xSl=st.xSl;
   out.xDir=st.xDir;
   out.xBar=st.xBar;
   out.xExit=st.xExit;
   out.xR=st.xR;
   out.trend=st.trend;
   out.bosUp=st.bosUp;
   out.bosDown=st.bosDown;
   out.chochUp=st.chochUp;
   out.chochDown=st.chochDown;
   out.mssUp=st.mssUp;
   out.mssDown=st.mssDown;
   out.retestUp=st.retestBull;
   out.retestDown=st.retestBear;
   out.failUp=st.failBull;
   out.failDown=st.failBear;
   out.sweepUp=st.sweepBull;
   out.sweepDown=st.sweepBear;
   out.hh=st.isHH;
   out.hl=st.isHL;
   out.lh=st.isLH;
   out.ll=st.isLL;
   out.contUp=st.contBull;
   out.contDown=st.contBear;
   out.pullUp=st.pullBull;
   out.pullDown=st.pullBear;
   out.eqHi=st.eqHi;
   out.eqLo=st.eqLo;
   out.brkLevel=st.brkLevel;
   out.brkDir=st.brkDir;
   out.cpBull=cpBull;
   out.cpBear=cpBear;
   out.candleScore=cpScore;
   out.pinBull=bullPin;
   out.pinBear=bearPin;
   out.engBull=bullEng;
   out.engBear=bearEng;
   out.dispBull=dispBull;
   out.dispBear=dispBear;
   out.dispBullV=dispBullV;
   out.dispBearV=dispBearV;
   out.rejBull=bullRej;
   out.rejBear=bearRej;
   out.atr=atr;
   out.atrPct=(atrOk && bar.close!=0.0 ? atr/bar.close*100.0 : EMPTY_VALUE);
   out.atrMA=bar.atrMA;
   out.atrRegime=atrRegime;
   out.rsi=bar.rsi;
   out.macdHist=bar.macdHist;
   out.adx=bar.adx;
   out.diPlus=bar.diPlus;
   out.diMinus=bar.diMinus;
   out.bbWidth=bar.bbWidth;
   out.bbWidthMA=bar.bbWidthMA;
   out.bbExpand=bbExpand;
   out.volRatio=volRatio;
   out.volBucket=volBucket;
   out.isTim=isTim;
   out.relVol=relVol;
   out.obvSlope=obvSlope;
   out.vwap=bar.vwap;
   out.pdh=bar.pdh;
   out.pdl=bar.pdl;
   out.pwh=bar.pwh;
   out.pwl=bar.pwl;
   out.dayRange=dayRange;
   out.locationScore=locationScore;
   out.volumeScore=volumeScore;
   out.momScore=momScore;
   out.trendScore=trendScore;
   out.sessScore=X2SessionScore(sessName);
   out.sessName=sessName;
   out.sessHi=(st.hasSessHi ? st.sessHi : EMPTY_VALUE);
   out.sessLo=(st.hasSessLo ? st.sessLo : EMPTY_VALUE);
   out.mtfCtxDir=ctxDir;
   out.mtfSetupDir=setupDir;
   out.okSetup=okSetup;
   out.htfVeto=htfVeto;
   out.swingLo=bar.swingLo;
   out.swingHi=bar.swingHi;
   out.lastHigh=(st.hasLastHigh ? st.lastHigh : EMPTY_VALUE);
   out.lastLow=(st.hasLastLow ? st.lastLow : EMPTY_VALUE);
   out.nearSupport=nearSupport;
   out.nearResistance=nearResistance;
   out.nearFvgBull=nearFvgBull;
   out.nearFvgBear=nearFvgBear;
   out.srCount=st.srCount;
   out.fvgCount=st.fvgCount;
   out.obCount=st.obCount;
   if(st.evtCount>0)
     {
      const int last=st.evtCount-1;
      out.evtKind=st.evt[last].kind;
      out.evtDir=st.evt[last].dir;
      out.evtSrcBar=st.evt[last].srcBar;
      out.evtSrcTime=st.evt[last].srcTime;
      out.evtLevel=st.evt[last].level;
     }
   else
     {
      out.evtKind=X2_EVT_NONE;
      out.evtDir=0;
      out.evtSrcBar=-1;
      out.evtSrcTime=0;
      out.evtLevel=EMPTY_VALUE;
     }
   out.evtCount=st.evtCount;
  }

//+------------------------------------------------------------------+
//| Config clamps (contract section 3)                               |
//+------------------------------------------------------------------+
void X2NormalizeConfig(X2Config &cfg)
  {
   cfg.maxBars=X2ClampInt(cfg.maxBars,0,1000000);
   cfg.swingLen=X2ClampInt(cfg.swingLen,2,20);
   cfg.retestBars=X2ClampInt(cfg.retestBars,1,100);
   cfg.retestTolAtr=X2ClampMin(cfg.retestTolAtr,0.0);
   cfg.failBars=X2ClampInt(cfg.failBars,1,50);
   cfg.eqTolAtr=X2ClampMin(cfg.eqTolAtr,0.0);
   cfg.srLeft=X2ClampInt(cfg.srLeft,2,50);
   cfg.srRight=X2ClampInt(cfg.srRight,2,50);
   cfg.srWidthAtr=X2ClampMin(cfg.srWidthAtr,0.05);
   cfg.srMax=X2ClampInt(cfg.srMax,1,30);
   cfg.fvgMinAtr=X2ClampMin(cfg.fvgMinAtr,0.05);
   cfg.fvgMax=X2ClampInt(cfg.fvgMax,1,50);
   cfg.fvgLife=X2ClampInt(cfg.fvgLife,10,500);
   cfg.obMax=X2ClampInt(cfg.obMax,1,50);
   cfg.pinRatio=X2ClampMin(cfg.pinRatio,1.0);
   cfg.dispAtr=X2ClampMin(cfg.dispAtr,0.5);
   cfg.emaFast=X2ClampInt(cfg.emaFast,2,500);
   cfg.emaMid=X2ClampInt(cfg.emaMid,5,500);
   cfg.emaSlow=X2ClampInt(cfg.emaSlow,10,500);
   cfg.atrLen=X2ClampInt(cfg.atrLen,1,200);
   cfg.rsiLen=X2ClampInt(cfg.rsiLen,2,200);
   cfg.rsiOb=X2Clamp(cfg.rsiOb,50.0,99.0);
   cfg.rsiOs=X2Clamp(cfg.rsiOs,1.0,50.0);
   cfg.macdFast=X2ClampInt(cfg.macdFast,2,200);
   cfg.macdSlow=X2ClampInt(cfg.macdSlow,5,200);
   cfg.macdSignal=X2ClampInt(cfg.macdSignal,1,200);
   cfg.dmiLen=X2ClampInt(cfg.dmiLen,2,200);
   cfg.dmiSmooth=X2ClampInt(cfg.dmiSmooth,2,200);
   cfg.adxMin=X2Clamp(cfg.adxMin,0.0,100.0);
   cfg.bbLen=X2ClampInt(cfg.bbLen,2,200);
   cfg.bbMult=X2ClampMin(cfg.bbMult,0.5);
   cfg.rvLen=X2ClampInt(cfg.rvLen,2,200);
   cfg.rvMin=X2ClampMin(cfg.rvMin,0.5);
   cfg.obvLen=X2ClampInt(cfg.obvLen,2,200);
   cfg.volMaLen=X2ClampInt(cfg.volMaLen,5,100);
   cfg.volSpikeR=X2ClampMin(cfg.volSpikeR,1.5);
   cfg.volRVH=X2ClampMin(cfg.volRVH,1.0);
   cfg.volRH=X2ClampMin(cfg.volRH,0.8);
   cfg.volRN=X2ClampMin(cfg.volRN,0.4);
   cfg.volRL=X2ClampMin(cfg.volRL,0.1);
   cfg.volMin=X2ClampMin(cfg.volMin,0.0);
   cfg.volSessStartMin=X2ClampInt(cfg.volSessStartMin,0,1439);
   cfg.volSessEndMin=X2ClampInt(cfg.volSessEndMin,0,1439);
   cfg.ctxLen=X2ClampInt(cfg.ctxLen,10,500);
   cfg.setupLen=X2ClampInt(cfg.setupLen,5,500);
   cfg.wTrend=X2ClampMin(cfg.wTrend,0.0);
   cfg.wStruct=X2ClampMin(cfg.wStruct,0.0);
   cfg.wLiq=X2ClampMin(cfg.wLiq,0.0);
   cfg.wLoc=X2ClampMin(cfg.wLoc,0.0);
   cfg.wSr=X2ClampMin(cfg.wSr,0.0);
   cfg.wCandle=X2ClampMin(cfg.wCandle,0.0);
   cfg.wVol=X2ClampMin(cfg.wVol,0.0);
   cfg.wAtr=X2ClampMin(cfg.wAtr,0.0);
   cfg.wMom=X2ClampMin(cfg.wMom,0.0);
   cfg.wSess=X2ClampMin(cfg.wSess,0.0);
   cfg.wMtf=X2ClampMin(cfg.wMtf,0.0);
   cfg.scrNoTrade=X2ClampInt(cfg.scrNoTrade,0,99);
   cfg.scrWeak=X2ClampInt(cfg.scrWeak,1,99);
   cfg.scrSetup=X2ClampInt(cfg.scrSetup,1,99);
   cfg.scrStrong=X2ClampInt(cfg.scrStrong,1,99);
   cfg.slAtrMul=X2ClampMin(cfg.slAtrMul,0.1);
   cfg.slSwing=X2ClampInt(cfg.slSwing,2,100);
   cfg.slPadAtr=X2ClampMin(cfg.slPadAtr,0.0);
   cfg.slMinAtr=X2ClampMin(cfg.slMinAtr,0.1);
   cfg.slMaxAtr=X2ClampMin(cfg.slMaxAtr,0.5);
   cfg.rr1=X2ClampMin(cfg.rr1,0.1);
   cfg.rr2=X2ClampMin(cfg.rr2,0.1);
   cfg.rr3=X2ClampMin(cfg.rr3,0.1);
   cfg.rrMin=X2ClampMin(cfg.rrMin,0.0);
   cfg.maxDay=X2ClampInt(cfg.maxDay,1,1000000);
   cfg.coolBars=X2ClampInt(cfg.coolBars,0,1000000);
  }

//+------------------------------------------------------------------+
//| Config canonical string and FNV-1a 32-bit hash                   |
//+------------------------------------------------------------------+
void X2CanonI(string &s,const string key,const long value)
  {
   s+=";"+key+"="+IntegerToString(value);
  }

void X2CanonD(string &s,const string key,const double value)
  {
   s+=";"+key+"="+StringFormat("%.10g",value);
  }

string X2ConfigCanonical(const X2Config &cfg)
  {
   string s="v="+X2_CONTRACT_VERSION;
   X2CanonI(s,"srv",cfg.srvOffsetMin);
   X2CanonI(s,"mkt",cfg.mktOffsetMin);
   X2CanonI(s,"volOff",cfg.volSessOffsetMin);
   X2CanonI(s,"maxBars",cfg.maxBars);
   X2CanonI(s,"swingLen",cfg.swingLen);
   X2CanonI(s,"retestOn",(int)cfg.retestOn);
   X2CanonI(s,"retestBars",cfg.retestBars);
   X2CanonD(s,"retestTolAtr",cfg.retestTolAtr);
   X2CanonI(s,"failOn",(int)cfg.failOn);
   X2CanonI(s,"failBars",cfg.failBars);
   X2CanonI(s,"contOn",(int)cfg.contOn);
   X2CanonI(s,"pullOn",(int)cfg.pullOn);
   X2CanonD(s,"eqTolAtr",cfg.eqTolAtr);
   X2CanonI(s,"pdOn",(int)cfg.pdOn);
   X2CanonI(s,"pwOn",(int)cfg.pwOn);
   X2CanonI(s,"sessOn",(int)cfg.sessOn);
   X2CanonI(s,"srLeft",cfg.srLeft);
   X2CanonI(s,"srRight",cfg.srRight);
   X2CanonD(s,"srWidthAtr",cfg.srWidthAtr);
   X2CanonI(s,"srMax",cfg.srMax);
   X2CanonD(s,"fvgMinAtr",cfg.fvgMinAtr);
   X2CanonI(s,"fvgMax",cfg.fvgMax);
   X2CanonI(s,"fvgLife",cfg.fvgLife);
   X2CanonI(s,"obMax",cfg.obMax);
   X2CanonD(s,"pinRatio",cfg.pinRatio);
   X2CanonI(s,"engulfOn",(int)cfg.engulfOn);
   X2CanonI(s,"pinOn",(int)cfg.pinOn);
   X2CanonI(s,"dispOn",(int)cfg.dispOn);
   X2CanonD(s,"dispAtr",cfg.dispAtr);
   X2CanonI(s,"rejOn",(int)cfg.rejOn);
   X2CanonI(s,"emaFast",cfg.emaFast);
   X2CanonI(s,"emaMid",cfg.emaMid);
   X2CanonI(s,"emaSlow",cfg.emaSlow);
   X2CanonI(s,"atrLen",cfg.atrLen);
   X2CanonI(s,"rsiLen",cfg.rsiLen);
   X2CanonD(s,"rsiOb",cfg.rsiOb);
   X2CanonD(s,"rsiOs",cfg.rsiOs);
   X2CanonI(s,"macdFast",cfg.macdFast);
   X2CanonI(s,"macdSlow",cfg.macdSlow);
   X2CanonI(s,"macdSignal",cfg.macdSignal);
   X2CanonI(s,"dmiLen",cfg.dmiLen);
   X2CanonI(s,"dmiSmooth",cfg.dmiSmooth);
   X2CanonD(s,"adxMin",cfg.adxMin);
   X2CanonI(s,"bbLen",cfg.bbLen);
   X2CanonD(s,"bbMult",cfg.bbMult);
   X2CanonI(s,"rvLen",cfg.rvLen);
   X2CanonD(s,"rvMin",cfg.rvMin);
   X2CanonI(s,"obvLen",cfg.obvLen);
   X2CanonI(s,"volMaLen",cfg.volMaLen);
   X2CanonD(s,"volSpikeR",cfg.volSpikeR);
   X2CanonD(s,"volRVH",cfg.volRVH);
   X2CanonD(s,"volRH",cfg.volRH);
   X2CanonD(s,"volRN",cfg.volRN);
   X2CanonD(s,"volRL",cfg.volRL);
   X2CanonD(s,"volMin",cfg.volMin);
   X2CanonI(s,"volSessOn",(int)cfg.volSessOn);
   X2CanonI(s,"volSessStartMin",cfg.volSessStartMin);
   X2CanonI(s,"volSessEndMin",cfg.volSessEndMin);
   X2CanonI(s,"ctxTf",(int)cfg.ctxTf);
   X2CanonI(s,"ctxLen",cfg.ctxLen);
   X2CanonI(s,"setupTf",(int)cfg.setupTf);
   X2CanonI(s,"setupLen",cfg.setupLen);
   X2CanonI(s,"htfFilter",(int)cfg.htfFilter);
   X2CanonI(s,"htfVetoOn",(int)cfg.htfVetoOn);
   X2CanonD(s,"wTrend",cfg.wTrend);
   X2CanonD(s,"wStruct",cfg.wStruct);
   X2CanonD(s,"wLiq",cfg.wLiq);
   X2CanonD(s,"wLoc",cfg.wLoc);
   X2CanonD(s,"wSr",cfg.wSr);
   X2CanonD(s,"wCandle",cfg.wCandle);
   X2CanonD(s,"wVol",cfg.wVol);
   X2CanonD(s,"wAtr",cfg.wAtr);
   X2CanonD(s,"wMom",cfg.wMom);
   X2CanonD(s,"wSess",cfg.wSess);
   X2CanonD(s,"wMtf",cfg.wMtf);
   X2CanonI(s,"scrNoTrade",cfg.scrNoTrade);
   X2CanonI(s,"scrWeak",cfg.scrWeak);
   X2CanonI(s,"scrSetup",cfg.scrSetup);
   X2CanonI(s,"scrStrong",cfg.scrStrong);
   X2CanonD(s,"slAtrMul",cfg.slAtrMul);
   X2CanonI(s,"slSwing",cfg.slSwing);
   X2CanonD(s,"slPadAtr",cfg.slPadAtr);
   X2CanonD(s,"slMinAtr",cfg.slMinAtr);
   X2CanonD(s,"slMaxAtr",cfg.slMaxAtr);
   X2CanonD(s,"rr1",cfg.rr1);
   X2CanonD(s,"rr2",cfg.rr2);
   X2CanonD(s,"rr3",cfg.rr3);
   X2CanonD(s,"rrMin",cfg.rrMin);
   X2CanonI(s,"maxDay",cfg.maxDay);
   X2CanonI(s,"coolBars",cfg.coolBars);
   return(s);
  }

uint X2Fnv1a(const string text)
  {
   uint hash=(uint)2166136261;
   for(int i=0; i<StringLen(text); i++)
     {
      hash^=(uint)(StringGetCharacter(text,i)&0xFF);
      hash=(uint)(hash*(uint)16777619);
     }
   return(hash);
  }

uint X2ConfigHash(const X2Config &cfg)
  {
   return(X2Fnv1a(X2_CONTRACT_VERSION+"|"+X2ConfigCanonical(cfg)));
  }

#endif // TMXAUSIGNALS2_CONTRACT_MQH
