//+------------------------------------------------------------------+
//|                                              EntrySignals.mqh    |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     Entry Signal Generation System                |
//+------------------------------------------------------------------+

#ifndef __ENTRY_SIGNALS_MQH__
#define __ENTRY_SIGNALS_MQH__

//+------------------------------------------------------------------+
//| CheckEntrySignals: Main Signal Dispatcher                       |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Main function that checks all entry conditions and |
//|              routes to appropriate entry method. Dispatches based|
//|              on EntryMethod parameter.                           |
//|                                                                  |
//| Process:                                                         |
//| 1. Reset current trade setup                                    |
//| 2. Validate spread acceptability                                |
//| 3. Check HTF confirmation if required                           |
//| 4. Route to correct entry method based on EntryMethod enum      |
//| 5. Execute trade if setup is valid                              |
//+------------------------------------------------------------------+
void CheckEntrySignals()
{
   // Reset setup from previous bar
   currentSetup.ResetSetup();

   // Check if spread is acceptable before proceeding
   if(!IsSpreadAcceptable())
   {
      if(debugMode)
         Print("[SIGNALS] Spread too high, skipping entry checks");
      return;
   }

   // Check HTF confirmation if required
   if(RequireHTFConfirmation)
   {
      // HTF must be in uptrend for buy, downtrend for sell
      if(structureHTF.state == STATE_NEUTRAL)
      {
         if(debugMode)
            Print("[SIGNALS] HTF confirmation required but HTF is NEUTRAL");
         return;
      }
   }

   // Route to appropriate entry method
   switch(EntryMethod)
   {
      case ENTRY_BOS_IMMEDIATE:
         CheckBOSImmediate();
         break;

      case ENTRY_BOS_RETEST:
         CheckBOSRetest();
         break;

      case ENTRY_CHOCH_REVERSAL:
         CheckCHOCHReversal();
         break;

      case ENTRY_COMBINED:
         CheckCombinedSignals();
         break;

      default:
         Print("[ERROR] Unknown entry method: ", EntryMethod);
         return;
   }

   // If trade setup is valid, execute it
   if(currentSetup.isValid)
   {
      ExecuteTrade();
   }
}

//+------------------------------------------------------------------+
//| CheckBOSImmediate: Immediate BOS Entry Method                  |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Enters immediately when Break of Structure (BOS)   |
//|              is detected on LTF, with HTF confirmation.         |
//|              Stop Loss = Previous swing level                    |
//|              Take Profit = Risk x MinRiskRewardRatio             |
//+------------------------------------------------------------------+
void CheckBOSImmediate()
{
   // Must have BOS signal on LTF
   if(!structureLTF.hasBOS)
   {
      if(debugMode)
         Print("[BOS_IMM] No BOS signal on LTF");
      return;
   }

   // Determine direction based on LTF state
   if(structureLTF.state == STATE_UPTREND)
   {
      // Uptrend BOS = BUY signal
      // Verify HTF is also uptrend (if required)
      if(RequireHTFConfirmation && structureHTF.state != STATE_UPTREND)
      {
         if(debugMode)
            Print("[BOS_IMM] HTF not in uptrend, skipping buy");
         return;
      }

      SetupTrade(true, SIGNAL_BOS_BULL, "BOS Immediate Buy");
   }
   else if(structureLTF.state == STATE_DOWNTREND)
   {
      // Downtrend BOS = SELL signal
      // Verify HTF is also downtrend (if required)
      if(RequireHTFConfirmation && structureHTF.state != STATE_DOWNTREND)
      {
         if(debugMode)
            Print("[BOS_IMM] HTF not in downtrend, skipping sell");
         return;
      }

      SetupTrade(false, SIGNAL_BOS_BEAR, "BOS Immediate Sell");
   }

   // Reset BOS flag after entry signal
   structureLTF.hasBOS = false;
}

//+------------------------------------------------------------------+
//| CheckBOSRetest: BOS Retest Entry Method                         |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Waits for price to retest previous swing level     |
//|              after a BOS. Enters when price near retest level.   |
//|              More conservative than immediate entry.            |
//+------------------------------------------------------------------+
void CheckBOSRetest()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // In uptrend, look for retest of previous high
   if(structureLTF.state == STATE_UPTREND)
   {
      // Previous high is the retest level
      double retestLevel = structureLTF.prevHigh;
      double tolerance = RetestTolerance * _Point;

      // Check if price is near retest level (within tolerance)
      if(currentPrice >= retestLevel - tolerance &&
         currentPrice <= retestLevel + tolerance)
      {
         // HTF confirmation if required
         if(RequireHTFConfirmation && structureHTF.state != STATE_UPTREND)
            return;

         SetupTrade(true, SIGNAL_BOS_BULL, "BOS Retest Buy");
      }
   }
   // In downtrend, look for retest of previous low
   else if(structureLTF.state == STATE_DOWNTREND)
   {
      // Previous low is the retest level
      double retestLevel = structureLTF.prevLow;
      double tolerance = RetestTolerance * _Point;

      // Check if price is near retest level (within tolerance)
      if(currentPrice >= retestLevel - tolerance &&
         currentPrice <= retestLevel + tolerance)
      {
         // HTF confirmation if required
         if(RequireHTFConfirmation && structureHTF.state != STATE_DOWNTREND)
            return;

         SetupTrade(false, SIGNAL_BOS_BEAR, "BOS Retest Sell");
      }
   }
}

