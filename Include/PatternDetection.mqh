//+------------------------------------------------------------------+
//|                                           PatternDetection.mqh   |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     FVG & Order Block Detection System            |
//+------------------------------------------------------------------+

#ifndef __PATTERN_DETECTION_MQH__
#define __PATTERN_DETECTION_MQH__

//+------------------------------------------------------------------+
//| DetectFVG: Fair Value Gap Detection                             |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Scans recent bars for Fair Value Gap (FVG) patterns.|
//|              FVG is a gap between candles that represents a      |
//|              liquidity zone where price tends to return.         |
//|                                                                  |
//| Bullish FVG: Gap below current price (between candle 1 and 3)   |
//|   Gap = Low[1] - High[3]                                         |
//|   If gap > MinFVGPips: Bullish FVG zone created                 |
//|                                                                  |
//| Bearish FVG: Gap above current price                            |
//|   Gap = Low[3] - High[1]                                         |
//|   If gap > MinFVGPips: Bearish FVG zone created                 |
//+------------------------------------------------------------------+
void DetectFVG()
{
   if(!EnableFVGDetection)
      return;

   // Copy OHLC data
   if(!CopyHigh(_Symbol, cachedLTF, 0, MAX_LOOKBACK_BARS, priceHigh))
      return;
   if(!CopyLow(_Symbol, cachedLTF, 0, MAX_LOOKBACK_BARS, priceLow))
      return;
   if(!CopyClose(_Symbol, cachedLTF, 0, MAX_LOOKBACK_BARS, priceClose))
      return;

   // Scan for bullish FVGs (gap formed by 3-candle pattern)
   // Pattern: Current bar closes above previous, then gap down happens
   for(int i = 3; i < 50; i++)  // Scan 50 bars
   {
      // Bullish FVG: Gap where Low[i] > High[i+2]
      // This creates a "gap up" that will be filled when price returns down
      double gap = priceLow[i - 1] - priceHigh[i];

      if(gap > MinFVGPips * _Point)
      {
         // Check if this FVG already exists
         bool exists = false;
         for(int j = 0; j < fvgCount; j++)
         {
            if(fvgArray[j].detectBar == i && fvgArray[j].direction == FVG_BULLISH)
            {
               exists = true;
               break;
            }
         }

         if(!exists && fvgCount < MAX_FVG_ARRAY_SIZE)
         {
            // Create new bullish FVG
            FVGInfo newFVG;
            newFVG.topPrice = priceLow[i - 1];
            newFVG.bottomPrice = priceHigh[i];
            newFVG.direction = FVG_BULLISH;  // Demand zone
            newFVG.isFilled = false;
            newFVG.detectTime = TimeCurrent();
            newFVG.detectBar = i;
            newFVG.ageInBars = 0;
            newFVG.objectName = OBJ_PREFIX_FVG + "BULL_" + IntegerToString(i);

            // Add to array
            fvgArray[fvgCount] = newFVG;
            fvgCount++;

            // Draw FVG box
            if(ShowFVG)
               DrawFVGBox(newFVG);

            // Send alert
            if(EnableAlerts && AlertOnSignal)
               SendAlert("FVG Detected", "Bullish Fair Value Gap");

            if(debugMode)
               Print("[FVG] Bullish FVG detected | Top: ", newFVG.topPrice,
                     " | Bottom: ", newFVG.bottomPrice,
                     " | Gap: ", gap);
         }
      }

      // Bearish FVG: Gap where High[i] < Low[i+2]
      // This creates a "gap down" that will be filled when price returns up
      gap = priceHigh[i - 1] - priceLow[i];

      if(gap > MinFVGPips * _Point)
      {
         // Check if this FVG already exists
         bool exists = false;
         for(int j = 0; j < fvgCount; j++)
         {
            if(fvgArray[j].detectBar == i && fvgArray[j].direction == FVG_BEARISH)
            {
               exists = true;
               break;
            }
         }

         if(!exists && fvgCount < MAX_FVG_ARRAY_SIZE)
         {
            // Create new bearish FVG
            FVGInfo newFVG;
            newFVG.topPrice = priceHigh[i - 1];
            newFVG.bottomPrice = priceLow[i];
            newFVG.direction = FVG_BEARISH;  // Supply zone
            newFVG.isFilled = false;
            newFVG.detectTime = TimeCurrent();
            newFVG.detectBar = i;
            newFVG.ageInBars = 0;
            newFVG.objectName = OBJ_PREFIX_FVG + "BEAR_" + IntegerToString(i);

            // Add to array
            fvgArray[fvgCount] = newFVG;
            fvgCount++;

            // Draw FVG box
            if(ShowFVG)
               DrawFVGBox(newFVG);

            // Send alert
            if(EnableAlerts && AlertOnSignal)
               SendAlert("FVG Detected", "Bearish Fair Value Gap");

            if(debugMode)
               Print("[FVG] Bearish FVG detected | Top: ", newFVG.topPrice,
                     " | Bottom: ", newFVG.bottomPrice,
                     " | Gap: ", gap);
         }
      }
   }

   // Check if FVGs have been filled
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   for(int i = 0; i < fvgCount; i++)
   {
      if(!fvgArray[i].isFilled)
      {
         if(fvgArray[i].direction == FVG_BULLISH)
         {
            // Bullish FVG filled when price returns to top
            if(currentBid >= fvgArray[i].topPrice)
            {
               fvgArray[i].isFilled = true;
               // Update visual to dotted style
               if(ShowFVG)
                  UpdateFVGBoxFilled(fvgArray[i]);

               if(debugMode)
                  Print("[FVG] Bullish FVG filled");
            }
         }
         else if(fvgArray[i].direction == FVG_BEARISH)
         {
            // Bearish FVG filled when price returns to bottom
            if(currentBid <= fvgArray[i].bottomPrice)
            {
               fvgArray[i].isFilled = true;
               // Update visual to dotted style
               if(ShowFVG)
                  UpdateFVGBoxFilled(fvgArray[i]);

               if(debugMode)
                  Print("[FVG] Bearish FVG filled");
            }
         }
      }
   }

   // Cleanup old FVGs
   CleanupOldFVGs();
}

