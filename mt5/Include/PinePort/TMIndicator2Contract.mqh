//+------------------------------------------------------------------+
//|                                      TMIndicator2Contract.mqh    |
//|     MT5 EA & AI Lab - PinePort buffer contract and pure logic    |
//|                                                                  |
//| Port of "TM Indicator 2" v2.1.0 (Pine v6) to MQL5.               |
//| Simulation-only research module: no file I/O, no account access, |
//| no order functions, no alerts/webhooks.                          |
//| Contract: docs/indicators/tm-indicator-2.md                   |
//+------------------------------------------------------------------+
#ifndef TMINDICATOR2_CONTRACT_MQH
#define TMINDICATOR2_CONTRACT_MQH

#define TM2_CONTRACT_VERSION   "1.0.0"
#define TM2_PLOT_BUFFERS       16
#define TM2_CONTRACT_BUFFERS   226
#define TM2_TOTAL_BUFFERS      242
#define TM2_CONTRACT_FIRST     16
#define TM2_MAX_SR             20
#define TM2_MAX_FVG            50
#define TM2_MAX_OB             30
#define TM2_MAX_EVT            50
#define TM2_OBV_MAX            12

#define TM2_SR_PIV             10
#define TM2_DMI_SMOOTH         14
#define TM2_BB_LEN             20
#define TM2_BB_MULT            2.0
#define TM2_BBW_MA             20
#define TM2_VOL_SMA            20
#define TM2_OBV_LAG            10
#define TM2_GROUP_COUNT        10

//--- group index (order used by weights / ablation arrays)
#define TM2_G_TREND            0
#define TM2_G_STRUCT           1
#define TM2_G_LIQ              2
#define TM2_G_LOC              3
#define TM2_G_SR               4
#define TM2_G_CANDLE           5
#define TM2_G_VOLUME           6
#define TM2_G_MOM              7
#define TM2_G_SESS             8
#define TM2_G_MTF              9

enum ENUM_TM2_ASSET
  {
   TM2_ASSET_AUTO     = 0,
   TM2_ASSET_XAU      = 1,
   TM2_ASSET_BTC      = 2,
   TM2_ASSET_ETH      = 3,
   TM2_ASSET_LIQ_ALT  = 4,
   TM2_ASSET_HIGH_RISK= 5,
   TM2_ASSET_CUSTOM   = 6
  };

enum ENUM_TM2_ENTRY_MODE
  {
   TM2_ENTRY_MARKET       = 0,
   TM2_ENTRY_LIMIT_STRICT = 1,
   TM2_ENTRY_AUTO         = 2
  };

enum ENUM_TM2_LIMIT_SOURCE
  {
   TM2_LIMIT_FVG50    = 0,
   TM2_LIMIT_OB_EDGE  = 1,
   TM2_LIMIT_EMA_FAST = 2
  };

enum ENUM_TM2_QUALITY
  {
   TM2_Q_NOTRADE = 0,
   TM2_Q_WEAK    = 1,
   TM2_Q_SETUP   = 2,
   TM2_Q_STRONG  = 3,
   TM2_Q_APLUS   = 4
  };

enum ENUM_TM2_MINQ
  {
   TM2_MINQ_WEAK   = 1,
   TM2_MINQ_SETUP  = 2,
   TM2_MINQ_STRONG = 3,
   TM2_MINQ_APLUS  = 4
  };

enum ENUM_TM2_ABLATION
  {
   TM2_ABL_A = 1,
   TM2_ABL_B = 2,
   TM2_ABL_C = 3,
   TM2_ABL_D = 4,
   TM2_ABL_E = 5
  };

enum ENUM_TM2_DIRCODE
  {
   TM2_DIRCODE_OK   = 0,
   TM2_DIRCODE_NONE = 1,
   TM2_DIRCODE_AMBIG= 2
  };

enum ENUM_TM2_REGIME
  {
   TM2_REGIME_CHOP  = -1,
   TM2_REGIME_RANGE = 0,
   TM2_REGIME_TREND = 1
  };

enum ENUM_TM2_SESSION
  {
   TM2_SESS_NONE      = 0,
   TM2_SESS_ASIA      = 1,
   TM2_SESS_LONDON    = 2,
   TM2_SESS_NY        = 3,
   TM2_SESS_LONDON_NY = 4
  };

enum ENUM_TM2_BUCKET
  {
   TM2_BUCKET_VERYLOW  = 0,
   TM2_BUCKET_LOW      = 1,
   TM2_BUCKET_NORMAL   = 2,
   TM2_BUCKET_HIGH     = 3,
   TM2_BUCKET_VERYHIGH = 4,
   TM2_BUCKET_TIM      = 5
  };

enum ENUM_TM2_EVENT
  {
   TM2_EVT_NONE  = 0,
   TM2_EVT_BOS   = 1,
   TM2_EVT_CHOCH = 2,
   TM2_EVT_MSS   = 3,
   TM2_EVT_SWEEP = 4
  };

enum ENUM_TM2_MODE
  {
   TM2_MODE_NONE = 0,
   TM2_MODE_A    = 1,
   TM2_MODE_B    = 2,
   TM2_MODE_C    = 3
  };

enum ENUM_TM2_ORDER
  {
   TM2_ORDER_NONE   = 0,
   TM2_ORDER_MARKET = 1,
   TM2_ORDER_LIMIT  = 2
  };

enum ENUM_TM2_STAGE
  {
   TM2_STAGE_IDLE      = 0,
   TM2_STAGE_PENDING   = 1,
   TM2_STAGE_OPEN      = 2,
   TM2_STAGE_TP1_BE    = 3,
   TM2_STAGE_TP2_TRAIL = 4
  };

enum ENUM_TM2_CLOSE
  {
   TM2_X_NONE           = 0,
   TM2_X_SL             = 1,
   TM2_X_TP1            = 2,
   TM2_X_TP2            = 3,
   TM2_X_TP3            = 4,
   TM2_X_BREAKEVEN      = 5,
   TM2_X_TRAIL          = 6,
   TM2_X_TIMEDECAY      = 7,
   TM2_X_TIMEOUT        = 8,
   TM2_X_CANCEL_TIMEOUT = 9,
   TM2_X_CANCEL_MISSED  = 10
  };

enum ENUM_TM2_REASON
  {
   TM2_R_OK                  = 0,
   TM2_R_NO_SETUP            = 1,
   TM2_R_NO_DIRECTION        = 2,
   TM2_R_AMBIGUOUS           = 3,
   TM2_R_WAIT_CONFIRMATION   = 4,
   TM2_R_WAIT_PULLBACK       = 5,
   TM2_R_BLOCK_SCORE_LONG    = 6,
   TM2_R_BLOCK_SCORE_SHORT   = 7,
   TM2_R_BLOCK_MTF           = 8,
   TM2_R_BLOCK_REGIME        = 9,
   TM2_R_BLOCK_LIQUIDITY     = 10,
   TM2_R_BLOCK_OBSTACLE      = 11,
   TM2_R_BLOCK_OVEREXT       = 12,
   TM2_R_BLOCK_NO_ATR        = 13,
   TM2_R_BLOCK_BAD_SL        = 14,
   TM2_R_BLOCK_BAD_TP        = 15,
   TM2_R_BLOCK_RR            = 16,
   TM2_R_BLOCK_NET_RR        = 17,
   TM2_R_BLOCK_MAX_LEV       = 18,
   TM2_R_BLOCK_LIQUIDATION   = 19,
   TM2_R_BLOCK_COOLDOWN      = 20,
   TM2_R_BLOCK_DAILY_LIMIT   = 21,
   TM2_R_BLOCK_CIRCUIT       = 22,
   TM2_R_BLOCK_POSITION_OPEN = 23,
   TM2_R_BTC_DUMPING         = 24,
   TM2_R_BTC_PUMPING         = 25,
   TM2_R_MODE_DISABLED       = 26,
   TM2_R_MODE_REGIME_MISMATCH= 27,
   TM2_R_MODE_INVALIDATED    = 28,
   TM2_R_MODE_A_PULLBACK     = 29,
   TM2_R_MODE_B_SWEEP        = 30,
   TM2_R_MODE_C_RANGE        = 31
  };

//--- contract buffer map (16..241)
enum ENUM_TM2_BUFFER
  {
   TM2_BUF_LONG_SCORE        = 16,
   TM2_BUF_SHORT_SCORE       = 17,
   TM2_BUF_SCORE100          = 18,
   TM2_BUF_SCORE_GAP         = 19,
   TM2_BUF_DIR               = 20,
   TM2_BUF_DIRECTION_CODE    = 21,
   TM2_BUF_QUALITY           = 22,
   TM2_BUF_QUALITY_LEVEL     = 23,
   TM2_BUF_MIN_REQ_LEVEL     = 24,
   TM2_BUF_OK_QUALITY        = 25,
   TM2_BUF_SCORE_BLOCK       = 26,
   TM2_BUF_ABLATION_CODE     = 27,
   TM2_BUF_W_DIR_TOTAL       = 28,
   TM2_BUF_LONG_WEIGHTED     = 29,
   TM2_BUF_GATE_REGIME       = 30,
   TM2_BUF_GATE_MTF          = 31,
   TM2_BUF_GATE_BTC          = 32,
   TM2_BUF_GATE_OBSTACLE     = 33,
   TM2_BUF_GATE_OVEREXT      = 34,
   TM2_BUF_GATE_CIRCUIT      = 35,
   TM2_BUF_GATE_ALL          = 36,
   TM2_BUF_GATE_TOP_REASON   = 37,
   TM2_BUF_NO_TRADE_REASON   = 38,
   TM2_BUF_OK_COOL           = 39,
   TM2_BUF_OK_DAY            = 40,
   TM2_BUF_OK_CIRCUIT        = 41,
   TM2_BUF_PLAN_VALID        = 42,
   TM2_BUF_PLAN_REASON       = 43,
   TM2_BUF_ORDER_TYPE        = 44,
   TM2_BUF_ENTRY             = 45,
   TM2_BUF_LIMIT             = 46,
   TM2_BUF_SL                = 47,
   TM2_BUF_TP1               = 48,
   TM2_BUF_TP2               = 49,
   TM2_BUF_TP3               = 50,
   TM2_BUF_RISK              = 51,
   TM2_BUF_EVAL_RR           = 52,
   TM2_BUF_POS_SIZE          = 53,
   TM2_BUF_NOTIONAL          = 54,
   TM2_BUF_EFF_LEV           = 55,
   TM2_BUF_MARGIN_REQ        = 56,
   TM2_BUF_LIQ_PRICE         = 57,
   TM2_BUF_NET_RR            = 58,
   TM2_BUF_SIGNAL            = 59,
   TM2_BUF_CANDIDATE         = 60,
   TM2_BUF_ELIGIBLE          = 61,
   TM2_BUF_EV_ENTRY          = 62,
   TM2_BUF_EV_PENDING        = 63,
   TM2_BUF_EV_FILLED         = 64,
   TM2_BUF_EV_CANCEL         = 65,
   TM2_BUF_EV_TP             = 66,
   TM2_BUF_EV_SL             = 67,
   TM2_BUF_EV_BE             = 68,
   TM2_BUF_EV_TRAIL          = 69,
   TM2_BUF_EV_TIMEOUT        = 70,
   TM2_BUF_EV_DECAY          = 71,
   TM2_BUF_EV_CLOSE          = 72,
   TM2_BUF_CANCEL_REASON     = 73,
   TM2_BUF_CLOSE_REASON      = 74,
   TM2_BUF_POS_DIR           = 75,
   TM2_BUF_POS_STAGE         = 76,
   TM2_BUF_POS_ORDER_TYPE    = 77,
   TM2_BUF_POS_MODE          = 78,
   TM2_BUF_POS_ENTRY         = 79,
   TM2_BUF_POS_LIMIT         = 80,
   TM2_BUF_POS_SL            = 81,
   TM2_BUF_POS_TP1           = 82,
   TM2_BUF_POS_TP2           = 83,
   TM2_BUF_POS_TP3           = 84,
   TM2_BUF_POS_RISK          = 85,
   TM2_BUF_POS_BARS          = 86,
   TM2_BUF_POS_BAR           = 87,
   TM2_BUF_POS_MAXFAVR       = 88,
   TM2_BUF_DAY_COUNT         = 89,
   TM2_BUF_BARS_SINCE        = 90,
   TM2_BUF_CONSEC_LOSSES     = 91,
   TM2_BUF_TRADES            = 92,
   TM2_BUF_TP1_HITS          = 93,
   TM2_BUF_NET_WINS          = 94,
   TM2_BUF_BE_SAVES          = 95,
   TM2_BUF_FULL_LOSSES       = 96,
   TM2_BUF_TIMEOUTS          = 97,
   TM2_BUF_DECAYS            = 98,
   TM2_BUF_REALIZED_R_SUM    = 99,
   TM2_BUF_CANDIDATES        = 100,
   TM2_BUF_ELIGIBLE_N        = 101,
   TM2_BUF_PENDING_N         = 102,
   TM2_BUF_FILLED_N          = 103,
   TM2_BUF_CLOSED_N          = 104,
   TM2_BUF_X_DIR             = 105,
   TM2_BUF_X_ENTRY           = 106,
   TM2_BUF_X_SL              = 107,
   TM2_BUF_X_EXIT            = 108,
   TM2_BUF_X_R               = 109,
   TM2_BUF_X_REASON          = 110,
   TM2_BUF_X_BAR             = 111,
   TM2_BUF_X_STAGE           = 112,
   TM2_BUF_REGIME_CODE       = 113,
   TM2_BUF_REGIME_DIR        = 114,
   TM2_BUF_REGIME_ADX        = 115,
   TM2_BUF_REGIME_BBW_PCT    = 116,
   TM2_BUF_IS_SQUEEZE        = 117,
   TM2_BUF_BB_WIDTH          = 118,
   TM2_BUF_BB_WIDTH_MA       = 119,
   TM2_BUF_BB_EXPAND         = 120,
   TM2_BUF_TREND             = 121,
   TM2_BUF_BOS_UP            = 122,
   TM2_BUF_BOS_DN            = 123,
   TM2_BUF_CHOCH_UP          = 124,
   TM2_BUF_CHOCH_DN          = 125,
   TM2_BUF_MSS_UP            = 126,
   TM2_BUF_MSS_DN            = 127,
   TM2_BUF_RETEST_UP         = 128,
   TM2_BUF_RETEST_DN         = 129,
   TM2_BUF_FAIL_UP           = 130,
   TM2_BUF_FAIL_DN           = 131,
   TM2_BUF_CONT_UP           = 132,
   TM2_BUF_CONT_DN           = 133,
   TM2_BUF_PULL_UP           = 134,
   TM2_BUF_PULL_DN           = 135,
   TM2_BUF_HH                = 136,
   TM2_BUF_LL                = 137,
   TM2_BUF_EQ_HI             = 138,
   TM2_BUF_EQ_LO             = 139,
   TM2_BUF_SWING_HI          = 140,
   TM2_BUF_SWING_LO          = 141,
   TM2_BUF_PREV_HIGH         = 142,
   TM2_BUF_PREV_LOW          = 143,
   TM2_BUF_BRK_LEVEL         = 144,
   TM2_BUF_BRK_DIR           = 145,
   TM2_BUF_BRK_BAR           = 146,
   TM2_BUF_EVT_KIND          = 147,
   TM2_BUF_EVT_DIR           = 148,
   TM2_BUF_EVT_SRC_BAR       = 149,
   TM2_BUF_EVT_SRC_TIME      = 150,
   TM2_BUF_EVT_LEVEL         = 151,
   TM2_BUF_EVT_COUNT         = 152,
   TM2_BUF_LAST_SWEEP_BULL_BAR = 153,
   TM2_BUF_LAST_SWEEP_BULL_PX  = 154,
   TM2_BUF_LAST_SWEEP_BEAR_BAR = 155,
   TM2_BUF_LAST_SWEEP_BEAR_PX  = 156,
   TM2_BUF_CP_BULL           = 157,
   TM2_BUF_CP_BEAR           = 158,
   TM2_BUF_CANDLE_SCORE      = 159,
   TM2_BUF_PIN_BULL          = 160,
   TM2_BUF_PIN_BEAR          = 161,
   TM2_BUF_ENG_BULL          = 162,
   TM2_BUF_ENG_BEAR          = 163,
   TM2_BUF_DISP_BULL         = 164,
   TM2_BUF_DISP_BEAR         = 165,
   TM2_BUF_REJ_BULL          = 166,
   TM2_BUF_REJ_BEAR          = 167,
   TM2_BUF_IS_OVEREXT        = 168,
   TM2_BUF_EXT_EMA_ATR       = 169,
   TM2_BUF_EXT_CANDLE_ATR    = 170,
   TM2_BUF_ATR               = 171,
   TM2_BUF_ATR_PCT           = 172,
   TM2_BUF_RSI               = 173,
   TM2_BUF_MACD_HIST         = 174,
   TM2_BUF_ADX               = 175,
   TM2_BUF_DI_PLUS           = 176,
   TM2_BUF_DI_MINUS          = 177,
   TM2_BUF_EMA_SLOPE20       = 178,
   TM2_BUF_EMA_BULL          = 179,
   TM2_BUF_EMA_BEAR          = 180,
   TM2_BUF_ATR_SAFE          = 181,
   TM2_BUF_VOL               = 182,
   TM2_BUF_VOL_MA            = 183,
   TM2_BUF_VOL_RATIO         = 184,
   TM2_BUF_VOL_BUCKET        = 185,
   TM2_BUF_IS_TIM            = 186,
   TM2_BUF_REL_VOL           = 187,
   TM2_BUF_OBV               = 188,
   TM2_BUF_OBV_SLOPE         = 189,
   TM2_BUF_VWAP              = 190,
   TM2_BUF_VWAP_SCORE        = 191,
   TM2_BUF_PDH               = 192,
   TM2_BUF_PDL               = 193,
   TM2_BUF_PWH               = 194,
   TM2_BUF_PWL               = 195,
   TM2_BUF_DAY_RANGE         = 196,
   TM2_BUF_SESS_NAME         = 197,
   TM2_BUF_SESS_HI           = 198,
   TM2_BUF_SESS_LO           = 199,
   TM2_BUF_NEAR_SUP          = 200,
   TM2_BUF_NEAR_RES          = 201,
   TM2_BUF_NEAR_FVG_BULL     = 202,
   TM2_BUF_NEAR_FVG_BEAR     = 203,
   TM2_BUF_NEAR_OB_BULL      = 204,
   TM2_BUF_NEAR_OB_BEAR      = 205,
   TM2_BUF_SR_COUNT          = 206,
   TM2_BUF_FVG_COUNT         = 207,
   TM2_BUF_OB_COUNT          = 208,
   TM2_BUF_NEAREST_RES       = 209,
   TM2_BUF_NEAREST_SUP       = 210,
   TM2_BUF_FVG_BULL_PX       = 211,
   TM2_BUF_FVG_BEAR_PX       = 212,
   TM2_BUF_OB_BULL_PX        = 213,
   TM2_BUF_OB_BEAR_PX        = 214,
   TM2_BUF_MTF_CTX_DIR       = 215,
   TM2_BUF_MTF_SETUP_DIR     = 216,
   TM2_BUF_MTF_CTX_EMA       = 217,
   TM2_BUF_MTF_SETUP_EMA     = 218,
   TM2_BUF_MTF_BIAS          = 219,
   TM2_BUF_MTF_HIER_OK       = 220,
   TM2_BUF_BTC_DUMP          = 221,
   TM2_BUF_BTC_PUMP          = 222,
   TM2_BUF_WEEKEND_BLOCK     = 223,
   TM2_BUF_MODE_DIR          = 224,
   TM2_BUF_ACTIVE_MODE       = 225,
   TM2_BUF_MODE_READY        = 226,
   TM2_BUF_MODE_GATE_OK      = 227,
   TM2_BUF_MODE_REASON       = 228,
   TM2_BUF_MODE_B_INVALID_LONG  = 229,
   TM2_BUF_MODE_B_INVALID_SHORT = 230,
   TM2_BUF_MODE_C_BOX_OK     = 231,
   TM2_BUF_G_TREND           = 232,
   TM2_BUF_G_STRUCT          = 233,
   TM2_BUF_G_LIQ             = 234,
   TM2_BUF_G_LOC             = 235,
   TM2_BUF_G_SR              = 236,
   TM2_BUF_G_CANDLE          = 237,
   TM2_BUF_G_VOLUME          = 238,
   TM2_BUF_G_MOM             = 239,
   TM2_BUF_G_SESS            = 240,
   TM2_BUF_G_MTF             = 241
  };

//+------------------------------------------------------------------+
//| Zones and events                                                 |
//+------------------------------------------------------------------+
struct TM2SrZone
  {
   double            top;
   double            bot;
   int               side;
   int               touches;
   bool              broken;
  };