//+------------------------------------------------------------------+
//| CheckCHOCHReversal: Change of Character Reversal Entry         |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Enters when CHoCH (Change of Character) is detected |
//|              on LTF. CHoCH indicates trend reversal.             |
//|              Entry direction opposite to previous trend.        |
//+------------------------------------------------------------------+
void CheckCHOCHReversal()
{
   // Must have CHoCH signal on LTF
   if(!structureLTF.hasCHOCH)
   {
      if(debugMode)
         Print("[CHOCH] No CHoCH signal on LTF");
      return;
   }

   // CHoCH indicates trend change, so opposite direction
   if(structureLTF.state == STATE_UPTREND)
   {
      // Was downtrend, now uptrend = BUY
      SetupTrade(true, SIGNAL_CHOCH_BULL, "CHoCH Reversal Buy");
   }
   else if(structureLTF.state == STATE_DOWNTREND)
   {
      // Was uptrend, now downtrend = SELL
      SetupTrade(false, SIGNAL_CHOCH_BEAR, "CHoCH Reversal Sell");
   }

   // Reset CHoCH flag after entry signal
   structureLTF.hasCHOCH = false;
}

//+------------------------------------------------------------------+
//| CheckCombinedSignals: Multi-Signal Confirmation Entry          |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Requires multiple signals (BOS + FVG + OB) for    |
//|              higher probability entries. More conservative but   |
//|              stronger confirmation.                             |
//+------------------------------------------------------------------+
void CheckCombinedSignals()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Initialize signal counters
   int bullSignalCount = 0;
   int bearSignalCount = 0;
   string signalReason = "";

   // Check for BOS signals
   if(structureLTF.hasBOS)
   {
      if(structureLTF.state == STATE_UPTREND)
      {
         bullSignalCount++;
         signalReason += " BOS↑";
      }
      else if(structureLTF.state == STATE_DOWNTREND)
      {
         bearSignalCount++;
         signalReason += " BOS↓";
      }
   }

   // Check for CHoCH signals
   if(structureLTF.hasCHOCH)
   {
      if(structureLTF.state == STATE_UPTREND)
      {
         bullSignalCount++;
         signalReason += " CHoCH↑";
      }
      else if(structureLTF.state == STATE_DOWNTREND)
      {
         bearSignalCount++;
         signalReason += " CHoCH↓";
      }
   }

   // Check for FVG signals (if price near FVG)
   for(int i = 0; i < fvgCount; i++)
   {
      // Bullish FVG
      if(fvgArray[i].direction == FVG_BULLISH &&
         currentPrice >= fvgArray[i].bottomPrice &&
         currentPrice <= fvgArray[i].topPrice)
      {
         bullSignalCount++;
         signalReason += " FVG↑";
         break;
      }
      // Bearish FVG
      else if(fvgArray[i].direction == FVG_BEARISH &&
              currentPrice >= fvgArray[i].bottomPrice &&
              currentPrice <= fvgArray[i].topPrice)
      {
         bearSignalCount++;
         signalReason += " FVG↓";
         break;
      }
   }

   // Check for OB signals (if price near OB)
   for(int i = 0; i < obCount; i++)
   {
      // Bullish OB
      if(obArray[i].direction == OB_BULLISH &&
         currentPrice >= obArray[i].lowPrice &&
         currentPrice <= obArray[i].highPrice)
      {
         bullSignalCount++;
         signalReason += " OB↑";
         break;
      }
      // Bearish OB
      else if(obArray[i].direction == OB_BEARISH &&
              currentPrice >= obArray[i].lowPrice &&
              currentPrice <= obArray[i].highPrice)
      {
         bearSignalCount++;
         signalReason += " OB↓";
         break;
      }
   }

   // Apply HTF filter
   if(RequireHTFConfirmation)
   {
      if(bullSignalCount > 0 && structureHTF.state != STATE_UPTREND)
         bullSignalCount = 0;

      if(bearSignalCount > 0 && structureHTF.state != STATE_DOWNTREND)
         bearSignalCount = 0;
   }

   // Require at least 2 signals for combined entry
   if(bullSignalCount >= 2)
   {
      SetupTrade(true, SIGNAL_BOS_BULL, "Combined Signals (Bull):" + signalReason);
   }
   else if(bearSignalCount >= 2)
   {
      SetupTrade(false, SIGNAL_BOS_BEAR, "Combined Signals (Bear):" + signalReason);
   }

   // Reset flags
   structureLTF.hasBOS = false;
   structureLTF.hasCHOCH = false;
}

#endif // __ENTRY_SIGNALS_MQH__
