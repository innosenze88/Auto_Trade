//+------------------------------------------------------------------+
//|                                          SMC_Ultimate_Hybrid_EA |
//|                         Copyright 2024, Auto_Trade Development  |
//|                                   Ultimate SMC Trading Solution |
//+------------------------------------------------------------------+
#property copyright "Auto_Trade Development"
#property link      "https://github.com/innosenze88/Auto_Trade"
#property version   "1.000"
#property description "Ultimate Hybrid EA combining the best features from all SMC EAs"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

CTrade trade;
CPositionInfo position;
COrderInfo order;

//--- Input Parameters Categories
input group "=== PRESET MODES ===";
enum ENUM_PRESET_MODE {
    PRESET_CONSERVATIVE,    // Conservative Mode
    PRESET_BALANCED,       // Balanced Mode
    PRESET_AGGRESSIVE,     // Aggressive Mode
    PRESET_CUSTOM         // Custom Mode
};
input ENUM_PRESET_MODE PresetMode = PRESET_BALANCED;

input group "=== GENERAL SETTINGS ===";
input double LotSize = 0.01;
input int MagicNumber = 123456;
input bool UseAutoLot = true;
input double RiskPercent = 2.0;
input int MaxOpenPositions = 3;
input int MaxDailyTrades = 10;
input double MaxDailyLoss = 100.0;
input double TakeProfitPoints = 500;
input double StopLossPoints = 250;

input group "=== SMC SETTINGS ===";
input bool UseBOSConfirmation = true;
input bool UseCHoCHFilter = true;
input bool UseOrderBlocks = true;
input bool UseFairValueGaps = true;
input bool UseVolumeProfile = true;
input int OrderBlockLookback = 50;
input int FVGLookback = 20;
input double MinFVGSize = 100;
input double OBBuffer = 50;

input group "=== VWAP SYSTEM ===";
input bool UseVWAP = true;
input bool DrawVWAP = true;
input bool UseVWAPFilter = true;
input double VWAPFilterBuffer = 20;
input ENUM_TIMEFRAMES VWAPTimeframe = PERIOD_D1;
input int VWAPPeriod = 20;
input bool ShowVWAPStatus = true;

input group "=== GRID RECOVERY SYSTEM ===";
input bool UseGridRecovery = false;
input double GridStepPoints = 200;
input int MaxGridLevels = 5;
input double GridLotMultiplier = 1.5;
input bool EnableAddOnStrategy = true;
input int AddOnStepPoints = 150;
input double AddOnLotMultiplier = 1.3;

input group "=== LINEAR REGRESSION ===";
input bool UseLinearRegression = true;
input int RegressionPeriod = 50;
input double RegressionDeviation = 2.0;
input ENUM_TIMEFRAMES HTF_Timeframe = PERIOD_H4;
input ENUM_TIMEFRAMES CTF_Timeframe = PERIOD_H1;
input bool RequireHTFAlignment = true;

input group "=== TRAILING STOP ===";
input bool UseTrailingStop = true;
input double TrailingStopPoints = 100;
input double TrailingStepPoints = 50;
input bool UseBreakevenStop = true;
input double BreakevenTriggerPoints = 200;
input double BreakevenStopPoints = 20;

input group "=== TIME FILTERS ===";
input bool UseTimeFilter = false;
input int StartHour = 8;
input int EndHour = 17;
input bool AvoidNews = true;
input bool TradeMonday = true;
input bool TradeFriday = false;

input group "=== CONFLUENCE SCORING ===";
input bool UseConfluenceScoring = true;
input int MinConfluenceScore = 3;
input int MaxConfluenceScore = 10;
input double ScoreWeight_SMC = 2.0;
input double ScoreWeight_VWAP = 1.5;
input double ScoreWeight_Regression = 1.5;
input double ScoreWeight_Volume = 1.0;

//--- State Machine Enums
enum ENUM_EA_STATE {
    STATE_IDLE,
    STATE_SCANNING_MARKET,
    STATE_STRUCTURE_ANALYSIS,
    STATE_CONFIRMATION_PENDING,
    STATE_ENTRY_SETUP,
    STATE_POSITION_MANAGEMENT,
    STATE_EXIT_ANALYSIS,
    STATE_RISK_CHECK
};

enum ENUM_MARKET_STRUCTURE {
    STRUCTURE_BULLISH,
    STRUCTURE_BEARISH,
    STRUCTURE_CONSOLIDATION,
    STRUCTURE_UNKNOWN
};

enum ENUM_SIGNAL_STRENGTH {
    SIGNAL_WEAK = 1,
    SIGNAL_MEDIUM = 2,
    SIGNAL_STRONG = 3,
    SIGNAL_VERY_STRONG = 4
};

//--- Global Variables
ENUM_EA_STATE g_currentState = STATE_IDLE;
ENUM_MARKET_STRUCTURE g_marketStructure = STRUCTURE_UNKNOWN;
double g_vwapValue = 0;
double g_regressionUpper = 0;
double g_regressionLower = 0;
double g_regressionMid = 0;
double g_dailyLoss = 0;
int g_dailyTrades = 0;
datetime g_lastTradeTime = 0;
datetime g_lastAnalysisTime = 0;
datetime g_currentDay = 0;