struct TM2Fvg
  {
   double            top;
   double            bot;
   int               srcBar;
   int               side;
   bool              dead;
  };

struct TM2Ob
  {
   double            top;
   double            bot;
   int               srcBar;
   int               side;
   bool              dead;
  };

struct TM2Event
  {
   int               kind;
   int               dir;
   int               srcBar;
   datetime          srcTime;
   bool              confirmed;
   double            level;
  };

//+------------------------------------------------------------------+
//| Config (118 inputs: 5 MQL5-only + 113 ported Pine)               |
//+------------------------------------------------------------------+
struct TM2Config
  {
   //--- MQL5 only
   int               srvOffsetMin;
   int               mktOffsetMin;
   int               maxBars;
   string            btcSymbol;
   bool              assetIsCrypto;
   //--- asset profile
   int               assetMode;
   bool              cryptoSessNeutral;
   bool              weekendFilter;
   bool              btcLeaderOn;
   double            btcImpulseAtr;
   //--- entry
   int               entryMode;
   int               limitSource;
   int               limitCancelBars;
   bool              limitCancelOnTp1;
   //--- modes
   bool              modeFilterOn;
   bool              modeAOn;
   bool              modeBOn;
   bool              modeCOn;
   int               modeSweepBars;
   double            modePullTol;
   double            modeRangeTol;
   //--- management
   bool              autoBeOn;
   double            beOffsetAtr;
   bool              trailOn;
   double            trailDistAtr;
   bool              timeDecayOn;
   int               stagnantBars;
   int               maxHoldBars;
   //--- gates
   bool              gateRegime;
   bool              gateObstacle;
   bool              gateOverext;
   bool              gateCircuit;
   bool              gateRisk;
   //--- regime
   double            adxTrending;
   double            adxChop;
   int               bbwLen;
   double            bbwSqueezePct;
   //--- obstacle / overextension
   double            obstacleBuffer;
   double            maxExtAtr;
   double            maxCandleAtr;
   //--- structure
   int               msSwingLen;
   bool              msBosOn;
   bool              msChochOn;
   bool              msMssOn;
   bool              msRetestOn;
   int               msRetestBars;
   double            msRetestTolAtr;
   bool              msFailOn;
   int               msFailBars;
   bool              msContOn;
   bool              msPullOn;
   //--- liquidity
   bool              liqPdOn;
   bool              liqPwOn;
   bool              liqSessOn;
   //--- zones
   double            srWidthAtr;
   int               srMax;
   double            fvgMinAtr;
   int               fvgMax;
   int               fvgLife;
   int               obMax;
   int               obLife;
   //--- indicators
   int               emaFast;
   int               emaMid;
   int               emaSlow;
   int               atrLen;
   int               rsiLen;
   double            rsiOb;
   double            rsiOs;
   int               macdFast;
   int               macdSlow;
   int               macdSignal;
   int               dmiLen;
   //--- MTF
   ENUM_TIMEFRAMES   ctxTf;
   int               ctxLen;
   ENUM_TIMEFRAMES   setupTf;
   int               setupLen;
   bool              htfFilter;
   bool              htfVetoOn;
   //--- volume
   int               volMaLen;
   double            volSpikeR;
   double            volRVH;
   double            volRH;
   double            volRN;
   double            volRL;
   double            rvMin;
   //--- weights
   double            wTrend;
   double            wStruct;
   double            wLiq;
   double            wLoc;
   double            wSr;
   double            wCandle;
   double            wVol;
   double            wMom;
   double            wSess;
   double            wMtf;
   //--- scores
   int               scrNoTrade;
   int               scrWeak;
   int               scrSetup;
   int               scrStrong;
   int               minQuality;
   int               scoreMargin;
   int               ablation;
   //--- plan
   double            slAtrMul;
   double            slPadAtr;
   double            slMinAtr;
   double            slMaxAtr;
   double            rr1;
   double            rr2;
   double            rr3;
   double            rrMin;
   //--- risk
   int               maxDay;
   int               coolBars;
   double            riskEquity;
   double            riskPct;
   double            riskMaxLev;
   double            riskMmr;
   double            riskFeeSlipPct;
   int               riskMaxLosses;
  };

//+------------------------------------------------------------------+
//| Engine state (Pine `var` block, rebuilt by full replay)          |
//+------------------------------------------------------------------+
struct TM2EngineState
  {
   //--- structure
   double            swingHi;
   double            swingLo;
   double            prevHigh;
   double            prevLow;
   double            brkLevel;
   int               hiBar;
   int               loBar;
   int               trend;
   int               brkBar;
   int               brkDir;
   bool              hasSwingHi;
   bool              hasSwingLo;
   bool              hasPrevHigh;
   bool              hasPrevLow;
   bool              hasBrk;
   //--- current-bar edge flags
   bool              bosUp;
   bool              bosDown;
   bool              chochUp;
   bool              chochDown;
   bool              mssUp;
   bool              mssDown;
   bool              retestBull;
   bool              retestBear;
   bool              failBull;
   bool              failBear;
   bool              contBull;
   bool              contBear;
   bool              pullBull;
   bool              pullBear;
   bool              isHH;
   bool              isLL;
   bool              eqHi;
   bool              eqLo;
   //--- session
   double            sessHi;
   double            sessLo;
   int               sessPrev;
   bool              hasSessHi;
   bool              hasSessLo;
   //--- zones
   TM2SrZone         sr[TM2_MAX_SR];
   int               srCount;
   TM2Fvg            fvg[TM2_MAX_FVG];
   int               fvgCount;
   TM2Ob             ob[TM2_MAX_OB];
   int               obCount;
   //--- event ring + sweep memory
   TM2Event          evt[TM2_MAX_EVT];
   int               evtCount;
   int               lastSweepBullBar;
   int               lastSweepBearBar;
   double            lastSweepBullPx;
   double            lastSweepBearPx;
   //--- volume / vwap
   double            obv;
   double            obvHist[TM2_OBV_MAX];
   int               obvCount;
   double            vwapPV;
   double            vwapVol;
   long              dayStamp;
   double            pdh;
   double            pdl;
   double            pwh;
   double            pwl;
   bool              hasPd;
   bool              hasPw;
   //--- day clock
   int               dayCount;
   int               barsSince;
   int               consecLosses;
   //--- position
   int               posStage;
   int               posDir;
   int               posBars;
   int               posBar;
   int               posMode;
   int               posOrderType;
   double            posEntry;
   double            posLimit;
   double            posSl;
   double            posTp1;
   double            posTp2;
   double            posTp3;
   double            posRisk;
   double            posMaxFavR;
   bool              needReset;
   //--- last closed trade
   double            xEntry;
   double            xSl;
   double            xTp1;
   double            xTp2;
   double            xTp3;
   double            xExit;
   double            xR;
   int               xDir;
   int               xBar;
   int               xReason;
   int               xStage;
   //--- stats
   int               trades;
   int               tp1Hits;
   int               netWins;
   int               beSaves;
   int               fullLosses;
   int               timeouts;
   int               decays;
   int               candidates;
   int               eligibleN;
   int               pendingN;
   int               filledN;
   int               closedN;
   double            realizedRSum;
   bool              prevCandidate;
   bool              prevEligible;
   //--- current-bar output events
   bool              evEntry;
   bool              evPending;
   bool              evFilled;
   bool              evCancel;
   bool              evSl;
   bool              evBe;
   bool              evTrail;
   bool              evTimeout;
   bool              evDecay;
   bool              evClose;
   int               evTp;
   int               exitReason;
   int               cancelReason;
   double            realizedR;
  };

//+------------------------------------------------------------------+
//| Bar input (precomputed series at bar j)                          |
//+------------------------------------------------------------------+
struct TM2Bar
  {
   datetime          time;
   double            open;
   double            high;
   double            low;
   double            close;
   long              vol;
   double            volMA;
   double            volSma20;
   double            mintick;
   double            prevOpen;
   double            prevClose;
   double            prevHigh;
   double            prevLow;
   double            high2;
   double            low2;
   double            atr;
   double            atrPct;
   double            atrSafe;
   double            emaF;
   double            emaM;
   double            emaS;
   double            rsi;
   double            macdHist;
   double            macdPrevHist;
   double            diPlus;
   double            diMinus;
   double            adx;
   double            slope20;
   double            bbMid;
   double            bbUp;
   double            bbLo;
   double            bbWidth;
   double            bbWidthMA;
   double            bbwPct;
   bool              isSqueeze;
   bool              bbExpand;
   bool              pivHOk;
   bool              pivLOk;
   bool              srPivHOk;
   bool              srPivLOk;
   double            pivH;
   double            pivL;
   double            srPivH;
   double            srPivL;
   double            swingHi;
   double            swingLo;
   bool              swingHiOk;
   bool              swingLoOk;
   double            ctxEma;
   double            setupEma;
   bool              ctxOk;
   bool              setupOk;
   int               ctxDir;
   int               setupDir;
   bool              mtfHierOk;
   int               sessName;
   bool              hasSessHi;
   bool              hasSessLo;
   double            sessHi;
   double            sessLo;
   double            pdh;
   double            pdl;
   double            pwh;
   double            pwl;
   bool              hasPd;
   bool              hasPw;
   bool              isOverext;
   double            btcClose;
   double            btcEma;
   double            btcRsi;
   double            btcAtr;
   bool              btcOk;
   bool              btcNeed;
   bool              isCrypto;
   bool              isWeekend;
   bool              weekendBlocked;
  };

//+------------------------------------------------------------------+
//| Plan / gates / mode input                                        |
//+------------------------------------------------------------------+
struct TM2Plan
  {
   bool              valid;
   int               dir;
   int               orderType;
   double            entry;
   double            limit;
   double            sl;
   double            tp1;
   double            tp2;
   double            tp3;
   double            risk;
   double            evalRR;
   double            posSize;
   double            notional;
   double            effLev;
   double            marginReq;
   double            liqPrice;
   double            netRR;
   int               reason;
  };

struct TM2GateStatus
  {
   bool              regimeOk;
   bool              mtfOk;
   bool              btcOk;
   bool              obstacleOk;
   bool              overextOk;
   bool              circuitOk;
   bool              allPassed;
   int               topReason;
   int               blockMask;
  };

struct TM2ModeInput
  {
   int               regimeCode;
   int               regimeDir;
   int               ctxDir;
   int               setupDir;
   int               dir;
   double            open;
   double            close;
   double            high;
   double            low;
   double            emaF;
   double            atrSafe;
   bool              hasFvgBull;
   double            fvgBullPx;
   bool              hasFvgBear;
   double            fvgBearPx;
   bool              hasObBull;
   double            obBullPx;
   bool              hasObBear;
   double            obBearPx;
   int               sweepAgeBull;
   int               sweepAgeBear;
   bool              hasSweepBullPx;
   double            sweepBullPx;
   bool              hasSweepBearPx;
   double            sweepBearPx;
   bool              confirmBull;
   bool              confirmBear;
   bool              hasRes;
   double            nearestRes;
   bool              hasSup;
   double            nearestSup;
   bool              modeAOn;
   bool              modeBOn;
   bool              modeCOn;
   int               modeSweepBars;
   double            modePullTol;
   double            modeRangeTol;
  };

//+------------------------------------------------------------------+
//| Per-bar output (maps 1:1 to contract buffers)                    |
//+------------------------------------------------------------------+
struct TM2BarOut
  {
   //--- A
   double            longScore;
   double            shortScore;
   double            score100;
   double            scoreGap;
   int               dir;
   int               directionCode;
   int               quality;
   int               qualityLevel;
   int               minReqLevel;
   bool              okQuality;
   int               scoreBlock;
   int               ablationCode;
   double            wDirTotal;
   double            longWeighted;
   //--- B
   bool              gateRegime;
   bool              gateMtf;
   bool              gateBtc;
   bool              gateObstacle;
   bool              gateOverext;
   bool              gateCircuit;
   bool              gateAll;
   int               gateTopReason;
   int               noTradeReason;
   bool              okCool;
   bool              okDay;
   bool              okCircuit;
   //--- C
   bool              planValid;
   int               planReason;
   int               orderType;
   double            entry;
   double            limit;
   double            sl;
   double            tp1;
   double            tp2;
   double            tp3;
   double            risk;
   double            evalRR;
   double            posSize;
   double            notional;
   double            effLev;
   double            marginReq;
   double            liqPrice;
   double            netRR;
   //--- D
   bool              signal;
   bool              candidate;
   bool              eligible;
   bool              evEntry;
   bool              evPending;
   bool              evFilled;
   bool              evCancel;
   int               evTp;
   bool              evSl;
   bool              evBe;
   bool              evTrail;
   bool              evTimeout;
   bool              evDecay;
   bool              evClose;
   int               cancelReason;
   int               closeReason;
   //--- E
   int               posDir;
   int               posStage;
   int               posOrderType;
   int               posMode;
   double            posEntry;
   double            posLimit;
   double            posSl;
   double            posTp1;
   double            posTp2;
   double            posTp3;
   double            posRisk;
   int               posBars;
   int               posBar;
   double            posMaxFavR;
   //--- F
   int               dayCount;
   int               barsSince;
   int               consecLosses;
   int               trades;
   int               tp1Hits;
   int               netWins;
   int               beSaves;
   int               fullLosses;
   int               timeouts;
   int               decays;
   double            realizedRSum;
   int               candidates;
   int               eligibleN;
   int               pendingN;
   int               filledN;
   int               closedN;
   //--- G
   int               xDir;
   double            xEntry;
   double            xSl;
   double            xExit;
   double            xR;
   int               xReason;
   int               xBar;
   int               xStage;
   //--- H
   int               regimeCode;
   int               regimeDir;
   double            regimeAdx;
   double            regimeBbwPct;
   bool              isSqueeze;
   double            bbWidth;
   double            bbWidthMA;
   bool              bbExpand;
   //--- I
   int               trend;
   bool              bosUp;
   bool              bosDown;
   bool              chochUp;
   bool              chochDown;
   bool              mssUp;
   bool              mssDown;
   bool              retestUp;
   bool              retestDown;
   bool              failUp;
   bool              failDown;
   bool              contUp;
   bool              contDown;
   bool              pullUp;
   bool              pullDown;
   bool              hh;
   bool              ll;
   bool              eqHi;
   bool              eqLo;
   double            swingHi;
   double            swingLo;
   double            prevHigh;
   double            prevLow;
   double            brkLevel;
   int               brkDir;
   int               brkBar;
   //--- J
   int               evtKind;
   int               evtDir;
   int               evtSrcBar;
   datetime          evtSrcTime;
   double            evtLevel;
   int               evtCount;
   int               lastSweepBullBar;
   double            lastSweepBullPx;
   int               lastSweepBearBar;
   double            lastSweepBearPx;
   //--- K
   double            cpBull;
   double            cpBear;
   double            candleScore;
   bool              pinBull;
   bool              pinBear;
   bool              engBull;
   bool              engBear;
   bool              dispBull;
   bool              dispBear;
   bool              rejBull;
   bool              rejBear;
   bool              isOverext;
   double            extEma;
   double            extCandle;
   //--- L
   double            atr;
   double            atrPct;
   double            rsi;
   double            macdHist;
   double            adx;
   double            diPlus;
   double            diMinus;
   double            emaSlope20;
   bool              emaBull;
   bool              emaBear;
   double            atrSafe;
   //--- M
   double            vol;
   double            volMA;
   double            volRatio;
   int               volBucket;
   bool              isTim;
   double            relVol;
   double            obv;
   double            obvSlope;
   //--- N
   double            vwap;
   double            vwapScore;
   double            pdh;
   double            pdl;
   double            pwh;
   double            pwl;
   double            dayRange;
   int               sessName;
   double            sessHi;
   double            sessLo;
   //--- O
   bool              nearSup;
   bool              nearRes;
   bool              nearFvgBull;
   bool              nearFvgBear;
   bool              nearObBull;
   bool              nearObBear;
   int               srCount;
   int               fvgCount;
   int               obCount;
   double            nearestRes;
   double            nearestSup;
   double            fvgBullPx;
   double            fvgBearPx;
   double            obBullPx;
   double            obBearPx;
   //--- P
   int               mtfCtxDir;
   int               mtfSetupDir;
   double            mtfCtxEma;
   double            mtfSetupEma;
   double            mtfBias;
   bool              mtfHierOk;
   bool              btcDump;
   bool              btcPump;
   bool              weekendBlock;
   //--- Q
   int               modeDir;
   int               activeMode;
   bool              modeReady;
   bool              modeGateOk;
   int               modeReason;
   bool              modeBInvalidLong;
   bool              modeBInvalidShort;
   bool              modeCBoxOk;
   //--- R
   double            gTrend;
   double            gStruct;
   double            gLiq;
   double            gLoc;
   double            gSr;
   double            gCandle;
   double            gVolume;
   double            gMom;
   double            gSess;
   double            gMtf;
  };

//+------------------------------------------------------------------+
//| Math and time helpers                                            |
//+------------------------------------------------------------------+
double TM2Clamp(const double v,const double lo,const double hi)
  {
// Pine f_clamp returns lo when lo > hi (no swap); keep the quirk (Q11).
   if(lo>hi)
      return(lo);
   if(v<lo)
      return(lo);
   if(v>hi)
      return(hi);
   return(v);
  }

bool TM2IsEmpty(const double v)
  {
   return(!MathIsValidNumber(v) || v==EMPTY_VALUE || v==DBL_MAX);
  }

int TM2LocalMinute(const datetime serverTime,const int srvOffsetMin,const int mktOffsetMin)
  {
   long secs=(long)serverTime+(long)(mktOffsetMin-srvOffsetMin)*60;
   long sod=secs%86400;
   if(sod<0)
      sod+=86400;
   return((int)(sod/60));
  }

bool TM2InWindow(const int minute,const int startMin,const int endMin)
  {
   if(startMin<=endMin)
      return(minute>=startMin && minute<endMin);
   return(minute>=startMin || minute<endMin);
  }

int TM2SessionName(const int minute)
  {
   const bool asia=TM2InWindow(minute,1020,120);
   const bool london=TM2InWindow(minute,120,600);
   const bool ny=TM2InWindow(minute,420,900);
   if(london && ny)
      return(TM2_SESS_LONDON_NY);
   if(ny)
      return(TM2_SESS_NY);
   if(london)
      return(TM2_SESS_LONDON);
   if(asia)
      return(TM2_SESS_ASIA);
   return(TM2_SESS_NONE);
  }

double TM2SessionComponent(const bool closeUp,const bool cryptoSessNeutral)
  {
   return((closeUp ? 1.0 : -1.0)*(cryptoSessNeutral ? 0.0 : 0.5));
  }

bool TM2IsNewServerDay(const datetime prev,const datetime cur)
  {
   MqlDateTime a,b;
   TimeToStruct(prev,a);
   TimeToStruct(cur,b);
   return(a.year!=b.year || a.day_of_year!=b.day_of_year);
  }

long TM2ServerWeekKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t,dt);
   const int mondayOffset=(dt.day_of_week+6)%7;
   return((long)dt.year*1000+(long)(dt.day_of_year-mondayOffset));
  }

bool TM2IsNewServerWeek(const datetime prev,const datetime cur)
  {
   return(TM2ServerWeekKey(prev)!=TM2ServerWeekKey(cur));
  }

bool TM2IsClosedBar(const int bar,const int ratesTotal)
  {
   return(bar<=ratesTotal-2);
  }

bool TM2IsCrypto(const TM2Config &cfg,const string symbol)
  {
   if(cfg.assetIsCrypto)
      return(true);
   if(cfg.assetMode==TM2_ASSET_BTC || cfg.assetMode==TM2_ASSET_ETH ||
      cfg.assetMode==TM2_ASSET_LIQ_ALT || cfg.assetMode==TM2_ASSET_HIGH_RISK)
      return(true);
   return(StringFind(symbol,"USDT")>=0);
  }

bool TM2NeedBtcLeader(const TM2Config &cfg,const string symbol)
  {
   const bool btcSelf=StringFind(symbol,"BTC")>=0;
   const bool altMode=(cfg.assetMode==TM2_ASSET_AUTO || cfg.assetMode==TM2_ASSET_ETH ||
                       cfg.assetMode==TM2_ASSET_LIQ_ALT || cfg.assetMode==TM2_ASSET_HIGH_RISK);
   return(cfg.btcLeaderOn && !btcSelf && altMode);
  }

//+------------------------------------------------------------------+
//| Config canonical string and FNV-1a hash                          |
//+------------------------------------------------------------------+
string TM2NumStr(const double v)
  {
   string s=DoubleToString(v,10);
   if(StringFind(s,".")>=0)
     {
      while(StringLen(s)>0 && StringGetCharacter(s,StringLen(s)-1)=='0')
         s=StringSubstr(s,0,StringLen(s)-1);
      if(StringLen(s)>0 && StringGetCharacter(s,StringLen(s)-1)=='.')
         s=StringSubstr(s,0,StringLen(s)-1);
     }
   if(s=="-0")
      s="0";
   return(s);
  }

