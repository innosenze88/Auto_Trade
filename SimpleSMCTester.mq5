//+------------------------------------------------------------------+
//|                                             SimpleSMCTester.mq5 |
//|                                  Copyright 2024, SMC Tester    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, SMC Tester"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Input parameters
input int    ZigZagDepth = 5;           // ZigZag depth for testing
input int    ZigZagDeviation = 3;       // ZigZag deviation
input int    ZigZagBackstep = 2;        // ZigZag backstep
input bool   ShowSwingPoints = true;    // Show swing points on chart
input bool   ShowTrendLines = true;     // Show trend lines
input bool   ShowOrderBlocks = true;    // Show order blocks
input bool   ShowDebugInfo = true;      // Show debug information
input int    AnalysisInterval = 10;     // Analysis interval in seconds

//--- Global variables
struct SwingPoint
{
    datetime time;
    double   price;
    int      type;  // 1 = High, -1 = Low
    int      bar;
};

SwingPoint g_swings[];
int g_swingCount = 0;

//--- Market structure enum
enum MARKET_STRUCTURE
{
    STRUCTURE_UNKNOWN = 0,
    STRUCTURE_BULLISH = 1,
    STRUCTURE_BEARISH = -1
};

MARKET_STRUCTURE g_marketStructure = STRUCTURE_UNKNOWN;
datetime g_lastAnalysis = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Simple SMC Tester Initialized ===");
    Print("ZigZag Parameters: Depth=", ZigZagDepth, " Deviation=", ZigZagDeviation, " Backstep=", ZigZagBackstep);
    
    // Initialize swing points array
    ArrayResize(g_swings, 100);
    g_swingCount = 0;
    g_lastAnalysis = 0;
    
    // Set indicator properties
    IndicatorSetString(INDICATOR_SHORTNAME, "SMC Tester");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up chart objects
    CleanupChartObjects();
    Print("=== Simple SMC Tester Deinitialized ===");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    datetime currentTime = TimeCurrent();
    
    // Run analysis every N seconds to avoid spam
    if (currentTime - g_lastAnalysis < AnalysisInterval)
        return rates_total;
    
    g_lastAnalysis = currentTime;
    
    if (ShowDebugInfo)
    {
        Print("\n=== SMC Analysis at ", TimeToString(currentTime), " ===");
        Print("Available bars: ", rates_total);
    }
    
    if (rates_total < 20)
    {
        if (ShowDebugInfo)
            Print("Not enough bars for analysis (need at least 20)");
        return rates_total;
    }
    
    // Update swing points
    UpdateSwingPoints(rates_total, time, high, low);
    
    // Analyze market structure
    AnalyzeMarketStructure();
    
    // Test SMC patterns
    TestSMCPatterns(time, open, high, low, close, volume);
    
    // Draw on chart if enabled
    if (ShowSwingPoints) DrawSwingPoints();
    if (ShowTrendLines) DrawTrendLines();
    if (ShowOrderBlocks) DrawOrderBlocks(time, open, high, low, close, volume);
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Update swing points using simple logic                          |
//+------------------------------------------------------------------+
void UpdateSwingPoints(const int rates_total, 
                      const datetime &time[],
                      const double &high[],
                      const double &low[])
{
    g_swingCount = 0;
    
    for (int i = ZigZagDepth; i < rates_total - ZigZagDepth; i++)
    {
        // Check for swing high
        bool isSwingHigh = true;
        for (int j = i - ZigZagDepth; j <= i + ZigZagDepth; j++)
        {
            if (j != i && high[j] >= high[i])
            {
                isSwingHigh = false;
                break;
            }
        }
        
        if (isSwingHigh)
        {
            AddSwingPoint(time[i], high[i], 1, i);
        }
        
        // Check for swing low
        bool isSwingLow = true;
        for (int j = i - ZigZagDepth; j <= i + ZigZagDepth; j++)
        {
            if (j != i && low[j] <= low[i])
            {
                isSwingLow = false;
                break;
            }
        }
        
        if (isSwingLow)
        {
            AddSwingPoint(time[i], low[i], -1, i);
        }
    }
    
    if (ShowDebugInfo)
        Print("Swing Points Found: ", g_swingCount);
}

