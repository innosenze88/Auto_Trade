//+------------------------------------------------------------------+
//|                                   SMC_Fixed_Complete.mq5        |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Ultimate SMC Trading Solution - V2.0        |
//+------------------------------------------------------------------+
#property copyright "Auto_Trade Development"
#property link      "https://github.com/innosenze88/Auto_Trade"
#property version   "2.000"
#property description "Ultimate SMC Trading Solution - MT5 Compatible"

// Input Parameters
input int MagicNumber = 12345;
input double FixedLotSize = 0.1;
input double RiskPercent = 2.0;
input double MaxSpread = 3.0;
input bool UseZigZag = true;
input int ZigZagDepth = 15;
input int ZigZagDeviation = 8;
input int ZigZagBackstep = 3;
input bool UseBOSConfirmation = true;
input bool UseCHoCHFilter = true;
input bool UseOrderBlocks = true;
input bool UseFairValueGaps = true;
input bool UseImbalanceDetection = true;
input bool UseLiquidityLevels = true;
input bool UseTrailingStop = true;
input bool UseBreakevenStop = true;
input double TrailingStopPips = 20;
input double BreakevenPips = 15;
input int MaxPositions = 1;
input bool UseLinearRegression = true;
input int RegressionPeriod = 20;
input double RegressionChannelWidth = 2.0;
input bool UseConfluenceScoring = true;
input int MinConfluenceScore = 3;
input bool UseVolumeProfile = true;
input int VolumeProfilePeriod = 100;
input bool ShowVolumeNodes = true;
input bool DrawSwingPoints = true;
input bool DrawBOS = true;
input bool DrawCHoCH = true;
input bool DrawOrderBlocks = true;
input bool DrawFairValueGaps = true;
input bool DrawDynamicLevels = true;
input bool DrawTrendLines = true;
input bool DrawVolumeProfile = true;
input color SwingPointColor = clrYellow;
input color BOSColor = clrLime;
input color CHoCHColor = clrOrange;
input color BullishOBColor = clrBlue;
input color BearishOBColor = clrRed;
input color FVGColor = clrPurple;
input color SLColor = clrRed;
input color TPColor = clrGreen;
input bool UseVWAP = true;
input bool DrawVWAP = true;
input bool UseVWAPFilter = true;
input double VWAPFilterBuffer = 20;
input ENUM_TIMEFRAMES VWAPTimeframe = PERIOD_D1;
input int VWAPPeriod = 20;
input bool ShowVWAPStatus = true;

// Global Variables
double g_lastHighPrice = 0;
double g_lastLowPrice = 0;
int g_lastHighIndex = 0;
int g_lastLowIndex = 0;
datetime g_lastHighTime = 0;
datetime g_lastLowTime = 0;
bool g_trendUp = true;
int g_zigzagHandle = INVALID_HANDLE;
double g_zigzagBuffer[];
double g_zigzagHighBuffer[];
double g_zigzagLowBuffer[];
double g_volumeProfile[];
double g_vwapBuffer[];
double g_regressionBuffer[];
double g_upperChannelBuffer[];
double g_lowerChannelBuffer[];
double g_atrBuffer[];
int g_atrHandle = INVALID_HANDLE;
int g_tickVolHandle = INVALID_HANDLE;
double g_tickVolBuffer[];
int g_totalBars = 0;
double g_spread = 0;
bool g_newBar = false;

// Structures
struct SwingPoint {
    double price;
    datetime time;
    int index;
    bool isHigh;
    bool confirmed;
};

struct OrderBlock {
    double highPrice;
    double lowPrice;
    datetime startTime;
    datetime endTime;
    bool isBullish;
    bool isValid;
    int strength;
};

struct FairValueGap {
    double upperPrice;
    double lowerPrice;
    datetime time;
    bool isBullish;
    bool filled;
};

struct VolumeNode {
    double price;
    double volume;
    int count;
};

struct LiquidityLevel {
    double price;
    datetime time;
    int touches;
    bool isBroken;
    bool isSupport;
};