//+------------------------------------------------------------------+
//| DetectOrderBlocks: Order Block Pattern Detection               |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Scans for Order Block patterns. An Order Block is  |
//|              the last candle before a reversal, representing     |
//|              where large institutions likely placed orders.      |
//|                                                                  |
//| Bullish OB: Strong bearish candle followed by bullish reversal |
//|   Pattern: Bearish candle (i), Bullish candle (i-1)            |
//|   OB Range: High/Low of the bullish candle                     |
//|                                                                  |
//| Bearish OB: Strong bullish candle followed by bearish reversal |
//|   Pattern: Bullish candle (i), Bearish candle (i-1)            |
//|   OB Range: High/Low of the bearish candle                     |
//+------------------------------------------------------------------+
void DetectOrderBlocks()
{
   if(!EnableOBDetection)
      return;

   // Copy OHLC data
   if(!CopyOpen(_Symbol, cachedLTF, 0, MAX_LOOKBACK_BARS, priceOpen))
      return;
   if(!CopyHigh(_Symbol, cachedLTF, 0, MAX_LOOKBACK_BARS, priceHigh))
      return;
   if(!CopyLow(_Symbol, cachedLTF, 0, MAX_LOOKBACK_BARS, priceLow))
      return;
   if(!CopyClose(_Symbol, cachedLTF, 0, MAX_LOOKBACK_BARS, priceClose))
      return;

   // Scan for bullish order blocks (bearish followed by bullish reversal)
   for(int i = 2; i < 15; i++)  // Scan 15 bars
   {
      // Bullish OB: Previous bar is bearish, current bar is bullish
      bool prevBearish = priceOpen[i] > priceClose[i];      // Previous bar closes down
      bool currBullish = priceOpen[i - 1] < priceClose[i - 1];  // Current bar closes up

      if(prevBearish && currBullish)
      {
         // Check minimum size
         double obSize = priceHigh[i - 1] - priceLow[i - 1];
         if(obSize > MinOBPips * _Point)
         {
            // Check if already exists
            bool exists = false;
            for(int j = 0; j < obCount; j++)
            {
               if(obArray[j].detectBar == (i - 1) && obArray[j].direction == OB_BULLISH)
               {
                  exists = true;
                  break;
               }
            }

            if(!exists && obCount < MAX_OB_ARRAY_SIZE)
            {
               // Create new bullish OB
               OrderBlockInfo newOB;
               newOB.highPrice = priceHigh[i - 1];
               newOB.lowPrice = priceLow[i - 1];
               newOB.direction = OB_BULLISH;  // Support zone
               newOB.isBreached = false;
               newOB.detectTime = TimeCurrent();
               newOB.detectBar = i - 1;
               newOB.ageInBars = 0;
               newOB.objectName = OBJ_PREFIX_OB + "BULL_" + IntegerToString(i);

               // Add to array
               obArray[obCount] = newOB;
               obCount++;

               // Draw OB box
               if(ShowOB)
                  DrawOrderBlock(newOB);

               // Send alert
               if(EnableAlerts && AlertOnSignal)
                  SendAlert("OB Detected", "Bullish Order Block");

               if(debugMode)
                  Print("[OB] Bullish OB detected | High: ", newOB.highPrice,
                        " | Low: ", newOB.lowPrice);
            }
         }
      }

      // Bearish OB: Previous bar is bullish, current bar is bearish
      prevBearish = priceOpen[i - 1] < priceClose[i - 1];    // Previous bar closes up
      currBullish = priceOpen[i] > priceClose[i];            // Current bar closes down

      if(!prevBearish && !currBullish)
      {
         // Check minimum size
         double obSize = priceHigh[i] - priceLow[i];
         if(obSize > MinOBPips * _Point)
         {
            // Check if already exists
            bool exists = false;
            for(int j = 0; j < obCount; j++)
            {
               if(obArray[j].detectBar == i && obArray[j].direction == OB_BEARISH)
               {
                  exists = true;
                  break;
               }
            }

            if(!exists && obCount < MAX_OB_ARRAY_SIZE)
            {
               // Create new bearish OB
               OrderBlockInfo newOB;
               newOB.highPrice = priceHigh[i];
               newOB.lowPrice = priceLow[i];
               newOB.direction = OB_BEARISH;  // Resistance zone
               newOB.isBreached = false;
               newOB.detectTime = TimeCurrent();
               newOB.detectBar = i;
               newOB.ageInBars = 0;
               newOB.objectName = OBJ_PREFIX_OB + "BEAR_" + IntegerToString(i);

               // Add to array
               obArray[obCount] = newOB;
               obCount++;

               // Draw OB box
               if(ShowOB)
                  DrawOrderBlock(newOB);

               // Send alert
               if(EnableAlerts && AlertOnSignal)
                  SendAlert("OB Detected", "Bearish Order Block");

               if(debugMode)
                  Print("[OB] Bearish OB detected | High: ", newOB.highPrice,
                        " | Low: ", newOB.lowPrice);
            }
         }
      }
   }

   // Cleanup old Order Blocks
   CleanupOldOrderBlocks();
}

