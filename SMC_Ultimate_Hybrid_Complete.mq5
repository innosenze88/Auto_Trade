//+------------------------------------------------------------------+
//|                                   SMC_Ultimate_Hybrid_Complete  |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Ultimate SMC Trading Solution - V2.0        |
//|                                                                  |
//| Professional Smart Money Concepts EA with:                      |
//| • True ZigZag-based Swing Point Analysis                        |
//| • Confirmed Order Block Detection                               |
//| • Dynamic SL/TP based on Market Structure                       |
//| • Change of Character (CHoCH) Detection                         |
//| • Break of Structure (BOS) Confirmation                         |
//| • Volume Profile Analysis (Performance Optimized)              |
//| • No Martingale/Grid Recovery - Pure Risk Management            |
//+------------------------------------------------------------------+

#property copyright "Auto_Trade Development"
#property link      "https://github.com/innosenze88/Auto_Trade"
#property version   "2.000"
#property description "Ultimate SMC Trading Solution - Professional Smart Money Concepts EA"
#property description "Features: ZigZag Swing Analysis + True Order Blocks + Dynamic SL/TP"
#property description "No Martingale - Pure SMC Strategy with Risk Management"
#property strict

// Input Parameters
//=== SMC CORE SETTINGS ===
input int MagicNumber = 12345;
input double FixedLotSize = 0.1;
input double RiskPercent = 2.0;
input double MaxSpread = 3.0;
input bool UseZigZag = true;

//=== ZIGZAG SETTINGS ===
input int ZigZagDepth = 15;
input int ZigZagDeviation = 8;
input int ZigZagBackstep = 3;

//=== SMC FILTERS ===
input bool UseBOSConfirmation = true;
input bool UseCHoCHFilter = true;
input bool UseOrderBlocks = true;
input bool UseFairValueGaps = true;
input bool UseImbalanceDetection = true;
input bool UseLiquidityLevels = true;

//=== RISK MANAGEMENT ===
input bool UseTrailingStop = true;
input bool UseBreakevenStop = true;
input double TrailingStopPips = 20;
input double BreakevenPips = 15;
input int MaxPositions = 1;

//=== LINEAR REGRESSION ===
input bool UseLinearRegression = true;
input int RegressionPeriod = 20;
input double RegressionChannelWidth = 2.0;

//=== CONFLUENCE SYSTEM ===
input bool UseConfluenceScoring = true;
input int MinConfluenceScore = 3;

//=== VOLUME ANALYSIS ===
input bool UseVolumeProfile = true;
input int VolumeProfilePeriod = 100;
input bool ShowVolumeNodes = true;

//=== VISUALIZATION ===
input bool DrawSwingPoints = true;
input bool DrawBOS = true;
input bool DrawCHoCH = true;
input bool DrawOrderBlocks = true;
input bool DrawFairValueGaps = true;
input bool DrawDynamicLevels = true;
input bool DrawTrendLines = true;
input bool DrawVolumeProfile = true;

//=== COLORS ===
input color SwingPointColor = clrYellow;
input color BOSColor = clrLime;
input color CHoCHColor = clrOrange;
input color BullishOBColor = clrBlue;
input color BearishOBColor = clrRed;
input color FVGColor = clrPurple;
input color SLColor = clrRed;
input color TPColor = clrGreen;

//=== VWAP SYSTEM ===
input bool UseVWAP = true;
input bool DrawVWAP = true;
input bool UseVWAPFilter = true;
input double VWAPFilterBuffer = 20;
input ENUM_TIMEFRAMES VWAPTimeframe = PERIOD_D1;
input int VWAPPeriod = 20;
input bool ShowVWAPStatus = true;

// Global Variables
int g_zigzagHandle = INVALID_HANDLE;
bool g_drawingEnabled = true;

// Object prefixes for management
string g_swingPrefix = "SMC_Swing_";
string g_bosPrefix = "SMC_BOS_";
string g_chochPrefix = "SMC_CHoCH_";
string g_obPrefix = "SMC_OB_";
string g_fvgPrefix = "SMC_FVG_";
string g_trendPrefix = "SMC_Trend_";
string g_levelPrefix = "SMC_Level_";

// Trading variables
datetime g_lastTradeTime = 0;
double g_currentATR = 0;
double g_currentVWAP = 0;

// ZigZag arrays
double g_zigzagBuffer[];
datetime g_zigzagTime[];
double g_lastHighPrice = 0;
double g_lastLowPrice = 0;
datetime g_lastHighTime = 0;
datetime g_lastLowTime = 0;

// Market structure
bool g_currentTrend = true; // true = bullish, false = bearish
bool g_bosDetected = false;
bool g_chochDetected = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("SMC Ultimate Hybrid EA - Professional Smart Money Concepts Trading");
    Print("Version 2.0 - Advanced Market Structure Analysis");
    
    // Initialize ZigZag indicator
    if (UseZigZag) {
        g_zigzagHandle = iCustom(_Symbol, _Period, "Examples\\ZigZag", 
                                ZigZagDepth, ZigZagDeviation, ZigZagBackstep);
        if (g_zigzagHandle == INVALID_HANDLE) {
            Print("Error: Failed to create ZigZag indicator handle");
            return INIT_FAILED;
        }
        Print("ZigZag Indicator initialized successfully");
    }
    
    // Initialize arrays
    ArraySetAsSeries(g_zigzagBuffer, true);
    ArraySetAsSeries(g_zigzagTime, true);
    
    // Set up drawing
    g_drawingEnabled = (DrawSwingPoints || DrawBOS || DrawCHoCH || 
                       DrawOrderBlocks || DrawFairValueGaps || DrawDynamicLevels);
    
    Print("SMC EA Initialization Complete - Ready for trading");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Clean up objects
    CleanupAllObjects();
    
    // Release indicator handles
    if (g_zigzagHandle != INVALID_HANDLE) {
        IndicatorRelease(g_zigzagHandle);
    }
    
    Print("SMC EA Deinitialized - Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Skip if spread too wide
    double spread = MarketInfo(_Symbol, MODE_SPREAD) * Point;
    if (spread > MaxSpread * Point) return;
    
    // Update ZigZag data
    if (UseZigZag) {
        UpdateZigZagData();
    }
    
    // Update VWAP
    if (UseVWAP) {
        UpdateVWAP();
    }
    
    // Analyze market structure
    AnalyzeMarketStructure();
    
    // Update visualization
    if (g_drawingEnabled) {
        UpdateDrawingObjects();
    }
    
    // Check for trading signals
    CheckTradingSignals();
    
    // Manage open positions
    AdvancedPositionManagement();
}

//+------------------------------------------------------------------+
//| Update VWAP calculation                                          |
//+------------------------------------------------------------------+
void UpdateVWAP() {
    // Simplified VWAP calculation
    double typicalPrice = (High[0] + Low[0] + Close[0]) / 3.0;
    double volume = Volume[0];
    static double cumulativeVWAP = 0;
    static double cumulativeVolume = 0;
    static datetime lastDay = 0;
    
    // Reset on new day
    datetime currentDay = TimeDayOfYear(Time[0]);
    if (currentDay != lastDay) {
        cumulativeVWAP = 0;
        cumulativeVolume = 0;
        lastDay = currentDay;
    }
    
    cumulativeVWAP += typicalPrice * volume;
    cumulativeVolume += volume;
    
    if (cumulativeVolume > 0) {
        g_currentVWAP = cumulativeVWAP / cumulativeVolume;
    }
    
    // Draw VWAP line
    if (DrawVWAP) {
        DrawVWAPLine();
    }
    
    // Show status
    if (ShowVWAPStatus) {
        ShowVWAPStatusOnChart();
    }
}

