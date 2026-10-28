//+------------------------------------------------------------------+
//|                                 LongKacoVSAContractTests.mq5     |
//|      MT5 EA & AI Lab - synthetic checks for the LK contract      |
//|                                                                  |
//| Runs once. No file I/O, no market data, no account access, no    |
//| trading functions. Vectors: docs/indicators/longkaco-vsa.md  |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Synthetic contract tests for LongKaco VSA. No trading."

#include "../Include/PinePort/LongKacoVSAContract.mqh"

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
   return(MathAbs(a-b)<=1e-9);
  }

LkConfig BaseConfig()
  {
   LkConfig cfg;
   cfg.signal_mode=LK_SIGNAL_VSA;
   cfg.wyckoff_event=LK_WYCKOFF_LPS;
   cfg.entry_mode=LK_ENTRY_MARKET;
   cfg.tp_mode=LK_TP_R;
   cfg.len=20;
   cfg.r_p=2.2;
   cfg.r_vh=1.8;
   cfg.r_h=1.2;
   cfg.r_n=0.8;
   cfg.r_l=0.4;
   cfg.pur_win=20;
   cfg.vol_min=0.0;
   cfg.evt_on=true;
   cfg.quiet_on=true;
   cfg.run=5;
   cfg.lv_tol=0.5;
   cfg.lv_fresh=60;
   cfg.test_r=1.2;
   cfg.retest_t=1.0;
   cfg.atr_len=14;
   cfg.piv_len=20;
   cfg.sos_spread=1.0;
   cfg.sos_vol=1.2;
   cfg.lps_tol=0.5;
   cfg.sweep_req=true;
   cfg.sweep_win=10;
   cfg.clx_on=true;
   cfg.clx_r=1.5;
   cfg.sl_buf=0.5;
   cfg.rr_fb=2.0;
   cfg.fee_pct=0.05;
   cfg.fee_max_r=0.15;
   LkNormalizeConfig(cfg);
   return(cfg);
  }

//--- A: volume bucket thresholds
void CheckBucket(const string id,const double vol,const double vol_ma,
                 const ENUM_LK_BUCKET expected)
  {
   const LkConfig cfg=BaseConfig();
   const ENUM_LK_BUCKET got=LkBucket(vol,vol_ma,cfg.r_p,cfg.r_vh,cfg.r_h,cfg.r_n,cfg.r_l);
   Record(id,got==expected,
          StringFormat("vol=%.3f ma=%.3f got=%s expected=%s",
                       vol,vol_ma,LkBucketName(got),LkBucketName(expected)));
  }

void RunA()
  {
   CheckBucket("A1",220.0,100.0,LK_BUCKET_TIM);
   CheckBucket("A2",180.0,100.0,LK_BUCKET_VERY_HIGH);
   CheckBucket("A3",120.0,100.0,LK_BUCKET_HIGH);
   CheckBucket("A4", 80.0,100.0,LK_BUCKET_NORMAL);
   CheckBucket("A5", 40.0,100.0,LK_BUCKET_LOW);
   CheckBucket("A6", 39.9,100.0,LK_BUCKET_VERY_LOW);
   CheckBucket("A7",220.0,  0.0,LK_BUCKET_VERY_LOW);
  }

//--- B: purple / quiet flags at boundaries
void RunB()
  {
   const LkConfig cfg=BaseConfig();

   Record("B1",LkIsPurple(220.0,100.0,cfg.r_p),
          "purple must be true at vol == ma*r_p");
   Record("B2",!LkIsPurple(219.9,100.0,cfg.r_p),
          "purple must be false just below ma*r_p");
   Record("B3",LkIsQuietSt(110.0,100.0,cfg.r_p,cfg.test_r),
          "quietST must be true below both thresholds");
   Record("B4",!LkIsQuietSt(120.0,100.0,cfg.r_p,cfg.test_r),
          "quietST must be false at vol == ma*test_r");
   Record("B5",!LkIsQuietLow(80.0,100.0,cfg.r_n) &&
          LkIsQuietLow(79.9,100.0,cfg.r_n),
          "quietLow boundary must be exclusive");
  }

//--- C: sweep age / recency
void RunC()
  {
   Record("C1",LkSweepAge(-1,10)==-1,
          StringFormat("age=%d",LkSweepAge(-1,10)));

   Record("C2",LkSweepRecent(5,10,10),
          "sweep 5 bars back with win 10 must be recent");

   Record("C3",!LkSweepRecent(5,20,10),
          "sweep 15 bars back with win 10 must be stale");

   Record("C4",LkSweepRecent(5,1000,0),
          "win 0 must mean unlimited");

   Record("C5",LkSweepAge(10,10)==0 && LkSweepRecent(10,10,10),
          "same-bar sweep must be age 0 and recent");
  }

