//+------------------------------------------------------------------+
//|                                  PriceActionMTFContract.mqh      |
//|     MT5 EA & AI Lab - PinePort buffer contract and pure logic    |
//|                                                                  |
//| No file I/O, no account access, no trading functions.            |
//| Contract: docs/indicators/price-action-mtf.md                 |
//+------------------------------------------------------------------+
#ifndef PRICEACTIONMTF_CONTRACT_MQH
#define PRICEACTIONMTF_CONTRACT_MQH

#define PA_CONTRACT_VERSION   "1.0.0"
#define PA_PLOT_BUFFERS       12
#define PA_CONTRACT_FIRST     12
#define PA_CONTRACT_BUFFERS   95
#define PA_TOTAL_BUFFERS      107
#define PA_MAX_SR             30
#define PA_MAX_FVG            50
#define PA_MAX_OB             50
#define PA_MAX_PAT            30
#define PA_PIV_HIST           4
#define PA_OBV_MAX            202
#define PA_BBW_MAX            500

enum ENUM_PA_TP_MODE
  {
   PA_TP_R  = 0,
   PA_TP_MM = 1
  };

enum ENUM_PA_QUALITY
  {
   PA_Q_NOTRADE = 0,
   PA_Q_WEAK    = 1,
   PA_Q_SETUP   = 2,
   PA_Q_STRONG  = 3,
   PA_Q_APLUS   = 4
  };

enum ENUM_PA_REGIME
  {
   PA_REG_RANGING  = 0,
   PA_REG_TRENDING = 1,
   PA_REG_CHOPPY   = 2
  };

enum ENUM_PA_PATTERN
  {
   PA_PAT_NONE = 0,
   PA_PAT_DT   = 1,
   PA_PAT_DB   = 2,
   PA_PAT_HST  = 3,
   PA_PAT_HSN  = 4
  };

enum ENUM_PA_BUCKET
  {
   PA_BUCKET_VERYLOW  = 0,
   PA_BUCKET_LOW      = 1,
   PA_BUCKET_NORMAL   = 2,
   PA_BUCKET_HIGH     = 3,
   PA_BUCKET_VERYHIGH = 4,
   PA_BUCKET_TIM      = 5
  };

enum ENUM_PA_SESSION
  {
   PA_SESS_NONE      = 0,
   PA_SESS_ASIA      = 1,
   PA_SESS_LONDON    = 2,
   PA_SESS_NY        = 3,
   PA_SESS_LONDON_NY = 4
  };

enum ENUM_PA_CLOSE
  {
   PA_CLOSE_NONE    = 0,
   PA_CLOSE_TP3     = 1,
   PA_CLOSE_SL      = 2,
   PA_CLOSE_TIMEOUT = 3
  };

enum ENUM_PA_BLOCK
  {
   PA_BLOCK_NONE         = 0,
   PA_BLOCK_PLAN_INVALID = 1,
   PA_BLOCK_MTF_FILTER   = 2,
   PA_BLOCK_HTF_VETO     = 3,
   PA_BLOCK_COOLDOWN     = 4,
   PA_BLOCK_DAY_LIMIT    = 5,
   PA_BLOCK_SCORE        = 6,
   PA_BLOCK_DIR          = 7,
   PA_BLOCK_CONFLUENCE   = 8,
   PA_BLOCK_REGIME       = 9
  };

enum ENUM_PA_BUFFER
  {
   PA_BUF_SCORE100        = 12,
   PA_BUF_DIR             = 13,
   PA_BUF_QUALITY         = 14,
   PA_BUF_CONFLUENCE      = 15,
   PA_BUF_REGIME          = 16,
   PA_BUF_PLAN_VALID      = 17,
   PA_BUF_ENTRY           = 18,
   PA_BUF_SL              = 19,
   PA_BUF_TP1             = 20,
   PA_BUF_TP2             = 21,
   PA_BUF_TP3             = 22,
   PA_BUF_RISK            = 23,
   PA_BUF_SIG_LONG        = 24,
   PA_BUF_SIG_SHORT       = 25,
   PA_BUF_BLOCK           = 26,
   PA_BUF_EV_ENTRY        = 27,
   PA_BUF_EV_TP1          = 28,
   PA_BUF_EV_TP2          = 29,
   PA_BUF_EV_TP3          = 30,
   PA_BUF_EV_SL           = 31,
   PA_BUF_EV_CLOSE        = 32,
   PA_BUF_CLOSE_REASON    = 33,
   PA_BUF_POS_DIR         = 34,
   PA_BUF_POS_ENTRY       = 35,
   PA_BUF_POS_SL          = 36,
   PA_BUF_POS_TP1         = 37,
   PA_BUF_POS_TP2         = 38,
   PA_BUF_POS_TP3         = 39,
   PA_BUF_POS_RISK        = 40,
   PA_BUF_POS_STAGE       = 41,
   PA_BUF_POS_BARS        = 42,
   PA_BUF_DAY_COUNT       = 43,
   PA_BUF_BARS_SINCE      = 44,
   PA_BUF_TRADES          = 45,
   PA_BUF_WINS            = 46,
   PA_BUF_LOSSES          = 47,
   PA_BUF_TREND           = 48,
   PA_BUF_BOS_UP          = 49,
   PA_BUF_BOS_DOWN        = 50,
   PA_BUF_CHOCH_UP        = 51,
   PA_BUF_CHOCH_DOWN      = 52,
   PA_BUF_MSS_UP          = 53,
   PA_BUF_MSS_DOWN        = 54,
   PA_BUF_RETEST_UP       = 55,
   PA_BUF_RETEST_DOWN     = 56,
   PA_BUF_FAIL_UP         = 57,
   PA_BUF_FAIL_DOWN       = 58,
   PA_BUF_SWEEP_UP        = 59,
   PA_BUF_SWEEP_DOWN      = 60,
   PA_BUF_HH              = 61,
   PA_BUF_HL              = 62,
   PA_BUF_LH              = 63,
   PA_BUF_LL              = 64,
   PA_BUF_CONT_UP         = 65,
   PA_BUF_CONT_DOWN       = 66,
   PA_BUF_PULL_UP         = 67,
   PA_BUF_PULL_DOWN       = 68,
   PA_BUF_PATTERN         = 69,
   PA_BUF_PATTERN_DIR     = 70,
   PA_BUF_PATTERN_HEIGHT  = 71,
   PA_BUF_CANDLE_SCORE    = 72,
   PA_BUF_ATR             = 73,
   PA_BUF_ATR_PCT         = 74,
   PA_BUF_RSI             = 75,
   PA_BUF_MACD_HIST       = 76,
   PA_BUF_ADX             = 77,
   PA_BUF_DI_PLUS         = 78,
   PA_BUF_DI_MINUS        = 79,
   PA_BUF_BB_WIDTH        = 80,
   PA_BUF_VOL_RATIO       = 81,
   PA_BUF_REL_VOL         = 82,
   PA_BUF_OBV_SLOPE       = 83,
   PA_BUF_VWAP            = 84,
   PA_BUF_PDH             = 85,
   PA_BUF_PDL             = 86,
   PA_BUF_PWH             = 87,
   PA_BUF_PWL             = 88,
   PA_BUF_SESS_HI         = 89,
   PA_BUF_SESS_LO         = 90,
   PA_BUF_VOL_BUCKET      = 91,
   PA_BUF_SESS_NAME       = 92,
   PA_BUF_MTF_CTX_DIR     = 93,
   PA_BUF_MTF_SETUP_DIR   = 94,
   PA_BUF_HTF_VETO        = 95,
   PA_BUF_CF1             = 96,
   PA_BUF_CF2             = 97,
   PA_BUF_CF3             = 98,
   PA_BUF_NEAR_SUPPORT    = 99,
   PA_BUF_NEAR_RESISTANCE = 100,
   PA_BUF_NEAR_FVG_BULL   = 101,
   PA_BUF_NEAR_FVG_BEAR   = 102,
   PA_BUF_SWING_LO        = 103,
   PA_BUF_SWING_HI        = 104,
   PA_BUF_LAST_HIGH       = 105,
   PA_BUF_LAST_LOW        = 106
  };

struct PaConfig
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
   bool   ibOn;
   bool   dojiOn;
   double dojiMax;
   bool   soldOn;
   double strongBody;
   bool   volVetoOn;
   double volVetoR;
   bool   streakOn;
   int    streakMin;
   double streakAdd;
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
   ENUM_PA_TP_MODE tpMode;
   bool   tpMmFallback;
   bool   regOn;
   double regAdxTrend;
   double regAdxChop;
   int    regBbwLen;
   double regBbwSqueeze;
   double regRangeEdge;
   bool   patOn;
   double patBandAtr;
   int    patMaxBars;
   double hsRatio;
   bool   cfOn;
   double cfLevelTolAtr;
   bool   cfRequire3;
  };

struct PaSrZone
  {
   double top;
   double bot;
   int    side;
   int    touches;
   bool   broken;
  };

struct PaFvg
  {
   double top;
   double bot;
   int    srcBar;
   int    dir;
   bool   dead;
  };

struct PaOb
  {
   double top;
   double bot;
   int    srcBar;
   int    dir;
   bool   dead;
  };

struct PaPattern
  {
   int    kind;
   int    dir;
   double a;
   double b;
   double c;
   double neck;
   int    aBar;
   int    bBar;
   int    cBar;
   bool   broken;
   int    brkBar;
  };

struct PaEngineState
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
   //--- trendline pivots (2 each side)
   double tl1Lo;
   double tl2Lo;
   double tl1Hi;
   double tl2Hi;
   int    tl1LoB;
   int    tl2LoB;
   int    tl1HiB;
   int    tl2HiB;
   bool   hasTl1Lo;
   bool   hasTl2Lo;
   bool   hasTl1Hi;
   bool   hasTl2Hi;
   //--- session
   double sessHi;
   double sessLo;
   int    sessPrev;
   bool   hasSessHi;
   bool   hasSessLo;
   //--- patterns
   PaPattern pats[PA_MAX_PAT];
   int    patCount;
   double hiPx[PA_PIV_HIST];
   double loPx[PA_PIV_HIST];
   int    hiBar[PA_PIV_HIST];
   int    loBar[PA_PIV_HIST];
   int    hiCount;
   int    loCount;
   double patHeight;
   //--- zones
   PaSrZone sr[PA_MAX_SR];
   int    srCount;
   PaFvg    fvg[PA_MAX_FVG];
   int    fvgCount;
   PaOb     ob[PA_MAX_OB];
   int    obCount;
   //--- candle streak
   int    engulfStreak;
   //--- OBV window
   double obv;
   double obvHist[PA_OBV_MAX];
   int    obvCount;
   //--- day / week
   int    dayStamp;
   int    weekStamp;
   double curDayHi;
   double curDayLo;
   double curWeekHi;
   double curWeekLo;
   double pdh;
   double pdl;
   double pwh;
   double pwl;
   bool   hasDay;
   bool   hasPd;
   bool   hasPw;
   //--- VWAP
   int    vwapStamp;
   double vwapPV;
   double vwapVol;
   bool   hasVwap;
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
   //--- events of the current bar
   bool   evEntry;
   bool   evTp1;
   bool   evTp2;
   bool   evTp3;
   bool   evSl;
   bool   evClose;
   int    closeReason;
   //--- previous bar snapshot (internal, needed by pattern/engulf/OB logic)
   bool   hasPrev;
   datetime pbTime;
   double pbOpen;
   double pbHigh;
   double pbLow;
   double pbClose;
   bool   hasPrev2;
   double pb2Open;
   double pb2High;
   double pb2Low;
   double pb2Close;
   bool   hasPrevMacd;
   double prevMacdHist;
   //--- BBW percentile window
   double bbwHist[PA_BBW_MAX];
   int    bbwCount;
  };

struct PaBar
  {
   datetime time;
   double   open;
   double   high;
   double   low;
   double   close;
   double   volume;
   double   tickSize;
   //--- precomputed series (pass 1)
   double   atr;
   double   volMA;
   double   volSma;
   double   emaF;
   double   emaM;
   double   emaS;
   double   swingLo;
   double   swingHi;
   double   pivH;
   bool     pivHValid;
   double   pivL;
   bool     pivLValid;
   double   srPivH;
   bool     srPivHValid;
   double   srPivL;
   bool     srPivLValid;
   double   pivNeckLow;   // min low between last two pivot highs (DT/HST)
   double   pivNeckHigh;  // max high between last two pivot lows (DB/HSN)
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
   double   atrMA;
   double   htfCtxEma;
   bool     htfCtxValid;
   double   htfSetupEma;
   bool     htfSetupValid;
  };

struct PaPlan
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