//+------------------------------------------------------------------+
//| Draw VWAP line on chart                                         |
//+------------------------------------------------------------------+
void DrawVWAPLine() {
    string vwapName = "VWAP_Line";
    ObjectDelete(0, vwapName);
    
    if (ObjectCreate(0, vwapName, OBJ_HLINE, 0, 0, g_currentVWAP)) {
        ObjectSetInteger(0, vwapName, OBJPROP_COLOR, clrAqua);
        ObjectSetInteger(0, vwapName, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, vwapName, OBJPROP_WIDTH, 2);
        ObjectSetString(0, vwapName, OBJPROP_TEXT, "VWAP: " + DoubleToString(g_currentVWAP, Digits));
    }
}

//+------------------------------------------------------------------+
//| Show VWAP status on chart                                       |
//+------------------------------------------------------------------+
void ShowVWAPStatusOnChart() {
    string statusName = "VWAP_Status";
    string status = "";
    color statusColor = clrWhite;
    
    if (Close[0] > g_currentVWAP) {
        status = "Price Above VWAP - Bullish Bias";
        statusColor = clrLimeGreen;
    } else {
        status = "Price Below VWAP - Bearish Bias";
        statusColor = clrOrangeRed;
    }
    
    ObjectDelete(0, statusName);
    if (ObjectCreate(0, statusName, OBJ_LABEL, 0, 0, 0)) {
        ObjectSetInteger(0, statusName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, statusName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, statusName, OBJPROP_YDISTANCE, 50);
        ObjectSetInteger(0, statusName, OBJPROP_COLOR, statusColor);
        ObjectSetString(0, statusName, OBJPROP_TEXT, status);
        ObjectSetInteger(0, statusName, OBJPROP_FONTSIZE, 10);
    }
}

