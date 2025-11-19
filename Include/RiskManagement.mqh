//+------------------------------------------------------------------+
//|                                            RiskManagement.mqh    |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     Risk Management & Daily Limits System         |
//+------------------------------------------------------------------+

#ifndef __RISK_MANAGEMENT_MQH__
#define __RISK_MANAGEMENT_MQH__

//+------------------------------------------------------------------+
//| CheckAndResetDailyStats: Check Daily Boundary and Reset if Needed|
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Checks if it's a new trading day and resets stats   |
//|              if needed. Uses 00:00 (midnight) as daily boundary. |
//+------------------------------------------------------------------+
void CheckAndResetDailyStats()
{
   datetime now = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(now, timeStruct);

   // Build today's date key
   string todayKey = IntegerToString(timeStruct.year) +
                     IntegerToString(timeStruct.mon) +
                     IntegerToString(timeStruct.day);

   // Get last reset date
   string lastResetKey = "";
   if(stats.lastResetDate > 0)
   {
      MqlDateTime lastResetStruct;
      TimeToStruct(stats.lastResetDate, lastResetStruct);
      lastResetKey = IntegerToString(lastResetStruct.year) +
                     IntegerToString(lastResetStruct.mon) +
                     IntegerToString(lastResetStruct.day);
   }

   // Reset if new day
   if(lastResetKey != todayKey)
   {
      ResetDailyStats();
   }
}

//+------------------------------------------------------------------+
//| ResetDailyStats: Reset Daily Statistics to Zero                |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Calculates and stores today's closed profit, then   |
//|              resets counters. Called once per day at midnight.   |
//|              Runs cleanup of aged patterns (FVGs, OBs).          |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
   // Calculate today's closed profit from deal history
   stats.closedProfit = CalculateTodayClosedProfit();

   // Reset floating profit (will be recalculated on each tick)
   stats.floatingProfit = 0;

   // Count today's trades from deal history
   stats.tradeCount = CountTodayTrades();

   // Reset win/loss counts
   stats.winCount = 0;
   stats.lossCount = 0;

   // Update reset timestamp
   stats.lastResetDate = TimeCurrent();
   stats.lastResetBar = (int)SeriesInfoInteger(_Symbol, cachedLTF, SERIES_LASTBAR_INDEX);

   // Cleanup old patterns
   CleanupOldFVGs();
   CleanupOldOrderBlocks();

   // Save stats
   SaveDailyStats();

   if(debugMode)
      Print("[RESET] Daily stats reset | Closed Profit: ", stats.closedProfit,
            " | Trade Count: ", stats.tradeCount);
}

//+------------------------------------------------------------------+
//| UpdateFloatingPNL: Calculate Floating Profit/Loss               |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Sums profit from all open positions with EA's magic |
//|              Updates stats.floatingProfit                        |
//+------------------------------------------------------------------+
void UpdateFloatingPNL()
{
   stats.floatingProfit = 0;

   // Loop all positions
   int totalPositions = PositionsTotal();

   for(int i = 0; i < totalPositions; i++)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i)))
         continue;

      // Filter by symbol and magic
      if(PositionGetSymbol() != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != EA_MAGIC_NUMBER)
         continue;

      // Add position profit to floating total
      stats.floatingProfit += PositionGetDouble(POSITION_PROFIT);
   }
}

//+------------------------------------------------------------------+
//| CalculateTodayClosedProfit: Sum Closed Profit from Deal History|
//| Parameters: None                                                 |
//| Returns: Total profit/loss from all deals closed today           |
//| Description: Scans deal history and sums profit from all deals   |
//|              that were opened and closed on the current day.     |
//+------------------------------------------------------------------+
double CalculateTodayClosedProfit()
{
   double totalProfit = 0;

   // Get today's date
   datetime now = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(now, timeStruct);

   // Create midnight today
   MqlDateTime midnightStruct;
   midnightStruct = timeStruct;
   midnightStruct.hour = 0;
   midnightStruct.min = 0;
   midnightStruct.sec = 0;
   datetime midnightToday = StructToTime(midnightStruct);

   // Loop history deals
   int totalDeals = HistoryDealsTotal();

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      // Check if deal is from today
      datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(dealTime < midnightToday)
         continue;

      // Check if deal belongs to this EA
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != EA_MAGIC_NUMBER)
         continue;

      // Check if deal is from this symbol
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;

      // Add profit if deal is closed (DEAL_TYPE_BUY or DEAL_TYPE_SELL)
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT ||
         HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_INOUT)
      {
         double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         totalProfit += dealProfit;
      }
   }

   return totalProfit;
}

