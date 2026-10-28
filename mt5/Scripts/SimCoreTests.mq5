//+------------------------------------------------------------------+
//|                                                 SimCoreTests.mq5 |
//|      MT5 EA Lab - synthetic checks for the simulation core        |
//|                                                                  |
//| Runs once. No market data, no file I/O, no account access and no  |
//| trading functions. Vectors: docs/reference/simulation.md.                     |
//+------------------------------------------------------------------+
#property copyright "MT5 EA & AI Lab"
#property version   "1.00"
#property description "Synthetic tests for SimPortfolio/SimValidate/SimLogger/SimCostModel/SimRiskGuard."
#property script_show_inputs

#include "../Include/Sim/SimPortfolio.mqh"
#include "../Include/Sim/SimLogger.mqh"
#include "../Include/Sim/SimCostModel.mqh"
#include "../Include/Sim/SimRiskGuard.mqh"
#include "../Include/Sim/SimTrailing.mqh"
#include "../Include/Sim/SimGrid.mqh"
#include "../Include/Sim/SimDca.mqh"

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

bool Near(const double a,const double b,const double tolerance=1e-9)
  {
   return(MathAbs(a-b)<=tolerance);
  }

int CountFields(const string line)
  {
   int count=1;
   const int length=StringLen(line);
   for(int i=0; i<length; i++)
      if(StringGetCharacter(line,i)==44) // ','
         count++;
   return(count);
  }

void RunPortfolio(void)
  {
   string error="";
   CSimPortfolio portfolio;

   Record("P1",!portfolio.Init(0.0,error) && error=="initial_balance_must_be_finite_positive",
          "init(0) error="+error);
   Record("P2",portfolio.Init(10000.0,error) && portfolio.IsInitialized() &&
          Near(portfolio.Balance(),10000.0),
          "init(10000) error="+error);

   Record("P3",!portfolio.Open(SIM_SIDE_NONE,1.2,1.0,0.0,error) &&
          error=="side_must_not_be_none","open none error="+error);
   Record("P4",!portfolio.Open(SIM_SIDE_BUY,0.0,1.0,0.0,error) &&
          error=="price_must_be_finite_positive","open price=0 error="+error);
   Record("P5",!portfolio.Open(SIM_SIDE_BUY,1.2,0.0,0.0,error) &&
          error=="volume_must_be_finite_positive","open volume=0 error="+error);
   Record("P6",!portfolio.Open(SIM_SIDE_BUY,1.2,1.0,-1.0,error) &&
          error=="commission_must_be_finite_non_negative","open commission=-1 error="+error);

   CSimPortfolio empty;
   Record("P7",!empty.Open(SIM_SIDE_BUY,1.2,1.0,0.0,error) &&
          error=="portfolio_not_initialized","open uninitialized error="+error);

   error="";
   CSimPortfolio single;
   single.Init(10000.0,error);
   const bool opened=single.Open(SIM_SIDE_BUY,1.2,2.0,0.0,error);
   Record("P8",opened && single.OpenPositions()==1 &&
          Near(single.AverageEntry(),1.2) && Near(single.Exposure(),2.0) &&
          Near(single.NetVolume(),2.0) && Near(single.UnrealizedPnl(1.25),0.1),
          StringFormat("open=%d avg=%.8f exp=%.4f net=%.4f upnl=%.8f",
                       (int)opened,single.AverageEntry(),single.Exposure(),
                       single.NetVolume(),single.UnrealizedPnl(1.25)));

   error="";
   CSimPortfolio weighted;
   weighted.Init(10000.0,error);
   weighted.Open(SIM_SIDE_BUY,1.1,1.0,0.0,error);
   weighted.Open(SIM_SIDE_BUY,1.0,2.0,0.0,error);
   const bool avg_ok=Near(weighted.AverageEntry(),3.1/3.0,1e-8);
   Record("P9",avg_ok && Near(weighted.Exposure(),3.0) &&
          Near(weighted.UnrealizedPnl(1.05),0.05),
          StringFormat("avg=%.8f exp=%.4f upnl=%.8f",
                       weighted.AverageEntry(),weighted.Exposure(),
                       weighted.UnrealizedPnl(1.05)));

   error="";
   double weighted_delta=0.0;
   const bool weighted_closed=weighted.CloseAll(1.05,0.0,error,weighted_delta);
   Record("P10",weighted_closed && Near(weighted_delta,0.05) &&
          weighted.OpenPositions()==0,
          StringFormat("closed=%d delta=%.8f positions=%d err=%s",
                       (int)weighted_closed,weighted_delta,
                       weighted.OpenPositions(),error));
  }

