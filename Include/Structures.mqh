//+------------------------------------------------------------------+
//|                                                  Structures.mqh   |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     All data structure definitions                |
//+------------------------------------------------------------------+

#ifndef __STRUCTURES_MQH__
#define __STRUCTURES_MQH__

#include "Enums.mqh"

//+------------------------------------------------------------------+
//| Market Structure Information                                     |
//| Stores swing points and structural state for one timeframe       |
//+------------------------------------------------------------------+
struct MarketStructure
{
   // Swing Points
   double  lastHigh;        // Most recent swing high
   double  lastLow;         // Most recent swing low
   double  prevHigh;        // Previous swing high (one before last)
   double  prevLow;         // Previous swing low (one before last)

   // State Information
   ENUM_STRUCTURE_STATE  state;  // Current trend: NEUTRAL, UPTREND, DOWNTREND

   // Structural Events
   bool  hasBOS;            // Break of Structure detected on last update
   bool  hasCHOCH;          // Change of Character detected on last update

   // Metadata
   datetime lastUpdateTime; // When this structure was last updated
   int    lastUpdateBar;    // Bar index when updated

   // Constructor
   MarketStructure()
   {
      ResetStructure();
   }

   // Method to reset all fields to default
   void ResetStructure()
   {
      lastHigh = 0;
      lastLow = 0;
      prevHigh = 0;
      prevLow = 0;
      state = STATE_NEUTRAL;
      hasBOS = false;
      hasCHOCH = false;
      lastUpdateTime = 0;
      lastUpdateBar = 0;
   }
};

//+------------------------------------------------------------------+
//| Fair Value Gap Information                                       |
//| Stores data about a detected FVG pattern                         |
//+------------------------------------------------------------------+
struct FVGInfo
{
   // Zone Boundaries
   double  topPrice;        // Upper boundary of FVG zone
   double  bottomPrice;     // Lower boundary of FVG zone

   // Direction
   ENUM_FVG_DIRECTION direction;  // BULLISH (demand) or BEARISH (supply)

   // Status
   bool  isFilled;          // Whether price has already filled this FVG

   // Metadata
   datetime detectTime;     // When FVG was detected
   int    detectBar;        // Bar index when detected
   int    ageInBars;        // How many bars old is this FVG

   // Chart Object
   string objectName;       // Name of rectangle object on chart

   // Constructor
   FVGInfo()
   {
      topPrice = 0;
      bottomPrice = 0;
      direction = FVG_BULLISH;
      isFilled = false;
      detectTime = 0;
      detectBar = 0;
      ageInBars = 0;
      objectName = "";
   }
};

//+------------------------------------------------------------------+
//| Order Block Information                                          |
//| Stores data about a detected Order Block pattern                 |
//+------------------------------------------------------------------+
struct OrderBlockInfo
{
   // Zone Boundaries
   double  highPrice;       // High of the order block candle
   double  lowPrice;        // Low of the order block candle

   // Direction
   ENUM_OB_DIRECTION direction;   // BULLISH (support) or BEARISH (resistance)

   // Status
   bool  isBreached;        // Whether price has broken through this OB

   // Metadata
   datetime detectTime;     // When OB was detected
   int    detectBar;        // Bar index when detected
   int    ageInBars;        // How many bars old is this OB

   // Chart Object
   string objectName;       // Name of rectangle object on chart

   // Constructor
   OrderBlockInfo()
   {
      highPrice = 0;
      lowPrice = 0;
      direction = OB_BULLISH;
      isBreached = false;
      detectTime = 0;
      detectBar = 0;
      ageInBars = 0;
      objectName = "";
   }
};

//+------------------------------------------------------------------+
//| Trade Setup Information                                          |
//| Calculated trade parameters ready for execution                  |
//+------------------------------------------------------------------+
struct TradeSetup
{
   // Entry Details
   bool   isValid;          // Whether this setup passed all validations
   bool   isBuy;            // TRUE = Buy, FALSE = Sell
   double entryPrice;       // Entry price (Ask for buy, Bid for sell)

   // Stop Loss & Take Profit
   double stopLoss;         // Stop loss level
   double takeProfit;       // Take profit level
   double stopLossPoints;   // Distance in points from entry
   double takeProfitPoints; // Distance in points from entry
   double riskRewardRatio;  // TP distance / SL distance

