//+------------------------------------------------------------------+
//|                                         StructureDetection.mqh   |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     Market Structure & Swing Detection System     |
//+------------------------------------------------------------------+

#ifndef __STRUCTURE_DETECTION_MQH__
#define __STRUCTURE_DETECTION_MQH__

//+------------------------------------------------------------------+
//| UpdateMarketStructure: Main Structure Update Function           |
//| Parameters:                                                      |
//|   tf - Timeframe to update (HTF or LTF)                          |
//|   structure - MarketStructure object to populate                 |
//| Returns: void                                                    |
//| Description: Main function that detects swings and updates      |
//|              market structure. Routes to ZigZag or simple        |
//|              detection based on configuration.                   |
//+------------------------------------------------------------------+
void UpdateMarketStructure(ENUM_TIMEFRAMES tf, MarketStructure &structure)
{
   // Copy price data needed for analysis
   if(!CopyHigh(_Symbol, tf, 0, MAX_LOOKBACK_BARS, priceHigh))
   {
      Print("[ERROR] Failed to copy High prices | TF: ", tf);
      return;
   }

   if(!CopyLow(_Symbol, tf, 0, MAX_LOOKBACK_BARS, priceLow))
   {
      Print("[ERROR] Failed to copy Low prices | TF: ", tf);
      return;
   }

   // Choose detection method
   if(UseZigZag && (tf == cachedLTF) && handleZigZag != INVALID_HANDLE)
   {
      // Try ZigZag-based detection
      if(!UpdateStructureFromZigZag(structure))
      {
         // Fallback to simple detection if ZigZag fails
         if(debugMode)
            Print("[STRUCT] ZigZag detection failed, falling back to simple detection");
         DetectSwingsSimple(tf, structure);
      }
   }
   else
   {
      // Use simple fractal-based detection
      DetectSwingsSimple(tf, structure);
   }

   // Update metadata
   structure.lastUpdateTime = TimeCurrent();
   structure.lastUpdateBar = (int)SeriesInfoInteger(_Symbol, tf, SERIES_LASTBAR_INDEX);

   if(debugMode)
      Print("[STRUCT] Structure updated | TF: ", tf,
            " | Last High: ", structure.lastHigh,
            " | Last Low: ", structure.lastLow,
            " | State: ", structure.state);
}

//+------------------------------------------------------------------+
//| UpdateStructureFromZigZag: ZigZag-Based Structure Detection    |
//| Parameters:                                                      |
//|   structure - MarketStructure object to populate                 |
//| Returns: true if successful, false if ZigZag data unavailable   |
//| Description: Uses ZigZag indicator to identify swing points.    |
//|              More reliable than fractal detection but slower.    |
//|              Finds the last 2 swing highs and 2 swing lows.      |
//+------------------------------------------------------------------+
bool UpdateStructureFromZigZag(MarketStructure &structure)
{
   if(handleZigZag == INVALID_HANDLE)
      return false;

   // Copy ZigZag indicator buffer
   if(CopyBuffer(handleZigZag, 0, 0, MAX_LOOKBACK_BARS, zigZagBuffer) <= 0)
   {
      Print("[ERROR] Failed to copy ZigZag buffer");
      return false;
   }

   // Find swing points from ZigZag
   int swingHighCount = 0;
   int swingLowCount = 0;
   double tempHighs[5];    // Store last 5 highs
   double tempLows[5];     // Store last 5 lows
   int tempHighIdx[5];     // Index positions
   int tempLowIdx[5];

   ArrayInitialize(tempHighs, 0);
   ArrayInitialize(tempLows, 0);

   // Scan buffer for non-zero values (swing points)
   for(int i = 0; i < MAX_LOOKBACK_BARS - 1; i++)
   {
      if(zigZagBuffer[i] != 0)
      {
         // Determine if high or low based on next value
         if(i + 1 < MAX_LOOKBACK_BARS && zigZagBuffer[i + 1] != 0)
         {
            if(zigZagBuffer[i] > zigZagBuffer[i + 1])
            {
               // This is a high
               if(swingHighCount < 5)
               {
                  tempHighs[swingHighCount] = zigZagBuffer[i];
                  tempHighIdx[swingHighCount] = i;
                  swingHighCount++;
               }
            }
            else
            {
               // This is a low
               if(swingLowCount < 5)
               {
                  tempLows[swingLowCount] = zigZagBuffer[i];
                  tempLowIdx[swingLowCount] = i;
                  swingLowCount++;
               }
            }
         }
      }
   }

   // Verify we have at least 2 highs and 2 lows
   if(swingHighCount < 2 || swingLowCount < 2)
      return false;

   // Store last 2 highs (most recent and previous)
   double newHigh = tempHighs[swingHighCount - 1];
   double prevHigh = tempHighs[swingHighCount - 2];

   // Store last 2 lows
   double newLow = tempLows[swingLowCount - 1];
   double prevLow = tempLows[swingLowCount - 2];

   // Check if structure actually changed
   if(newHigh == structure.lastHigh && newLow == structure.lastLow)
   {
      return true;  // No change
   }

   // Update structure and process change
   structure.prevHigh = structure.lastHigh;
   structure.prevLow = structure.lastLow;
   structure.lastHigh = newHigh;
   structure.lastLow = newLow;

   // Process the structural change
   ProcessStructureChange(structure);

   // Draw structure lines on chart
   if(ShowStructure)
      DrawStructureLines(cachedLTF, structure);

   return true;
}