void RunRealized(void)
  {
   string error="";
   CSimPortfolio portfolio;
   portfolio.Init(10000.0,error);

   const bool opened=portfolio.Open(SIM_SIDE_BUY,1.1,1.0,2.0,error);
   Record("P11",opened && Near(portfolio.Balance(),9998.0) &&
          Near(portfolio.RealizedPnl(),-2.0),
          StringFormat("balance=%.4f realized=%.4f",portfolio.Balance(),
                       portfolio.RealizedPnl()));

   double delta=0.0;
   const bool closed=portfolio.CloseAll(1.12,3.0,error,delta);
   Record("P12",closed && Near(delta,-2.98) && Near(portfolio.RealizedPnl(),-4.98) &&
          Near(portfolio.Balance(),9995.02) && portfolio.OpenPositions()==0,
          StringFormat("delta=%.4f realized=%.4f balance=%.4f positions=%d err=%s",
                       delta,portfolio.RealizedPnl(),portfolio.Balance(),
                       portfolio.OpenPositions(),error));

   Record("P13",!portfolio.CloseAll(1.12,0.0,error,delta) &&
          error=="no_open_positions","close empty error="+error);

   error="";
   CSimPortfolio side_portfolio;
   side_portfolio.Init(10000.0,error);
   side_portfolio.Open(SIM_SIDE_BUY,1.1,1.0,0.0,error);
   Record("P14",!side_portfolio.Open(SIM_SIDE_SELL,1.2,1.0,0.0,error) &&
          error=="opposite_side_not_allowed","opposite side error="+error);

   error="";
   CSimPortfolio reset;
   reset.Init(10000.0,error);
   reset.Open(SIM_SIDE_SELL,1.1,1.5,0.0,error);
   double reset_delta=0.0;
   reset.CloseAll(1.0,0.0,error,reset_delta);
   Record("P15",reset.OpenPositions()==0 && Near(reset.AverageEntry(),0.0) &&
          Near(reset.Exposure(),0.0) && Near(reset.NetVolume(),0.0),
          StringFormat("positions=%d avg=%.8f exp=%.4f net=%.4f",
                       reset.OpenPositions(),reset.AverageEntry(),
                       reset.Exposure(),reset.NetVolume()));

   error="";
   CSimPortfolio partial;
   partial.Init(10000.0,error);
   partial.Open(SIM_SIDE_BUY,1.0,1.0,0.0,error);
   partial.Open(SIM_SIDE_BUY,0.9,2.0,0.0,error);
   double partial_delta=0.0;
   int closed_count=0;
   const bool partial_ok=partial.CloseProfitableAtLeast(1.0,0.05,0.5,error,
                                                        partial_delta,closed_count);
   Record("P20",partial_ok && closed_count==1 && Near(partial_delta,-0.8) &&
          partial.OpenPositions()==1 && Near(partial.MinEntry(),1.0) &&
          Near(partial.MaxEntry(),1.0) && Near(partial.Exposure(),1.0),
          StringFormat("closed=%d delta=%.4f positions=%d min=%.4f exp=%.4f err=%s",
                       closed_count,partial_delta,partial.OpenPositions(),
                       partial.MinEntry(),partial.Exposure(),error));

   error="";
   const bool no_match=partial.CloseProfitableAtLeast(1.0,0.05,0.5,error,
                                                      partial_delta,closed_count);
   Record("P21",!no_match && error=="no_matching_positions" && closed_count==0 &&
          Near(partial_delta,0.0),"no match error="+error);

   error="";
   CSimPortfolio short_partial;
   short_partial.Init(10000.0,error);
   short_partial.Open(SIM_SIDE_SELL,1.0,1.0,0.0,error);
   short_partial.Open(SIM_SIDE_SELL,1.1,1.0,0.0,error);
   double short_delta=0.0;
   int short_closed=0;
   const bool short_ok=short_partial.CloseProfitableAtLeast(0.9,0.05,0.0,error,
                                                            short_delta,short_closed);
   Record("P22",short_ok && short_closed==2 && Near(short_delta,0.3) &&
          short_partial.OpenPositions()==0,
          StringFormat("closed=%d delta=%.4f positions=%d err=%s",
                       short_closed,short_delta,short_partial.OpenPositions(),error));
  }

void RunDrawdown(void)
  {
   string error="";
   CSimPortfolio portfolio;
   portfolio.Init(10000.0,error);
   portfolio.Open(SIM_SIDE_BUY,100.0,1.0,0.0,error);

   const double e1=portfolio.Equity(90.0);
   const double dd1=portfolio.MaxDrawdownPct();
   const double e2=portfolio.Equity(105.0);
   const double peak2=portfolio.PeakEquity();
   const double e3=portfolio.Equity(80.0);
   const double dd3=portfolio.MaxDrawdownPct();

   Record("P16",Near(e1,9990.0) && Near(dd1,0.1,1e-9),
          StringFormat("e1=%.4f dd1=%.6f",e1,dd1));
   Record("P17",Near(e2,10005.0) && Near(peak2,10005.0) && Near(dd1,0.1,1e-9),
          StringFormat("e2=%.4f peak=%.4f",e2,peak2));
   Record("P18",Near(e3,9980.0) && dd3>0.24 && dd3<0.26,
          StringFormat("e3=%.4f dd3=%.6f",e3,dd3));

   SimPortfolioSnapshot snapshot;
   const bool snap_ok=portfolio.Snapshot(90.0,snapshot);
   Record("P19",snap_ok && snapshot.open_positions==1 &&
          Near(snapshot.exposure,1.0) && Near(snapshot.average_entry,100.0) &&
          Near(snapshot.unrealized_pnl,-10.0) && Near(snapshot.equity,9990.0),
          StringFormat("snap open=%d exp=%.4f avg=%.4f upnl=%.4f eq=%.4f",
                       snapshot.open_positions,snapshot.exposure,
                       snapshot.average_entry,snapshot.unrealized_pnl,
                       snapshot.equity));
  }

void RunValidation(void)
  {
   string error="";

   Record("V1",SimValidatePrice(1.2,error) && error=="",
          "price valid error="+error);
   Record("V2",!SimValidatePrice(-0.1,error) && !SimValidatePrice(0.0,error),
          "price invalid accepted");
   Record("V3",SimValidateVolume(0.01,error) && !SimValidateVolume(0.0,error),
          "volume boundary");
   Record("V4",SimValidateCommission(0.0,error) && !SimValidateCommission(-0.01,error),
          "commission boundary");
   Record("V5",SimValidateInitialBalance(100.0,error) &&
          !SimValidateInitialBalance(0.0,error),"balance boundary");
   Record("V6",SimValidateLevels(1,error) && SimValidateLevels(1000,error) &&
          !SimValidateLevels(0,error) && !SimValidateLevels(1001,error),
          "levels boundary");
   Record("V7",SimValidateMultiplier(1.0,error) && !SimValidateMultiplier(0.99,error),
          "multiplier boundary");
   Record("V8",SimValidatePercent(0.0,error) && SimValidatePercent(100.0,error) &&
          !SimValidatePercent(100.01,error) && !SimValidatePercent(-0.01,error),
          "percent boundary");
   Record("V9",SimValidateSpreadPoints(0.0,error) &&
          !SimValidateSpreadPoints(-1.0,error),"spread boundary");
   Record("V10",SimValidateWarmupBars(0,error) && !SimValidateWarmupBars(-1,error),
          "warmup boundary");
   Record("V11",SimValidateSlippagePoints(0.0,error) &&
          !SimValidateSlippagePoints(-0.5,error),"slippage boundary");
  }