uint TM2Fnv1a(const string text)
  {
   uint hash=2166136261;
   const int len=StringLen(text);
   for(int i=0; i<len; i++)
     {
      hash^=(uint)(StringGetCharacter(text,i)&0xFF);
      hash*=16777619;
     }
   return(hash);
  }

string TM2ConfigCanonical(const TM2Config &cfg)
  {
   string s="version="+TM2_CONTRACT_VERSION+";";
   s+="srvOffsetMin="+(string)cfg.srvOffsetMin+";";
   s+="mktOffsetMin="+(string)cfg.mktOffsetMin+";";
   s+="maxBars="+(string)cfg.maxBars+";";
   s+="btcSymbol="+cfg.btcSymbol+";";
   s+="assetIsCrypto="+(cfg.assetIsCrypto ? "1" : "0")+";";
   s+="assetMode="+(string)cfg.assetMode+";";
   s+="cryptoSessNeutral="+(cfg.cryptoSessNeutral ? "1" : "0")+";";
   s+="weekendFilter="+(cfg.weekendFilter ? "1" : "0")+";";
   s+="btcLeaderOn="+(cfg.btcLeaderOn ? "1" : "0")+";";
   s+="btcImpulseAtr="+TM2NumStr(cfg.btcImpulseAtr)+";";
   s+="entryMode="+(string)cfg.entryMode+";";
   s+="limitSource="+(string)cfg.limitSource+";";
   s+="limitCancelBars="+(string)cfg.limitCancelBars+";";
   s+="limitCancelOnTp1="+(cfg.limitCancelOnTp1 ? "1" : "0")+";";
   s+="modeFilterOn="+(cfg.modeFilterOn ? "1" : "0")+";";
   s+="modeAOn="+(cfg.modeAOn ? "1" : "0")+";";
   s+="modeBOn="+(cfg.modeBOn ? "1" : "0")+";";
   s+="modeCOn="+(cfg.modeCOn ? "1" : "0")+";";
   s+="modeSweepBars="+(string)cfg.modeSweepBars+";";
   s+="modePullTol="+TM2NumStr(cfg.modePullTol)+";";
   s+="modeRangeTol="+TM2NumStr(cfg.modeRangeTol)+";";
   s+="autoBeOn="+(cfg.autoBeOn ? "1" : "0")+";";
   s+="beOffsetAtr="+TM2NumStr(cfg.beOffsetAtr)+";";
   s+="trailOn="+(cfg.trailOn ? "1" : "0")+";";
   s+="trailDistAtr="+TM2NumStr(cfg.trailDistAtr)+";";
   s+="timeDecayOn="+(cfg.timeDecayOn ? "1" : "0")+";";
   s+="stagnantBars="+(string)cfg.stagnantBars+";";
   s+="maxHoldBars="+(string)cfg.maxHoldBars+";";
   s+="gateRegime="+(cfg.gateRegime ? "1" : "0")+";";
   s+="gateObstacle="+(cfg.gateObstacle ? "1" : "0")+";";
   s+="gateOverext="+(cfg.gateOverext ? "1" : "0")+";";
   s+="gateCircuit="+(cfg.gateCircuit ? "1" : "0")+";";
   s+="gateRisk="+(cfg.gateRisk ? "1" : "0")+";";
   s+="adxTrending="+TM2NumStr(cfg.adxTrending)+";";
   s+="adxChop="+TM2NumStr(cfg.adxChop)+";";
   s+="bbwLen="+(string)cfg.bbwLen+";";
   s+="bbwSqueezePct="+TM2NumStr(cfg.bbwSqueezePct)+";";
   s+="obstacleBuffer="+TM2NumStr(cfg.obstacleBuffer)+";";
   s+="maxExtAtr="+TM2NumStr(cfg.maxExtAtr)+";";
   s+="maxCandleAtr="+TM2NumStr(cfg.maxCandleAtr)+";";
   s+="msSwingLen="+(string)cfg.msSwingLen+";";
   s+="msBosOn="+(cfg.msBosOn ? "1" : "0")+";";
   s+="msChochOn="+(cfg.msChochOn ? "1" : "0")+";";
   s+="msMssOn="+(cfg.msMssOn ? "1" : "0")+";";
   s+="msRetestOn="+(cfg.msRetestOn ? "1" : "0")+";";
   s+="msRetestBars="+(string)cfg.msRetestBars+";";
   s+="msRetestTolAtr="+TM2NumStr(cfg.msRetestTolAtr)+";";
   s+="msFailOn="+(cfg.msFailOn ? "1" : "0")+";";
   s+="msFailBars="+(string)cfg.msFailBars+";";
   s+="msContOn="+(cfg.msContOn ? "1" : "0")+";";
   s+="msPullOn="+(cfg.msPullOn ? "1" : "0")+";";
   s+="liqPdOn="+(cfg.liqPdOn ? "1" : "0")+";";
   s+="liqPwOn="+(cfg.liqPwOn ? "1" : "0")+";";
   s+="liqSessOn="+(cfg.liqSessOn ? "1" : "0")+";";
   s+="srWidthAtr="+TM2NumStr(cfg.srWidthAtr)+";";
   s+="srMax="+(string)cfg.srMax+";";
   s+="fvgMinAtr="+TM2NumStr(cfg.fvgMinAtr)+";";
   s+="fvgMax="+(string)cfg.fvgMax+";";
   s+="fvgLife="+(string)cfg.fvgLife+";";
   s+="obMax="+(string)cfg.obMax+";";
   s+="obLife="+(string)cfg.obLife+";";
   s+="emaFast="+(string)cfg.emaFast+";";
   s+="emaMid="+(string)cfg.emaMid+";";
   s+="emaSlow="+(string)cfg.emaSlow+";";
   s+="atrLen="+(string)cfg.atrLen+";";
   s+="rsiLen="+(string)cfg.rsiLen+";";
   s+="rsiOb="+TM2NumStr(cfg.rsiOb)+";";
   s+="rsiOs="+TM2NumStr(cfg.rsiOs)+";";
   s+="macdFast="+(string)cfg.macdFast+";";
   s+="macdSlow="+(string)cfg.macdSlow+";";
   s+="macdSignal="+(string)cfg.macdSignal+";";
   s+="dmiLen="+(string)cfg.dmiLen+";";
   s+="ctxTf="+(string)(int)cfg.ctxTf+";";
   s+="ctxLen="+(string)cfg.ctxLen+";";
   s+="setupTf="+(string)(int)cfg.setupTf+";";
   s+="setupLen="+(string)cfg.setupLen+";";
   s+="htfFilter="+(cfg.htfFilter ? "1" : "0")+";";
   s+="htfVetoOn="+(cfg.htfVetoOn ? "1" : "0")+";";
   s+="volMaLen="+(string)cfg.volMaLen+";";
   s+="volSpikeR="+TM2NumStr(cfg.volSpikeR)+";";
   s+="volRVH="+TM2NumStr(cfg.volRVH)+";";
   s+="volRH="+TM2NumStr(cfg.volRH)+";";
   s+="volRN="+TM2NumStr(cfg.volRN)+";";
   s+="volRL="+TM2NumStr(cfg.volRL)+";";
   s+="rvMin="+TM2NumStr(cfg.rvMin)+";";
   s+="wTrend="+TM2NumStr(cfg.wTrend)+";";
   s+="wStruct="+TM2NumStr(cfg.wStruct)+";";
   s+="wLiq="+TM2NumStr(cfg.wLiq)+";";
   s+="wLoc="+TM2NumStr(cfg.wLoc)+";";
   s+="wSr="+TM2NumStr(cfg.wSr)+";";
   s+="wCandle="+TM2NumStr(cfg.wCandle)+";";
   s+="wVol="+TM2NumStr(cfg.wVol)+";";
   s+="wMom="+TM2NumStr(cfg.wMom)+";";
   s+="wSess="+TM2NumStr(cfg.wSess)+";";
   s+="wMtf="+TM2NumStr(cfg.wMtf)+";";
   s+="scrNoTrade="+(string)cfg.scrNoTrade+";";
   s+="scrWeak="+(string)cfg.scrWeak+";";
   s+="scrSetup="+(string)cfg.scrSetup+";";
   s+="scrStrong="+(string)cfg.scrStrong+";";
   s+="minQuality="+(string)cfg.minQuality+";";
   s+="scoreMargin="+(string)cfg.scoreMargin+";";
   s+="ablation="+(string)cfg.ablation+";";
   s+="slAtrMul="+TM2NumStr(cfg.slAtrMul)+";";
   s+="slPadAtr="+TM2NumStr(cfg.slPadAtr)+";";
   s+="slMinAtr="+TM2NumStr(cfg.slMinAtr)+";";
   s+="slMaxAtr="+TM2NumStr(cfg.slMaxAtr)+";";
   s+="rr1="+TM2NumStr(cfg.rr1)+";";
   s+="rr2="+TM2NumStr(cfg.rr2)+";";
   s+="rr3="+TM2NumStr(cfg.rr3)+";";
   s+="rrMin="+TM2NumStr(cfg.rrMin)+";";
   s+="maxDay="+(string)cfg.maxDay+";";
   s+="coolBars="+(string)cfg.coolBars+";";
   s+="riskEquity="+TM2NumStr(cfg.riskEquity)+";";
   s+="riskPct="+TM2NumStr(cfg.riskPct)+";";
   s+="riskMaxLev="+TM2NumStr(cfg.riskMaxLev)+";";
   s+="riskMmr="+TM2NumStr(cfg.riskMmr)+";";
   s+="riskFeeSlipPct="+TM2NumStr(cfg.riskFeeSlipPct)+";";
   s+="riskMaxLosses="+(string)cfg.riskMaxLosses+";";
   return(s);
  }

uint TM2ConfigHash(const TM2Config &cfg)
  {
   return(TM2Fnv1a(TM2_CONTRACT_VERSION+"|"+TM2ConfigCanonical(cfg)));
  }

void TM2NormalizeConfig(TM2Config &cfg)
  {
   if(cfg.assetMode<0)          cfg.assetMode=0;
   if(cfg.assetMode>6)          cfg.assetMode=6;
   if(cfg.entryMode<0)          cfg.entryMode=0;
   if(cfg.entryMode>2)          cfg.entryMode=2;
   if(cfg.limitSource<0)        cfg.limitSource=0;
   if(cfg.limitSource>2)        cfg.limitSource=2;
   cfg.btcImpulseAtr=(cfg.btcImpulseAtr<0.5 ? 0.5 : cfg.btcImpulseAtr);
   cfg.limitCancelBars=(int)TM2Clamp(cfg.limitCancelBars,1,20);
   cfg.modeSweepBars=(int)TM2Clamp(cfg.modeSweepBars,1,20);
   cfg.modePullTol=(cfg.modePullTol<0.05 ? 0.05 : cfg.modePullTol);
   cfg.modeRangeTol=(cfg.modeRangeTol<0.05 ? 0.05 : cfg.modeRangeTol);
   cfg.beOffsetAtr=(cfg.beOffsetAtr<0.0 ? 0.0 : cfg.beOffsetAtr);
   cfg.trailDistAtr=(cfg.trailDistAtr<0.5 ? 0.5 : cfg.trailDistAtr);
   cfg.stagnantBars=(int)TM2Clamp(cfg.stagnantBars,5,60);
   cfg.maxHoldBars=(int)TM2Clamp(cfg.maxHoldBars,10,2000);
   cfg.adxTrending=(double)(int)TM2Clamp(cfg.adxTrending,10,50);
   cfg.adxChop=(double)(int)TM2Clamp(cfg.adxChop,5,30);
   cfg.bbwLen=(int)TM2Clamp(cfg.bbwLen,20,300);
   cfg.bbwSqueezePct=(double)(int)TM2Clamp(cfg.bbwSqueezePct,5,50);
   cfg.obstacleBuffer=TM2Clamp(cfg.obstacleBuffer,0.3,2.0);
   cfg.maxExtAtr=(cfg.maxExtAtr<1.0 ? 1.0 : cfg.maxExtAtr);
   cfg.maxCandleAtr=(cfg.maxCandleAtr<1.0 ? 1.0 : cfg.maxCandleAtr);
   cfg.msSwingLen=(int)TM2Clamp(cfg.msSwingLen,2,20);
   cfg.msRetestBars=(int)TM2Clamp(cfg.msRetestBars,1,100);
   cfg.msRetestTolAtr=(cfg.msRetestTolAtr<0.0 ? 0.0 : cfg.msRetestTolAtr);
   cfg.msFailBars=(int)TM2Clamp(cfg.msFailBars,1,50);
   cfg.srWidthAtr=(cfg.srWidthAtr<0.05 ? 0.05 : cfg.srWidthAtr);
   cfg.srMax=(int)TM2Clamp(cfg.srMax,1,20);
   cfg.fvgMinAtr=(cfg.fvgMinAtr<0.05 ? 0.05 : cfg.fvgMinAtr);
   cfg.fvgMax=(int)TM2Clamp(cfg.fvgMax,1,50);
   cfg.fvgLife=(int)TM2Clamp(cfg.fvgLife,10,500);
   cfg.obMax=(int)TM2Clamp(cfg.obMax,1,30);
   cfg.obLife=(int)TM2Clamp(cfg.obLife,10,300);
   cfg.emaFast=(int)TM2Clamp(cfg.emaFast,2,500);
   cfg.emaMid=(int)TM2Clamp(cfg.emaMid,5,500);
   cfg.emaSlow=(int)TM2Clamp(cfg.emaSlow,10,500);
   cfg.atrLen=(int)TM2Clamp(cfg.atrLen,1,200);
   cfg.rsiLen=(int)TM2Clamp(cfg.rsiLen,2,200);
   cfg.rsiOb=TM2Clamp(cfg.rsiOb,50,99);
   cfg.rsiOs=TM2Clamp(cfg.rsiOs,1,50);
   cfg.macdFast=(int)TM2Clamp(cfg.macdFast,2,200);
   cfg.macdSlow=(int)TM2Clamp(cfg.macdSlow,5,200);
   cfg.macdSignal=(int)TM2Clamp(cfg.macdSignal,1,200);
   cfg.dmiLen=(int)TM2Clamp(cfg.dmiLen,2,200);
   cfg.ctxLen=(int)TM2Clamp(cfg.ctxLen,10,500);
   cfg.setupLen=(int)TM2Clamp(cfg.setupLen,5,500);
   cfg.volMaLen=(int)TM2Clamp(cfg.volMaLen,5,100);
   cfg.volSpikeR=(cfg.volSpikeR<1.5 ? 1.5 : cfg.volSpikeR);
   cfg.volRVH=(cfg.volRVH<1.0 ? 1.0 : cfg.volRVH);
   cfg.volRH=(cfg.volRH<0.8 ? 0.8 : cfg.volRH);
   cfg.volRN=(cfg.volRN<0.4 ? 0.4 : cfg.volRN);
   cfg.volRL=(cfg.volRL<0.1 ? 0.1 : cfg.volRL);
   cfg.rvMin=(cfg.rvMin<0.5 ? 0.5 : cfg.rvMin);
   if(cfg.wTrend<0)   cfg.wTrend=0;
   if(cfg.wStruct<0)  cfg.wStruct=0;
   if(cfg.wLiq<0)     cfg.wLiq=0;
   if(cfg.wLoc<0)     cfg.wLoc=0;
   if(cfg.wSr<0)      cfg.wSr=0;
   if(cfg.wCandle<0)  cfg.wCandle=0;
   if(cfg.wVol<0)     cfg.wVol=0;
   if(cfg.wMom<0)     cfg.wMom=0;
   if(cfg.wSess<0)    cfg.wSess=0;
   if(cfg.wMtf<0)     cfg.wMtf=0;
   cfg.scrNoTrade=(int)TM2Clamp(cfg.scrNoTrade,0,99);
   cfg.scrWeak=(int)TM2Clamp(cfg.scrWeak,1,99);
   cfg.scrSetup=(int)TM2Clamp(cfg.scrSetup,1,99);
   cfg.scrStrong=(int)TM2Clamp(cfg.scrStrong,1,99);
   cfg.minQuality=(int)TM2Clamp(cfg.minQuality,1,4);
   cfg.scoreMargin=(int)TM2Clamp(cfg.scoreMargin,0,50);
   cfg.ablation=(int)TM2Clamp(cfg.ablation,1,5);
   cfg.slAtrMul=(cfg.slAtrMul<0.1 ? 0.1 : cfg.slAtrMul);
   cfg.slPadAtr=(cfg.slPadAtr<0.0 ? 0.0 : cfg.slPadAtr);
   cfg.slMinAtr=(cfg.slMinAtr<0.1 ? 0.1 : cfg.slMinAtr);
   cfg.slMaxAtr=(cfg.slMaxAtr<0.5 ? 0.5 : cfg.slMaxAtr);
   cfg.rr1=(cfg.rr1<0.5 ? 0.5 : cfg.rr1);
   cfg.rr2=(cfg.rr2<1.0 ? 1.0 : cfg.rr2);
   cfg.rr3=(cfg.rr3<1.5 ? 1.5 : cfg.rr3);
   cfg.rrMin=(cfg.rrMin<0.0 ? 0.0 : cfg.rrMin);
   cfg.maxDay=(cfg.maxDay<1 ? 1 : cfg.maxDay);
   cfg.coolBars=(cfg.coolBars<0 ? 0 : cfg.coolBars);
   cfg.riskEquity=(cfg.riskEquity<100.0 ? 100.0 : cfg.riskEquity);
   cfg.riskPct=TM2Clamp(cfg.riskPct,0.1,10.0);
   cfg.riskMaxLev=TM2Clamp(cfg.riskMaxLev,1.0,125.0);
   cfg.riskMmr=TM2Clamp(cfg.riskMmr,0.001,0.05);
   cfg.riskFeeSlipPct=TM2Clamp(cfg.riskFeeSlipPct,0.0,1.0);
   cfg.riskMaxLosses=(int)TM2Clamp(cfg.riskMaxLosses,1,10);
  }

//+------------------------------------------------------------------+
//| Series builders (Pine ta.* semantics)                            |
//+------------------------------------------------------------------+
double TM2TrueRange(const bool hasPrev,const double h,const double l,const double prevClose)
  {
   if(!hasPrev)
      return(h-l);
   double v=h-l;
   const double a=MathAbs(h-prevClose);
   const double b=MathAbs(l-prevClose);
   if(a>v)
      v=a;
   if(b>v)
      v=b;
   return(v);
  }

void TM2BuildSma(const double &src[],const int total,const int len,double &out[])
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
         if(TM2IsEmpty(src[i]))
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

void TM2BuildEma(const double &src[],const int total,const int len,double &out[])
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
            if(TM2IsEmpty(src[i]))
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
         if(TM2IsEmpty(value) || TM2IsEmpty(src[j]))
            value=EMPTY_VALUE;
         else
            value=alpha*src[j]+(1.0-alpha)*value;
        }
      out[j]=value;
     }
  }

void TM2BuildRma(const double &src[],const int total,const int len,double &out[])
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
            if(TM2IsEmpty(src[i]))
              {
               ok=false;
               break;
              }
            sum+=src[i];
           }
         out[j]=(ok ? sum/(double)len : EMPTY_VALUE);
         continue;
        }
      if(TM2IsEmpty(out[j-1]) || TM2IsEmpty(src[j]))
         continue;
      out[j]=(((double)(len-1))*out[j-1]+src[j])/(double)len;
     }
  }

void TM2BuildAtr(const double &high[],const double &low[],const double &close[],
                 const int total,const int len,double &out[])
  {
   ArrayResize(out,0);
   if(total<=0 || ArraySize(high)<total || ArraySize(low)<total || ArraySize(close)<total)
      return;
   double tr[];
   ArrayResize(tr,total);
   for(int j=0; j<total; j++)
      tr[j]=TM2TrueRange(j>0,high[j],low[j],(j>0 ? close[j-1] : close[j]));
   TM2BuildRma(tr,total,len,out);
  }

void TM2BuildRsi(const double &src[],const int total,const int len,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0 || len<=0 || ArraySize(src)<total || total<=len)
      return;
   double gainSum=0.0;
   double lossSum=0.0;
   double avgGain=EMPTY_VALUE;
   double avgLoss=EMPTY_VALUE;
   for(int j=1; j<total; j++)
     {
      const double diff=src[j]-src[j-1];
      const double gain=(diff>0.0 ? diff : 0.0);
      const double loss=(diff<0.0 ? -diff : 0.0);
      if(j<len)
        {
         gainSum+=gain;
         lossSum+=loss;
         continue;
        }
      if(j==len)
        {
         gainSum+=gain;
         lossSum+=loss;
         avgGain=gainSum/(double)len;
         avgLoss=lossSum/(double)len;
        }
      else
        {
         if(TM2IsEmpty(avgGain) || TM2IsEmpty(avgLoss))
            continue;
         avgGain=(((double)(len-1))*avgGain+gain)/(double)len;
         avgLoss=(((double)(len-1))*avgLoss+loss)/(double)len;
        }
      if(TM2IsEmpty(avgGain) || TM2IsEmpty(avgLoss))
         continue;
      if(avgLoss==0.0)
         out[j]=(avgGain==0.0 ? 50.0 : 100.0);
      else
         out[j]=100.0-(100.0/(1.0+avgGain/avgLoss));
     }
  }