//+------------------------------------------------------------------+
//| Add swing point to array                                        |
//+------------------------------------------------------------------+
void AddSwingPoint(datetime time, double price, int type, int bar)
{
    if (g_swingCount >= ArraySize(g_swings))
    {
        ArrayResize(g_swings, g_swingCount + 50);
    }
    
    g_swings[g_swingCount].time = time;
    g_swings[g_swingCount].price = price;
    g_swings[g_swingCount].type = type;
    g_swings[g_swingCount].bar = bar;
    g_swingCount++;
}

//+------------------------------------------------------------------+
//| Analyze market structure                                        |
//+------------------------------------------------------------------+
void AnalyzeMarketStructure()
{
    if (g_swingCount < 4)
    {
        g_marketStructure = STRUCTURE_UNKNOWN;
        if (ShowDebugInfo)
            Print("Market Structure: UNKNOWN (not enough swing points: ", g_swingCount, ")");
        return;
    }
    
    // Sort swings by time (most recent first)
    SortSwingsByTime();
    
    // Analyze last 4 swings for trend
    int highs = 0, lows = 0;
    double lastHigh = 0, lastLow = 999999;
    
    for (int i = 0; i < MathMin(4, g_swingCount); i++)
    {
        if (g_swings[i].type == 1) // High
        {
            highs++;
            if (lastHigh == 0 || g_swings[i].price > lastHigh)
                lastHigh = g_swings[i].price;
        }
        else if (g_swings[i].type == -1) // Low
        {
            lows++;
            if (g_swings[i].price < lastLow)
                lastLow = g_swings[i].price;
        }
    }
    
    // Determine structure
    if (highs >= 2 && lows >= 2)
    {
        // Check if we have higher highs and higher lows
        bool higherHighs = false, higherLows = false;
        
        if (g_swingCount >= 4)
        {
            // Compare recent highs and lows
            for (int i = 0; i < g_swingCount - 2; i++)
            {
                for (int j = i + 2; j < g_swingCount; j++)
                {
                    if (g_swings[i].type == g_swings[j].type)
                    {
                        if (g_swings[i].type == 1 && g_swings[i].price > g_swings[j].price)
                            higherHighs = true;
                        if (g_swings[i].type == -1 && g_swings[i].price > g_swings[j].price)
                            higherLows = true;
                    }
                }
            }
        }
        
        if (higherHighs && higherLows)
            g_marketStructure = STRUCTURE_BULLISH;
        else if (!higherHighs && !higherLows)
            g_marketStructure = STRUCTURE_BEARISH;
        else
            g_marketStructure = STRUCTURE_UNKNOWN;
    }
    
    if (ShowDebugInfo)
    {
        string structureStr = "";
        switch(g_marketStructure)
        {
            case STRUCTURE_BULLISH: structureStr = "BULLISH"; break;
            case STRUCTURE_BEARISH: structureStr = "BEARISH"; break;
            default: structureStr = "UNKNOWN"; break;
        }
        
        Print("Market Structure: ", structureStr, " (Highs: ", highs, ", Lows: ", lows, ")");
    }
}

