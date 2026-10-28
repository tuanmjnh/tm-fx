//+------------------------------------------------------------------+
//|                                                     TRConfig.mqh |
//|      PA_TrendRider_XAU_V1 - strategy configuration and checks     |
//|                                                                  |
//| Defaults are the specification's starting hypothesis, not tuned   |
//| values. Validation is fail-closed: any invalid field disables the |
//| strategy before a single bar is read.                            |
//+------------------------------------------------------------------+
#ifndef TR_CONFIG_MQH
#define TR_CONFIG_MQH

#include "TRTypes.mqh"

struct TRConfig
  {
   //--- Structure detection
   int               swing_left;
   int               swing_right;
   //--- Money management
   double            risk_percent;
   int               max_positions;
   double            daily_loss_limit_pct;
   double            max_drawdown_pct;
   int               max_consecutive_losses;
   int               cooldown_minutes;
   //--- Trade management
   double            break_even_at_r;
   double            trailing_start_r;
   int               atr_period;
   double            atr_stop_buffer;
   double            atr_trailing_multiplier;
   double            abnormal_atr_ratio;
   int               atr_baseline_bars;
   //--- Break buffers and setup filters
   double            spread_buffer_multiplier;
   double            atr_break_buffer_multiplier;
   double            trend_min_delta_atr;
   double            retest_zone_atr;
   double            confirmation_body_atr;
   double            confirmation_close_zone;
   int               max_signal_age_bars;
   //--- Stop bounds and execution costs
   double            min_sl_atr;
   double            max_sl_atr;
   double            max_spread_points;
   double            max_spread_atr_ratio;
   double            max_virtual_exposure;
   double            commission_per_volume;
   double            slippage_points;
  };

TRConfig TRConfigDefault(void)
  {
   TRConfig cfg;
   cfg.swing_left=2;
   cfg.swing_right=2;
   cfg.risk_percent=0.25;
   cfg.max_positions=1;
   cfg.daily_loss_limit_pct=1.0;
   cfg.max_drawdown_pct=8.0;
   cfg.max_consecutive_losses=3;
   cfg.cooldown_minutes=30;
   cfg.break_even_at_r=1.0;
   cfg.trailing_start_r=1.5;
   cfg.atr_period=14;
   cfg.atr_stop_buffer=0.2;
   cfg.atr_trailing_multiplier=1.2;
   cfg.abnormal_atr_ratio=2.5;
   cfg.atr_baseline_bars=100;
   cfg.spread_buffer_multiplier=2.0;
   cfg.atr_break_buffer_multiplier=0.10;
   cfg.trend_min_delta_atr=0.05;
   cfg.retest_zone_atr=0.25;
   cfg.confirmation_body_atr=0.5;
   cfg.confirmation_close_zone=0.25;
   cfg.max_signal_age_bars=8;
   cfg.min_sl_atr=0.5;
   cfg.max_sl_atr=4.0;
   cfg.max_spread_points=600.0;
   cfg.max_spread_atr_ratio=0.25;
   cfg.max_virtual_exposure=1.0;
   cfg.commission_per_volume=0.0;
   cfg.slippage_points=0.0;
   return(cfg);
  }