struct PaBarOut
  {
   int    score100;
   int    dir;
   int    quality;
   int    confluence;
   int    regime;
   bool   planValid;
   double entry;
   double sl;
   double tp1;
   double tp2;
   double tp3;
   double risk;
   bool   sigLong;
   bool   sigShort;
   int    block;
   bool   evEntry;
   bool   evTp1;
   bool   evTp2;
   bool   evTp3;
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
   int    dayCount;
   int    barsSince;
   int    trades;
   int    wins;
   int    losses;
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
   int    pattern;
   int    patternDir;
   double patternHeight;
   double candleScore;
   double atr;
   double atrPct;
   double rsi;
   double macdHist;
   double adx;
   double diPlus;
   double diMinus;
   double bbWidth;
   double volRatio;
   double relVol;
   double obvSlope;
   double vwap;
   double pdh;
   double pdl;
   double pwh;
   double pwl;
   double sessHi;
   double sessLo;
   int    volBucket;
   int    sessName;
   int    mtfCtxDir;
   int    mtfSetupDir;
   bool   htfVeto;
   bool   cf1;
   bool   cf2;
   bool   cf3;
   bool   nearSupport;
   bool   nearResistance;
   bool   nearFvgBull;
   bool   nearFvgBear;
   double swingLo;
   double swingHi;
   double lastHigh;
   double lastLow;
  };

//+------------------------------------------------------------------+
//| Math helpers                                                     |
//+------------------------------------------------------------------+
bool PaIsEmpty(const double value)
  {
   return(value==EMPTY_VALUE || value==-EMPTY_VALUE || !MathIsValidNumber(value));
  }

double PaClamp(const double value,const double low,const double high)
  {
   if(PaIsEmpty(value) || PaIsEmpty(low) || PaIsEmpty(high))
      return(EMPTY_VALUE);
   return(MathMax(low,MathMin(high,value)));
  }

double PaTrueRange(const bool hasPrev,const double high,const double low,
                   const double prevClose)
  {
   const double range=high-low;
   if(!hasPrev)
      return(range);
   return(MathMax(range,MathMax(MathAbs(high-prevClose),MathAbs(low-prevClose))));
  }

bool PaInBand(const double x,const double y,const double band)
  {
   if(PaIsEmpty(x) || PaIsEmpty(y) || PaIsEmpty(band))
      return(false);
   return(MathAbs(x-y)<=band);
  }

int PaClampInt(const int value,const int low,const int high)
  {
   return((int)MathMax((double)low,MathMin((double)high,(double)value)));
  }

double PaClampMin(const double value,const double low)
  {
   if(PaIsEmpty(value))
      return(low);
   return(MathMax(low,value));
  }

//+------------------------------------------------------------------+
//| Config clamps (contract section 3)                               |
//+------------------------------------------------------------------+
void PaNormalizeConfig(PaConfig &cfg)
  {
   cfg.swingLen=PaClampInt(cfg.swingLen,2,20);
   cfg.retestBars=PaClampInt(cfg.retestBars,1,100);
   cfg.retestTolAtr=PaClampMin(cfg.retestTolAtr,0.0);
   cfg.failBars=PaClampInt(cfg.failBars,1,50);
   cfg.eqTolAtr=PaClampMin(cfg.eqTolAtr,0.0);
   cfg.srLeft=PaClampInt(cfg.srLeft,2,50);
   cfg.srRight=PaClampInt(cfg.srRight,2,50);
   cfg.srWidthAtr=PaClampMin(cfg.srWidthAtr,0.05);
   cfg.srMax=PaClampInt(cfg.srMax,1,30);
   cfg.fvgMinAtr=PaClampMin(cfg.fvgMinAtr,0.05);
   cfg.fvgMax=PaClampInt(cfg.fvgMax,1,50);
   cfg.fvgLife=PaClampInt(cfg.fvgLife,10,500);
   cfg.obMax=PaClampInt(cfg.obMax,1,50);
   cfg.pinRatio=PaClampMin(cfg.pinRatio,1.0);
   cfg.dispAtr=PaClampMin(cfg.dispAtr,0.5);
   cfg.dojiMax=PaClamp(cfg.dojiMax,0.01,0.5);
   cfg.strongBody=PaClamp(cfg.strongBody,0.1,0.95);
   cfg.volVetoR=PaClampMin(cfg.volVetoR,0.5);
   cfg.streakMin=PaClampInt(cfg.streakMin,2,5);
   cfg.streakAdd=PaClamp(cfg.streakAdd,0.0,2.0);
   cfg.emaFast=PaClampInt(cfg.emaFast,2,500);
   cfg.emaMid=PaClampInt(cfg.emaMid,5,500);
   cfg.emaSlow=PaClampInt(cfg.emaSlow,10,500);
   cfg.atrLen=PaClampInt(cfg.atrLen,1,200);
   cfg.rsiLen=PaClampInt(cfg.rsiLen,2,200);
   cfg.rsiOb=PaClamp(cfg.rsiOb,50.0,99.0);
   cfg.rsiOs=PaClamp(cfg.rsiOs,1.0,50.0);
   cfg.macdFast=PaClampInt(cfg.macdFast,2,200);
   cfg.macdSlow=PaClampInt(cfg.macdSlow,5,200);
   cfg.macdSignal=PaClampInt(cfg.macdSignal,1,200);
   cfg.dmiLen=PaClampInt(cfg.dmiLen,2,200);
   cfg.dmiSmooth=PaClampInt(cfg.dmiSmooth,2,200);
   cfg.adxMin=PaClamp(cfg.adxMin,0.0,100.0);
   cfg.bbLen=PaClampInt(cfg.bbLen,2,200);
   cfg.bbMult=PaClampMin(cfg.bbMult,0.5);
   cfg.rvLen=PaClampInt(cfg.rvLen,2,200);
   cfg.rvMin=PaClampMin(cfg.rvMin,0.5);
   cfg.obvLen=PaClampInt(cfg.obvLen,2,200);
   cfg.volMaLen=PaClampInt(cfg.volMaLen,5,100);
   cfg.volSpikeR=PaClampMin(cfg.volSpikeR,1.5);
   cfg.volRVH=PaClampMin(cfg.volRVH,1.0);
   cfg.volRH=PaClampMin(cfg.volRH,0.8);
   cfg.volRN=PaClampMin(cfg.volRN,0.4);
   cfg.volRL=PaClampMin(cfg.volRL,0.1);
   cfg.volMin=PaClampMin(cfg.volMin,0.0);
   cfg.volSessStartMin=PaClampInt(cfg.volSessStartMin,0,1439);
   cfg.volSessEndMin=PaClampInt(cfg.volSessEndMin,0,1439);
   cfg.ctxLen=PaClampInt(cfg.ctxLen,10,500);
   cfg.setupLen=PaClampInt(cfg.setupLen,5,500);
   cfg.wTrend=PaClampMin(cfg.wTrend,0.0);
   cfg.wStruct=PaClampMin(cfg.wStruct,0.0);
   cfg.wLiq=PaClampMin(cfg.wLiq,0.0);
   cfg.wLoc=PaClampMin(cfg.wLoc,0.0);
   cfg.wSr=PaClampMin(cfg.wSr,0.0);
   cfg.wCandle=PaClampMin(cfg.wCandle,0.0);
   cfg.wVol=PaClampMin(cfg.wVol,0.0);
   cfg.wAtr=PaClampMin(cfg.wAtr,0.0);
   cfg.wMom=PaClampMin(cfg.wMom,0.0);
   cfg.wSess=PaClampMin(cfg.wSess,0.0);
   cfg.wMtf=PaClampMin(cfg.wMtf,0.0);
   cfg.scrNoTrade=PaClampInt(cfg.scrNoTrade,0,99);
   cfg.scrWeak=PaClampInt(cfg.scrWeak,1,99);
   cfg.scrSetup=PaClampInt(cfg.scrSetup,1,99);
   cfg.scrStrong=PaClampInt(cfg.scrStrong,1,99);
   cfg.slAtrMul=PaClampMin(cfg.slAtrMul,0.1);
   cfg.slSwing=PaClampInt(cfg.slSwing,2,100);
   cfg.slPadAtr=PaClampMin(cfg.slPadAtr,0.0);
   cfg.slMinAtr=PaClampMin(cfg.slMinAtr,0.1);
   cfg.slMaxAtr=PaClampMin(cfg.slMaxAtr,0.5);
   cfg.rr1=PaClampMin(cfg.rr1,0.1);
   cfg.rr2=PaClampMin(cfg.rr2,0.1);
   cfg.rr3=PaClampMin(cfg.rr3,0.1);
   cfg.rrMin=PaClampMin(cfg.rrMin,0.0);
   cfg.maxDay=PaClampInt(cfg.maxDay,1,1000000);
   cfg.coolBars=PaClampInt(cfg.coolBars,0,1000000);
   cfg.regAdxTrend=PaClamp(cfg.regAdxTrend,5.0,60.0);
   cfg.regAdxChop=PaClamp(cfg.regAdxChop,5.0,60.0);
   cfg.regBbwLen=PaClampInt(cfg.regBbwLen,20,500);
   cfg.regBbwSqueeze=PaClamp(cfg.regBbwSqueeze,1.0,60.0);
   cfg.regRangeEdge=PaClamp(cfg.regRangeEdge,0.0,2.0);
   cfg.patBandAtr=PaClamp(cfg.patBandAtr,0.1,3.0);
   cfg.patMaxBars=PaClampInt(cfg.patMaxBars,20,1000);
   cfg.hsRatio=PaClamp(cfg.hsRatio,1.0,3.0);
   cfg.cfLevelTolAtr=PaClamp(cfg.cfLevelTolAtr,0.1,3.0);
   cfg.maxBars=PaClampInt(cfg.maxBars,0,1000000);
  }

//+------------------------------------------------------------------+
//| Series builders (pass 1)                                         |
//+------------------------------------------------------------------+
void PaBuildSma(const double &src[],const int total,const int len,double &out[])
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
         if(PaIsEmpty(src[i]))
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

void PaBuildEma(const double &src[],const int total,const int len,double &out[])
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
            if(PaIsEmpty(src[i]))
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
         if(PaIsEmpty(value) || PaIsEmpty(src[j]))
            value=EMPTY_VALUE;
         else
            value=alpha*src[j]+(1.0-alpha)*value;
        }
      out[j]=value;
     }
  }

void PaBuildRma(const double &src[],const int total,const int len,double &out[])
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
            if(PaIsEmpty(src[i]))
              {
               ok=false;
               break;
              }
            sum+=src[i];
           }
         out[j]=(ok ? sum/(double)len : EMPTY_VALUE);
         continue;
        }
      if(PaIsEmpty(out[j-1]) || PaIsEmpty(src[j]))
         continue;
      out[j]=(((double)(len-1))*out[j-1]+src[j])/(double)len;
     }
  }

void PaBuildAtr(const double &high[],const double &low[],const double &close[],
                const int total,const int len,double &out[])
  {
   ArrayResize(out,0);
   if(total<=0 || ArraySize(high)<total || ArraySize(low)<total || ArraySize(close)<total)
      return;
   double tr[];
   ArrayResize(tr,total);
   for(int j=0; j<total; j++)
      tr[j]=PaTrueRange(j>0,high[j],low[j],(j>0 ? close[j-1] : close[j]));
   PaBuildRma(tr,total,len,out);
  }

void PaBuildRsi(const double &src[],const int total,const int len,double &out[])
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
      if(PaIsEmpty(src[j]) || PaIsEmpty(src[j-1]))
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
         if(PaIsEmpty(avgGain) || PaIsEmpty(avgLoss))
            continue;
         avgGain=(((double)(len-1))*avgGain+gain)/(double)len;
         avgLoss=(((double)(len-1))*avgLoss+loss)/(double)len;
        }
      if(j>=len && !PaIsEmpty(avgGain) && !PaIsEmpty(avgLoss))
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

void PaBuildMacdHist(const double &src[],const int total,const int fast,const int slow,
                     const int sig,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0 || fast<=0 || slow<=0 || sig<=0 || ArraySize(src)<total)
      return;
   double emaFast[];
   double emaSlow[];
   PaBuildEma(src,total,fast,emaFast);
   PaBuildEma(src,total,slow,emaSlow);
   double line[];
   ArrayResize(line,total);
   ArrayInitialize(line,EMPTY_VALUE);
   for(int j=0; j<total; j++)
     {
      if(!PaIsEmpty(emaFast[j]) && !PaIsEmpty(emaSlow[j]))
         line[j]=emaFast[j]-emaSlow[j];
     }
   double signal[];
   PaBuildEma(line,total,sig,signal);
   for(int j=0; j<total; j++)
     {
      if(!PaIsEmpty(line[j]) && !PaIsEmpty(signal[j]))
         out[j]=line[j]-signal[j];
     }
  }