void TM2BuildMacdHist(const double &src[],const int total,const int fast,const int slow,
                      const int sig,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0 || ArraySize(src)<total)
      return;
   double emaFast[],emaSlow[];
   TM2BuildEma(src,total,fast,emaFast);
   TM2BuildEma(src,total,slow,emaSlow);
   double line[];
   ArrayResize(line,total);
   ArrayInitialize(line,EMPTY_VALUE);
   for(int j=0; j<total; j++)
     {
      if(!TM2IsEmpty(emaFast[j]) && !TM2IsEmpty(emaSlow[j]))
         line[j]=emaFast[j]-emaSlow[j];
     }
   double signal[];
   TM2BuildEma(line,total,sig,signal);
   for(int j=0; j<total; j++)
     {
      if(!TM2IsEmpty(line[j]) && !TM2IsEmpty(signal[j]))
         out[j]=line[j]-signal[j];
     }
  }

void TM2BuildDmi(const double &high[],const double &low[],const double &close[],
                 const int total,const int len,const int smooth,
                 double &diP[],double &diM[],double &adx[])
  {
   ArrayResize(diP,total);
   ArrayInitialize(diP,EMPTY_VALUE);
   ArrayResize(diM,total);
   ArrayInitialize(diM,EMPTY_VALUE);
   ArrayResize(adx,total);
   ArrayInitialize(adx,EMPTY_VALUE);
   if(total<=1)
      return;
   double tr[],plusDm[],minusDm[];
   ArrayResize(tr,total);
   ArrayResize(plusDm,total);
   ArrayResize(minusDm,total);
   tr[0]=high[0]-low[0];
   plusDm[0]=0.0;
   minusDm[0]=0.0;
   for(int j=1; j<total; j++)
     {
      tr[j]=TM2TrueRange(true,high[j],low[j],close[j-1]);
      const double up=high[j]-high[j-1];
      const double down=low[j-1]-low[j];
      plusDm[j]=(up>down && up>0.0 ? up : 0.0);
      minusDm[j]=(down>up && down>0.0 ? down : 0.0);
     }
   double rmaTr[],rmaPlus[],rmaMinus[];
   TM2BuildRma(tr,total,len,rmaTr);
   TM2BuildRma(plusDm,total,len,rmaPlus);
   TM2BuildRma(minusDm,total,len,rmaMinus);
   double dx[];
   ArrayResize(dx,total);
   ArrayInitialize(dx,EMPTY_VALUE);
   for(int j=0; j<total; j++)
     {
      if(TM2IsEmpty(rmaTr[j]) || TM2IsEmpty(rmaPlus[j]) || TM2IsEmpty(rmaMinus[j]))
         continue;
      if(rmaTr[j]<=0.0)
         continue;
      diP[j]=100.0*rmaPlus[j]/rmaTr[j];
      diM[j]=100.0*rmaMinus[j]/rmaTr[j];
      const double sum=diP[j]+diM[j];
      dx[j]=(sum>0.0 ? 100.0*MathAbs(diP[j]-diM[j])/sum : 0.0);
     }
   TM2BuildRma(dx,total,smooth,adx);
  }

void TM2BuildBb(const double &src[],const int total,const int len,const double mult,
                double &mid[],double &up[],double &lo[])
  {
   ArrayResize(mid,total);
   ArrayInitialize(mid,EMPTY_VALUE);
   ArrayResize(up,total);
   ArrayInitialize(up,EMPTY_VALUE);
   ArrayResize(lo,total);
   ArrayInitialize(lo,EMPTY_VALUE);
   if(total<=0 || len<=0 || ArraySize(src)<total)
      return;
   for(int j=len-1; j<total; j++)
     {
      double sum=0.0;
      bool ok=true;
      for(int i=j-len+1; i<=j; i++)
        {
         if(TM2IsEmpty(src[i]))
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
         var+=(src[i]-mean)*(src[i]-mean);
      const double dev=MathSqrt(var/(double)len);
      mid[j]=mean;
      up[j]=mean+mult*dev;
      lo[j]=mean-mult*dev;
     }
  }

void TM2BuildBbWidthPct(const double &width[],const int total,const int len,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0 || len<=0 || ArraySize(width)<total)
      return;
   for(int j=len-1; j<total; j++)
     {
      double lo=DBL_MAX;
      double hi=-DBL_MAX;
      bool ok=true;
      for(int i=j-len+1; i<=j; i++)
        {
         if(TM2IsEmpty(width[i]))
           {
            ok=false;
            break;
           }
         if(width[i]<lo)
            lo=width[i];
         if(width[i]>hi)
            hi=width[i];
        }
      if(!ok)
         continue;
      out[j]=((hi-lo)>0.0 ? (width[j]-lo)/(hi-lo)*100.0 : 50.0);
     }
  }

double TM2RollingMin(const double &src[],const int total,const int end,const int len)
  {
   if(end<0 || end>=total || len<=0)
      return(EMPTY_VALUE);
   const int start=end-len+1;
   if(start<0)
      return(EMPTY_VALUE);
   double v=DBL_MAX;
   for(int i=start; i<=end; i++)
     {
      if(TM2IsEmpty(src[i]))
         return(EMPTY_VALUE);
      if(src[i]<v)
         v=src[i];
     }
   return(v);
  }

double TM2RollingMax(const double &src[],const int total,const int end,const int len)
  {
   if(end<0 || end>=total || len<=0)
      return(EMPTY_VALUE);
   const int start=end-len+1;
   if(start<0)
      return(EMPTY_VALUE);
   double v=-DBL_MAX;
   for(int i=start; i<=end; i++)
     {
      if(TM2IsEmpty(src[i]))
         return(EMPTY_VALUE);
      if(src[i]>v)
         v=src[i];
     }
   return(v);
  }

void TM2BuildVwap(const double &c[],const double &h[],const double &l[],
                  const long &vol[],const datetime &t[],const int total,
                  const int srvOffsetMin,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(total<=0)
      return;
   double cumVol=0.0;
   double cumPV=0.0;
   long dayStamp=-1;
   for(int j=0; j<total; j++)
     {
      long stamp=0;
      MqlDateTime dt;
      TimeToStruct(t[j],dt);
      stamp=(long)dt.year*10000+(long)dt.mon*100+dt.day;
      const double v=(double)vol[j];
      const double hlc3=(h[j]+l[j]+c[j])/3.0;
      if(dayStamp!=stamp)
        {
         dayStamp=stamp;
         cumVol=v;
         cumPV=v*hlc3;
        }
      else
        {
         cumVol+=v;
         cumPV+=v*hlc3;
        }
      out[j]=(cumVol>0.0 ? cumPV/cumVol : c[j]);
     }
  }

int TM2MapHtfIndex(const datetime &htfCloseTime[],const int count,const datetime chartOpen)
  {
   int found=-1;
   for(int i=0; i<count; i++)
     {
      if(htfCloseTime[i]<=chartOpen)
         found=i;
      else
         break;
     }
   return(found);
  }

double TM2HtfBias(const double close,const double ema,const bool hasData)
  {
   if(!hasData || TM2IsEmpty(close) || TM2IsEmpty(ema))
      return(0.0);
   if(close>ema)
      return(1.0);
   if(close<ema)
      return(-1.0);
   return(0.0);
  }

bool TM2MtfHierarchyOk(const int chartSec,const int setupSec,const int ctxSec)
  {
   return(chartSec<=setupSec && setupSec<=ctxSec);
  }

bool TM2WeekendBlocked(const TM2Config &cfg,const bool isCrypto,const bool isWeekend,
                       const double volRatio,const double atrPct)
  {
   return(cfg.weekendFilter && isCrypto && isWeekend &&
          (volRatio<0.8 || atrPct<0.6));
  }

//+------------------------------------------------------------------+
//| Pivots, zones, events                                            |
//+------------------------------------------------------------------+
bool TM2PivotHighAt(const double &h[],const int total,const int bar,
                    const int left,const int right,double &out)
  {
   out=EMPTY_VALUE;
   if(left<=0 || right<=0 || bar<left+right || bar>=total)
      return(false);
   const int c=bar-right;
   const double v=h[c];
   for(int i=1; i<=left; i++)
     {
      if(h[c-i]>=v)
         return(false);
     }
   for(int i=1; i<=right; i++)
     {
      if(h[c+i]>v)
         return(false);
     }
   out=v;
   return(true);
  }

bool TM2PivotLowAt(const double &l[],const int total,const int bar,
                   const int left,const int right,double &out)
  {
   out=EMPTY_VALUE;
   if(left<=0 || right<=0 || bar<left+right || bar>=total)
      return(false);
   const int c=bar-right;
   const double v=l[c];
   for(int i=1; i<=left; i++)
     {
      if(l[c-i]<=v)
         return(false);
     }
   for(int i=1; i<=right; i++)
     {
      if(l[c+i]<v)
         return(false);
     }
   out=v;
   return(true);
  }

void TM2ZoneAdd(TM2EngineState &st,const double px,const int side,const double atr,
                const double width,const int maxZones)
  {
   if(TM2IsEmpty(px) || atr<=0.0)
      return;
   const double half=atr*width*0.5;
   bool merged=false;
   for(int i=0; i<st.srCount; i++)
     {
      const double mid=(st.sr[i].top+st.sr[i].bot)*0.5;
      if(MathAbs(mid-px)<atr*width)
        {
         st.sr[i].touches++;
         merged=true;
         break;
        }
     }
   if(!merged && st.srCount<TM2_MAX_SR)
     {
      st.sr[st.srCount].top=px+half;
      st.sr[st.srCount].bot=px-half;
      st.sr[st.srCount].side=side;
      st.sr[st.srCount].touches=1;
      st.sr[st.srCount].broken=false;
      st.srCount++;
     }
// Pine removes broken zones; replay never sets `broken` (P5).
   int w=0;
   for(int i=0; i<st.srCount; i++)
     {
      if(st.sr[i].broken)
         continue;
      if(w!=i)
         st.sr[w]=st.sr[i];
      w++;
     }
   st.srCount=w;
   if(maxZones>0)
     {
      while(st.srCount>maxZones)
        {
         for(int i=1; i<st.srCount; i++)
            st.sr[i-1]=st.sr[i];
         st.srCount--;
        }
     }
  }

bool TM2NearSupport(const TM2EngineState &st,const double low,const double atr)
  {
   for(int i=0; i<st.srCount; i++)
     {
      if(st.sr[i].broken || st.sr[i].side!=1)
         continue;
      if(low>=st.sr[i].bot-atr*0.3 && low<=st.sr[i].top+atr*0.3)
         return(true);
     }
   return(false);
  }

bool TM2NearResistance(const TM2EngineState &st,const double high,const double atr)
  {
   for(int i=0; i<st.srCount; i++)
     {
      if(st.sr[i].broken || st.sr[i].side!=-1)
         continue;
      if(high>=st.sr[i].bot-atr*0.3 && high<=st.sr[i].top+atr*0.3)
         return(true);
     }
   return(false);
  }

void TM2PushEvent(TM2EngineState &st,const int kind,const int dir,const int srcBar,
                  const datetime srcTime,const double level)
  {
   if(st.evtCount>=TM2_MAX_EVT)
     {
      for(int i=1; i<st.evtCount; i++)
         st.evt[i-1]=st.evt[i];
      st.evtCount=TM2_MAX_EVT-1;
     }
   st.evt[st.evtCount].kind=kind;
   st.evt[st.evtCount].dir=dir;
   st.evt[st.evtCount].srcBar=srcBar;
   st.evt[st.evtCount].srcTime=srcTime;
   st.evt[st.evtCount].confirmed=true;
   st.evt[st.evtCount].level=level;
   st.evtCount++;
  }

//+------------------------------------------------------------------+
//| Candle / volume / indicator scores                               |
//+------------------------------------------------------------------+
double TM2CandleScore(const bool pinBull,const bool engBull,const bool dispBull,
                      const bool rejBull,const bool pinBear,const bool engBear,
                      const bool dispBear,const bool rejBear)
  {
   const double cpBull=(pinBull ? 1.0 : 0.0)+(engBull ? 1.0 : 0.0)+
                       (dispBull ? 1.2 : 0.0)+(rejBull ? 0.8 : 0.0);
   const double cpBear=(pinBear ? 1.0 : 0.0)+(engBear ? 1.0 : 0.0)+
                       (dispBear ? 1.2 : 0.0)+(rejBear ? 0.8 : 0.0);
   if(cpBull>cpBear)
      return(MathMin(1.0,cpBull/3.0));
   if(cpBear>cpBull)
      return(-MathMin(1.0,cpBear/3.0));
   return(0.0);
  }

int TM2VolBucket(const double vol,const double volMA,const double rP,const double rVH,
                 const double rH,const double rN,const double rL)
  {
// Pine f_vsaName has no `ma > 0` guard (Q1 in §14): ma == 0 -> TIM.
   if(TM2IsEmpty(volMA))
      return(TM2_BUCKET_VERYLOW);
   if(vol>=volMA*rP)
      return(TM2_BUCKET_TIM);
   if(vol>=volMA*rVH)
      return(TM2_BUCKET_VERYHIGH);
   if(vol>=volMA*rH)
      return(TM2_BUCKET_HIGH);
   if(vol>=volMA*rN)
      return(TM2_BUCKET_NORMAL);
   if(vol>=volMA*rL)
      return(TM2_BUCKET_LOW);
   return(TM2_BUCKET_VERYLOW);
  }

double TM2VolumeScore(const bool isTim,const double relVol,const double rvMin,
                      const double close,const double open,const double obvSlope)
  {
   const double base=(isTim ? 1.0 : (relVol>=rvMin ? 0.7 : 0.0));
   const double dir=(close>=open ? 1.0 : -1.0);
   const double obvScore=(obvSlope>0.0 ? 1.0 : obvSlope<0.0 ? -1.0 : 0.0);
   return(TM2Clamp(base*dir*0.6+obvScore*0.4,-1.0,1.0));
  }

double TM2RsiScore(const double rsi,const double os,const double ob)
  {
   if(TM2IsEmpty(rsi))
      return(0.0);
   if(rsi<os)
      return(1.0);
   if(rsi>ob)
      return(-1.0);
   return((rsi-50.0)/20.0);
  }

double TM2MacdScore(const double hist,const bool hasPrev,const double prevHist)
  {
   if(TM2IsEmpty(hist))
      return(0.0);
   if(hist>0.0)
      return((hasPrev && !TM2IsEmpty(prevHist) && hist>prevHist) ? 1.0 : 0.5);
   return((hasPrev && !TM2IsEmpty(prevHist) && hist<prevHist) ? -1.0 : -0.5);
  }

double TM2MomScore(const double rsiScore,const double macdScore)
  {
   return(TM2Clamp(rsiScore*0.4+macdScore*0.6,-1.0,1.0));
  }

double TM2TrendScore(const bool stackBull,const bool stackBear,const double close,
                     const double emaF)
  {
   if(stackBull)
      return(1.0);
   if(stackBear)
      return(-1.0);
   if(close>emaF)
      return(0.4);
   if(close<emaF)
      return(-0.4);
   return(0.0);
  }

double TM2VwapScore(const bool vwapOk,const double close,const double vwap,const double atr)
  {
   if(!vwapOk || TM2IsEmpty(vwap) || vwap<=0.0)
      return(0.0);
   const double denom=(!TM2IsEmpty(atr) && atr!=0.0 ? atr : close*0.01);
   if(denom==0.0)
      return(0.0);
   return(TM2Clamp((close-vwap)/denom,-1.0,1.0));
  }

double TM2DayRange(const double close,const bool hasPd,const double pdh,const double pdl)
  {
   if(!hasPd || TM2IsEmpty(pdh) || TM2IsEmpty(pdl) || pdh<=pdl)
      return(0.0);
   return((close-pdl)/(pdh-pdl)*2.0-1.0);
  }

double TM2ExtEma(const double close,const double emaF,const double atr)
  {
   if(TM2IsEmpty(atr) || atr<=0.0)
      return(0.0);
   return(MathAbs(close-emaF)/atr);
  }

double TM2ExtCandle(const double high,const double low,const double atr)
  {
   if(TM2IsEmpty(atr) || atr<=0.0)
      return(1.0);
   return((high-low)/atr);
  }

bool TM2IsOverextended(const double extEma,const double extCandle,
                       const double maxExtAtr,const double maxCandleAtr)
  {
   return(extEma>maxExtAtr || extCandle>maxCandleAtr);
  }

//+------------------------------------------------------------------+
//| Regime, weights, side scores                                     |
//+------------------------------------------------------------------+
void TM2ClassifyRegime(const double adx,const bool squeeze,const double slope20,
                       const bool emaUp,const bool emaDn,const double bbwPct,
                       const TM2Config &cfg,int &code,int &dir)
  {
   code=0;
   dir=0;
   if(!TM2IsEmpty(adx) && adx>=cfg.adxTrending && (emaUp || emaDn) && !squeeze)
     {
      code=1;
      dir=(emaUp ? 1 : -1);
      return;
     }
   if((!TM2IsEmpty(adx) && adx<cfg.adxChop) ||
      (squeeze && MathAbs(slope20)<0.05))
     {
      code=-1;
      dir=0;
      return;
     }
   code=0;
   dir=0;
  }

void TM2EffectiveWeights(const TM2Config &cfg,const int regimeCode,double &w[])
  {
   ArrayResize(w,TM2_GROUP_COUNT);
   w[TM2_G_TREND]=cfg.wTrend;
   w[TM2_G_STRUCT]=cfg.wStruct;
   w[TM2_G_LIQ]=cfg.wLiq;
   w[TM2_G_LOC]=cfg.wLoc;
   w[TM2_G_SR]=cfg.wSr;
   w[TM2_G_CANDLE]=cfg.wCandle;
   w[TM2_G_VOLUME]=cfg.wVol;
   w[TM2_G_MOM]=cfg.wMom;
   w[TM2_G_SESS]=cfg.wSess;
   w[TM2_G_MTF]=cfg.wMtf;
   if(regimeCode==1)
     {
      w[TM2_G_TREND]*=1.30;
      w[TM2_G_STRUCT]*=1.25;
      w[TM2_G_MOM]*=1.20;
      w[TM2_G_SR]*=0.60;
     }
   else if(regimeCode==0)
     {
      w[TM2_G_TREND]*=0.60;
      w[TM2_G_SR]*=1.30;
      w[TM2_G_LIQ]*=1.30;
      w[TM2_G_LOC]*=1.20;
     }
   else if(regimeCode==-1)
     {
      w[TM2_G_TREND]*=0.50;
      w[TM2_G_STRUCT]*=0.50;
      w[TM2_G_MOM]*=0.50;
     }
  }

void TM2AblationAdjust(double &w[],const int ablationCode)
  {
   if(ArraySize(w)<TM2_GROUP_COUNT)
      return;
   if(ablationCode<=1)
     {
      w[TM2_G_TREND]=0.0;
      w[TM2_G_VOLUME]=0.0;
      w[TM2_G_MOM]=0.0;
      w[TM2_G_SESS]=0.0;
      w[TM2_G_MTF]=0.0;
      return;
     }
   if(ablationCode==2)
     {
      w[TM2_G_VOLUME]=0.0;
      w[TM2_G_SESS]=0.0;
      w[TM2_G_MTF]=0.0;
      return;
     }
   if(ablationCode==3)
     {
      w[TM2_G_SESS]=0.0;
      w[TM2_G_MTF]=0.0;
      return;
     }
// D and E keep every feature.
  }

double TM2LongPart(const double v)
  {
   return(MathMax(v,0.0));
  }

double TM2ShortPart(const double v)
  {
   return(MathMax(-v,0.0));
  }

int TM2SideScore(const double weighted,const double totalWeight)
  {
   if(totalWeight<=0.0)
      return(0);
   return((int)MathRound(100.0*TM2Clamp(weighted/totalWeight,0.0,1.0)));
  }

void TM2SideScores(const double &g[],const double &w[],const int count,
                   int &longScore,int &shortScore,double &total)
  {
   longScore=0;
   shortScore=0;
   total=0.0;
   double longW=0.0;
   double shortW=0.0;
   for(int i=0; i<count; i++)
     {
      total+=w[i];
      longW+=w[i]*TM2LongPart(g[i]);
      shortW+=w[i]*TM2ShortPart(g[i]);
     }
   longScore=TM2SideScore(longW,total);
   shortScore=TM2SideScore(shortW,total);
  }

