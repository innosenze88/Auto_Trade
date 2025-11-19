//+------------------------------------------------------------------+
//|                                                  Constants.mqh    |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     Global constants and prefixes                |
//+------------------------------------------------------------------+

#ifndef __CONSTANTS_MQH__
#define __CONSTANTS_MQH__

// EA Identification
#define EA_NAME                "SmartMoney_Pro_v2.0"
#define EA_VERSION             "2.000"
#define EA_MAGIC_NUMBER        20240001
#define EA_DEVELOPER           "Auto_Trade"

// GlobalVariable Prefixes (for persistent storage)
#define GLOBAL_VAR_PREFIX      "SMC_"
#define STATS_CLOSED_PROFIT    "STATS_CLOSED_PROFIT"
#define STATS_FLOATING_PROFIT  "STATS_FLOATING_PROFIT"
#define STATS_TRADE_COUNT      "STATS_TRADE_COUNT"
#define STATS_WIN_COUNT        "STATS_WIN_COUNT"
#define STATS_LOSS_COUNT       "STATS_LOSS_COUNT"
#define STATS_LAST_RESET       "STATS_LAST_RESET"

// Chart Object Prefixes
#define OBJ_PREFIX_STRUCTURE   "SMC_STRUCT_"
#define OBJ_PREFIX_FVG         "SMC_FVG_"
#define OBJ_PREFIX_OB          "SMC_OB_"
#define OBJ_PREFIX_SL          "SMC_SL_"
#define OBJ_PREFIX_TP          "SMC_TP_"

// Array Sizing Constants
#define MAX_FVG_ARRAY_SIZE     100   // Maximum FVGs to track
#define MAX_OB_ARRAY_SIZE      50    // Maximum OBs to track
#define MAX_POSITIONS_TRACKED  10    // Maximum positions to monitor

// Pattern Detection Constants
#define MAX_PATTERN_AGE_BARS   200   // Delete patterns older than this
#define MIN_SWING_BARS         2     // Minimum bars for valid swing
#define MAX_LOOKBACK_BARS      100   // Maximum bars to scan for patterns

// Time Constants (in seconds)
#define SECONDS_PER_HOUR       3600
#define SECONDS_PER_DAY        86400
#define LONDON_SESSION_START   8     // 08:00 GMT
#define LONDON_SESSION_END     17    // 17:00 GMT
#define NEWYORK_SESSION_START  13    // 13:00 GMT
#define NEWYORK_SESSION_END    22    // 22:00 GMT
#define OVERLAP_START          13    // 13:00 GMT
#define OVERLAP_END            17    // 17:00 GMT

// NFP (Non-Farm Payroll) Timing
#define NFP_DAY_OFFSET         0     // 1st Friday of month
#define NFP_HOUR_GMT           13    // 13:00 GMT
#define NFP_MINUTE_GMT         30    // 13:30 GMT

// Position Management Defaults
#define DEFAULT_BREAKEVEN_BUFFER 2   // Points to leave above/below entry
#define DEFAULT_TRAILING_STEP    10  // Points to trail each update

// Risk Management Defaults
#define MIN_RISK_REWARD_RATIO  1.5   // Minimum TP/SL ratio
#define DEFAULT_MAX_SPREAD     10    // Maximum acceptable spread (points)
#define DEFAULT_MIN_SL_POINTS  5     // Minimum stop loss distance (points)

// Display Constants
#define PANEL_POSITION_X       20    // Chart position for statistics panel
#define PANEL_POSITION_Y       20
#define PANEL_FONT_SIZE        10    // Font size for display
#define PANEL_LINE_HEIGHT      16    // Pixels between lines
#define PANEL_WIDTH            300   // Width of info panel
#define PANEL_HEIGHT           500   // Height of info panel

// Color Defaults
#define COLOR_BULLISH          clrGreen
#define COLOR_BEARISH          clrRed
#define COLOR_NEUTRAL          clrGray
#define COLOR_BULLISH_LIGHT    C'135,206,235'   // Light blue
#define COLOR_BEARISH_LIGHT    C'255,182,193'   // Light red
#define COLOR_ALERT            clrYellow

// Line Style Defaults
#define LINE_STYLE_STRUCTURE   STYLE_SOLID
#define LINE_STYLE_PREVIOUS    STYLE_DASH
#define LINE_WIDTH_STRUCTURE   2
#define LINE_WIDTH_PREVIOUS    1

// Alert Message Templates
#define ALERT_TEMPLATE         "[%s] %s: %s"
#define ENTRY_ALERT_TEMPLATE   "[%s] ENTRY: %s | SL: %.5f | TP: %.5f"
#define SIGNAL_ALERT_TEMPLATE  "[%s] SIGNAL: %s on %s"

#endif // __CONSTANTS_MQH__