void RunHashes(void)
  {
   Record("H1",SimHashString("abc")=="1A47E90B","abc="+SimHashString("abc"));
   Record("H2",SimHashString("")=="811C9DC5","empty="+SimHashString(""));
   Record("H3",SimHashString("abc")!=SimHashString("abd"),
          "hash collision on sample");
   Record("H4",SimFormatFingerprintPartInt("levels",3)=="levels=3;",
          SimFormatFingerprintPartInt("levels",3));
   Record("H5",SimFormatFingerprintPart("mult",1.5,2)=="mult=1.50;",
          SimFormatFingerprintPart("mult",1.5,2));
   Record("H6",SimFormatFingerprintPartText("side","BUY")=="side=BUY;",
          SimFormatFingerprintPartText("side","BUY"));
  }

string SimLogRecordEmptyReason(void)
  {
   SimLogRecord empty_record;
   SimClearLogRecord(empty_record);
   return(empty_record.reason);
  }

void RunLoggerFormat(void)
  {
   SimLogRecord record;
   SimClearLogRecord(record);
   record.logged_at=D'2026.01.05 10:05:00';
   record.bar_time=D'2026.01.05 10:00:00';
   record.ea="SimCoreTests";
   record.version="1.00";
   record.config_hash=SimHashString("test");
   record.symbol="EURUSD";
   record.timeframe="M5";
   record.event="OPEN";
   record.side=SIM_SIDE_BUY;
   record.price=1.105;
   record.volume=1.5;
   record.entry=1.105;
   record.sl=1.1;
   record.tp=1.12;
   record.exposure=1.5;
   record.equity=10000.0;
   record.drawdown_pct=0.25;
   record.reason="TEST_REASON";

   const string line=SimFormatLogLine(record);
   Record("L1",CountFields(SIM_LOG_HEADER)==18,
          StringFormat("header_fields=%d",CountFields(SIM_LOG_HEADER)));
   Record("L2",CountFields(line)==18,StringFormat("line_fields=%d",CountFields(line)));
   Record("L3",StringFind(line,"SimCoreTests")>=0 && StringFind(line,"BUY")>=0 &&
          StringFind(line,"TEST_REASON")>=0 && StringFind(line,"2026.01.05 10:00:00")>=0,
          line);
   Record("L4",SimSideName(SIM_SIDE_SELL)=="SELL" &&
          SimSideName(SIM_SIDE_NONE)=="NONE","side names");
   Record("L5",StringLen(SimLogRecordEmptyReason())==0,"empty record reason");
  }

SimCostAssumptions CostBase(void)
  {
   SimCostAssumptions a=SimCostAssumptionsDefault();
   a.point=0.0001;
   a.commission_per_volume=4.0;
   a.slippage_points=1.0;
   a.swap_per_volume_day=-1.5;
   return(a);
  }

void RunCost(void)
  {
   string error="";
   CSimCostModel model;

   SimCostAssumptions bad_point=CostBase();
   bad_point.point=0.0;
   Record("C1",!model.Init(bad_point,error) &&
          error=="point_must_be_finite_positive","point=0 error="+error);

   SimCostAssumptions bad_commission=CostBase();
   bad_commission.commission_per_volume=-1.0;
   Record("C2",!model.Init(bad_commission,error) &&
          error=="commission_must_be_finite_non_negative",
          "commission=-1 error="+error);

   SimCostAssumptions bad_slippage=CostBase();
   bad_slippage.slippage_points=-1.0;
   Record("C3",!model.Init(bad_slippage,error) &&
          error=="slippage_must_be_finite_non_negative",
          "slippage=-1 error="+error);

   Record("C4",model.Init(CostBase(),error) && model.IsInitialized(),
          "init valid error="+error);

   const double buy_fill=model.FillPrice(SIM_SIDE_BUY,1.1,2.0);
   Record("C5",Near(buy_fill,1.1003,1e-12),
          StringFormat("buy_fill=%.10f",buy_fill));

   const double sell_fill=model.FillPrice(SIM_SIDE_SELL,1.1,2.0);
   Record("C6",Near(sell_fill,1.0997,1e-12),
          StringFormat("sell_fill=%.10f",sell_fill));

   Record("C7",Near(model.Commission(2.5),10.0,1e-12),
          StringFormat("commission=%.6f",model.Commission(2.5)));
   Record("C8",Near(model.SpreadPrice(20.0),0.002,1e-12),
          StringFormat("spread_price=%.10f",model.SpreadPrice(20.0)));
   Record("C9",Near(model.Swap(2.0,3),-9.0,1e-12),
          StringFormat("swap=%.6f",model.Swap(2.0,3)));
   Record("C10",Near(model.TotalCost(2.0,20.0,1),5.004,1e-12),
          StringFormat("total_cost=%.6f",model.TotalCost(2.0,20.0,1)));

   CSimCostModel uninitialized;
   Record("C11",Near(uninitialized.Commission(1.0),0.0) &&
          Near(uninitialized.FillPrice(SIM_SIDE_BUY,1.1,0.0),0.0),
          "uninitialized model must be inert");

   CSimCostModel model_a;
   CSimCostModel model_b;
   SimCostAssumptions assumptions_b=CostBase();
   assumptions_b.point=0.00001;
   model_a.Init(CostBase(),error);
   model_b.Init(assumptions_b,error);
   Record("C12",model_a.Fingerprint()==model_a.Fingerprint() &&
          model_a.Fingerprint()!=model_b.Fingerprint(),
          "fingerprint stable and point-sensitive");
  }