//+------------------------------------------------------------------+
//| DetectSwingsSimple: Fractal-Based Swing Detection              |
//| Parameters:                                                      |
//|   tf - Timeframe to analyze                                      |
//|   structure - MarketStructure object to populate                 |
//| Returns: void                                                    |
//| Description: Uses fractal pattern (higher high/high, lower low/l |
//|              for swing detection. Slower but works without ZigZag.|
//|              Scans up to 30 bars looking for valid swings.       |
//+------------------------------------------------------------------+
void DetectSwingsSimple(ENUM_TIMEFRAMES tf, MarketStructure &structure)
{
   // We need at least 3 bars for fractal pattern (current + 1 before + 1 after)
   int barsToCheck = 30;  // Look back 30 bars

   double lastHigh = 0;
   double lastLow = 0;
   int lastHighBar = 0;
   int lastLowBar = 0;

   // Scan for swing highs (fractal: H[i] > H[i-1] && H[i] > H[i+1])
   for(int i = 1; i < barsToCheck - 1; i++)
   {
      // Check for swing high (fractal pattern)
      if(priceHigh[i] > priceHigh[i - 1] && priceHigh[i] > priceHigh[i + 1])
      {
         if(lastHighBar == 0 || priceHigh[i] > lastHigh)
         {
            // New highest point found
            lastHigh = priceHigh[i];
            lastHighBar = i;
         }
      }
   }

   // Scan for swing lows (fractal: L[i] < L[i-1] && L[i] < L[i+1])
   for(int i = 1; i < barsToCheck - 1; i++)
   {
      // Check for swing low (fractal pattern)
      if(priceLow[i] < priceLow[i - 1] && priceLow[i] < priceLow[i + 1])
      {
         if(lastLowBar == 0 || priceLow[i] < lastLow)
         {
            // New lowest point found
            lastLow = priceLow[i];
            lastLowBar = i;
         }
      }
   }

   // Verify valid swings were found
   if(lastHigh == 0 || lastLow == 0)
      return;

   // Check if structure actually changed
   if(lastHigh == structure.lastHigh && lastLow == structure.lastLow)
      return;

   // Update structure with new values
   structure.prevHigh = structure.lastHigh;
   structure.prevLow = structure.lastLow;
   structure.lastHigh = lastHigh;
   structure.lastLow = lastLow;

   // Process the structural change
   ProcessStructureChange(structure);

   // Draw structure lines on chart
   if(ShowStructure)
      DrawStructureLines(tf, structure);

   if(debugMode)
      Print("[SWING_DETECT] Swing found | High: ", lastHigh,
            " | Low: ", lastLow,
            " | Age High: ", lastHighBar,
            " | Age Low: ", lastLowBar);
}

