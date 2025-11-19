//+------------------------------------------------------------------+
//|                                         PositionManagement.mqh   |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     Position Management & Profit Protection       |
//+------------------------------------------------------------------+

#ifndef __POSITION_MANAGEMENT_MQH__
#define __POSITION_MANAGEMENT_MQH__

//+------------------------------------------------------------------+
//| ManagePositions: Main Position Management Loop                  |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Iterates through all open positions and applies    |
//|              protection strategies in order:                     |
//|              1. Breakeven - move SL to entry after profit        |
//|              2. Trailing - dynamically trail SL with price       |
//|              3. Partial Close - lock profits at milestones       |
//+------------------------------------------------------------------+
void ManagePositions()
{
   // Iterate through all positions
   int totalPositions = PositionsTotal();

   for(int i = totalPositions - 1; i >= 0; i--)
   {
      // Select position
      if(!PositionSelectByTicket(PositionGetTicket(i)))
         continue;

      // Filter by symbol and magic
      if(PositionGetSymbol() != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != EA_MAGIC_NUMBER)
         continue;

      // Get position details
      ulong ticket = PositionGetTicket(i);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = (type == POSITION_TYPE_BUY) ?
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      double profit = PositionGetDouble(POSITION_PROFIT);

      // Calculate profit in points
      double profitPoints = profit / (SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * PositionGetDouble(POSITION_VOLUME));

      // Apply management rules in order
      // 1. Breakeven
      if(EnableBreakeven && profitPoints >= BreakevenPoints)
      {
         bool isBuy = (type == POSITION_TYPE_BUY);
         ApplyBreakeven(ticket, isBuy, openPrice, stopLoss);
      }

      // 2. Trailing Stop
      if(EnableTrailing && profitPoints >= TrailingStartPoints)
      {
         bool isBuy = (type == POSITION_TYPE_BUY);
         ApplyTrailing(ticket, isBuy, currentPrice, stopLoss);
      }

      // 3. Partial Close
      if(EnablePartialClose && profitPoints >= PartialClosePoints)
      {
         bool isBuy = (type == POSITION_TYPE_BUY);
         ApplyPartialClose(ticket, isBuy);
      }
   }
}

//+------------------------------------------------------------------+
//| ApplyBreakeven: Move Stop Loss to Entry + Buffer                |
//| Parameters:                                                      |
//|   ticket - Position ticket number                                |
//|   isBuy - true for BUY position, false for SELL                  |
//|   openPrice - Position entry price                               |
//|   currentSL - Current stop loss (modified by reference)          |
//| Returns: void                                                    |
//| Description: Once position reaches BreakevenPoints profit,       |
//|              moves stop loss to entry price + buffer to protect  |
//|              capital and lock in gains.                          |
//+------------------------------------------------------------------+
void ApplyBreakeven(ulong ticket, bool isBuy, double openPrice, double &currentSL)
{
   // Check if already at breakeven
   if(isBuy && currentSL >= openPrice - (BreakevenBuffer * _Point))
      return;
   if(!isBuy && currentSL <= openPrice + (BreakevenBuffer * _Point))
      return;

   // Calculate new SL
   double newSL;
   if(isBuy)
      newSL = openPrice - (BreakevenBuffer * _Point);
   else
      newSL = openPrice + (BreakevenBuffer * _Point);

   // Only update if new SL is better
   bool shouldUpdate = false;
   if(isBuy && newSL > currentSL)
      shouldUpdate = true;
   if(!isBuy && newSL < currentSL)
      shouldUpdate = true;

   if(shouldUpdate)
   {
      // Modify position
      if(trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
      {
         if(debugMode)
            Print("[BREAKEVEN] Applied | Ticket: ", ticket,
                  " | New SL: ", newSL);
      }
   }
}

//+------------------------------------------------------------------+
//| ApplyTrailing: Implement Dynamic Trailing Stop                  |
//| Parameters:                                                      |
//|   ticket - Position ticket number                                |
//|   isBuy - true for BUY position, false for SELL                  |
//|   currentPrice - Current market price                            |
//|   currentSL - Current stop loss (modified by reference)          |
//| Returns: void                                                    |
//| Description: Once position reaches TrailingStartPoints profit,   |
//|              trailing stop activates. SL moves with price but    |
//|              never moves backwards (closer to current price).    |
//|              Helps lock in profits during strong trends.         |
//+------------------------------------------------------------------+
void ApplyTrailing(ulong ticket, bool isBuy, double currentPrice, double &currentSL)
{
   // Calculate new SL based on trailing step
   double newSL;

   if(isBuy)
   {
      // For BUY: new SL = current price - trailing step
      newSL = currentPrice - (TrailingStepPoints * _Point);

      // Only update if new SL is better (higher) than current
      if(newSL > currentSL)
      {
         // Verify new SL is still profitable (above entry)
         if(trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
         {
            if(debugMode)
               Print("[TRAILING] Applied | Ticket: ", ticket,
                     " | New SL: ", newSL,
                     " | Current Price: ", currentPrice);
         }
      }
   }
   else
   {
      // For SELL: new SL = current price + trailing step
      newSL = currentPrice + (TrailingStepPoints * _Point);

      // Only update if new SL is better (lower) than current
      if(newSL < currentSL)
      {
         // Verify new SL is still profitable (below entry)
         if(trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
         {
            if(debugMode)
               Print("[TRAILING] Applied | Ticket: ", ticket,
                     " | New SL: ", newSL,
                     " | Current Price: ", currentPrice);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ApplyPartialClose: Close Partial Position at Profit Milestone   |
//| Parameters:                                                      |
//|   ticket - Position ticket number                                |
//|   isBuy - true for BUY position, false for SELL                  |
//| Returns: void                                                    |
//| Description: Once position reaches PartialClosePoints profit,    |
//|              closes a portion (PartialClosePercent) of position   |
//|              to lock in guaranteed profit while keeping          |
//|              remainder exposed for additional upside.            |
//+------------------------------------------------------------------+
void ApplyPartialClose(ulong ticket, bool isBuy)
{
   // Check if already partially closed
   if(PositionGetDouble(POSITION_VOLUME) <= 0)
      return;

   // Get current volume
   double currentVolume = PositionGetDouble(POSITION_VOLUME);

   // Calculate volume to close
   double closeVolume = currentVolume * PartialClosePercent;

   // Get minimum lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   // Check if close volume is valid
   if(closeVolume < minLot)
      return;  // Volume too small to close

   // Close partial position
   if(trade.PositionClosePartial(ticket, (int)(closeVolume * 100)))
   {
      if(debugMode)
         Print("[PARTIAL_CLOSE] Applied | Ticket: ", ticket,
               " | Closed Volume: ", closeVolume,
               " | Remaining: ", currentVolume - closeVolume);
   }
}

#endif // __POSITION_MANAGEMENT_MQH__