SimRiskContext RiskCtx(void)
  {
   SimRiskContext c;
   c.spread_points=10.0;
   c.price_valid=true;
   c.open_positions=0;
   c.grid_levels=0;
   c.dca_adds=0;
   c.exposure=0.0;
   c.volume_to_add=1.0;
   c.equity=10000.0;
   c.day_start_equity=10000.0;
   c.peak_equity=10000.0;
   c.bar_time=D'2026.01.05 10:00:00';
   return(c);
  }

SimRiskLimits RiskBase(void)
  {
   SimRiskLimits l=SimRiskLimitsDefault();
   l.max_spread_points=50.0;
   l.max_virtual_positions=3;
   l.max_grid_levels=4;
   l.max_dca_adds=2;
   l.max_virtual_exposure=10.0;
   l.max_daily_loss_pct=5.0;
   l.max_drawdown_pct=8.0;
   l.cooldown_bars=2;
   l.require_valid_price=true;
   l.kill_switch=false;
   l.halt_on_breach=false;
   return(l);
  }

void RunRisk(void)
  {
   string error="";
   CSimRiskGuard guard;
   Record("R1",guard.Init(RiskBase(),300,error) &&
          guard.IsInitialized() && guard.State()==SIM_RISK_ACTIVE,
          "init error="+error);

   SimRiskDecision decision=guard.Evaluate(RiskCtx());
   Record("R2",decision.allowed && decision.state==SIM_RISK_ACTIVE,
          "baseline reason="+decision.reason);

   SimRiskContext ctx=RiskCtx();
   ctx.spread_points=50.1;
   decision=guard.Evaluate(ctx);
   const bool spread_blocked=!decision.allowed &&
                             decision.reason=="spread_exceeded" &&
                             decision.state==SIM_RISK_BLOCKED;
   ctx.spread_points=50.0;
   decision=guard.Evaluate(ctx);
   Record("R3",spread_blocked && decision.allowed &&
          guard.State()==SIM_RISK_ACTIVE,
          "spread boundary block="+(string)spread_blocked);

   ctx=RiskCtx();
   ctx.price_valid=false;
   decision=guard.Evaluate(ctx);
   Record("R4",!decision.allowed && decision.reason=="price_invalid",
          "invalid price reason="+decision.reason);

   ctx=RiskCtx();
   ctx.open_positions=3;
   decision=guard.Evaluate(ctx);
   const bool positions_blocked=!decision.allowed &&
                                decision.reason=="max_virtual_positions_reached";
   ctx.open_positions=2;
   decision=guard.Evaluate(ctx);
   Record("R5",positions_blocked && decision.allowed,
          "positions boundary block="+(string)positions_blocked);

   ctx=RiskCtx();
   ctx.grid_levels=4;
   decision=guard.Evaluate(ctx);
   const bool grid_blocked=!decision.allowed &&
                           decision.reason=="max_grid_levels_reached";
   ctx.grid_levels=3;
   decision=guard.Evaluate(ctx);
   Record("R6",grid_blocked && decision.allowed,
          "grid boundary block="+(string)grid_blocked);

   ctx=RiskCtx();
   ctx.dca_adds=2;
   decision=guard.Evaluate(ctx);
   const bool dca_blocked=!decision.allowed &&
                          decision.reason=="max_dca_adds_reached";
   ctx.dca_adds=1;
   decision=guard.Evaluate(ctx);
   Record("R7",dca_blocked && decision.allowed,
          "dca boundary block="+(string)dca_blocked);

   ctx=RiskCtx();
   ctx.exposure=9.5;
   decision=guard.Evaluate(ctx);
   const bool exposure_blocked=!decision.allowed &&
                               decision.reason=="max_virtual_exposure_reached";
   ctx.exposure=9.0;
   decision=guard.Evaluate(ctx);
   Record("R8",exposure_blocked && decision.allowed &&
          Near(ctx.exposure+ctx.volume_to_add,10.0),
          "exposure boundary block="+(string)exposure_blocked);

   CSimRiskGuard daily;
   daily.Init(RiskBase(),300,error);
   ctx=RiskCtx();
   ctx.equity=9499.0;
   decision=daily.Evaluate(ctx);
   Record("R9",!decision.allowed && decision.state==SIM_RISK_HALTED &&
          decision.reason=="daily_loss_limit_reached",
          StringFormat("daily decision=%s reason=%s",
                       SimRiskStateName(decision.state),decision.reason));

   CSimRiskGuard drawdown;
   SimRiskLimits drawdown_limits=RiskBase();
   drawdown_limits.max_daily_loss_pct=0.0;
   drawdown.Init(drawdown_limits,300,error);
   ctx=RiskCtx();
   ctx.equity=9199.0;
   decision=drawdown.Evaluate(ctx);
   Record("R10",!decision.allowed && decision.state==SIM_RISK_HALTED &&
          decision.reason=="max_drawdown_reached",
          StringFormat("drawdown decision=%s reason=%s",
                       SimRiskStateName(decision.state),decision.reason));

   SimRiskLimits kill_limits=RiskBase();
   kill_limits.kill_switch=true;
   CSimRiskGuard kill_guard;
   kill_guard.Init(kill_limits,300,error);
   decision=kill_guard.Evaluate(RiskCtx());
   const bool kill_blocked=!decision.allowed &&
                           decision.reason=="kill_switch_active";
   kill_guard.SetKillSwitch(false);
   decision=kill_guard.Evaluate(RiskCtx());
   const bool still_halted=!decision.allowed &&
                           decision.state==SIM_RISK_HALTED;
   kill_guard.Reset();
   decision=kill_guard.Evaluate(RiskCtx());
   Record("R11",kill_blocked && still_halted && decision.allowed,
          StringFormat("kill blocked=%d still_halted=%d after_reset=%d",
                       (int)kill_blocked,(int)still_halted,(int)decision.allowed));

   CSimRiskGuard cooldown;
   cooldown.Init(RiskBase(),300,error);
   cooldown.RecordEntry(D'2026.01.05 10:00:00');
   ctx=RiskCtx();
   ctx.bar_time=D'2026.01.05 10:05:00';
   decision=cooldown.Evaluate(ctx);
   const bool cooldown_blocked=!decision.allowed &&
                               decision.reason=="cooldown_active";
   ctx.bar_time=D'2026.01.05 10:10:00';
   decision=cooldown.Evaluate(ctx);
   Record("R12",cooldown_blocked && decision.allowed,
          "cooldown boundary block="+(string)cooldown_blocked);

   SimRiskLimits strict=RiskBase();
   strict.halt_on_breach=true;
   CSimRiskGuard strict_guard;
   strict_guard.Init(strict,300,error);
   ctx=RiskCtx();
   ctx.spread_points=60.0;
   decision=strict_guard.Evaluate(ctx);
   const bool strict_halted=!decision.allowed &&
                            decision.state==SIM_RISK_HALTED;
   ctx.spread_points=10.0;
   decision=strict_guard.Evaluate(ctx);
   const bool strict_sticky=!decision.allowed &&
                            decision.state==SIM_RISK_HALTED;
   strict_guard.Reset();
   decision=strict_guard.Evaluate(ctx);
   Record("R13",strict_halted && strict_sticky && decision.allowed,
          StringFormat("strict halted=%d sticky=%d after_reset=%d",
                       (int)strict_halted,(int)strict_sticky,(int)decision.allowed));

   CSimRiskGuard loss_guard;
   loss_guard.Init(RiskBase(),300,error);
   ctx=RiskCtx();
   ctx.equity=9499.0;
   loss_guard.Evaluate(ctx);
   ctx.equity=10000.0;
   decision=loss_guard.Evaluate(ctx);
   Record("R14",!decision.allowed && decision.state==SIM_RISK_HALTED,
          "daily loss must not reset on recovery");

   CSimRiskGuard invalid_day;
   invalid_day.Init(RiskBase(),300,error);
   ctx=RiskCtx();
   ctx.day_start_equity=0.0;
   decision=invalid_day.Evaluate(ctx);
   Record("R15",!decision.allowed && decision.state==SIM_RISK_HALTED &&
          decision.reason=="day_start_equity_invalid",
          "invalid day equity reason="+decision.reason);

   SimRiskLimits bad_loss=RiskBase();
   bad_loss.max_daily_loss_pct=101.0;
   CSimRiskGuard bad_loss_guard;
   const bool bad_loss_rejected=!bad_loss_guard.Init(bad_loss,300,error) &&
                                error=="max_daily_loss_pct_must_be_between_0_and_100";
   SimRiskLimits bad_positions=RiskBase();
   bad_positions.max_virtual_positions=-1;
   CSimRiskGuard bad_positions_guard;
   const bool bad_positions_rejected=!bad_positions_guard.Init(bad_positions,300,error) &&
                                     error=="max_virtual_positions_must_be_non_negative";
   CSimRiskGuard bad_timeframe_guard;
   const bool bad_timeframe_rejected=!bad_timeframe_guard.Init(RiskBase(),0,error) &&
                                     error=="timeframe_seconds_must_be_positive";
   Record("R16",bad_loss_rejected && bad_positions_rejected &&
          bad_timeframe_rejected,
          StringFormat("loss=%d positions=%d tf=%d",
                       (int)bad_loss_rejected,(int)bad_positions_rejected,
                       (int)bad_timeframe_rejected));

   CSimRiskGuard counter;
   counter.Init(RiskBase(),300,error);
   ctx=RiskCtx();
   ctx.spread_points=60.0;
   counter.Evaluate(ctx);
   const int blocked_before=counter.BlockedCount();
   counter.Reset();
   Record("R17",blocked_before==1 && counter.BlockedCount()==0,
          StringFormat("before=%d after=%d",blocked_before,counter.BlockedCount()));

   CSimRiskGuard fp_a;
   CSimRiskGuard fp_b;
   SimRiskLimits fp_limits=RiskBase();
   fp_limits.max_virtual_positions=5;
   fp_a.Init(RiskBase(),300,error);
   fp_b.Init(fp_limits,300,error);
   Record("R18",fp_a.Fingerprint()==fp_a.Fingerprint() &&
          fp_a.Fingerprint()!=fp_b.Fingerprint(),
          "risk fingerprint stable and limit-sensitive");

   SimRiskLimits disabled=RiskBase();
   disabled.max_spread_points=0.0;
   disabled.max_daily_loss_pct=0.0;
   disabled.max_drawdown_pct=0.0;
   disabled.max_virtual_exposure=0.0;
   disabled.max_virtual_positions=5;
   disabled.max_dca_adds=5;
   disabled.cooldown_bars=0;
   CSimRiskGuard disabled_guard;
   disabled_guard.Init(disabled,300,error);
   ctx=RiskCtx();
   ctx.spread_points=999.0;
   ctx.equity=100.0;
   ctx.peak_equity=10000.0;
   ctx.day_start_equity=10000.0;
   decision=disabled_guard.Evaluate(ctx);
   Record("R19",decision.allowed,
          "zero limits must disable checks reason="+decision.reason);

   CSimRiskGuard counting;
   counting.Init(RiskBase(),300,error);
   ctx=RiskCtx();
   ctx.price_valid=false;
   counting.Evaluate(ctx);
   counting.Evaluate(ctx);
   Record("R20",counting.BlockedCount()==2,
          StringFormat("blocked_count=%d",counting.BlockedCount()));

   SimRiskLimits no_dca=RiskBase();
   no_dca.max_dca_adds=0;
   CSimRiskGuard no_dca_guard;
   no_dca_guard.Init(no_dca,300,error);
   ctx=RiskCtx();
   ctx.dca_adds=0;
   decision=no_dca_guard.Evaluate(ctx);
   Record("R21",decision.allowed,
          "zero dca limit must disable the check reason="+decision.reason);
  }