// Arrays
SwingPoint g_swingPoints[];
OrderBlock g_orderBlocks[];
FairValueGap g_fairValueGaps[];
VolumeNode g_volumeNodes[];
LiquidityLevel g_liquidityLevels[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("SMC Ultimate Hybrid EA - Initializing...");
    
    // Initialize ZigZag indicator
    g_zigzagHandle = iCustom(_Symbol, _Period, "Examples\\ZigZag", ZigZagDepth, ZigZagDeviation, ZigZagBackstep);
    if (g_zigzagHandle == INVALID_HANDLE) {
        Print("Error creating ZigZag indicator");
        return INIT_FAILED;
    }
    
    // Initialize ATR indicator
    g_atrHandle = iATR(_Symbol, _Period, 14);
    if (g_atrHandle == INVALID_HANDLE) {
        Print("Error creating ATR indicator");
        return INIT_FAILED;
    }
    
    // Initialize Tick Volume indicator
    g_tickVolHandle = iVolumes(_Symbol, _Period, VOLUME_TICK);
    if (g_tickVolHandle == INVALID_HANDLE) {
        Print("Error creating Tick Volume indicator");
        return INIT_FAILED;
    }
    
    // Set array properties
    ArraySetAsSeries(g_zigzagBuffer, true);
    ArraySetAsSeries(g_zigzagHighBuffer, true);
    ArraySetAsSeries(g_zigzagLowBuffer, true);
    ArraySetAsSeries(g_volumeProfile, true);
    ArraySetAsSeries(g_vwapBuffer, true);
    ArraySetAsSeries(g_regressionBuffer, true);
    ArraySetAsSeries(g_upperChannelBuffer, true);
    ArraySetAsSeries(g_lowerChannelBuffer, true);
    ArraySetAsSeries(g_atrBuffer, true);
    ArraySetAsSeries(g_tickVolBuffer, true);
    
    // Initialize arrays
    ArrayResize(g_swingPoints, 0);
    ArrayResize(g_orderBlocks, 0);
    ArrayResize(g_fairValueGaps, 0);
    ArrayResize(g_volumeNodes, 0);
    ArrayResize(g_liquidityLevels, 0);
    
    g_totalBars = Bars(_Symbol, _Period);
    
    Print("SMC Ultimate Hybrid EA - Initialization Complete");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Release indicator handles
    if (g_zigzagHandle != INVALID_HANDLE) IndicatorRelease(g_zigzagHandle);
    if (g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
    if (g_tickVolHandle != INVALID_HANDLE) IndicatorRelease(g_tickVolHandle);
    
    // Clean up objects
    ObjectsDeleteAll(0, "SMC_");
    
    Print("SMC Ultimate Hybrid EA - Deinitialization Complete");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Check for new bar
    int currentBars = Bars(_Symbol, _Period);
    g_newBar = (currentBars > g_totalBars);
    g_totalBars = currentBars;
    
    // Update spread
    g_spread = (Ask - Bid) / _Point;
    
    // Skip if spread is too high
    if (g_spread > MaxSpread) return;
    
    // Update indicators on new bar
    if (g_newBar) {
        UpdateIndicators();
        AnalyzeMarketStructure();
        ManagePositions();
        
        if (UseZigZag) {
            UpdateZigZagAnalysis();
        }
        
        if (UseVolumeProfile) {
            UpdateVolumeProfile();
        }
        
        if (UseVWAP) {
            UpdateVWAP();
        }
        
        if (UseLinearRegression) {
            UpdateLinearRegression();
        }
        
        DrawStructureOnChart();
    }
    
    // Check for trade signals
    CheckTradeSignals();
}

//+------------------------------------------------------------------+
//| Update all indicators                                            |
//+------------------------------------------------------------------+
void UpdateIndicators() {
    // Copy ZigZag data
    if (CopyBuffer(g_zigzagHandle, 0, 0, 100, g_zigzagBuffer) < 0) {
        Print("Error copying ZigZag buffer");
        return;
    }
    
    // Copy ATR data
    if (CopyBuffer(g_atrHandle, 0, 0, 50, g_atrBuffer) < 0) {
        Print("Error copying ATR buffer");
        return;
    }
    
    // Copy Volume data
    if (CopyBuffer(g_tickVolHandle, 0, 0, 100, g_tickVolBuffer) < 0) {
        Print("Error copying Volume buffer");
        return;
    }
}

//+------------------------------------------------------------------+
//| Update ZigZag analysis                                           |
//+------------------------------------------------------------------+
void UpdateZigZagAnalysis() {
    double swingHighPrice = 0, swingLowPrice = 0;
    datetime swingHighTime = 0, swingLowTime = 0;
    
    // Find latest swing points
    for (int i = 1; i < ArraySize(g_zigzagBuffer); i++) {
        if (g_zigzagBuffer[i] != 0 && g_zigzagBuffer[i] != EMPTY_VALUE) {
            if (g_zigzagBuffer[i] > iClose(_Symbol, _Period, i)) {
                // Swing High found
                swingHighPrice = g_zigzagBuffer[i];
                swingHighTime = iTime(_Symbol, _Period, i);
                break;
            } else {
                // Swing Low found
                swingLowPrice = g_zigzagBuffer[i];
                swingLowTime = iTime(_Symbol, _Period, i);
                break;
            }
        }
    }
    
    // Update global swing point data
    if (swingHighPrice > 0) {
        g_lastHighPrice = swingHighPrice;
        g_lastHighTime = swingHighTime;
        
        if (DrawSwingPoints) {
            DrawSwingPointsOnChart();
        }
    }
    
    if (swingLowPrice > 0) {
        g_lastLowPrice = swingLowPrice;
        g_lastLowTime = swingLowTime;
        
        if (DrawSwingPoints) {
            DrawSwingPointsOnChart();
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze market structure                                         |
//+------------------------------------------------------------------+
void AnalyzeMarketStructure() {
    // BOS Detection
    if (UseBOSConfirmation) {
        DetectBreakOfStructure();
    }
    
    // CHoCH Detection
    if (UseCHoCHFilter) {
        DetectChangeOfCharacter();
    }
    
    // Order Block Detection
    if (UseOrderBlocks) {
        DetectOrderBlocks();
    }
    
    // Fair Value Gap Detection
    if (UseFairValueGaps) {
        DetectFairValueGaps();
    }
    
    // Liquidity Level Detection
    if (UseLiquidityLevels) {
        DetectLiquidityLevels();
    }
}

//+------------------------------------------------------------------+
//| Detect Break of Structure                                        |
//+------------------------------------------------------------------+
void DetectBreakOfStructure() {
    double currentPrice = iClose(_Symbol, _Period, 0);
    
    // Bullish BOS - Price breaks above previous high
    if (g_trendUp) {
        if (currentPrice > g_lastHighPrice) {
            g_trendUp = true;
            if (DrawBOS) {
                DrawBOSSignal(iTime(_Symbol, _Period, 0), currentPrice, true);
            }
        }
        // Bearish BOS - Price breaks below previous low
        if (currentPrice < g_lastLowPrice) {
            g_trendUp = false;
            if (DrawBOS) {
                DrawBOSSignal(iTime(_Symbol, _Period, 0), currentPrice, false);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Detect Change of Character                                       |
//+------------------------------------------------------------------+
void DetectChangeOfCharacter() {
    double currentPrice = iClose(_Symbol, _Period, 0);
    
    // CHoCH occurs when trend changes direction
    if (!g_trendUp) {
        if (currentPrice < g_lastLowPrice) {
            g_trendUp = false;
            // Bearish CHoCH
            if (DrawCHoCH) {
                DrawCHoCHSignal(iTime(_Symbol, _Period, 0), currentPrice, false);
            }
        }
        if (currentPrice > g_lastHighPrice) {
            g_trendUp = true;
            // Bullish CHoCH
            if (DrawCHoCH) {
                DrawCHoCHSignal(iTime(_Symbol, _Period, 0), currentPrice, true);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Detect Order Blocks                                              |
//+------------------------------------------------------------------+
void DetectOrderBlocks() {
    int lookback = 20;
    
    for (int i = 1; i < lookback; i++) {
        // Bearish Order Block detection
        if (iClose(_Symbol, _Period, i) < iOpen(_Symbol, _Period, i) && 
            iClose(_Symbol, _Period, i-1) > iOpen(_Symbol, _Period, i-1) &&
            (iHigh(_Symbol, _Period, i-1) - iLow(_Symbol, _Period, i-1)) > (iHigh(_Symbol, _Period, i) - iLow(_Symbol, _Period, i)) * 1.5) {
            
            // Create bearish order block
            OrderBlock ob;
            ob.highPrice = iHigh(_Symbol, _Period, i-1);
            ob.lowPrice = iLow(_Symbol, _Period, i-1);
            ob.startTime = iTime(_Symbol, _Period, i-1);
            ob.endTime = iTime(_Symbol, _Period, 0);
            ob.isBullish = false;
            ob.isValid = true;
            ob.strength = CalculateOrderBlockStrength(i-1);
            
            ArrayResize(g_orderBlocks, ArraySize(g_orderBlocks) + 1);
            g_orderBlocks[ArraySize(g_orderBlocks) - 1] = ob;
            
            if (DrawOrderBlocks) {
                DrawOrderBlock(ob);
            }
        }
        
        // Bullish Order Block detection
        if (iClose(_Symbol, _Period, i) > iOpen(_Symbol, _Period, i) && 
            iClose(_Symbol, _Period, i-1) < iOpen(_Symbol, _Period, i-1) &&
            (iHigh(_Symbol, _Period, i-1) - iLow(_Symbol, _Period, i-1)) > (iHigh(_Symbol, _Period, i) - iLow(_Symbol, _Period, i)) * 1.5) {
            
            // Create bullish order block
            OrderBlock ob;
            ob.highPrice = iHigh(_Symbol, _Period, i-1);
            ob.lowPrice = iLow(_Symbol, _Period, i-1);
            ob.startTime = iTime(_Symbol, _Period, i-1);
            ob.endTime = iTime(_Symbol, _Period, 0);
            ob.isBullish = true;
            ob.isValid = true;
            ob.strength = CalculateOrderBlockStrength(i-1);
            
            ArrayResize(g_orderBlocks, ArraySize(g_orderBlocks) + 1);
            g_orderBlocks[ArraySize(g_orderBlocks) - 1] = ob;
            
            if (DrawOrderBlocks) {
                DrawOrderBlock(ob);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate Order Block Strength                                   |
//+------------------------------------------------------------------+
int CalculateOrderBlockStrength(int index) {
    int strength = 0;
    
    // Volume-based strength
    if (ArraySize(g_tickVolBuffer) > index) {
        if (g_tickVolBuffer[index] > g_tickVolBuffer[index+1] * 1.2) strength++;
        if (g_tickVolBuffer[index] > g_tickVolBuffer[index+1] * 1.5) strength++;
    }
    
    // Size-based strength
    double candleSize = iHigh(_Symbol, _Period, index) - iLow(_Symbol, _Period, index);
    double atr = ArraySize(g_atrBuffer) > 0 ? g_atrBuffer[0] : 0;
    if (atr > 0 && candleSize > atr * 1.5) strength++;
    
    // Time-based strength
    if (index < 5) strength++; // Recent order blocks are stronger
    
    return strength;
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gaps                                           |
//+------------------------------------------------------------------+
void DetectFairValueGaps() {
    for (int i = 2; i < 50; i++) {
        // Bullish FVG: Gap between high[i+1] and low[i-1]
        if (iHigh(_Symbol, _Period, i+1) < iLow(_Symbol, _Period, i-1)) {
            FairValueGap fvg;
            fvg.upperPrice = iLow(_Symbol, _Period, i-1);
            fvg.lowerPrice = iHigh(_Symbol, _Period, i+1);
            fvg.time = iTime(_Symbol, _Period, i);
            fvg.isBullish = true;
            fvg.filled = false;
            
            ArrayResize(g_fairValueGaps, ArraySize(g_fairValueGaps) + 1);
            g_fairValueGaps[ArraySize(g_fairValueGaps) - 1] = fvg;
            
            if (DrawFairValueGaps) {
                DrawFairValueGap(fvg);
            }
        }
        
        // Bearish FVG: Gap between low[i+1] and high[i-1]
        if (iLow(_Symbol, _Period, i+1) > iHigh(_Symbol, _Period, i-1)) {
            FairValueGap fvg;
            fvg.upperPrice = iLow(_Symbol, _Period, i+1);
            fvg.lowerPrice = iHigh(_Symbol, _Period, i-1);
            fvg.time = iTime(_Symbol, _Period, i);
            fvg.isBullish = false;
            fvg.filled = false;
            
            ArrayResize(g_fairValueGaps, ArraySize(g_fairValueGaps) + 1);
            g_fairValueGaps[ArraySize(g_fairValueGaps) - 1] = fvg;
            
            if (DrawFairValueGaps) {
                DrawFairValueGap(fvg);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Detect Liquidity Levels                                          |
//+------------------------------------------------------------------+
void DetectLiquidityLevels() {
    // Implementation for liquidity level detection
    // This would identify areas where stops are likely to be placed
    for (int i = 1; i < 100; i++) {
        double high = iHigh(_Symbol, _Period, i);
        double low = iLow(_Symbol, _Period, i);
        
        // Check for double tops/bottoms indicating liquidity
        int touches = CountPriceTouches(high, 10, 0.0001);
        if (touches >= 2) {
            LiquidityLevel level;
            level.price = high;
            level.time = iTime(_Symbol, _Period, i);
            level.touches = touches;
            level.isBroken = false;
            level.isSupport = false;
            
            ArrayResize(g_liquidityLevels, ArraySize(g_liquidityLevels) + 1);
            g_liquidityLevels[ArraySize(g_liquidityLevels) - 1] = level;
        }
        
        touches = CountPriceTouches(low, 10, 0.0001);
        if (touches >= 2) {
            LiquidityLevel level;
            level.price = low;
            level.time = iTime(_Symbol, _Period, i);
            level.touches = touches;
            level.isBroken = false;
            level.isSupport = true;
            
            ArrayResize(g_liquidityLevels, ArraySize(g_liquidityLevels) + 1);
            g_liquidityLevels[ArraySize(g_liquidityLevels) - 1] = level;
        }
    }
}

//+------------------------------------------------------------------+
//| Count price touches                                              |
//+------------------------------------------------------------------+
int CountPriceTouches(double price, int lookback, double tolerance) {
    int touches = 0;
    for (int i = 0; i < lookback; i++) {
        if (MathAbs(iHigh(_Symbol, _Period, i) - price) <= tolerance ||
            MathAbs(iLow(_Symbol, _Period, i) - price) <= tolerance) {
            touches++;
        }
    }
    return touches;
}

//+------------------------------------------------------------------+
//| Update Volume Profile                                            |
//+------------------------------------------------------------------+
void UpdateVolumeProfile() {
    ArrayResize(g_volumeProfile, VolumeProfilePeriod);
    ArrayInitialize(g_volumeProfile, 0);
    
    double highestPrice = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, VolumeProfilePeriod, 0));
    double lowestPrice = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, VolumeProfilePeriod, 0));
    double priceStep = (highestPrice - lowestPrice) / VolumeProfilePeriod;
    
    // Calculate volume at each price level
    for (int i = 0; i < VolumeProfilePeriod; i++) {
        double volume = 0;
        double priceLevel = lowestPrice + (i * priceStep);
        
        for (int j = 0; j < VolumeProfilePeriod; j++) {
            if (iLow(_Symbol, _Period, j) <= priceLevel && iHigh(_Symbol, _Period, j) >= priceLevel) {
                if (ArraySize(g_tickVolBuffer) > j) {
                    volume += g_tickVolBuffer[j];
                }
            }
        }
        
        g_volumeProfile[i] = volume;
    }
    
    // Find volume nodes
    FindVolumeNodes(lowestPrice, priceStep);
}

//+------------------------------------------------------------------+
//| Find Volume Nodes                                                |
//+------------------------------------------------------------------+
void FindVolumeNodes(double basePrice, double priceStep) {
    ArrayResize(g_volumeNodes, 0);
    
    for (int i = 1; i < ArraySize(g_volumeProfile) - 1; i++) {
        // High Volume Node (HVN)
        if (g_volumeProfile[i] > g_volumeProfile[i-1] && 
            g_volumeProfile[i] > g_volumeProfile[i+1]) {
            
            VolumeNode node;
            node.price = basePrice + (i * priceStep);
            node.volume = g_volumeProfile[i];
            node.count = 1;
            
            ArrayResize(g_volumeNodes, ArraySize(g_volumeNodes) + 1);
            g_volumeNodes[ArraySize(g_volumeNodes) - 1] = node;
        }
    }
    
    if (ShowVolumeNodes) {
        DrawVolumeNodes();
    }
}

//+------------------------------------------------------------------+
//| Update VWAP                                                      |
//+------------------------------------------------------------------+
void UpdateVWAP() {
    ArrayResize(g_vwapBuffer, VWAPPeriod);
    
    double sumPriceVolume = 0;
    double sumVolume = 0;
    
    for (int i = 0; i < VWAPPeriod; i++) {
        double typicalPrice = (iHigh(_Symbol, _Period, i) + iLow(_Symbol, _Period, i) + iClose(_Symbol, _Period, i)) / 3;
        double volume = ArraySize(g_tickVolBuffer) > i ? g_tickVolBuffer[i] : 1;
        
        sumPriceVolume += typicalPrice * volume;
        sumVolume += volume;
        
        g_vwapBuffer[i] = sumVolume > 0 ? sumPriceVolume / sumVolume : typicalPrice;
    }
    
    if (DrawVWAP) {
        DrawVWAPLine();
    }
}

//+------------------------------------------------------------------+
//| Update Linear Regression                                         |
//+------------------------------------------------------------------+
void UpdateLinearRegression() {
    ArrayResize(g_regressionBuffer, RegressionPeriod);
    ArrayResize(g_upperChannelBuffer, RegressionPeriod);
    ArrayResize(g_lowerChannelBuffer, RegressionPeriod);
    
    // Calculate linear regression
    for (int i = 0; i < RegressionPeriod; i++) {
        double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
        
        for (int j = 0; j < RegressionPeriod; j++) {
            double x = j;
            double y = iClose(_Symbol, _Period, i + j);
            
            sumX += x;
            sumY += y;
            sumXY += x * y;
            sumX2 += x * x;
        }
        
        double slope = (RegressionPeriod * sumXY - sumX * sumY) / (RegressionPeriod * sumX2 - sumX * sumX);
        double intercept = (sumY - slope * sumX) / RegressionPeriod;
        
        g_regressionBuffer[i] = intercept + slope * 0; // Current bar
        
        // Calculate channel width
        double atr = ArraySize(g_atrBuffer) > 0 ? g_atrBuffer[0] : 0.001;
        double channelWidth = atr * RegressionChannelWidth;
        
        g_upperChannelBuffer[i] = g_regressionBuffer[i] + channelWidth;
        g_lowerChannelBuffer[i] = g_regressionBuffer[i] - channelWidth;
    }
}

//+------------------------------------------------------------------+
//| Check for trade signals                                          |
//+------------------------------------------------------------------+
void CheckTradeSignals() {
    if (PositionsTotal() >= MaxPositions) return;
    
    int confluenceScore = CalculateConfluenceScore();
    
    if (UseConfluenceScoring && confluenceScore < MinConfluenceScore) return;
    
    // Check for bullish signals
    if (IsBullishSignal()) {
        OpenBuyTrade(confluenceScore);
    }
    
    // Check for bearish signals
    if (IsBearishSignal()) {
        OpenSellTrade(confluenceScore);
    }
}

//+------------------------------------------------------------------+
//| Calculate confluence score                                        |
//+------------------------------------------------------------------+
int CalculateConfluenceScore() {
    int score = 0;
    double currentPrice = iClose(_Symbol, _Period, 0);
    
    // ZigZag trend confirmation
    if (UseZigZag && g_trendUp) score++;
    if (UseZigZag && !g_trendUp) score++;
    
    // Order Block confluence
    if (UseOrderBlocks) {
        for (int i = 0; i < ArraySize(g_orderBlocks); i++) {
            if (g_orderBlocks[i].isValid) {
                if (currentPrice >= g_orderBlocks[i].lowPrice && 
                    currentPrice <= g_orderBlocks[i].highPrice) {
                    score += g_orderBlocks[i].strength;
                }
            }
        }
    }
    
    // Fair Value Gap confluence
    if (UseFairValueGaps) {
        for (int i = 0; i < ArraySize(g_fairValueGaps); i++) {
            if (!g_fairValueGaps[i].filled) {
                if (currentPrice >= g_fairValueGaps[i].lowerPrice && 
                    currentPrice <= g_fairValueGaps[i].upperPrice) {
                    score++;
                }
            }
        }
    }
    
    // VWAP confluence
    if (UseVWAP && ArraySize(g_vwapBuffer) > 0) {
        double vwap = g_vwapBuffer[0];
        if (MathAbs(currentPrice - vwap) <= VWAPFilterBuffer * _Point) {
            score++;
        }
    }
    
    // Linear Regression confluence
    if (UseLinearRegression && ArraySize(g_regressionBuffer) > 0) {
        double regression = g_regressionBuffer[0];
        if (MathAbs(currentPrice - regression) <= g_atrBuffer[0] * 0.5) {
            score++;
        }
    }
    
    // Volume confluence
    if (UseVolumeProfile) {
        for (int i = 0; i < ArraySize(g_volumeNodes); i++) {
            if (MathAbs(currentPrice - g_volumeNodes[i].price) <= g_atrBuffer[0] * 0.3) {
                score++;
            }
        }
    }
    
    return score;
}

//+------------------------------------------------------------------+
//| Check for bullish signal                                         |
//+------------------------------------------------------------------+
bool IsBullishSignal() {
    double currentPrice = iClose(_Symbol, _Period, 0);
    
    // Basic trend check
    if (!g_trendUp) return false;
    
    // Price above VWAP
    if (UseVWAPFilter && ArraySize(g_vwapBuffer) > 0) {
        if (currentPrice <= g_vwapBuffer[0]) return false;
    }
    
    // Price near bullish order block
    if (UseOrderBlocks) {
        bool nearBullishOB = false;
        for (int i = 0; i < ArraySize(g_orderBlocks); i++) {
            if (g_orderBlocks[i].isValid && g_orderBlocks[i].isBullish) {
                if (currentPrice >= g_orderBlocks[i].lowPrice && 
                    currentPrice <= g_orderBlocks[i].highPrice) {
                    nearBullishOB = true;
                    break;
                }
            }
        }
        if (!nearBullishOB) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check for bearish signal                                         |
//+------------------------------------------------------------------+
bool IsBearishSignal() {
    double currentPrice = iClose(_Symbol, _Period, 0);
    
    // Basic trend check
    if (g_trendUp) return false;
    
    // Price below VWAP
    if (UseVWAPFilter && ArraySize(g_vwapBuffer) > 0) {
        if (currentPrice >= g_vwapBuffer[0]) return false;
    }
    
    // Price near bearish order block
    if (UseOrderBlocks) {
        bool nearBearishOB = false;
        for (int i = 0; i < ArraySize(g_orderBlocks); i++) {
            if (g_orderBlocks[i].isValid && !g_orderBlocks[i].isBullish) {
                if (currentPrice >= g_orderBlocks[i].lowPrice && 
                    currentPrice <= g_orderBlocks[i].highPrice) {
                    nearBearishOB = true;
                    break;
                }
            }
        }
        if (!nearBearishOB) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Open buy trade                                                   |
//+------------------------------------------------------------------+
void OpenBuyTrade(int confluenceScore) {
    double lotSize = CalculateLotSize();
    double stopLoss = CalculateBuyStopLoss();
    double takeProfit = CalculateBuyTakeProfit();
    
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = Ask;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.magic = MagicNumber;
    request.comment = StringFormat("SMC Buy - Score: %d", confluenceScore);
    
    if (OrderSend(request, result)) {
        Print("Buy order opened successfully. Ticket: ", result.order);
    } else {
        Print("Error opening buy order: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Open sell trade                                                  |
//+------------------------------------------------------------------+
void OpenSellTrade(int confluenceScore) {
    double lotSize = CalculateLotSize();
    double stopLoss = CalculateSellStopLoss();
    double takeProfit = CalculateSellTakeProfit();
    
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = Bid;
    request.sl = stopLoss;
    request.tp = takeProfit;
    request.magic = MagicNumber;
    request.comment = StringFormat("SMC Sell - Score: %d", confluenceScore);
    
    if (OrderSend(request, result)) {
        Print("Sell order opened successfully. Ticket: ", result.order);
    } else {
        Print("Error opening sell order: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Calculate lot size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize() {
    if (RiskPercent > 0) {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = balance * RiskPercent / 100;
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double stopDistance = g_atrBuffer[0] * 2; // 2 ATR stop loss
        
        if (tickValue > 0 && stopDistance > 0) {
            double lotSize = riskAmount / (stopDistance / _Point * tickValue);
            return NormalizeDouble(lotSize, 2);
        }
    }
    
    return FixedLotSize;
}

//+------------------------------------------------------------------+
//| Calculate buy stop loss                                          |
//+------------------------------------------------------------------+
double CalculateBuyStopLoss() {
    double atr = ArraySize(g_atrBuffer) > 0 ? g_atrBuffer[0] : 0.001;
    double currentPrice = Ask;
    
    // Use the lowest order block or swing low
    double stopLevel = currentPrice - (atr * 2);
    
    // Check for recent swing low
    if (g_lastLowPrice > 0 && g_lastLowPrice < currentPrice) {
        double swingStop = g_lastLowPrice - (atr * 0.5);
        if (swingStop > stopLevel) {
            stopLevel = swingStop;
        }
    }
    
    return NormalizeDouble(stopLevel, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate sell stop loss                                         |
//+------------------------------------------------------------------+
double CalculateSellStopLoss() {
    double atr = ArraySize(g_atrBuffer) > 0 ? g_atrBuffer[0] : 0.001;
    double currentPrice = Bid;
    
    // Use the highest order block or swing high
    double stopLevel = currentPrice + (atr * 2);
    
    // Check for recent swing high
    if (g_lastHighPrice > 0 && g_lastHighPrice > currentPrice) {
        double swingStop = g_lastHighPrice + (atr * 0.5);
        if (swingStop < stopLevel) {
            stopLevel = swingStop;
        }
    }
    
    return NormalizeDouble(stopLevel, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate buy take profit                                        |
//+------------------------------------------------------------------+
double CalculateBuyTakeProfit() {
    double atr = ArraySize(g_atrBuffer) > 0 ? g_atrBuffer[0] : 0.001;
    double currentPrice = Ask;
    
    // Target next resistance level or 1:2 RR
    double takeProfit = currentPrice + (atr * 4); // 1:2 risk-reward
    
    // Check for resistance levels (liquidity levels)
    for (int i = 0; i < ArraySize(g_liquidityLevels); i++) {
        if (!g_liquidityLevels[i].isSupport && 
            g_liquidityLevels[i].price > currentPrice &&
            g_liquidityLevels[i].price < takeProfit + (atr * 2)) {
            takeProfit = g_liquidityLevels[i].price - (atr * 0.2);
            break;
        }
    }
    
    return NormalizeDouble(takeProfit, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate sell take profit                                       |
//+------------------------------------------------------------------+
double CalculateSellTakeProfit() {
    double atr = ArraySize(g_atrBuffer) > 0 ? g_atrBuffer[0] : 0.001;
    double currentPrice = Bid;
    
    // Target next support level or 1:2 RR
    double takeProfit = currentPrice - (atr * 4); // 1:2 risk-reward
    
    // Check for support levels (liquidity levels)
    for (int i = 0; i < ArraySize(g_liquidityLevels); i++) {
        if (g_liquidityLevels[i].isSupport && 
            g_liquidityLevels[i].price < currentPrice &&
            g_liquidityLevels[i].price > takeProfit - (atr * 2)) {
            takeProfit = g_liquidityLevels[i].price + (atr * 0.2);
            break;
        }
    }
    
    return NormalizeDouble(takeProfit, _Digits);
}

//+------------------------------------------------------------------+
//| Manage positions                                                 |
//+------------------------------------------------------------------+
void ManagePositions() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            
            if (UseTrailingStop) {
                ApplyTrailingStop(ticket);
            }
            
            if (UseBreakevenStop) {
                ApplyBreakevenStop(ticket);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply trailing stop                                              |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return;
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    double trailDistance = TrailingStopPips * _Point;
    double newSL = 0;
    
    if (posType == POSITION_TYPE_BUY) {
        newSL = Bid - trailDistance;
        if (newSL > currentSL && (currentSL == 0 || newSL > currentSL)) {
            ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
        }
    } else if (posType == POSITION_TYPE_SELL) {
        newSL = Ask + trailDistance;
        if (newSL < currentSL && (currentSL == 0 || newSL < currentSL)) {
            ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
        }
    }
}

//+------------------------------------------------------------------+
//| Apply breakeven stop                                             |
//+------------------------------------------------------------------+
void ApplyBreakevenStop(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return;
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    double breakevenDistance = BreakevenPips * _Point;
    
    if (posType == POSITION_TYPE_BUY) {
        if (Bid >= openPrice + breakevenDistance && (currentSL < openPrice || currentSL == 0)) {
            ModifyPosition(ticket, openPrice, PositionGetDouble(POSITION_TP));
        }
    } else if (posType == POSITION_TYPE_SELL) {
        if (Ask <= openPrice - breakevenDistance && (currentSL > openPrice || currentSL == 0)) {
            ModifyPosition(ticket, openPrice, PositionGetDouble(POSITION_TP));
        }
    }
}

//+------------------------------------------------------------------+
//| Modify position                                                  |
//+------------------------------------------------------------------+
void ModifyPosition(ulong ticket, double sl, double tp) {
    MqlTradeRequest request;
    MqlTradeResult result;
    
    ZeroMemory(request);
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.sl = NormalizeDouble(sl, _Digits);
    request.tp = NormalizeDouble(tp, _Digits);
    
    if (!OrderSend(request, result)) {
        Print("Error modifying position: ", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| Drawing Functions                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw structure on chart                                          |
//+------------------------------------------------------------------+
void DrawStructureOnChart() {
    if (DrawSwingPoints) DrawSwingPointsOnChart();
    if (DrawOrderBlocks) DrawAllOrderBlocks();
    if (DrawFairValueGaps) DrawAllFairValueGaps();
    if (DrawDynamicLevels) DrawDynamicLevels();
    if (DrawTrendLines) DrawTrendStructure();
    if (DrawVolumeProfile) DrawVolumeProfileChart();
}

//+------------------------------------------------------------------+
//| Draw swing points on chart                                       |
//+------------------------------------------------------------------+
void DrawSwingPointsOnChart() {
    if (g_lastHighPrice > 0) {
        string objName = "SMC_SwingHigh_" + TimeToString(g_lastHighTime);
        ObjectCreate(0, objName, OBJ_ARROW_UP, 0, g_lastHighTime, g_lastHighPrice);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, SwingPointColor);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    }
    
    if (g_lastLowPrice > 0) {
        string objName = "SMC_SwingLow_" + TimeToString(g_lastLowTime);
        ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, g_lastLowTime, g_lastLowPrice);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, SwingPointColor);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    }
}

//+------------------------------------------------------------------+
//| Draw BOS signal                                                  |
//+------------------------------------------------------------------+
void DrawBOSSignal(datetime time, double price, bool isBullish) {
    string objName = "SMC_BOS_" + TimeToString(time);
    
    if (isBullish) {
        ObjectCreate(0, objName, OBJ_ARROW_UP, 0, time, price);
    } else {
        ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, time, price);
    }
    
    ObjectSetInteger(0, objName, OBJPROP_COLOR, BOSColor);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
    
    // Add text label
    string labelName = objName + "_Label";
    ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price);
    ObjectSetString(0, labelName, OBJPROP_TEXT, "BOS");
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, BOSColor);
}

//+------------------------------------------------------------------+
//| Draw CHoCH signal                                                |
//+------------------------------------------------------------------+
void DrawCHoCHSignal(datetime time, double price, bool isBullish) {
    string objName = "SMC_CHoCH_" + TimeToString(time);
    
    if (isBullish) {
        ObjectCreate(0, objName, OBJ_ARROW_UP, 0, time, price);
    } else {
        ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, time, price);
    }
    
    ObjectSetInteger(0, objName, OBJPROP_COLOR, CHoCHColor);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
    
    // Add text label
    string labelName = objName + "_Label";
    ObjectCreate(0, labelName, OBJ_TEXT, 0, time, price);
    ObjectSetString(0, labelName, OBJPROP_TEXT, "CHoCH");
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, CHoCHColor);
}

//+------------------------------------------------------------------+
//| Draw order block                                                 |
//+------------------------------------------------------------------+
void DrawOrderBlock(OrderBlock &ob) {
    string objName = "SMC_OB_" + TimeToString(ob.startTime);
    
    ObjectCreate(0, objName, OBJ_RECTANGLE, 0, ob.startTime, ob.highPrice, ob.endTime, ob.lowPrice);
    
    if (ob.isBullish) {
        ObjectSetInteger(0, objName, OBJPROP_COLOR, BullishOBColor);
    } else {
        ObjectSetInteger(0, objName, OBJPROP_COLOR, BearishOBColor);
    }
    
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, objName, OBJPROP_FILL, true);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Draw all order blocks                                            |
//+------------------------------------------------------------------+
void DrawAllOrderBlocks() {
    for (int i = 0; i < ArraySize(g_orderBlocks); i++) {
        if (g_orderBlocks[i].isValid) {
            DrawOrderBlock(g_orderBlocks[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw fair value gap                                              |
//+------------------------------------------------------------------+
void DrawFairValueGap(FairValueGap &fvg) {
    string objName = "SMC_FVG_" + TimeToString(fvg.time);
    
    datetime endTime = TimeCurrent() + PeriodSeconds() * 20; // Extend 20 bars into future
    
    ObjectCreate(0, objName, OBJ_RECTANGLE, 0, fvg.time, fvg.upperPrice, endTime, fvg.lowerPrice);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, FVGColor);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, objName, OBJPROP_FILL, true);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
}

//+------------------------------------------------------------------+
//| Draw all fair value gaps                                         |
//+------------------------------------------------------------------+
void DrawAllFairValueGaps() {
    for (int i = 0; i < ArraySize(g_fairValueGaps); i++) {
        if (!g_fairValueGaps[i].filled) {
            DrawFairValueGap(g_fairValueGaps[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw trend structure                                             |
//+------------------------------------------------------------------+
void DrawTrendStructure() {
    if (g_lastHighPrice > 0 && g_lastLowPrice > 0) {
        string objName = "SMC_TrendLine_" + TimeToString(TimeCurrent());
        
        ObjectCreate(0, objName, OBJ_TREND, 0, g_lastLowTime, g_lastLowPrice, g_lastHighTime, g_lastHighPrice);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true);
    }
}

//+------------------------------------------------------------------+
//| Draw dynamic levels                                              |
//+------------------------------------------------------------------+
void DrawDynamicLevels() {
    // Draw liquidity levels
    for (int i = 0; i < ArraySize(g_liquidityLevels); i++) {
        if (!g_liquidityLevels[i].isBroken) {
            string objName = "SMC_Liquidity_" + IntegerToString(i);
            datetime endTime = TimeCurrent() + PeriodSeconds() * 50;
            
            ObjectCreate(0, objName, OBJ_HLINE, 0, g_liquidityLevels[i].time, g_liquidityLevels[i].price);
            
            if (g_liquidityLevels[i].isSupport) {
                ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGreen);
            } else {
                ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
            }
            
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw VWAP line                                                   |
//+------------------------------------------------------------------+
void DrawVWAPLine() {
    if (ArraySize(g_vwapBuffer) == 0) return;
    
    for (int i = 1; i < ArraySize(g_vwapBuffer); i++) {
        string objName = "SMC_VWAP_" + IntegerToString(i);
        
        ObjectCreate(0, objName, OBJ_TREND, 0, 
                    iTime(_Symbol, _Period, i), g_vwapBuffer[i],
                    iTime(_Symbol, _Period, i-1), g_vwapBuffer[i-1]);
                    
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
    }
}

//+------------------------------------------------------------------+
//| Draw volume nodes                                                |
//+------------------------------------------------------------------+
void DrawVolumeNodes() {
    for (int i = 0; i < ArraySize(g_volumeNodes); i++) {
        string objName = "SMC_VolumeNode_" + IntegerToString(i);
        
        ObjectCreate(0, objName, OBJ_HLINE, 0, TimeCurrent(), g_volumeNodes[i].price);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrAqua);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        
        // Add volume text
        string labelName = objName + "_Label";
        ObjectCreate(0, labelName, OBJ_TEXT, 0, TimeCurrent(), g_volumeNodes[i].price);
        ObjectSetString(0, labelName, OBJPROP_TEXT, DoubleToString(g_volumeNodes[i].volume, 0));
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrAqua);
    }
}

//+------------------------------------------------------------------+
//| Draw volume profile chart                                        |
//+------------------------------------------------------------------+
void DrawVolumeProfileChart() {
    if (ArraySize(g_volumeProfile) == 0) return;
    
    // This would create a histogram-style volume profile
    // Implementation depends on specific visualization requirements
    for (int i = 0; i < ArraySize(g_volumeProfile); i++) {
        if (g_volumeProfile[i] > 0) {
            string objName = "SMC_VP_" + IntegerToString(i);
            // Draw volume bars as horizontal lines or rectangles
            // Implementation details would go here
        }
    }
}