int TM2ScoreLevel(const int score,const int noTrade,const int weak,const int setup,
                  const int strong)
  {
   if(score<=noTrade)
      return(0);
   if(score<=weak)
      return(1);
   if(score<=setup)
      return(2);
   if(score<=strong)
      return(3);
   return(4);
  }

int TM2MinLevel(const int minQuality)
  {
   switch(minQuality)
     {
      case TM2_MINQ_WEAK:   return(1);
      case TM2_MINQ_SETUP:  return(2);
      case TM2_MINQ_STRONG: return(3);
      case TM2_MINQ_APLUS:  return(4);
     }
   return(0);
  }

int TM2DirectionCode(const int longScore,const int shortScore,const int noTrade,
                     const int margin)
  {
   const bool longOk=longScore>noTrade;
   const bool shortOk=shortScore>noTrade;
   if(!(longOk || shortOk))
      return(TM2_DIRCODE_NONE);
   if(longOk && shortOk && MathAbs(longScore-shortScore)<margin)
      return(TM2_DIRCODE_AMBIG);
   return(TM2_DIRCODE_OK);
  }

int TM2CandidateDir(const int longScore,const int shortScore,const int noTrade)
  {
   const bool longOk=longScore>noTrade;
   const bool shortOk=shortScore>noTrade;
   if(longOk && longScore>=shortScore)
      return(1);
   if(shortOk && shortScore>longScore)
      return(-1);
   return(0);
  }

int TM2ScoreBlock(const int dirCode,const int dir,const bool okQuality)
  {
   if(dirCode!=TM2_DIRCODE_OK)
      return(dirCode==TM2_DIRCODE_NONE ? TM2_R_NO_DIRECTION : TM2_R_AMBIGUOUS);
   if(!okQuality)
     {
      if(dir==1)
         return(TM2_R_BLOCK_SCORE_LONG);
      if(dir==-1)
         return(TM2_R_BLOCK_SCORE_SHORT);
      return(TM2_R_NO_DIRECTION);
     }
   return(TM2_R_OK);
  }

//+------------------------------------------------------------------+
//| Gate block mask (contract 9.10: bitmask, not a string)           |
//+------------------------------------------------------------------+
#define TM2_MASK_REGIME      1
#define TM2_MASK_MTF         2
#define TM2_MASK_BTC         4
#define TM2_MASK_OBSTACLE    8
#define TM2_MASK_OVEREXT     16
#define TM2_MASK_LIQUIDITY   32

long TM2ServerDayStamp(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t,dt);
   return((long)dt.year*10000+(long)dt.mon*100+dt.day);
  }

//+------------------------------------------------------------------+
//| Active FVG / OB entry prices (contract 9.4)                      |
//+------------------------------------------------------------------+
void TM2ActiveFvgOb(const TM2EngineState &st,double &fvgBullPx,double &fvgBearPx,
                    double &obBullPx,double &obBearPx)
  {
   fvgBullPx=EMPTY_VALUE;
   fvgBearPx=EMPTY_VALUE;
   obBullPx=EMPTY_VALUE;
   obBearPx=EMPTY_VALUE;
   for(int i=0; i<st.fvgCount; i++)
     {
      if(st.fvg[i].dead)
         continue;
      const double mid=(st.fvg[i].top+st.fvg[i].bot)*0.5;
      if(st.fvg[i].side==1 && (TM2IsEmpty(fvgBullPx) || st.fvg[i].top>fvgBullPx))
         fvgBullPx=mid;
      if(st.fvg[i].side==-1 && (TM2IsEmpty(fvgBearPx) || st.fvg[i].bot<fvgBearPx))
         fvgBearPx=mid;
     }
   for(int i=0; i<st.obCount; i++)
     {
      if(st.ob[i].dead)
         continue;
      if(st.ob[i].side==1 && (TM2IsEmpty(obBullPx) || st.ob[i].top>obBullPx))
         obBullPx=st.ob[i].top;
      if(st.ob[i].side==-1 && (TM2IsEmpty(obBearPx) || st.ob[i].bot<obBearPx))
         obBearPx=st.ob[i].bot;
     }
  }

//+------------------------------------------------------------------+
//| Nearest barrier / support (contract 9.4, FVGs excluded)           |
//+------------------------------------------------------------------+
void TM2NearestLevels(const TM2Bar &bar,const TM2EngineState &st,
                      double &res,double &sup)
  {
   res=EMPTY_VALUE;
   sup=EMPTY_VALUE;
   for(int i=0; i<st.srCount; i++)
     {
      if(st.sr[i].broken)
         continue;
      if(st.sr[i].side==-1 && st.sr[i].bot>bar.close)
         res=TM2IsEmpty(res) ? st.sr[i].bot : MathMin(res,st.sr[i].bot);
      if(st.sr[i].side==1 && st.sr[i].top<bar.close)
         sup=TM2IsEmpty(sup) ? st.sr[i].top : MathMax(sup,st.sr[i].top);
     }
   for(int i=0; i<st.obCount; i++)
     {
      if(st.ob[i].dead)
         continue;
      if(st.ob[i].side==-1 && st.ob[i].bot>bar.close)
         res=TM2IsEmpty(res) ? st.ob[i].bot : MathMin(res,st.ob[i].bot);
      if(st.ob[i].side==1 && st.ob[i].top<bar.close)
         sup=TM2IsEmpty(sup) ? st.ob[i].top : MathMax(sup,st.ob[i].top);
     }
   const double minObsDist=bar.atrSafe*0.3;
   if(!TM2IsEmpty(st.pdh) && st.pdh>bar.close && (st.pdh-bar.close)>=minObsDist)
      res=TM2IsEmpty(res) ? st.pdh : MathMin(res,st.pdh);
   if(!TM2IsEmpty(st.pdl) && st.pdl<bar.close && (bar.close-st.pdl)>=minObsDist)
      sup=TM2IsEmpty(sup) ? st.pdl : MathMax(sup,st.pdl);
   if(!TM2IsEmpty(st.pwh) && st.pwh>bar.close && (st.pwh-bar.close)>=minObsDist)
      res=TM2IsEmpty(res) ? st.pwh : MathMin(res,st.pwh);
   if(!TM2IsEmpty(st.pwl) && st.pwl<bar.close && (bar.close-st.pwl)>=minObsDist)
      sup=TM2IsEmpty(sup) ? st.pwl : MathMax(sup,st.pwl);
  }

//+------------------------------------------------------------------+
//| Entry modes by market state (contract 9.9)                       |
//+------------------------------------------------------------------+
bool TM2ModeAPull(const bool longSide,const double low,const double high,
                  const double emaF,const double pbTol,const bool hasFvg,
                  const double fvgPx,const bool hasOb,const double obPx)
  {
   if(TM2IsEmpty(emaF))
      return(false);
   if(longSide)
     {
      if(low<=emaF+pbTol)
         return(true);
      if(hasFvg && !TM2IsEmpty(fvgPx) && low<=fvgPx+pbTol)
         return(true);
      if(hasOb && !TM2IsEmpty(obPx) && low<=obPx+pbTol)
         return(true);
      return(false);
     }
   if(high>=emaF-pbTol)
      return(true);
   if(hasFvg && !TM2IsEmpty(fvgPx) && high>=fvgPx-pbTol)
      return(true);
   if(hasOb && !TM2IsEmpty(obPx) && high>=obPx-pbTol)
      return(true);
   return(false);
  }

bool TM2ModeAConfirm(const bool longSide,const double open,const double close,
                     const double emaF,const double pbTol)
  {
   if(TM2IsEmpty(emaF))
      return(false);
   if(longSide)
      return(close>open && close>=emaF-pbTol);
   return(close<open && close<=emaF+pbTol);
  }

bool TM2ModeBReady(const bool longSide,const int sweepAge,const int sweepBars,
                   const bool hasPx,const bool confirm,const double close,
                   const double sweepPx)
  {
   if(!hasPx || TM2IsEmpty(sweepPx) || sweepAge<0 || sweepAge>sweepBars || !confirm)
      return(false);
   return(longSide ? close>sweepPx : close<sweepPx);
  }

bool TM2ModeBInvalid(const bool longSide,const int sweepAge,const int sweepBars,
                     const bool hasPx,const double close,const double sweepPx,
                     const double atrSafe)
  {
   if(!hasPx || TM2IsEmpty(sweepPx) || sweepAge<0 || sweepAge>sweepBars)
      return(false);
   return(longSide ? close<sweepPx-0.1*atrSafe : close>sweepPx+0.1*atrSafe);
  }

bool TM2ModeCReady(const bool longSide,const bool boxOk,const double close,
                   const double res,const double sup,const double rgTol,
                   const double atrSafe,const bool confirm,const double open)
  {
   if(!boxOk)
      return(false);
   if(longSide)
      return(close<=sup+rgTol && close>=sup-atrSafe && confirm && close>open);
   return(close>=res-rgTol && close<=res+atrSafe && confirm && close<open);
  }

void TM2SelectMode(const TM2ModeInput &in,int &modeDir,int &activeMode)
  {
   modeDir=0;
   activeMode=TM2_MODE_NONE;

   const double pbTol=in.atrSafe*in.modePullTol;
   const double rgTol=in.atrSafe*in.modeRangeTol;
   const int modeADir=in.regimeCode==1 ? in.regimeDir : 0;
   const bool modeAMtfOk=modeADir==1 ? (in.ctxDir>=0 && in.setupDir>=0) :
                        modeADir==-1 ? (in.ctxDir<=0 && in.setupDir<=0) : false;

   const bool pullLong=TM2ModeAPull(true,in.low,in.high,in.emaF,pbTol,
                                    in.hasFvgBull,in.fvgBullPx,in.hasObBull,in.obBullPx);
   const bool pullShort=TM2ModeAPull(false,in.low,in.high,in.emaF,pbTol,
                                     in.hasFvgBear,in.fvgBearPx,in.hasObBear,in.obBearPx);
   const bool confirmLongA=TM2ModeAConfirm(true,in.open,in.close,in.emaF,pbTol);
   const bool confirmShortA=TM2ModeAConfirm(false,in.open,in.close,in.emaF,pbTol);

   const bool readyALong=in.modeAOn && modeADir==1 && modeAMtfOk && pullLong && confirmLongA;
   const bool readyAShort=in.modeAOn && modeADir==-1 && modeAMtfOk && pullShort && confirmShortA;

   const bool readyBLong=in.modeBOn && TM2ModeBReady(true,in.sweepAgeBull,in.modeSweepBars,
                                                    in.hasSweepBullPx,in.confirmBull,in.close,in.sweepBullPx);
   const bool readyBShort=in.modeBOn && TM2ModeBReady(false,in.sweepAgeBear,in.modeSweepBars,
                                                     in.hasSweepBearPx,in.confirmBear,in.close,in.sweepBearPx);

   bool boxOk=false;
   if(in.regimeCode==0 && in.hasRes && in.hasSup &&
      (in.nearestRes-in.nearestSup)>in.atrSafe)
      boxOk=true;

   const bool readyCLong=in.modeCOn && TM2ModeCReady(true,boxOk,in.close,in.nearestRes,
                                                     in.nearestSup,rgTol,in.atrSafe,
                                                     in.confirmBull,in.open);
   const bool readyCShort=in.modeCOn && TM2ModeCReady(false,boxOk,in.close,in.nearestRes,
                                                      in.nearestSup,rgTol,in.atrSafe,
                                                      in.confirmBear,in.open);

   if(readyALong)
     {
      modeDir=1;
      activeMode=TM2_MODE_A;
     }
   else if(readyAShort)
     {
      modeDir=-1;
      activeMode=TM2_MODE_A;
     }
   else if(readyBLong)
     {
      modeDir=1;
      activeMode=TM2_MODE_B;
     }
   else if(readyBShort)
     {
      modeDir=-1;
      activeMode=TM2_MODE_B;
     }
   else if(readyCLong)
     {
      modeDir=1;
      activeMode=TM2_MODE_C;
     }
   else if(readyCShort)
     {
      modeDir=-1;
      activeMode=TM2_MODE_C;
     }
  }

int TM2ModeReason(const TM2ModeInput &in,const bool filterOn,const int modeReady)
  {
   if(!filterOn)
      return(TM2_R_OK);
   if(modeReady==TM2_MODE_A)
      return(TM2_R_MODE_A_PULLBACK);
   if(modeReady==TM2_MODE_B)
      return(TM2_R_MODE_B_SWEEP);
   if(modeReady==TM2_MODE_C)
      return(TM2_R_MODE_C_RANGE);
   if(in.modeBOn &&
      (TM2ModeBInvalid(true,in.sweepAgeBull,in.modeSweepBars,in.hasSweepBullPx,
                       in.close,in.sweepBullPx,in.atrSafe) ||
       TM2ModeBInvalid(false,in.sweepAgeBear,in.modeSweepBars,in.hasSweepBearPx,
                       in.close,in.sweepBearPx,in.atrSafe)))
      return(TM2_R_MODE_INVALIDATED);

   const double pbTol=in.atrSafe*in.modePullTol;
   const double rgTol=in.atrSafe*in.modeRangeTol;
   const bool pullLong=TM2ModeAPull(true,in.low,in.high,in.emaF,pbTol,
                                    in.hasFvgBull,in.fvgBullPx,in.hasObBull,in.obBullPx);
   const bool pullShort=TM2ModeAPull(false,in.low,in.high,in.emaF,pbTol,
                                     in.hasFvgBear,in.fvgBearPx,in.hasObBear,in.obBearPx);
   const bool freshBull=in.hasSweepBullPx && in.sweepAgeBull>=0 &&
                        in.sweepAgeBull<=in.modeSweepBars;
   const bool freshBear=in.hasSweepBearPx && in.sweepAgeBear>=0 &&
                        in.sweepAgeBear<=in.modeSweepBars;
   bool boxOk=false;
   if(in.regimeCode==0 && in.hasRes && in.hasSup &&
      (in.nearestRes-in.nearestSup)>in.atrSafe)
      boxOk=true;
   const bool nearSup=boxOk && in.close<=in.nearestSup+rgTol &&
                      in.close>=in.nearestSup-in.atrSafe;
   const bool nearRes=boxOk && in.close>=in.nearestRes-rgTol &&
                      in.close<=in.nearestRes+in.atrSafe;

   if(pullLong || pullShort || freshBull || freshBear || nearSup || nearRes)
      return(TM2_R_WAIT_CONFIRMATION);
   const int modeADir=in.regimeCode==1 ? in.regimeDir : 0;
   if(modeADir!=0)
      return(TM2_R_WAIT_PULLBACK);
   return(TM2_R_NO_SETUP);
  }

bool TM2ObstacleBlocked(const bool longSide,const bool hasDist,const double dist,
                        const double estTp1,const double buffer)
  {
   if(!hasDist || TM2IsEmpty(dist))
      return(false);
   const double roomLimit=estTp1*buffer;
   return(longSide ? dist<roomLimit : dist<roomLimit);
  }

//+------------------------------------------------------------------+
//| Eligibility gates (contract 9.10)                                |
//+------------------------------------------------------------------+
void TM2EvaluateGates(const TM2Config &cfg,const TM2Bar &bar,
                      const TM2EngineState &st,const int dir,TM2GateStatus &out)
  {
   out.regimeOk=true;
   out.mtfOk=true;
   out.btcOk=true;
   out.obstacleOk=true;
   out.overextOk=true;
   out.circuitOk=true;
   out.allPassed=false;
   out.topReason=TM2_R_OK;
   out.blockMask=0;

   int regCode=0;
   int regDir=0;
   const bool hasEma=!TM2IsEmpty(bar.emaF) && !TM2IsEmpty(bar.emaM) && !TM2IsEmpty(bar.emaS);
   const bool emaUp=hasEma && bar.close>bar.emaF && bar.emaF>bar.emaM && bar.slope20>0.03;
   const bool emaDn=hasEma && bar.close<bar.emaF && bar.emaF<bar.emaM && bar.slope20<-0.03;
   TM2ClassifyRegime(bar.adx,bar.isSqueeze,bar.slope20,emaUp,emaDn,bar.bbwPct,
                     cfg,regCode,regDir);

   double nearestRes=EMPTY_VALUE;
   double nearestSup=EMPTY_VALUE;
   TM2NearestLevels(bar,st,nearestRes,nearestSup);

   bool regimeBlocked=false;
   if(cfg.gateRegime && regCode==-1)
      regimeBlocked=true;
   else if(cfg.gateRegime && regCode==0)
     {
      if(!TM2IsEmpty(nearestRes) && !TM2IsEmpty(nearestSup))
        {
         const double rangeMid=(nearestRes+nearestSup)*0.5;
         if(dir==1 && bar.close>rangeMid)
            regimeBlocked=true;
         if(dir==-1 && bar.close<rangeMid)
            regimeBlocked=true;
        }
     }
   if(regimeBlocked)
     {
      out.regimeOk=false;
      out.topReason=TM2_R_BLOCK_REGIME;
      out.blockMask|=TM2_MASK_REGIME;
     }

   const bool setupOk=!cfg.htfFilter || !bar.mtfHierOk || bar.setupDir==0 ||
                      bar.setupDir==dir;
   const bool vetoCtx=cfg.htfVetoOn && bar.mtfHierOk && bar.ctxDir!=0 &&
                      bar.ctxDir!=dir;
   out.mtfOk=setupOk && !vetoCtx;
   if(!out.mtfOk)
     {
      if(out.topReason==TM2_R_OK)
         out.topReason=TM2_R_BLOCK_MTF;
      out.blockMask|=TM2_MASK_MTF;
     }

   const bool btcData=bar.btcOk;
   const bool btcDump=bar.btcNeed && btcData &&
                      (bar.btcClose<bar.btcEma-cfg.btcImpulseAtr*bar.btcAtr ||
                       bar.btcRsi<32.0);
   const bool btcPump=bar.btcNeed && btcData &&
                      (bar.btcClose>bar.btcEma+cfg.btcImpulseAtr*bar.btcAtr ||
                       bar.btcRsi>68.0);
   out.btcOk=dir==1 ? !btcDump : dir==-1 ? !btcPump : true;
   if(!out.btcOk)
     {
      if(out.topReason==TM2_R_OK)
         out.topReason=dir==1 ? TM2_R_BTC_DUMPING : TM2_R_BTC_PUMPING;
      out.blockMask|=TM2_MASK_BTC;
     }

   const double estDistTp1=bar.atrSafe*cfg.slAtrMul*cfg.rr1;
   const double distToRes=TM2IsEmpty(nearestRes) ? EMPTY_VALUE : nearestRes-bar.close;
   const double distToSup=TM2IsEmpty(nearestSup) ? EMPTY_VALUE : bar.close-nearestSup;
   const bool blockedLong=TM2ObstacleBlocked(true,!TM2IsEmpty(distToRes),distToRes,
                                             estDistTp1,cfg.obstacleBuffer);
   const bool blockedShort=TM2ObstacleBlocked(false,!TM2IsEmpty(distToSup),distToSup,
                                              estDistTp1,cfg.obstacleBuffer);
   out.obstacleOk=!cfg.gateObstacle ||
                  (dir==1 ? !blockedLong : dir==-1 ? !blockedShort : true);
   if(!out.obstacleOk)
     {
      if(out.topReason==TM2_R_OK)
         out.topReason=TM2_R_BLOCK_OBSTACLE;
      out.blockMask|=TM2_MASK_OBSTACLE;
     }

   out.overextOk=!cfg.gateOverext || !bar.isOverext || cfg.entryMode!=TM2_ENTRY_MARKET;
   if(!out.overextOk)
     {
      if(out.topReason==TM2_R_OK)
         out.topReason=TM2_R_BLOCK_OVEREXT;
      out.blockMask|=TM2_MASK_OVEREXT;
     }

   if(bar.weekendBlocked)
     {
      out.circuitOk=false;
      if(out.topReason==TM2_R_OK)
         out.topReason=TM2_R_BLOCK_LIQUIDITY;
      out.blockMask|=TM2_MASK_LIQUIDITY;
     }

   out.allPassed=out.regimeOk && out.mtfOk && out.btcOk && out.obstacleOk &&
                 out.overextOk && out.circuitOk;
  }