SimTrailingInputs TrailBase(void)
  {
   SimTrailingInputs in;
   in.side=SIM_SIDE_BUY;
   in.entry=1.1;
   in.old_sl=1.095;
   in.price=1.11;
   in.distance=0.004;
   in.breakeven_trigger=0.0;
   in.breakeven_offset=0.0;
   in.min_stop=0.0002;
   return(in);
  }

void RunTrailing(void)
  {
   SimTrailingInputs in=TrailBase();
   SimTrailingResult out=SimTrailingEvaluate(in);
   Record("T1",out.accepted && Near(out.candidate_sl,1.106,1e-12),
          StringFormat("accepted=%d candidate=%.8f reason=%s",
                       (int)out.accepted,out.candidate_sl,out.reason));

   in=TrailBase();
   in.old_sl=1.107;
   out=SimTrailingEvaluate(in);
   Record("T2",!out.accepted && out.reason=="not_improving" &&
          Near(out.candidate_sl,1.107,1e-12),
          "long not improving reason="+out.reason);

   in=TrailBase();
   in.distance=0.0001;
   out=SimTrailingEvaluate(in);
   Record("T3",!out.accepted && out.reason=="candidate_too_close",
          "long too close reason="+out.reason);

   in=TrailBase();
   in.side=SIM_SIDE_SELL;
   in.entry=1.2;
   in.old_sl=1.205;
   in.price=1.19;
   out=SimTrailingEvaluate(in);
   Record("T4",out.accepted && Near(out.candidate_sl,1.194,1e-12),
          StringFormat("short accepted=%d candidate=%.8f reason=%s",
                       (int)out.accepted,out.candidate_sl,out.reason));

   in=TrailBase();
   in.side=SIM_SIDE_SELL;
   in.entry=1.2;
   in.old_sl=1.193;
   in.price=1.19;
   out=SimTrailingEvaluate(in);
   Record("T5",!out.accepted && out.reason=="not_improving",
          "short not improving reason="+out.reason);

   in=TrailBase();
   in.price=1.12;
   in.distance=0.03;
   in.breakeven_trigger=0.01;
   out=SimTrailingEvaluate(in);
   Record("T6",out.accepted && Near(out.candidate_sl,1.1,1e-12),
          StringFormat("breakeven long candidate=%.8f",out.candidate_sl));

   in=TrailBase();
   in.side=SIM_SIDE_SELL;
   in.entry=1.2;
   in.old_sl=1.205;
   in.price=1.17;
   in.distance=0.04;
   in.breakeven_trigger=0.02;
   out=SimTrailingEvaluate(in);
   Record("T7",out.accepted && Near(out.candidate_sl,1.2,1e-12),
          StringFormat("breakeven short candidate=%.8f",out.candidate_sl));

   in=TrailBase();
   in.price=1.12;
   in.distance=0.03;
   in.breakeven_trigger=0.0;
   out=SimTrailingEvaluate(in);
   Record("T8",!out.accepted && out.reason=="not_improving",
          "breakeven disabled reason="+out.reason);

   Record("T9",SimStopHit(SIM_SIDE_BUY,1.095,1.0949,1.0951) &&
          !SimStopHit(SIM_SIDE_BUY,1.095,1.0951,1.0953) &&
          SimStopHit(SIM_SIDE_SELL,1.205,1.2048,1.205),
          "stop trigger boundaries");

   const double gap_fill=SimStopFillPrice(SIM_SIDE_BUY,1.095,1.09,1.0902);
   Record("T10",Near(gap_fill,1.09,1e-12) &&
          SimStopGapped(SIM_SIDE_BUY,1.095,gap_fill),
          StringFormat("gap_fill=%.8f",gap_fill));

   const double touch_fill=SimStopFillPrice(SIM_SIDE_BUY,1.095,1.095,1.0952);
   Record("T11",Near(touch_fill,1.095,1e-12) &&
          !SimStopGapped(SIM_SIDE_BUY,1.095,touch_fill),
          StringFormat("touch_fill=%.8f",touch_fill));

   const double short_gap=SimStopFillPrice(SIM_SIDE_SELL,1.205,1.2098,1.21);
   Record("T12",Near(short_gap,1.21,1e-12) &&
          SimStopGapped(SIM_SIDE_SELL,1.205,short_gap),
          StringFormat("short_gap=%.8f",short_gap));

   in=TrailBase();
   in.distance=0.0;
   out=SimTrailingEvaluate(in);
   Record("T13",!out.accepted && out.reason=="invalid_inputs",
          "zero distance reason="+out.reason);

   in=TrailBase();
   in.old_sl=1.107;
   out=SimTrailingEvaluate(in);
   Record("T14",!out.accepted && Near(out.raw_candidate,1.106,1e-12) &&
          Near(out.candidate_sl,1.107,1e-12),
          StringFormat("raw=%.8f kept=%.8f",out.raw_candidate,out.candidate_sl));

   in=TrailBase();
   in.price=1.12;
   in.distance=0.03;
   in.breakeven_trigger=0.01;
   in.breakeven_offset=0.001;
   out=SimTrailingEvaluate(in);
   Record("T15",out.accepted && Near(out.candidate_sl,1.101,1e-12),
          StringFormat("breakeven offset candidate=%.8f",out.candidate_sl));
  }

