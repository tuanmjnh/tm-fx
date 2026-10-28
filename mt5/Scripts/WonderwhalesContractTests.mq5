//+------------------------------------------------------------------+
//|                                  WonderwhalesContractTests.mq5    |
//|      MT5 EA & AI Lab - synthetic checks for the WW contract      |
//|                                                                  |
//| Runs once. No file I/O, no market data, no account access, no    |
//| trading functions. Vectors: docs/BUFFER_CONTRACT_Wonderwhales.md |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Synthetic contract tests for Wonderwhales. No trading."
#property script_show_inputs

#include "../Include/PinePort/WonderwhalesContract.mqh"

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

WwConfig TestConfig()
  {
   WwConfig cfg;
   cfg.mode=WW_MODE_SAR;
   cfg.psar_start=0.02;
   cfg.psar_inc=0.02;
   cfg.psar_max=0.20;
   cfg.fast_ema=20;
   cfg.slow_ema=50;
   cfg.ema200=200;
   cfg.atr_len=14;
   cfg.min_atr_pct=0.5;
   cfg.vol_ma_len=20;
   cfg.rsi_len=14;
   cfg.bb_len=20;
   cfg.bb_mult=2.0;
   WwNormalizeConfig(cfg);
   return(cfg);
  }

WwBarInput BlankInput()
  {
   WwBarInput in;
   in.psar_valid=false;
   in.psar=0.0;
   in.close=100.0;
   in.ema_now_valid=false;
   in.ema_prev_valid=false;
   in.fast_prev=0.0;
   in.slow_prev=0.0;
   in.fast_now=0.0;
   in.slow_now=0.0;
   in.atr_pct=0.0;
   return(in);
  }

void CheckA(const string id,const WwConfig &cfg,
            const bool psar_valid,const double psar,const double close_val,
            const int dir_prev,const int exp_dir,const bool exp_buy,const bool exp_sell)
  {
   WwBarInput in=BlankInput();
   in.psar_valid=psar_valid;
   in.psar=psar;
   in.close=close_val;

   WwBarOutput out;
   WwEvaluateBar(cfg,in,dir_prev,true,out);

   const bool ok=(out.sar_dir==exp_dir && out.buy_flip==exp_buy && out.sell_flip==exp_sell);
   Record(id,ok,StringFormat("dir=%d/%d buy=%d/%d sell=%d/%d",
                              out.sar_dir,exp_dir,
                              (int)out.buy_flip,(int)exp_buy,
                              (int)out.sell_flip,(int)exp_sell));
  }

void RunA(const WwConfig &cfg)
  {
   CheckA("A1",cfg,true, 99.0,100.0, 0, 1,false,false);
   CheckA("A2",cfg,true, 99.0,100.0,-1, 1,true, false);
   CheckA("A3",cfg,true,101.0,100.0, 1,-1,false,true);
   CheckA("A4",cfg,true,100.0,100.0, 1,-1,false,true);
   CheckA("A5",cfg,true,100.0,100.0,-1,-1,false,false);
   CheckA("A6",cfg,true,101.0,100.0,-1,-1,false,false);
   CheckA("A7",cfg,true, 99.0,100.0, 1, 1,false,false);
   CheckA("A8",cfg,false,0.0,100.0, 1, 1,false,false);
   CheckA("A9",cfg,false,0.0,100.0, 0, 0,false,false);
  }

void CheckB(const string id,const ENUM_WW_MODE mode,
            const bool raw_buy,const bool raw_sell,
            const bool ema_bull,const bool ema_bear,const bool atr_ok,
            const bool exp_valid_buy,const bool exp_valid_sell,
            const bool exp_blocked_buy,const bool exp_blocked_sell)
  {
   bool valid_buy=false;
   bool valid_sell=false;
   bool blocked_buy=false;
   bool blocked_sell=false;

   WwApplyMode(mode,raw_buy,raw_sell,ema_bull,ema_bear,atr_ok,
               valid_buy,valid_sell,blocked_buy,blocked_sell);

   const bool ok=(valid_buy==exp_valid_buy && valid_sell==exp_valid_sell &&
                  blocked_buy==exp_blocked_buy && blocked_sell==exp_blocked_sell);
   Record(id,ok,StringFormat("vb=%d/%d vs=%d/%d bb=%d/%d bs=%d/%d",
                              (int)valid_buy,(int)exp_valid_buy,
                              (int)valid_sell,(int)exp_valid_sell,
                              (int)blocked_buy,(int)exp_blocked_buy,
                              (int)blocked_sell,(int)exp_blocked_sell));
  }

void RunB()
  {
   CheckB("B1", WW_MODE_SAR,          true, false, false,false,false,  true, false, false,false);
   CheckB("B2", WW_MODE_EMA,          true, false, false,false,false,  true, false, false,false);
   CheckB("B3", WW_MODE_SAR_EMA,      true, false, false,false,false,  false,false, true, false);
   CheckB("B4", WW_MODE_SAR_EMA,      true, false, true, false,false,  true, false, false,false);
   CheckB("B5", WW_MODE_SAR_EMA_ATR,  true, false, true, false,false,  false,false, true, false);
   CheckB("B6", WW_MODE_SAR_EMA_ATR,  true, false, true, false,true,   true, false, false,false);
   CheckB("B7", WW_MODE_SAR_EMA,      false,true,  false,false,false,  false,false, false,true);
   CheckB("B8", WW_MODE_SAR_EMA,      false,true,  false,true, false,  false,true,  false,false);
   CheckB("B9", WW_MODE_SAR,          false,false, false,false,false,  false,false, false,false);
   CheckB("B10",WW_MODE_SAR_EMA_ATR,  false,true,  false,true, false,  false,false, false,true);
  }