//+------------------------------------------------------------------+
//| Plan builder, sizing, net RR (contract 9.11)                     |
//+------------------------------------------------------------------+
void TM2BuildPlan(const TM2Config &cfg,const TM2Bar &bar,
                  const TM2EngineState &st,const int dir,TM2Plan &plan)
  {
   plan.valid=false;
   plan.dir=dir;
   plan.orderType=TM2_ORDER_MARKET;
   plan.entry=EMPTY_VALUE;
   plan.limit=EMPTY_VALUE;
   plan.sl=EMPTY_VALUE;
   plan.tp1=EMPTY_VALUE;
   plan.tp2=EMPTY_VALUE;
   plan.tp3=EMPTY_VALUE;
   plan.risk=EMPTY_VALUE;
   plan.evalRR=EMPTY_VALUE;
   plan.posSize=EMPTY_VALUE;
   plan.notional=EMPTY_VALUE;
   plan.effLev=EMPTY_VALUE;
   plan.marginReq=EMPTY_VALUE;
   plan.liqPrice=EMPTY_VALUE;
   plan.netRR=EMPTY_VALUE;
   plan.reason=TM2_R_BLOCK_NO_ATR;

   const bool atrOk=!TM2IsEmpty(bar.atr) && bar.atr>0.0;
   const bool dirOk=dir==1 || dir==-1;
   const double r1=cfg.rr1;
   const double r2=MathMax(cfg.rr2,cfg.rr1+0.5);
   const double r3=MathMax(cfg.rr3,r2+1.0);
   plan.evalRR=r2;

   int ordType=TM2_ORDER_MARKET;
   if(cfg.entryMode==TM2_ENTRY_LIMIT_STRICT)
      ordType=TM2_ORDER_LIMIT;
   else if(cfg.entryMode==TM2_ENTRY_AUTO)
      ordType=bar.isOverext ? TM2_ORDER_LIMIT : TM2_ORDER_MARKET;
   plan.orderType=ordType;

   double fvgBullPx=EMPTY_VALUE;
   double fvgBearPx=EMPTY_VALUE;
   double obBullPx=EMPTY_VALUE;
   double obBearPx=EMPTY_VALUE;
   TM2ActiveFvgOb(st,fvgBullPx,fvgBearPx,obBullPx,obBearPx);

   double limPx=EMPTY_VALUE;
   if(dir==1)
     {
      limPx=cfg.limitSource==TM2_LIMIT_FVG50 && !TM2IsEmpty(fvgBullPx) ? fvgBullPx :
            cfg.limitSource==TM2_LIMIT_OB_EDGE && !TM2IsEmpty(obBullPx) ? obBullPx :
            bar.emaF;
      if(!TM2IsEmpty(limPx))
         limPx=MathMin(limPx,bar.close-bar.mintick);
     }
   else if(dir==-1)
     {
      limPx=cfg.limitSource==TM2_LIMIT_FVG50 && !TM2IsEmpty(fvgBearPx) ? fvgBearPx :
            cfg.limitSource==TM2_LIMIT_OB_EDGE && !TM2IsEmpty(obBearPx) ? obBearPx :
            bar.emaF;
      if(!TM2IsEmpty(limPx))
         limPx=MathMax(limPx,bar.close+bar.mintick);
     }
   plan.limit=limPx;

   const double entryPx=(ordType==TM2_ORDER_LIMIT && dir!=0) ? limPx : bar.close;
   plan.entry=entryPx;

   if(!atrOk)
      return;
   if(TM2IsEmpty(entryPx))
     {
      plan.reason=TM2_R_BLOCK_BAD_SL;
      return;
     }

   const double a=bar.atr;
   const double pad=a*cfg.slPadAtr;
   const double swing=dir==1 ? (st.hasSwingLo ? st.swingLo : bar.low) :
                            (st.hasSwingHi ? st.swingHi : bar.high);
   const double sDist=dir==1 ? (entryPx-swing)+pad : (swing-entryPx)+pad;
   const double aDist=a*cfg.slAtrMul;
   const double base=(aDist+sDist)*0.5;
   const double dist=TM2Clamp(base,a*cfg.slMinAtr,a*cfg.slMaxAtr);

   const double slPx=entryPx-dir*dist;
   const double risk=dist;
   const double tp1=entryPx+dir*r1*risk;
   const double tp2=entryPx+dir*r2*risk;
   const double tp3=entryPx+dir*r3*risk;

   const bool rrOk=cfg.rrMin<=0.0 || r2>=cfg.rrMin;
   const bool slOk=dist>0.0 && !TM2IsEmpty(slPx) &&
                   (dir==1 ? slPx<entryPx : slPx>entryPx);
   const bool tpOk=!TM2IsEmpty(tp1) && !TM2IsEmpty(tp2) && !TM2IsEmpty(tp3) &&
                   (dir==1 ? (entryPx<tp1 && tp1<tp2 && tp2<tp3) :
                             (entryPx>tp1 && tp1>tp2 && tp2>tp3));

   const double riskUsd=cfg.riskEquity*(cfg.riskPct/100.0);
   const double posSize=dist>0.0 ? riskUsd/dist : 0.0;
   const double notional=posSize*entryPx;
   const double effLev=cfg.riskEquity>0.0 ? notional/cfg.riskEquity : 0.0;
   const double marginReq=cfg.riskMaxLev>0.0 ? notional/cfg.riskMaxLev : notional;

   const double levForLiq=MathMax(effLev,1.0);
   const double liqLong=entryPx*MathMax(0.0,1.0-(1.0/levForLiq)+cfg.riskMmr);
   const double liqShort=entryPx*(1.0+(1.0/levForLiq)-cfg.riskMmr);
   const double liqPrice=dir==1 ? liqLong : dir==-1 ? liqShort : EMPTY_VALUE;

   const bool liqOk=!cfg.gateRisk ||
                    (dir==1 ? slPx>liqPrice : slPx<liqPrice);
   const bool levOk=!cfg.gateRisk || cfg.riskMaxLev<=0.0 ||
                    effLev<=(cfg.riskMaxLev*1.05);

   const double fee=notional*(cfg.riskFeeSlipPct/100.0);
   const double netProfit=(r2*riskUsd)-fee;
   const double netRisk=riskUsd+fee;
   const double netRR=netRisk>0.0 ? netProfit/netRisk : r2;
   const bool netRrOk=cfg.rrMin<=0.0 || netRR>=cfg.rrMin;

   plan.evalRR=r2;
   plan.sl=slPx;
   plan.tp1=tp1;
   plan.tp2=tp2;
   plan.tp3=tp3;
   plan.risk=risk;
   plan.posSize=posSize;
   plan.notional=notional;
   plan.effLev=effLev;
   plan.marginReq=marginReq;
   plan.liqPrice=liqPrice;
   plan.netRR=netRR;

   if(!dirOk)
     {
      plan.reason=TM2_R_NO_DIRECTION;
      plan.valid=false;
      return;
     }
   if(!slOk)
     {
      plan.reason=TM2_R_BLOCK_BAD_SL;
      plan.valid=false;
      return;
     }
   if(!tpOk)
     {
      plan.reason=TM2_R_BLOCK_BAD_TP;
      plan.valid=false;
      return;
     }
   if(!rrOk)
     {
      plan.reason=TM2_R_BLOCK_RR;
      plan.valid=false;
      return;
     }
   if(!levOk)
     {
      plan.reason=TM2_R_BLOCK_MAX_LEV;
      plan.valid=false;
      return;
     }
   if(!liqOk)
     {
      plan.reason=TM2_R_BLOCK_LIQUIDATION;
      plan.valid=false;
      return;
     }
   if(!netRrOk)
     {
      plan.reason=TM2_R_BLOCK_NET_RR;
      plan.valid=false;
      return;
     }

   plan.reason=TM2_R_OK;
   plan.valid=atrOk && dirOk && slOk && tpOk && rrOk && levOk && liqOk && netRrOk;
  }

//+------------------------------------------------------------------+
//| State init (contract 7.1)                                        |
//+------------------------------------------------------------------+
void TM2StateInit(TM2EngineState &st)
  {
   st.swingHi=EMPTY_VALUE;
   st.swingLo=EMPTY_VALUE;
   st.prevHigh=EMPTY_VALUE;
   st.prevLow=EMPTY_VALUE;
   st.brkLevel=EMPTY_VALUE;
   st.hiBar=-1;
   st.loBar=-1;
   st.trend=0;
   st.brkBar=-1;
   st.brkDir=0;
   st.hasSwingHi=false;
   st.hasSwingLo=false;
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
   st.isHH=false;
   st.isLL=false;
   st.eqHi=false;
   st.eqLo=false;

   st.sessHi=EMPTY_VALUE;
   st.sessLo=EMPTY_VALUE;
   st.sessPrev=TM2_SESS_NONE;
   st.hasSessHi=false;
   st.hasSessLo=false;

   for(int i=0; i<TM2_MAX_SR; i++)
     {
      st.sr[i].top=EMPTY_VALUE;
      st.sr[i].bot=EMPTY_VALUE;
      st.sr[i].side=0;
      st.sr[i].touches=0;
      st.sr[i].broken=false;
     }
   st.srCount=0;
   for(int i=0; i<TM2_MAX_FVG; i++)
     {
      st.fvg[i].top=EMPTY_VALUE;
      st.fvg[i].bot=EMPTY_VALUE;
      st.fvg[i].srcBar=-1;
      st.fvg[i].side=0;
      st.fvg[i].dead=false;
     }
   st.fvgCount=0;
   for(int i=0; i<TM2_MAX_OB; i++)
     {
      st.ob[i].top=EMPTY_VALUE;
      st.ob[i].bot=EMPTY_VALUE;
      st.ob[i].srcBar=-1;
      st.ob[i].side=0;
      st.ob[i].dead=false;
     }
   st.obCount=0;

   for(int i=0; i<TM2_MAX_EVT; i++)
     {
      st.evt[i].kind=TM2_EVT_NONE;
      st.evt[i].dir=0;
      st.evt[i].srcBar=-1;
      st.evt[i].srcTime=0;
      st.evt[i].confirmed=false;
      st.evt[i].level=EMPTY_VALUE;
     }
   st.evtCount=0;
   st.lastSweepBullBar=-1;
   st.lastSweepBearBar=-1;
   st.lastSweepBullPx=EMPTY_VALUE;
   st.lastSweepBearPx=EMPTY_VALUE;

   st.obv=0.0;
   ArrayInitialize(st.obvHist,0.0);
   st.obvCount=0;
   st.vwapPV=0.0;
   st.vwapVol=0.0;
   st.dayStamp=-1;
   st.pdh=EMPTY_VALUE;
   st.pdl=EMPTY_VALUE;
   st.pwh=EMPTY_VALUE;
   st.pwl=EMPTY_VALUE;
   st.hasPd=false;
   st.hasPw=false;

   st.dayCount=0;
   st.barsSince=999999;
   st.consecLosses=0;

   st.posStage=TM2_STAGE_IDLE;
   st.posDir=0;
   st.posBars=0;
   st.posBar=-1;
   st.posMode=TM2_MODE_NONE;
   st.posOrderType=TM2_ORDER_NONE;
   st.posEntry=EMPTY_VALUE;
   st.posLimit=EMPTY_VALUE;
   st.posSl=EMPTY_VALUE;
   st.posTp1=EMPTY_VALUE;
   st.posTp2=EMPTY_VALUE;
   st.posTp3=EMPTY_VALUE;
   st.posRisk=EMPTY_VALUE;
   st.posMaxFavR=0.0;
   st.needReset=false;

   st.xEntry=EMPTY_VALUE;
   st.xSl=EMPTY_VALUE;
   st.xTp1=EMPTY_VALUE;
   st.xTp2=EMPTY_VALUE;
   st.xTp3=EMPTY_VALUE;
   st.xExit=EMPTY_VALUE;
   st.xR=EMPTY_VALUE;
   st.xDir=0;
   st.xBar=-1;
   st.xReason=TM2_X_NONE;
   st.xStage=0;

   st.trades=0;
   st.tp1Hits=0;
   st.netWins=0;
   st.beSaves=0;
   st.fullLosses=0;
   st.timeouts=0;
   st.decays=0;
   st.candidates=0;
   st.eligibleN=0;
   st.pendingN=0;
   st.filledN=0;
   st.closedN=0;
   st.realizedRSum=0.0;
   st.prevCandidate=false;
   st.prevEligible=false;

   st.evEntry=false;
   st.evPending=false;
   st.evFilled=false;
   st.evCancel=false;
   st.evSl=false;
   st.evBe=false;
   st.evTrail=false;
   st.evTimeout=false;
   st.evDecay=false;
   st.evClose=false;
   st.evTp=0;
   st.exitReason=TM2_X_NONE;
   st.cancelReason=TM2_X_NONE;
   st.realizedR=0.0;
  }

