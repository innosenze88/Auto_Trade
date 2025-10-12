void DetectAndDrawOrderBlocks()
{
   static datetime lastDetect = 0;
   datetime lastBar = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   
   // Reset OB detection on new bar
   if(lastDetect != lastBar)
   {
      if(OB != NULL) 
      { 
         delete OB; 
         OB = NULL; 
      }
      lastDetect = lastBar;
   }
   
   // Only detect new OB if we don't have one already
   if(OB == NULL)
   {
      for(int i = 1; i < 100; i++)
      {
         // Bullish OB candidate
         if(getOpen(i) < getClose(i) && 
            getOpen(i+2) < getClose(i+2) &&
            getOpen(i+3) > getClose(i+3) && 
            getOpen(i+3) < getClose(i+2))
         {
            OB = new COrderBlock();
            OB.direction = 1;
            OB.time = getTimeBar(i+3);
            OB.high = getHigh(i+3);
            OB.low = getLow(i+3);
            OBClr = BullOB;
            T1 = OB.time;
            Print("Bullish Order Block detected at: ", TimeToString(OB.time));
            break;
         }
         
         // Bearish OB candidate
         if(getOpen(i) > getClose(i) && 
            getOpen(i+2) > getClose(i+2) &&
            getOpen(i+3) < getClose(i+3) && 
            getOpen(i+3) > getClose(i+2)) // Fixed condition
         {
            OB = new COrderBlock();
            OB.direction = -1;
            OB.time = getTimeBar(i+3);
            OB.high = getHigh(i+3);
            OB.low = getLow(i+3);
            OBClr = BearOB;
            T1 = OB.time;
            Print("Bearish Order Block detected at: ", TimeToString(OB.time));
            break;
         }
      }
   }

   if(OB == NULL) return;
   
   // Check if we already traded this OB
   if(lastTradedOBTime == OB.time) return;

   // If price retraces inside OB zone
   Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool inBullZone = (OB.direction > 0 && Ask <= OB.high && Ask >= OB.low);
   bool inBearZone = (OB.direction < 0 && Bid >= OB.low && Bid <= OB.high);

   if(!inBullZone && !inBearZone) return;

   // Use your DetectSwing function to find swings
   // We need to call it multiple times to find the most recent swings
   double mostRecentSwingHigh = 0;
   double mostRecentSwingLow = EMPTY_VALUE;
   datetime mostRecentSwingHighTime = 0;
   datetime mostRecentSwingLowTime = 0;
   
   // Scan recent bars to find the most recent swings
   for(int i = 0; i < 20; i++) // Check the last 20 bars
   {
      // Reset swing variables
      fib_high = 0;
      fib_low = 0;
      fib_t1 = 0;
      fib_t2 = 0;
      
      DetectSwingForBar(i, SWING_OB);
      
      if(fib_high > 0 && (mostRecentSwingHighTime == 0 || fib_t1 > mostRecentSwingHighTime))
      {
         mostRecentSwingHigh = fib_high;
         mostRecentSwingHighTime = fib_t1;
      }
      
      if(fib_low < EMPTY_VALUE && (mostRecentSwingLowTime == 0 || fib_t2 > mostRecentSwingLowTime))
      {
         mostRecentSwingLow = fib_low;
         mostRecentSwingLowTime = fib_t2;
      }
   }
   
   // Ensure we found both swing points
   if(mostRecentSwingHighTime == 0 || mostRecentSwingLowTime == 0) return;
   
   // Draw Fibonacci before trading to validate
   if(OB.direction > 0 && inBullZone)
   {
      // Draw Fibonacci from recent swing low to recent swing high
      ObjectDelete(0, "FIB_OB_BULL");
      if(ObjectCreate(0, "FIB_OB_BULL", OBJ_FIBO, 0, mostRecentSwingLowTime, mostRecentSwingLow, 
                     mostRecentSwingHighTime, mostRecentSwingHigh))
      {
         // Format Fibonacci
         ObjectSetInteger(0, "FIB_OB_BULL", OBJPROP_COLOR, clrBlack);
         for(int i = 0; i < ObjectGetInteger(0, "FIB_OB_BULL", OBJPROP_LEVELS); i++)
         {
            ObjectSetInteger(0, "FIB_OB_BULL", OBJPROP_LEVELCOLOR, i, clrBlack);
         }
         
         double entLvlBull = mostRecentSwingHigh - (mostRecentSwingHigh - mostRecentSwingLow) * (Fib_Trade_lvls / 100.0);
         
         if(Ask <= entLvlBull)
         {
            T2 = getTimeBar(0);
            OB.draw(T1, T2, BullOB);
            ExecuteTrade(ORDER_TYPE_BUY);
            lastTradedOBTime = OB.time; // Mark this OB as traded
            delete OB;
            OB = NULL;
         }
      }
   }
   else if(OB.direction < 0 && inBearZone)
   {
      // Draw Fibonacci from recent swing high to recent swing low
      ObjectDelete(0, "FIB_OB_BEAR");
      if(ObjectCreate(0, "FIB_OB_BEAR", OBJ_FIBO, 0, mostRecentSwingHighTime, mostRecentSwingHigh, 
                     mostRecentSwingLowTime, mostRecentSwingLow))
      {
         // Format Fibonacci
         ObjectSetInteger(0, "FIB_OB_BEAR", OBJPROP_COLOR, clrBlack);
         for(int i = 0; i < ObjectGetInteger(0, "FIB_OB_BEAR", OBJPROP_LEVELS); i++)
         {
            ObjectSetInteger(0, "FIB_OB_BEAR", OBJPROP_LEVELCOLOR, i, clrBlack);
         }
         
         double entLvlBear = mostRecentSwingLow + (mostRecentSwingHigh - mostRecentSwingLow) * (Fib_Trade_lvls / 100.0);
         
         if(Bid >= entLvlBear)
         {
            T2 = getTimeBar(0);
            OB.draw(T1, T2, BearOB);
            ExecuteTrade(ORDER_TYPE_SELL);
            lastTradedOBTime = OB.time; // Mark this OB as traded
            delete OB;
            OB = NULL;
         }
      }
   }
}