void MakeFive(const double a0,const double a1,const double a2,
              const double a3,const double a4,double &out[])
  {
   ArrayResize(out,5);
   out[0]=a0;
   out[1]=a1;
   out[2]=a2;
   out[3]=a3;
   out[4]=a4;
  }

//--- D: pivot detection, ties and boundaries
void RunD()
  {
   double low_case[];
   MakeFive(5.0,4.0,3.0,4.0,5.0,low_case);
   Record("D1",LkIsPivotLow(low_case,2,2,2),
          "3.0 inside 4.0/5.0 must be a pivot low");

   double high_case[];
   MakeFive(1.0,2.0,3.0,2.0,1.0,high_case);
   Record("D2",LkIsPivotHigh(high_case,2,2,2),
          "3.0 inside 2.0/1.0 must be a pivot high");

   double tie_case[];
   MakeFive(5.0,3.0,3.0,3.0,5.0,tie_case);
   Record("D3",LkIsPivotLow(tie_case,2,2,2) && !LkIsPivotHigh(tie_case,2,2,2),
          "equal neighbours are allowed for low, not for high");

   Record("D4",!LkIsPivotLow(low_case,1,2,2),
          "left edge must fail with insufficient left bars");

   Record("D5",!LkIsPivotLow(low_case,3,1,2),
          "right edge must fail with insufficient right bars");

   Record("D6",!LkIsPivotLow(high_case,2,2,2),
          "middle of a high shape must not be a pivot low");
  }

//--- E: setup levels
void CheckLong(const string id,const LkConfig &cfg,
               const double close_val,const double low_val,
               const double sv_px,const double atr,
               const bool pv,const double piv_high,const bool pf,const double mm_up,
               const bool exp_ok,const double exp_entry,const double exp_sl,const double exp_tp)
  {
   double entry=0.0;
   double sl=0.0;
   double tp=0.0;
   const bool ok=LkSetupLong(cfg,close_val,low_val,sv_px,atr,pv,piv_high,pf,mm_up,
                             entry,sl,tp);
   const bool match=(ok==exp_ok &&
                     (!exp_ok || (Near(entry,exp_entry) && Near(sl,exp_sl) && Near(tp,exp_tp))));
   Record(id,match,
          StringFormat("ok=%d/%d e=%.4f/%.4f sl=%.4f/%.4f tp=%.4f/%.4f",
                       (int)ok,(int)exp_ok,entry,exp_entry,sl,exp_sl,tp,exp_tp));
  }

void CheckShort(const string id,const LkConfig &cfg,
                const double close_val,const double high_val,
                const double bc_px,const double atr,
                const bool pv,const double piv_low,const bool pf,const double mm_dn,
                const bool exp_ok,const double exp_entry,const double exp_sl,const double exp_tp)
  {
   double entry=0.0;
   double sl=0.0;
   double tp=0.0;
   const bool ok=LkSetupShort(cfg,close_val,high_val,bc_px,atr,pv,piv_low,pf,mm_dn,
                              entry,sl,tp);
   const bool match=(ok==exp_ok &&
                     (!exp_ok || (Near(entry,exp_entry) && Near(sl,exp_sl) && Near(tp,exp_tp))));
   Record(id,match,
          StringFormat("ok=%d/%d e=%.4f/%.4f sl=%.4f/%.4f tp=%.4f/%.4f",
                       (int)ok,(int)exp_ok,entry,exp_entry,sl,exp_sl,tp,exp_tp));
  }

void RunE()
  {
   LkConfig cfg=BaseConfig();

   CheckLong("E1",cfg,100.0,99.0,99.0,1.0,false,0.0,false,0.0,
             true,100.0,98.5,103.0);

   LkConfig piv=BaseConfig();
   piv.tp_mode=LK_TP_PIVOT;
   CheckLong("E2",piv,100.0,99.0,99.0,1.0,true,105.0,false,0.0,
             true,100.0,98.5,105.0);

   LkConfig mm=BaseConfig();
   mm.tp_mode=LK_TP_MM;
   CheckLong("E3",mm,100.0,99.0,99.0,1.0,false,0.0,true,5.0,
             true,100.0,98.5,105.0);

   CheckLong("E4",mm,100.0,99.0,99.0,1.0,false,0.0,false,0.0,
             true,100.0,98.5,103.0);

   LkConfig limit=BaseConfig();
   limit.entry_mode=LK_ENTRY_LIMIT;
   CheckLong("E5",limit,100.0,99.0,99.0,1.0,false,0.0,false,0.0,
             true,99.0,98.5,100.0);

   LkConfig wyck=BaseConfig();
   wyck.signal_mode=LK_SIGNAL_WYCKOFF;
   CheckLong("E6",wyck,100.0,98.0,99.0,1.0,false,0.0,false,0.0,
             true,100.0,97.5,105.0);

   CheckLong("E7",cfg,100.0,99.0,100.5,1.0,false,0.0,false,0.0,
             false,0.0,0.0,0.0);

   CheckShort("E8",cfg,100.0,101.0,101.0,1.0,false,0.0,false,0.0,
              true,100.0,101.5,97.0);
  }