//+------------------------------------------------------------------+
//| Engine step: one closed bar (contract 8)                          |
//+------------------------------------------------------------------+
void TM2EngineStep(const TM2Config &cfg,TM2EngineState &st,const TM2Bar &bar,
                   const int barIndex,TM2BarOut &out)
  {
   //--- 0. reset per-bar edge flags ---------------------------------
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
   st.isHH=false;
   st.isLL=false;
   st.eqHi=false;
   st.eqLo=false;
   st.evEntry=false;
   st.evPending=false;
   st.evFilled=false;
   st.evCancel=false;
   st.evSl=false;
   st.evBe=false;
   st.evTrail=false;
   st.evTimeout=false;
   st.evDecay=false;
   st.evClose=false;
   st.evTp=0;
   st.cancelReason=TM2_X_NONE;
   st.realizedR=0.0;

   const bool atrOk=!TM2IsEmpty(bar.atr) && bar.atr>0.0;

   //--- 1. regime ----------------------------------------------------
   const bool hasEma=!TM2IsEmpty(bar.emaF) && !TM2IsEmpty(bar.emaM) && !TM2IsEmpty(bar.emaS);
   const bool emaUp=hasEma && bar.close>bar.emaF && bar.emaF>bar.emaM && bar.slope20>0.03;
   const bool emaDn=hasEma && bar.close<bar.emaF && bar.emaF<bar.emaM && bar.slope20<-0.03;
   int regimeCode=0;
   int regimeDir=0;
   TM2ClassifyRegime(bar.adx,bar.isSqueeze,bar.slope20,emaUp,emaDn,bar.bbwPct,
                     cfg,regimeCode,regimeDir);

   //--- 2. candle metrics --------------------------------------------
   const double body=MathAbs(bar.close-bar.open);
   const double range=MathMax(bar.high-bar.low,bar.mintick);
   const double hiWick=bar.high-MathMax(bar.close,bar.open);
   const double loWick=MathMin(bar.close,bar.open)-bar.low;
   const bool bullBar=bar.close>bar.open;
   const bool bearBar=bar.close<bar.open;
   const double prevBody=MathAbs(bar.prevClose-bar.prevOpen);

   bool dispBull=false;
   bool dispBear=false;
   if(atrOk)
     {
      dispBull=body>=1.5*bar.atr && hiWick<body*0.3;
      dispBear=body>=1.5*bar.atr && loWick<body*0.3;
     }
   const bool pinBull=bullBar && loWick>=2.0*body;
   const bool pinBear=bearBar && hiWick>=2.0*body;
   const bool engBull=bullBar && bar.prevClose<bar.prevOpen && bar.close>=bar.prevOpen &&
                      bar.open<=bar.prevClose && body>=prevBody;
   const bool engBear=bearBar && bar.prevClose>bar.prevOpen && bar.close<=bar.prevOpen &&
                      bar.open>=bar.prevClose && body>=prevBody;
   const bool rejBull=hiWick>=range*0.55 && loWick<=range*0.15 && bullBar;
   const bool rejBear=loWick>=range*0.55 && hiWick<=range*0.15 && bearBar;
   const double cpBull=(pinBull?1.0:0.0)+(engBull?1.0:0.0)+(dispBull?1.2:0.0)+(rejBull?0.8:0.0);
   const double cpBear=(pinBear?1.0:0.0)+(engBear?1.0:0.0)+(dispBear?1.2:0.0)+(rejBear?0.8:0.0);
   const double cpScore=TM2CandleScore(pinBull,engBull,dispBull,rejBull,
                                       pinBear,engBear,dispBear,rejBear);

   //--- 3. structure -------------------------------------------------
   const double priorSwingHi=st.swingHi;
   const double priorSwingLo=st.swingLo;
   const bool priorHasSwingHi=st.hasSwingHi;
   const bool priorHasSwingLo=st.hasSwingLo;

   if(bar.pivHOk)
     {
      st.prevHigh=st.swingHi;
      st.hasPrevHigh=st.hasSwingHi;
      st.swingHi=bar.pivH;
      st.hasSwingHi=true;
      st.hiBar=barIndex-cfg.msSwingLen;
     }
   if(bar.pivLOk)
     {
      st.prevLow=st.swingLo;
      st.hasPrevLow=st.hasSwingLo;
      st.swingLo=bar.pivL;
      st.hasSwingLo=true;
      st.loBar=barIndex-cfg.msSwingLen;
     }

   if(st.hasSwingHi && st.hasPrevHigh && st.hasSwingLo && st.hasPrevLow)
     {
      if(st.swingHi>st.prevHigh && st.swingLo>st.prevLow)
         st.trend=1;
      else if(st.swingHi<st.prevHigh && st.swingLo<st.prevLow)
         st.trend=-1;
     }

   const bool crossOverHi=st.hasSwingHi && !TM2IsEmpty(st.swingHi) &&
                          bar.close>st.swingHi && priorHasSwingHi &&
                          bar.prevClose<=priorSwingHi;
   const bool crossUnderLo=st.hasSwingLo && !TM2IsEmpty(st.swingLo) &&
                           bar.close<st.swingLo && priorHasSwingLo &&
                           bar.prevClose>=priorSwingLo;

   st.bosUp=cfg.msBosOn && st.hasSwingHi && crossOverHi && st.trend==1;
   st.bosDown=cfg.msBosOn && st.hasSwingLo && crossUnderLo && st.trend==-1;
   st.chochUp=cfg.msChochOn && st.hasSwingHi && crossOverHi && st.trend==-1;
   st.chochDown=cfg.msChochOn && st.hasSwingLo && crossUnderLo && st.trend==1;
   st.mssUp=cfg.msMssOn && st.chochUp && dispBull;
   st.mssDown=cfg.msMssOn && st.chochDown && dispBear;

   if(st.bosUp)
      TM2PushEvent(st,TM2_EVT_BOS,1,barIndex,bar.time,st.swingHi);
   if(st.bosDown)
      TM2PushEvent(st,TM2_EVT_BOS,-1,barIndex,bar.time,st.swingLo);
   if(st.chochUp)
      TM2PushEvent(st,TM2_EVT_CHOCH,1,barIndex,bar.time,st.swingHi);
   if(st.chochDown)
      TM2PushEvent(st,TM2_EVT_CHOCH,-1,barIndex,bar.time,st.swingLo);
   if(st.mssUp)
      TM2PushEvent(st,TM2_EVT_MSS,1,barIndex,bar.time,st.swingHi);
   if(st.mssDown)
      TM2PushEvent(st,TM2_EVT_MSS,-1,barIndex,bar.time,st.swingLo);

   if(st.bosUp || st.chochUp)
     {
      st.brkLevel=st.swingHi;
      st.brkBar=barIndex;
      st.brkDir=1;
      st.hasBrk=true;
     }
   else if(st.bosDown || st.chochDown)
     {
      st.brkLevel=st.swingLo;
      st.brkBar=barIndex;
      st.brkDir=-1;
      st.hasBrk=true;
     }

   if(cfg.msRetestOn && st.hasBrk && atrOk && !TM2IsEmpty(st.brkLevel) &&
      (barIndex-st.brkBar)<=cfg.msRetestBars && (barIndex-st.brkBar)>=1)
     {
      const double tol=cfg.msRetestTolAtr*bar.atr;
      if(st.brkDir==1)
         st.retestBull=bar.low<=st.brkLevel+tol && bar.close>st.brkLevel;
      else if(st.brkDir==-1)
         st.retestBear=bar.high>=st.brkLevel-tol && bar.close<st.brkLevel;
     }

   if(cfg.msFailOn && st.hasBrk && atrOk && !TM2IsEmpty(st.brkLevel) &&
      (barIndex-st.brkBar)<=cfg.msFailBars)
     {
      if(st.brkDir==1)
         st.failBull=bar.close<st.brkLevel-bar.atr*0.3;
      else if(st.brkDir==-1)
         st.failBear=bar.close>st.brkLevel+bar.atr*0.3;
     }

   st.isHH=bar.pivHOk && priorHasSwingHi && bar.pivH>priorSwingHi;
   st.isLL=bar.pivLOk && priorHasSwingLo && bar.pivL<priorSwingLo;
   st.contBull=cfg.msContOn && st.trend==1 && st.isHH;
   st.contBear=cfg.msContOn && st.trend==-1 && st.isLL;
   if(cfg.msPullOn && st.trend==1 && !TM2IsEmpty(bar.emaM))
      st.pullBull=bar.low<=bar.emaM && bar.close>bar.emaM;
   if(cfg.msPullOn && st.trend==-1 && !TM2IsEmpty(bar.emaM))
      st.pullBear=bar.high>=bar.emaM && bar.close<bar.emaM;

   const double eqThresh=atrOk ? bar.atr*0.05 : EMPTY_VALUE;
   st.eqHi=bar.pivHOk && st.hasPrevHigh && atrOk &&
           MathAbs(bar.pivH-st.prevHigh)<=eqThresh;
   st.eqLo=bar.pivLOk && st.hasPrevLow && atrOk &&
           MathAbs(bar.pivL-st.prevLow)<=eqThresh;

   //--- 4. session ---------------------------------------------------
   const bool sessChanged=bar.sessName!=st.sessPrev;
   if(sessChanged && bar.sessName!=TM2_SESS_NONE)
     {
      st.sessHi=bar.high;
      st.sessLo=bar.low;
      st.hasSessHi=true;
      st.hasSessLo=true;
     }
   else if(bar.sessName!=TM2_SESS_NONE)
     {
      st.sessHi=MathMax(st.hasSessHi ? st.sessHi : bar.high,bar.high);
      st.sessLo=MathMin(st.hasSessLo ? st.sessLo : bar.low,bar.low);
      st.hasSessHi=true;
      st.hasSessLo=true;
     }
   if(bar.sessName!=TM2_SESS_NONE)
      st.sessPrev=bar.sessName;

   //--- 5. zones -----------------------------------------------------
   if(bar.srPivHOk)
      TM2ZoneAdd(st,bar.srPivH,-1,bar.atr,cfg.srWidthAtr,cfg.srMax);
   if(bar.srPivLOk)
      TM2ZoneAdd(st,bar.srPivL,1,bar.atr,cfg.srWidthAtr,cfg.srMax);

   if(atrOk)
     {
      if(!TM2IsEmpty(bar.high2) && bar.low>bar.high2 &&
         (bar.low-bar.high2)>=cfg.fvgMinAtr*bar.atr)
        {
         if(st.fvgCount>=TM2_MAX_FVG)
           {
            for(int i=1; i<st.fvgCount; i++)
               st.fvg[i-1]=st.fvg[i];
            st.fvgCount=TM2_MAX_FVG-1;
           }
         st.fvg[st.fvgCount].top=bar.low;
         st.fvg[st.fvgCount].bot=bar.high2;
         st.fvg[st.fvgCount].srcBar=barIndex;
         st.fvg[st.fvgCount].side=1;
         st.fvg[st.fvgCount].dead=false;
         st.fvgCount++;
        }
      if(!TM2IsEmpty(bar.low2) && bar.high<bar.low2 &&
         (bar.low2-bar.high)>=cfg.fvgMinAtr*bar.atr)
        {
         if(st.fvgCount>=TM2_MAX_FVG)
           {
            for(int i=1; i<st.fvgCount; i++)
               st.fvg[i-1]=st.fvg[i];
            st.fvgCount=TM2_MAX_FVG-1;
           }
         st.fvg[st.fvgCount].top=bar.low2;
         st.fvg[st.fvgCount].bot=bar.high;
         st.fvg[st.fvgCount].srcBar=barIndex;
         st.fvg[st.fvgCount].side=-1;
         st.fvg[st.fvgCount].dead=false;
         st.fvgCount++;
        }
     }
   while(st.fvgCount>cfg.fvgMax && st.fvgCount>0)
     {
      for(int i=1; i<st.fvgCount; i++)
         st.fvg[i-1]=st.fvg[i];
      st.fvgCount--;
     }
   for(int i=0; i<st.fvgCount; i++)
     {
      if(barIndex-st.fvg[i].srcBar>cfg.fvgLife)
         st.fvg[i].dead=true;
      if(st.fvg[i].side==1 && bar.low<=st.fvg[i].bot)
         st.fvg[i].dead=true;
      if(st.fvg[i].side==-1 && bar.high>=st.fvg[i].top)
         st.fvg[i].dead=true;
     }

   const bool newObBull=dispBull && bar.prevClose<bar.prevOpen;
   const bool newObBear=dispBear && bar.prevClose>bar.prevOpen;
   if(newObBull)
     {
      if(st.obCount>=TM2_MAX_OB)
        {
         for(int i=1; i<st.obCount; i++)
            st.ob[i-1]=st.ob[i];
         st.obCount=TM2_MAX_OB-1;
        }
      st.ob[st.obCount].top=bar.prevOpen;
      st.ob[st.obCount].bot=bar.prevClose;
      st.ob[st.obCount].srcBar=barIndex-1;
      st.ob[st.obCount].side=1;
      st.ob[st.obCount].dead=false;
      st.obCount++;
     }
   if(newObBear)
     {
      if(st.obCount>=TM2_MAX_OB)
        {
         for(int i=1; i<st.obCount; i++)
            st.ob[i-1]=st.ob[i];
         st.obCount=TM2_MAX_OB-1;
        }
      st.ob[st.obCount].top=bar.prevClose;
      st.ob[st.obCount].bot=bar.prevOpen;
      st.ob[st.obCount].srcBar=barIndex-1;
      st.ob[st.obCount].side=-1;
      st.ob[st.obCount].dead=false;
      st.obCount++;
     }
   while(st.obCount>cfg.obMax && st.obCount>0)
     {
      for(int i=1; i<st.obCount; i++)
         st.ob[i-1]=st.ob[i];
      st.obCount--;
     }
   for(int i=0; i<st.obCount; i++)
     {
      if(barIndex-st.ob[i].srcBar>cfg.obLife)
         st.ob[i].dead=true;
      if(st.ob[i].side==1 && bar.low<=st.ob[i].bot)
         st.ob[i].dead=true;
      if(st.ob[i].side==-1 && bar.high>=st.ob[i].top)
         st.ob[i].dead=true;
     }

   double fvgBullPx=EMPTY_VALUE;
   double fvgBearPx=EMPTY_VALUE;
   double obBullPx=EMPTY_VALUE;
   double obBearPx=EMPTY_VALUE;
   TM2ActiveFvgOb(st,fvgBullPx,fvgBearPx,obBullPx,obBearPx);

   //--- 6. momentum, volume, vwap -----------------------------------
   const bool stackBull=hasEma && bar.emaF>bar.emaM && bar.emaM>bar.emaS;
   const bool stackBear=hasEma && bar.emaF<bar.emaM && bar.emaM<bar.emaS;
   const double trendScore=hasEma ? TM2TrendScore(stackBull,stackBear,bar.close,bar.emaF) : EMPTY_VALUE;

   const double rsiScore=TM2RsiScore(bar.rsi,cfg.rsiOs,cfg.rsiOb);
   const double macdScore=TM2MacdScore(bar.macdHist,!TM2IsEmpty(bar.macdPrevHist),
                                       bar.macdPrevHist);
   const double momScore=TM2MomScore(rsiScore,macdScore);

   const double vol=(double)bar.vol;
   const double volRatio=(!TM2IsEmpty(bar.volMA) && bar.volMA>0.0) ? vol/bar.volMA : 0.0;
   const int volBucket=TM2VolBucket(vol,bar.volMA,cfg.volSpikeR,cfg.volRVH,
                                    cfg.volRH,cfg.volRN,cfg.volRL);
   const bool isTim=!TM2IsEmpty(bar.volMA) && bar.volMA>0.0 && vol>=bar.volMA*cfg.volSpikeR;
   const double relVol=(!TM2IsEmpty(bar.volSma20) && bar.volSma20>0.0) ?
                       vol/bar.volSma20 : 0.0;

   if(bar.close>bar.prevClose)
      st.obv+=vol;
   else if(bar.close<bar.prevClose)
      st.obv-=vol;
   const double prevObv=st.obvCount>=TM2_OBV_LAG ? st.obvHist[st.obvCount-TM2_OBV_LAG] : 0.0;
   const double obvSlope=st.obv-prevObv;
   if(st.obvCount>=TM2_OBV_MAX)
     {
      for(int i=1; i<st.obvCount; i++)
         st.obvHist[i-1]=st.obvHist[i];
      st.obvCount=TM2_OBV_MAX-1;
     }
   st.obvHist[st.obvCount]=st.obv;
   st.obvCount++;
   const double volumeScore=TM2VolumeScore(isTim,relVol,cfg.rvMin,bar.close,bar.open,obvSlope);

   const long stamp=TM2ServerDayStamp(bar.time);
   const bool newDay=st.dayStamp!=stamp;
   const double hlc3=(bar.high+bar.low+bar.close)/3.0;
   if(newDay)
     {
      st.vwapVol=vol;
      st.vwapPV=vol*hlc3;
     }
   else
     {
      st.vwapVol+=vol;
      st.vwapPV+=vol*hlc3;
     }
   st.dayStamp=stamp;
   const double vwap=st.vwapVol>0.0 ? st.vwapPV/st.vwapVol : bar.close;
   const bool vwapOk=!TM2IsEmpty(vwap) && vwap>0.0;
   const double vwapScore=TM2VwapScore(vwapOk,bar.close,vwap,bar.atr);

   const double extEma=TM2ExtEma(bar.close,bar.emaF,bar.atr);
   const double extCandle=TM2ExtCandle(bar.high,bar.low,bar.atr);
   const bool isOverext=TM2IsOverextended(extEma,extCandle,cfg.maxExtAtr,cfg.maxCandleAtr);

   //--- 7. liquidity, MTF, BTC, weekend -----------------------------
   st.pdh=bar.pdh;
   st.pdl=bar.pdl;
   st.pwh=bar.pwh;
   st.pwl=bar.pwl;
   st.hasPd=bar.hasPd;
   st.hasPw=bar.hasPw;

   const bool sweepBull=((cfg.liqPdOn && !TM2IsEmpty(bar.pdl) &&
                          bar.low<bar.pdl && bar.close>bar.pdl) ||
                         (cfg.liqPwOn && !TM2IsEmpty(bar.pwl) &&
                          bar.low<bar.pwl && bar.close>bar.pwl) ||
                         (cfg.liqSessOn && st.hasSessLo &&
                          bar.low<st.sessLo && bar.close>st.sessLo) ||
                         (st.eqLo && bar.pivL<st.prevLow && bar.close>st.prevLow));
   const bool sweepBear=((cfg.liqPdOn && !TM2IsEmpty(bar.pdh) &&
                          bar.high>bar.pdh && bar.close<bar.pdh) ||
                         (cfg.liqPwOn && !TM2IsEmpty(bar.pwh) &&
                          bar.high>bar.pwh && bar.close<bar.pwh) ||
                         (cfg.liqSessOn && st.hasSessHi &&
                          bar.high>st.sessHi && bar.close<st.sessHi) ||
                         (st.eqHi && bar.pivH>st.prevHigh && bar.close<st.prevHigh));

   if(sweepBull)
     {
      st.lastSweepBullBar=barIndex;
      st.lastSweepBullPx=bar.low;
      double lvl=EMPTY_VALUE;
      if(!TM2IsEmpty(bar.pdl))
         lvl=MathMax(bar.pdl,st.hasSessLo ? st.sessLo : bar.pdl);
      TM2PushEvent(st,TM2_EVT_SWEEP,1,barIndex,bar.time,lvl);
     }
   if(sweepBear)
     {
      st.lastSweepBearBar=barIndex;
      st.lastSweepBearPx=bar.high;
      double lvl=EMPTY_VALUE;
      if(!TM2IsEmpty(bar.pdh))
         lvl=MathMin(bar.pdh,st.hasSessHi ? st.sessHi : bar.pdh);
      TM2PushEvent(st,TM2_EVT_SWEEP,-1,barIndex,bar.time,lvl);
     }

   const double gMtfBias=bar.mtfHierOk ? (double)(bar.ctxDir+bar.setupDir)/2.0 : 0.0;
   const int ctxDirEff=bar.mtfHierOk ? bar.ctxDir : 0;
   const int setupDirEff=bar.mtfHierOk ? bar.setupDir : 0;
   const bool btcData=bar.btcOk;
   const bool btcDump=bar.btcNeed && btcData &&
                      (bar.btcClose<bar.btcEma-cfg.btcImpulseAtr*bar.btcAtr ||
                       bar.btcRsi<32.0);
   const bool btcPump=bar.btcNeed && btcData &&
                      (bar.btcClose>bar.btcEma+cfg.btcImpulseAtr*bar.btcAtr ||
                       bar.btcRsi>68.0);

   //--- 8. nearest levels -------------------------------------------
   double nearestRes=EMPTY_VALUE;
   double nearestSup=EMPTY_VALUE;
   TM2NearestLevels(bar,st,nearestRes,nearestSup);

   const bool nearSup=atrOk && TM2NearSupport(st,bar.low,bar.atr);
   const bool nearRes=atrOk && TM2NearResistance(st,bar.high,bar.atr);

   //--- 9. group scores, weights, side scores -----------------------
   double g[TM2_GROUP_COUNT];
   g[TM2_G_TREND]=trendScore;
   g[TM2_G_STRUCT]=(st.bosUp || st.chochUp || st.mssUp) ? 1.0 :
                   (st.bosDown || st.chochDown || st.mssDown) ? -1.0 :
                   (double)st.trend*0.5;
   g[TM2_G_LIQ]=sweepBull ? 1.0 : sweepBear ? -1.0 :
                st.retestBull ? 0.7 : st.retestBear ? -0.7 : 0.0;
   g[TM2_G_LOC]=vwapScore;
   g[TM2_G_SR]=nearSup ? 1.0 : nearRes ? -1.0 :
               !TM2IsEmpty(fvgBullPx) ? 0.8 : !TM2IsEmpty(fvgBearPx) ? -0.8 : 0.0;
   g[TM2_G_CANDLE]=cpScore;
   g[TM2_G_VOLUME]=TM2IsEmpty(bar.volMA) || TM2IsEmpty(bar.volSma20) ? EMPTY_VALUE : volumeScore;
   g[TM2_G_MOM]=TM2IsEmpty(bar.rsi) || TM2IsEmpty(bar.macdHist) ? EMPTY_VALUE : momScore;
   g[TM2_G_SESS]=(bar.close>=bar.open ? 1.0 : -1.0)*(cfg.cryptoSessNeutral ? 0.0 : 0.5);
   g[TM2_G_MTF]=gMtfBias;

   double w[TM2_GROUP_COUNT];
   TM2EffectiveWeights(cfg,regimeCode,w);
   TM2AblationAdjust(w,cfg.ablation);

   double wDirTotal=0.0;
   double longWeighted=0.0;
   bool warmupEmpty=false;
   for(int i=0; i<TM2_GROUP_COUNT; i++)
     {
      wDirTotal+=w[i];
      if(w[i]>0.0)
        {
         if(TM2IsEmpty(g[i]))
            warmupEmpty=true;
         else
            longWeighted+=w[i]*TM2LongPart(g[i]);
        }
     }

   int longScore=0;
   int shortScore=0;
   int directionCode=TM2_DIRCODE_NONE;
   int dir=0;
   int score100=0;
   int qualityLevel=0;
   int quality=TM2_Q_NOTRADE;
   bool okQuality=false;
   int scoreBlock=TM2_R_NO_DIRECTION;
   double scoreGap=EMPTY_VALUE;

   if(warmupEmpty)
     {
      longWeighted=EMPTY_VALUE;
      out.longScore=EMPTY_VALUE;
      out.shortScore=EMPTY_VALUE;
      out.score100=EMPTY_VALUE;
      out.scoreGap=EMPTY_VALUE;
      directionCode=TM2_DIRCODE_NONE;
      dir=0;
      qualityLevel=0;
      quality=TM2_Q_NOTRADE;
      okQuality=false;
      scoreBlock=TM2_R_NO_DIRECTION;
     }
   else
     {
      double total=0.0;
      TM2SideScores(g,w,TM2_GROUP_COUNT,longScore,shortScore,total);
      scoreGap=MathAbs(longScore-shortScore);
      directionCode=TM2DirectionCode(longScore,shortScore,cfg.scrNoTrade,cfg.scoreMargin);
      const int candidateDir=TM2CandidateDir(longScore,shortScore,cfg.scrNoTrade);
      dir=directionCode==TM2_DIRCODE_OK ? candidateDir : 0;
      score100=dir==1 ? longScore : dir==-1 ? shortScore : MathMax(longScore,shortScore);
      qualityLevel=directionCode!=TM2_DIRCODE_OK ? 0 :
                   TM2ScoreLevel(score100,cfg.scrNoTrade,cfg.scrWeak,cfg.scrSetup,cfg.scrStrong);
      quality=directionCode!=TM2_DIRCODE_OK ? (int)TM2_Q_NOTRADE : qualityLevel;
      const int minReq=TM2MinLevel(cfg.minQuality);
      okQuality=qualityLevel>=minReq;
      scoreBlock=TM2ScoreBlock(directionCode,dir,okQuality);
      out.longScore=longScore;
      out.shortScore=shortScore;
      out.score100=score100;
      out.scoreGap=scoreGap;
     }

   const int minReqLevel=TM2MinLevel(cfg.minQuality);

   //--- 10. entry modes ---------------------------------------------
   TM2ModeInput modeIn;
   modeIn.regimeCode=regimeCode;
   modeIn.regimeDir=regimeDir;
   modeIn.ctxDir=ctxDirEff;
   modeIn.setupDir=setupDirEff;
   modeIn.dir=dir;
   modeIn.open=bar.open;
   modeIn.close=bar.close;
   modeIn.high=bar.high;
   modeIn.low=bar.low;
   modeIn.emaF=bar.emaF;
   modeIn.atrSafe=bar.atrSafe;
   modeIn.hasFvgBull=!TM2IsEmpty(fvgBullPx);
   modeIn.fvgBullPx=fvgBullPx;
   modeIn.hasFvgBear=!TM2IsEmpty(fvgBearPx);
   modeIn.fvgBearPx=fvgBearPx;
   modeIn.hasObBull=!TM2IsEmpty(obBullPx);
   modeIn.obBullPx=obBullPx;
   modeIn.hasObBear=!TM2IsEmpty(obBearPx);
   modeIn.obBearPx=obBearPx;
   modeIn.sweepAgeBull=st.lastSweepBullBar>=0 ? barIndex-st.lastSweepBullBar : 999999;
   modeIn.sweepAgeBear=st.lastSweepBearBar>=0 ? barIndex-st.lastSweepBearBar : 999999;
   modeIn.hasSweepBullPx=!TM2IsEmpty(st.lastSweepBullPx);
   modeIn.sweepBullPx=st.lastSweepBullPx;
   modeIn.hasSweepBearPx=!TM2IsEmpty(st.lastSweepBearPx);
   modeIn.sweepBearPx=st.lastSweepBearPx;
   modeIn.confirmBull=pinBull || engBull || rejBull;
   modeIn.confirmBear=pinBear || engBear || rejBear;
   modeIn.hasRes=!TM2IsEmpty(nearestRes);
   modeIn.nearestRes=nearestRes;
   modeIn.hasSup=!TM2IsEmpty(nearestSup);
   modeIn.nearestSup=nearestSup;
   modeIn.modeAOn=cfg.modeAOn;
   modeIn.modeBOn=cfg.modeBOn;
   modeIn.modeCOn=cfg.modeCOn;
   modeIn.modeSweepBars=cfg.modeSweepBars;
   modeIn.modePullTol=cfg.modePullTol;
   modeIn.modeRangeTol=cfg.modeRangeTol;

   int modeDir=0;
   int activeMode=TM2_MODE_NONE;
   TM2SelectMode(modeIn,modeDir,activeMode);
   const bool modeReady=modeDir!=0;
   const bool modeGateOk=!cfg.modeFilterOn || (modeReady && modeDir==dir);
   const int modeReason=TM2ModeReason(modeIn,cfg.modeFilterOn,
                                      modeReady ? activeMode : TM2_MODE_NONE);

   const bool modeBInvalidLong=cfg.modeBOn &&
      TM2ModeBInvalid(true,modeIn.sweepAgeBull,cfg.modeSweepBars,
                      modeIn.hasSweepBullPx,bar.close,modeIn.sweepBullPx,bar.atrSafe);
   const bool modeBInvalidShort=cfg.modeBOn &&
      TM2ModeBInvalid(false,modeIn.sweepAgeBear,cfg.modeSweepBars,
                      modeIn.hasSweepBearPx,bar.close,modeIn.sweepBearPx,bar.atrSafe);
   const bool modeCBoxOk=regimeCode==0 && modeIn.hasRes && modeIn.hasSup &&
                         (nearestRes-nearestSup)>bar.atrSafe;

   //--- 11. plan and eligibility ------------------------------------
   TM2Plan plan;
   TM2BuildPlan(cfg,bar,st,dir,plan);

   st.barsSince+=1;
   if(newDay)
     {
      st.dayCount=0;
      st.consecLosses=0;
     }

   TM2GateStatus gate;
   TM2EvaluateGates(cfg,bar,st,dir,gate);

   const bool okDir=dir!=0;
   const bool okCool=st.barsSince>=cfg.coolBars;
   const bool okDay=st.dayCount<cfg.maxDay;
   const bool okCircuit=!cfg.gateCircuit || st.consecLosses<cfg.riskMaxLosses;
   const bool okPosition=st.posStage==TM2_STAGE_IDLE;

   const bool tradeEligible=okDir && okQuality && gate.allPassed && modeGateOk &&
                            okCool && okDay && okCircuit && okPosition;
   const bool riskEligible=plan.valid;
   const bool signal=tradeEligible && riskEligible;

   int noTradeReason=scoreBlock;
   if(noTradeReason==TM2_R_OK)
     {
      if(!gate.regimeOk)
         noTradeReason=TM2_R_BLOCK_REGIME;
      else if(!gate.mtfOk)
         noTradeReason=TM2_R_BLOCK_MTF;
      else if(!gate.btcOk)
         noTradeReason=dir==1 ? TM2_R_BTC_DUMPING : TM2_R_BTC_PUMPING;
      else if(!gate.obstacleOk)
         noTradeReason=TM2_R_BLOCK_OBSTACLE;
      else if(!gate.overextOk)
         noTradeReason=TM2_R_BLOCK_OVEREXT;
      else if(!modeGateOk)
         noTradeReason=modeReason;
      else if(!okCool)
         noTradeReason=TM2_R_BLOCK_COOLDOWN;
      else if(!okDay)
         noTradeReason=TM2_R_BLOCK_DAILY_LIMIT;
      else if(!okCircuit)
         noTradeReason=TM2_R_BLOCK_CIRCUIT;
      else if(!okPosition)
         noTradeReason=TM2_R_BLOCK_POSITION_OPEN;
      else if(!riskEligible)
         noTradeReason=plan.reason;
      else
         noTradeReason=TM2_R_OK;
     }

   const bool candidateNow=scoreBlock==TM2_R_OK && okDir;
   const bool candidateEdge=candidateNow && !st.prevCandidate;
   if(candidateEdge)
      st.candidates++;
   st.prevCandidate=candidateNow;

   const bool eligibleNow=tradeEligible && riskEligible;
   const bool eligibleEdge=eligibleNow && !st.prevEligible;
   if(eligibleEdge)
      st.eligibleN++;
   st.prevEligible=eligibleNow;

   //--- 12. state machine -------------------------------------------
   if(st.needReset)
     {
      st.needReset=false;
      st.posStage=TM2_STAGE_IDLE;
      st.posDir=0;
      st.posOrderType=TM2_ORDER_NONE;
      st.posMode=TM2_MODE_NONE;
      st.posEntry=EMPTY_VALUE;
      st.posLimit=EMPTY_VALUE;
      st.posSl=EMPTY_VALUE;
      st.posTp1=EMPTY_VALUE;
      st.posTp2=EMPTY_VALUE;
      st.posTp3=EMPTY_VALUE;
      st.posRisk=EMPTY_VALUE;
      st.posBars=0;
      st.posBar=-1;
      st.posMaxFavR=0.0;
      st.exitReason=TM2_X_NONE;
     }

   if(st.posStage==TM2_STAGE_PENDING)
     {
      st.posBars+=1;
      const bool isUp=st.posDir==1;
      const bool filled=isUp ? bar.low<=st.posLimit : bar.high>=st.posLimit;
      const bool reachedTp1Early=isUp ? bar.high>=st.posTp1 : bar.low<=st.posTp1;
      if(filled)
        {
         st.posStage=TM2_STAGE_OPEN;
         st.posEntry=st.posLimit;
         st.posBar=barIndex;
         st.posBars=0;
         st.evFilled=true;
         st.filledN+=1;
        }
      else if(cfg.limitCancelOnTp1 && reachedTp1Early)
        {
         st.exitReason=TM2_X_CANCEL_MISSED;
         st.cancelReason=TM2_X_CANCEL_MISSED;
         st.evCancel=true;
         st.needReset=true;
        }
      else if(st.posBars>=cfg.limitCancelBars)
        {
         st.exitReason=TM2_X_CANCEL_TIMEOUT;
         st.cancelReason=TM2_X_CANCEL_TIMEOUT;
         st.evCancel=true;
         st.needReset=true;
        }
     }

   if(st.posStage>=TM2_STAGE_OPEN)
     {
      st.posBars+=1;
      const bool isUp=st.posDir==1;
      const double curFavR=isUp ? (bar.high-st.posEntry)/st.posRisk :
                                 (st.posEntry-bar.low)/st.posRisk;
      st.posMaxFavR=MathMax(st.posMaxFavR,curFavR);

      const double t1=st.posStage<TM2_STAGE_TP1_BE ? st.posTp1 : EMPTY_VALUE;
      const double t2=st.posStage<TM2_STAGE_TP2_TRAIL ? st.posTp2 : EMPTY_VALUE;
      const double t3=st.posTp3;

      const bool fillBar=st.posBar==barIndex;
      const bool hitSl=isUp ? bar.low<=st.posSl : bar.high>=st.posSl;
      const bool hit1=!fillBar && !TM2IsEmpty(t1) && (isUp ? bar.high>=t1 : bar.low<=t1);
      const bool hit2=!fillBar && !TM2IsEmpty(t2) && (isUp ? bar.high>=t2 : bar.low<=t2);
      const bool hit3=!fillBar && !TM2IsEmpty(t3) && (isUp ? bar.high>=t3 : bar.low<=t3);
      const bool hitAnyTp=hit1 || hit2 || hit3;

      if(hitAnyTp && st.posStage==TM2_STAGE_OPEN && !hitSl)
         st.tp1Hits+=1;

      bool closed=false;
      double realizedTradeR=0.0;
      double xExit=EMPTY_VALUE;

      if(hitSl && hitAnyTp)
        {
         closed=true;
         st.evSl=true;
         st.evClose=true;
         xExit=st.posSl;
         if(st.posStage==TM2_STAGE_OPEN)
           {
            st.exitReason=TM2_X_SL;
            realizedTradeR=-1.0;
            st.fullLosses+=1;
            st.consecLosses+=1;
           }
         else if(st.posStage==TM2_STAGE_TP1_BE)
           {
            st.exitReason=TM2_X_BREAKEVEN;
            realizedTradeR=0.40*cfg.rr1-(cfg.riskFeeSlipPct*2.0/100.0);
            st.beSaves+=1;
            st.netWins+=1;
            st.consecLosses=0;
           }
         else
           {
            st.exitReason=TM2_X_TRAIL;
            realizedTradeR=0.40*cfg.rr1+0.40*cfg.rr2-(cfg.riskFeeSlipPct*2.0/100.0);
            st.netWins+=1;
            st.consecLosses=0;
           }
        }
      else if(hitSl)
        {
         closed=true;
         st.evSl=true;
         st.evClose=true;
         xExit=st.posSl;
         if(st.posStage==TM2_STAGE_OPEN)
           {
            st.exitReason=TM2_X_SL;
            realizedTradeR=-1.0;
            st.fullLosses+=1;
            st.consecLosses+=1;
           }
         else if(st.posStage==TM2_STAGE_TP1_BE)
           {
            st.exitReason=TM2_X_BREAKEVEN;
            realizedTradeR=0.40*cfg.rr1-(cfg.riskFeeSlipPct*2.0/100.0);
            st.beSaves+=1;
            st.netWins+=1;
            st.consecLosses=0;
           }
         else
           {
            st.exitReason=TM2_X_TRAIL;
            realizedTradeR=0.40*cfg.rr1+0.40*cfg.rr2-(cfg.riskFeeSlipPct*2.0/100.0);
            st.netWins+=1;
            st.consecLosses=0;
           }
        }
      else if(hit3)
        {
         closed=true;
         st.evTp=3;
         st.evClose=true;
         st.exitReason=TM2_X_TP3;
         realizedTradeR=0.40*cfg.rr1+0.40*cfg.rr2+0.20*cfg.rr3;
         st.netWins+=1;
         st.consecLosses=0;
         xExit=st.posTp3;
        }
      else if(hit2)
        {
         st.evTp=2;
         st.posStage=TM2_STAGE_TP2_TRAIL;
         st.posSl=st.posTp1;
         st.evTrail=true;
        }
      else if(hit1)
        {
         st.evTp=1;
         st.posStage=TM2_STAGE_TP1_BE;
         if(cfg.autoBeOn && atrOk)
           {
            st.posSl=st.posEntry+st.posDir*bar.atr*cfg.beOffsetAtr;
            st.evBe=true;
           }
        }

      if(!closed && st.posStage==TM2_STAGE_TP2_TRAIL && cfg.trailOn && atrOk)
        {
         const double trailLvl=isUp ? bar.prevHigh-cfg.trailDistAtr*bar.atr :
                                      bar.prevLow+cfg.trailDistAtr*bar.atr;
         st.posSl=isUp ? MathMax(st.posSl,trailLvl) : MathMin(st.posSl,trailLvl);
        }

      if(!closed && cfg.timeDecayOn && st.posStage==TM2_STAGE_OPEN &&
         st.posBars>=cfg.stagnantBars && st.posMaxFavR<0.3 &&
         !TM2IsEmpty(bar.adx) && bar.adx<cfg.adxTrending)
        {
         closed=true;
         st.evDecay=true;
         st.evClose=true;
         st.exitReason=TM2_X_TIMEDECAY;
         st.decays+=1;
         realizedTradeR=(bar.close-st.posEntry)*st.posDir/st.posRisk;
         if(realizedTradeR>0.0)
           {
            st.netWins+=1;
            st.consecLosses=0;
           }
         else
            st.consecLosses+=1;
         xExit=bar.close;
        }

      if(!closed && st.posBars>=cfg.maxHoldBars)
        {
         closed=true;
         st.evTimeout=true;
         st.evClose=true;
         st.exitReason=TM2_X_TIMEOUT;
         st.timeouts+=1;
         realizedTradeR=(bar.close-st.posEntry)*st.posDir/st.posRisk;
         if(realizedTradeR>0.0)
           {
            st.netWins+=1;
            st.consecLosses=0;
           }
         else
            st.consecLosses+=1;
         xExit=bar.close;
        }

      if(closed)
        {
         st.trades+=1;
         st.closedN+=1;
         st.realizedRSum+=realizedTradeR;
         st.realizedR=realizedTradeR;
         st.xDir=st.posDir;
         st.xEntry=st.posEntry;
         st.xSl=st.posSl;
         st.xTp1=st.posTp1;
         st.xTp2=st.posTp2;
         st.xTp3=st.posTp3;
         st.xExit=xExit;
         st.xR=realizedTradeR;
         st.xReason=st.exitReason;
         st.xBar=st.posBar;
         st.xStage=st.posStage;
         st.needReset=true;
        }
     }

   if(signal && st.posStage==TM2_STAGE_IDLE)
     {
      st.posDir=plan.dir;
      st.posOrderType=plan.orderType;
      st.posMode=activeMode;
      st.posEntry=plan.entry;
      st.posLimit=plan.limit;
      st.posSl=plan.sl;
      st.posTp1=plan.tp1;
      st.posTp2=plan.tp2;
      st.posTp3=plan.tp3;
      st.posRisk=plan.risk;
      st.posBars=0;
      st.posBar=barIndex;
      st.posMaxFavR=0.0;
      st.dayCount+=1;
      st.barsSince=0;
      st.exitReason=TM2_X_NONE;
      if(plan.orderType==TM2_ORDER_LIMIT)
        {
         st.posStage=TM2_STAGE_PENDING;
         st.evPending=true;
         st.pendingN+=1;
        }
      else
        {
         st.posStage=TM2_STAGE_OPEN;
         st.evEntry=true;
         st.filledN+=1;
        }
     }

   //--- 13. publish ------------------------------------------------
   out.longScore=warmupEmpty ? EMPTY_VALUE : (double)longScore;
   out.shortScore=warmupEmpty ? EMPTY_VALUE : (double)shortScore;
   out.score100=warmupEmpty ? EMPTY_VALUE : (double)score100;
   out.scoreGap=scoreGap;
   out.dir=dir;
   out.directionCode=directionCode;
   out.quality=quality;
   out.qualityLevel=qualityLevel;
   out.minReqLevel=minReqLevel;
   out.okQuality=okQuality;
   out.scoreBlock=scoreBlock;
   out.ablationCode=cfg.ablation;
   out.wDirTotal=wDirTotal;
   out.longWeighted=longWeighted;

   out.gateRegime=gate.regimeOk;
   out.gateMtf=gate.mtfOk;
   out.gateBtc=gate.btcOk;
   out.gateObstacle=gate.obstacleOk;
   out.gateOverext=gate.overextOk;
   out.gateCircuit=gate.circuitOk;
   out.gateAll=gate.allPassed;
   out.gateTopReason=gate.topReason;
   out.noTradeReason=noTradeReason;
   out.okCool=okCool;
   out.okDay=okDay;
   out.okCircuit=okCircuit;

   out.planValid=plan.valid;
   out.planReason=plan.reason;
   out.orderType=plan.orderType;
   out.entry=plan.entry;
   out.limit=plan.limit;
   out.sl=plan.sl;
   out.tp1=plan.tp1;
   out.tp2=plan.tp2;
   out.tp3=plan.tp3;
   out.risk=plan.risk;
   out.evalRR=plan.evalRR;
   out.posSize=plan.posSize;
   out.notional=plan.notional;
   out.effLev=plan.effLev;
   out.marginReq=plan.marginReq;
   out.liqPrice=plan.liqPrice;
   out.netRR=plan.netRR;

   out.signal=signal;
   out.candidate=candidateEdge;
   out.eligible=eligibleEdge;
   out.evEntry=st.evEntry;
   out.evPending=st.evPending;
   out.evFilled=st.evFilled;
   out.evCancel=st.evCancel;
   out.evTp=st.evTp;
   out.evSl=st.evSl;
   out.evBe=st.evBe;
   out.evTrail=st.evTrail;
   out.evTimeout=st.evTimeout;
   out.evDecay=st.evDecay;
   out.evClose=st.evClose;
   out.cancelReason=st.cancelReason;
   out.closeReason=st.evClose ? st.exitReason : TM2_X_NONE;

   out.posDir=st.posDir;
   out.posStage=st.posStage;
   out.posOrderType=st.posOrderType;
   out.posMode=st.posMode;
   out.posEntry=st.posEntry;
   out.posLimit=st.posLimit;
   out.posSl=st.posSl;
   out.posTp1=st.posTp1;
   out.posTp2=st.posTp2;
   out.posTp3=st.posTp3;
   out.posRisk=st.posRisk;
   out.posBars=st.posBars;
   out.posBar=st.posBar;
   out.posMaxFavR=st.posMaxFavR;

   out.dayCount=st.dayCount;
   out.barsSince=st.barsSince;
   out.consecLosses=st.consecLosses;
   out.trades=st.trades;
   out.tp1Hits=st.tp1Hits;
   out.netWins=st.netWins;
   out.beSaves=st.beSaves;
   out.fullLosses=st.fullLosses;
   out.timeouts=st.timeouts;
   out.decays=st.decays;
   out.realizedRSum=st.realizedRSum;
   out.candidates=st.candidates;
   out.eligibleN=st.eligibleN;
   out.pendingN=st.pendingN;
   out.filledN=st.filledN;
   out.closedN=st.closedN;

   out.xDir=st.xDir;
   out.xEntry=st.xEntry;
   out.xSl=st.xSl;
   out.xExit=st.xExit;
   out.xR=st.xR;
   out.xReason=st.xReason;
   out.xBar=st.xBar;
   out.xStage=st.xStage;

   out.regimeCode=regimeCode;
   out.regimeDir=regimeDir;
   out.regimeAdx=bar.adx;
   out.regimeBbwPct=bar.bbwPct;
   out.isSqueeze=bar.isSqueeze;
   out.bbWidth=TM2IsEmpty(bar.bbMid) ? EMPTY_VALUE : bar.bbWidth;
   out.bbWidthMA=bar.bbWidthMA;
   out.bbExpand=bar.bbExpand;

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
   out.contUp=st.contBull;
   out.contDown=st.contBear;
   out.pullUp=st.pullBull;
   out.pullDown=st.pullBear;
   out.hh=st.isHH;
   out.ll=st.isLL;
   out.eqHi=st.eqHi;
   out.eqLo=st.eqLo;
   out.swingHi=st.hasSwingHi ? st.swingHi : EMPTY_VALUE;
   out.swingLo=st.hasSwingLo ? st.swingLo : EMPTY_VALUE;
   out.prevHigh=st.hasPrevHigh ? st.prevHigh : EMPTY_VALUE;
   out.prevLow=st.hasPrevLow ? st.prevLow : EMPTY_VALUE;
   out.brkLevel=st.hasBrk ? st.brkLevel : EMPTY_VALUE;
   out.brkDir=st.brkDir;
   out.brkBar=st.brkBar;

   if(st.evtCount>0)
     {
      out.evtKind=st.evt[st.evtCount-1].kind;
      out.evtDir=st.evt[st.evtCount-1].dir;
      out.evtSrcBar=st.evt[st.evtCount-1].srcBar;
      out.evtSrcTime=st.evt[st.evtCount-1].srcTime;
      out.evtLevel=st.evt[st.evtCount-1].level;
     }
   else
     {
      out.evtKind=TM2_EVT_NONE;
      out.evtDir=0;
      out.evtSrcBar=-1;
      out.evtSrcTime=0;
      out.evtLevel=EMPTY_VALUE;
     }
   out.evtCount=st.evtCount;
   out.lastSweepBullBar=st.lastSweepBullBar;
   out.lastSweepBullPx=st.lastSweepBullPx;
   out.lastSweepBearBar=st.lastSweepBearBar;
   out.lastSweepBearPx=st.lastSweepBearPx;

   out.cpBull=cpBull;
   out.cpBear=cpBear;
   out.candleScore=cpScore;
   out.pinBull=pinBull;
   out.pinBear=pinBear;
   out.engBull=engBull;
   out.engBear=engBear;
   out.dispBull=dispBull;
   out.dispBear=dispBear;
   out.rejBull=rejBull;
   out.rejBear=rejBear;
   out.isOverext=isOverext;
   out.extEma=extEma;
   out.extCandle=extCandle;

   out.atr=bar.atr;
   out.atrPct=bar.atrPct;
   out.rsi=bar.rsi;
   out.macdHist=bar.macdHist;
   out.adx=bar.adx;
   out.diPlus=bar.diPlus;
   out.diMinus=bar.diMinus;
   out.emaSlope20=bar.slope20;
   out.emaBull=emaUp;
   out.emaBear=emaDn;
   out.atrSafe=bar.atrSafe;

   out.vol=vol;
   out.volMA=bar.volMA;
   out.volRatio=volRatio;
   out.volBucket=volBucket;
   out.isTim=isTim;
   out.relVol=relVol;
   out.obv=st.obv;
   out.obvSlope=obvSlope;

   out.vwap=vwapOk ? vwap : EMPTY_VALUE;
   out.vwapScore=vwapScore;
   out.pdh=bar.pdh;
   out.pdl=bar.pdl;
   out.pwh=bar.pwh;
   out.pwl=bar.pwl;
   out.dayRange=TM2DayRange(bar.close,bar.hasPd,bar.pdh,bar.pdl);
   out.sessName=bar.sessName;
   out.sessHi=st.hasSessHi ? st.sessHi : EMPTY_VALUE;
   out.sessLo=st.hasSessLo ? st.sessLo : EMPTY_VALUE;

   out.nearSup=nearSup;
   out.nearRes=nearRes;
   out.nearFvgBull=!TM2IsEmpty(fvgBullPx);
   out.nearFvgBear=!TM2IsEmpty(fvgBearPx);
   out.nearObBull=!TM2IsEmpty(obBullPx);
   out.nearObBear=!TM2IsEmpty(obBearPx);
   out.srCount=st.srCount;
   out.fvgCount=st.fvgCount;
   out.obCount=st.obCount;
   out.nearestRes=nearestRes;
   out.nearestSup=nearestSup;
   out.fvgBullPx=fvgBullPx;
   out.fvgBearPx=fvgBearPx;
   out.obBullPx=obBullPx;
   out.obBearPx=obBearPx;

   out.mtfCtxDir=ctxDirEff;
   out.mtfSetupDir=setupDirEff;
   out.mtfCtxEma=bar.ctxEma;
   out.mtfSetupEma=bar.setupEma;
   out.mtfBias=gMtfBias;
   out.mtfHierOk=bar.mtfHierOk;
   out.btcDump=btcDump;
   out.btcPump=btcPump;
   out.weekendBlock=bar.weekendBlocked;

   out.modeDir=modeDir;
   out.activeMode=activeMode;
   out.modeReady=modeReady;
   out.modeGateOk=modeGateOk;
   out.modeReason=modeReason;
   out.modeBInvalidLong=modeBInvalidLong;
   out.modeBInvalidShort=modeBInvalidShort;
   out.modeCBoxOk=modeCBoxOk;

   out.gTrend=g[TM2_G_TREND];
   out.gStruct=g[TM2_G_STRUCT];
   out.gLiq=g[TM2_G_LIQ];
   out.gLoc=g[TM2_G_LOC];
   out.gSr=g[TM2_G_SR];
   out.gCandle=g[TM2_G_CANDLE];
   out.gVolume=g[TM2_G_VOLUME];
   out.gMom=g[TM2_G_MOM];
   out.gSess=g[TM2_G_SESS];
   out.gMtf=g[TM2_G_MTF];
  }
#endif