//--- Arrays for Analysis
double g_highs[], g_lows[], g_closes[], g_volumes[];
double g_vwap_array[];
bool g_orderBlocks[];
bool g_fairValueGaps[];

//--- Performance Optimization
int g_tickCounter = 0;
datetime g_lastTickTime = 0;
bool g_fastMode = false;

//--- Grid Recovery Arrays
double g_gridLevels[];
double g_gridLots[];
int g_gridTickets[];
int g_activeGridLevels = 0;

//--- Drawing Objects
long g_chartID = 0;
string g_vwapObjectName = "VWAP_Line";
string g_statusObjectName = "EA_Status";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("=== SMC Ultimate Hybrid EA Starting ===");
    
    // Initialize chart ID
    g_chartID = ChartID();
    
    // Apply Preset Settings
    ApplyPresetSettings();
    
    // Initialize arrays
    InitializeArrays();
    
    // Setup drawing objects
    SetupDrawingObjects();
    
    // Reset daily counters
    ResetDailyCounters();
    
    // Initialize VWAP
    InitializeVWAP();
    
    // Set initial state
    g_currentState = STATE_IDLE;
    
    Print("EA initialized successfully with Preset Mode: ", EnumToString(PresetMode));
    UpdateStatusDisplay("EA INITIALIZED");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("=== SMC Ultimate Hybrid EA Stopping ===");
    
    // Clean up drawing objects
    CleanupDrawingObjects();
    
    // Save performance data
    SavePerformanceData();
    
    Print("EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function - Main State Machine                       |
//+------------------------------------------------------------------+
void OnTick() {
    // Performance optimization - limit tick processing
    g_tickCounter++;
    datetime currentTime = TimeCurrent();
    
    if (currentTime == g_lastTickTime) return;
    g_lastTickTime = currentTime;
    
    // Check if new day for daily reset
    CheckDailyReset();
    
    // Daily risk check
    if (g_dailyLoss >= MaxDailyLoss || g_dailyTrades >= MaxDailyTrades) {
        g_currentState = STATE_RISK_CHECK;
        UpdateStatusDisplay("DAILY LIMIT REACHED");
        return;
    }
    
    // State Machine Logic
    switch(g_currentState) {
        case STATE_IDLE:
            if (ShouldStartAnalysis()) {
                g_currentState = STATE_SCANNING_MARKET;
                UpdateStatusDisplay("SCANNING MARKET");
            }
            break;
            
        case STATE_SCANNING_MARKET:
            if (PerformMarketScan()) {
                g_currentState = STATE_STRUCTURE_ANALYSIS;
                UpdateStatusDisplay("ANALYZING STRUCTURE");
            }
            break;
            
        case STATE_STRUCTURE_ANALYSIS:
            if (AnalyzeMarketStructure()) {
                g_currentState = STATE_CONFIRMATION_PENDING;
                UpdateStatusDisplay("WAITING CONFIRMATION");
            } else {
                g_currentState = STATE_IDLE;
            }
            break;
            
        case STATE_CONFIRMATION_PENDING:
            if (CheckEntryConfirmation()) {
                g_currentState = STATE_ENTRY_SETUP;
                UpdateStatusDisplay("PREPARING ENTRY");
            } else if (IsConfirmationExpired()) {
                g_currentState = STATE_IDLE;
                UpdateStatusDisplay("CONFIRMATION EXPIRED");
            }
            break;
            
        case STATE_ENTRY_SETUP:
            if (ExecuteEntry()) {
                g_currentState = STATE_POSITION_MANAGEMENT;
                UpdateStatusDisplay("MANAGING POSITION");
            } else {
                g_currentState = STATE_IDLE;
                UpdateStatusDisplay("ENTRY FAILED");
            }
            break;
            
        case STATE_POSITION_MANAGEMENT:
            ManageOpenPositions();
            if (PositionsTotal() == 0) {
                g_currentState = STATE_IDLE;
                UpdateStatusDisplay("NO POSITIONS");
            }
            break;
            
        case STATE_EXIT_ANALYSIS:
            if (ShouldClosePositions()) {
                CloseAllPositions();
                g_currentState = STATE_IDLE;
                UpdateStatusDisplay("POSITIONS CLOSED");
            } else {
                g_currentState = STATE_POSITION_MANAGEMENT;
            }
            break;
            
        case STATE_RISK_CHECK:
            UpdateStatusDisplay("RISK CHECK MODE");
            // Stay in this state until next day
            break;
    }
    
    // Update VWAP and visual elements
    if (UseVWAP) {
        UpdateVWAP();
    }
    
    // Update drawing objects
    UpdateDrawingObjects();
}

//+------------------------------------------------------------------+
//| Apply Preset Settings                                           |
//+------------------------------------------------------------------+
void ApplyPresetSettings() {
    switch(PresetMode) {
        case PRESET_CONSERVATIVE:
            // Conservative settings
            TakeProfitPoints = 300;
            StopLossPoints = 150;
            MinConfluenceScore = 4;
            UseVWAPFilter = true;
            RequireHTFAlignment = true;
            UseGridRecovery = false;
            MaxOpenPositions = 1;
            break;
            
        case PRESET_BALANCED:
            // Balanced settings (default values)
            TakeProfitPoints = 500;
            StopLossPoints = 250;
            MinConfluenceScore = 3;
            UseVWAPFilter = true;
            RequireHTFAlignment = true;
            UseGridRecovery = false;
            MaxOpenPositions = 2;
            break;
            
        case PRESET_AGGRESSIVE:
            // Aggressive settings
            TakeProfitPoints = 800;
            StopLossPoints = 400;
            MinConfluenceScore = 2;
            UseVWAPFilter = false;
            RequireHTFAlignment = false;
            UseGridRecovery = true;
            MaxOpenPositions = 3;
            break;
            
        case PRESET_CUSTOM:
            // Use user-defined settings
            break;
    }
    
    Print("Applied preset settings: ", EnumToString(PresetMode));
}

//+------------------------------------------------------------------+
//| Initialize Arrays                                               |
//+------------------------------------------------------------------+
void InitializeArrays() {
    ArrayResize(g_highs, 200);
    ArrayResize(g_lows, 200);
    ArrayResize(g_closes, 200);
    ArrayResize(g_volumes, 200);
    ArrayResize(g_vwap_array, 200);
    ArrayResize(g_orderBlocks, 200);
    ArrayResize(g_fairValueGaps, 200);
    
    if (UseGridRecovery) {
        ArrayResize(g_gridLevels, MaxGridLevels);
        ArrayResize(g_gridLots, MaxGridLevels);
        ArrayResize(g_gridTickets, MaxGridLevels);
        ArrayInitialize(g_gridLevels, 0);
        ArrayInitialize(g_gridLots, 0);
        ArrayInitialize(g_gridTickets, 0);
    }
}

//+------------------------------------------------------------------+
//| Setup Drawing Objects                                           |
//+------------------------------------------------------------------+
void SetupDrawingObjects() {
    if (DrawVWAP) {
        ObjectCreate(g_chartID, g_vwapObjectName, OBJ_TREND, 0, 0, 0, 0, 0);
        ObjectSetInteger(g_chartID, g_vwapObjectName, OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(g_chartID, g_vwapObjectName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(g_chartID, g_vwapObjectName, OBJPROP_STYLE, STYLE_SOLID);
    }
    
    if (ShowVWAPStatus) {
        ObjectCreate(g_chartID, g_statusObjectName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(g_chartID, g_statusObjectName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(g_chartID, g_statusObjectName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(g_chartID, g_statusObjectName, OBJPROP_YDISTANCE, 30);
        ObjectSetInteger(g_chartID, g_statusObjectName, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(g_chartID, g_statusObjectName, OBJPROP_FONTSIZE, 10);
    }
}

//+------------------------------------------------------------------+
//| Initialize VWAP                                                 |
//+------------------------------------------------------------------+
void InitializeVWAP() {
    if (!UseVWAP) return;
    
    // Calculate initial VWAP value
    CalculateVWAP();
    
    Print("VWAP initialized. Current value: ", DoubleToString(g_vwapValue, _Digits));
}

//+------------------------------------------------------------------+
//| Should Start Analysis                                           |
//+------------------------------------------------------------------+
bool ShouldStartAnalysis() {
    // Time filter check
    if (UseTimeFilter && !IsWithinTradingHours()) {
        return false;
    }
    
    // Check if enough time passed since last analysis
    if (TimeCurrent() - g_lastAnalysisTime < 60) { // 1 minute minimum
        return false;
    }
    
    // Check if we have open positions at max
    if (PositionsTotal() >= MaxOpenPositions) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Perform Market Scan                                            |
//+------------------------------------------------------------------+
bool PerformMarketScan() {
    // Update market data
    UpdateMarketData();
    
    // Check basic conditions
    if (!HasSufficientData()) {
        return false;
    }
    
    // Update VWAP if enabled
    if (UseVWAP) {
        CalculateVWAP();
    }
    
    // Update Linear Regression if enabled
    if (UseLinearRegression) {
        CalculateLinearRegression();
    }
    
    g_lastAnalysisTime = TimeCurrent();
    return true;
}

//+------------------------------------------------------------------+
//| Analyze Market Structure                                        |
//+------------------------------------------------------------------+
bool AnalyzeMarketStructure() {
    // Detect current market structure
    g_marketStructure = DetectMarketStructure();
    
    if (g_marketStructure == STRUCTURE_UNKNOWN) {
        return false;
    }
    
    // Look for SMC patterns
    bool smcSignal = AnalyzeSMCPatterns();
    if (!smcSignal) {
        return false;
    }
    
    // Check confluence if enabled
    if (UseConfluenceScoring) {
        int confluenceScore = CalculateConfluenceScore();
        if (confluenceScore < MinConfluenceScore) {
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check Entry Confirmation                                        |
//+------------------------------------------------------------------+
bool CheckEntryConfirmation() {
    // Check VWAP confirmation if enabled
    if (UseVWAP && UseVWAPFilter) {
        if (!IsVWAPConfirmed()) {
            return false;
        }
    }
    
    // Check Linear Regression confirmation if enabled
    if (UseLinearRegression && RequireHTFAlignment) {
        if (!IsRegressionAligned()) {
            return false;
        }
    }
    
    // Check SMC confirmation
    if (!IsSMCConfirmed()) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Execute Entry                                                   |
//+------------------------------------------------------------------+
bool ExecuteEntry() {
    // Determine trade direction
    ENUM_ORDER_TYPE orderType = (g_marketStructure == STRUCTURE_BULLISH) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    
    // Calculate position size
    double lotSize = CalculatePositionSize();
    if (lotSize <= 0) {
        return false;
    }
    
    // Calculate entry price
    double entryPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate SL and TP
    double stopLoss = CalculateStopLoss(orderType, entryPrice);
    double takeProfit = CalculateTakeProfit(orderType, entryPrice);
    
    // Execute trade
    bool result = false;
    if (orderType == ORDER_TYPE_BUY) {
        result = trade.Buy(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "SMC_Ultimate_BUY");
    } else {
        result = trade.Sell(lotSize, _Symbol, entryPrice, stopLoss, takeProfit, "SMC_Ultimate_SELL");
    }
    
    if (result) {
        g_dailyTrades++;
        g_lastTradeTime = TimeCurrent();
        Print("Trade executed: ", EnumToString(orderType), " ", lotSize, " lots");
        
        // Setup grid recovery if enabled
        if (UseGridRecovery) {
            SetupGridRecovery(orderType, entryPrice, lotSize);
        }
    } else {
        Print("Trade execution failed. Error: ", GetLastError());
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Manage Open Positions                                          |
//+------------------------------------------------------------------+
void ManageOpenPositions() {
    for (int i = 0; i < PositionsTotal(); i++) {
        if (position.SelectByIndex(i)) {
            if (position.Symbol() != _Symbol || position.Magic() != MagicNumber) continue;
            
            // Apply trailing stop
            if (UseTrailingStop) {
                ApplyTrailingStop(position.Ticket());
            }
            
            // Apply breakeven
            if (UseBreakevenStop) {
                ApplyBreakevenStop(position.Ticket());
            }
            
            // Check for structural exit
            if (ShouldExitOnStructuralChange(position.Ticket())) {
                trade.PositionClose(position.Ticket());
                Print("Position closed due to structural change: ", position.Ticket());
            }
            
            // Grid recovery management
            if (UseGridRecovery) {
                ManageGridRecovery(position.Ticket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate VWAP                                                  |
//+------------------------------------------------------------------+
void CalculateVWAP() {
    double totalVolume = 0;
    double totalPriceVolume = 0;
    
    for (int i = 0; i < VWAPPeriod; i++) {
        double high = iHigh(_Symbol, VWAPTimeframe, i);
        double low = iLow(_Symbol, VWAPTimeframe, i);
        double close = iClose(_Symbol, VWAPTimeframe, i);
        double volume = iVolume(_Symbol, VWAPTimeframe, i);
        
        if (volume <= 0) continue;
        
        double typicalPrice = (high + low + close) / 3.0;
        totalPriceVolume += typicalPrice * volume;
        totalVolume += volume;
    }
    
    if (totalVolume > 0) {
        g_vwapValue = totalPriceVolume / totalVolume;
    }
}

//+------------------------------------------------------------------+
//| Calculate Linear Regression                                     |
//+------------------------------------------------------------------+
void CalculateLinearRegression() {
    // Simple linear regression calculation
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    int n = RegressionPeriod;
    
    for (int i = 0; i < n; i++) {
        double price = iClose(_Symbol, PERIOD_CURRENT, i);
        sumX += i;
        sumY += price;
        sumXY += i * price;
        sumX2 += i * i;
    }
    
    double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    double intercept = (sumY - slope * sumX) / n;
    
    // Calculate current regression line value
    g_regressionMid = intercept + slope * 0; // Current bar
    
    // Calculate standard deviation for bands
    double variance = 0;
    for (int i = 0; i < n; i++) {
        double price = iClose(_Symbol, PERIOD_CURRENT, i);
        double regressionValue = intercept + slope * i;
        variance += MathPow(price - regressionValue, 2);
    }
    double stdDev = MathSqrt(variance / n);
    
    g_regressionUpper = g_regressionMid + (RegressionDeviation * stdDev);
    g_regressionLower = g_regressionMid - (RegressionDeviation * stdDev);
}

//+------------------------------------------------------------------+
//| Detect Market Structure                                         |
//+------------------------------------------------------------------+
ENUM_MARKET_STRUCTURE DetectMarketStructure() {
    // Simple structure detection based on recent highs and lows
    double recentHigh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 1));
    double recentLow = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 20, 1));
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    double range = recentHigh - recentLow;
    double pricePosition = (currentPrice - recentLow) / range;
    
    if (pricePosition > 0.7) {
        return STRUCTURE_BULLISH;
    } else if (pricePosition < 0.3) {
        return STRUCTURE_BEARISH;
    } else {
        return STRUCTURE_CONSOLIDATION;
    }
}

//+------------------------------------------------------------------+
//| Analyze SMC Patterns                                           |
//+------------------------------------------------------------------+
bool AnalyzeSMCPatterns() {
    bool signal = false;
    
    // Check for BOS if enabled
    if (UseBOSConfirmation) {
        signal = signal || DetectBOS();
    }
    
    // Check for CHoCH if enabled
    if (UseCHoCHFilter) {
        signal = signal || DetectCHoCH();
    }
    
    // Check for Order Blocks if enabled
    if (UseOrderBlocks) {
        signal = signal || DetectOrderBlocks();
    }
    
    // Check for Fair Value Gaps if enabled
    if (UseFairValueGaps) {
        signal = signal || DetectFairValueGaps();
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Detect Break of Structure                                       |
//+------------------------------------------------------------------+
bool DetectBOS() {
    // Simple BOS detection - price breaking recent significant level
    double recentHigh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 1));
    double recentLow = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 20, 1));
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // Bullish BOS - current price above recent high
    if (g_marketStructure == STRUCTURE_BULLISH && currentPrice > recentHigh) {
        return true;
    }
    
    // Bearish BOS - current price below recent low
    if (g_marketStructure == STRUCTURE_BEARISH && currentPrice < recentLow) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect Change of Character                                      |
//+------------------------------------------------------------------+
bool DetectCHoCH() {
    // Simple CHoCH detection - reversal pattern
    double ma_fast = iMA(_Symbol, PERIOD_CURRENT, 10, 0, MODE_EMA, PRICE_CLOSE, 0);
    double ma_slow = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    double ma_fast_prev = iMA(_Symbol, PERIOD_CURRENT, 10, 0, MODE_EMA, PRICE_CLOSE, 1);
    double ma_slow_prev = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
    
    // Bullish CHoCH - fast MA crosses above slow MA
    if (ma_fast > ma_slow && ma_fast_prev <= ma_slow_prev) {
        g_marketStructure = STRUCTURE_BULLISH;
        return true;
    }
    
    // Bearish CHoCH - fast MA crosses below slow MA
    if (ma_fast < ma_slow && ma_fast_prev >= ma_slow_prev) {
        g_marketStructure = STRUCTURE_BEARISH;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect Order Blocks                                            |
//+------------------------------------------------------------------+
bool DetectOrderBlocks() {
    // Simple order block detection based on volume and price action
    for (int i = 1; i < OrderBlockLookback; i++) {
        double volume = iVolume(_Symbol, PERIOD_CURRENT, i);
        double avgVolume = 0;
        
        // Calculate average volume
        for (int j = i; j < i + 10; j++) {
            avgVolume += iVolume(_Symbol, PERIOD_CURRENT, j);
        }
        avgVolume /= 10;
        
        // High volume candle indicates potential order block
        if (volume > avgVolume * 1.5) {
            double high = iHigh(_Symbol, PERIOD_CURRENT, i);
            double low = iLow(_Symbol, PERIOD_CURRENT, i);
            double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
            
            // Check if current price is near this level
            if (MathAbs(currentPrice - high) < OBBuffer * _Point || 
                MathAbs(currentPrice - low) < OBBuffer * _Point) {
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gaps                                         |
//+------------------------------------------------------------------+
bool DetectFairValueGaps() {
    for (int i = 2; i < FVGLookback; i++) {
        double high1 = iHigh(_Symbol, PERIOD_CURRENT, i + 1);
        double low1 = iLow(_Symbol, PERIOD_CURRENT, i + 1);
        double high2 = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low2 = iLow(_Symbol, PERIOD_CURRENT, i);
        double high3 = iHigh(_Symbol, PERIOD_CURRENT, i - 1);
        double low3 = iLow(_Symbol, PERIOD_CURRENT, i - 1);
        
        // Bullish FVG - gap between candle 1 high and candle 3 low
        if (low3 > high1) {
            double gapSize = (low3 - high1) / _Point;
            if (gapSize >= MinFVGSize) {
                double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
                if (currentPrice >= high1 && currentPrice <= low3) {
                    return true;
                }
            }
        }
        
        // Bearish FVG - gap between candle 1 low and candle 3 high
        if (high3 < low1) {
            double gapSize = (low1 - high3) / _Point;
            if (gapSize >= MinFVGSize) {
                double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
                if (currentPrice <= low1 && currentPrice >= high3) {
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate Confluence Score                                      |
//+------------------------------------------------------------------+
int CalculateConfluenceScore() {
    double score = 0;
    
    // SMC signals contribution
    if (DetectBOS()) score += ScoreWeight_SMC;
    if (DetectCHoCH()) score += ScoreWeight_SMC;
    if (DetectOrderBlocks()) score += ScoreWeight_SMC * 0.5;
    if (DetectFairValueGaps()) score += ScoreWeight_SMC * 0.5;
    
    // VWAP contribution
    if (UseVWAP) {
        double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
        if (g_marketStructure == STRUCTURE_BULLISH && currentPrice > g_vwapValue) {
            score += ScoreWeight_VWAP;
        } else if (g_marketStructure == STRUCTURE_BEARISH && currentPrice < g_vwapValue) {
            score += ScoreWeight_VWAP;
        }
    }
    
    // Linear Regression contribution
    if (UseLinearRegression) {
        double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
        if (g_marketStructure == STRUCTURE_BULLISH && currentPrice > g_regressionMid) {
            score += ScoreWeight_Regression;
        } else if (g_marketStructure == STRUCTURE_BEARISH && currentPrice < g_regressionMid) {
            score += ScoreWeight_Regression;
        }
    }
    
    // Volume contribution
    double currentVolume = iVolume(_Symbol, PERIOD_CURRENT, 0);
    double avgVolume = 0;
    for (int i = 1; i <= 10; i++) {
        avgVolume += iVolume(_Symbol, PERIOD_CURRENT, i);
    }
    avgVolume /= 10;
    
    if (currentVolume > avgVolume * 1.2) {
        score += ScoreWeight_Volume;
    }
    
    return (int)MathRound(score);
}

//+------------------------------------------------------------------+
//| Is VWAP Confirmed                                              |
//+------------------------------------------------------------------+
bool IsVWAPConfirmed() {
    if (!UseVWAP) return true;
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double buffer = VWAPFilterBuffer * _Point;
    
    if (g_marketStructure == STRUCTURE_BULLISH) {
        return currentPrice > (g_vwapValue + buffer);
    } else if (g_marketStructure == STRUCTURE_BEARISH) {
        return currentPrice < (g_vwapValue - buffer);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Is Regression Aligned                                          |
//+------------------------------------------------------------------+
bool IsRegressionAligned() {
    if (!UseLinearRegression) return true;
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    if (g_marketStructure == STRUCTURE_BULLISH) {
        return currentPrice > g_regressionLower;
    } else if (g_marketStructure == STRUCTURE_BEARISH) {
        return currentPrice < g_regressionUpper;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Is SMC Confirmed                                               |
//+------------------------------------------------------------------+
bool IsSMCConfirmed() {
    // Additional SMC confirmation logic
    bool bosConfirmed = !UseBOSConfirmation || DetectBOS();
    bool chochConfirmed = !UseCHoCHFilter || DetectCHoCH();
    bool obConfirmed = !UseOrderBlocks || DetectOrderBlocks();
    bool fvgConfirmed = !UseFairValueGaps || DetectFairValueGaps();
    
    return bosConfirmed && chochConfirmed && (obConfirmed || fvgConfirmed);
}

//+------------------------------------------------------------------+
//| Calculate Position Size                                         |
//+------------------------------------------------------------------+
double CalculatePositionSize() {
    double lotSize = LotSize;
    
    if (UseAutoLot && RiskPercent > 0) {
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = accountBalance * RiskPercent / 100.0;
        double stopLossPoints = StopLossPoints;
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        
        if (stopLossPoints > 0 && tickValue > 0) {
            lotSize = riskAmount / (stopLossPoints * tickValue);
        }
    }
    
    // Apply lot size limits
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if (lotSize < minLot) lotSize = minLot;
    if (lotSize > maxLot) lotSize = maxLot;
    
    // Round to lot step
    lotSize = MathRound(lotSize / lotStep) * lotStep;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss                                            |
//+------------------------------------------------------------------+
double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice) {
    double stopLoss = 0;
    
    if (orderType == ORDER_TYPE_BUY) {
        stopLoss = entryPrice - (StopLossPoints * _Point);
    } else {
        stopLoss = entryPrice + (StopLossPoints * _Point);
    }
    
    return stopLoss;
}

//+------------------------------------------------------------------+
//| Calculate Take Profit                                          |
//+------------------------------------------------------------------+
double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice) {
    double takeProfit = 0;
    
    if (orderType == ORDER_TYPE_BUY) {
        takeProfit = entryPrice + (TakeProfitPoints * _Point);
    } else {
        takeProfit = entryPrice - (TakeProfitPoints * _Point);
    }
    
    return takeProfit;
}

//+------------------------------------------------------------------+
//| Setup Grid Recovery                                            |
//+------------------------------------------------------------------+
void SetupGridRecovery(ENUM_ORDER_TYPE orderType, double entryPrice, double lotSize) {
    if (!UseGridRecovery) return;
    
    g_activeGridLevels = 1;
    g_gridLevels[0] = entryPrice;
    g_gridLots[0] = lotSize;
    g_gridTickets[0] = trade.ResultOrder();
    
    Print("Grid recovery setup. Entry level: ", entryPrice, " Lot: ", lotSize);
}

//+------------------------------------------------------------------+
//| Manage Grid Recovery                                           |
//+------------------------------------------------------------------+
void ManageGridRecovery(ulong ticket) {
    if (!UseGridRecovery || g_activeGridLevels >= MaxGridLevels) return;
    
    if (!position.SelectByTicket(ticket)) return;
    
    double entryPrice = position.PriceOpen();
    double currentPrice = (position.PositionType() == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Check if price moved against us enough to add grid level
    double distancePoints = MathAbs(currentPrice - entryPrice) / _Point;
    
    if (distancePoints >= GridStepPoints * g_activeGridLevels) {
        // Add new grid level
        double newLotSize = g_gridLots[g_activeGridLevels - 1] * GridLotMultiplier;
        bool result = false;
        
        if (position.PositionType() == POSITION_TYPE_BUY) {
            result = trade.Buy(newLotSize, _Symbol, currentPrice, 0, 0, "Grid_BUY_" + IntegerToString(g_activeGridLevels));
        } else {
            result = trade.Sell(newLotSize, _Symbol, currentPrice, 0, 0, "Grid_SELL_" + IntegerToString(g_activeGridLevels));
        }
        
        if (result) {
            g_gridLevels[g_activeGridLevels] = currentPrice;
            g_gridLots[g_activeGridLevels] = newLotSize;
            g_gridTickets[g_activeGridLevels] = trade.ResultOrder();
            g_activeGridLevels++;
            
            Print("Grid level ", g_activeGridLevels, " added at price: ", currentPrice, " Lot: ", newLotSize);
        }
    }
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop                                            |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket) {
    if (!position.SelectByTicket(ticket)) return;
    
    double currentPrice = (position.PositionType() == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentSL = position.StopLoss();
    double newSL = currentSL;
    
    if (position.PositionType() == POSITION_TYPE_BUY) {
        double trailPrice = currentPrice - (TrailingStopPoints * _Point);
        if (currentSL == 0 || trailPrice > currentSL) {
            newSL = trailPrice;
        }
    } else {
        double trailPrice = currentPrice + (TrailingStopPoints * _Point);
        if (currentSL == 0 || trailPrice < currentSL) {
            newSL = trailPrice;
        }
    }
    
    if (newSL != currentSL && MathAbs(newSL - currentSL) >= TrailingStepPoints * _Point) {
        trade.PositionModify(ticket, newSL, position.TakeProfit());
    }
}

//+------------------------------------------------------------------+
//| Apply Breakeven Stop                                           |
//+------------------------------------------------------------------+
void ApplyBreakevenStop(ulong ticket) {
    if (!position.SelectByTicket(ticket)) return;
    
    double entryPrice = position.PriceOpen();
    double currentPrice = (position.PositionType() == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentSL = position.StopLoss();
    
    bool shouldMoveToBreakeven = false;
    
    if (position.PositionType() == POSITION_TYPE_BUY) {
        if (currentPrice >= entryPrice + (BreakevenTriggerPoints * _Point)) {
            if (currentSL < entryPrice + (BreakevenStopPoints * _Point)) {
                shouldMoveToBreakeven = true;
            }
        }
    } else {
        if (currentPrice <= entryPrice - (BreakevenTriggerPoints * _Point)) {
            if (currentSL > entryPrice - (BreakevenStopPoints * _Point)) {
                shouldMoveToBreakeven = true;
            }
        }
    }
    
    if (shouldMoveToBreakeven) {
        double newSL = (position.PositionType() == POSITION_TYPE_BUY) ? 
                      entryPrice + (BreakevenStopPoints * _Point) : 
                      entryPrice - (BreakevenStopPoints * _Point);
        
        trade.PositionModify(ticket, newSL, position.TakeProfit());
        Print("Position moved to breakeven: ", ticket);
    }
}

//+------------------------------------------------------------------+
//| Should Exit On Structural Change                               |
//+------------------------------------------------------------------+
bool ShouldExitOnStructuralChange(ulong ticket) {
    if (!position.SelectByTicket(ticket)) return false;
    
    // Check if market structure changed against our position
    ENUM_MARKET_STRUCTURE currentStructure = DetectMarketStructure();
    
    if (position.PositionType() == POSITION_TYPE_BUY && currentStructure == STRUCTURE_BEARISH) {
        return true;
    }
    
    if (position.PositionType() == POSITION_TYPE_SELL && currentStructure == STRUCTURE_BULLISH) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Should Close Positions                                         |
//+------------------------------------------------------------------+
bool ShouldClosePositions() {
    // Check for major structural change
    if (DetectCHoCH()) {
        return true;
    }
    
    // Check time-based exit
    if (UseTimeFilter && !IsWithinTradingHours()) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Close All Positions                                            |
//+------------------------------------------------------------------+
void CloseAllPositions() {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (position.SelectByIndex(i)) {
            if (position.Symbol() == _Symbol && position.Magic() == MagicNumber) {
                trade.PositionClose(position.Ticket());
                Print("Position closed: ", position.Ticket());
            }
        }
    }
    
    // Reset grid recovery
    if (UseGridRecovery) {
        g_activeGridLevels = 0;
        ArrayInitialize(g_gridLevels, 0);
        ArrayInitialize(g_gridLots, 0);
        ArrayInitialize(g_gridTickets, 0);
    }
}

//+------------------------------------------------------------------+
//| Update Market Data                                             |
//+------------------------------------------------------------------+
void UpdateMarketData() {
    // Update price arrays
    for (int i = 0; i < 50; i++) {
        g_highs[i] = iHigh(_Symbol, PERIOD_CURRENT, i);
        g_lows[i] = iLow(_Symbol, PERIOD_CURRENT, i);
        g_closes[i] = iClose(_Symbol, PERIOD_CURRENT, i);
        g_volumes[i] = iVolume(_Symbol, PERIOD_CURRENT, i);
    }
}

//+------------------------------------------------------------------+
//| Has Sufficient Data                                           |
//+------------------------------------------------------------------+
bool HasSufficientData() {
    return iBars(_Symbol, PERIOD_CURRENT) > 100;
}

//+------------------------------------------------------------------+
//| Is Within Trading Hours                                        |
//+------------------------------------------------------------------+
bool IsWithinTradingHours() {
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    
    // Check day of week
    if (!TradeMonday && time.day_of_week == 1) return false;
    if (!TradeFriday && time.day_of_week == 5) return false;
    
    // Check hour
    if (time.hour < StartHour || time.hour >= EndHour) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Is Confirmation Expired                                        |
//+------------------------------------------------------------------+
bool IsConfirmationExpired() {
    return (TimeCurrent() - g_lastAnalysisTime) > 300; // 5 minutes
}

//+------------------------------------------------------------------+
//| Check Daily Reset                                              |
//+------------------------------------------------------------------+
void CheckDailyReset() {
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);
    
    datetime today = StringToTime(IntegerToString(currentTime.year) + "." + 
                                 IntegerToString(currentTime.mon) + "." + 
                                 IntegerToString(currentTime.day));
    
    if (g_currentDay != today) {
        ResetDailyCounters();
        g_currentDay = today;
    }
}

//+------------------------------------------------------------------+
//| Reset Daily Counters                                          |
//+------------------------------------------------------------------+
void ResetDailyCounters() {
    g_dailyTrades = 0;
    g_dailyLoss = 0;
    g_currentState = STATE_IDLE;
    Print("Daily counters reset");
}

//+------------------------------------------------------------------+
//| Update VWAP                                                    |
//+------------------------------------------------------------------+
void UpdateVWAP() {
    if (!UseVWAP) return;
    
    CalculateVWAP();
}

//+------------------------------------------------------------------+
//| Update Drawing Objects                                         |
//+------------------------------------------------------------------+
void UpdateDrawingObjects() {
    if (DrawVWAP && UseVWAP) {
        // Update VWAP line
        datetime time1 = iTime(_Symbol, PERIOD_CURRENT, 20);
        datetime time2 = iTime(_Symbol, PERIOD_CURRENT, 0);
        
        ObjectSetInteger(g_chartID, g_vwapObjectName, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(g_chartID, g_vwapObjectName, OBJPROP_PRICE, 0, g_vwapValue);
        ObjectSetInteger(g_chartID, g_vwapObjectName, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(g_chartID, g_vwapObjectName, OBJPROP_PRICE, 1, g_vwapValue);
    }
}

//+------------------------------------------------------------------+
//| Update Status Display                                          |
//+------------------------------------------------------------------+
void UpdateStatusDisplay(string status) {
    if (!ShowVWAPStatus) return;
    
    string displayText = "SMC Ultimate EA\n";
    displayText += "State: " + status + "\n";
    displayText += "Structure: " + EnumToString(g_marketStructure) + "\n";
    displayText += "Daily Trades: " + IntegerToString(g_dailyTrades) + "/" + IntegerToString(MaxDailyTrades) + "\n";
    displayText += "Positions: " + IntegerToString(PositionsTotal()) + "/" + IntegerToString(MaxOpenPositions) + "\n";
    
    if (UseVWAP) {
        displayText += "VWAP: " + DoubleToString(g_vwapValue, _Digits) + "\n";
    }
    
    if (UseConfluenceScoring) {
        int score = CalculateConfluenceScore();
        displayText += "Confluence: " + IntegerToString(score) + "/" + IntegerToString(MaxConfluenceScore) + "\n";
    }
    
    ObjectSetString(g_chartID, g_statusObjectName, OBJPROP_TEXT, displayText);
}

//+------------------------------------------------------------------+
//| Cleanup Drawing Objects                                        |
//+------------------------------------------------------------------+
void CleanupDrawingObjects() {
    ObjectDelete(g_chartID, g_vwapObjectName);
    ObjectDelete(g_chartID, g_statusObjectName);
}

//+------------------------------------------------------------------+
//| Save Performance Data                                          |
//+------------------------------------------------------------------+
void SavePerformanceData() {
    // Save performance metrics to global variables for analysis
    Print("Performance Summary:");
    Print("Daily Trades: ", g_dailyTrades);
    Print("Current State: ", EnumToString(g_currentState));
    Print("Market Structure: ", EnumToString(g_marketStructure));
}

//+------------------------------------------------------------------+
//| End of SMC Ultimate Hybrid EA                                  |
//+------------------------------------------------------------------+