//+------------------------------------------------------------------+
//| CountTodayTrades: Count Entry Trades from Today                |
//| Parameters: None                                                 |
//| Returns: Number of trades (deal entries) opened today            |
//| Description: Counts DEAL_ENTRY_IN deals from today's date.       |
//|              Used to enforce MaxDailyTrades limit.               |
//+------------------------------------------------------------------+
int CountTodayTrades()
{
   int tradeCount = 0;

   // Get today's date
   datetime now = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(now, timeStruct);

   // Create midnight today
   MqlDateTime midnightStruct;
   midnightStruct = timeStruct;
   midnightStruct.hour = 0;
   midnightStruct.min = 0;
   midnightStruct.sec = 0;
   datetime midnightToday = StructToTime(midnightStruct);

   // Loop history deals
   int totalDeals = HistoryDealsTotal();

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      // Check if deal is from today
      datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(dealTime < midnightToday)
         continue;

      // Check if deal belongs to this EA
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != EA_MAGIC_NUMBER)
         continue;

      // Check if deal is from this symbol
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;

      // Count entry deals (DEAL_ENTRY_IN)
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
      {
         tradeCount++;
      }
   }

   return tradeCount;
}

//+------------------------------------------------------------------+
//| SaveDailyStats: Persist Stats to GlobalVariables               |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Saves daily statistics to GlobalVariables so they   |
//|              persist across EA restarts and recompiles.          |
//+------------------------------------------------------------------+
void SaveDailyStats()
{
   // Build unique prefix key
   string prefix = GLOBAL_VAR_PREFIX + _Symbol + "_";

   // Save each stat
   GlobalVariableSet(prefix + STATS_CLOSED_PROFIT, stats.closedProfit);
   GlobalVariableSet(prefix + STATS_FLOATING_PROFIT, stats.floatingProfit);
   GlobalVariableSet(prefix + STATS_TRADE_COUNT, stats.tradeCount);
   GlobalVariableSet(prefix + STATS_WIN_COUNT, stats.winCount);
   GlobalVariableSet(prefix + STATS_LOSS_COUNT, stats.lossCount);
   GlobalVariableSet(prefix + STATS_LAST_RESET, (double)stats.lastResetDate);

   if(debugMode)
      Print("[SAVE_STATS] Saved to GlobalVariables | Prefix: ", prefix);
}

//+------------------------------------------------------------------+
//| LoadDailyStats: Load Stats from GlobalVariables                |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Loads daily statistics from GlobalVariables on     |
//|              EA startup. If GlobalVariables don't exist, starts   |
//|              with fresh stats.                                   |
//+------------------------------------------------------------------+
void LoadDailyStats()
{
   // Build unique prefix key
   string prefix = GLOBAL_VAR_PREFIX + _Symbol + "_";

   // Try to load each stat
   double value;

   if(GlobalVariableGet(prefix + STATS_CLOSED_PROFIT, value))
      stats.closedProfit = value;
   else
      stats.closedProfit = 0;

   if(GlobalVariableGet(prefix + STATS_FLOATING_PROFIT, value))
      stats.floatingProfit = value;
   else
      stats.floatingProfit = 0;

   if(GlobalVariableGet(prefix + STATS_TRADE_COUNT, value))
      stats.tradeCount = (int)value;
   else
      stats.tradeCount = 0;

   if(GlobalVariableGet(prefix + STATS_WIN_COUNT, value))
      stats.winCount = (int)value;
   else
      stats.winCount = 0;

   if(GlobalVariableGet(prefix + STATS_LOSS_COUNT, value))
      stats.lossCount = (int)value;
   else
      stats.lossCount = 0;

   if(GlobalVariableGet(prefix + STATS_LAST_RESET, value))
      stats.lastResetDate = (datetime)value;
   else
      stats.lastResetDate = 0;

   if(debugMode)
      Print("[LOAD_STATS] Loaded from GlobalVariables",
            " | Closed Profit: ", stats.closedProfit,
            " | Trades: ", stats.tradeCount);
}

#endif // __RISK_MANAGEMENT_MQH__