bool TRConfigValidate(const TRConfig &cfg,string &error)
  {
   error="";
   if(cfg.swing_left<1 || cfg.swing_left>10)
     {
      error="swing_left_must_be_between_1_and_10";
      return(false);
     }
   if(cfg.swing_right<1 || cfg.swing_right>10)
     {
      error="swing_right_must_be_between_1_and_10";
      return(false);
     }
   if(!TRIsFinitePositive(cfg.risk_percent) || cfg.risk_percent>100.0)
     {
      error="risk_percent_must_be_in_0_100";
      return(false);
     }
   if(cfg.max_positions<1 || cfg.max_positions>1)
     {
      error="max_positions_must_be_one_in_v1";
      return(false);
     }
   if(!MathIsValidNumber(cfg.daily_loss_limit_pct) ||
      cfg.daily_loss_limit_pct<0.0 || cfg.daily_loss_limit_pct>100.0)
     {
      error="daily_loss_limit_pct_must_be_between_0_and_100";
      return(false);
     }
   if(!MathIsValidNumber(cfg.max_drawdown_pct) ||
      cfg.max_drawdown_pct<0.0 || cfg.max_drawdown_pct>100.0)
     {
      error="max_drawdown_pct_must_be_between_0_and_100";
      return(false);
     }
   if(cfg.max_consecutive_losses<1)
     {
      error="max_consecutive_losses_must_be_positive";
      return(false);
     }
   if(cfg.cooldown_minutes<0)
     {
      error="cooldown_minutes_must_be_non_negative";
      return(false);
     }
   if(!TRIsFinitePositive(cfg.break_even_at_r) || cfg.break_even_at_r>20.0)
     {
      error="break_even_at_r_must_be_in_0_20";
      return(false);
     }
   if(!TRIsFinitePositive(cfg.trailing_start_r) ||
      cfg.trailing_start_r<cfg.break_even_at_r)
     {
      error="trailing_start_r_must_be_at_least_break_even_at_r";
      return(false);
     }
   if(cfg.atr_period<2 || cfg.atr_period>500)
     {
      error="atr_period_must_be_between_2_and_500";
      return(false);
     }
   if(!MathIsValidNumber(cfg.atr_stop_buffer) || cfg.atr_stop_buffer<0.0)
     {
      error="atr_stop_buffer_must_be_non_negative";
      return(false);
     }
   if(!TRIsFinitePositive(cfg.atr_trailing_multiplier))
     {
      error="atr_trailing_multiplier_must_be_positive";
      return(false);
     }
   if(!MathIsValidNumber(cfg.abnormal_atr_ratio) || cfg.abnormal_atr_ratio<=1.0)
     {
      error="abnormal_atr_ratio_must_exceed_one";
      return(false);
     }
   if(cfg.atr_baseline_bars<10 || cfg.atr_baseline_bars>5000)
     {
      error="atr_baseline_bars_must_be_between_10_and_5000";
      return(false);
     }
   if(!MathIsValidNumber(cfg.spread_buffer_multiplier) ||
      cfg.spread_buffer_multiplier<=0.0)
     {
      error="spread_buffer_multiplier_must_be_positive";
      return(false);
     }
   if(!MathIsValidNumber(cfg.atr_break_buffer_multiplier) ||
      cfg.atr_break_buffer_multiplier<0.0)
     {
      error="atr_break_buffer_multiplier_must_be_non_negative";
      return(false);
     }
   if(!MathIsValidNumber(cfg.trend_min_delta_atr) || cfg.trend_min_delta_atr<0.0)
     {
      error="trend_min_delta_atr_must_be_non_negative";
      return(false);
     }
   if(!TRIsFinitePositive(cfg.retest_zone_atr))
     {
      error="retest_zone_atr_must_be_positive";
      return(false);
     }
   if(!MathIsValidNumber(cfg.confirmation_body_atr) ||
      cfg.confirmation_body_atr<0.0 || cfg.confirmation_body_atr>3.0)
     {
      error="confirmation_body_atr_must_be_in_0_3";
      return(false);
     }
   if(!MathIsValidNumber(cfg.confirmation_close_zone) ||
      cfg.confirmation_close_zone<=0.0 || cfg.confirmation_close_zone>=0.5)
     {
      error="confirmation_close_zone_must_be_in_0_0.5";
      return(false);
     }
   if(cfg.max_signal_age_bars<1 || cfg.max_signal_age_bars>500)
     {
      error="max_signal_age_bars_must_be_between_1_and_500";
      return(false);
     }
   if(!TRIsFinitePositive(cfg.min_sl_atr))
     {
      error="min_sl_atr_must_be_positive";
      return(false);
     }
   if(!TRIsFinitePositive(cfg.max_sl_atr) || cfg.max_sl_atr<=cfg.min_sl_atr)
     {
      error="max_sl_atr_must_exceed_min_sl_atr";
      return(false);
     }
   if(!MathIsValidNumber(cfg.max_spread_points) || cfg.max_spread_points<0.0)
     {
      error="max_spread_points_must_be_non_negative";
      return(false);
     }
   if(!MathIsValidNumber(cfg.max_spread_atr_ratio) ||
      cfg.max_spread_atr_ratio<0.0 || cfg.max_spread_atr_ratio>1.0)
     {
      error="max_spread_atr_ratio_must_be_between_0_and_1";
      return(false);
     }
   if(!TRIsFinitePositive(cfg.max_virtual_exposure))
     {
      error="max_virtual_exposure_must_be_positive";
      return(false);
     }
   if(!MathIsValidNumber(cfg.commission_per_volume) ||
      cfg.commission_per_volume<0.0)
     {
      error="commission_per_volume_must_be_non_negative";
      return(false);
     }
   if(!MathIsValidNumber(cfg.slippage_points) || cfg.slippage_points<0.0)
     {
      error="slippage_points_must_be_non_negative";
      return(false);
     }
   return(true);
  }

