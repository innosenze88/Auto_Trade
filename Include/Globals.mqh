//+------------------------------------------------------------------+
//|                                                   Globals.mqh     |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     Global variables and arrays                  |
//+------------------------------------------------------------------+

#ifndef __GLOBALS_MQH__
#define __GLOBALS_MQH__

#include "Structures.mqh"
#include "Constants.mqh"

//+------------------------------------------------------------------+
//| Trade Object                                                     |
//+------------------------------------------------------------------+
CTrade trade;                // Trade execution object

//+------------------------------------------------------------------+
//| Indicator Handles                                                |
//+------------------------------------------------------------------+
int handleZigZag = INVALID_HANDLE;   // ZigZag indicator handle
int handleATR = INVALID_HANDLE;      // ATR indicator handle

//+------------------------------------------------------------------+
//| Market Structure Objects (One for each timeframe)                |
//+------------------------------------------------------------------+
MarketStructure structureHTF;        // Higher Timeframe structure
MarketStructure structureLTF;        // Lower Timeframe structure

//+------------------------------------------------------------------+
//| Pattern Arrays (Dynamic Lists)                                   |
//+------------------------------------------------------------------+
FVGInfo fvgArray[];                  // Array of Fair Value Gaps
OrderBlockInfo obArray[];            // Array of Order Blocks

int fvgCount = 0;                    // Current number of FVGs
int obCount = 0;                     // Current number of OBs

//+------------------------------------------------------------------+
//| Current Trade Setup                                              |
//+------------------------------------------------------------------+
TradeSetup currentSetup;             // Setup being prepared for execution

//+------------------------------------------------------------------+
//| Daily Statistics                                                 |
//+------------------------------------------------------------------+
DailyStats stats;                    // Daily trading statistics

//+------------------------------------------------------------------+
//| Time Tracking (for new bar detection)                            |
//+------------------------------------------------------------------+
datetime lastBarTimeHTF = 0;         // Last HTF bar time
datetime lastBarTimeLTF = 0;         // Last LTF bar time

//+------------------------------------------------------------------+
//| Trade Helper Variables                                           |
//+------------------------------------------------------------------+
bool  canOpenPosition = true;        // Whether new positions can be opened
ulong lastTicket = 0;                // Last opened position ticket
datetime lastTradeTime = 0;          // Time of last trade

//+------------------------------------------------------------------+
//| Price Data Buffers (for indicator calculations)                  |
//+------------------------------------------------------------------+
double priceHigh[];                  // High prices for pattern detection
double priceLow[];                   // Low prices for pattern detection
double priceOpen[];                  // Open prices
double priceClose[];                 // Close prices
double priceVolume[];                // Volume data

double zigZagBuffer[];               // ZigZag indicator buffer
double atrBuffer[];                  // ATR indicator buffer

//+------------------------------------------------------------------+
//| Position Tracking                                                |
//+------------------------------------------------------------------+
PositionInfo positionList[];         // List of tracked positions
int positionCount = 0;               // Number of positions currently tracking

//+------------------------------------------------------------------+
//| Visual Display (Chart Objects)                                   |
//+------------------------------------------------------------------+
bool objectsCreated = false;         // Whether chart objects have been initialized

//+------------------------------------------------------------------+
//| EA State Variables                                               |
//+------------------------------------------------------------------+
bool isInitialized = false;          // Whether EA has completed OnInit
bool isDeinitialized = false;        // Whether EA is being unloaded
int deinitReason = 0;                // Reason for deinitialization

//+------------------------------------------------------------------+
//| Configuration Cache                                              |
//| These are cached from input parameters on init                   |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES cachedHTF = PERIOD_H4;
ENUM_TIMEFRAMES cachedLTF = PERIOD_H1;
ENUM_ENTRY_METHOD cachedEntryMethod = ENTRY_BOS_IMMEDIATE;

double cachedRiskPercent = 2.0;
double cachedMaxSpread = 10.0;
int cachedMaxDailyTrades = 5;
int cachedMaxDailyLoss = -500;

bool cachedEnableTimeFilter = true;
bool cachedEnableAlerts = true;
bool cachedEnableFVG = true;
bool cachedEnableOB = true;

//+------------------------------------------------------------------+
//| Debug/Logging                                                    |
//+------------------------------------------------------------------+
bool debugMode = false;              // Enable detailed logging
string lastError = "";               // Last error message

#endif // __GLOBALS_MQH__
