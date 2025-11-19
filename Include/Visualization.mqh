//+------------------------------------------------------------------+
//|                                             Visualization.mqh    |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     Display & Alert System                        |
//+------------------------------------------------------------------+

#ifndef __VISUALIZATION_MQH__
#define __VISUALIZATION_MQH__

//+------------------------------------------------------------------+
//| DrawStructureLines: Draw Market Structure on Chart              |
//| Parameters:                                                      |
//|   tf - Timeframe being displayed                                 |
//|   structure - Structure object containing swing points           |
//| Returns: void                                                    |
//| Description: Draws horizontal lines at swing high/low levels.    |
//|              Last levels are solid, previous levels are dashed.  |
//+------------------------------------------------------------------+
void DrawStructureLines(ENUM_TIMEFRAMES tf, MarketStructure &structure)
{
   if(!ShowStructure)
      return;

   string tfStr = TimeframeToString(tf);

   // Draw last high
   if(structure.lastHigh > 0)
   {
      string objName = OBJ_PREFIX_STRUCTURE + "LH_" + tfStr;
      ObjectCreate(0, objName, OBJ_HLINE, 0, 0, structure.lastHigh);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, COLOR_BULLISH);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, LINE_STYLE_STRUCTURE);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, LINE_WIDTH_STRUCTURE);
   }

   // Draw last low
   if(structure.lastLow > 0)
   {
      string objName = OBJ_PREFIX_STRUCTURE + "LL_" + tfStr;
      ObjectCreate(0, objName, OBJ_HLINE, 0, 0, structure.lastLow);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, COLOR_BEARISH);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, LINE_STYLE_STRUCTURE);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, LINE_WIDTH_STRUCTURE);
   }

   // Draw previous high (dashed)
   if(structure.prevHigh > 0)
   {
      string objName = OBJ_PREFIX_STRUCTURE + "PH_" + tfStr;
      ObjectCreate(0, objName, OBJ_HLINE, 0, 0, structure.prevHigh);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, COLOR_NEUTRAL);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, LINE_STYLE_PREVIOUS);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, LINE_WIDTH_PREVIOUS);
   }

   // Draw previous low (dashed)
   if(structure.prevLow > 0)
   {
      string objName = OBJ_PREFIX_STRUCTURE + "PL_" + tfStr;
      ObjectCreate(0, objName, OBJ_HLINE, 0, 0, structure.prevLow);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, COLOR_NEUTRAL);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, LINE_STYLE_PREVIOUS);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, LINE_WIDTH_PREVIOUS);
   }
}

//+------------------------------------------------------------------+
//| DrawFVGBox: Draw Fair Value Gap Zone on Chart                   |
//| Parameters:                                                      |
//|   fvg - FVGInfo structure with zone boundaries                   |
//| Returns: void                                                    |
//| Description: Creates a rectangle object representing FVG zone.   |
//|              Bullish FVG = green, Bearish FVG = red             |
//+------------------------------------------------------------------+
void DrawFVGBox(FVGInfo &fvg)
{
   if(!ShowFVG)
      return;

   // Create rectangle object
   datetime now = TimeCurrent();
   datetime future = now + 86400 * 30;  // 30 days in future

   ObjectCreate(0, fvg.objectName, OBJ_RECTANGLE, 0, now, fvg.topPrice, future, fvg.bottomPrice);

   // Set color based on direction
   color boxColor = (fvg.direction == FVG_BULLISH) ? FVGBullishColor : FVGBearishColor;

   ObjectSetInteger(0, fvg.objectName, OBJPROP_FILL, true);
   ObjectSetInteger(0, fvg.objectName, OBJPROP_COLOR, boxColor);
   ObjectSetInteger(0, fvg.objectName, OBJPROP_BACK, true);  // Behind price
}

//+------------------------------------------------------------------+
//| UpdateFVGBoxFilled: Change FVG Appearance When Filled           |
//| Parameters:                                                      |
//|   fvg - FVGInfo structure representing filled FVG                |
//| Returns: void                                                    |
//| Description: Changes FVG box style from solid to dotted when     |
//|              price fills the gap zone.                           |
//+------------------------------------------------------------------+
void UpdateFVGBoxFilled(FVGInfo &fvg)
{
   if(ObjectFind(0, fvg.objectName) >= 0)
   {
      // Change to dotted style
      ObjectSetInteger(0, fvg.objectName, OBJPROP_STYLE, STYLE_DOT);
   }
}

//+------------------------------------------------------------------+
//| DrawOrderBlock: Draw Order Block Zone on Chart                  |
//| Parameters:                                                      |
//|   ob - OrderBlockInfo structure with zone boundaries             |
//| Returns: void                                                    |
//| Description: Creates a rectangle object representing OB zone.    |
//|              Bullish OB = light blue, Bearish OB = light red     |
//+------------------------------------------------------------------+
void DrawOrderBlock(OrderBlockInfo &ob)
{
   if(!ShowOB)
      return;

   // Create rectangle object
   datetime now = TimeCurrent();
   datetime future = now + 86400 * 30;  // 30 days in future

   ObjectCreate(0, ob.objectName, OBJ_RECTANGLE, 0, now, ob.highPrice, future, ob.lowPrice);

   // Set color based on direction
   color boxColor = (ob.direction == OB_BULLISH) ? OBBullishColor : OBBearishColor;

   ObjectSetInteger(0, ob.objectName, OBJPROP_FILL, true);
   ObjectSetInteger(0, ob.objectName, OBJPROP_COLOR, boxColor);
   ObjectSetInteger(0, ob.objectName, OBJPROP_BACK, true);  // Behind price
}