void RunC()
  {
   WwConfig cfg=TestConfig();
   cfg.mode=WW_MODE_SAR;

   WwBarInput in=BlankInput();
   in.psar_valid=true;
   in.psar=99.0;
   in.close=100.0;

   WwBarOutput out;
   WwEvaluateBar(cfg,in,-1,true,out);
   Record("C1",out.signal_buy && !out.signal_sell,
          StringFormat("buy=%d sell=%d",(int)out.signal_buy,(int)out.signal_sell));

   WwEvaluateBar(cfg,in,-1,false,out);
   Record("C2",!out.signal_buy && !out.signal_sell,
          StringFormat("buy=%d sell=%d",(int)out.signal_buy,(int)out.signal_sell));

   WwConfig cfg2=TestConfig();
   cfg2.mode=WW_MODE_SAR_EMA;
   WwBarInput blocked=BlankInput();
   blocked.psar_valid=true;
   blocked.psar=99.0;
   blocked.close=100.0;
   blocked.ema_now_valid=false;
   blocked.ema_prev_valid=false;

   WwEvaluateBar(cfg2,blocked,-1,false,out);
   Record("C3",!out.signal_blocked_buy,
          StringFormat("blk=%d",(int)out.signal_blocked_buy));

   WwEvaluateBar(cfg2,blocked,-1,true,out);
   Record("C4",out.signal_blocked_buy && !out.signal_buy,
          StringFormat("blk=%d buy=%d",(int)out.signal_blocked_buy,(int)out.signal_buy));
  }

void CheckD(const string id,const bool valid,
            const double f_prev,const double s_prev,
            const double f_now,const double s_now,
            const bool exp_up,const bool exp_down)
  {
   const bool up=WwEmaCrossUp(valid,f_prev,s_prev,f_now,s_now);
   const bool down=WwEmaCrossDown(valid,f_prev,s_prev,f_now,s_now);
   Record(id,(up==exp_up && down==exp_down),
          StringFormat("up=%d/%d down=%d/%d",(int)up,(int)exp_up,(int)down,(int)exp_down));
  }

void RunD()
  {
   CheckD("D1",true, 1.0,1.0,1.1,1.0, true, false);
   CheckD("D2",true, 1.0,1.0,1.0,1.0, false,false);
   CheckD("D3",true, 1.1,1.0,1.0,1.0, false,false);
   CheckD("D4",true, 1.1,1.0,0.9,1.0, false,true);
   CheckD("D5",true, 1.0,1.0,0.9,1.0, false,true);
   CheckD("D6",true, 0.9,1.0,1.01,1.0,true, false);
   CheckD("D7",false,1.0,1.0,1.0,1.0, false,false);
  }

void RunE(const WwConfig &cfg)
  {
   Record("E1",
          WwAtrPct(false,1.0,100.0)==0.0 && WwAtrPct(true,1.0,100.0)==1.0,
          StringFormat("na=%s ok=%s",
                       DoubleToString(WwAtrPct(false,1.0,100.0),8),
                       DoubleToString(WwAtrPct(true,1.0,100.0),8)));

   Record("E2",
          WwVolRatio(false,100.0,50.0)==0.0 && WwVolRatio(true,100.0,0.0)==0.0 &&
          WwVolRatio(true,100.0,50.0)==2.0,
          StringFormat("na=%s zero=%s two=%s",
                       DoubleToString(WwVolRatio(false,100.0,50.0),8),
                       DoubleToString(WwVolRatio(true,100.0,0.0),8),
                       DoubleToString(WwVolRatio(true,100.0,50.0),8)));

   Record("E3",!WwEmaCrossUp(false,1.0,1.0,1.1,1.0),
          "cross_up should be false when EMA is missing");

   WwBarInput in=BlankInput();
   in.psar_valid=true;
   in.psar=99.0;
   in.close=100.0;
   WwBarOutput out;
   WwEvaluateBar(cfg,in,-1,false,out);
   Record("E4",!out.signal_buy && !out.signal_sell,
          "forming bar must suppress signals");

   Record("E5",WwDirFromPsar(false,0.0,100.0,1)==1 &&
          WwDirFromPsar(false,0.0,100.0,0)==0,
          "invalid PSAR must preserve previous direction");

   Record("E6",WwDirFromPsar(true,100.0,100.0,1)==-1 &&
          WwIsSellFlip(-1,1),
          "psar == close must be bearish");
  }

void OnStart()
  {
   WwConfig cfg=TestConfig();
   cfg.mode=WW_MODE_SAR;

   RunA(cfg);
   RunB();
   RunC();
   RunD();
   RunE(cfg);

   PrintFormat("TEST|RESULT|%s|pass=%d fail=%d|contract=%s",
               (g_fail==0 ? "ALL_PASS" : "FAIL"),
               g_pass,g_fail,WW_CONTRACT_VERSION);
  }
//+------------------------------------------------------------------+