void RunGrid(void)
  {
   SimGridPlan plan=SimGridPlanAdd(1,3,0.1,2.0,1.0,0.0,1.0);
   Record("G1",plan.allowed && Near(plan.volume,0.1,1e-12),
          StringFormat("level1 volume=%.6f reason=%s",plan.volume,plan.reason));

   plan=SimGridPlanAdd(3,3,0.1,2.0,1.0,0.0,1.0);
   Record("G2",plan.allowed && Near(plan.volume,0.4,1e-12),
          StringFormat("level3 volume=%.6f reason=%s",plan.volume,plan.reason));

   plan=SimGridPlanAdd(4,5,0.1,2.0,0.5,0.0,1.0);
   Record("G3",plan.allowed && Near(plan.volume,0.5,1e-12),
          StringFormat("clamped volume=%.6f reason=%s",plan.volume,plan.reason));

   plan=SimGridPlanAdd(4,3,0.1,2.0,1.0,0.0,1.0);
   Record("G4",!plan.allowed && plan.reason=="max_grid_levels_reached",
          "max levels reason="+plan.reason);

   plan=SimGridPlanAdd(2,3,0.1,1.0,1.0,0.95,1.0);
   Record("G5",!plan.allowed && plan.reason=="max_virtual_exposure_reached",
          "exposure block reason="+plan.reason);

   plan=SimGridPlanAdd(2,3,0.1,1.0,1.0,0.9,1.0);
   Record("G6",plan.allowed && Near(plan.volume,0.1,1e-12),
          StringFormat("exposure boundary volume=%.6f reason=%s",
                       plan.volume,plan.reason));

   plan=SimGridPlanAdd(2,3,0.1,0.5,1.0,0.0,1.0);
   Record("G7",!plan.allowed && plan.reason=="grid_volume_invalid",
          "multiplier reason="+plan.reason);

   const double buy_next=SimGridNextLevelPrice(SIM_SIDE_BUY,1.1,0.01);
   const double sell_next=SimGridNextLevelPrice(SIM_SIDE_SELL,1.1,0.01);
   Record("G8",Near(buy_next,1.09,1e-12) && Near(sell_next,1.11,1e-12),
          StringFormat("buy_next=%.6f sell_next=%.6f",buy_next,sell_next));

   Record("G9",SimGridTriggered(SIM_SIDE_BUY,1.1,0.01,1.09,1.0902) &&
          !SimGridTriggered(SIM_SIDE_BUY,1.1,0.01,1.0901,1.0903) &&
          SimGridTriggered(SIM_SIDE_SELL,1.1,0.01,1.1098,1.11),
          "grid trigger boundaries");

   Record("G10",SimGridTargetHit(SIM_SIDE_BUY,1.05,0.02,1.07,1.0702) &&
          !SimGridTargetHit(SIM_SIDE_BUY,1.05,0.02,1.0699,1.0701) &&
          SimGridTargetHit(SIM_SIDE_SELL,1.05,0.02,1.0298,1.03),
          "basket target boundaries");

   Record("G11",SimGridStopHit(SIM_SIDE_BUY,1.05,0.02,1.03,1.0302) &&
          !SimGridStopHit(SIM_SIDE_BUY,1.05,0.02,1.0301,1.0303) &&
          SimGridStopHit(SIM_SIDE_SELL,1.05,0.02,1.0698,1.07),
          "basket stop boundaries");

   Record("G12",Near(SimGridNextLevelPrice(SIM_SIDE_BUY,1.1,0.0),0.0,1e-12) &&
          !SimGridTriggered(SIM_SIDE_BUY,1.1,0.0,1.0,1.0) &&
          !SimGridTargetHit(SIM_SIDE_NONE,1.05,0.02,1.07,1.07),
          "invalid spacing and side");
  }