//+------------------------------------------------------------------+
//| Sort swings by time (newest first)                              |
//+------------------------------------------------------------------+
void SortSwingsByTime()
{
    for (int i = 0; i < g_swingCount - 1; i++)
    {
        for (int j = 0; j < g_swingCount - 1 - i; j++)
        {
            if (g_swings[j].time < g_swings[j + 1].time)
            {
                SwingPoint temp = g_swings[j];
                g_swings[j] = g_swings[j + 1];
                g_swings[j + 1] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Test SMC patterns                                               |
//+------------------------------------------------------------------+
void TestSMCPatterns(const datetime &time[],
                    const double &open[],
                    const double &high[],
                    const double &low[],
                    const double &close[],
                    const long &volume[])
{
    if (!ShowDebugInfo) return;
    
    Print("\n--- Testing SMC Patterns ---");
    
    // Test BOS (Break of Structure)
    bool bosDetected = TestBOS();
    Print("BOS Detected: ", (bosDetected ? "YES" : "NO"));
    
    // Test CHoCH (Change of Character)
    bool chochDetected = TestCHoCH();
    Print("CHoCH Detected: ", (chochDetected ? "YES" : "NO"));
    
    // Test Order Blocks
    bool orderBlockDetected = TestOrderBlocks(time, open, high, low, close, volume);
    Print("Order Block Detected: ", (orderBlockDetected ? "YES" : "NO"));
    
    // Test Fair Value Gaps
    bool fvgDetected = TestFairValueGaps(high, low);
    Print("Fair Value Gap Detected: ", (fvgDetected ? "YES" : "NO"));
    
    // Overall SMC signal
    bool smcSignal = bosDetected || chochDetected || orderBlockDetected || fvgDetected;
    Print("Overall SMC Signal: ", (smcSignal ? "SIGNAL DETECTED" : "NO SIGNAL"));
}

//+------------------------------------------------------------------+
//| Test Break of Structure                                         |
//+------------------------------------------------------------------+
bool TestBOS()
{
    if (g_swingCount < 2) return false;
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // Look for recent swing highs/lows
    for (int i = 0; i < MathMin(5, g_swingCount); i++)
    {
        if (g_swings[i].type == 1) // High
        {
            if (currentPrice > g_swings[i].price)
            {
                if (ShowDebugInfo)
                    Print("BOS: Price broke above swing high at ", g_swings[i].price);
                return true;
            }
        }
        else if (g_swings[i].type == -1) // Low
        {
            if (currentPrice < g_swings[i].price)
            {
                if (ShowDebugInfo)
                    Print("BOS: Price broke below swing low at ", g_swings[i].price);
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Test Change of Character                                        |
//+------------------------------------------------------------------+
bool TestCHoCH()
{
    if (g_marketStructure == STRUCTURE_UNKNOWN) return false;
    
    // Simple CHoCH detection based on structure change
    static MARKET_STRUCTURE lastStructure = STRUCTURE_UNKNOWN;
    
    if (lastStructure != STRUCTURE_UNKNOWN && lastStructure != g_marketStructure)
    {
        if (ShowDebugInfo)
            Print("CHoCH: Market structure changed");
        lastStructure = g_marketStructure;
        return true;
    }
    
    lastStructure = g_marketStructure;
    return false;
}

//+------------------------------------------------------------------+
//| Test Order Blocks                                               |
//+------------------------------------------------------------------+
bool TestOrderBlocks(const datetime &time[],
                    const double &open[],
                    const double &high[],
                    const double &low[],
                    const double &close[],
                    const long &volume[])
{
    int rates_total = ArraySize(time);
    if (rates_total < 10) return false;
    
    // Look for high volume bars near swing points
    for (int i = 1; i < MathMin(10, rates_total - 1); i++)
    {
        // Check if this bar has high volume
        long avgVolume = 0;
        for (int j = MathMax(0, i - 5); j <= MathMin(rates_total - 1, i + 5); j++)
        {
            avgVolume += volume[j];
        }
        avgVolume /= 11;
        
        if (volume[i] > avgVolume * 1.5) // High volume threshold
        {
            // Check if near swing point
            for (int s = 0; s < g_swingCount; s++)
            {
                if (MathAbs(g_swings[s].bar - i) <= 2)
                {
                    if (ShowDebugInfo)
                        Print("Order Block: High volume at bar ", i, " near swing point");
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Test Fair Value Gaps                                           |
//+------------------------------------------------------------------+
bool TestFairValueGaps(const double &high[], const double &low[])
{
    int rates_total = ArraySize(high);
    if (rates_total < 3) return false;
    
    // Look for gaps in recent bars
    for (int i = 2; i < MathMin(10, rates_total); i++)
    {
        // Check for upward gap
        if (low[i] > high[i - 2])
        {
            double gapSize = low[i] - high[i - 2];
            double atr = CalculateATR(high, low, 14, i);
            
            if (gapSize > atr * 0.3) // Significant gap
            {
                if (ShowDebugInfo)
                    Print("Fair Value Gap: Upward gap of ", gapSize, " points at bar ", i);
                return true;
            }
        }
        
        // Check for downward gap
        if (high[i] < low[i - 2])
        {
            double gapSize = low[i - 2] - high[i];
            double atr = CalculateATR(high, low, 14, i);
            
            if (gapSize > atr * 0.3) // Significant gap
            {
                if (ShowDebugInfo)
                    Print("Fair Value Gap: Downward gap of ", gapSize, " points at bar ", i);
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate ATR                                                   |
//+------------------------------------------------------------------+
double CalculateATR(const double &high[], const double &low[], int period, int index)
{
    if (index < period) return 0;
    
    double sum = 0;
    for (int i = index - period + 1; i <= index; i++)
    {
        sum += high[i] - low[i];
    }
    
    return sum / period;
}

//+------------------------------------------------------------------+
//| Draw swing points on chart                                      |
//+------------------------------------------------------------------+
void DrawSwingPoints()
{
    for (int i = 0; i < g_swingCount; i++)
    {
        string objName = "Swing_" + IntegerToString(i);
        
        if (ObjectFind(0, objName) < 0)
        {
            ObjectCreate(0, objName, OBJ_ARROW, 0, g_swings[i].time, g_swings[i].price);
            ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, g_swings[i].type == 1 ? 233 : 234);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, g_swings[i].type == 1 ? clrRed : clrBlue);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw trend lines                                               |
//+------------------------------------------------------------------+
void DrawTrendLines()
{
    if (g_swingCount < 2) return;
    
    // Draw line connecting last two swing points
    if (g_swingCount >= 2)
    {
        string objName = "TrendLine_Latest";
        
        if (ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
            
        ObjectCreate(0, objName, OBJ_TREND, 0, 
                    g_swings[1].time, g_swings[1].price,
                    g_swings[0].time, g_swings[0].price);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    }
}

//+------------------------------------------------------------------+
//| Draw order blocks                                              |
//+------------------------------------------------------------------+
void DrawOrderBlocks(const datetime &time[],
                    const double &open[],
                    const double &high[],
                    const double &low[],
                    const double &close[],
                    const long &volume[])
{
    static int lastDrawnOB = 0;
    
    for (int i = lastDrawnOB; i < ArraySize(time) - 1; i++)
    {
        if (volume[i] > 2000) // High volume threshold
        {
            string objName = "OrderBlock_" + IntegerToString(i);
            
            if (ObjectFind(0, objName) < 0)
            {
                ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 
                            time[i], high[i], 
                            time[i] + PeriodSeconds(PERIOD_CURRENT) * 5, low[i]);
                ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDarkGray);
                ObjectSetInteger(0, objName, OBJPROP_FILL, true);
                ObjectSetInteger(0, objName, OBJPROP_BACK, true);
                ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
            }
        }
    }
    
    lastDrawnOB = ArraySize(time) - 1;
}

//+------------------------------------------------------------------+
//| Clean up chart objects                                         |
//+------------------------------------------------------------------+
void CleanupChartObjects()
{
    // Remove swing points
    for (int i = 0; i < 1000; i++)
    {
        string objName = "Swing_" + IntegerToString(i);
        if (ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
    }
    
    // Remove trend lines
    if (ObjectFind(0, "TrendLine_Latest") >= 0)
        ObjectDelete(0, "TrendLine_Latest");
    
    // Remove order blocks
    for (int i = 0; i < 1000; i++)
    {
        string objName = "OrderBlock_" + IntegerToString(i);
        if (ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
    }
}

//+------------------------------------------------------------------+
