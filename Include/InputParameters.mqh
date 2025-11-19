//+------------------------------------------------------------------+
//|                                            InputParameters.mqh   |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     User-configurable input parameters           |
//+------------------------------------------------------------------+

#ifndef __INPUT_PARAMETERS_MQH__
#define __INPUT_PARAMETERS_MQH__

#include "Enums.mqh"

//+------------------------------------------------------------------+
//| GROUP 1: TIMEFRAME SETTINGS
//+------------------------------------------------------------------+
input group "═══ 1. TIMEFRAME SETTINGS ═══"

input ENUM_TIMEFRAMES HTF = PERIOD_H4;
   /* Higher Timeframe for structural confirmation
      Used to confirm trend direction before entry
      Recommended: H4, D1 */

input ENUM_TIMEFRAMES LTF = PERIOD_H1;
   /* Lower Timeframe for entry signals
      Where actual entries are triggered
      Recommended: H1, M30, M15 */

input int ZigZagDepth = 12;
   /* ZigZag indicator deviation percentage
      Higher = fewer, more significant swings
      Range: 1-50 */

input bool UseZigZag = true;
   /* Use ZigZag indicator for structure detection
      If false, uses simple fractal-based detection
      Recommended: true for more reliable structure */

//+------------------------------------------------------------------+
//| GROUP 2: ENTRY METHOD
//+------------------------------------------------------------------+
input group "═══ 2. ENTRY METHOD ═══"

input ENUM_ENTRY_METHOD EntryMethod = ENTRY_BOS_IMMEDIATE;
   /* Which entry signal type to use:
      0 = BOS Immediate (enter right after BOS)
      1 = BOS Retest (enter on retest of swing level)
      2 = CHoCH Reversal (enter on trend reversal)
      3 = Combined (multiple signal confirmation) */

input bool RequireHTFConfirmation = true;
   /* Require higher timeframe to be trending in same direction
      Recommended: true for better win rate */

input int RetestTolerance = 10;
   /* Pips from previous swing for retest detection
      Range: 5-30 pips */

input bool UseMultipleSignals = true;
   /* Allow combination of BOS + FVG + OB signals
      Recommended: true for stronger confirmation */

//+------------------------------------------------------------------+
//| GROUP 3: RISK MANAGEMENT
//+------------------------------------------------------------------+
input group "═══ 3. RISK MANAGEMENT ═══"

input bool UseFixedLot = false;
   /* Use fixed lot size instead of risk-based sizing
      Recommended: false for proper risk management */

input double FixedLotSize = 0.1;
   /* Lot size if UseFixedLot = true
      Range: 0.01 - 10.0 depending on broker */

input double RiskPercent = 2.0;
   /* Risk per trade as % of account balance
      Only used if UseFixedLot = false
      Recommended: 1-3% for safety
      Range: 0.1-10% */

input double MinRiskRewardRatio = 1.5;
   /* Minimum required TP/SL distance ratio
      1.5 = TakeProfit must be 1.5x the StopLoss distance
      Range: 1.0-3.0 */

input double MaxLotSize = 1.0;
   /* Maximum allowed lot size per trade
      Cap on lot size even with risk-based calculation
      Range: 0.1-10.0 */

input double MaxRiskPerTrade = 100.0;
   /* Maximum USD amount to risk per trade
      Overrides RiskPercent if exceeded
      Range: 10-1000 USD */

input int MaxSpreadPoints = 10;
   /* Maximum acceptable spread in points
      Trade skipped if spread exceeds this
      Range: 2-50 points */

input int MinSLPoints = 5;
   /* Minimum stop loss distance in points
      SL will never be closer than this to entry
      Range: 2-20 points */

//+------------------------------------------------------------------+
//| GROUP 4: SMC SETTINGS (PATTERNS)
//+------------------------------------------------------------------+
input group "═══ 4. SMC SETTINGS (PATTERNS) ═══"

input bool EnableFVGDetection = true;
   /* Enable Fair Value Gap detection and display
      Recommended: true */

input bool EnableOBDetection = true;
   /* Enable Order Block detection and display
      Recommended: true */

input int MinFVGPips = 5;
   /* Minimum gap size for FVG detection (pips)
      Smaller = more FVGs detected
      Range: 2-20 pips */

input int MinOBPips = 5;
   /* Minimum candle size for OB detection (pips)
      Smaller = more OBs detected
      Range: 2-20 pips */

input bool ConfirmOBWithPrice = true;
   /* Require current price to test OB before entry
      Recommended: true for better confirmation */

input bool ConfirmFVGWithPrice = true;
   /* Require current price near FVG zone for entry
      Recommended: true for better confirmation */

//+------------------------------------------------------------------+
//| GROUP 5: PROFIT PROTECTION
//+------------------------------------------------------------------+
input group "═══ 5. PROFIT PROTECTION ═══"

input bool EnableBreakeven = true;
   /* Move stop loss to entry point after certain profit
      Recommended: true to protect capital */

input int BreakevenPoints = 20;
   /* Profit in points required to activate breakeven
      Once profit ≥ this, SL moves to entry + buffer
      Range: 10-50 points */