string TRConfigFingerprint(const TRConfig &cfg)
  {
   string text="";
   text+=SimFormatFingerprintPartInt("tr.swing_left",cfg.swing_left);
   text+=SimFormatFingerprintPartInt("tr.swing_right",cfg.swing_right);
   text+=SimFormatFingerprintPart("tr.risk_pct",cfg.risk_percent,4);
   text+=SimFormatFingerprintPartInt("tr.max_positions",cfg.max_positions);
   text+=SimFormatFingerprintPart("tr.daily_loss_pct",cfg.daily_loss_limit_pct,4);
   text+=SimFormatFingerprintPart("tr.max_dd_pct",cfg.max_drawdown_pct,4);
   text+=SimFormatFingerprintPartInt("tr.max_losses",cfg.max_consecutive_losses);
   text+=SimFormatFingerprintPartInt("tr.cooldown_min",cfg.cooldown_minutes);
   text+=SimFormatFingerprintPart("tr.be_r",cfg.break_even_at_r,4);
   text+=SimFormatFingerprintPart("tr.trail_r",cfg.trailing_start_r,4);
   text+=SimFormatFingerprintPartInt("tr.atr_period",cfg.atr_period);
   text+=SimFormatFingerprintPart("tr.atr_stop_buffer",cfg.atr_stop_buffer,4);
   text+=SimFormatFingerprintPart("tr.atr_trail_mult",cfg.atr_trailing_multiplier,4);
   text+=SimFormatFingerprintPart("tr.abnormal_atr",cfg.abnormal_atr_ratio,4);
   text+=SimFormatFingerprintPartInt("tr.atr_baseline",cfg.atr_baseline_bars);
   text+=SimFormatFingerprintPart("tr.spread_buf_mult",cfg.spread_buffer_multiplier,4);
   text+=SimFormatFingerprintPart("tr.atr_break_buf",cfg.atr_break_buffer_multiplier,4);
   text+=SimFormatFingerprintPart("tr.trend_delta",cfg.trend_min_delta_atr,4);
   text+=SimFormatFingerprintPart("tr.zone_atr",cfg.retest_zone_atr,4);
   text+=SimFormatFingerprintPart("tr.confirm_body",cfg.confirmation_body_atr,4);
   text+=SimFormatFingerprintPart("tr.confirm_zone",cfg.confirmation_close_zone,4);
   text+=SimFormatFingerprintPartInt("tr.signal_age",cfg.max_signal_age_bars);
   text+=SimFormatFingerprintPart("tr.min_sl_atr",cfg.min_sl_atr,4);
   text+=SimFormatFingerprintPart("tr.max_sl_atr",cfg.max_sl_atr,4);
   text+=SimFormatFingerprintPart("tr.max_spread_pts",cfg.max_spread_points,2);
   text+=SimFormatFingerprintPart("tr.max_spread_atr",cfg.max_spread_atr_ratio,4);
   text+=SimFormatFingerprintPart("tr.max_exposure",cfg.max_virtual_exposure,4);
   text+=SimFormatFingerprintPart("tr.commission",cfg.commission_per_volume,4);
   text+=SimFormatFingerprintPart("tr.slippage_pts",cfg.slippage_points,2);
   return(SimHashString(text));
  }

#endif // TR_CONFIG_MQH