//+------------------------------------------------------------------+
//| CleanupOldFVGs: Remove Aged Fair Value Gaps                    |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Removes FVGs older than MAX_PATTERN_AGE_BARS (200).|
//|              Also deletes associated chart objects.              |
//+------------------------------------------------------------------+
void CleanupOldFVGs()
{
   for(int i = 0; i < fvgCount; i++)
   {
      // Update age
      fvgArray[i].ageInBars++;

      // Remove if too old
      if(fvgArray[i].ageInBars > MAX_PATTERN_AGE_BARS)
      {
         // Delete chart object
         if(ObjectFind(0, fvgArray[i].objectName) >= 0)
            ObjectDelete(0, fvgArray[i].objectName);

         // Remove from array
         for(int j = i; j < fvgCount - 1; j++)
            fvgArray[j] = fvgArray[j + 1];

         fvgCount--;
         i--;

         if(debugMode)
            Print("[CLEANUP] FVG removed (age > ", MAX_PATTERN_AGE_BARS, " bars)");
      }
   }
}

//+------------------------------------------------------------------+
//| CleanupOldOrderBlocks: Remove Aged Order Blocks                |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Removes Order Blocks older than MAX_PATTERN_AGE_BARS|
//|              Also deletes associated chart objects.              |
//+------------------------------------------------------------------+
void CleanupOldOrderBlocks()
{
   for(int i = 0; i < obCount; i++)
   {
      // Update age
      obArray[i].ageInBars++;

      // Remove if too old
      if(obArray[i].ageInBars > MAX_PATTERN_AGE_BARS)
      {
         // Delete chart object
         if(ObjectFind(0, obArray[i].objectName) >= 0)
            ObjectDelete(0, obArray[i].objectName);

         // Remove from array
         for(int j = i; j < obCount - 1; j++)
            obArray[j] = obArray[j + 1];

         obCount--;
         i--;

         if(debugMode)
            Print("[CLEANUP] OB removed (age > ", MAX_PATTERN_AGE_BARS, " bars)");
      }
   }
}

#endif // __PATTERN_DETECTION_MQH__
