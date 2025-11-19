//+------------------------------------------------------------------+
//|                                           UtilityFunctions.mqh   |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     Helper & Utility Functions                    |
//+------------------------------------------------------------------+

#ifndef __UTILITY_FUNCTIONS_MQH__
#define __UTILITY_FUNCTIONS_MQH__

//+------------------------------------------------------------------+
//| IsNewBar: Detect if New Bar has Formed on Timeframe             |
//| Parameters:                                                      |
//|   tf - Timeframe to check                                        |
//| Returns: true if new bar detected, false otherwise               |
//| Description: Uses static variable to track last bar time and     |
//|              compares with current bar time. Returns true only   |
//|              on first tick of new bar, then false on subsequent  |
//|              ticks of same bar.                                  |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES tf)
{
   static datetime lastBarTime[21];  // Array for 21 timeframes (indices 0-20)
   int index = (int)tf - 1;

   if(index < 0 || index >= 21)
      return false;

   datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, tf, SERIES_LASTBAR_DATE);

   if(currentBarTime != lastBarTime[index])
   {
      lastBarTime[index] = currentBarTime;
      return true;  // New bar detected
   }

   return false;  // Same bar as last check
}

//+------------------------------------------------------------------+
//| GetStateString: Convert Structure State Enum to Display String  |
//| Parameters:                                                      |
//|   state - ENUM_STRUCTURE_STATE value                             |
//| Returns: Display string with emoji (e.g., "UPTREND ↑")           |
//| Description: Converts internal structure state to human-readable |
//|              format with visual indicators.                      |
//+------------------------------------------------------------------+
string GetStateString(ENUM_STRUCTURE_STATE state)
{
   switch(state)
   {
      case STATE_NEUTRAL:
         return "NEUTRAL ◆";
      case STATE_UPTREND:
         return "UPTREND ↑";
      case STATE_DOWNTREND:
         return "DOWNTREND ↓";
      default:
         return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| GetSignalString: Convert Signal Type Enum to Display String     |
//| Parameters:                                                      |
//|   signal - ENUM_SIGNAL_TYPE value                                |
//| Returns: Display string with emoji (e.g., "BOS ↑")               |
//| Description: Converts internal signal type to human-readable     |
//|              format with visual indicators.                      |
//+------------------------------------------------------------------+
string GetSignalString(ENUM_SIGNAL_TYPE signal)
{
   switch(signal)
   {
      case SIGNAL_NONE:
         return "NONE";
      case SIGNAL_BOS_BULL:
         return "BOS ↑";
      case SIGNAL_BOS_BEAR:
         return "BOS ↓";
      case SIGNAL_CHOCH_BULL:
         return "CHoCH ↑";
      case SIGNAL_CHOCH_BEAR:
         return "CHoCH ↓";
      case SIGNAL_FVG_BULL:
         return "FVG ↑";
      case SIGNAL_FVG_BEAR:
         return "FVG ↓";
      case SIGNAL_OB_BULL:
         return "OB ↑";
      case SIGNAL_OB_BEAR:
         return "OB ↓";
      default:
         return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| ResetStructure: Initialize Structure Object to Default State    |
//| Parameters:                                                      |
//|   structure - Structure object to reset                          |
//| Returns: void                                                    |
//| Description: Resets all fields in MarketStructure to defaults.  |
//|              Used during initialization.                         |
//+------------------------------------------------------------------+
void ResetStructure(MarketStructure &structure)
{
   structure.lastHigh = 0;
   structure.lastLow = 0;
   structure.prevHigh = 0;
   structure.prevLow = 0;
   structure.state = STATE_NEUTRAL;
   structure.hasBOS = false;
   structure.hasCHOCH = false;
   structure.lastUpdateTime = 0;
   structure.lastUpdateBar = 0;
}

#endif // __UTILITY_FUNCTIONS_MQH__