//--- F: fill and exit tracking
void CheckTrack(const string id,const int dir,const bool filled_in,
                const double entry,const double sl,const double tp,
                const double bar_low,const double bar_high,
                const bool exp_filled,const int exp_result)
  {
   bool filled=filled_in;
   const int result=LkTrackSetup(dir,filled,entry,sl,tp,bar_low,bar_high);
   Record(id,result==exp_result && filled==exp_filled,
          StringFormat("filled=%d/%d result=%d/%d",
                       (int)filled,(int)exp_filled,result,exp_result));
  }

void RunF()
  {
   CheckTrack("F1",1,false,100.0,99.0,105.0,99.5,101.0,true,LK_RESULT_OPEN);
   CheckTrack("F2",1,true, 100.0,99.0,105.0,98.9,101.0,true,LK_RESULT_SL);
   CheckTrack("F3",1,true, 100.0,99.0,105.0,98.0,106.0,true,LK_RESULT_SL);
   CheckTrack("F4",1,true, 100.0,99.0,105.0,100.0,105.1,true,LK_RESULT_TP);
   CheckTrack("F5",-1,true,100.0,101.5,97.0,100.0,102.0,true,LK_RESULT_SL);
   CheckTrack("F6",-1,true,100.0,101.5,97.0,96.9,100.5,true,LK_RESULT_TP);
  }

//--- G: CLX-E trigger
void RunG()
  {
   Record("G1",LkClxTrigger(1,103.0,100.0,100.0,2.0,1.5),
          "long CLX must fire at entry + 1.5R");
   Record("G2",!LkClxTrigger(1,102.9,100.0,100.0,2.0,1.5),
          "long CLX must not fire below entry + 1.5R");
   Record("G3",LkClxTrigger(-1,100.0,97.0,100.0,2.0,1.5),
          "short CLX must fire at entry - 1.5R");
   Record("G4",!LkClxTrigger(1,200.0,100.0,100.0,0.0,1.5),
          "CLX must not fire when risk is zero");
  }

//--- H: RMA, ratio, clamp, hash
void RunH()
  {
   Record("H1",Near(LkRmaUpdate(0.0,false,1.0,20),1.0),
          "RMA without previous value must return the source");

   Record("H2",Near(LkRmaUpdate(1.0,true,2.0,2),1.5),
          "RMA(2) of prev 1.0 and src 2.0 must be 1.5");

   Record("H3",Near(LkVolumeRatio(50.0,100.0),0.5),
          "volume ratio must be vol/ma");

   Record("H4",Near(LkVolumeRatio(50.0,0.0),0.0) &&
          Near(LkVolumeRatio(50.0,-1.0),0.0),
          "volume ratio must be 0 when ma <= 0");

   LkConfig bad=BaseConfig();
   bad.len=3;
   bad.pur_win=200;
   bad.atr_len=1;
   bad.piv_len=500;
   bad.r_p=1.0;
   bad.clx_r=0.1;
   bad.rr_fb=0.1;
   bad.sweep_win=-5;
   LkNormalizeConfig(bad);
   Record("H5",bad.len==5 && bad.pur_win==100 && bad.atr_len==2 &&
          bad.piv_len==100 && Near(bad.r_p,1.5) && Near(bad.clx_r,0.5) &&
          Near(bad.rr_fb,0.5) && bad.sweep_win==0,
          StringFormat("len=%d pw=%d al=%d pl=%d rp=%.2f cr=%.2f rr=%.2f sw=%d",
                       bad.len,bad.pur_win,bad.atr_len,bad.piv_len,
                       bad.r_p,bad.clx_r,bad.rr_fb,bad.sweep_win));

   const LkConfig cfg=BaseConfig();
   const string h0=LkConfigHash(cfg,0);
   const string h1=LkConfigHash(cfg,1);
   Record("H6",StringLen(h0)==8 && h0!=h1 &&
          h0==LkConfigHash(cfg,0),
          StringFormat("h0=%s h1=%s",h0,h1));
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

   PrintFormat("TEST|RESULT|%s|pass=%d fail=%d|contract=%s",
               (g_fail==0 ? "ALL_PASS" : "FAIL"),
               g_pass,g_fail,LK_CONTRACT_VERSION);
  }
//+------------------------------------------------------------------+