//+------------------------------------------------------------------+
//| UpdateStatisticsPanel: Display EA Statistics on Chart           |
//| Parameters: None                                                 |
//| Returns: void                                                    |
//| Description: Builds and displays information panel with:         |
//|              - Session status & GMT time                         |
//|              - Market structure state (HTF/LTF)                  |
//|              - Pattern counts (FVGs, OBs)                        |
//|              - Daily statistics (trades, P&L, win rate)          |
//|              - Current spread                                    |
//+------------------------------------------------------------------+
void UpdateStatisticsPanel()
{
   if(!ShowPanel)
   {
      Comment("");
      return;
   }

   // Build info string
   string info = "";

   // 1. Header with version and time filter indicator
   info += "╔══════════════════════════════════════════════════╗\n";
   info += "║ SmartMoney_Pro v2.0 " + (EnableTimeFilter ? "🕐" : "🔓") + "\n";
   info += "╚══════════════════════════════════════════════════╝\n";
   info += "\n";

   // 2. Mode & Timeframes
   info += "MODE & TIMEFRAMES\n";
   info += "─────────────────────────────────────────────────\n";
   info += "Entry Method: " + EntryMethodToString(EntryMethod) + "\n";
   info += "HTF: " + TimeframeToString(cachedHTF) + " | LTF: " + TimeframeToString(cachedLTF) + "\n";
   info += "\n";

   // 3. Session Status (NEW in Phase 2)
   string sessionStr = GetCurrentSession();
   datetime gmtTime = GetGMTTime();

   info += "TRADING SESSION " + sessionStr + "\n";
   info += "─────────────────────────────────────────────────\n";
   info += "GMT Time: " + TimeToString(gmtTime, TIME_DATE | TIME_SECONDS) + "\n";
   info += "Trading: " + (IsTradingAllowed() ? "✓ ALLOWED" : "✗ BLOCKED") + "\n";
   info += "\n";

   // 4. Market Structure States
   string hsfStr = "";
   if(structureHTF.state == STATE_UPTREND)
      hsfStr = "UPTREND ↑";
   else if(structureHTF.state == STATE_DOWNTREND)
      hsfStr = "DOWNTREND ↓";
   else
      hsfStr = "NEUTRAL ◆";

   string ltfStr = "";
   if(structureLTF.state == STATE_UPTREND)
      ltfStr = "UPTREND ↑";
   else if(structureLTF.state == STATE_DOWNTREND)
      ltfStr = "DOWNTREND ↓";
   else
      ltfStr = "NEUTRAL ◆";

   info += "STRUCTURE STATE\n";
   info += "─────────────────────────────────────────────────\n";
   info += "HTF: " + hsfStr + "\n";
   info += "LTF: " + ltfStr + "\n";
   info += "\n";

   // 5. Pattern Counts
   info += "PATTERNS DETECTED\n";
   info += "─────────────────────────────────────────────────\n";
   info += "FVGs: " + IntegerToString(fvgCount) + " | Order Blocks: " + IntegerToString(obCount) + "\n";
   info += "\n";

   // 6. Daily Statistics
   stats.UpdateTotalPnL();
   stats.UpdateWinRate();

   info += "DAILY STATISTICS\n";
   info += "─────────────────────────────────────────────────\n";
   info += "Trades Today: " + IntegerToString(stats.tradeCount) + "/" + IntegerToString(MaxDailyTrades) + "\n";
   info += "Closed P&L: " + DoubleToString(stats.closedProfit, 2) + " USD\n";
   info += "Floating P&L: " + DoubleToString(stats.floatingProfit, 2) + " USD\n";
   info += "Total P&L: " + DoubleToString(stats.totalPnL, 2) + " USD\n";

   if(stats.tradeCount > 0)
   {
      info += "Win Rate: " + DoubleToString(stats.winRate, 1) + "% (" +
              IntegerToString(stats.winCount) + "W / " +
              IntegerToString(stats.lossCount) + "L)\n";
   }

   // 7. Spread
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spreadPoints = (ask - bid) / _Point;

   info += "\n";
   info += "MARKET CONDITIONS\n";
   info += "─────────────────────────────────────────────────\n";
   info += "Spread: " + DoubleToString(spreadPoints, 1) + " pips";
   if(spreadPoints <= MaxSpreadPoints)
      info += " ✓";
   else
      info += " ✗";
   info += "\n";

   // Display comment
   Comment(info);
}

//+------------------------------------------------------------------+
//| SendAlert: Send Alert Notification                              |
//| Parameters:                                                      |
//|   title - Alert title                                            |
//|   message - Alert message                                        |
//| Returns: void                                                    |
//| Description: Sends alert via multiple channels based on config.  |
//|              Supports: Alert popup, Email, Push notification, Sound|
//+------------------------------------------------------------------+
void SendAlert(string title, string message)
{
   if(!EnableAlerts)
      return;

   string fullMessage = "[" + EA_NAME + "] " + title + ": " + message;

   // Alert popup
   Alert(fullMessage);

   // Email notification
   if(EnableEmail)
   {
      SendMail(EA_NAME + " - " + title, fullMessage);
   }

   // Push notification
   if(EnablePush)
   {
      SendNotification(fullMessage);
   }

   // Sound notification
   if(EnableSound)
   {
      PlaySound("alert.wav");
   }

   // Print to log
   Print("[ALERT] " + fullMessage);
}

#endif // __VISUALIZATION_MQH__