//+------------------------------------------------------------------+
//| ProcessStructureChange: Identify BOS and CHoCH Events          |
//| Parameters:                                                      |
//|   structure - MarketStructure with updated swing points         |
//| Returns: void                                                    |
//| Description: Analyzes change in swing points to identify Break  |
//|              of Structure (BOS) and Change of Character (CHoCH)  |
//|              events. These are key entry signals in SMC trading. |
//|                                                                  |
//| BOS (Break of Structure):                                        |
//|   Uptrend: New high > previous high = BOS ↑                     |
//|   Downtrend: New low < previous low = BOS ↓                    |
//|                                                                  |
//| CHoCH (Change of Character):                                    |
//|   Uptrend: New high < previous high = trend reversal = CHoCH ↓ |
//|   Downtrend: New low > previous low = trend reversal = CHoCH ↑ |
//+------------------------------------------------------------------+
void ProcessStructureChange(MarketStructure &structure)
{
   // Reset flags
   structure.hasBOS = false;
   structure.hasCHOCH = false;

   // Can't process if we don't have previous structure
   if(structure.prevHigh == 0 && structure.prevLow == 0)
   {
      // First detection, determine initial trend
      if(structure.lastHigh > structure.lastLow)
      {
         structure.state = STATE_UPTREND;
      }
      else
      {
         structure.state = STATE_DOWNTREND;
      }
      return;
   }

   // Determine current trend
   if(structure.state == STATE_UPTREND)
   {
      // In uptrend, new high > previous high = BOS ↑
      if(structure.lastHigh > structure.prevHigh)
      {
         structure.hasBOS = true;
         structure.state = STATE_UPTREND;

         if(EnableAlerts && AlertOnSignal)
            SendAlert("BOS Detected", "Break of Structure ↑ Confirmed");
      }
      // In uptrend, new high < previous high = CHoCH ↓
      else if(structure.lastHigh < structure.prevHigh)
      {
         structure.hasCHOCH = true;
         structure.state = STATE_DOWNTREND;  // Switch to downtrend

         if(EnableAlerts && AlertOnSignal)
            SendAlert("CHoCH Detected", "Change of Character ↓ (Trend Reversal)");
      }
   }
   else if(structure.state == STATE_DOWNTREND)
   {
      // In downtrend, new low < previous low = BOS ↓
      if(structure.lastLow < structure.prevLow)
      {
         structure.hasBOS = true;
         structure.state = STATE_DOWNTREND;

         if(EnableAlerts && AlertOnSignal)
            SendAlert("BOS Detected", "Break of Structure ↓ Confirmed");
      }
      // In downtrend, new low > previous low = CHoCH ↑
      else if(structure.lastLow > structure.prevLow)
      {
         structure.hasCHOCH = true;
         structure.state = STATE_UPTREND;  // Switch to uptrend

         if(EnableAlerts && AlertOnSignal)
            SendAlert("CHoCH Detected", "Change of Character ↑ (Trend Reversal)");
      }
   }

   if(debugMode)
   {
      string stateStr = "";
      if(structure.state == STATE_UPTREND)
         stateStr = "UPTREND ↑";
      else if(structure.state == STATE_DOWNTREND)
         stateStr = "DOWNTREND ↓";
      else
         stateStr = "NEUTRAL ◆";

      Print("[STRUCT_CHANGE] State: ", stateStr,
            " | BOS: ", (structure.hasBOS ? "YES" : "NO"),
            " | CHoCH: ", (structure.hasCHOCH ? "YES" : "NO"));
   }
}

#endif // __STRUCTURE_DETECTION_MQH__
