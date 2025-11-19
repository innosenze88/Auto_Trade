//+------------------------------------------------------------------+
//|                                            TradeManagement.mqh   |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     Trade Setup, Execution & Position Management  |
//+------------------------------------------------------------------+

#ifndef __TRADE_MANAGEMENT_MQH__
#define __TRADE_MANAGEMENT_MQH__

//+------------------------------------------------------------------+
//| IsSpreadAcceptable: Check if Current Spread is Acceptable       |
//| Parameters: None                                                 |
//| Returns: true if spread <= MaxSpreadPoints, false otherwise      |
//| Description: Validates that current bid-ask spread is within    |
//|              acceptable limits before executing trade.           |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Calculate spread in points
   double spreadPoints = (ask - bid) / _Point;

   if(spreadPoints > MaxSpreadPoints)
   {
      if(debugMode)
         Print("[SPREAD] Spread too high: ", spreadPoints, " > ", MaxSpreadPoints);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| SetupTrade: Calculate Trade Parameters (Entry, SL, TP, Lot Size)|
//| Parameters:                                                      |
//|   isBuy - true for BUY, false for SELL                           |
//|   signal - Signal type that triggered entry (SIGNAL_BOS_BULL, etc)|
//|   reason - Detailed reason string for trade                      |
//| Returns: void (populates currentSetup structure)                |
//| Description: Calculates all trade parameters including stop loss,|
//|              take profit, and lot size based on market structure |
//|              levels and risk management rules.                   |
//|                                                                  |
//| SL Calculation:                                                  |
//|   BUY: SL below last swing low (or ATR-based alternative)       |
//|   SELL: SL above last swing high (or ATR-based alternative)      |
//|                                                                  |
//| TP Calculation:                                                  |
//|   TP = Entry ± (SL_distance × MinRiskRewardRatio)               |
//|                                                                  |
//| Lot Sizing:                                                      |
//|   Risk-based: Risk% of balance divided by SL distance           |
//|   Fixed: Use FixedLotSize parameter                             |
//+------------------------------------------------------------------+
void SetupTrade(bool isBuy, ENUM_SIGNAL_TYPE signal, string reason)
{
   // Reset setup
   currentSetup.ResetSetup();

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // 1. Determine entry price
   if(isBuy)
      currentSetup.entryPrice = ask;  // Buy at Ask price
   else
      currentSetup.entryPrice = bid;  // Sell at Bid price

   // 2. Get ATR for alternative SL calculation
   if(CopyBuffer(handleATR, 0, 0, 1, atrBuffer) <= 0)
   {
      if(debugMode)
         Print("[SETUP] Failed to copy ATR");
      return;
   }

   double atrValue = atrBuffer[0];

   // 3. Calculate Stop Loss
   double stopLoss = 0;

   if(isBuy)
   {
      // For BUY: SL below entry
      // Use structure low or ATR-based
      if(structureLTF.lastLow > 0)
      {
         stopLoss = structureLTF.lastLow - (MinSLPoints * _Point);
      }
      else
      {
         // Fallback to ATR-based
         stopLoss = currentSetup.entryPrice - (2.0 * atrValue);
      }

      // Ensure minimum SL distance
      if((currentSetup.entryPrice - stopLoss) / _Point < MinSLPoints)
      {
         stopLoss = currentSetup.entryPrice - (MinSLPoints * _Point);
      }
   }
   else
   {
      // For SELL: SL above entry
      // Use structure high or ATR-based
      if(structureLTF.lastHigh > 0)
      {
         stopLoss = structureLTF.lastHigh + (MinSLPoints * _Point);
      }
      else
      {
         // Fallback to ATR-based
         stopLoss = currentSetup.entryPrice + (2.0 * atrValue);
      }

      // Ensure minimum SL distance
      if((stopLoss - currentSetup.entryPrice) / _Point < MinSLPoints)
      {
         stopLoss = currentSetup.entryPrice + (MinSLPoints * _Point);
      }
   }

   // 4. Calculate distance from entry to SL
   if(isBuy)
      currentSetup.stopLossPoints = (currentSetup.entryPrice - stopLoss) / _Point;
   else
      currentSetup.stopLossPoints = (stopLoss - currentSetup.entryPrice) / _Point;

   currentSetup.stopLoss = stopLoss;

   // 5. Calculate Take Profit
   double tpDistance = currentSetup.stopLossPoints * MinRiskRewardRatio;

   if(isBuy)
      currentSetup.takeProfit = currentSetup.entryPrice + (tpDistance * _Point);
   else
      currentSetup.takeProfit = currentSetup.entryPrice - (tpDistance * _Point);

   currentSetup.takeProfitPoints = tpDistance;
   currentSetup.riskRewardRatio = MinRiskRewardRatio;

   // 6. Validate stops against broker requirements
   ValidateStops(isBuy, currentSetup.entryPrice, currentSetup.stopLoss, currentSetup.takeProfit);

   // 7. Calculate lot size
   currentSetup.lotSize = CalculateLotSize(currentSetup.stopLossPoints);

   // 8. Validate R:R ratio is acceptable
   if(currentSetup.riskRewardRatio < MinRiskRewardRatio)
   {
      if(debugMode)
         Print("[SETUP] R:R too low: ", currentSetup.riskRewardRatio, " < ", MinRiskRewardRatio);
      return;
   }

   // 9. Mark setup as valid
   currentSetup.isValid = true;
   currentSetup.isBuy = isBuy;
   currentSetup.signal = signal;
   currentSetup.reason = reason;
   currentSetup.setupTime = TimeCurrent();
   currentSetup.spreadAcceptable = IsSpreadAcceptable();

   if(debugMode)
      Print("[SETUP] Trade setup complete | Direction: ", (isBuy ? "BUY" : "SELL"),
            " | Entry: ", currentSetup.entryPrice,
            " | SL: ", currentSetup.stopLoss,
            " | TP: ", currentSetup.takeProfit,
            " | Lot: ", currentSetup.lotSize);
}

//+------------------------------------------------------------------+
//| ValidateStops: Enforce Broker Stop Level Requirements           |
//| Parameters:                                                      |
//|   isBuy - true for BUY, false for SELL                           |
//|   entry - Entry price                                            |
//|   sl - Stop loss (modified by reference)                         |
//|   tp - Take profit (modified by reference)                       |
//| Returns: void                                                    |
//| Description: Adjusts SL/TP if they violate broker's minimum stop |
//|              distance requirements. Different brokers have       |
//|              different STOPS_LEVEL values (typically 5-20 pips). |
//+------------------------------------------------------------------+
void ValidateStops(bool isBuy, double entry, double &sl, double &tp)
{
   // Get broker's minimum stop distance
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   if(stopsLevel == 0)
   {
      // Some brokers don't enforce STOPS_LEVEL in MT5
      stopsLevel = 10;  // Default to 10 points
   }

   if(isBuy)
   {
      // For BUY, SL must be below entry
      double minSL = entry - (stopsLevel * _Point);
      if(sl > minSL)
      {
         sl = minSL;
         if(debugMode)
            Print("[VALIDATE] Adjusted SL (too close): ", sl);
      }

      // For BUY, TP must be above entry
      double minTP = entry + (stopsLevel * _Point);
      if(tp < minTP)
      {
         tp = minTP;
         if(debugMode)
            Print("[VALIDATE] Adjusted TP (too close): ", tp);
      }
   }
   else
   {
      // For SELL, SL must be above entry
      double minSL = entry + (stopsLevel * _Point);
      if(sl < minSL)
      {
         sl = minSL;
         if(debugMode)
            Print("[VALIDATE] Adjusted SL (too close): ", sl);
      }

      // For SELL, TP must be below entry
      double minTP = entry - (stopsLevel * _Point);
      if(tp > minTP)
      {
         tp = minTP;
         if(debugMode)
            Print("[VALIDATE] Adjusted TP (too close): ", tp);
      }
   }
}

//+------------------------------------------------------------------+
//| CalculateLotSize: Calculate Position Size Based on Risk        |
//| Parameters:                                                      |
//|   slPoints - Stop loss distance in points                        |
//| Returns: Calculated lot size (normalized to broker requirements) |
//| Description: Calculates lot size based on account risk settings. |
//|              Supports both fixed and risk-based sizing.          |
//|                                                                  |
//| Fixed Lot Sizing:                                               |
//|   If UseFixedLot = true: use FixedLotSize parameter             |
//|                                                                  |
//| Risk-Based Lot Sizing:                                          |
//|   1. Calculate risk amount: AccountBalance × RiskPercent        |
//|   2. Cap at MaxRiskPerTrade                                    |
//|   3. Calculate tick value from symbol                           |
//|   4. LotSize = RiskAmount / (SLPoints × TickValue)             |
//|   5. Normalize to broker's lot step (usually 0.01)              |
//+------------------------------------------------------------------+
double CalculateLotSize(double slPoints)
{
   // Use fixed lot size if configured
   if(UseFixedLot)
   {
      return NormalizeDouble(FixedLotSize,
                            (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) - 5);
   }

   // Risk-based lot sizing
   // 1. Calculate risk amount
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100.0);

   // 2. Cap at max risk per trade
   if(riskAmount > MaxRiskPerTrade)
      riskAmount = MaxRiskPerTrade;

   // 3. Get tick value from symbol
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   // 4. Calculate lot size
   // Formula: Lots = RiskAmount / (SLPoints in dollars)
   double slInDollars = slPoints * _Point * tickValue;

   if(slInDollars <= 0)
      return 0.01;  // Minimum lot

   double lotSize = riskAmount / slInDollars;

   // 5. Normalize to broker's lot step
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;

   // 6. Apply min/max constraints
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(lotSize < minLot)
      lotSize = minLot;
   if(lotSize > maxLot || lotSize > MaxLotSize)
      lotSize = MaxLotSize;

   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| ExecuteTrade: Send Buy/Sell Order                               |
//| Parameters: None (uses currentSetup structure)                   |
//| Returns: void                                                    |
//| Description: Executes the trade setup by sending order to broker |
//|              Handles both BUY and SELL orders with full SL/TP.   |
//|              Updates trade count and saves stats on success.     |
//+------------------------------------------------------------------+
void ExecuteTrade()
{
   // Verify setup is valid
   if(!currentSetup.isValid)
   {
      if(debugMode)
         Print("[EXECUTE] Trade setup is invalid, cannot execute");
      return;
   }

   // Re-check spread before execution
   if(!IsSpreadAcceptable())
   {
      if(debugMode)
         Print("[EXECUTE] Spread changed, aborting execution");
      return;
   }

   // Check if we already have an open position
   if(PositionSelect(_Symbol))
   {
      if(PositionGetInteger(POSITION_MAGIC) == EA_MAGIC_NUMBER)
      {
         if(debugMode)
            Print("[EXECUTE] Position already exists, cannot open new one");
         return;
      }
   }

   // Build trade comment
   string comment = EA_NAME + " | " + currentSetup.reason;

   // Execute trade
   bool result = false;

   if(currentSetup.isBuy)
   {
      result = trade.Buy(currentSetup.lotSize,
                        _Symbol,
                        currentSetup.entryPrice,
                        currentSetup.stopLoss,
                        currentSetup.takeProfit,
                        comment);
   }
   else
   {
      result = trade.Sell(currentSetup.lotSize,
                         _Symbol,
                         currentSetup.entryPrice,
                         currentSetup.stopLoss,
                         currentSetup.takeProfit,
                         comment);
   }

   // Handle result
   if(result)
   {
      // Trade executed successfully
      lastTicket = trade.ResultOrder();
      lastTradeTime = TimeCurrent();
      stats.tradeCount++;

      SaveDailyStats();

      Print("[EXECUTE] ✓ Trade executed successfully!");
      Print("  Type: ", (currentSetup.isBuy ? "BUY" : "SELL"),
            " | Ticket: ", lastTicket,
            " | Entry: ", currentSetup.entryPrice,
            " | SL: ", currentSetup.stopLoss,
            " | TP: ", currentSetup.takeProfit,
            " | Lots: ", currentSetup.lotSize);

      if(EnableAlerts && AlertOnEntry)
         SendAlert("Trade Opened", currentSetup.reason);
   }
   else
   {
      // Trade failed
      Print("[EXECUTE] ✗ Trade execution failed!");
      Print("  Error: ", trade.ResultRetcode(),
            " | Reason: ", trade.ResultRetcodeDescription());

      lastError = trade.ResultRetcodeDescription();
   }
}

#endif // __TRADE_MANAGEMENT_MQH__
