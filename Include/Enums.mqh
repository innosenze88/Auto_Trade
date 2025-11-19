//+------------------------------------------------------------------+
//|                                                       Enums.mqh  |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     All enumeration definitions                  |
//+------------------------------------------------------------------+

#ifndef __ENUMS_MQH__
#define __ENUMS_MQH__

//+------------------------------------------------------------------+
//| Entry Method Enumeration                                         |
//| Determines which signal type triggers trade entry                |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_METHOD
{
   ENTRY_BOS_IMMEDIATE   = 0,  // Enter immediately on Break of Structure
   ENTRY_BOS_RETEST      = 1,  // Enter on retest of previous swing level
   ENTRY_CHOCH_REVERSAL  = 2,  // Enter on Change of Character (trend reversal)
   ENTRY_COMBINED        = 3   // Enter only with multiple signal confirmation
};

//+------------------------------------------------------------------+
//| Market Structure State                                           |
//| Determines current trend direction                               |
//+------------------------------------------------------------------+
enum ENUM_STRUCTURE_STATE
{
   STATE_NEUTRAL    = 0,  // No clear trend
   STATE_UPTREND    = 1,  // Higher Highs and Higher Lows
   STATE_DOWNTREND  = 2   // Lower Highs and Lower Lows
};

//+------------------------------------------------------------------+
//| Signal Type Enumeration                                          |
//| Identifies what pattern triggered the entry signal               |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE         = 0,   // No signal
   SIGNAL_BOS_BULL     = 1,   // Break of Structure - Bullish
   SIGNAL_BOS_BEAR     = 2,   // Break of Structure - Bearish
   SIGNAL_CHOCH_BULL   = 3,   // Change of Character - Bullish reversal
   SIGNAL_CHOCH_BEAR   = 4,   // Change of Character - Bearish reversal
   SIGNAL_FVG_BULL     = 5,   // Fair Value Gap - Bullish
   SIGNAL_FVG_BEAR     = 6,   // Fair Value Gap - Bearish
   SIGNAL_OB_BULL      = 7,   // Order Block - Bullish
   SIGNAL_OB_BEAR      = 8    // Order Block - Bearish
};

//+------------------------------------------------------------------+
//| News Event Type                                                  |
//| Classifies different news events for avoidance logic             |
//+------------------------------------------------------------------+
enum ENUM_NEWS_TYPE
{
   NEWS_NONE    = 0,  // No news event
   NEWS_NFP     = 1,  // Non-Farm Payroll (1st Friday)
   NEWS_MAJOR   = 2,  // Major economic events
   NEWS_REGULAR = 3   // Regular scheduled events
};

//+------------------------------------------------------------------+
//| FVG Direction                                                    |
//| Indicates if FVG is bullish or bearish                           |
//+------------------------------------------------------------------+
enum ENUM_FVG_DIRECTION
{
   FVG_BULLISH  = 1,  // Gap below current price (demand zone)
   FVG_BEARISH  = -1  // Gap above current price (supply zone)
};

//+------------------------------------------------------------------+
//| Order Block Direction                                            |
//| Indicates if OB is bullish or bearish                            |
//+------------------------------------------------------------------+
enum ENUM_OB_DIRECTION
{
   OB_BULLISH   = 1,  // Bullish OB (support level)
   OB_BEARISH   = -1  // Bearish OB (resistance level)
};

//+------------------------------------------------------------------+
//| Trading Session                                                  |
//| Identifies current market session                                |
//+------------------------------------------------------------------+
enum ENUM_TRADING_SESSION
{
   SESSION_CLOSED    = 0,  // Market closed 💤
   SESSION_LONDON    = 1,  // London session (08:00-17:00 GMT)
   SESSION_NEWYORK   = 2,  // New York session (13:00-22:00 GMT)
   SESSION_OVERLAP   = 3   // Overlap period (13:00-17:00 GMT)
};

#endif // __ENUMS_MQH__