input int BreakevenBuffer = 2;
   /* Points above/below entry when applying breakeven
      Prevents whipsaw at entry price
      Range: 1-5 points */

input bool EnableTrailing = true;
   /* Enable trailing stop loss
      Recommended: true to maximize profits */

input int TrailingStartPoints = 50;
   /* Profit required before trailing starts
      Range: 20-100 points */

input int TrailingStepPoints = 10;
   /* Points to trail SL on each update
      Smaller = more sensitive trailing
      Range: 5-30 points */

input bool EnablePartialClose = true;
   /* Close partial position at certain profit
      Lock in guaranteed profit
      Recommended: true */

input int PartialClosePoints = 30;
   /* Profit in points to trigger partial close
      Range: 15-100 points */

input double PartialClosePercent = 0.5;
   /* Percentage of position to close (0.0-1.0)
      0.5 = close 50%, keep 50% for trailing
      Range: 0.25-0.75 */

//+------------------------------------------------------------------+
//| GROUP 6: VISUAL SETTINGS
//+------------------------------------------------------------------+
input group "═══ 6. VISUAL SETTINGS ═══"

input bool ShowStructure = true;
   /* Display swing highs/lows on chart
      Recommended: true */

input color StructureColor = clrBlue;
   /* Color for structure lines
      Blue = uptrend, customizable */

input bool ShowFVG = true;
   /* Display Fair Value Gap zones
      Recommended: true */

input color FVGBullishColor = C'144,238,144';
   /* Color for bullish FVG zones (light green)
      Default: pale green */

input color FVGBearishColor = C'255,192,203';
   /* Color for bearish FVG zones (light red)
      Default: pale red */

input bool ShowOB = true;
   /* Display Order Block zones
      Recommended: true */

input color OBBullishColor = C'135,206,235';
   /* Color for bullish OB zones (light blue)
      Default: pale blue */

input color OBBearishColor = C'240,128,128';
   /* Color for bearish OB zones (light coral)
      Default: pale red-orange */

input bool ShowPanel = true;
   /* Display statistics panel on chart
      Shows trading stats and current session
      Recommended: true */

input int PanelFontSize = 10;
   /* Font size for information panel
      Range: 8-14 */

input bool ShowAlerts = true;
   /* Display visual alerts on entry signals
      Recommended: true */

//+------------------------------------------------------------------+
//| GROUP 7: ALERT SETTINGS
//+------------------------------------------------------------------+
input group "═══ 7. ALERT SETTINGS ═══"

input bool EnableAlerts = true;
   /* Enable all types of alerts
      Recommended: true */

input bool AlertOnEntry = true;
   /* Alert when trade is opened
      Recommended: true */

input bool AlertOnSignal = true;
   /* Alert when entry signal is detected
      Recommended: true */

input bool EnableSound = true;
   /* Play sound alerts
      Recommended: true */

input bool EnableEmail = false;
   /* Send email notifications (requires MT5 setup)
      Recommended: false unless configured */

input bool EnablePush = false;
   /* Send push notifications to mobile app
      Recommended: false unless configured */

input int AlertCheckFrequency = 1;
   /* Check for alerts every N ticks
      1 = every tick, 5 = every 5 ticks
      Range: 1-10 */

//+------------------------------------------------------------------+
//| GROUP 8: TIME FILTER SETTINGS (NEW)
//+------------------------------------------------------------------+
input group "═══ 8. TIME FILTER SETTINGS ⭐ ═══"

input bool EnableTimeFilter = true;
   /* Enable session-based trading restrictions
      Recommended: true for better risk management */

input bool TradeOnlyLondon = false;
   /* Restrict trading to London session only (08:00-17:00 GMT)
      If true, ignores NY session completely
      Recommended: false for flexible trading */

input bool TradeOnlyNY = false;
   /* Restrict trading to New York session only (13:00-22:00 GMT)
      If true, ignores London session completely
      Recommended: false for flexible trading */

input bool TradeOverlapOnly = true;
   /* Restrict trading to overlap period (13:00-17:00 GMT)
      When both London and NY are open
      High liquidity, tight spreads
      Recommended: true for best conditions */

input bool AvoidNewsTime = true;
   /* Avoid trading around scheduled news events
      Prevents entry during high volatility spikes
      Recommended: true */

input int NewsAvoidMinutes = 60;
   /* Minutes before/after news to avoid (NFP, major events)
      e.g., 60 = avoid trades from 1 hour before to 1 hour after
      Range: 30-180 minutes */

input int MaxDailyTrades = 5;
   /* Maximum number of trades per day
      Trading stops after this many entries
      Range: 1-20 */

input int MaxDailyLossPoints = -500;
   /* Maximum loss allowed per day (in points)
      Trading stops if daily loss exceeds this
      Negative value: e.g., -500 points = max 500 point loss
      Range: -100 to -5000 points */

input bool ResetStatsOnNewDay = true;
   /* Automatically reset daily statistics at midnight
      Recommended: true */

input int GMTOffset = 0;
   /* GMT offset in hours for your broker's server
      e.g., +2 for EET (Eastern European Time)
      Range: -12 to +14
      Adjust based on broker server timezone */

#endif // __INPUT_PARAMETERS_MQH__