   // Position Sizing
   double lotSize;          // Number of lots to open
   double riskAmount;       // USD amount at risk

   // Signal Information
   ENUM_SIGNAL_TYPE signal;       // What signal triggered this trade
   string reason;           // Detailed reason string for trade

   // Validation
   bool   spreadAcceptable; // Spread check passed
   bool   stopsValidated;   // Broker stop requirements met

   // Metadata
   datetime setupTime;      // When this trade was set up

   // Constructor
   TradeSetup()
   {
      ResetSetup();
   }

   // Method to reset to default
   void ResetSetup()
   {
      isValid = false;
      isBuy = true;
      entryPrice = 0;
      stopLoss = 0;
      takeProfit = 0;
      stopLossPoints = 0;
      takeProfitPoints = 0;
      riskRewardRatio = 0;
      lotSize = 0;
      riskAmount = 0;
      signal = SIGNAL_NONE;
      reason = "";
      spreadAcceptable = false;
      stopsValidated = false;
      setupTime = 0;
   }
};

//+------------------------------------------------------------------+
//| Daily Statistics Information                                     |
//| Tracks trading performance across a trading day                  |
//+------------------------------------------------------------------+
struct DailyStats
{
   // Profit Tracking
   double closedProfit;     // Profit/Loss from closed trades today (USD)
   double floatingProfit;   // Profit/Loss from open positions (USD)

   // Trade Counting
   int    tradeCount;       // Total number of trades opened today
   int    winCount;         // Number of winning trades today
   int    lossCount;        // Number of losing trades today

   // Timing
   datetime lastResetDate;  // Timestamp of last daily reset
   int    lastResetBar;     // Bar index when stats were last reset

   // Limits & Thresholds
   int    maxDailyTrades;   // Maximum trades allowed per day
   double maxDailyLoss;     // Maximum loss allowed per day (points)

   // Calculated Fields
   double totalPnL;         // closedProfit + floatingProfit
   double winRate;          // winCount / tradeCount (percentage)

   // Constructor
   DailyStats()
   {
      ResetStats();
   }

   // Method to reset stats to zero
   void ResetStats()
   {
      closedProfit = 0;
      floatingProfit = 0;
      tradeCount = 0;
      winCount = 0;
      lossCount = 0;
      lastResetDate = 0;
      lastResetBar = 0;
      maxDailyTrades = 0;
      maxDailyLoss = 0;
      totalPnL = 0;
      winRate = 0;
   }

   // Method to calculate total P&L
   void UpdateTotalPnL()
   {
      totalPnL = closedProfit + floatingProfit;
   }

   // Method to calculate win rate
   void UpdateWinRate()
   {
      if(tradeCount > 0)
         winRate = (double)winCount / (double)tradeCount * 100.0;
      else
         winRate = 0;
   }
};

//+------------------------------------------------------------------+
//| Position Tracking Information                                    |
//| Tracks state of individual open positions                        |
//+------------------------------------------------------------------+
struct PositionInfo
{
   // Position Identification
   ulong  ticket;           // Position ticket number
   bool   isBuy;            // TRUE = Buy, FALSE = Sell

   // Entry Details
   double entryPrice;       // Entry price
   double currentPrice;     // Current market price

   // Stop Loss & Take Profit
   double stopLoss;         // Current stop loss level
   double takeProfit;       // Current take profit level

   // Volume
   double volume;           // Current position volume (lots)
   double volumeInitial;    // Initial volume when opened

   // Profit Tracking
   double profit;           // Current profit/loss (USD)
   double profitPoints;     // Current profit/loss (points)
   bool   isPartialClosed;  // Whether partial close has been applied

   // Signal Information
   ENUM_SIGNAL_TYPE signal; // Signal that opened this position
   string openReason;       // Reason for opening

   // Metadata
   datetime openTime;       // When position was opened

   // Constructor
   PositionInfo()
   {
      ResetInfo();
   }

   // Method to reset
   void ResetInfo()
   {
      ticket = 0;
      isBuy = true;
      entryPrice = 0;
      currentPrice = 0;
      stopLoss = 0;
      takeProfit = 0;
      volume = 0;
      volumeInitial = 0;
      profit = 0;
      profitPoints = 0;
      isPartialClosed = false;
      signal = SIGNAL_NONE;
      openReason = "";
      openTime = 0;
   }
};

#endif // __STRUCTURES_MQH__