//============================== FVG ================================//
// Definition (ICT-style):
// Let C=i, B=i+1, A=i+2.
// Bullish FVG if Low(A) > High(C) -> gap [High(C), Low(A)]
// Bearish FVG if High(A) < Low(C) -> gap [High(A), Low(C)]
struct SFVG
{
   int      dir;    // +1 bull, -1 bear
   datetime tLeft;  // left time anchor
   double   top;    // zone top price
   double   bot;    // zone bottom price

   string Name() const
   {
      string k = TimeToString(tLeft, TIME_DATE|TIME_MINUTES);
      return (dir>0 ? "FVG_B_" : "FVG_S_") + k + "_" + IntegerToString((int)(top*1000.0));
   }
};

bool FVGExistsAt(const string &name){ return ObjectFind(0, name) != -1; }

void DetectAndDrawFVGs()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int counted = 0;

   for(int i=2; i<MathMin(FVG_ScanBars, Bars(_Symbol, _Period))-2; i++)
   {
      // Build A,B,C
      double lowA  = getLow(i+2);
      double highA = getHigh(i+2);
      double highC = getHigh(i);
      double lowC  = getLow(i);

      // Bullish FVG: Low of A > High of C
      if(lowA > highC && (lowA - highC >= FVG_MinPoints * point))
      {
         SFVG z;
         z.dir   = +1;
         z.tLeft = getTimeBar(i+2);  // Changed from getTimeBar to getTime
         z.top   = lowA;
         z.bot   = highC;
         DrawFVG(z);
         counted++;
      }
      // Bearish FVG: High of A < Low of C
      else if(highA < lowC && (lowC - highA >= FVG_MinPoints * point))
      {
         SFVG z;
         z.dir   = -1;
         z.tLeft = getTimeBar(i+2);  // Changed from getTimeBar to getTime
         z.top   = lowC;          // Fixed: should be lowC for bearish FVG top
         z.bot   = highA;         // Fixed: should be highA for bearish FVG bottom
         DrawFVG(z);
         counted++;
      }
      
      if(counted > 15) break; // avoid clutter
   }

   // --- Simplified trading for FVGs ---
   Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // scan drawn objects and trade on first valid touch of EQ (50%)
   int total = ObjectsTotal(0, 0, -1);
   static datetime lastTradeBar = 0;
   
   if(OneTradePerBar)
   {
      datetime barNow = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
      if(lastTradeBar == barNow) return; // already traded this bar
   }

   for(int idx=0; idx<total; idx++)
   {
      string name = ObjectName(0, idx);
      if(StringFind(name, "FVG_", 0) != 0) continue; // only our FVGs

      // Get object coordinates
      datetime t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
      double y1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      datetime t2 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
      double y2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);

      double top = MathMax(y1, y2);
      double bot = MathMin(y1, y2);
      bool isBull = (StringFind(name, "FVG_B_", 0) == 0);
      double mid  = (top + bot) * 0.5;

      if(isBull)
      {
         // trade when Ask is inside the gap and at/under EQ
         if(Ask <= top && Ask >= bot && (!FVG_TradeAtEQ || Ask <= mid))
         {
            ExecuteTrade(ORDER_TYPE_BUY);
            lastTradeBar = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
            break;
         }
      }
      else
      {
         // trade when Bid is inside the gap and at/over EQ
         if(Bid <= top && Bid >= bot && (!FVG_TradeAtEQ || Bid >= mid))
         {
            ExecuteTrade(ORDER_TYPE_SELL);
            lastTradeBar = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
            break;
         }
      }
   }
}
//=============================== BOS ===============================//
// Use unified swings (no RSI). Trading logic mirrors your earlier code:
// - Sell when price breaks above last swing high (liquidity run idea)
// - Buy  when price breaks below last swing low
void DetectAndDrawBOS()
{
   // Use DetectSwingForBar to find the most recent swing points
   double mostRecentSwingHigh = 0;
   double mostRecentSwingLow = EMPTY_VALUE;
   datetime mostRecentSwingHighTime = 0;
   datetime mostRecentSwingLowTime = 0;
   
   // Scan recent bars to find the most recent swings for BOS
   for(int i = 0; i < 20; i++) // Check the last 20 bars
   {
      // Reset swing variables
      swng_High = 0;
      swng_Low = 0;
      bos_tH = 0;
      bos_tL = 0;
      
      // Detect swing at this bar for BOS
      DetectSwingForBar(i, SWING_BOS);
      
      if(swng_High > 0 && (mostRecentSwingHighTime == 0 || bos_tH > mostRecentSwingHighTime))
      {
         mostRecentSwingHigh = swng_High;
         mostRecentSwingHighTime = bos_tH;
      }
      
      if(swng_Low < EMPTY_VALUE && (mostRecentSwingLowTime == 0 || bos_tL > mostRecentSwingLowTime))
      {
         mostRecentSwingLow = swng_Low;
         mostRecentSwingLowTime = bos_tL;
      }
   }
   
   // Update the global BOS variables with the most recent swings
   if(mostRecentSwingHighTime > 0)
   {
      if(mostRecentSwingHighTime != bos_tH)
         Bull_BOS_traded = false;
      swng_High = mostRecentSwingHigh;
      bos_tH = mostRecentSwingHighTime;
   }
   
   if(mostRecentSwingLowTime > 0)
   {
      if(mostRecentSwingLowTime != bos_tL)
         Bear_BOS_traded = false;
      swng_Low = mostRecentSwingLow;
      bos_tL = mostRecentSwingLowTime;
   }
   
   // Now check for break of structure
   Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Get current bar time to prevent multiple trades on same bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   
   // SELL on break above swing high
   if(swng_High > 0 && Ask > swng_High && Bull_BOS_traded == false)
   {
      // Check if we haven't already traded this breakout
      if(lastBOSTradeTime != currentBarTime || lastBOSTradeDirection != -1)
      {
         if(DrawBOSLines)
            DrawBOS("BOS_H_" + TimeToString(bos_tH), bos_tH, swng_High,
                    TimeCurrent(), swng_High, BOSBear, -1);
         
         ExecuteTrade(ORDER_TYPE_BUY);
         
         // Update trade tracking
         lastBOSTradeTime = currentBarTime;
         lastBOSTradeDirection = -1;
         Bull_BOS_traded = true;
         
         // Reset the swing high to prevent immediate re-trading
         swng_High = -1.0;
      }
   }
   
   // BUY on break below swing low
   if(swng_Low > 0 && Bid < swng_Low && Bear_BOS_traded == false)
   {
      // Check if we haven't already traded this breakout
      if(lastBOSTradeTime != currentBarTime || lastBOSTradeDirection != 1)
      {
         if(DrawBOSLines)
            DrawBOS("BOS_L_" + TimeToString(bos_tL), bos_tL, swng_Low,
                    TimeCurrent(), swng_Low, BOSBull, +1);
         
         ExecuteTrade(ORDER_TYPE_SELL);
         
         // Update trade tracking
         Bear_BOS_traded = true;
         lastBOSTradeTime = currentBarTime;
         lastBOSTradeDirection = 1;
         
         // Reset the swing low to prevent immediate re-trading
         swng_Low = -1.0;
      }
   }   
}
void DrawFVG(const SFVG &z)
{
   string name = z.Name();
   datetime tNow = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   
   // Delete existing object if it exists
   if(ObjectFind(0, name) != -1) 
      ObjectDelete(0, name);
   
   // Create rectangle object for FVG
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, z.tLeft, z.bot, tNow, z.top))
   {
      Print("Error creating FVG object: ", GetLastError());
      return;
   }
   
   // Set object properties
   ObjectSetInteger(0, name, OBJPROP_COLOR, z.dir>0 ? BullFVG : BearFVG);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   
   // Set Z-order to make sure it's visible
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
}