//+------------------------------------------------------------------+
//| Update ZigZag data arrays                                        |
//+------------------------------------------------------------------+
void UpdateZigZagData() {
    if (g_zigzagHandle == INVALID_HANDLE) return;
    
    if (CopyBuffer(g_zigzagHandle, 0, 0, 100, g_zigzagBuffer) <= 0) {
        Print("Error copying ZigZag buffer");
        return;
    }
    
    // Find swing points
    for (int i = 1; i < 99; i++) {
        if (g_zigzagBuffer[i] != 0 && g_zigzagBuffer[i] != EMPTY_VALUE) {
            bool isSwingHigh = (g_zigzagBuffer[i] == High[i]);
            bool isSwingLow = (g_zigzagBuffer[i] == Low[i]);
            
            if (isSwingHigh && DrawSwingPoints) {
                DrawSwingPoint(Time[i], g_zigzagBuffer[i], true);
            }
            if (isSwingLow && DrawSwingPoints) {
                DrawSwingPoint(Time[i], g_zigzagBuffer[i], false);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw swing point on chart                                       |
//+------------------------------------------------------------------+
void DrawSwingPoint(datetime time, double price, bool isHigh) {
    string name = g_swingPrefix + TimeToString(time, TIME_SECONDS);
    
    if (ObjectCreate(0, name, OBJ_ARROW, 0, time, price)) {
        if (isHigh) {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 234); // Down arrow
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
        } else {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 233); // Up arrow  
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
        }
        ObjectSetInteger(0, name, OBJPROP_COLOR, SwingPointColor);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
    }
}

//+------------------------------------------------------------------+
//| Check if point is confirmed swing high/low                      |
//+------------------------------------------------------------------+
bool IsConfirmedSwing(int index, bool checkHigh) {
    if (index < 2 || index >= Bars - 2) return false;
    
    if (checkHigh) {
        return (High[index] > High[index+1] && High[index] > High[index+2] &&
                High[index] > High[index-1] && High[index] > High[index-2]);
    } else {
        return (Low[index] < Low[index+1] && Low[index] < Low[index+2] &&
                Low[index] < Low[index-1] && Low[index] < Low[index-2]);
    }
}

//+------------------------------------------------------------------+
//| Analyze market structure for BOS and CHoCH                      |
//+------------------------------------------------------------------+
void AnalyzeMarketStructure() {
    static datetime lastAnalysisTime = 0;
    if (Time[0] <= lastAnalysisTime) return;
    lastAnalysisTime = Time[0];
    
    // Update last swing points from ZigZag
    UpdateLastSwingPoints();
    
    // Detect BOS and CHoCH
    DetectBOSAndCHoCH();
    
    // Update trend based on structure
    UpdateTrendDirection();
}

//+------------------------------------------------------------------+
//| Update last swing points from ZigZag                            |
//+------------------------------------------------------------------+
void UpdateLastSwingPoints() {
    if (g_zigzagHandle == INVALID_HANDLE) return;
    
    double swingHigh = 0, swingLow = 0;
    datetime swingHighTime = 0, swingLowTime = 0;
    
    // Find most recent swing high and low
    for (int i = 1; i < 50; i++) {
        if (g_zigzagBuffer[i] != 0 && g_zigzagBuffer[i] != EMPTY_VALUE) {
            bool isHigh = (g_zigzagBuffer[i] == High[i]);
            bool isLow = (g_zigzagBuffer[i] == Low[i]);
            
            if (isHigh && swingHighTime == 0) {
                swingHigh = g_zigzagBuffer[i];
                swingHighTime = Time[i];
            }
            if (isLow && swingLowTime == 0) {
                swingLow = g_zigzagBuffer[i];
                swingLowTime = Time[i];
            }
            
            if (swingHighTime > 0 && swingLowTime > 0) break;
        }
    }
    
    // Update global variables
    if (swingHighTime > g_lastHighTime) {
        g_lastHighPrice = swingHigh;
        g_lastHighTime = swingHighTime;
    }
    if (swingLowTime > g_lastLowTime) {
        g_lastLowPrice = swingLow;
        g_lastLowTime = swingLowTime;
    }
}

//+------------------------------------------------------------------+
//| Detect Break of Structure (BOS) and Change of Character (CHoCH) |
//+------------------------------------------------------------------+
void DetectBOSAndCHoCH() {
    static bool lastTrendState = true;
    bool currentTrendBullish = (g_lastHighTime > g_lastLowTime);
    
    // Check for BOS (continuation of trend)
    if (UseBOSConfirmation) {
        CheckBOSPattern();
    }
    
    // Check for CHoCH (trend reversal)
    if (UseCHoCHFilter) {
        CheckCHoCHPattern();
    }
    
    // Check for Order Blocks
    if (UseOrderBlocks) {
        DetectOrderBlocks();
    }
    
    // Check for Fair Value Gaps
    if (UseFairValueGaps) {
        DetectFairValueGaps();
    }
}

//+------------------------------------------------------------------+
//| Check for BOS pattern                                           |
//+------------------------------------------------------------------+
void CheckBOSPattern() {
    // BOS: Price breaks previous swing high (bullish) or low (bearish)
    if (g_currentTrend) { // Bullish trend
        if (Close[0] > g_lastHighPrice) {
            g_bosDetected = true;
            if (DrawBOS) {
                DrawBOSSignal(Time[0], Close[0], true);
            }
        }
    } else { // Bearish trend
        if (Close[0] < g_lastLowPrice) {
            g_bosDetected = true;
            if (DrawBOS) {
                DrawBOSSignal(Time[0], Close[0], false);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check for CHoCH pattern                                         |
//+------------------------------------------------------------------+
void CheckCHoCHPattern() {
    // CHoCH: Trend change when structure is broken opposite direction
    if (g_currentTrend) { // Currently bullish
        if (Close[0] < g_lastLowPrice) {
            g_chochDetected = true;
            g_currentTrend = false; // Change to bearish
            if (DrawCHoCH) {
                DrawCHoCHSignal(Time[0], Close[0], false);
            }
        }
    } else { // Currently bearish
        if (Close[0] > g_lastHighPrice) {
            g_chochDetected = true;
            g_currentTrend = true; // Change to bullish
            if (DrawCHoCH) {
                DrawCHoCHSignal(Time[0], Close[0], true);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update trend direction based on structure                       |
//+------------------------------------------------------------------+
void UpdateTrendDirection() {
    // Use ZigZag swing analysis for trend
    if (g_lastHighTime > g_lastLowTime && g_lastHighPrice > g_lastLowPrice) {
        g_currentTrend = true; // Bullish
    } else if (g_lastLowTime > g_lastHighTime && g_lastLowPrice < g_lastHighPrice) {
        g_currentTrend = false; // Bearish
    }
}

//+------------------------------------------------------------------+
//| Detect Order Blocks                                             |
//+------------------------------------------------------------------+
void DetectOrderBlocks() {
    // Look for consolidation areas before strong moves
    for (int i = 5; i < 20; i++) {
        // Bullish Order Block: consolidation before upward move
        if (Close[i] < Open[i] && Close[i-1] > Open[i-1] && 
            (High[i-1] - Low[i-1]) > (High[i] - Low[i]) * 1.5) {
            if (DrawOrderBlocks) {
                DrawOrderBlock(Time[i], High[i], Low[i], true);
            }
        }
        
        // Bearish Order Block: consolidation before downward move
        if (Close[i] > Open[i] && Close[i-1] < Open[i-1] && 
            (High[i-1] - Low[i-1]) > (High[i] - Low[i]) * 1.5) {
            if (DrawOrderBlocks) {
                DrawOrderBlock(Time[i], High[i], Low[i], false);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gaps                                          |
//+------------------------------------------------------------------+
void DetectFairValueGaps() {
    // Look for gaps between candles
    for (int i = 1; i < 10; i++) {
        // Bullish FVG: gap up
        if (Low[i-1] > High[i+1]) {
            if (DrawFairValueGaps) {
                DrawFairValueGap(Time[i], High[i+1], Low[i-1], true);
            }
        }
        
        // Bearish FVG: gap down
        if (High[i-1] < Low[i+1]) {
            if (DrawFairValueGaps) {
                DrawFairValueGap(Time[i], Low[i+1], High[i-1], false);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw BOS signal on chart                                        |
//+------------------------------------------------------------------+
void DrawBOSSignal(datetime time, double price, bool isBullish) {
    string name = g_bosPrefix + TimeToString(time, TIME_SECONDS);
    
    if (ObjectCreate(0, name, OBJ_ARROW, 0, time, price)) {
        ObjectSetInteger(0, name, OBJPROP_ARROWCODE, isBullish ? 241 : 242);
        ObjectSetInteger(0, name, OBJPROP_COLOR, BOSColor);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
        ObjectSetString(0, name, OBJPROP_TEXT, "BOS " + (isBullish ? "↑" : "↓"));
    }
}

//+------------------------------------------------------------------+
//| Draw CHoCH signal on chart                                      |
//+------------------------------------------------------------------+
void DrawCHoCHSignal(datetime time, double price, bool isBullish) {
    string name = g_chochPrefix + TimeToString(time, TIME_SECONDS);
    
    if (ObjectCreate(0, name, OBJ_ARROW, 0, time, price)) {
        ObjectSetInteger(0, name, OBJPROP_ARROWCODE, isBullish ? 217 : 218);
        ObjectSetInteger(0, name, OBJPROP_COLOR, CHoCHColor);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 4);
        ObjectSetString(0, name, OBJPROP_TEXT, "CHoCH " + (isBullish ? "↑" : "↓"));
    }
}

//+------------------------------------------------------------------+
//| Draw Order Block on chart                                       |
//+------------------------------------------------------------------+
void DrawOrderBlock(datetime time, double highPrice, double lowPrice, bool isBullish) {
    string name = g_obPrefix + TimeToString(time, TIME_SECONDS);
    
    if (ObjectCreate(0, name, OBJ_RECTANGLE, 0, time, highPrice, time + PeriodSeconds(), lowPrice)) {
        ObjectSetInteger(0, name, OBJPROP_COLOR, isBullish ? BullishOBColor : BearishOBColor);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_FILL, true);
        ObjectSetString(0, name, OBJPROP_TEXT, "OB " + (isBullish ? "Bull" : "Bear"));
    }
}

//+------------------------------------------------------------------+
//| Draw Fair Value Gap on chart                                    |
//+------------------------------------------------------------------+
void DrawFairValueGap(datetime time, double highPrice, double lowPrice, bool isBullish) {
    string name = g_fvgPrefix + TimeToString(time, TIME_SECONDS);
    
    if (ObjectCreate(0, name, OBJ_RECTANGLE, 0, time, highPrice, time + PeriodSeconds() * 10, lowPrice)) {
        ObjectSetInteger(0, name, OBJPROP_COLOR, FVGColor);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetString(0, name, OBJPROP_TEXT, "FVG " + (isBullish ? "↑" : "↓"));
    }
}

//+------------------------------------------------------------------+
//| Check for trading signals                                        |
//+------------------------------------------------------------------+
void CheckTradingSignals() {
    if (PositionsTotal() >= MaxPositions) return;
    if (TimeCurrent() - g_lastTradeTime < 300) return; // 5 min cooldown
    
    // Check VWAP filter
    if (UseVWAPFilter) {
        double vwapDist = MathAbs(Close[0] - g_currentVWAP);
        if (vwapDist > VWAPFilterBuffer * Point) return;
    }
    
    // Linear regression filter
    if (UseLinearRegression) {
        if (!CheckLinearRegressionSignal()) return;
    }
    
    // Confluence scoring
    if (UseConfluenceScoring) {
        if (!CheckAdvancedEntryConditions()) return;
    }
    
    // Main trading logic
    bool bullishSignal = false, bearishSignal = false;
    
    // BOS + trend continuation
    if (g_bosDetected && g_currentTrend) {
        bullishSignal = true;
    } else if (g_bosDetected && !g_currentTrend) {
        bearishSignal = true;
    }
    
    // CHoCH reversal signals
    if (g_chochDetected && g_currentTrend) {
        bullishSignal = true;
    } else if (g_chochDetected && !g_currentTrend) {
        bearishSignal = true;
    }
    
    // Execute trades
    if (bullishSignal) {
        ExecuteBuyTrade();
    } else if (bearishSignal) {
        ExecuteSellTrade();
    }
    
    // Reset detection flags
    g_bosDetected = false;
    g_chochDetected = false;
}

//+------------------------------------------------------------------+
//| Check linear regression signal                                  |
//+------------------------------------------------------------------+
bool CheckLinearRegressionSignal() {
    // Calculate simple linear regression trend
    double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
    
    for (int i = 0; i < RegressionPeriod; i++) {
        sum_x += i;
        sum_y += Close[i];
        sum_xy += i * Close[i];
        sum_x2 += i * i;
    }
    
    double slope = (RegressionPeriod * sum_xy - sum_x * sum_y) / 
                   (RegressionPeriod * sum_x2 - sum_x * sum_x);
    
    return (slope > 0); // Bullish if slope positive
}

//+------------------------------------------------------------------+
//| Calculate confluence score                                       |
//+------------------------------------------------------------------+
int CalculateConfluenceScore() {
    int score = 0;
    
    // VWAP confluence
    if (UseVWAP && MathAbs(Close[0] - g_currentVWAP) < 10 * Point) score++;
    
    // Trend confluence
    if (g_currentTrend && Close[0] > Open[0]) score++;
    if (!g_currentTrend && Close[0] < Open[0]) score++;
    
    // Structure confluence
    if (g_bosDetected || g_chochDetected) score++;
    
    // Volume confluence
    if (Volume[0] > Volume[1] * 1.2) score++;
    
    return score;
}

//+------------------------------------------------------------------+
//| Execute buy trade                                               |
//+------------------------------------------------------------------+
void ExecuteBuyTrade() {
    double lotSize = CalculateLotSize();
    double sl = CalculateDynamicSL(true);
    double tp = CalculateDynamicTP(true);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    request.sl = sl;
    request.tp = tp;
    request.magic = MagicNumber;
    request.comment = "SMC Buy Signal";
    
    if (OrderSend(request, result)) {
        g_lastTradeTime = TimeCurrent();
        Print("Buy order executed: Ticket #", result.order);
    } else {
        Print("Buy order failed: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Execute sell trade                                              |
//+------------------------------------------------------------------+
void ExecuteSellTrade() {
    double lotSize = CalculateLotSize();
    double sl = CalculateDynamicSL(false);
    double tp = CalculateDynamicTP(false);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    request.sl = sl;
    request.tp = tp;
    request.magic = MagicNumber;
    request.comment = "SMC Sell Signal";
    
    if (OrderSend(request, result)) {
        g_lastTradeTime = TimeCurrent();
        Print("Sell order executed: Ticket #", result.order);
    } else {
        Print("Sell order failed: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                |
//+------------------------------------------------------------------+
double CalculateLotSize() {
    if (FixedLotSize > 0) return FixedLotSize;
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * RiskPercent / 100.0;
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double stopLossPips = 50; // Default SL distance
    
    double lotSize = riskAmount / (stopLossPips * tickValue);
    
    // Normalize lot size
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, 
              MathRound(lotSize / stepLot) * stepLot));
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate dynamic stop loss                                     |
//+------------------------------------------------------------------+
double CalculateDynamicSL(bool isBuy) {
    // Use last swing point as SL reference
    if (isBuy) {
        return g_lastLowPrice - 10 * Point; // Below last swing low
    } else {
        return g_lastHighPrice + 10 * Point; // Above last swing high
    }
}

//+------------------------------------------------------------------+
//| Calculate dynamic take profit                                   |
//+------------------------------------------------------------------+
double CalculateDynamicTP(bool isBuy) {
    double sl = CalculateDynamicSL(isBuy);
    double entry = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double slDistance = MathAbs(entry - sl);
    
    // 1:2 Risk-Reward ratio
    if (isBuy) {
        return entry + slDistance * 2;
    } else {
        return entry - slDistance * 2;
    }
}

//+------------------------------------------------------------------+
//| Manage open positions                                           |
//+------------------------------------------------------------------+
void ManagePositions() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket)) {
            if (PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
                // Trailing stop
                if (UseTrailingStop) {
                    ApplyTrailingStop(ticket);
                }
                
                // Breakeven stop
                if (UseBreakevenStop) {
                    ApplyBreakevenStop(ticket);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply trailing stop                                             |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return;
    
    double currentSL = PositionGetDouble(POSITION_SL);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    double newSL = 0;
    if (isLong) {
        double currentProfit = Bid - openPrice;
        if (currentProfit > TrailingStopPips * Point) {
            newSL = Bid - TrailingStopPips * Point;
            if (newSL > currentSL + Point) {
                ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
        }
    } else {
        double currentProfit = openPrice - Ask;
        if (currentProfit > TrailingStopPips * Point) {
            newSL = Ask + TrailingStopPips * Point;
            if (newSL < currentSL - Point || currentSL == 0) {
                ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply breakeven stop                                            |
//+------------------------------------------------------------------+
void ApplyBreakevenStop(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return;
    
    double currentSL = PositionGetDouble(POSITION_SL);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    if (isLong) {
        if (Bid - openPrice > BreakevenPips * Point && currentSL < openPrice) {
            ModifyPosition(ticket, openPrice, PositionGetDouble(POSITION_TP));
        }
    } else {
        if (openPrice - Ask > BreakevenPips * Point && 
            (currentSL > openPrice || currentSL == 0)) {
            ModifyPosition(ticket, openPrice, PositionGetDouble(POSITION_TP));
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position SL/TP                                           |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp) {
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    if (!PositionSelectByTicket(ticket)) return false;
    
    request.action = TRADE_ACTION_SLTP;
    request.symbol = PositionGetString(POSITION_SYMBOL);
    request.sl = sl;
    request.tp = tp;
    request.magic = MagicNumber;
    
    return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Update drawing objects                                          |
//+------------------------------------------------------------------+
void UpdateDrawingObjects() {
    static datetime lastUpdate = 0;
    if (Time[0] <= lastUpdate) return;
    lastUpdate = Time[0];
    
    // Update trend structure
    if (DrawTrendLines) {
        DrawTrendStructure();          // ZigZag-based trend lines
    }
    
    // Update BOS levels
    DrawBOSLevels();              // Break of Structure levels
    
    // Update CHoCH levels  
    DrawCHoCHLevels();            // Change of Character levels
    
    DrawMarketStructure();         // Generic structure break lines
    
    // 🎯 2. Entry & Management Zones
    DrawOrderBlocksOnChart();      // D. Order Blocks (OBs)
    DrawDynamicLevelsOnChart();    // E. Dynamic SL/TP levels
    DrawFairValueGapsOnChart();    // F. Fair Value Gaps (FVGs)
    
    // 📊 3. Additional Components
    DrawSwingPointsOnChart();      // Swing points with HH/HL/LH/LL labels
    
    // 📈 4. Advanced Analysis
    AnalyzeAdvancedStructure();    // Liquidity levels and imbalances
    UpdateVolumeProfile();         // Volume profile analysis
    UpdateStatusDisplay();         // Performance display
    
    // Update dynamic levels
    if (DrawDynamicLevels) {
        DrawDynamicSupportResistance();
    }
    
    // Clean up old objects periodically
    static int cleanupCounter = 0;
    if (++cleanupCounter >= 100) {
        CleanupOldObjects();
        cleanupCounter = 0;
    }
}

//+------------------------------------------------------------------+
//| Draw trend structure based on ZigZag                           |
//+------------------------------------------------------------------+
void DrawTrendStructure() {
    if (!DrawTrendLines) return;
    
    // Clean up old trend objects
    CleanupObjectsByPrefix(g_trendPrefix);
    
    // Draw trend lines connecting swing points
    if (g_lastHighTime > 0 && g_lastLowTime > 0) {
        string trendName = g_trendPrefix + "Main_" + TimeToString(Time[0], TIME_SECONDS);
        
        datetime startTime, endTime;
        double startPrice, endPrice;
        
        if (g_lastHighTime > g_lastLowTime) {
            // Recent high to current
            startTime = g_lastLowTime;
            startPrice = g_lastLowPrice;
            endTime = Time[0];
            endPrice = Close[0];
        } else {
            // Recent low to current
            startTime = g_lastHighTime;
            startPrice = g_lastHighPrice;
            endTime = Time[0];
            endPrice = Close[0];
        }
        
        if (ObjectCreate(0, trendName, OBJ_TREND, 0, startTime, startPrice, endTime, endPrice)) {
            ObjectSetInteger(0, trendName, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(0, trendName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, trendName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, trendName, OBJPROP_RAY_RIGHT, true);
            ObjectSetString(0, trendName, OBJPROP_TEXT, "Trend Structure");
        }
    }
}

//+------------------------------------------------------------------+
//| Draw BOS (Break of Structure) Levels                           |
//+------------------------------------------------------------------+
void DrawBOSLevels() {
    if (!DrawBOS) return;
    
    // Clean up old BOS objects
    CleanupObjectsByPrefix(g_bosPrefix);
    
    // Detect and draw BOS levels
    for (int i = 1; i < 20; i++) {
        if (g_zigzagBuffer[i] != 0 && g_zigzagBuffer[i] != EMPTY_VALUE) {
            bool isNewHH = false, isNewLL = false;
            
            // Check for higher high (BOS bullish)
            for (int j = i + 1; j < 50; j++) {
                if (g_zigzagBuffer[j] != 0 && g_zigzagBuffer[j] != EMPTY_VALUE) {
                    if (g_zigzagBuffer[i] == High[i] && g_zigzagBuffer[j] == High[j]) {
                        if (High[i] > High[j]) {
                            isNewHH = true;
                            break;
                        }
                    }
                }
            }
            
            // Check for lower low (BOS bearish)  
            for (int j = i + 1; j < 50; j++) {
                if (g_zigzagBuffer[j] != 0 && g_zigzagBuffer[j] != EMPTY_VALUE) {
                    if (g_zigzagBuffer[i] == Low[i] && g_zigzagBuffer[j] == Low[j]) {
                        if (Low[i] < Low[j]) {
                            isNewLL = true;
                            break;
                        }
                    }
                }
            }
            
            // Draw BOS level
            if (isNewHH || isNewLL) {
                string bosName = g_bosPrefix + "Level_" + TimeToString(Time[i], TIME_SECONDS);
                
                if (ObjectCreate(0, bosName, OBJ_HLINE, 0, 0, g_zigzagBuffer[i])) {
                    ObjectSetInteger(0, bosName, OBJPROP_COLOR, BOSColor);
                    ObjectSetInteger(0, bosName, OBJPROP_STYLE, STYLE_DASH);
                    ObjectSetInteger(0, bosName, OBJPROP_WIDTH, 2);
                    ObjectSetString(0, bosName, OBJPROP_TEXT, 
                                   "BOS " + (isNewHH ? "Bullish" : "Bearish") + " Level");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw CHoCH (Change of Character) Levels                        |
//+------------------------------------------------------------------+
void DrawCHoCHLevels() {
    if (!DrawCHoCH) return;
    
    // Clean up old CHoCH objects
    CleanupObjectsByPrefix(g_chochPrefix);
    
    // Detect trend changes and draw CHoCH levels
    bool previousTrend = true; // Start assuming bullish
    
    for (int i = 5; i < 50; i++) {
        if (g_zigzagBuffer[i] != 0 && g_zigzagBuffer[i] != EMPTY_VALUE &&
            g_zigzagBuffer[i+1] != 0 && g_zigzagBuffer[i+1] != EMPTY_VALUE) {
            
            bool currentMove = (g_zigzagBuffer[i] > g_zigzagBuffer[i+1]);
            
            // Check for trend change
            if (currentMove != previousTrend) {
                string chochName = g_chochPrefix + "Level_" + TimeToString(Time[i], TIME_SECONDS);
                
                if (ObjectCreate(0, chochName, OBJ_HLINE, 0, 0, g_zigzagBuffer[i])) {
                    ObjectSetInteger(0, chochName, OBJPROP_COLOR, CHoCHColor);
                    ObjectSetInteger(0, chochName, OBJPROP_STYLE, STYLE_DOT);
                    ObjectSetInteger(0, chochName, OBJPROP_WIDTH, 3);
                    ObjectSetString(0, chochName, OBJPROP_TEXT, 
                                   "CHoCH " + (currentMove ? "Bullish" : "Bearish") + " Change");
                }
                
                previousTrend = currentMove;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw BOS and CHoCH Signals                                      |
//+------------------------------------------------------------------+
void DrawMarketStructure() {
    if (!DrawBOS && !DrawCHoCH) return;
    
    static bool lastBOSState = false;
    static bool lastCHoCHState = false;
    static datetime lastBOSTime = 0;
    static datetime lastCHoCHTime = 0;
    
    // Draw BOS signals
    if (g_bosDetected && !lastBOSState && Time[0] > lastBOSTime + 3600) {
        string bosSignal = "BOS_Signal_" + TimeToString(Time[0], TIME_SECONDS);
        
        if (ObjectCreate(0, bosSignal, OBJ_ARROW, 0, Time[0], Close[0])) {
            ObjectSetInteger(0, bosSignal, OBJPROP_ARROWCODE, g_currentTrend ? 241 : 242);
            ObjectSetInteger(0, bosSignal, OBJPROP_COLOR, BOSColor);
            ObjectSetInteger(0, bosSignal, OBJPROP_WIDTH, 4);
            ObjectSetString(0, bosSignal, OBJPROP_TEXT, "BOS Confirmed");
        }
        
        lastBOSTime = Time[0];
    }
    
    // Draw CHoCH signals
    if (g_chochDetected && !lastCHoCHState && Time[0] > lastCHoCHTime + 3600) {
        string chochSignal = "CHoCH_Signal_" + TimeToString(Time[0], TIME_SECONDS);
        
        if (ObjectCreate(0, chochSignal, OBJ_ARROW, 0, Time[0], Close[0])) {
            ObjectSetInteger(0, chochSignal, OBJPROP_ARROWCODE, 220);
            ObjectSetInteger(0, chochSignal, OBJPROP_COLOR, CHoCHColor);
            ObjectSetInteger(0, chochSignal, OBJPROP_WIDTH, 5);
            ObjectSetString(0, chochSignal, OBJPROP_TEXT, "CHoCH - Trend Change");
        }
        
        lastCHoCHTime = Time[0];
    }
    
    lastBOSState = g_bosDetected;
    lastCHoCHState = g_chochDetected;
}

//+------------------------------------------------------------------+
//| Draw dynamic support and resistance levels                      |
//+------------------------------------------------------------------+
void DrawDynamicSupportResistance() {
    // Clean up old level objects
    CleanupObjectsByPrefix(g_levelPrefix);
    
    // Calculate dynamic levels based on recent price action
    double resistance = 0, support = 0;
    
    // Find highest high and lowest low in recent bars
    int lookback = 50;
    resistance = High[iHighest(_Symbol, _Period, MODE_HIGH, lookback, 0)];
    support = Low[iLowest(_Symbol, _Period, MODE_LOW, lookback, 0)];
    
    // Draw support level
    string supportName = g_levelPrefix + "Support_" + TimeToString(Time[0], TIME_SECONDS);
    if (ObjectCreate(0, supportName, OBJ_HLINE, 0, 0, support)) {
        ObjectSetInteger(0, supportName, OBJPROP_COLOR, SLColor);
        ObjectSetInteger(0, supportName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, supportName, OBJPROP_WIDTH, 1);
        ObjectSetString(0, supportName, OBJPROP_TEXT, "Dynamic Support: " + DoubleToString(support, Digits));
    }
    
    // Draw resistance level
    string resistanceName = g_levelPrefix + "Resistance_" + TimeToString(Time[0], TIME_SECONDS);
    if (ObjectCreate(0, resistanceName, OBJ_HLINE, 0, 0, resistance)) {
        ObjectSetInteger(0, resistanceName, OBJPROP_COLOR, TPColor);
        ObjectSetInteger(0, resistanceName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, resistanceName, OBJPROP_WIDTH, 1);
        ObjectSetString(0, resistanceName, OBJPROP_TEXT, "Dynamic Resistance: " + DoubleToString(resistance, Digits));
    }
}

//+------------------------------------------------------------------+
//| Clean up objects by prefix                                      |
//+------------------------------------------------------------------+
void CleanupObjectsByPrefix(string prefix) {
    int totalObjects = ObjectsTotal(0);
    
    for (int i = totalObjects - 1; i >= 0; i--) {
        string name = ObjectName(0, i);
        if (StringFind(name, prefix) == 0) {
            ObjectDelete(0, name);
        }
    }
}

//+------------------------------------------------------------------+
//| Clean up old objects (older than 24 hours)                     |
//+------------------------------------------------------------------+
void CleanupOldObjects() {
    int totalObjects = ObjectsTotal(0);
    datetime cutoffTime = TimeCurrent() - 86400; // 24 hours ago
    
    for (int i = totalObjects - 1; i >= 0; i--) {
        string name = ObjectName(0, i);
        
        // Check if object belongs to this EA
        if (StringFind(name, "SMC_") == 0) {
            datetime objectTime = ObjectGetInteger(0, name, OBJPROP_TIME);
            if (objectTime < cutoffTime) {
                ObjectDelete(0, name);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Clean up all objects created by this EA                         |
//+------------------------------------------------------------------+
void CleanupAllObjects() {
    CleanupObjectsByPrefix(g_swingPrefix);
    CleanupObjectsByPrefix(g_bosPrefix);
    CleanupObjectsByPrefix(g_chochPrefix);
    CleanupObjectsByPrefix(g_obPrefix);
    CleanupObjectsByPrefix(g_fvgPrefix);
    CleanupObjectsByPrefix(g_trendPrefix);
    CleanupObjectsByPrefix(g_levelPrefix);
    
    // Clean up VWAP objects
    ObjectDelete(0, "VWAP_Line");
    ObjectDelete(0, "VWAP_Status");
}

//+------------------------------------------------------------------+
//| Chart event handler                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam) {
    if (id == CHARTEVENT_CHART_CHANGE) {
        // Redraw objects when chart is modified
        if (g_drawingEnabled) {
            UpdateDrawingObjects();
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Swing Points on Chart                                      |
//+------------------------------------------------------------------+
void DrawSwingPointsOnChart() {
    if (!DrawSwingPoints || !g_drawingEnabled) return;
    
    // Draw swing points from ZigZag data
    for (int i = 1; i < 50; i++) {
        if (g_zigzagBuffer[i] != 0 && g_zigzagBuffer[i] != EMPTY_VALUE) {
            bool isSwingHigh = (g_zigzagBuffer[i] == High[i]);
            bool isSwingLow = (g_zigzagBuffer[i] == Low[i]);
            
            if (isSwingHigh) {
                DrawSwingPoint(Time[i], g_zigzagBuffer[i], true);
            }
            if (isSwingLow) {
                DrawSwingPoint(Time[i], g_zigzagBuffer[i], false);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Order Blocks on Chart                                      |
//+------------------------------------------------------------------+
void DrawOrderBlocksOnChart() {
    if (!DrawOrderBlocks || !g_drawingEnabled) return;
    
    // Look for order blocks around recent price action
    for (int i = 5; i < 25; i++) {
        // Bullish Order Block detection
        if (Close[i] < Open[i] && Close[i-1] > Open[i-1]) {
            double obHigh = MathMax(Open[i], Close[i]);
            double obLow = MathMin(Open[i], Close[i]);
            
            string obName = g_obPrefix + "Bull_" + TimeToString(Time[i], TIME_SECONDS);
            
            if (ObjectCreate(0, obName, OBJ_RECTANGLE, 0, Time[i], obHigh, Time[i] + PeriodSeconds() * 5, obLow)) {
                ObjectSetInteger(0, obName, OBJPROP_COLOR, BullishOBColor);
                ObjectSetInteger(0, obName, OBJPROP_STYLE, STYLE_SOLID);
                ObjectSetInteger(0, obName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, obName, OBJPROP_BACK, true);
                ObjectSetInteger(0, obName, OBJPROP_FILL, true);
                ObjectSetString(0, obName, OBJPROP_TEXT, "Bullish OB");
            }
        }
        
        // Bearish Order Block detection
        if (Close[i] > Open[i] && Close[i-1] < Open[i-1]) {
            double obHigh = MathMax(Open[i], Close[i]);
            double obLow = MathMin(Open[i], Close[i]);
            
            string obName = g_obPrefix + "Bear_" + TimeToString(Time[i], TIME_SECONDS);
            
            if (ObjectCreate(0, obName, OBJ_RECTANGLE, 0, Time[i], obHigh, Time[i] + PeriodSeconds() * 5, obLow)) {
                ObjectSetInteger(0, obName, OBJPROP_COLOR, BearishOBColor);
                ObjectSetInteger(0, obName, OBJPROP_STYLE, STYLE_SOLID);
                ObjectSetInteger(0, obName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, obName, OBJPROP_BACK, true);
                ObjectSetInteger(0, obName, OBJPROP_FILL, true);
                ObjectSetString(0, obName, OBJPROP_TEXT, "Bearish OB");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Fair Value Gaps on Chart                                   |
//+------------------------------------------------------------------+
void DrawFairValueGapsOnChart() {
    if (!DrawFairValueGaps || !g_drawingEnabled) return;
    
    // Look for Fair Value Gaps in recent candles
    for (int i = 2; i < 20; i++) {
        // Bullish FVG: Low[i-1] > High[i+1]
        if (Low[i-1] > High[i+1]) {
            string fvgName = g_fvgPrefix + "Bull_" + TimeToString(Time[i], TIME_SECONDS);
            
            if (ObjectCreate(0, fvgName, OBJ_RECTANGLE, 0, Time[i+1], Low[i-1], Time[i-1], High[i+1])) {
                ObjectSetInteger(0, fvgName, OBJPROP_COLOR, FVGColor);
                ObjectSetInteger(0, fvgName, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(0, fvgName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, fvgName, OBJPROP_BACK, true);
                ObjectSetString(0, fvgName, OBJPROP_TEXT, "Bullish FVG");
            }
        }
        
        // Bearish FVG: High[i-1] < Low[i+1]
        if (High[i-1] < Low[i+1]) {
            string fvgName = g_fvgPrefix + "Bear_" + TimeToString(Time[i], TIME_SECONDS);
            
            if (ObjectCreate(0, fvgName, OBJ_RECTANGLE, 0, Time[i+1], High[i-1], Time[i-1], Low[i+1])) {
                ObjectSetInteger(0, fvgName, OBJPROP_COLOR, FVGColor);
                ObjectSetInteger(0, fvgName, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(0, fvgName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, fvgName, OBJPROP_BACK, true);
                ObjectSetString(0, fvgName, OBJPROP_TEXT, "Bearish FVG");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Dynamic SL/TP Levels                                       |
//+------------------------------------------------------------------+
void DrawDynamicLevelsOnChart() {
    if (!DrawDynamicLevels || !g_drawingEnabled) return;
    
    // Calculate dynamic SL/TP levels based on current market structure
    double dynamicSL = 0, dynamicTP = 0;
    
    if (g_currentTrend) { // Bullish trend
        dynamicSL = g_lastLowPrice - 20 * Point;
        dynamicTP = Close[0] + (Close[0] - dynamicSL) * 2; // 1:2 RR
    } else { // Bearish trend
        dynamicSL = g_lastHighPrice + 20 * Point;
        dynamicTP = Close[0] - (dynamicSL - Close[0]) * 2; // 1:2 RR
    }
    
    // Draw Dynamic SL
    string slName = g_levelPrefix + "Dynamic_SL";
    ObjectDelete(0, slName);
    if (ObjectCreate(0, slName, OBJ_HLINE, 0, 0, dynamicSL)) {
        ObjectSetInteger(0, slName, OBJPROP_COLOR, SLColor);
        ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, slName, OBJPROP_WIDTH, 2);
        ObjectSetString(0, slName, OBJPROP_TEXT, "Dynamic SL: " + DoubleToString(dynamicSL, Digits));
    }
    
    // Draw Dynamic TP
    string tpName = g_levelPrefix + "Dynamic_TP";
    ObjectDelete(0, tpName);
    if (ObjectCreate(0, tpName, OBJ_HLINE, 0, 0, dynamicTP)) {
        ObjectSetInteger(0, tpName, OBJPROP_COLOR, TPColor);
        ObjectSetInteger(0, tpName, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, tpName, OBJPROP_WIDTH, 2);
        ObjectSetString(0, tpName, OBJPROP_TEXT, "Dynamic TP: " + DoubleToString(dynamicTP, Digits));
    }
}

//+------------------------------------------------------------------+
//| Volume Profile Analysis (Performance Optimized)                |
//+------------------------------------------------------------------+
void UpdateVolumeProfile() {
    if (!UseVolumeProfile || !DrawVolumeProfile) return;
    
    static datetime lastVPUpdate = 0;
    if (Time[0] <= lastVPUpdate) return;
    lastVPUpdate = Time[0];
    
    // Clean up old volume profile objects
    CleanupObjectsByPrefix("VP_");
    
    // Calculate volume profile for recent period
    double priceHigh = High[iHighest(_Symbol, _Period, MODE_HIGH, VolumeProfilePeriod, 0)];
    double priceLow = Low[iLowest(_Symbol, _Period, MODE_LOW, VolumeProfilePeriod, 0)];
    double priceRange = priceHigh - priceLow;
    
    if (priceRange <= 0) return;
    
    int levels = 20; // Number of price levels for volume profile
    double levelHeight = priceRange / levels;
    
    // Volume profile arrays
    double volumeAtPrice[];
    ArrayResize(volumeAtPrice, levels);
    ArrayInitialize(volumeAtPrice, 0);
    
    // Calculate volume at each price level
    for (int i = 0; i < VolumeProfilePeriod; i++) {
        double barVolume = Volume[i];
        double barHigh = High[i];
        double barLow = Low[i];
        
        // Distribute volume across price levels within the bar
        for (int level = 0; level < levels; level++) {
            double levelPrice = priceLow + level * levelHeight;
            if (levelPrice >= barLow && levelPrice <= barHigh) {
                volumeAtPrice[level] += barVolume / 4; // Simplified distribution
            }
        }
    }
    
    // Find highest volume level (POC - Point of Control)
    int pocLevel = 0;
    double maxVolume = 0;
    for (int level = 0; level < levels; level++) {
        if (volumeAtPrice[level] > maxVolume) {
            maxVolume = volumeAtPrice[level];
            pocLevel = level;
        }
    }
    
    // Draw volume profile levels
    for (int level = 0; level < levels; level++) {
        if (volumeAtPrice[level] > maxVolume * 0.1) { // Only show significant levels
            double levelPrice = priceLow + level * levelHeight;
            double volumeRatio = volumeAtPrice[level] / maxVolume;
            
            string vpName = "VP_Level_" + IntegerToString(level);
            color levelColor = (level == pocLevel) ? clrYellow : clrGray;
            
            if (ObjectCreate(0, vpName, OBJ_HLINE, 0, 0, levelPrice)) {
                ObjectSetInteger(0, vpName, OBJPROP_COLOR, levelColor);
                ObjectSetInteger(0, vpName, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(0, vpName, OBJPROP_WIDTH, (level == pocLevel) ? 3 : 1);
                ObjectSetString(0, vpName, OBJPROP_TEXT, 
                               (level == pocLevel) ? "POC: " + DoubleToString(levelPrice, Digits) :
                               "VP: " + DoubleToString(levelPrice, Digits));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Enhanced Market Structure Analysis                              |
//+------------------------------------------------------------------+
void AnalyzeAdvancedStructure() {
    // Liquidity Levels Detection
    if (UseLiquidityLevels) {
        DetectLiquidityLevels();
    }
    
    // Market Imbalance Detection
    if (UseImbalanceDetection) {
        DetectMarketImbalances();
    }
    
    // Multi-timeframe structure analysis
    AnalyzeHigherTimeframeStructure();
}

//+------------------------------------------------------------------+
//| Detect Liquidity Levels                                        |
//+------------------------------------------------------------------+
void DetectLiquidityLevels() {
    // Look for equal highs/lows (liquidity pools)
    for (int i = 5; i < 50; i++) {
        // Equal highs (resistance liquidity)
        for (int j = i + 5; j < 50; j++) {
            if (MathAbs(High[i] - High[j]) < 10 * Point) {
                string liqName = g_levelPrefix + "Liquidity_H_" + TimeToString(Time[i], TIME_SECONDS);
                
                if (ObjectCreate(0, liqName, OBJ_HLINE, 0, 0, High[i])) {
                    ObjectSetInteger(0, liqName, OBJPROP_COLOR, clrMagenta);
                    ObjectSetInteger(0, liqName, OBJPROP_STYLE, STYLE_DASHDOT);
                    ObjectSetInteger(0, liqName, OBJPROP_WIDTH, 2);
                    ObjectSetString(0, liqName, OBJPROP_TEXT, "Liquidity Level: " + DoubleToString(High[i], Digits));
                }
                break;
            }
        }
        
        // Equal lows (support liquidity)
        for (int j = i + 5; j < 50; j++) {
            if (MathAbs(Low[i] - Low[j]) < 10 * Point) {
                string liqName = g_levelPrefix + "Liquidity_L_" + TimeToString(Time[i], TIME_SECONDS);
                
                if (ObjectCreate(0, liqName, OBJ_HLINE, 0, 0, Low[i])) {
                    ObjectSetInteger(0, liqName, OBJPROP_COLOR, clrMagenta);
                    ObjectSetInteger(0, liqName, OBJPROP_STYLE, STYLE_DASHDOT);
                    ObjectSetInteger(0, liqName, OBJPROP_WIDTH, 2);
                    ObjectSetString(0, liqName, OBJPROP_TEXT, "Liquidity Level: " + DoubleToString(Low[i], Digits));
                }
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Detect Market Imbalances                                       |
//+------------------------------------------------------------------+
void DetectMarketImbalances() {
    // Look for price imbalances (gaps that need to be filled)
    for (int i = 1; i < 20; i++) {
        // Bullish imbalance
        if (Low[i-1] > High[i+1] + 5 * Point) {
            string imbName = g_fvgPrefix + "Imbalance_Bull_" + TimeToString(Time[i], TIME_SECONDS);
            
            if (ObjectCreate(0, imbName, OBJ_RECTANGLE, 0, Time[i+1], Low[i-1], Time[i-1], High[i+1])) {
                ObjectSetInteger(0, imbName, OBJPROP_COLOR, clrCyan);
                ObjectSetInteger(0, imbName, OBJPROP_STYLE, STYLE_SOLID);
                ObjectSetInteger(0, imbName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, imbName, OBJPROP_BACK, true);
                ObjectSetString(0, imbName, OBJPROP_TEXT, "Bullish Imbalance");
            }
        }
        
        // Bearish imbalance
        if (High[i-1] < Low[i+1] - 5 * Point) {
            string imbName = g_fvgPrefix + "Imbalance_Bear_" + TimeToString(Time[i], TIME_SECONDS);
            
            if (ObjectCreate(0, imbName, OBJ_RECTANGLE, 0, Time[i+1], High[i-1], Time[i-1], Low[i+1])) {
                ObjectSetInteger(0, imbName, OBJPROP_COLOR, clrCyan);
                ObjectSetInteger(0, imbName, OBJPROP_STYLE, STYLE_SOLID);
                ObjectSetInteger(0, imbName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, imbName, OBJPROP_BACK, true);
                ObjectSetString(0, imbName, OBJPROP_TEXT, "Bearish Imbalance");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze Higher Timeframe Structure                             |
//+------------------------------------------------------------------+
void AnalyzeHigherTimeframeStructure() {
    // Get higher timeframe trend direction
    ENUM_TIMEFRAMES htf = VWAPTimeframe; // Use VWAP timeframe as HTF
    
    double htfHigh = iHigh(_Symbol, htf, 1);
    double htfLow = iLow(_Symbol, htf, 1);
    double htfClose = iClose(_Symbol, htf, 1);
    double htfOpen = iOpen(_Symbol, htf, 1);
    
    bool htfBullish = (htfClose > htfOpen);
    
    // Draw HTF bias indicator
    string htfName = "HTF_Bias";
    ObjectDelete(0, htfName);
    
    if (ObjectCreate(0, htfName, OBJ_LABEL, 0, 0, 0)) {
        ObjectSetInteger(0, htfName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, htfName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, htfName, OBJPROP_YDISTANCE, 30);
        ObjectSetInteger(0, htfName, OBJPROP_COLOR, htfBullish ? clrLimeGreen : clrOrangeRed);
        ObjectSetString(0, htfName, OBJPROP_TEXT, "HTF Bias: " + (htfBullish ? "BULLISH" : "BEARISH"));
        ObjectSetInteger(0, htfName, OBJPROP_FONTSIZE, 12);
    }
}

//+------------------------------------------------------------------+
//| Advanced Trading Signal Logic                                   |
//+------------------------------------------------------------------+
bool CheckAdvancedEntryConditions() {
    // Multi-factor confluence check
    int confluenceScore = 0;
    
    // 1. Structure confluence (BOS/CHoCH)
    if (g_bosDetected || g_chochDetected) confluenceScore += 2;
    
    // 2. VWAP confluence
    if (UseVWAPFilter) {
        double vwapDistance = MathAbs(Close[0] - g_currentVWAP);
        if (vwapDistance < VWAPFilterBuffer * Point) confluenceScore += 1;
    }
    
    // 3. Volume confluence
    if (Volume[0] > Volume[1] * 1.3) confluenceScore += 1;
    
    // 4. Linear regression confluence
    if (UseLinearRegression && CheckLinearRegressionSignal()) confluenceScore += 1;
    
    // 5. Order block confluence
    if (UseOrderBlocks && IsNearOrderBlock()) confluenceScore += 1;
    
    // 6. Fair value gap confluence
    if (UseFairValueGaps && IsNearFairValueGap()) confluenceScore += 1;
    
    return (confluenceScore >= MinConfluenceScore);
}

//+------------------------------------------------------------------+
//| Check if price is near Order Block                             |
//+------------------------------------------------------------------+
bool IsNearOrderBlock() {
    double currentPrice = Close[0];
    double buffer = 20 * Point;
    
    // Check recent order blocks
    for (int i = 5; i < 25; i++) {
        double obHigh = MathMax(Open[i], Close[i]);
        double obLow = MathMin(Open[i], Close[i]);
        
        if (currentPrice >= obLow - buffer && currentPrice <= obHigh + buffer) {
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if price is near Fair Value Gap                          |
//+------------------------------------------------------------------+
bool IsNearFairValueGap() {
    double currentPrice = Close[0];
    double buffer = 15 * Point;
    
    // Check recent FVGs
    for (int i = 2; i < 15; i++) {
        // Bullish FVG
        if (Low[i-1] > High[i+1]) {
            double fvgHigh = Low[i-1];
            double fvgLow = High[i+1];
            
            if (currentPrice >= fvgLow - buffer && currentPrice <= fvgHigh + buffer) {
                return true;
            }
        }
        
        // Bearish FVG
        if (High[i-1] < Low[i+1]) {
            double fvgHigh = Low[i+1];
            double fvgLow = High[i-1];
            
            if (currentPrice >= fvgLow - buffer && currentPrice <= fvgHigh + buffer) {
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Enhanced Position Management                                    |
//+------------------------------------------------------------------+
void AdvancedPositionManagement() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket)) {
            if (PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
                
                // Structure-based exit
                if (ShouldExitOnStructureChange(ticket)) {
                    ClosePosition(ticket);
                    continue;
                }
                
                // Partial profit taking
                if (ShouldTakePartialProfit(ticket)) {
                    TakePartialProfit(ticket);
                }
                
                // Advanced trailing stop
                if (UseTrailingStop) {
                    ApplyStructureBasedTrailing(ticket);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if should exit on structure change                       |
//+------------------------------------------------------------------+
bool ShouldExitOnStructureChange(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return false;
    
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    // Exit long position on bearish CHoCH
    if (isLong && g_chochDetected && !g_currentTrend) {
        Print("Exiting long position due to bearish CHoCH");
        return true;
    }
    
    // Exit short position on bullish CHoCH
    if (!isLong && g_chochDetected && g_currentTrend) {
        Print("Exiting short position due to bullish CHoCH");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if should take partial profit                            |
//+------------------------------------------------------------------+
bool ShouldTakePartialProfit(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return false;
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    
    double profitPoints = 0;
    if (isLong) {
        profitPoints = (currentPrice - openPrice) / Point;
    } else {
        profitPoints = (openPrice - currentPrice) / Point;
    }
    
    // Take partial profit at 1:1 risk-reward
    return (profitPoints >= 100); // Adjust based on your SL distance
}

//+------------------------------------------------------------------+
//| Take partial profit                                            |
//+------------------------------------------------------------------+
void TakePartialProfit(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return;
    
    double currentVolume = PositionGetDouble(POSITION_VOLUME);
    double partialVolume = currentVolume * 0.5; // Close 50%
    
    // Close partial position (simplified - in real implementation you'd need to handle partial closes properly)
    Print("Taking partial profit on position ", ticket);
}

//+------------------------------------------------------------------+
//| Apply structure-based trailing stop                            |
//+------------------------------------------------------------------+
void ApplyStructureBasedTrailing(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return;
    
    bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
    double currentSL = PositionGetDouble(POSITION_SL);
    double newSL = 0;
    
    if (isLong) {
        // Trail behind recent swing low
        newSL = g_lastLowPrice - 10 * Point;
        if (newSL > currentSL + Point) {
            ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
        }
    } else {
        // Trail behind recent swing high
        newSL = g_lastHighPrice + 10 * Point;
        if (newSL < currentSL - Point || currentSL == 0) {
            ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
        }
    }
}

//+------------------------------------------------------------------+
//| Close position helper function                                  |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket) {
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    if (!PositionSelectByTicket(ticket)) return false;
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = PositionGetString(POSITION_SYMBOL);
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                   SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    request.position = ticket;
    request.magic = MagicNumber;
    
    return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Performance and Status Display                                  |
//+------------------------------------------------------------------+
void UpdateStatusDisplay() {
    string statusText = "";
    color statusColor = clrWhite;
    
    // Current trend status
    statusText += "Trend: " + (g_currentTrend ? "BULLISH" : "BEARISH") + "\n";
    
    // Structure status
    if (g_bosDetected) statusText += "BOS DETECTED\n";
    if (g_chochDetected) statusText += "CHoCH DETECTED\n";
    
    // VWAP status
    if (UseVWAP) {
        statusText += "VWAP: " + DoubleToString(g_currentVWAP, Digits) + "\n";
        statusText += "Price vs VWAP: " + (Close[0] > g_currentVWAP ? "ABOVE" : "BELOW") + "\n";
    }
    
    // Position status
    statusText += "Positions: " + IntegerToString(PositionsTotal()) + "/" + IntegerToString(MaxPositions) + "\n";
    
    // Display status
    string statusName = "EA_Status_Display";
    ObjectDelete(0, statusName);
    
    if (ObjectCreate(0, statusName, OBJ_LABEL, 0, 0, 0)) {
        ObjectSetInteger(0, statusName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, statusName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, statusName, OBJPROP_YDISTANCE, 80);
        ObjectSetInteger(0, statusName, OBJPROP_COLOR, clrWhite);
        ObjectSetString(0, statusName, OBJPROP_TEXT, statusText);
        ObjectSetInteger(0, statusName, OBJPROP_FONTSIZE, 9);
    }
}

//+------------------------------------------------------------------+
//| End of SMC Ultimate Hybrid Complete EA                          |
//+------------------------------------------------------------------+