void PaBuildDmi(const double &high[],const double &low[],const double &close[],
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
      tr[j]=PaTrueRange(j>0,high[j],low[j],(j>0 ? close[j-1] : close[j]));
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
   PaBuildRma(tr,total,len,trSm);
   PaBuildRma(dmPos,total,len,posSm);
   PaBuildRma(dmNeg,total,len,negSm);
   double dx[];
   ArrayResize(dx,total);
   ArrayInitialize(dx,EMPTY_VALUE);
   for(int j=0; j<total; j++)
     {
      if(PaIsEmpty(trSm[j]) || PaIsEmpty(posSm[j]) || PaIsEmpty(negSm[j]))
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
   PaBuildRma(dx,total,smooth,adx);
  }

void PaBuildBb(const double &src[],const int total,const int len,const double mult,
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
         if(PaIsEmpty(src[i]))
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

void PaBuildVwap(const double &high[],const double &low[],const double &close[],
                 const long &vol[],const datetime &t[],const int total,
                 const int srvDayOffMin,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0 || ArraySize(high)<total || ArraySize(low)<total
      || ArraySize(close)<total || ArraySize(vol)<total || ArraySize(t)<total)
      return;
   int stamp=-1;
   double pv=0.0;
   double vv=0.0;
   for(int j=0; j<total; j++)
     {
      const long shifted=(long)t[j]+(long)srvDayOffMin*60;
      long days=(long)(shifted/86400);
      if(shifted<0 && (shifted%86400)!=0)
         days-=1;
      if((int)days!=stamp)
        {
         stamp=(int)days;
         pv=0.0;
         vv=0.0;
        }
      const double v=(double)vol[j];
      pv+=close[j]*v;
      vv+=v;
      out[j]=(vv>0.0 ? pv/vv : EMPTY_VALUE);
     }
  }

double PaRollingMin(const double &src[],const int total,const int end,const int len)
  {
   if(len<=0 || end<len-1 || end>=total || ArraySize(src)<total)
      return(EMPTY_VALUE);
   double best=EMPTY_VALUE;
   for(int i=end-len+1; i<=end; i++)
     {
      if(PaIsEmpty(src[i]))
         return(EMPTY_VALUE);
      if(PaIsEmpty(best) || src[i]<best)
         best=src[i];
     }
   return(best);
  }

double PaRollingMax(const double &src[],const int total,const int end,const int len)
  {
   if(len<=0 || end<len-1 || end>=total || ArraySize(src)<total)
      return(EMPTY_VALUE);
   double best=EMPTY_VALUE;
   for(int i=end-len+1; i<=end; i++)
     {
      if(PaIsEmpty(src[i]))
         return(EMPTY_VALUE);
      if(PaIsEmpty(best) || src[i]>best)
         best=src[i];
     }
   return(best);
  }

int PaMapHtfIndex(const datetime &htfCloseTime[],const int count,
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
//| Pivots (strict both sides; confirmation bar -> value at center)   |
//+------------------------------------------------------------------+
bool PaPivotHighAt(const double &high[],const int total,const int bar,
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

bool PaPivotLowAt(const double &low[],const int total,const int bar,
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
//| Pattern necklines: extreme strictly between the two pivot bars    |
//+------------------------------------------------------------------+
double PaNeckMinLow(const double &low[],const int total,const int firstBar,
                    const int secondBar)
  {
   double best=EMPTY_VALUE;
   for(int k=firstBar+1; k<secondBar; k++)
     {
      if(k<0 || k>=total || k>=ArraySize(low))
         continue;
      if(PaIsEmpty(best) || low[k]<best)
         best=low[k];
     }
   return(best);
  }

double PaNeckMaxHigh(const double &high[],const int total,const int firstBar,
                     const int secondBar)
  {
   double best=EMPTY_VALUE;
   for(int k=firstBar+1; k<secondBar; k++)
     {
      if(k<0 || k>=total || k>=ArraySize(high))
         continue;
      if(PaIsEmpty(best) || high[k]>best)
         best=high[k];
     }
   return(best);
  }

//+------------------------------------------------------------------+
//| Time helpers                                                     |
//+------------------------------------------------------------------+
int PaMinuteOfDay(const datetime t,const int offsetMin)
  {
   long shifted=(long)t+(long)offsetMin*60;
   long sec=shifted%86400;
   if(sec<0)
      sec+=86400;
   return((int)(sec/60));
  }

bool PaInWindow(const int minute,const int startMin,const int endMin)
  {
   if(startMin==endMin)
      return(true);
   if(startMin<endMin)
      return(minute>=startMin && minute<endMin);
   return(minute>=startMin || minute<endMin);
  }

int PaSessionName(const datetime serverTime,const int srvOffsetMin,const int mktOffsetMin)
  {
   const int minute=PaMinuteOfDay(serverTime,mktOffsetMin-srvOffsetMin);
   const bool asia=PaInWindow(minute,1020,120);
   const bool london=PaInWindow(minute,120,600);
   const bool ny=PaInWindow(minute,420,900);
   if(london && ny)
      return(PA_SESS_LONDON_NY);
   if(ny)
      return(PA_SESS_NY);
   if(london)
      return(PA_SESS_LONDON);
   if(asia)
      return(PA_SESS_ASIA);
   return(PA_SESS_NONE);
  }

double PaSessionScore(const int sessName)
  {
   switch(sessName)
     {
      case PA_SESS_LONDON_NY: return(1.0);
      case PA_SESS_NY:        return(0.8);
      case PA_SESS_LONDON:    return(0.6);
      case PA_SESS_ASIA:      return(0.2);
     }
   return(0.0);
  }

bool PaIsNewServerDay(const datetime prevTime,const datetime curTime)
  {
   MqlDateTime prevDt;
   MqlDateTime curDt;
   TimeToStruct(prevTime,prevDt);
   TimeToStruct(curTime,curDt);
   return(prevDt.year!=curDt.year || prevDt.day_of_year!=curDt.day_of_year);
  }

long PaWeekIndex(const datetime t)
  {
   const long days=(long)((long)t/86400);
   int wd=(int)((days+3)%7);
   if(wd<0)
      wd+=7;
   return(days-(long)wd);
  }

long PaDayIndex(const datetime t)
  {
   return((long)((long)t/86400));
  }

bool PaIsNewServerWeek(const datetime prevTime,const datetime curTime)
  {
   return(PaWeekIndex(prevTime)!=PaWeekIndex(curTime));
  }

//+------------------------------------------------------------------+
//| Bar policy: only closed bars feed the engine (P1)                |
//+------------------------------------------------------------------+
bool PaIsClosedBar(const int bar,const int ratesTotal)
  {
   return(bar>=0 && ratesTotal>1 && bar<=ratesTotal-2);
  }

//+------------------------------------------------------------------+
//| S/R zones                                                        |
//+------------------------------------------------------------------+
void PaZoneAdd(PaEngineState &st,const double px,const int side,const double atr,
               const double width,const int maxZones)
  {
   if(PaIsEmpty(px) || PaIsEmpty(atr) || atr<=0.0 || width<=0.0)
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
   if(st.srCount>=PA_MAX_SR)
     {
      for(int i=1; i<st.srCount; i++)
         st.sr[i-1]=st.sr[i];
      st.srCount=PA_MAX_SR-1;
     }
   st.sr[st.srCount].top=px+half;
   st.sr[st.srCount].bot=px-half;
   st.sr[st.srCount].side=side;
   st.sr[st.srCount].touches=1;
   st.sr[st.srCount].broken=false;
   st.srCount+=1;
   while(st.srCount>maxZones && st.srCount>0)
     {
      for(int i=1; i<st.srCount; i++)
         st.sr[i-1]=st.sr[i];
      st.srCount-=1;
     }
  }

bool PaNearSupport(const PaEngineState &st,const double low,const double atrArg)
  {
   if(PaIsEmpty(atrArg))
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

bool PaNearResistance(const PaEngineState &st,const double high,const double atrArg)
  {
   if(PaIsEmpty(atrArg))
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

//+------------------------------------------------------------------+
//| Scoring / plan                                                   |
//+------------------------------------------------------------------+
double PaRsiScore(const double rsi,const double rsiOs,const double rsiOb)
  {
   if(PaIsEmpty(rsi))
      return(0.0);
   return(rsi<rsiOs ? 1.0 : rsi>rsiOb ? -1.0 : 0.0);
  }

double PaMacdScore(const double macdHist,const bool hasPrev,const double prevMacdHist)
  {
   if(PaIsEmpty(macdHist))
      return(0.0);
   if(macdHist>0.0 && hasPrev && prevMacdHist<=0.0)
      return(1.0);
   if(macdHist<0.0 && hasPrev && prevMacdHist>=0.0)
      return(-1.0);
   return(macdHist>0.0 ? 0.5 : macdHist<0.0 ? -0.5 : 0.0);
  }

double PaDmiScore(const double adx,const double diPlus,const double diMinus,
                  const double adxMin)
  {
   if(PaIsEmpty(adx) || adx<adxMin)
      return(0.0);
   return(diPlus>diMinus ? 1.0 : -1.0);
  }

double PaMomScore(const double rsiScore,const double macdScore,const double dmiScore)
  {
   return((rsiScore+macdScore+dmiScore)/3.0);
  }

double PaAtrRegime(const double atr,const double atrMA)
  {
   if(PaIsEmpty(atr) || PaIsEmpty(atrMA))
      return(0.5);
   if(atr>atrMA*1.2)
      return(1.0);
   if(atr<atrMA*0.8)
      return(0.0);
   return(0.5);
  }

double PaVolumeScore(const double relVolScore,const double obvScore,
                     const double vsaScore)
  {
   return((relVolScore+obvScore+vsaScore)/3.0);
  }

double PaLocationScore(const double vwapScore,const double dayRange)
  {
   return((vwapScore+PaClamp(dayRange,-1.0,1.0))/2.0);
  }

int PaQuality(const int score100,const int noTrade,const int weak,
              const int setup,const int strong)
  {
   if(score100<=noTrade)
      return(PA_Q_NOTRADE);
   if(score100<=weak)
      return(PA_Q_WEAK);
   if(score100<=setup)
      return(PA_Q_SETUP);
   if(score100<=strong)
      return(PA_Q_STRONG);
   return(PA_Q_APLUS);
  }

int PaRegime(const bool adxValid,const double adx,const bool squeeze,
             const double emaF,const double emaM,const double atr,
             const double adxTrend,const double adxChop)
  {
   if(adxValid && adx>=adxTrend && !squeeze)
      return(PA_REG_TRENDING);
   bool choppy=false;
   if(adxValid && adx<adxChop)
      choppy=true;
   if(squeeze && !PaIsEmpty(emaF) && !PaIsEmpty(emaM) && !PaIsEmpty(atr)
      && MathAbs(emaF-emaM)<0.1*atr)
      choppy=true;
   if(choppy)
      return(PA_REG_CHOPPY);
   return(PA_REG_RANGING);
  }

double PaPlanDistance(const double atr,const double entry,const double swing,
                      const int dir,const double atrMul,const double padAtr,
                      const double minAtr,const double maxAtr)
  {
   if(PaIsEmpty(atr) || atr<=0.0 || PaIsEmpty(entry))
      return(EMPTY_VALUE);
   const double pad=atr*padAtr;
   double sDist=EMPTY_VALUE;
   if(!PaIsEmpty(swing))
      sDist=(dir==1 ? (entry-swing)+pad : (swing-entry)+pad);
   const double aDist=atr*atrMul;
   const double base=(PaIsEmpty(sDist) ? aDist : (aDist+sDist)*0.5);
   const double low=atr*minAtr;
   const double high=MathMax(atr*maxAtr,low);
   return(PaClamp(base,low,high));
  }

void PaBuildPlan(const PaConfig &cfg,const PaBar &bar,const int dir,
                 const bool hasLastHigh,const double lastHigh,
                 const bool hasLastLow,const double lastLow,
                 const double patHeight,PaPlan &plan)
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
   const bool atrOk=(!PaIsEmpty(atr) && atr>0.0);
   double swing;
   if(dir==1)
      swing=(!PaIsEmpty(bar.swingLo) ? bar.swingLo : bar.low);
   else
      swing=(!PaIsEmpty(bar.swingHi) ? bar.swingHi : bar.high);

   const double dist=PaPlanDistance(atr,bar.close,swing,dir,cfg.slAtrMul,
                                    cfg.slPadAtr,cfg.slMinAtr,cfg.slMaxAtr);
   double sl=EMPTY_VALUE;
   if(!PaIsEmpty(dist))
      sl=bar.close-(double)dir*dist;
   const double risk=dist;

   const double rr2=MathMax(cfg.rr2,cfg.rr1);
   const double rr3=MathMax(cfg.rr3,rr2);

   const bool dirOk=(dir!=0);
   const bool slOk=(!PaIsEmpty(dist) && dist>0.0
                    && (dir==1 ? sl<bar.close : sl>bar.close));
   const bool rrOk=(cfg.rrMin<=0.0 || cfg.rr1>=cfg.rrMin);
   plan.valid=(atrOk && dirOk && slOk && rrOk);
   plan.sl=sl;
   plan.risk=risk;

   double tp1=EMPTY_VALUE;
   double tp2=EMPTY_VALUE;
   double tp3=EMPTY_VALUE;
   if(cfg.tpMode==PA_TP_MM)
     {
      double mmDist=0.0;
      if(patHeight>0.0)
         mmDist=patHeight;
      else if(hasLastHigh && hasLastLow && !PaIsEmpty(lastHigh) && !PaIsEmpty(lastLow))
         mmDist=MathAbs(lastHigh-lastLow);
      if(mmDist>0.0)
        {
         tp1=bar.close+(double)dir*(mmDist*0.5);
         tp2=bar.close+(double)dir*mmDist;
         tp3=bar.close+(double)dir*(mmDist*1.5);
        }
      else if(cfg.tpMmFallback && !PaIsEmpty(risk))
        {
         tp1=bar.close+(double)dir*cfg.rr1*risk;
         tp2=bar.close+(double)dir*rr2*risk;
         tp3=bar.close+(double)dir*rr3*risk;
        }
     }
   else
     {
      if(!PaIsEmpty(risk))
        {
         tp1=bar.close+(double)dir*cfg.rr1*risk;
         tp2=bar.close+(double)dir*rr2*risk;
         tp3=bar.close+(double)dir*rr3*risk;
        }
     }
   plan.tp1=tp1;
   plan.tp2=tp2;
   plan.tp3=tp3;
  }

//+------------------------------------------------------------------+
//| Init / reset                                                     |
//+------------------------------------------------------------------+
void PaStateInit(PaEngineState &st)
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

   st.tl1Lo=EMPTY_VALUE;
   st.tl2Lo=EMPTY_VALUE;
   st.tl1Hi=EMPTY_VALUE;
   st.tl2Hi=EMPTY_VALUE;
   st.tl1LoB=-1;
   st.tl2LoB=-1;
   st.tl1HiB=-1;
   st.tl2HiB=-1;
   st.hasTl1Lo=false;
   st.hasTl2Lo=false;
   st.hasTl1Hi=false;
   st.hasTl2Hi=false;

   st.sessHi=EMPTY_VALUE;
   st.sessLo=EMPTY_VALUE;
   st.sessPrev=-1;
   st.hasSessHi=false;
   st.hasSessLo=false;

   st.patCount=0;
   st.hiCount=0;
   st.loCount=0;
   st.patHeight=0.0;

   st.srCount=0;
   st.fvgCount=0;
   st.obCount=0;
   st.engulfStreak=0;

   st.obv=0.0;
   st.obvCount=0;

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
   st.hasDay=false;
   st.hasPd=false;
   st.hasPw=false;

   st.vwapStamp=-1;
   st.vwapPV=0.0;
   st.vwapVol=0.0;
   st.hasVwap=false;

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

   st.evEntry=false;
   st.evTp1=false;
   st.evTp2=false;
   st.evTp3=false;
   st.evSl=false;
   st.evClose=false;
   st.closeReason=PA_CLOSE_NONE;

   st.hasPrev=false;
   st.pbTime=0;
   st.pbOpen=EMPTY_VALUE;
   st.pbHigh=EMPTY_VALUE;
   st.pbLow=EMPTY_VALUE;
   st.pbClose=EMPTY_VALUE;
   st.hasPrev2=false;
   st.pb2Open=EMPTY_VALUE;
   st.pb2High=EMPTY_VALUE;
   st.pb2Low=EMPTY_VALUE;
   st.pb2Close=EMPTY_VALUE;
   st.hasPrevMacd=false;
   st.prevMacdHist=EMPTY_VALUE;

   st.bbwCount=0;
  }

void PaBarInit(PaBar &bar)
  {
   bar.time=0;
   bar.open=0.0;
   bar.high=0.0;
   bar.low=0.0;
   bar.close=0.0;
   bar.volume=0.0;
   bar.tickSize=0.0;
   bar.atr=EMPTY_VALUE;
   bar.volMA=EMPTY_VALUE;
   bar.volSma=EMPTY_VALUE;
   bar.emaF=EMPTY_VALUE;
   bar.emaM=EMPTY_VALUE;
   bar.emaS=EMPTY_VALUE;
   bar.swingLo=EMPTY_VALUE;
   bar.swingHi=EMPTY_VALUE;
   bar.pivH=EMPTY_VALUE;
   bar.pivHValid=false;
   bar.pivL=EMPTY_VALUE;
   bar.pivLValid=false;
   bar.srPivH=EMPTY_VALUE;
   bar.srPivHValid=false;
   bar.srPivL=EMPTY_VALUE;
   bar.srPivLValid=false;
   bar.pivNeckLow=EMPTY_VALUE;
   bar.pivNeckHigh=EMPTY_VALUE;
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
   bar.atrMA=EMPTY_VALUE;
   bar.htfCtxEma=EMPTY_VALUE;
   bar.htfCtxValid=false;
   bar.htfSetupEma=EMPTY_VALUE;
   bar.htfSetupValid=false;
  }

void PaBarOutReset(PaBarOut &out)
  {
   out.score100=0;
   out.dir=0;
   out.quality=PA_Q_NOTRADE;
   out.confluence=0;
   out.regime=PA_REG_RANGING;
   out.planValid=false;
   out.entry=EMPTY_VALUE;
   out.sl=EMPTY_VALUE;
   out.tp1=EMPTY_VALUE;
   out.tp2=EMPTY_VALUE;
   out.tp3=EMPTY_VALUE;
   out.risk=EMPTY_VALUE;
   out.sigLong=false;
   out.sigShort=false;
   out.block=PA_BLOCK_NONE;
   out.evEntry=false;
   out.evTp1=false;
   out.evTp2=false;
   out.evTp3=false;
   out.evSl=false;
   out.evClose=false;
   out.closeReason=PA_CLOSE_NONE;
   out.posDir=0;
   out.posEntry=EMPTY_VALUE;
   out.posSl=EMPTY_VALUE;
   out.posTp1=EMPTY_VALUE;
   out.posTp2=EMPTY_VALUE;
   out.posTp3=EMPTY_VALUE;
   out.posRisk=EMPTY_VALUE;
   out.posStage=0;
   out.posBars=0;
   out.dayCount=0;
   out.barsSince=0;
   out.trades=0;
   out.wins=0;
   out.losses=0;
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
   out.pattern=PA_PAT_NONE;
   out.patternDir=0;
   out.patternHeight=0.0;
   out.candleScore=0.0;
   out.atr=EMPTY_VALUE;
   out.atrPct=EMPTY_VALUE;
   out.rsi=EMPTY_VALUE;
   out.macdHist=EMPTY_VALUE;
   out.adx=EMPTY_VALUE;
   out.diPlus=EMPTY_VALUE;
   out.diMinus=EMPTY_VALUE;
   out.bbWidth=EMPTY_VALUE;
   out.volRatio=0.0;
   out.relVol=0.0;
   out.obvSlope=0.0;
   out.vwap=EMPTY_VALUE;
   out.pdh=EMPTY_VALUE;
   out.pdl=EMPTY_VALUE;
   out.pwh=EMPTY_VALUE;
   out.pwl=EMPTY_VALUE;
   out.sessHi=EMPTY_VALUE;
   out.sessLo=EMPTY_VALUE;
   out.volBucket=PA_BUCKET_VERYLOW;
   out.sessName=PA_SESS_NONE;
   out.mtfCtxDir=0;
   out.mtfSetupDir=0;
   out.htfVeto=false;
   out.cf1=false;
   out.cf2=false;
   out.cf3=false;
   out.nearSupport=false;
   out.nearResistance=false;
   out.nearFvgBull=false;
   out.nearFvgBear=false;
   out.swingLo=EMPTY_VALUE;
   out.swingHi=EMPTY_VALUE;
   out.lastHigh=EMPTY_VALUE;
   out.lastLow=EMPTY_VALUE;
  }

//+------------------------------------------------------------------+
//| Internal helpers for the engine                                  |
//+------------------------------------------------------------------+
void PaAddPattern(PaEngineState &st,const int kind,const int dir,
                  const double a,const double b,const double neck,
                  const int aBar,const int bBar)
  {
   if(st.patCount>=PA_MAX_PAT)
     {
      for(int i=1; i<st.patCount; i++)
         st.pats[i-1]=st.pats[i];
      st.patCount=PA_MAX_PAT-1;
     }
   PaPattern pat;
   pat.kind=kind;
   pat.dir=dir;
   pat.a=a;
   pat.b=b;
   pat.c=0.0;
   pat.neck=neck;
   pat.aBar=aBar;
   pat.bBar=bBar;
   pat.cBar=0;
   pat.broken=false;
   pat.brkBar=0;
   st.pats[st.patCount]=pat;
   st.patCount+=1;
  }

void PaPushPivotHigh(PaEngineState &st,const double px,const int bar)
  {
   if(st.hiCount>=PA_PIV_HIST)
     {
      for(int i=1; i<st.hiCount; i++)
        {
         st.hiPx[i-1]=st.hiPx[i];
         st.hiBar[i-1]=st.hiBar[i];
        }
      st.hiCount=PA_PIV_HIST-1;
     }
   st.hiPx[st.hiCount]=px;
   st.hiBar[st.hiCount]=bar;
   st.hiCount+=1;
  }

void PaPushPivotLow(PaEngineState &st,const double px,const int bar)
  {
   if(st.loCount>=PA_PIV_HIST)
     {
      for(int i=1; i<st.loCount; i++)
        {
         st.loPx[i-1]=st.loPx[i];
         st.loBar[i-1]=st.loBar[i];
        }
      st.loCount=PA_PIV_HIST-1;
     }
   st.loPx[st.loCount]=px;
   st.loBar[st.loCount]=bar;
   st.loCount+=1;
  }

void PaPushFvg(PaEngineState &st,const double top,const double bot,
               const int srcBar,const int dir)
  {
   if(st.fvgCount>=PA_MAX_FVG)
     {
      for(int i=1; i<st.fvgCount; i++)
         st.fvg[i-1]=st.fvg[i];
      st.fvgCount=PA_MAX_FVG-1;
     }
   st.fvg[st.fvgCount].top=top;
   st.fvg[st.fvgCount].bot=bot;
   st.fvg[st.fvgCount].srcBar=srcBar;
   st.fvg[st.fvgCount].dir=dir;
   st.fvg[st.fvgCount].dead=false;
   st.fvgCount+=1;
  }

void PaPushOb(PaEngineState &st,const double top,const double bot,
              const int srcBar,const int dir)
  {
   if(st.obCount>=PA_MAX_OB)
     {
      for(int i=1; i<st.obCount; i++)
         st.ob[i-1]=st.ob[i];
      st.obCount=PA_MAX_OB-1;
     }
   st.ob[st.obCount].top=top;
   st.ob[st.obCount].bot=bot;
   st.ob[st.obCount].srcBar=srcBar;
   st.ob[st.obCount].dir=dir;
   st.ob[st.obCount].dead=false;
   st.obCount+=1;
  }

//+------------------------------------------------------------------+
//| Engine step: one closed bar -> one output record                 |
//+------------------------------------------------------------------+
void PaEngineStep(const PaConfig &cfg,PaEngineState &st,const PaBar &bar,
                  const int barIndex,PaBarOut &out)
  {
   PaBarOutReset(out);

   //--- step 0: reset edge flags
   st.evEntry=false;
   st.evTp1=false;
   st.evTp2=false;
   st.evTp3=false;
   st.evSl=false;
   st.evClose=false;
   st.closeReason=PA_CLOSE_NONE;

   const double atr=bar.atr;
   const bool atrOk=(!PaIsEmpty(atr) && atr>0.0);
   const double tick=(bar.tickSize>0.0 ? bar.tickSize : 0.0);
   const double body=MathAbs(bar.close-bar.open);
   const double range=MathMax(bar.high-bar.low,tick);
   const double hiWick=bar.high-MathMax(bar.close,bar.open);
   const double loWick=MathMin(bar.close,bar.open)-bar.low;
   const bool bullBar=(bar.close>bar.open);
   const bool bearBar=(bar.close<bar.open);
   const double prevClose=(st.hasPrev ? st.pbClose : EMPTY_VALUE);
   const double prevOpen=(st.hasPrev ? st.pbOpen : EMPTY_VALUE);
   const double prevHigh=(st.hasPrev ? st.pbHigh : EMPTY_VALUE);
   const double prevLow=(st.hasPrev ? st.pbLow : EMPTY_VALUE);
   const double prevBody=(st.hasPrev ? MathAbs(st.pbClose-st.pbOpen) : EMPTY_VALUE);

   bool bosUp=false;
   bool bosDown=false;
   bool chochUp=false;
   bool chochDown=false;
   bool mssUp=false;
   bool mssDown=false;
   bool bHH=false;
   bool bHL=false;
   bool bLH=false;
   bool bLL=false;
   bool retestBull=false;
   bool retestBear=false;
   bool failBull=false;
   bool failBear=false;
   bool contBull=false;
   bool contBear=false;
   bool pullBull=false;
   bool pullBear=false;
   bool sweepBull=false;
   bool sweepBear=false;

   //--- L1: volume, OBV, candles, session
   double volRatio=0.0;
   if(!PaIsEmpty(bar.volMA) && bar.volMA>0.0)
      volRatio=bar.volume/bar.volMA;

   int bucket=PA_BUCKET_VERYLOW;
   if(!PaIsEmpty(bar.volMA) && bar.volMA>0.0)
     {
      if(bar.volume>=bar.volMA*cfg.volSpikeR)
         bucket=PA_BUCKET_TIM;
      else if(bar.volume>=bar.volMA*cfg.volRVH)
         bucket=PA_BUCKET_VERYHIGH;
      else if(bar.volume>=bar.volMA*cfg.volRH)
         bucket=PA_BUCKET_HIGH;
      else if(bar.volume>=bar.volMA*cfg.volRN)
         bucket=PA_BUCKET_NORMAL;
      else if(bar.volume>=bar.volMA*cfg.volRL)
         bucket=PA_BUCKET_LOW;
     }

   const int volMinute=PaMinuteOfDay(bar.time,cfg.volSessOffsetMin-cfg.srvOffsetMin);
   const bool volSessOk=(!cfg.volSessOn
                         || PaInWindow(volMinute,cfg.volSessStartMin,cfg.volSessEndMin));
   const bool volEvtOk=((cfg.volMin<=0.0 || bar.volume>=cfg.volMin) && volSessOk);
   const bool isTim=(!PaIsEmpty(bar.volMA) && bar.volMA>0.0
                     && bar.volume>=bar.volMA*cfg.volSpikeR && volEvtOk);

   if(st.hasPrev)
     {
      if(bar.close>st.pbClose)
         st.obv+=bar.volume;
      else if(bar.close<st.pbClose)
         st.obv-=bar.volume;
     }
   if(st.obvCount>=PA_OBV_MAX)
     {
      for(int i=1; i<st.obvCount; i++)
         st.obvHist[i-1]=st.obvHist[i];
      st.obvCount=PA_OBV_MAX-1;
     }
   st.obvHist[st.obvCount]=st.obv;
   st.obvCount+=1;
   const int obvKeep=cfg.obvLen+2;
   while(st.obvCount>obvKeep && st.obvCount>0)
     {
      for(int i=1; i<st.obvCount; i++)
         st.obvHist[i-1]=st.obvHist[i];
      st.obvCount-=1;
     }
   const int obvLag=st.obvCount-1-cfg.obvLen;
   const double obvPrev=(obvLag>=0 ? st.obvHist[obvLag] : 0.0);
   const double obvSlope=st.obv-obvPrev;

   bool dispBull=false;
   bool dispBear=false;
   if(atrOk)
     {
      dispBull=(body>=cfg.dispAtr*atr && hiWick<body*0.3);
      dispBear=(body>=cfg.dispAtr*atr && loWick<body*0.3);
     }

   const int sessName=PaSessionName(bar.time,cfg.srvOffsetMin,cfg.mktOffsetMin);
   const double sessScore=PaSessionScore(sessName);

   double relVol=0.0;
   if(!PaIsEmpty(bar.volSma) && bar.volSma>0.0)
      relVol=bar.volume/bar.volSma;

   //--- L2: structure
   const bool pivH=(bar.pivHValid && !PaIsEmpty(bar.pivH));
   const bool pivL=(bar.pivLValid && !PaIsEmpty(bar.pivL));

   double newH=EMPTY_VALUE;
   double newL=EMPTY_VALUE;
   int newHBar=-1;
   int newLBar=-1;

   if(pivH)
     {
      newH=bar.pivH;
      newHBar=barIndex-cfg.swingLen;
      if(st.hasLastHigh)
        {
         if(st.trend<=0 && bar.close>st.lastHigh)
           {
            bosUp=true;
            st.trend=1;
            st.brkLevel=st.lastHigh;
            st.brkDir=1;
            st.brkBar=newHBar;
            st.hasBrk=true;
           }
         if(st.trend<0 && newH>st.lastHigh)
           {
            chochUp=true;
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

   if(pivL)
     {
      newL=bar.pivL;
      newLBar=barIndex-cfg.swingLen;
      if(st.hasLastLow)
        {
         if(st.trend>=0 && bar.close<st.lastLow)
           {
            bosDown=true;
            st.trend=-1;
            st.brkLevel=st.lastLow;
            st.brkDir=-1;
            st.brkBar=newLBar;
            st.hasBrk=true;
           }
         if(st.trend>0 && newL<st.lastLow)
           {
            chochDown=true;
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

   if((bosUp || chochUp) && dispBull)
      mssUp=true;
   if((bosDown || chochDown) && dispBear)
      mssDown=true;

   if(pivH && st.hasPrevHigh && newH>st.prevHigh)
      bHH=true;
   if(pivH && st.hasPrevHigh && newH<st.prevHigh)
      bLH=true;
   if(pivL && st.hasPrevLow && newL>st.prevLow)
      bHL=true;
   if(pivL && st.hasPrevLow && newL<st.prevLow)
      bLL=true;

   if(st.hasBrk && !PaIsEmpty(st.brkLevel) && !PaIsEmpty(atr))
     {
      if(cfg.retestOn && st.brkDir==1
         && barIndex-st.brkBar<=cfg.retestBars
         && bar.low<=st.brkLevel+cfg.retestTolAtr*atr
         && bar.close>st.brkLevel)
         retestBull=true;
      if(cfg.retestOn && st.brkDir==-1
         && barIndex-st.brkBar<=cfg.retestBars
         && bar.high>=st.brkLevel-cfg.retestTolAtr*atr
         && bar.close<st.brkLevel)
         retestBear=true;
      if(cfg.failOn && st.brkDir==-1
         && barIndex-st.brkBar<=cfg.failBars
         && bar.close>st.brkLevel)
         failBull=true;
      if(cfg.failOn && st.brkDir==1
         && barIndex-st.brkBar<=cfg.failBars
         && bar.close<st.brkLevel)
         failBear=true;
     }

   if(cfg.contOn && st.trend==1 && bHH)
      contBull=true;
   if(cfg.contOn && st.trend==-1 && bLL)
      contBear=true;
   if(cfg.pullOn && st.trend==1 && !PaIsEmpty(bar.emaM)
      && bar.low<=bar.emaM && bar.close>bar.emaM)
      pullBull=true;
   if(cfg.pullOn && st.trend==-1 && !PaIsEmpty(bar.emaM)
      && bar.high>=bar.emaM && bar.close<bar.emaM)
      pullBear=true;

   //--- L2: pattern history / detect / shoulder-3 / trim / break
   if(pivH)
      PaPushPivotHigh(st,newH,newHBar);
   if(pivL)
      PaPushPivotLow(st,newL,newLBar);

   const double band=(PaIsEmpty(atr) ? EMPTY_VALUE : atr*cfg.patBandAtr);

   if(cfg.patOn && pivH && st.hiCount>=2)
     {
      const double h1=st.hiPx[st.hiCount-2];
      const double h2=st.hiPx[st.hiCount-1];
      const int b1=st.hiBar[st.hiCount-2];
      const int b2=st.hiBar[st.hiCount-1];
      const bool fresh2=(barIndex-b1<=cfg.patMaxBars);
      const double neckDT=bar.pivNeckLow;
      if(fresh2 && PaInBand(h1,h2,band) && !PaIsEmpty(neckDT))
         PaAddPattern(st,PA_PAT_DT,-1,h1,h2,neckDT,b1,b2);
      if(fresh2 && st.hiCount>=3 && h1>0.0 && h2>=h1*cfg.hsRatio
         && !PaIsEmpty(neckDT))
         PaAddPattern(st,PA_PAT_HST,-1,h1,h2,neckDT,b1,b2);
     }

   if(cfg.patOn && pivL && st.loCount>=2)
     {
      const double l1=st.loPx[st.loCount-2];
      const double l2=st.loPx[st.loCount-1];
      const int b1=st.loBar[st.loCount-2];
      const int b2=st.loBar[st.loCount-1];
      const bool fresh2=(barIndex-b1<=cfg.patMaxBars);
      const double neckDB=bar.pivNeckHigh;
      if(fresh2 && PaInBand(l1,l2,band) && !PaIsEmpty(neckDB))
         PaAddPattern(st,PA_PAT_DB,1,l1,l2,neckDB,b1,b2);
      if(fresh2 && st.loCount>=3 && l2>0.0 && l2<=l1/cfg.hsRatio
         && !PaIsEmpty(neckDB))
         PaAddPattern(st,PA_PAT_HSN,1,l1,l2,neckDB,b1,b2);
     }

   if(cfg.patOn && st.hiCount>=3)
     {
      const double h1=st.hiPx[st.hiCount-3];
      const double h3=st.hiPx[st.hiCount-1];
      const int b3=st.hiBar[st.hiCount-1];
      for(int i=0; i<st.patCount; i++)
        {
         if(st.pats[i].kind==PA_PAT_HST && st.pats[i].c==0.0
            && PaInBand(h1,h3,band))
           {
            st.pats[i].c=h3;
            st.pats[i].cBar=b3;
           }
        }
     }
   if(cfg.patOn && st.loCount>=3)
     {
      const double l1=st.loPx[st.loCount-3];
      const double l3=st.loPx[st.loCount-1];
      const int b3=st.loBar[st.loCount-1];
      for(int i=0; i<st.patCount; i++)
        {
         if(st.pats[i].kind==PA_PAT_HSN && st.pats[i].c==0.0
            && PaInBand(l1,l3,band))
           {
            st.pats[i].c=l3;
            st.pats[i].cBar=b3;
           }
        }
     }

   while(st.patCount>PA_MAX_PAT)
     {
      for(int i=1; i<st.patCount; i++)
         st.pats[i-1]=st.pats[i];
      st.patCount-=1;
     }

   bool dtBrk=false;
   bool dbBrk=false;
   bool hsTopBrk=false;
   bool hsBotBrk=false;
   if(st.hasPrev)
     {
      for(int i=0; i<st.patCount; i++)
        {
         if(st.pats[i].broken || PaIsEmpty(st.pats[i].neck))
            continue;
         if(barIndex<=st.pats[i].bBar)
            continue;
         const bool top=(st.pats[i].kind==PA_PAT_DT || st.pats[i].kind==PA_PAT_HST);
         const bool bot=(st.pats[i].kind==PA_PAT_DB || st.pats[i].kind==PA_PAT_HSN);
         if(top && bar.close<st.pats[i].neck && st.pbClose>=st.pats[i].neck)
           {
            st.pats[i].broken=true;
            st.pats[i].brkBar=barIndex;
            if(st.pats[i].kind==PA_PAT_DT)
               dtBrk=true;
            else
               hsTopBrk=true;
           }
         if(bot && bar.close>st.pats[i].neck && st.pbClose<=st.pats[i].neck)
           {
            st.pats[i].broken=true;
            st.pats[i].brkBar=barIndex;
            if(st.pats[i].kind==PA_PAT_DB)
               dbBrk=true;
            else
               hsBotBrk=true;
           }
        }
     }

   double patNeck=EMPTY_VALUE;
   if(cfg.patOn && st.patCount>0)
     {
      const int last=st.patCount-1;
      if(!st.pats[last].broken)
         patNeck=st.pats[last].neck;
     }

   const bool patSignal=(hsTopBrk || hsBotBrk || dtBrk || dbBrk);
   int patKind=PA_PAT_NONE;
   int patDir=0;
   if(hsTopBrk)
     {
      patKind=PA_PAT_HST;
      patDir=-1;
     }
   else if(hsBotBrk)
     {
      patKind=PA_PAT_HSN;
      patDir=1;
     }
   else if(dtBrk)
     {
      patKind=PA_PAT_DT;
      patDir=-1;
     }
   else if(dbBrk)
     {
      patKind=PA_PAT_DB;
      patDir=1;
     }

   if(patSignal && !PaIsEmpty(patNeck))
      st.patHeight=MathAbs(bar.close-patNeck);

   //--- L3: day / week / session / liquidity
   const int dayKey=(int)PaDayIndex(bar.time);
   bool newServerDay=false;
   if(st.dayStamp<0)
     {
      st.dayStamp=dayKey;
      st.curDayHi=bar.high;
      st.curDayLo=bar.low;
      st.hasDay=true;
     }
   else if(dayKey!=st.dayStamp)
     {
      st.pdh=st.curDayHi;
      st.pdl=st.curDayLo;
      st.hasPd=true;
      st.curDayHi=bar.high;
      st.curDayLo=bar.low;
      st.dayStamp=dayKey;
      newServerDay=true;
     }
   else
     {
      st.curDayHi=MathMax(st.curDayHi,bar.high);
      st.curDayLo=MathMin(st.curDayLo,bar.low);
     }

   const long weekKey=PaWeekIndex(bar.time);
   if(st.weekStamp<0)
     {
      st.weekStamp=(int)weekKey;
      st.curWeekHi=bar.high;
      st.curWeekLo=bar.low;
     }
   else if(weekKey!=(long)st.weekStamp)
     {
      st.pwh=st.curWeekHi;
      st.pwl=st.curWeekLo;
      st.hasPw=true;
      st.curWeekHi=bar.high;
      st.curWeekLo=bar.low;
      st.weekStamp=(int)weekKey;
     }
   else
     {
      st.curWeekHi=MathMax(st.curWeekHi,bar.high);
      st.curWeekLo=MathMin(st.curWeekLo,bar.low);
     }

   if(sessName!=PA_SESS_NONE)
     {
      if(sessName!=st.sessPrev || !st.hasSessHi)
        {
         st.sessHi=bar.high;
         st.sessLo=bar.low;
        }
      else
        {
         st.sessHi=MathMax(st.sessHi,bar.high);
         st.sessLo=MathMin(st.sessLo,bar.low);
        }
      st.hasSessHi=true;
      st.hasSessLo=true;
      st.sessPrev=sessName;
     }

   bool eqHi=false;
   bool eqLo=false;
   if(!PaIsEmpty(atr))
     {
      const double eqThresh=atr*cfg.eqTolAtr;
      if(pivH && st.hasPrevHigh && MathAbs(newH-st.prevHigh)<=eqThresh)
         eqHi=true;
      if(pivL && st.hasPrevLow && MathAbs(newL-st.prevLow)<=eqThresh)
         eqLo=true;
     }

   if(cfg.pdOn && st.hasPd && bar.low<st.pdl && bar.close>st.pdl)
      sweepBull=true;
   if(cfg.pwOn && st.hasPw && bar.low<st.pwl && bar.close>st.pwl)
      sweepBull=true;
   if(cfg.sessOn && st.hasSessLo && bar.low<st.sessLo && bar.close>st.sessLo)
      sweepBull=true;
   if(eqLo && st.hasPrevLow && newL<st.prevLow && bar.close>st.prevLow)
      sweepBull=true;

   if(cfg.pdOn && st.hasPd && bar.high>st.pdh && bar.close<st.pdh)
      sweepBear=true;
   if(cfg.pwOn && st.hasPw && bar.high>st.pwh && bar.close<st.pwh)
      sweepBear=true;
   if(cfg.sessOn && st.hasSessHi && bar.high>st.sessHi && bar.close<st.sessHi)
      sweepBear=true;
   if(eqHi && st.hasPrevHigh && newH>st.prevHigh && bar.close<st.prevHigh)
      sweepBear=true;

   if(pivL)
     {
      st.tl1Lo=st.tl2Lo;
      st.tl1LoB=st.tl2LoB;
      st.hasTl1Lo=st.hasTl2Lo;
      st.tl2Lo=newL;
      st.tl2LoB=newLBar;
      st.hasTl2Lo=true;
     }
   if(pivH)
     {
      st.tl1Hi=st.tl2Hi;
      st.tl1HiB=st.tl2HiB;
      st.hasTl1Hi=st.hasTl2Hi;
      st.tl2Hi=newH;
      st.tl2HiB=newHBar;
      st.hasTl2Hi=true;
     }
   const bool tlUpOk=(st.hasTl1Lo && st.hasTl2Lo && st.tl2LoB>st.tl1LoB);
   const bool tlDnOk=(st.hasTl1Hi && st.hasTl2Hi && st.tl2HiB>st.tl1HiB);
   double tlUpAt=EMPTY_VALUE;
   double tlDnAt=EMPTY_VALUE;
   if(tlUpOk)
     {
      const double slope=(st.tl2Lo-st.tl1Lo)/(double)(st.tl2LoB-st.tl1LoB);
      tlUpAt=st.tl1Lo+slope*(double)(barIndex-st.tl1LoB);
     }
   if(tlDnOk)
     {
      const double slope=(st.tl2Hi-st.tl1Hi)/(double)(st.tl2HiB-st.tl1HiB);
      tlDnAt=st.tl1Hi+slope*(double)(barIndex-st.tl1HiB);
     }

   //--- L4: S/R, FVG, OB
   if(bar.srPivHValid && !PaIsEmpty(bar.srPivH))
      PaZoneAdd(st,bar.srPivH,-1,atr,cfg.srWidthAtr,cfg.srMax);
   if(bar.srPivLValid && !PaIsEmpty(bar.srPivL))
      PaZoneAdd(st,bar.srPivL,1,atr,cfg.srWidthAtr,cfg.srMax);

   if(st.hasPrev2 && !PaIsEmpty(atr))
     {
      if(bar.low>st.pb2High && (bar.low-st.pb2High)>=cfg.fvgMinAtr*atr)
         PaPushFvg(st,bar.low,st.pb2High,barIndex,1);
      if(bar.high<st.pb2Low && (st.pb2Low-bar.high)>=cfg.fvgMinAtr*atr)
         PaPushFvg(st,st.pb2Low,bar.high,barIndex,-1);
     }
   while(st.fvgCount>cfg.fvgMax && st.fvgCount>0)
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

   if(st.hasPrev)
     {
      if(dispBull && st.pbClose<st.pbOpen)
         PaPushOb(st,MathMax(st.pbOpen,st.pbClose),MathMin(st.pbOpen,st.pbClose),
                  barIndex-1,1);
      if(dispBear && st.pbClose>st.pbOpen)
         PaPushOb(st,MathMax(st.pbOpen,st.pbClose),MathMin(st.pbOpen,st.pbClose),
                  barIndex-1,-1);
     }
   while(st.obCount>cfg.obMax && st.obCount>0)
     {
      for(int i=1; i<st.obCount; i++)
         st.ob[i-1]=st.ob[i];
      st.obCount-=1;
     }
   for(int i=0; i<st.obCount; i++)
     {
      if(barIndex-st.ob[i].srcBar>200)
         st.ob[i].dead=true;
      if(st.ob[i].dir==1 && bar.close<st.ob[i].bot)
         st.ob[i].dead=true;
      if(st.ob[i].dir==-1 && bar.close>st.ob[i].top)
         st.ob[i].dead=true;
     }

   bool nearFvgBull=false;
   bool nearFvgBear=false;
   if(!PaIsEmpty(atr))
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

   //--- L5: candle patterns
   const bool bullPin=(bullBar && loWick>=cfg.pinRatio*body);
   const bool bearPin=(bearBar && hiWick>=cfg.pinRatio*body);
   const bool bullEng=(bullBar && st.hasPrev && st.pbClose<st.pbOpen
                       && bar.close>=st.pbOpen && bar.open<=st.pbClose
                       && body>=prevBody
                       && body>=cfg.strongBody*range);
   const bool bearEng=(bearBar && st.hasPrev && st.pbClose>st.pbOpen
                       && bar.close<=st.pbOpen && bar.open>=st.pbClose
                       && body>=prevBody
                       && body>=cfg.strongBody*range);
   const bool dispBullV=(dispBull && bullBar && !PaIsEmpty(bar.volMA)
                         && bar.volume>=cfg.volSpikeR*bar.volMA);
   const bool dispBearV=(dispBear && bearBar && !PaIsEmpty(bar.volMA)
                         && bar.volume>=cfg.volSpikeR*bar.volMA);
   const bool bullRej=(hiWick>=range*0.55 && loWick<=range*0.15 && bullBar);
   const bool bearRej=(loWick>=range*0.55 && hiWick<=range*0.15 && bearBar);
   const bool ibBull=(cfg.ibOn && st.hasPrev2
                      && st.pbHigh<=st.pb2High && st.pbLow>=st.pb2Low
                      && bar.close>st.pbHigh);
   const bool ibBear=(cfg.ibOn && st.hasPrev2
                      && st.pbHigh<=st.pb2High && st.pbLow>=st.pb2Low
                      && bar.close<st.pbLow);
   const bool isDoji=(cfg.dojiOn && body<=cfg.dojiMax*range);
   const bool dojiBull=(isDoji && loWick>hiWick && bar.close>=bar.open);
   const bool dojiBear=(isDoji && hiWick>loWick && bar.close<=bar.open);
   bool soldiers=false;
   bool crows=false;
   if(cfg.soldOn && st.hasPrev2)
     {
      soldiers=(bar.close>bar.open && st.pbClose>st.pbOpen
                && st.pb2Close>st.pb2Open
                && bar.close>st.pbClose && st.pbClose>st.pb2Close
                && body>=cfg.strongBody*range
                && MathAbs(st.pbClose-st.pbOpen)>=cfg.strongBody*MathMax(st.pbHigh-st.pbLow,tick)
                && MathAbs(st.pb2Close-st.pb2Open)>=cfg.strongBody*MathMax(st.pb2High-st.pb2Low,tick));
      crows=(bar.close<bar.open && st.pbClose<st.pbOpen
             && st.pb2Close<st.pb2Open
             && bar.close<st.pbClose && st.pbClose<st.pb2Close
             && body>=cfg.strongBody*range
             && MathAbs(st.pbClose-st.pbOpen)>=cfg.strongBody*MathMax(st.pbHigh-st.pbLow,tick)
             && MathAbs(st.pb2Close-st.pb2Open)>=cfg.strongBody*MathMax(st.pb2High-st.pb2Low,tick));
     }
   const double vVetoMul=(cfg.volVetoOn ? (volRatio>=cfg.volVetoR ? 1.0 : 0.4) : 1.0);

   if(bullEng || bearEng)
      st.engulfStreak+=1;
   else
      st.engulfStreak=0;
   const double streakBonus=(cfg.streakOn && st.engulfStreak>=cfg.streakMin
                             ? cfg.streakAdd : 0.0);

   double cpBull=0.0;
   double cpBear=0.0;
   if(cfg.pinOn)
     {
      cpBull+=(bullPin ? 1.0 : 0.0)*vVetoMul;
      cpBear+=(bearPin ? 1.0 : 0.0)*vVetoMul;
     }
   if(cfg.engulfOn)
     {
      cpBull+=(bullEng ? 1.0+streakBonus : 0.0)*vVetoMul;
      cpBear+=(bearEng ? 1.0+streakBonus : 0.0)*vVetoMul;
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
   if(cfg.ibOn)
     {
      cpBull+=(ibBull ? 0.8 : 0.0);
      cpBear+=(ibBear ? 0.8 : 0.0);
     }
   if(cfg.dojiOn)
     {
      cpBull+=(dojiBull ? 0.5 : 0.0);
      cpBear+=(dojiBear ? 0.5 : 0.0);
     }
   if(cfg.soldOn)
     {
      cpBull+=(soldiers ? 1.2 : 0.0);
      cpBear+=(crows ? 1.2 : 0.0);
     }
   double cpScore=0.0;
   if(cpBull>cpBear)
      cpScore=MathMin(1.0,cpBull/3.0);
   else if(cpBear>cpBull)
      cpScore=-MathMin(1.0,cpBear/3.0);

   //--- L6: technical scores
   const double rsi=bar.rsi;
   const double rsiScore=PaRsiScore(rsi,cfg.rsiOs,cfg.rsiOb);
   const double macdScore=PaMacdScore(bar.macdHist,st.hasPrevMacd,st.prevMacdHist);
   const double dmiScore=PaDmiScore(bar.adx,bar.diPlus,bar.diMinus,cfg.adxMin);
   const double momScore=PaMomScore(rsiScore,macdScore,dmiScore);

   const double atrRegime=PaAtrRegime(atr,bar.atrMA);

   const bool bbExpand=(!PaIsEmpty(bar.bbWidth) && !PaIsEmpty(bar.bbWidthMA)
                        && bar.bbWidth>bar.bbWidthMA);
   const double volScore=(bbExpand ? (bar.close>bar.open ? 0.5 : -0.5) : 0.0);
   const double relVolScore=(relVol>=cfg.rvMin
                             ? (bar.close>bar.open ? 1.0 : bar.close<bar.open ? -1.0 : 0.0)
                             : 0.0);
   const double obvScore=(obvSlope>0.0 ? 1.0 : obvSlope<0.0 ? -1.0 : 0.0);
   const double vsaScore=(isTim ? (bullBar ? 1.0 : bearBar ? -1.0 : 0.0) : 0.0);
   const double volumeScore=PaVolumeScore(relVolScore,obvScore,vsaScore);

   double vwapPV=st.vwapPV;
   double vwapVol=st.vwapVol;
   if(st.vwapStamp!=dayKey)
     {
      vwapPV=0.0;
      vwapVol=0.0;
     }
   vwapPV+=bar.close*bar.volume;
   vwapVol+=bar.volume;
   const double vwap=(vwapVol>0.0 ? vwapPV/vwapVol : EMPTY_VALUE);
   st.hasVwap=!PaIsEmpty(vwap);
   double vwapScore=0.0;
   if(st.hasVwap)
      vwapScore=(bar.close>vwap ? 1.0 : bar.close<vwap ? -1.0 : 0.0);
   double dayRange=0.0;
   if(st.hasPd && !PaIsEmpty(st.pdh) && !PaIsEmpty(st.pdl) && st.pdh>st.pdl)
      dayRange=(bar.close-st.pdl)/(st.pdh-st.pdl)*2.0-1.0;
   const double locationScore=PaLocationScore(vwapScore,dayRange);

   bool emaBull=false;
   bool emaBear=false;
   if(!PaIsEmpty(bar.emaF) && !PaIsEmpty(bar.emaM) && !PaIsEmpty(bar.emaS))
     {
      emaBull=(bar.emaF>bar.emaM && bar.emaM>bar.emaS);
      emaBear=(bar.emaF<bar.emaM && bar.emaM<bar.emaS);
     }
   double trendScore=0.0;
   if(emaBull)
      trendScore=1.0;
   else if(emaBear)
      trendScore=-1.0;
   else if(!PaIsEmpty(bar.emaF) && !PaIsEmpty(bar.emaM))
     {
      if(bar.close>bar.emaF && bar.emaF>bar.emaM)
         trendScore=0.5;
      else if(bar.close<bar.emaF && bar.emaF<bar.emaM)
         trendScore=-0.5;
     }

   //--- L7: MTF
   int ctxDir=0;
   if(bar.htfCtxValid && !PaIsEmpty(bar.htfCtxEma))
      ctxDir=(bar.close>bar.htfCtxEma ? 1 : -1);
   int setupDir=0;
   if(bar.htfSetupValid && !PaIsEmpty(bar.htfSetupEma))
      setupDir=(bar.close>bar.htfSetupEma ? 1 : -1);
   const double gMtfBias=((double)ctxDir+(double)setupDir)/2.0;

   //--- L8: scoring / regime / confluence
   const bool nearSupport=PaNearSupport(st,bar.low,atr);
   const bool nearResistance=PaNearResistance(st,bar.high,atr);

   const double gTrend=trendScore;
   double gStruct=(double)st.trend*0.5;
   if(bosUp || chochUp || mssUp)
      gStruct=1.0;
   else if(bosDown || chochDown || mssDown)
      gStruct=-1.0;
   double gLiq=0.0;
   if(sweepBull)
      gLiq=1.0;
   else if(sweepBear)
      gLiq=-1.0;
   else if(retestBull)
      gLiq=0.7;
   else if(retestBear)
      gLiq=-0.7;
   const double gLoc=locationScore;
   double gSr=0.0;
   if(nearSupport)
      gSr=1.0;
   else if(nearResistance)
      gSr=-1.0;
   else if(nearFvgBull && !nearFvgBear)
      gSr=1.0;
   else if(nearFvgBear && !nearFvgBull)
      gSr=-1.0;
   const double gCandle=cpScore;
   const double gVolume=volumeScore;
   const double gVol=atrRegime*((bar.close>=bar.open) ? 1.0 : -1.0)*0.5+volScore*0.5;
   const double gMom=momScore;
   const double gSess=sessScore*((bar.close>=bar.open) ? 1.0 : -1.0);
   const double gMtf=gMtfBias;

   const double wTotal=cfg.wTrend+cfg.wStruct+cfg.wLiq+cfg.wLoc+cfg.wSr
                       +cfg.wCandle+cfg.wVol+cfg.wAtr+cfg.wMom+cfg.wSess+cfg.wMtf;
   const double wSum=cfg.wTrend*gTrend+cfg.wStruct*gStruct+cfg.wLiq*gLiq
                     +cfg.wLoc*gLoc+cfg.wSr*gSr+cfg.wCandle*gCandle
                     +cfg.wVol*gVolume+cfg.wAtr*gVol+cfg.wMom*gMom
                     +cfg.wSess*gSess+cfg.wMtf*gMtf;
   const double rawScore=(wTotal>0.0 ? PaClamp(wSum/wTotal,-1.0,1.0) : 0.0);
   const int score100=(int)MathRound(50.0+rawScore*50.0);
   const int dir=(rawScore>0.0 ? 1 : rawScore<0.0 ? -1 : 0);
   const int quality=PaQuality(score100,cfg.scrNoTrade,cfg.scrWeak,cfg.scrSetup,cfg.scrStrong);

   const bool okSetup=(!cfg.htfFilter || setupDir==0 || setupDir==dir);
   const bool htfVeto=(cfg.htfVetoOn && ctxDir!=0 && dir!=0 && ctxDir!=dir);
   const bool okMtf=(okSetup && !htfVeto);

   if(!PaIsEmpty(bar.bbWidth))
     {
      if(st.bbwCount>=PA_BBW_MAX)
        {
         for(int i=1; i<st.bbwCount; i++)
            st.bbwHist[i-1]=st.bbwHist[i];
         st.bbwCount=PA_BBW_MAX-1;
        }
      st.bbwHist[st.bbwCount]=bar.bbWidth;
      st.bbwCount+=1;
     }
   double bbwPct=50.0;
   if(!PaIsEmpty(bar.bbWidth) && cfg.regBbwLen>0 && st.bbwCount>=cfg.regBbwLen)
     {
      double lo=st.bbwHist[st.bbwCount-cfg.regBbwLen];
      double hi=lo;
      for(int i=st.bbwCount-cfg.regBbwLen+1; i<st.bbwCount; i++)
        {
         if(st.bbwHist[i]<lo)
            lo=st.bbwHist[i];
         if(st.bbwHist[i]>hi)
            hi=st.bbwHist[i];
        }
      if(hi-lo>0.0)
         bbwPct=(bar.bbWidth-lo)/(hi-lo)*100.0;
     }
   const bool squeeze=(bbwPct<=cfg.regBbwSqueeze);
   const int regime=PaRegime(!PaIsEmpty(bar.adx),bar.adx,squeeze,
                             bar.emaF,bar.emaM,atr,
                             cfg.regAdxTrend,cfg.regAdxChop);

   bool nearRangeEdge=((!PaIsEmpty(atr))
                       && (PaNearSupport(st,bar.low,atr*cfg.regRangeEdge)
                           || PaNearResistance(st,bar.high,atr*cfg.regRangeEdge)));
   if(cfg.pdOn && st.hasPd && !PaIsEmpty(atr))
     {
      if(!PaIsEmpty(st.pdl) && MathAbs(bar.close-st.pdl)<=cfg.regRangeEdge*atr)
         nearRangeEdge=true;
      if(!PaIsEmpty(st.pdh) && MathAbs(bar.close-st.pdh)<=cfg.regRangeEdge*atr)
         nearRangeEdge=true;
     }
   const bool okRegime=(!cfg.regOn || regime==PA_REG_TRENDING
                        || (regime==PA_REG_RANGING && nearRangeEdge));

   const bool cfTrendBull=(ctxDir==1 || (ctxDir==0 && setupDir==1));
   const bool cfTrendBear=(ctxDir==-1 || (ctxDir==0 && setupDir==-1));
   const bool cf1=(dir==1 ? cfTrendBull : dir==-1 ? cfTrendBear : false);

   bool cfLevelBull=(PaNearSupport(st,bar.low,atr*cfg.cfLevelTolAtr) || nearFvgBull);
   bool cfLevelBear=(PaNearResistance(st,bar.high,atr*cfg.cfLevelTolAtr) || nearFvgBear);
   if(!PaIsEmpty(atr))
     {
      if(cfg.pdOn && st.hasPd && !PaIsEmpty(st.pdl)
         && MathAbs(bar.low-st.pdl)<=cfg.cfLevelTolAtr*atr)
         cfLevelBull=true;
      if(cfg.pwOn && st.hasPw && !PaIsEmpty(st.pwl)
         && MathAbs(bar.low-st.pwl)<=cfg.cfLevelTolAtr*atr)
         cfLevelBull=true;
      if(cfg.sessOn && st.hasSessLo
         && MathAbs(bar.low-st.sessLo)<=cfg.cfLevelTolAtr*atr)
         cfLevelBull=true;
      if(tlUpOk && !PaIsEmpty(tlUpAt)
         && MathAbs(bar.low-tlUpAt)<=cfg.cfLevelTolAtr*atr)
         cfLevelBull=true;
      if(cfg.pdOn && st.hasPd && !PaIsEmpty(st.pdh)
         && MathAbs(bar.high-st.pdh)<=cfg.cfLevelTolAtr*atr)
         cfLevelBear=true;
      if(cfg.pwOn && st.hasPw && !PaIsEmpty(st.pwh)
         && MathAbs(bar.high-st.pwh)<=cfg.cfLevelTolAtr*atr)
         cfLevelBear=true;
      if(cfg.sessOn && st.hasSessHi
         && MathAbs(bar.high-st.sessHi)<=cfg.cfLevelTolAtr*atr)
         cfLevelBear=true;
      if(tlDnOk && !PaIsEmpty(tlDnAt)
         && MathAbs(bar.high-tlDnAt)<=cfg.cfLevelTolAtr*atr)
         cfLevelBear=true;
     }
   if(sweepBull)
      cfLevelBull=true;
   if(sweepBear)
      cfLevelBear=true;
   const bool cf2=(dir==1 ? cfLevelBull : dir==-1 ? cfLevelBear : false);

   const bool cfCandleBull=(cpScore>0.0 || patDir==1 || bosUp || mssUp
                            || bullPin || bullEng || ibBull || soldiers);
   const bool cfCandleBear=(cpScore<0.0 || patDir==-1 || bosDown || mssDown
                            || bearPin || bearEng || ibBear || crows);
   const bool cf3=(dir==1 ? cfCandleBull : dir==-1 ? cfCandleBear : false);
   const int confluence=((cf1 ? 1 : 0)+(cf2 ? 1 : 0)+(cf3 ? 1 : 0));
   const bool okConfluence=(!cfg.cfOn || !cfg.cfRequire3 || confluence>=3);

   //--- L9: plan and gates
   PaPlan plan;
   PaBuildPlan(cfg,bar,dir,st.hasLastHigh,st.lastHigh,st.hasLastLow,st.lastLow,
               st.patHeight,plan);

   if(newServerDay)
      st.dayCount=0;
   st.barsSince+=1;

   const bool okCool=(st.barsSince>=cfg.coolBars);
   const bool okDay=(st.dayCount<cfg.maxDay);
   const bool okScore=(score100>cfg.scrNoTrade);
   const bool okDir=(dir!=0);
   const bool okFilter=(okMtf && okCool && okDay && okScore && okDir
                        && okConfluence && okRegime);
   const bool signal=(plan.valid && okFilter);
   bool sigLong=(signal && dir==1);
   bool sigShort=(signal && dir==-1);

   int block=PA_BLOCK_NONE;
   if(!signal)
     {
      if(!plan.valid)
         block=PA_BLOCK_PLAN_INVALID;
      else if(!okSetup)
         block=PA_BLOCK_MTF_FILTER;
      else if(htfVeto)
         block=PA_BLOCK_HTF_VETO;
      else if(!okCool)
         block=PA_BLOCK_COOLDOWN;
      else if(!okDay)
         block=PA_BLOCK_DAY_LIMIT;
      else if(!okScore)
         block=PA_BLOCK_SCORE;
      else if(!okDir)
         block=PA_BLOCK_DIR;
      else if(!okConfluence)
         block=PA_BLOCK_CONFLUENCE;
      else if(!okRegime)
         block=PA_BLOCK_REGIME;
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

      const bool hitSl=(!PaIsEmpty(st.posSl)
                        && (isUp ? bar.low<=st.posSl : bar.high>=st.posSl));
      const bool hit1=(!PaIsEmpty(t1) && (isUp ? bar.high>=t1 : bar.low<=t1));
      const bool hit2=(!PaIsEmpty(t2) && (isUp ? bar.high>=t2 : bar.low<=t2));
      const bool hit3=(!PaIsEmpty(t3) && (isUp ? bar.high>=t3 : bar.low<=t3));
      bool closed=false;

      if(hitSl && (hit1 || hit2 || hit3))
        {
         closed=true;
         st.evSl=true;
         st.evClose=true;
         st.closeReason=PA_CLOSE_SL;
         st.losses+=1;
        }
      else if(hitSl)
        {
         closed=true;
         st.evSl=true;
         st.evClose=true;
         st.closeReason=PA_CLOSE_SL;
         st.losses+=1;
        }
      else if(hit3)
        {
         st.evTp3=true;
         st.posStage=3;
         closed=true;
         st.evClose=true;
         st.closeReason=PA_CLOSE_TP3;
         st.wins+=1;
        }
      else if(hit2)
        {
         st.evTp2=true;
         st.posStage=2;
        }
      else if(hit1)
        {
         st.evTp1=true;
         st.posStage=1;
        }

      if(!closed && st.posBars>300)
        {
         closed=true;
         st.evClose=true;
         st.closeReason=PA_CLOSE_TIMEOUT;
        }

      if(closed)
        {
         st.trades+=1;
         st.xEntry=st.posEntry;
         st.xSl=st.posSl;
         st.xDir=st.posDir;
         st.xBar=st.posBar;
         const double xExit=(st.evSl ? st.posSl
                             : st.evTp3 ? st.posTp3
                             : st.evTp2 ? st.posTp2 : st.posTp1);
         st.xExit=xExit;
         if(!PaIsEmpty(st.posRisk) && st.posRisk>0.0 && !PaIsEmpty(xExit))
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

   //--- outputs
   out.score100=score100;
   out.dir=dir;
   out.quality=quality;
   out.confluence=confluence;
   out.regime=regime;
   out.planValid=plan.valid;
   out.entry=plan.entry;
   out.sl=plan.sl;
   out.tp1=plan.tp1;
   out.tp2=plan.tp2;
   out.tp3=plan.tp3;
   out.risk=plan.risk;
   out.sigLong=sigLong;
   out.sigShort=sigShort;
   out.block=block;
   out.evEntry=st.evEntry;
   out.evTp1=st.evTp1;
   out.evTp2=st.evTp2;
   out.evTp3=st.evTp3;
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
   out.dayCount=st.dayCount;
   out.barsSince=st.barsSince;
   out.trades=st.trades;
   out.wins=st.wins;
   out.losses=st.losses;
   out.trend=st.trend;
   out.bosUp=bosUp;
   out.bosDown=bosDown;
   out.chochUp=chochUp;
   out.chochDown=chochDown;
   out.mssUp=mssUp;
   out.mssDown=mssDown;
   out.retestUp=retestBull;
   out.retestDown=retestBear;
   out.failUp=failBull;
   out.failDown=failBear;
   out.sweepUp=sweepBull;
   out.sweepDown=sweepBear;
   out.hh=bHH;
   out.hl=bHL;
   out.lh=bLH;
   out.ll=bLL;
   out.contUp=contBull;
   out.contDown=contBear;
   out.pullUp=pullBull;
   out.pullDown=pullBear;
   out.pattern=patKind;
   out.patternDir=patDir;
   out.patternHeight=st.patHeight;
   out.candleScore=cpScore;
   out.atr=atr;
   out.atrPct=(atrOk && bar.close!=0.0 ? atr/bar.close*100.0 : EMPTY_VALUE);
   out.rsi=bar.rsi;
   out.macdHist=bar.macdHist;
   out.adx=bar.adx;
   out.diPlus=bar.diPlus;
   out.diMinus=bar.diMinus;
   out.bbWidth=bar.bbWidth;
   out.volRatio=volRatio;
   out.relVol=relVol;
   out.obvSlope=obvSlope;
   out.vwap=vwap;
   out.pdh=(st.hasPd ? st.pdh : EMPTY_VALUE);
   out.pdl=(st.hasPd ? st.pdl : EMPTY_VALUE);
   out.pwh=(st.hasPw ? st.pwh : EMPTY_VALUE);
   out.pwl=(st.hasPw ? st.pwl : EMPTY_VALUE);
   out.sessHi=(st.hasSessHi ? st.sessHi : EMPTY_VALUE);
   out.sessLo=(st.hasSessLo ? st.sessLo : EMPTY_VALUE);
   out.volBucket=bucket;
   out.sessName=sessName;
   out.mtfCtxDir=ctxDir;
   out.mtfSetupDir=setupDir;
   out.htfVeto=htfVeto;
   out.cf1=cf1;
   out.cf2=cf2;
   out.cf3=cf3;
   out.nearSupport=nearSupport;
   out.nearResistance=nearResistance;
   out.nearFvgBull=nearFvgBull;
   out.nearFvgBear=nearFvgBear;
   out.swingLo=bar.swingLo;
   out.swingHi=bar.swingHi;
   out.lastHigh=(st.hasLastHigh ? st.lastHigh : EMPTY_VALUE);
   out.lastLow=(st.hasLastLow ? st.lastLow : EMPTY_VALUE);

   //--- VWAP accumulator (next bar)
   if(st.vwapStamp!=dayKey)
     {
      st.vwapStamp=dayKey;
      st.vwapPV=0.0;
      st.vwapVol=0.0;
     }
   st.vwapPV+=bar.close*bar.volume;
   st.vwapVol+=bar.volume;

   //--- previous bar snapshot
   if(st.hasPrev)
     {
      st.pb2Open=st.pbOpen;
      st.pb2High=st.pbHigh;
      st.pb2Low=st.pbLow;
      st.pb2Close=st.pbClose;
      st.hasPrev2=true;
     }
   st.pbOpen=bar.open;
   st.pbHigh=bar.high;
   st.pbLow=bar.low;
   st.pbClose=bar.close;
   st.pbTime=bar.time;
   st.hasPrev=true;

   if(!PaIsEmpty(bar.macdHist))
     {
      st.prevMacdHist=bar.macdHist;
      st.hasPrevMacd=true;
     }
   else
     {
      st.prevMacdHist=EMPTY_VALUE;
      st.hasPrevMacd=false;
     }
  }

//+------------------------------------------------------------------+
//| Config canonical string and FNV-1a 32-bit hash                   |
//+------------------------------------------------------------------+
void PaCanonI(string &s,const string key,const long value)
  {
   s+=";"+key+"="+IntegerToString(value);
  }

void PaCanonD(string &s,const string key,const double value)
  {
   s+=";"+key+"="+StringFormat("%.10g",value);
  }

string PaConfigCanonical(const PaConfig &cfg)
  {
   string s="v="+PA_CONTRACT_VERSION;
   PaCanonI(s,"srv",cfg.srvOffsetMin);
   PaCanonI(s,"mkt",cfg.mktOffsetMin);
   PaCanonI(s,"volOff",cfg.volSessOffsetMin);
   PaCanonI(s,"maxBars",cfg.maxBars);
   PaCanonI(s,"swingLen",cfg.swingLen);
   PaCanonI(s,"retestOn",(int)cfg.retestOn);
   PaCanonI(s,"retestBars",cfg.retestBars);
   PaCanonD(s,"retestTolAtr",cfg.retestTolAtr);
   PaCanonI(s,"failOn",(int)cfg.failOn);
   PaCanonI(s,"failBars",cfg.failBars);
   PaCanonI(s,"contOn",(int)cfg.contOn);
   PaCanonI(s,"pullOn",(int)cfg.pullOn);
   PaCanonD(s,"eqTolAtr",cfg.eqTolAtr);
   PaCanonI(s,"pdOn",(int)cfg.pdOn);
   PaCanonI(s,"pwOn",(int)cfg.pwOn);
   PaCanonI(s,"sessOn",(int)cfg.sessOn);
   PaCanonI(s,"srLeft",cfg.srLeft);
   PaCanonI(s,"srRight",cfg.srRight);
   PaCanonD(s,"srWidthAtr",cfg.srWidthAtr);
   PaCanonI(s,"srMax",cfg.srMax);
   PaCanonD(s,"fvgMinAtr",cfg.fvgMinAtr);
   PaCanonI(s,"fvgMax",cfg.fvgMax);
   PaCanonI(s,"fvgLife",cfg.fvgLife);
   PaCanonI(s,"obMax",cfg.obMax);
   PaCanonD(s,"pinRatio",cfg.pinRatio);
   PaCanonI(s,"engulfOn",(int)cfg.engulfOn);
   PaCanonI(s,"pinOn",(int)cfg.pinOn);
   PaCanonI(s,"dispOn",(int)cfg.dispOn);
   PaCanonD(s,"dispAtr",cfg.dispAtr);
   PaCanonI(s,"rejOn",(int)cfg.rejOn);
   PaCanonI(s,"ibOn",(int)cfg.ibOn);
   PaCanonI(s,"dojiOn",(int)cfg.dojiOn);
   PaCanonD(s,"dojiMax",cfg.dojiMax);
   PaCanonI(s,"soldOn",(int)cfg.soldOn);
   PaCanonD(s,"strongBody",cfg.strongBody);
   PaCanonI(s,"volVetoOn",(int)cfg.volVetoOn);
   PaCanonD(s,"volVetoR",cfg.volVetoR);
   PaCanonI(s,"streakOn",(int)cfg.streakOn);
   PaCanonI(s,"streakMin",cfg.streakMin);
   PaCanonD(s,"streakAdd",cfg.streakAdd);
   PaCanonI(s,"emaFast",cfg.emaFast);
   PaCanonI(s,"emaMid",cfg.emaMid);
   PaCanonI(s,"emaSlow",cfg.emaSlow);
   PaCanonI(s,"atrLen",cfg.atrLen);
   PaCanonI(s,"rsiLen",cfg.rsiLen);
   PaCanonD(s,"rsiOb",cfg.rsiOb);
   PaCanonD(s,"rsiOs",cfg.rsiOs);
   PaCanonI(s,"macdFast",cfg.macdFast);
   PaCanonI(s,"macdSlow",cfg.macdSlow);
   PaCanonI(s,"macdSignal",cfg.macdSignal);
   PaCanonI(s,"dmiLen",cfg.dmiLen);
   PaCanonI(s,"dmiSmooth",cfg.dmiSmooth);
   PaCanonD(s,"adxMin",cfg.adxMin);
   PaCanonI(s,"bbLen",cfg.bbLen);
   PaCanonD(s,"bbMult",cfg.bbMult);
   PaCanonI(s,"rvLen",cfg.rvLen);
   PaCanonD(s,"rvMin",cfg.rvMin);
   PaCanonI(s,"obvLen",cfg.obvLen);
   PaCanonI(s,"volMaLen",cfg.volMaLen);
   PaCanonD(s,"volSpikeR",cfg.volSpikeR);
   PaCanonD(s,"volRVH",cfg.volRVH);
   PaCanonD(s,"volRH",cfg.volRH);
   PaCanonD(s,"volRN",cfg.volRN);
   PaCanonD(s,"volRL",cfg.volRL);
   PaCanonD(s,"volMin",cfg.volMin);
   PaCanonI(s,"volSessOn",(int)cfg.volSessOn);
   PaCanonI(s,"volSessStartMin",cfg.volSessStartMin);
   PaCanonI(s,"volSessEndMin",cfg.volSessEndMin);
   PaCanonI(s,"ctxTf",(int)cfg.ctxTf);
   PaCanonI(s,"ctxLen",cfg.ctxLen);
   PaCanonI(s,"setupTf",(int)cfg.setupTf);
   PaCanonI(s,"setupLen",cfg.setupLen);
   PaCanonI(s,"htfFilter",(int)cfg.htfFilter);
   PaCanonI(s,"htfVetoOn",(int)cfg.htfVetoOn);
   PaCanonD(s,"wTrend",cfg.wTrend);
   PaCanonD(s,"wStruct",cfg.wStruct);
   PaCanonD(s,"wLiq",cfg.wLiq);
   PaCanonD(s,"wLoc",cfg.wLoc);
   PaCanonD(s,"wSr",cfg.wSr);
   PaCanonD(s,"wCandle",cfg.wCandle);
   PaCanonD(s,"wVol",cfg.wVol);
   PaCanonD(s,"wAtr",cfg.wAtr);
   PaCanonD(s,"wMom",cfg.wMom);
   PaCanonD(s,"wSess",cfg.wSess);
   PaCanonD(s,"wMtf",cfg.wMtf);
   PaCanonI(s,"scrNoTrade",cfg.scrNoTrade);
   PaCanonI(s,"scrWeak",cfg.scrWeak);
   PaCanonI(s,"scrSetup",cfg.scrSetup);
   PaCanonI(s,"scrStrong",cfg.scrStrong);
   PaCanonD(s,"slAtrMul",cfg.slAtrMul);
   PaCanonI(s,"slSwing",cfg.slSwing);
   PaCanonD(s,"slPadAtr",cfg.slPadAtr);
   PaCanonD(s,"slMinAtr",cfg.slMinAtr);
   PaCanonD(s,"slMaxAtr",cfg.slMaxAtr);
   PaCanonD(s,"rr1",cfg.rr1);
   PaCanonD(s,"rr2",cfg.rr2);
   PaCanonD(s,"rr3",cfg.rr3);
   PaCanonD(s,"rrMin",cfg.rrMin);
   PaCanonI(s,"maxDay",cfg.maxDay);
   PaCanonI(s,"coolBars",cfg.coolBars);
   PaCanonI(s,"tpMode",(int)cfg.tpMode);
   PaCanonI(s,"tpMmFallback",(int)cfg.tpMmFallback);
   PaCanonI(s,"regOn",(int)cfg.regOn);
   PaCanonD(s,"regAdxTrend",cfg.regAdxTrend);
   PaCanonD(s,"regAdxChop",cfg.regAdxChop);
   PaCanonI(s,"regBbwLen",cfg.regBbwLen);
   PaCanonD(s,"regBbwSqueeze",cfg.regBbwSqueeze);
   PaCanonD(s,"regRangeEdge",cfg.regRangeEdge);
   PaCanonI(s,"patOn",(int)cfg.patOn);
   PaCanonD(s,"patBandAtr",cfg.patBandAtr);
   PaCanonI(s,"patMaxBars",cfg.patMaxBars);
   PaCanonD(s,"hsRatio",cfg.hsRatio);
   PaCanonI(s,"cfOn",(int)cfg.cfOn);
   PaCanonD(s,"cfLevelTolAtr",cfg.cfLevelTolAtr);
   PaCanonI(s,"cfRequire3",(int)cfg.cfRequire3);
   return(s);
  }

uint PaFnv1a(const string text)
  {
   uint hash=(uint)2166136261;
   for(int i=0; i<StringLen(text); i++)
     {
      hash^=(uint)(StringGetCharacter(text,i)&0xFF);
      hash=(uint)(hash*(uint)16777619);
     }
   return(hash);
  }

uint PaConfigHash(const PaConfig &cfg)
  {
   return(PaFnv1a(PA_CONTRACT_VERSION+"|"+PaConfigCanonical(cfg)));
  }

#endif // PRICEACTIONMTF_CONTRACT_MQH