void RunDca(void)
  {
   SimDcaPlan plan=SimDcaPlanAdd(0,3,0.1,1.5,1.0,0.0,2.0);
   Record("D1",plan.allowed && plan.add_index==1 && Near(plan.volume,0.15,1e-12),
          StringFormat("add1 volume=%.6f index=%d reason=%s",
                       plan.volume,plan.add_index,plan.reason));

   plan=SimDcaPlanAdd(2,3,0.1,1.5,1.0,0.0,2.0);
   Record("D2",plan.allowed && plan.add_index==3 && Near(plan.volume,0.3375,1e-12),
          StringFormat("add3 volume=%.6f index=%d reason=%s",
                       plan.volume,plan.add_index,plan.reason));

   plan=SimDcaPlanAdd(1,3,0.1,2.0,0.15,0.0,2.0);
   Record("D3",plan.allowed && Near(plan.volume,0.15,1e-12),
          StringFormat("clamped volume=%.6f reason=%s",plan.volume,plan.reason));

   plan=SimDcaPlanAdd(1,1,0.1,1.5,1.0,0.0,2.0);
   Record("D4",!plan.allowed && plan.reason=="max_dca_adds_reached",
          "max add reached reason="+plan.reason);

   plan=SimDcaPlanAdd(0,0,0.1,1.5,1.0,0.0,2.0);
   Record("D5",!plan.allowed && plan.reason=="max_dca_adds_reached",
          "max add zero reason="+plan.reason);

   plan=SimDcaPlanAdd(0,3,0.1,1.0,1.0,1.95,2.0);
   Record("D6",!plan.allowed && plan.reason=="max_virtual_exposure_reached",
          "exposure block reason="+plan.reason);

   plan=SimDcaPlanAdd(0,3,0.1,1.0,1.0,1.9,2.0);
   Record("D7",plan.allowed && Near(plan.volume,0.1,1e-12),
          StringFormat("exposure boundary volume=%.6f reason=%s",
                       plan.volume,plan.reason));

   plan=SimDcaPlanAdd(0,3,0.1,0.5,1.0,0.0,2.0);
   Record("D8",!plan.allowed && plan.reason=="dca_volume_invalid",
          "multiplier reason="+plan.reason);

   plan=SimDcaPlanAdd(0,-1,0.1,1.5,1.0,0.0,2.0);
   Record("D9",!plan.allowed && plan.reason=="max_dca_adds_invalid",
          "negative max adds reason="+plan.reason);

   plan=SimDcaPlanAdd(0,3,0.1,1.5,1.0,0.0,0.0);
   Record("D10",!plan.allowed && plan.reason=="max_virtual_exposure_invalid",
          "zero exposure cap reason="+plan.reason);

   Record("D11",SimDcaPriceTriggered(SIM_SIDE_BUY,1.1,0.01,1.09,1.0902) &&
          !SimDcaPriceTriggered(SIM_SIDE_BUY,1.1,0.01,1.0901,1.0903) &&
          SimDcaPriceTriggered(SIM_SIDE_SELL,1.1,0.01,1.1098,1.11) &&
          !SimDcaPriceTriggered(SIM_SIDE_SELL,1.1,0.01,1.1096,1.1099),
          "price trigger boundaries");

   Record("D12",!SimDcaPriceTriggered(SIM_SIDE_NONE,1.1,0.01,1.0,1.0) &&
          !SimDcaPriceTriggered(SIM_SIDE_BUY,1.1,0.0,1.0,1.0) &&
          !SimDcaPriceTriggered(SIM_SIDE_BUY,0.0,0.01,1.0,1.0),
          "invalid trigger inputs");

   const datetime last_bar=D'2024.01.01 10:00';
   Record("D13",SimDcaBarTriggered(last_bar,last_bar+10800,3,3600) &&
          !SimDcaBarTriggered(last_bar,last_bar+10740,3,3600) &&
          !SimDcaBarTriggered(last_bar,last_bar,3,3600) &&
          !SimDcaBarTriggered(last_bar,last_bar-3600,3,3600),
          "bar interval boundaries");

   Record("D14",SimDcaBarsSince(last_bar,last_bar+10800,3600)==3 &&
          SimDcaBarsSince(last_bar,last_bar+10740,3600)==2 &&
          SimDcaBarsSince(last_bar,last_bar,3600)==0 &&
          !SimDcaBarTriggered(0,last_bar,1,3600) &&
          !SimDcaBarTriggered(last_bar,last_bar+3600,0,3600),
          "bars since and invalid interval");

   //--- Basket geometry: average entry (1.1*0.10 + 1.07*0.15) / 0.25 = 1.082.
   Record("D15",SimGridTargetHit(SIM_SIDE_BUY,1.082,0.03,1.112,1.1122) &&
          !SimGridTargetHit(SIM_SIDE_BUY,1.082,0.03,1.1119,1.1121) &&
          SimGridStopHit(SIM_SIDE_BUY,1.082,0.05,1.032,1.0322) &&
          !SimGridStopHit(SIM_SIDE_BUY,1.082,0.05,1.0321,1.0323),
          "dca basket target and stop from average entry");

   string error="";
   CSimPortfolio portfolio;
   portfolio.Init(10000.0,error);
   portfolio.Open(SIM_SIDE_BUY,1.1000,0.10,0.0,error);
   portfolio.Open(SIM_SIDE_BUY,1.0700,0.15,0.0,error);
   Record("D16",Near(portfolio.AverageEntry(),1.082,1e-12) &&
          Near(portfolio.Exposure(),0.25,1e-12) &&
          Near(portfolio.UnrealizedPnl(1.112),0.0075,1e-12),
          StringFormat("avg=%.6f exposure=%.6f upnl=%.6f",
                       portfolio.AverageEntry(),portfolio.Exposure(),
                       portfolio.UnrealizedPnl(1.112)));

   double realized_delta=0.0;
   portfolio.CloseAll(1.112,0.0,error,realized_delta);
   Record("D17",Near(realized_delta,0.0075,1e-12) &&
          Near(portfolio.Balance(),10000.0075,1e-9) &&
          portfolio.OpenPositions()==0,
          StringFormat("target delta=%.6f balance=%.6f",
                       realized_delta,portfolio.Balance()));

   CSimPortfolio with_commission;
   with_commission.Init(10000.0,error);
   with_commission.Open(SIM_SIDE_BUY,1.1000,0.10,0.05,error);
   with_commission.Open(SIM_SIDE_BUY,1.0700,0.15,0.075,error);
   realized_delta=0.0;
   with_commission.CloseAll(1.112,0.125,error,realized_delta);
   Record("D18",Near(realized_delta,-0.1175,1e-12) &&
          Near(with_commission.RealizedPnl(),-0.2425,1e-12),
          StringFormat("commission delta=%.6f realized=%.6f",
                       realized_delta,with_commission.RealizedPnl()));

   CSimPortfolio stopped;
   stopped.Init(10000.0,error);
   stopped.Open(SIM_SIDE_BUY,1.1000,0.10,0.0,error);
   stopped.Open(SIM_SIDE_BUY,1.0700,0.15,0.0,error);
   realized_delta=0.0;
   stopped.CloseAll(1.032,0.0,error,realized_delta);
   Record("D19",Near(realized_delta,-0.0125,1e-12),
          StringFormat("stop delta=%.6f",realized_delta));
  }

void OnStart(void)
  {
   PrintFormat("TEST|BEGIN|suite=sim_core|version=1.00");
   RunPortfolio();
   RunRealized();
   RunDrawdown();
   RunValidation();
   RunHashes();
   RunLoggerFormat();
   RunCost();
   RunRisk();
   RunTrailing();
   RunGrid();
   RunDca();
   if(g_fail==0)
      PrintFormat("TEST|RESULT|ALL_PASS|pass=%d fail=%d|suite=sim_core",g_pass,g_fail);
   else
      PrintFormat("TEST|RESULT|FAIL|pass=%d fail=%d|suite=sim_core",g_pass,g_fail);
  }
