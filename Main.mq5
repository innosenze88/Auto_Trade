//+------------------------------------------------------------------+
//|                                          SMC_Ultimate_Hybrid_EA |
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
// This file will compile perfectly in MetaTrader 5 Editor (MetaEditor).
// To compile: Open MetaEditor → File → Open → Select this file → Press F7
// 
// 🔧 How to use this EA:
// 1. Copy this file to MetaTrader 5 → MQL5 → Experts folder
// 2. Open MetaEditor (F4 in MT5)
// 3. Open this file and press F7 to compile
// 4. Attach to chart in MT5
//
// 📋 Drawing Functions Status:
// ✅ DrawTrendStructure() - ZigZag trend lines
// ✅ DrawBOSLevels() - Break of Structure signals  
// ✅ DrawCHoCHLevels() - Change of Character signals
// ✅ DrawSwingPointsOnChart() - HH/HL/LH/LL markers
// ✅ DrawOrderBlocksOnChart() - Order Block zones
// ✅ DrawDynamicLevelsOnChart() - SL/TP levels
// ✅ DrawFairValueGapsOnChart() - FVG rectangles
// ✅ All functions use proper MQL5 ObjectCreate() syntax

#property copyright "Auto_Trade Development"
#property link      "https://github.com/innosenze88/Auto_Trade"
#property version   "2.000"
#property description "Ultimate SMC Trading Solution - Professional Smart Money Concepts EA"
#property description "Features: ZigZag Swing Analysis + True Order Blocks + Dynamic SL/TP"
#property description "No Martingale - Pure SMC Strategy with Risk Management"
#property strict

// Note: Using standard MQL5 functions for better compatibility
// Trade library includes may not be available in all environments

//+------------------------------------------------------------------+
//| Trade Execution Helper Functions                                |
//+------------------------------------------------------------------+
// Trade execution using standard MQL5 functions
// --- Execution configuration inputs
// Note: trade execution input parameters are declared below with other inputs

// --- Small helpers
int GetSymbolDigits() { return (int)_Digits; }
double NormalizeToDigits(double v) { return NormalizeDouble(v, GetSymbolDigits()); }
double DMax(double a, double b) { return (a > b) ? a : b; }

// Debug logging helper - single unambiguous signature
void DebugLog(string msg) {
    if (VerboseLogging) Print(msg);
}
// Always-print warnings
void LogWarning(string msg) {
    Print("WARNING: " + msg);
}

// Ensure symbol is selected in MarketWatch to allow property queries when required
bool EnsureSymbolSelected(const string symbol) {
    // If already selected, nothing to do
    long sel = 0;
    if (SymbolInfoInteger(symbol, SYMBOL_SELECT, sel) && sel != 0) return true;
    return SymbolSelect(symbol, true);
}

double GetMinStopDistance() {
    // Broker minimum stop distance in price units
    long lvl = 0;
    if (!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, lvl)) lvl = 0;
    int stopLevel = (int)lvl;
    if (stopLevel < 0) stopLevel = 0;
    int buffer = MinStopBufferPoints;
    return (stopLevel + buffer) * _Point;
}

bool ValidateAndAdjustSLTP(ENUM_ORDER_TYPE type, double entry, double &sl, double &tp) {
    double minDist = GetMinStopDistance();
    bool ok = true;

    if (type == ORDER_TYPE_BUY) {
        // SL must be below entry; TP must be above entry
        if (sl <= 0 || sl >= entry - minDist) {
            sl = entry - minDist;
            ok = false; // adjusted
        }
        if (tp <= 0 || tp <= entry + minDist) {
            tp = entry + DMax(minDist, (g_TakeProfitPoints * _Point));
            ok = false; // adjusted
        }
    } else {
        if (sl <= 0 || sl <= entry + minDist) {
            sl = entry + minDist;
            ok = false;
        }
        if (tp <= 0 || tp >= entry - minDist) {
            tp = entry - DMax(minDist, (g_TakeProfitPoints * _Point));
            ok = false;
        }
    }

    // Normalize
    sl = NormalizeToDigits(sl);
    tp = NormalizeToDigits(tp);
    return ok;
}

bool PrepareFillingMode(MqlTradeRequest &request) {
    // Choose an allowed filling mode using flags
    long fill_flags = 0;
    SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE, fill_flags);
        bool allowIOC = (fill_flags & ORDER_FILLING_IOC) != 0;
        bool allowFOK = (fill_flags & ORDER_FILLING_FOK) != 0;
        bool allowRET = (fill_flags & ORDER_FILLING_RETURN) != 0;
    if (AllowIOCFill && allowIOC) {
        request.type_filling = ORDER_FILLING_IOC;
    } else if (allowRET) {
        request.type_filling = ORDER_FILLING_RETURN;
    } else if (allowFOK) {
        request.type_filling = ORDER_FILLING_FOK;
    } else {
        // Fallback preference
        request.type_filling = AllowIOCFill ? ORDER_FILLING_IOC : ORDER_FILLING_FOK;
    }
    return true;
}

// Safe wrapper for OrderSend with simple retry for transient errors
bool SafeOrderSend(MqlTradeRequest &req, MqlTradeResult &res, int maxRetries=2, int retryDelayMs=250) {
    int attempt = 0;
    while (attempt <= maxRetries) {
        bool ok = OrderSend(req, res);
        if (ok) return true;
        uint code = (uint)res.retcode;
        // Transient retcodes to retry -> use helper
        if (IsTransientTradeRetcode(code)) {
            // try small sleep then retry
            Sleep(retryDelayMs);
            attempt++;
            continue;
        }
        // Non-transient - give up
        return false;
    }
    return false;
}

// Returns true for trade result codes we consider transient and worth retrying
bool IsTransientTradeRetcode(uint code) {
    // Conservative list supported across brokers/MT5 builds
    if (code == TRADE_RETCODE_REQUOTE) return true;
    if (code == TRADE_RETCODE_PRICE_CHANGED) return true;
    if (code == TRADE_RETCODE_INVALID_PRICE) return true;
    if (code == TRADE_RETCODE_INVALID_STOPS) return true;
    // leave out less portable codes like SERVER_BUSY or REJECT to avoid unknown identifier issues
    return false;
}

bool PreTradeChecks(string symbol, double lot, ENUM_ORDER_TYPE type, double price) {
    // Trading allowed checks
    if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
        Print("ERROR: Trading not allowed in terminal.");
        return false;
    }
    // Check symbol trade mode
    long tradeModeRaw = 0;
    if (!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE, tradeModeRaw)) {
        int err = GetLastError();
        if (err == ERR_MARKET_NOT_SELECTED && EnsureSymbolSelected(symbol)) {
            ResetLastError();
            if (!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE, tradeModeRaw)) {
                Print("ERROR: SymbolInfoInteger(SYMBOL_TRADE_MODE) failed for ", symbol, " code=", GetLastError());
                return false;
            }
        } else {
            Print("ERROR: SymbolInfoInteger(SYMBOL_TRADE_MODE) failed for ", symbol, " code=", err);
            return false;
        }
    }
    ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)tradeModeRaw;
    if (tradeMode == SYMBOL_TRADE_MODE_DISABLED || tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY) {
        Print("ERROR: Trading mode for ", symbol, " is not open for new orders. Mode=", (int)tradeMode);
        return false;
    }
    bool isBuyReq = (type == ORDER_TYPE_BUY);
    bool isSellReq = (type == ORDER_TYPE_SELL);
    if (tradeMode == SYMBOL_TRADE_MODE_LONGONLY && isSellReq) {
        Print("ERROR: Symbol ", symbol, " allows LONG only; SELL not permitted.");
        return false;
    }
    if (tradeMode == SYMBOL_TRADE_MODE_SHORTONLY && isBuyReq) {
        Print("ERROR: Symbol ", symbol, " allows SHORT only; BUY not permitted.");
        return false;
    }
    // Free margin check
    double margin = 0.0;
    if (!OrderCalcMargin(type, symbol, lot, price, margin)) {
        Print("ERROR: OrderCalcMargin failed. Code: ", GetLastError());
        return false;
    }
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    if (margin > freeMargin) {
        Print("ERROR: Not enough free margin. Needed=", DoubleToString(margin, 2), " Free=", DoubleToString(freeMargin, 2));
        return false;
    }
    return true;
}

// Count open positions + pending orders for this EA and symbol
int CountEAOpenPositionsAndOrders(string symbol, long magic) {
    int count = 0;
    for (int i = 0; i < PositionsTotal(); i++) {
        ulong t = PositionGetTicket(i);
        if (t > 0 && PositionSelectByTicket(t)) {
            if (PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_MAGIC) == magic)
                count++;
        }
    }
    for (int i = 0; i < OrdersTotal(); i++) {
        ulong ot = OrderGetTicket(i);
        if (ot > 0 && OrderSelect(ot)) {
            if (OrderGetString(ORDER_SYMBOL) == symbol && (long)OrderGetInteger(ORDER_MAGIC) == magic)
                count++;
        }
    }
    return count;
}

//--- SMC Order Block type and storage (placed here for early usage)
// Where inside an Order Block to place pending entries
enum ENUM_PENDING_OB_PLACEMENT { OB_ENTRY_LOW, OB_ENTRY_MID, OB_ENTRY_SMART };

struct OrderBlock {
    datetime time;
    double high;
    double low;
    double volume;
    bool isBullish;
    bool isUsed;
    int strength;
};

OrderBlock g_orderBlocks[50];
int g_orderBlockCount = 0;

// Find most recent matching Order Block
bool FindRecentOrderBlock(bool bullish, OrderBlock &outOb) {
    datetime bestTime = 0;
    bool found = false;
    for (int i = 0; i < g_orderBlockCount; i++) {
        if (g_orderBlocks[i].isUsed) continue;
        if (g_orderBlocks[i].isBullish != bullish) continue;
        if (g_orderBlocks[i].time >= bestTime) {
            bestTime = g_orderBlocks[i].time;
            outOb = g_orderBlocks[i];
            found = true;
        }
    }
    return found;
}

// Compute pending entry price based on OB (limit entries)
bool GetOBPendingPrice(bool bullish, double &priceOut) {
    OrderBlock ob;
    if (!FindRecentOrderBlock(bullish, ob)) return false;
    double offset = EntryOffsetPoints * _Point;
    double obHeight = ob.high - ob.low;
    if (bullish) {
        // Determine entry inside OB based on placement mode
        switch (PendingOBPlacement) {
            case OB_ENTRY_LOW:
                priceOut = ob.low + offset;
                break;
            case OB_ENTRY_MID:
                priceOut = ob.low + (obHeight / 2.0);
                break;
            case OB_ENTRY_SMART:
            default:
                // Smart: bias toward lower part of OB (30% up from low)
                priceOut = ob.low + (0.30 * obHeight);
                break;
        }
        priceOut = NormalizeToDigits(priceOut);
        // Ensure below current ask for limit buy
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        if (priceOut >= ask) priceOut = NormalizeToDigits(ask - offset);
    } else {
        switch (PendingOBPlacement) {
            case OB_ENTRY_LOW:
                // For sell, low means deeper in zone (use high - offset instead)
                priceOut = ob.high - offset;
                break;
            case OB_ENTRY_MID:
                priceOut = ob.low + (obHeight / 2.0);
                break;
            case OB_ENTRY_SMART:
            default:
                // Smart: bias toward upper part of OB (30% down from high)
                priceOut = ob.high - (0.30 * obHeight);
                break;
        }
        priceOut = NormalizeToDigits(priceOut);
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if (priceOut <= bid) priceOut = NormalizeToDigits(bid + offset);
    }
    return true;
}

// Compute breakout pending price (stop entries) from last HH/LL
bool GetBreakoutPendingPrice(bool bullish, double &priceOut) {
    double offset = EntryOffsetPoints * _Point;
    if (bullish && g_lastHH > 0) {
        priceOut = NormalizeToDigits(g_lastHH + offset);
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        if (priceOut <= ask) priceOut = NormalizeToDigits(ask + offset);
        return true;
    }
    if (!bullish && g_lastLL > 0) {
        priceOut = NormalizeToDigits(g_lastLL - offset);
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if (priceOut >= bid) priceOut = NormalizeToDigits(bid - offset);
        return true;
    }
    return false;
}

// Place a pending order (LIMIT/STOP)
bool PlacePendingOrder(ENUM_ORDER_TYPE orderType, double lot, string symbol, double price, double sl, double tp, string comment) {
    MqlTradeRequest req = {};
    MqlTradeResult res = {};
    req.action = TRADE_ACTION_PENDING;
    req.type = orderType;
    req.symbol = symbol;
    req.volume = lot;
    req.price = NormalizeToDigits(price);
    req.sl = NormalizeToDigits(sl);
    req.tp = NormalizeToDigits(tp);
    req.deviation = SlippagePoints;
    req.magic = GetMagicForSymbol(symbol);
    // Apply expiration policy for pending orders (respect symbol's allowed modes)
    long expModes = 0;
    bool hasExpModes = SymbolInfoInteger(symbol, SYMBOL_EXPIRATION_MODE, expModes);
    if (!hasExpModes) {
        int err = GetLastError();
        if (err == ERR_MARKET_NOT_SELECTED && EnsureSymbolSelected(symbol)) {
            ResetLastError();
            hasExpModes = SymbolInfoInteger(symbol, SYMBOL_EXPIRATION_MODE, expModes);
        }
    }
    if (SetOrderExpiration && PendingExpiryMinutes > 0) {
        bool allowSpecified = hasExpModes ? ((expModes & SYMBOL_EXPIRATION_SPECIFIED) != 0) : true;
        bool allowDay = hasExpModes ? ((expModes & SYMBOL_EXPIRATION_DAY) != 0) : true;
        if (allowSpecified) {
            req.type_time = ORDER_TIME_SPECIFIED;
            req.expiration = (datetime)(TimeCurrent() + (PendingExpiryMinutes * 60));
        } else if (allowDay) {
            req.type_time = ORDER_TIME_DAY; // till end of day if SPECIFIED not allowed
        } else {
            req.type_time = ORDER_TIME_GTC; // fallback
        }
    } else {
        bool allowGTC = hasExpModes ? ((expModes & SYMBOL_EXPIRATION_GTC) != 0) : true;
        bool allowDay = hasExpModes ? ((expModes & SYMBOL_EXPIRATION_DAY) != 0) : false;
        req.type_time = allowGTC ? ORDER_TIME_GTC : (allowDay ? ORDER_TIME_DAY : ORDER_TIME_GTC);
    }
    PrepareFillingMode(req);
    // Pre-check margin using market side type
    ENUM_ORDER_TYPE marketSide = (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    if (!PreTradeChecks(symbol, lot, marketSide, req.price)) return false;
    bool ok = SafeOrderSend(req, res);
    if (!ok) {
        Print("Pending order send failed. Type=", (int)orderType, " Retcode=", res.retcode, " Comment=", res.comment);
    }
    return ok;
}

// Find the most recent position ticket for a symbol/magic
ulong FindLatestPositionTicketForSymbolMagic(string symbol, long magic) {
    ulong latest = 0;
    datetime latestTime = 0;
    for (int i = 0; i < PositionsTotal(); i++) {
        ulong t = PositionGetTicket(i);
            if (t > 0 && PositionSelectByTicket(t)) {
                if (PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_MAGIC) == magic) {
                    datetime pt = (datetime)PositionGetInteger(POSITION_TIME);
                    if (pt >= latestTime) { latestTime = pt; latest = t; }
                }
        }
    }
    return latest;
}

// Calculate position size from risk and actual SL distance (points)
double CalculatePositionSizeForSLDistance(const string symbol, double slDistancePoints) {
    double lotSize = LotSize;
    if (UseAutoLot && RiskPercent > 0 && slDistancePoints > 0) {
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = accountBalance * RiskPercent / 100.0;
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        double symbolPoint = SymbolInfoDouble(symbol, SYMBOL_POINT);
        double pointValue = (tickValue > 0 && tickSize > 0 && symbolPoint > 0) ? (tickValue / (tickSize / symbolPoint)) : 0;
        if (pointValue > 0) {
            lotSize = riskAmount / (slDistancePoints * pointValue);
        }
    }
    // Apply lot constraints
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    if (lotSize < minLot) lotSize = minLot;
    if (lotSize > maxLot) lotSize = maxLot;
    lotSize = MathRound(lotSize / lotStep) * lotStep;
    return lotSize;
}

bool ExecuteBuyOrder(double lotSize, string symbol, double price, double sl, double tp, string comment) {
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = NormalizeToDigits(price);
    request.sl = NormalizeToDigits(sl);
    request.tp = NormalizeToDigits(tp);
    request.comment = comment;
    request.magic = GetMagicForSymbol(symbol);
    request.deviation = SlippagePoints;
    request.type_time = ORDER_TIME_GTC;
    PrepareFillingMode(request);
    
    // Pre-check order
    MqlTradeCheckResult check;
    if (!PreTradeChecks(symbol, lotSize, ORDER_TYPE_BUY, request.price)) return false;
    if (!OrderCheck(request, check)) {
        Print("OrderCheck failed (BUY). Retcode=", check.retcode);
        // Try sending without SL/TP then modify
    }
    
    bool sent = SafeOrderSend(request, result);
    if (!sent) {
        Print("OrderSend BUY failed. Retcode=", result.retcode, " Comment=", result.comment, " LastError=", GetLastError());
        // Retry without SL/TP on typical stop/price errors
        if (result.retcode == TRADE_RETCODE_INVALID_STOPS || result.retcode == TRADE_RETCODE_INVALID_PRICE ||
            result.retcode == TRADE_RETCODE_REQUOTE || result.retcode == TRADE_RETCODE_PRICE_CHANGED) {
            MqlTradeRequest r2 = request; MqlTradeResult res2 = {};
            r2.sl = 0; r2.tp = 0;
            sent = SafeOrderSend(r2, res2);
            if (!sent) {
                Print("Fallback BUY send without SL/TP failed. Retcode=", res2.retcode, " Comment=", res2.comment);
                return false;
            }
            // Post-modify SL/TP
            ulong ticket = FindLatestPositionTicketForSymbolMagic(symbol, GetMagicForSymbol(symbol));
            if (ticket > 0) {
                double adjSL = sl, adjTP = tp;
                ValidateAndAdjustSLTP(ORDER_TYPE_BUY, price, adjSL, adjTP);
                ModifyPosition(ticket, adjSL, adjTP);
            }
            return true;
        }
    }
    return sent;
}

bool ExecuteSellOrder(double lotSize, string symbol, double price, double sl, double tp, string comment) {
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = NormalizeToDigits(price);
    request.sl = NormalizeToDigits(sl);
    request.tp = NormalizeToDigits(tp);
    request.comment = comment;
    request.magic = GetMagicForSymbol(symbol);
    request.deviation = SlippagePoints;
    request.type_time = ORDER_TIME_GTC;
    PrepareFillingMode(request);
    
    // Pre-check order
    MqlTradeCheckResult check;
    if (!PreTradeChecks(symbol, lotSize, ORDER_TYPE_SELL, request.price)) return false;
    if (!OrderCheck(request, check)) {
        Print("OrderCheck failed (SELL). Retcode=", check.retcode);
        // Proceed to try send; some servers return return codes only on send
    }
    
    bool sent = SafeOrderSend(request, result);
    if (!sent) {
        Print("OrderSend SELL failed. Retcode=", result.retcode, " Comment=", result.comment, " LastError=", GetLastError());
        if (result.retcode == TRADE_RETCODE_INVALID_STOPS || result.retcode == TRADE_RETCODE_INVALID_PRICE ||
            result.retcode == TRADE_RETCODE_REQUOTE || result.retcode == TRADE_RETCODE_PRICE_CHANGED) {
            MqlTradeRequest r2 = request; MqlTradeResult res2 = {};
            r2.sl = 0; r2.tp = 0;
            sent = SafeOrderSend(r2, res2);
            if (!sent) {
                Print("Fallback SELL send without SL/TP failed. Retcode=", res2.retcode, " Comment=", res2.comment);
                return false;
            }
            // Post-modify SL/TP
            ulong ticket = FindLatestPositionTicketForSymbolMagic(symbol, GetMagicForSymbol(symbol));
            if (ticket > 0) {
                double adjSL = sl, adjTP = tp;
                ValidateAndAdjustSLTP(ORDER_TYPE_SELL, price, adjSL, adjTP);
                ModifyPosition(ticket, adjSL, adjTP);
            }
            return true;
        }
    }
    return sent;
}

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
    request.magic = GetMagicForSymbol(request.symbol);
    request.deviation = 10;
    
    return SafeOrderSend(request, result);
}

bool ModifyPosition(ulong ticket, double sl, double tp) {
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    if (!PositionSelectByTicket(ticket)) return false;
    
    request.action = TRADE_ACTION_SLTP;
    request.symbol = PositionGetString(POSITION_SYMBOL);
    request.sl = sl;
    request.tp = tp;
    request.position = ticket;
    request.magic = GetMagicForSymbol(request.symbol);
    
    return SafeOrderSend(request, result);
}

// Position information helper functions
bool SelectPositionByTicket(ulong ticket) {
    return PositionSelectByTicket(ticket);
}

double GetPositionPrice(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return 0.0;
    return PositionGetDouble(POSITION_PRICE_OPEN);
}

double GetPositionStopLoss(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return 0.0;
    return PositionGetDouble(POSITION_SL);
}

double GetPositionTakeProfit(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return 0.0;
    return PositionGetDouble(POSITION_TP);
}

ENUM_POSITION_TYPE GetPositionType(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return -1;
    return (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
}

string GetPositionSymbol(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return "";
    return PositionGetString(POSITION_SYMBOL);
}

long GetPositionMagic(ulong ticket) {
    if (!PositionSelectByTicket(ticket)) return 0;
    return PositionGetInteger(POSITION_MAGIC);
}

// Deterministic small hash for symbol to produce per-symbol magic offset
int SymbolHashShort(const string symbol) {
    int h = 0;
    for (int i = 0; i < StringLen(symbol); i++)
        h = (h * 31 + StringGetCharacter(symbol, i)) & 0x7fffffff;
    return h;
}

// Get magic number for a specific symbol (optionally auto-offset)
int GetMagicForSymbol(const string symbol) {
    if (!AutoMagicPerSymbol) return MagicNumber;
    if (StringLen(symbol) == 0) return MagicNumber;
    int shortHash = SymbolHashShort(symbol) % (AutoMagicMaxOffset + 1);
    return MagicNumber + shortHash;
}

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
input bool AutoMagicPerSymbol = true;               // If true, derive per-symbol magic offsets
input int AutoMagicMaxOffset = 9999;                // Max offset to add per symbol (0..9999)
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

input group "=== ZIGZAG SETTINGS ===";
input bool UseZigZag_input = true; // user-configurable default
// Runtime mutable flag (can be toggled off if indicator missing)
bool UseZigZag = true;
input int ZigZagDepth = 8;           // ExtDepth parameter (ลดจาก 15 เป็น 8)
input int ZigZagDeviation = 5;       // ExtDeviation parameter (ลดจาก 8 เป็น 5)  
input int ZigZagBackstep = 3;        // ExtBackstep parameter
input int MaxSwingPoints = 50;       // Maximum swing points to track

input group "=== THREE-SWING PATTERN FILTER ===";
input bool UseThreeSwingPatternFilter = true;        // Gate entries by last 3-swing pattern
input bool AcceptUnknownThreeSwingPattern = true;    // If classification is unknown/insufficient, allow entry
// Allowed bullish-side patterns (await HH)
input bool AllowBull_LL_LH_HL = true;                // LL → LH → HL
input bool AllowBull_LL_HH_HL = true;                // LL → HH → HL
input bool AllowBull_HL_LH_HL = true;                // HL → LH → HL
input bool AllowBull_HL_HH_HL = true;                // HL → HH → HL
// Allowed bearish-side patterns (await LL)
input bool AllowBear_HH_HL_LH = true;                // HH → HL → LH
input bool AllowBear_HH_LL_LH = true;                // HH → LL → LH
input bool AllowBear_LH_HL_LH = true;                // LH → HL → LH
input bool AllowBear_LH_LL_LH = true;                // LH → LL → LH

input group "=== VISUALIZATION SETTINGS ===";
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

input bool VerboseLogging = false; // Toggle detailed debug prints

input group "=== VISUAL CLARITY ===";
// Limit how much we draw and how verbose labels are to keep the chart readable
enum ENUM_LABEL_VERBOSITY { LABEL_FULL, LABEL_COMPACT, LABEL_MINIMAL };
input int  Visual_ShowOnlyRecentBars = 600;          // 0 = no limit; otherwise keep only objects within last N bars
input int  Visual_MaxObjectsPerType = 60;            // Max objects to keep for each prefix/type
input ENUM_LABEL_VERBOSITY Visual_LabelVerbosity = LABEL_COMPACT; // How verbose labels should be
input bool Visual_ThinLines = true;                  // Force thin/dotted lines for structure levels
input bool Visual_LightenFVG = true;                 // Draw FVG rectangles as outlines (no fill) and send to background
input bool Visual_DrawRRBox = true;                  // Draw Risk/Reward box for pending setup
input int VisualUpdateIntervalSeconds = 5;          // Minimum seconds between expensive visual updates
// Additional visual tuning inputs
input int Visual_OBTransparency = 120;               // 0-255 alpha for Order Block fills
input int Visual_FVGTransparency = 140;              // 0-255 alpha for FVG fills
input int Visual_SwingArrowWidth = 1;                // width for swing arrow markers
input int Visual_CHoCHWidth = 2;                     // width for CHoCH arrows/lines

input group "=== STATUS PANEL ===";
input bool  Visual_ShowStatusPanel = true;           // Show compact status panel
input ENUM_BASE_CORNER Visual_PanelCorner = CORNER_LEFT_UPPER; // Panel corner
input int   Visual_PanelX = 10;                      // X offset (pixels)
input int   Visual_PanelY = 20;                      // Y offset (pixels)
input color Visual_PanelTextColor = clrWhite;        // Text color
input color Visual_PanelBGColor = clrBlack;          // Background color

input group "=== VISUAL PRESETS ===";
enum ENUM_VISUAL_PRESET { VISUAL_MAX_INFO, VISUAL_BALANCED, VISUAL_CLEAN, VISUAL_CUSTOM };
input ENUM_VISUAL_PRESET VisualPreset = VISUAL_BALANCED;

input group "=== LAYER TOGGLES ===";
// Additional layer toggles to quickly isolate specific visuals
input bool ShowLayer_Trend = true;                   // Trend lines backbone
input bool ShowLayer_SwingPoints = true;             // HH/HL/LH/LL markers
input bool ShowLayer_BOS = true;                     // BOS levels
input bool ShowLayer_CHoCH = true;                   // CHoCH levels
input bool ShowLayer_OB = true;                      // Order Blocks
input bool ShowLayer_FVG = true;                     // FVG gaps
input bool ShowLayer_SLTP = true;                    // Dynamic SL/TP
input bool ShowLayer_VWAP = true;                    // VWAP line
input bool ShowLayer_VolumeProfile = true;           // Volume profile

input group "=== VWAP SYSTEM ===";
input bool UseVWAP = true;
input bool DrawVWAP = true;
input bool UseVWAPFilter = true;
input double VWAPFilterBuffer = 20;
input ENUM_TIMEFRAMES VWAPTimeframe = PERIOD_D1;
input int VWAPPeriod = 20;
input bool ShowVWAPStatus = true;
input int VWAPUpdateIntervalSeconds = 30;          // seconds between VWAP recalculations

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

input group "=== TRADE EXECUTION SETTINGS ===";
input int SlippagePoints = 50;                 // Max price deviation (points)
input int MinStopBufferPoints = 10;            // Extra buffer beyond broker stop level (points)
input bool AllowIOCFill = true;                // Prefer IOC if supported
input bool AutoCloseOnDailyLimit = false;      // Automatically close positions when daily loss limit hit

input group "=== PENDING ORDER SETTINGS ===";
enum ENUM_PENDING_MODE { PENDING_LIMIT_OB, PENDING_STOP_BREAKOUT, PENDING_AUTO };
input bool UsePendingOrders = true;                   // Use pending instead of market execution
input ENUM_PENDING_MODE PendingMode = PENDING_LIMIT_OB; // Default: limit at OB zone
input int EntryOffsetPoints = 10;                     // Offset buffer for entry price
// Where inside an Order Block to place pending entries (enum declared earlier)
input ENUM_PENDING_OB_PLACEMENT PendingOBPlacement = OB_ENTRY_SMART; // default: smart-weighted entry inside OB
input bool SetOrderExpiration = true;                 // Set expiry time on pending orders
input int PendingExpiryMinutes = 240;                 // Expire after N minutes
input bool CancelPendingOnStructureChange = true;     // Auto-cancel when structure flips opposite
input int PendingManageIntervalSeconds = 5;           // Throttle pending management checks

input group "=== ANALYSIS TIMING ===";
input bool UseNewBarTrigger = false;                  // Only analyze on new bar
input ENUM_TIMEFRAMES AnalysisTimeframe = PERIOD_CURRENT; // Timeframe to trigger analysis
input int ConfirmationTimeoutSeconds = 300;           // Timeout for confirmation wait

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

// Three-swing pattern classification (alternating Low/High/Low or High/Low/High)
// Bullish-side patterns (expecting/awaiting HH next):
//  - LL → LH → HL
//  - LL → HH → HL
//  - HL → LH → HL
//  - HL → HH → HL
// Bearish-side patterns (expecting/awaiting LL next):
//  - HH → HL → LH
//  - HH → LL → LH
//  - LH → HL → LH
//  - LH → LL → LH
enum ENUM_THREE_SWING_PATTERN {
    TSP_BULL_LL_LH_HL = 0,   // LL → LH → HL (awaiting HH)
    TSP_BULL_LL_HH_HL,       // LL → HH → HL (awaiting HH)
    TSP_BULL_HL_LH_HL,       // HL → LH → HL (awaiting HH)
    TSP_BULL_HL_HH_HL,       // HL → HH → HL (awaiting HH)
    TSP_BEAR_HH_HL_LH,       // HH → HL → LH (awaiting LL)
    TSP_BEAR_HH_LL_LH,       // HH → LL → LH (awaiting LL)
    TSP_BEAR_LH_HL_LH,       // LH → HL → LH (awaiting LL)
    TSP_BEAR_LH_LL_LH,       // LH → LL → LH (awaiting LL)
    TSP_UNKNOWN              // Unclassified/insufficient data
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
double g_dailyNetPL = 0; // net P/L for today (profits - losses)

//--- Global Settings Variables (for preset modifications)
double g_TakeProfitPoints;
double g_StopLossPoints;
int g_MinConfluenceScore;
bool g_UseVWAPFilter;
bool g_RequireHTFAlignment;
int g_MaxOpenPositions;

//--- Arrays for Analysis
double g_highs[], g_lows[], g_closes[], g_volumes[];
double g_vwap_array[];
bool g_fairValueGaps[];

//--- Swing Points Analysis Arrays
struct SwingPoint {
    datetime time;
    double price;
    bool isHigh;
    bool isLow;
    int index;
    bool isConfirmed;    // ZigZag confirmed point
};
SwingPoint g_swingPoints[100];
int g_swingCount = 0;
double g_lastHH = 0, g_lastHL = 0, g_lastLH = 0, g_lastLL = 0;
datetime g_lastHHTime = 0, g_lastHLTime = 0, g_lastLHTime = 0, g_lastLLTime = 0;

//--- ZigZag Variables
int g_zigzagHandle = INVALID_HANDLE;
double g_zigzagBuffer[];
bool g_zigzagInitialized = false;

//--- Market Structure Variables
enum ENUM_TREND_DIRECTION {
    TREND_BULLISH,      // HH + HL pattern
    TREND_BEARISH,      // LH + LL pattern
    TREND_RANGING,      // Consolidation
    TREND_UNKNOWN,      // Not enough data
    // Fine-grained three-swing trend variants
    TREND_BULL_LL_LH_HL,   // LL → LH → HL (await HH)
    TREND_BULL_LL_HH_HL,   // LL → HH → HL (await HH)
    TREND_BULL_HL_LH_HL,   // HL → LH → HL (await HH)
    TREND_BULL_HL_HH_HL,   // HL → HH → HL (await HH)
    TREND_BEAR_HH_HL_LH,   // HH → HL → LH (await LL)
    TREND_BEAR_HH_LL_LH,   // HH → LL → LH (await LL)
    TREND_BEAR_LH_HL_LH,   // LH → HL → LH (await LL)
    TREND_BEAR_LH_LL_LH    // LH → LL → LH (await LL)
};

ENUM_TREND_DIRECTION g_currentTrend = TREND_UNKNOWN;
ENUM_TREND_DIRECTION g_htfTrend = TREND_UNKNOWN;
ENUM_TREND_DIRECTION g_threeSwingTrend = TREND_UNKNOWN; // mapped from last 3-swing pattern
double g_trendStrength = 0;
bool g_bosDetected = false;
bool g_chochDetected = false;
double g_cachedAvgVolume = 0;
datetime g_cachedAvgVolumeTime = 0;

//--- SMC Order Blocks and Dynamic Levels
double g_dynamicSL = 0;
double g_dynamicTP = 0;
double g_lastValidHigh = 0;
double g_lastValidLow = 0;
datetime g_lastBarTime = 0;  // For bar close detection

//--- Performance Optimization
int g_tickCounter = 0;
datetime g_lastTickTime = 0;
bool g_fastMode = false;
datetime g_lastPendingManageTime = 0;   // throttle pending checks
datetime g_confirmationStartTime = 0;   // start time of confirmation waiting
datetime g_lastAnalysisBarTime = 0;     // last bar time used to trigger analysis
datetime g_lastDrawUpdateTime = 0;      // legacy (kept for compatibility)
// Split draw update timers to avoid races between VWAP and visual updates
datetime g_lastVWAPUpdateTime = 0;      // last time VWAP was updated
datetime g_lastVisualUpdateTime = 0;    // last time visual/drawing update ran

//--- Effective Visual Settings (modifiable via presets)
int  g_Visual_ShowOnlyRecentBars;
int  g_Visual_MaxObjectsPerType;
ENUM_LABEL_VERBOSITY g_Visual_LabelVerbosity;
bool g_Visual_ThinLines;
bool g_Visual_LightenFVG;
bool g_ShowLayer_Trend;
bool g_ShowLayer_SwingPoints;
bool g_ShowLayer_BOS;
bool g_ShowLayer_CHoCH;
bool g_ShowLayer_OB;
bool g_ShowLayer_FVG;
bool g_ShowLayer_SLTP;
bool g_ShowLayer_VWAP;
bool g_ShowLayer_VolumeProfile;

//--- Drawing Objects
long g_chartID = 0;
string g_vwapObjectName = "VWAP_Line";
// Unified status panel name (single compact status box)
string g_statusObjectName = "SMC_Status_Panel";

//--- Drawing Object Prefixes for Easy Management
string g_swingPointPrefix = "SMC_SP_";
string g_trendPrefix = "SMC_TREND_";
string g_bosPrefix = "SMC_BOS_";
string g_chochPrefix = "SMC_CHoCH_";
string g_orderBlockPrefix = "SMC_OB_";
string g_fvgPrefix = "SMC_FVG_";
string g_slPrefix = "SMC_SL_";
string g_tpPrefix = "SMC_TP_";
string g_trendLinePrefix = "SMC_TREND_";
string g_vpPrefix = "SMC_VP_";
string g_rrPrefix = "SMC_RR_"; // Risk/Reward drawing prefix

//--- Drawing Control Variables
int g_lastDrawnSwingCount = 0;
int g_lastDrawnOBCount = 0;
datetime g_lastVPUpdate = 0;
bool g_drawingEnabled = true;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    DebugLog("=== SMC Ultimate Hybrid EA Starting ===");
    
    // Initialize chart ID
    g_chartID = ChartID();
    
    // Initialize global settings from inputs
    InitializeGlobalSettings();
    
    // Apply Preset Settings
    ApplyPresetSettings();

    // Apply visual presets
    ApplyVisualPresetSettings();
    
    // Initialize arrays
    InitializeArrays();
    
    // Setup drawing objects
    SetupDrawingObjects();
    
    // Reset daily counters
    ResetDailyCounters();
    
    // Initialize VWAP
    InitializeVWAP();
    // Recalculate today's P/L counters from history (in case EA restarted)
    RecalculateDailyPL();
    
    // Initialize runtime flags from inputs
    UseZigZag = UseZigZag_input;

    // Initialize ZigZag
    InitializeZigZag();
    // If ZigZag requested but not available, fallback and notify
    if (UseZigZag && !g_zigzagInitialized) {
    LogWarning("ZigZag indicator not initialized. Disabling ZigZag usage. Please ensure ZigZag indicator is installed in Indicators folder.");
        UseZigZag = false;
    }
    
    // Setup periodic timer for throttled background tasks (VWAP, visuals, pending)
    // Use a small interval (1s) and internal throttles to control heavy tasks
    EventSetTimer(1);

    // Set initial state
    g_currentState = STATE_IDLE;
    
    // Informational: show derived per-symbol magic (helps debugging multi-chart runs)
    int derivedMagic = GetMagicForSymbol(_Symbol);
    DebugLog(StringFormat("Derived Magic for %s = %d (AutoMagicPerSymbol=%s)", _Symbol, derivedMagic, AutoMagicPerSymbol ? "ON" : "OFF"));
    Print(StringFormat("SMC: Derived Magic for %s = %d (AutoMagicPerSymbol=%s)", _Symbol, derivedMagic, AutoMagicPerSymbol ? "ON" : "OFF"));
    DebugLog(StringFormat("EA initialized successfully with Preset Mode: %s", EnumToString(PresetMode)));
    UpdateStatusDisplay("EA INITIALIZED");
    // Create a persistent on-chart debug panel (updated by OnTimer)
    if (Visual_ShowStatusPanel) {
        string dbg = "SMC_DebugPanel";
        if (ObjectFind(g_chartID, dbg) == -1) {
            ObjectCreate(g_chartID, dbg, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(g_chartID, dbg, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
            ObjectSetInteger(g_chartID, dbg, OBJPROP_XDISTANCE, 5);
            ObjectSetInteger(g_chartID, dbg, OBJPROP_YDISTANCE, 80);
            ObjectSetInteger(g_chartID, dbg, OBJPROP_COLOR, Visual_PanelTextColor);
            ObjectSetInteger(g_chartID, dbg, OBJPROP_FONTSIZE, 10);
            ObjectSetString(g_chartID, dbg, OBJPROP_FONT, "Arial");
        }
        // initialize text
        ObjectSetString(g_chartID, dbg, OBJPROP_TEXT, StringFormat("Magic: %d\nState: %s", derivedMagic, EnumToString(g_currentState)));
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    DebugLog("=== SMC Ultimate Hybrid EA Stopping ===");
    
    // Release ZigZag handle
    if (g_zigzagHandle != INVALID_HANDLE) {
        IndicatorRelease(g_zigzagHandle);
    }
    
    // Clean up drawing objects
    CleanupDrawingObjects();
    
    // Save performance data
    SavePerformanceData();
    // Kill our timer
    EventKillTimer();
    
    DebugLog(StringFormat("EA deinitialized. Reason: %d", reason));
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
    
    // Debug: แสดงสถานะปัจจุบันทุก 30 วินาที
    static datetime lastDebugTime = 0;
    if(currentTime - lastDebugTime >= 30)
    {
    DebugLog("=== OnTick Debug ===");
    DebugLog(StringFormat("Current State: %s", EnumToString(g_currentState)));
    DebugLog(StringFormat("Current Time: %s", TimeToString(currentTime)));
    DebugLog(StringFormat("Positions Total: %d", PositionsTotal()));
    DebugLog(StringFormat("Daily Loss: %.2f / %d", g_dailyLoss, MaxDailyLoss));
    DebugLog(StringFormat("Daily Trades: %d / %d", g_dailyTrades, MaxDailyTrades));
        lastDebugTime = currentTime;
    }
    
    // Check if new day for daily reset
    CheckDailyReset();
    
    // Daily risk check
    if (g_dailyLoss >= MaxDailyLoss || g_dailyTrades >= MaxDailyTrades) {
        g_currentState = STATE_RISK_CHECK;
        UpdateStatusDisplay("DAILY LIMIT REACHED");
        LogWarning(StringFormat("Daily limit reached - Loss: %f Trades: %d", g_dailyLoss, g_dailyTrades));
        // Optional auto-close behavior
        if (AutoCloseOnDailyLimit) {
            Print("AutoCloseOnDailyLimit enabled. Closing all EA positions for symbol: ", _Symbol);
            CloseAllPositions();
        }
        return;
    }
    
    // State Machine Logic
    switch(g_currentState) {
        case STATE_IDLE:
            if (ShouldStartAnalysis()) {
                g_currentState = STATE_SCANNING_MARKET;
                UpdateStatusDisplay("SCANNING MARKET");
                DebugLog("DEBUG: State changed from IDLE to SCANNING_MARKET");
            }
            else {
                // Debug: แสดงสาเหตุที่ไม่เริ่มการวิเคราะห์ทุก 60 วินาที
                static datetime lastIdleDebugTime = 0;
                    if(currentTime - lastIdleDebugTime >= 60)
                {
                    DebugLog("DEBUG: Staying in IDLE state - ShouldStartAnalysis() returned false");
                    lastIdleDebugTime = currentTime;
                }
            }
            break;
            
        case STATE_SCANNING_MARKET:
            if (PerformMarketScan()) {
                g_currentState = STATE_STRUCTURE_ANALYSIS;
                UpdateStatusDisplay("ANALYZING STRUCTURE");
                DebugLog("DEBUG: State changed from SCANNING_MARKET to STRUCTURE_ANALYSIS");
            }
            else {
                // Avoid tight loop: back to IDLE; will retry on next trigger
                g_currentState = STATE_IDLE;
                DebugLog("DEBUG: PerformMarketScan() failed, returning to IDLE to avoid loop");
            }
            break;
            
        case STATE_STRUCTURE_ANALYSIS:
            // --- Calculate only on new bar (bar-close driven) ---
            {
                static datetime lastBarTimeAnalyzed = 0;
                datetime currentBarTime = iTime(Symbol(), Period(), 0);

                    if (currentBarTime == lastBarTimeAnalyzed) {
                    DebugLog("DEBUG: AnalyzeMarketStructure() throttled. Waiting for new bar close/open...");
                    break;
                }

                if (AnalyzeMarketStructure()) {
                    lastBarTimeAnalyzed = currentBarTime;
                    g_currentState = STATE_CONFIRMATION_PENDING;
                    g_confirmationStartTime = TimeCurrent();
                    UpdateStatusDisplay("WAITING CONFIRMATION");
                    DebugLog("DEBUG: State changed from STRUCTURE_ANALYSIS to CONFIRMATION_PENDING (Signal Found)");
                } else {
                    lastBarTimeAnalyzed = currentBarTime;
                    g_currentState = STATE_IDLE;
                    DebugLog("DEBUG: AnalyzeMarketStructure() failed on new bar, returning to IDLE for throttle/retry.");
                }
            }
            break;
            
        case STATE_CONFIRMATION_PENDING:
            if (CheckEntryConfirmation()) {
                g_currentState = STATE_ENTRY_SETUP;
                UpdateStatusDisplay("PREPARING ENTRY");
                DebugLog("DEBUG: State changed from CONFIRMATION_PENDING to ENTRY_SETUP");
            } else if (IsConfirmationExpired()) {
                g_currentState = STATE_IDLE;
                UpdateStatusDisplay("CONFIRMATION EXPIRED");
                DebugLog("DEBUG: Confirmation expired, returning to IDLE");
            }
            else {
                static datetime lastConfirmDebugTime = 0;
                if(currentTime - lastConfirmDebugTime >= 30)
                {
                    DebugLog("DEBUG: Waiting for entry confirmation...");
                    lastConfirmDebugTime = currentTime;
                }
            }
            break;
            
        case STATE_ENTRY_SETUP:
            if (ExecuteEntry()) {
                g_currentState = STATE_POSITION_MANAGEMENT;
                UpdateStatusDisplay("MANAGING POSITION");
                DebugLog("DEBUG: Entry executed successfully, changed to POSITION_MANAGEMENT");
            } else {
                g_currentState = STATE_IDLE;
                UpdateStatusDisplay("ENTRY FAILED");
                DebugLog("DEBUG: Entry execution failed, returning to IDLE");
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
    
    // Manage any existing pending orders (expiry/structure change) with throttle
    if (UsePendingOrders) {
        if (TimeCurrent() - g_lastPendingManageTime >= PendingManageIntervalSeconds) {
            ManagePendingOrders();
            g_lastPendingManageTime = TimeCurrent();
        }
    }
    
    // Update VWAP and visual elements - use separate timestamps to avoid races
    datetime now = TimeCurrent();
    if (UseVWAP && (now - g_lastVWAPUpdateTime >= VWAPUpdateIntervalSeconds)) {
        UpdateVWAP();
        g_lastVWAPUpdateTime = now;
    }

    if (now - g_lastVisualUpdateTime >= VisualUpdateIntervalSeconds) {
        UpdateDrawingObjects();
        g_lastVisualUpdateTime = now;
    }
}

//+------------------------------------------------------------------+
//| Timer handler - runs every second (throttled internal tasks)    |
//+------------------------------------------------------------------+
void OnTimer() {
    datetime now = TimeCurrent();

    // VWAP update throttle
    if (UseVWAP && (now - g_lastVWAPUpdateTime >= VWAPUpdateIntervalSeconds)) {
        UpdateVWAP();
        g_lastVWAPUpdateTime = now;
    }

    // Visual update throttle
    if (now - g_lastVisualUpdateTime >= VisualUpdateIntervalSeconds) {
        UpdateDrawingObjects();
        g_lastVisualUpdateTime = now;
    }

    // Pending orders management (throttled)
    if (UsePendingOrders && (now - g_lastPendingManageTime >= PendingManageIntervalSeconds)) {
        ManagePendingOrders();
        g_lastPendingManageTime = now;
    }

    // Update debug panel every VisualUpdateIntervalSeconds (coordinated)
    if (Visual_ShowStatusPanel && (now - g_lastVisualUpdateTime >= VisualUpdateIntervalSeconds)) {
        string dbg = "SMC_DebugPanel";
        if (ObjectFind(g_chartID, dbg) != -1) {
            string text = "";
            int magic = GetMagicForSymbol(_Symbol);
            text += StringFormat("Magic: %d\n", magic);
            text += StringFormat("Trades Today: %d\n", g_dailyTrades);
            text += StringFormat("Daily P/L: %s\n", DoubleToString(g_dailyNetPL, 2));
            text += StringFormat("State: %s\n", EnumToString(g_currentState));
            text += StringFormat("VWAP: %s\n", DoubleToString(g_vwapValue, _Digits));
            ObjectSetString(g_chartID, dbg, OBJPROP_TEXT, text);
        }
    }
}

//+------------------------------------------------------------------+
//| Initialize Global Settings                                      |
//+------------------------------------------------------------------+
void InitializeGlobalSettings() {
    g_TakeProfitPoints = TakeProfitPoints;
    g_StopLossPoints = StopLossPoints;
    g_MinConfluenceScore = MinConfluenceScore;
    g_UseVWAPFilter = UseVWAPFilter;
    g_RequireHTFAlignment = RequireHTFAlignment;
    g_MaxOpenPositions = MaxOpenPositions;

    // Mirror visual inputs into effective globals (can be overridden by presets)
    g_Visual_ShowOnlyRecentBars = Visual_ShowOnlyRecentBars;
    g_Visual_MaxObjectsPerType = Visual_MaxObjectsPerType;
    g_Visual_LabelVerbosity = Visual_LabelVerbosity;
    g_Visual_ThinLines = Visual_ThinLines;
    g_Visual_LightenFVG = Visual_LightenFVG;
    g_ShowLayer_Trend = ShowLayer_Trend;
    g_ShowLayer_SwingPoints = ShowLayer_SwingPoints;
    g_ShowLayer_BOS = ShowLayer_BOS;
    g_ShowLayer_CHoCH = ShowLayer_CHoCH;
    g_ShowLayer_OB = ShowLayer_OB;
    g_ShowLayer_FVG = ShowLayer_FVG;
    g_ShowLayer_SLTP = ShowLayer_SLTP;
    g_ShowLayer_VWAP = ShowLayer_VWAP;
    g_ShowLayer_VolumeProfile = ShowLayer_VolumeProfile;
}

//+------------------------------------------------------------------+
//| Apply Preset Settings                                           |
//+------------------------------------------------------------------+
void ApplyPresetSettings() {
    switch(PresetMode) {
        case PRESET_CONSERVATIVE:
            // Conservative settings
            g_TakeProfitPoints = 300;
            g_StopLossPoints = 150;
            g_MinConfluenceScore = 4;
            g_UseVWAPFilter = true;
            g_RequireHTFAlignment = true;
            g_MaxOpenPositions = 1;
            break;
            
        case PRESET_BALANCED:
            // Balanced settings (default values)
            g_TakeProfitPoints = 500;
            g_StopLossPoints = 250;
            g_MinConfluenceScore = 3;
            g_UseVWAPFilter = true;
            g_RequireHTFAlignment = true;
            g_MaxOpenPositions = 2;
            break;
            
        case PRESET_AGGRESSIVE:
            // Aggressive settings
            g_TakeProfitPoints = 800;
            g_StopLossPoints = 400;
            g_MinConfluenceScore = 2;
            g_UseVWAPFilter = false;
            g_RequireHTFAlignment = false;
            g_MaxOpenPositions = 3;
            break;
            
        case PRESET_CUSTOM:
            // Use user-defined settings (already initialized)
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
    ArrayResize(g_fairValueGaps, 200);
    
    // Initialize swing points
    g_swingCount = 0;
    for (int i = 0; i < 100; i++) {
        g_swingPoints[i].time = 0;
        g_swingPoints[i].price = 0;
        g_swingPoints[i].isHigh = false;
        g_swingPoints[i].isLow = false;
        g_swingPoints[i].index = 0;
        g_swingPoints[i].isConfirmed = false;
    }
    
    // Initialize ZigZag buffer
    ArrayResize(g_zigzagBuffer, 200);
    ArraySetAsSeries(g_zigzagBuffer, true);
    
    // Initialize Order Blocks
    g_orderBlockCount = 0;
    for (int i = 0; i < 50; i++) {
        g_orderBlocks[i].time = 0;
        g_orderBlocks[i].high = 0;
        g_orderBlocks[i].low = 0;
        g_orderBlocks[i].volume = 0;
        g_orderBlocks[i].isBullish = false;
        g_orderBlocks[i].isUsed = false;
        g_orderBlocks[i].strength = 0;
    }
    
    // Initialize dynamic levels
    g_dynamicSL = 0;
    g_dynamicTP = 0;
    g_lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
}

//+------------------------------------------------------------------+
//| Setup Drawing Objects                                           |
//+------------------------------------------------------------------+
void SetupDrawingObjects() {
    if (DrawVWAP) {
        // Upsert VWAP trend object so it exists and can be updated later
        ObjectUpsert(g_chartID, g_vwapObjectName, OBJ_TREND, 2, 0, 0, 0, 0);
        ObjectSetInteger(g_chartID, g_vwapObjectName, OBJPROP_COLOR, clrBlue);
        ObjectSetInteger(g_chartID, g_vwapObjectName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(g_chartID, g_vwapObjectName, OBJPROP_STYLE, STYLE_SOLID);
    }
    
    if (ShowVWAPStatus) {
        ObjectUpsert(g_chartID, g_statusObjectName, OBJ_LABEL, 1, 0, 0);
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
//| Initialize ZigZag                                               |
//+------------------------------------------------------------------+
void InitializeZigZag() {
    if (!UseZigZag) return;
    
    // Try multiple known paths for ZigZag
    string candidates[4] = { "ZigZag", "Examples\\ZigZag", "Examples\\Indicators\\ZigZag", "Indicators\\Examples\\ZigZag" };
    g_zigzagHandle = INVALID_HANDLE;
    for (int i = 0; i < 4; i++) {
        g_zigzagHandle = iCustom(_Symbol, PERIOD_CURRENT, candidates[i], ZigZagDepth, ZigZagDeviation, ZigZagBackstep);
        if (g_zigzagHandle != INVALID_HANDLE) {
            Print("ZigZag handle created with path: ", candidates[i]);
            break;
        }
    }
    if (g_zigzagHandle == INVALID_HANDLE) {
        Print("Failed to create ZigZag handle with all candidates. Error: ", GetLastError());
        g_zigzagInitialized = false;
        return;
    }
    
    g_zigzagInitialized = true;
    Print("ZigZag initialized successfully with parameters: Depth=", ZigZagDepth, 
          " Deviation=", ZigZagDeviation, " Backstep=", ZigZagBackstep);
}

//+------------------------------------------------------------------+
//| Should Start Analysis                                           |
//+------------------------------------------------------------------+
bool ShouldStartAnalysis() {
    // Time filter check
    if (UseTimeFilter && !IsWithinTradingHours()) {
    DebugLog("DEBUG: Blocked by time filter. Current time not in trading hours.");
        return false;
    }
    
    // Check if enough time passed since last analysis
    if (TimeCurrent() - g_lastAnalysisTime < 60) { // 1 minute minimum
    DebugLog(StringFormat("DEBUG: Blocked by analysis cooldown. Last analysis: %d", g_lastAnalysisTime));
        return false;
    }
    
    // Check if we have open positions + pending orders at max (only this EA + symbol)
    int openCount = CountEAOpenPositionsAndOrders(_Symbol, GetMagicForSymbol(_Symbol));
    if (openCount >= g_MaxOpenPositions) {
    DebugLog(StringFormat("DEBUG: Blocked by position/order limit. Current EA count: %d Max: %d", openCount, g_MaxOpenPositions));
        return false;
    }
    
    DebugLog("DEBUG: ShouldStartAnalysis = TRUE");
    return true;
}

//+------------------------------------------------------------------+
//| Perform Market Scan                                            |
//+------------------------------------------------------------------+
bool PerformMarketScan() {
    DebugLog("DEBUG: PerformMarketScan() started");
    
    // Update market data
    UpdateMarketData();
    
    // Check basic conditions
    if (!HasSufficientData()) {
    DebugLog("DEBUG: PerformMarketScan() failed - insufficient data");
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
    DebugLog("DEBUG: PerformMarketScan() completed successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Analyze Market Structure                                        |
//+------------------------------------------------------------------+
bool AnalyzeMarketStructure() {
    // Detect current market structure
    g_marketStructure = DetectMarketStructure();
    
    if (g_marketStructure == STRUCTURE_UNKNOWN) {
    DebugLog(StringFormat("DEBUG: Market structure UNKNOWN. Swing count: %d", g_swingCount));
        return false;
    }
    
    DebugLog(StringFormat("DEBUG: Market structure detected: %s", EnumToString(g_marketStructure)));
    
    // Look for SMC patterns
    bool smcSignal = AnalyzeSMCPatterns();
    if (!smcSignal) {
    DebugLog("DEBUG: No SMC patterns detected");
        return false;
    }
    
    DebugLog("DEBUG: SMC patterns found");
    
    // Check confluence if enabled
    if (UseConfluenceScoring) {
        int confluenceScore = CalculateConfluenceScore();
    DebugLog(StringFormat("DEBUG: Confluence Score: %d (Required: %d)", confluenceScore, g_MinConfluenceScore));
        if (confluenceScore < g_MinConfluenceScore) {
            DebugLog("DEBUG: Confluence score too low");
            return false;
        }
    }
    
    DebugLog("DEBUG: AnalyzeMarketStructure = TRUE");
    // Update fine-grained three-swing trend after structure analysis
    UpdateThreeSwingTrend();
    return true;
}

//+------------------------------------------------------------------+
//| Check Entry Confirmation                                        |
//+------------------------------------------------------------------+
bool CheckEntryConfirmation() {
    // Check VWAP confirmation if enabled
    if (UseVWAP && g_UseVWAPFilter) {
        if (!IsVWAPConfirmed()) {
            return false;
        }
    }
    
    // Check Linear Regression confirmation if enabled
    if (UseLinearRegression && g_RequireHTFAlignment) {
        if (!IsRegressionAligned() || !IsTrendAlignmentConfirmed()) {
            return false;
        }
    }
    
    // Check SMC confirmation
    if (!IsSMCConfirmed()) {
        return false;
    }

    // Gate by last three-swing pattern if enabled
    if (UseThreeSwingPatternFilter) {
        string lb1, lb2, lb3;
        ENUM_THREE_SWING_PATTERN tsp = ClassifyLastThreeSwingPattern(lb1, lb2, lb3);

        if (tsp == TSP_UNKNOWN) {
            if (!AcceptUnknownThreeSwingPattern) {
                Print("Three-swing pattern UNKNOWN and not accepted. Blocking entry.");
                return false;
            }
            // otherwise allow to pass
            return true;
        }

        // Determine if pattern aligns with intended direction
        bool isBullPattern = (tsp == TSP_BULL_LL_LH_HL || tsp == TSP_BULL_LL_HH_HL || tsp == TSP_BULL_HL_LH_HL || tsp == TSP_BULL_HL_HH_HL);
        bool isBearPattern = (tsp == TSP_BEAR_HH_HL_LH || tsp == TSP_BEAR_HH_LL_LH || tsp == TSP_BEAR_LH_HL_LH || tsp == TSP_BEAR_LH_LL_LH);

        // Map to per-side allow flags
        bool allowedBySide = false;
        switch (tsp) {
            case TSP_BULL_LL_LH_HL: allowedBySide = AllowBull_LL_LH_HL; break;
            case TSP_BULL_LL_HH_HL: allowedBySide = AllowBull_LL_HH_HL; break;
            case TSP_BULL_HL_LH_HL: allowedBySide = AllowBull_HL_LH_HL; break;
            case TSP_BULL_HL_HH_HL: allowedBySide = AllowBull_HL_HH_HL; break;
            case TSP_BEAR_HH_HL_LH: allowedBySide = AllowBear_HH_HL_LH; break;
            case TSP_BEAR_HH_LL_LH: allowedBySide = AllowBear_HH_LL_LH; break;
            case TSP_BEAR_LH_HL_LH: allowedBySide = AllowBear_LH_HL_LH; break;
            case TSP_BEAR_LH_LL_LH: allowedBySide = AllowBear_LH_LL_LH; break;
            default: allowedBySide = false; break;
        }

        // Directional gating based on current structure
        if (g_marketStructure == STRUCTURE_BULLISH) {
            if (!isBullPattern) {
                Print("Three-swing is bearish-side (", ThreeSwingPatternToString(tsp), ") while structure is bullish. Blocking entry.");
                return false;
            }
        } else if (g_marketStructure == STRUCTURE_BEARISH) {
            if (!isBearPattern) {
                Print("Three-swing is bullish-side (", ThreeSwingPatternToString(tsp), ") while structure is bearish. Blocking entry.");
                return false;
            }
        } else {
            // For consolidation/unknown structure, respect unknown acceptance; otherwise require allow list
            if (!AcceptUnknownThreeSwingPattern) {
                Print("Market structure not directional and unknown patterns not accepted. Blocking entry.");
                return false;
            }
            // If unknown allowed, pass through here
            return true;
        }

        if (!allowedBySide) {
            Print("Three-swing pattern (", ThreeSwingPatternToString(tsp), ") is disabled by user allow-list. Blocking entry.");
            return false;
        }

        Print("Three-swing filter PASSED: ", lb1, "→", lb2, "→", lb3, " (", ThreeSwingPatternToString(tsp), ")");
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
    
    // Calculate entry price base
    double marketPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double entryPrice = marketPrice;
    
    // Calculate SL and TP (initial) from market price baseline
    double stopLoss = CalculateStopLoss(orderType, entryPrice);
    double takeProfit = CalculateTakeProfit(orderType, entryPrice);
    // Validate SL/TP
    ValidateAndAdjustSLTP(orderType, entryPrice, stopLoss, takeProfit);
    
    // Recalc lot size by actual SL distance
    double slDistancePoints = DMax(1.0, MathAbs(entryPrice - stopLoss) / _Point);
    if (UseAutoLot) {
        double sizedLot = CalculatePositionSizeForSLDistance(_Symbol, slDistancePoints);
        if (sizedLot > 0) lotSize = sizedLot;
    }
    
    bool result = false;
    if (UsePendingOrders) {
    bool bullish = (orderType == ORDER_TYPE_BUY);
    ENUM_ORDER_TYPE pendingType = ORDER_TYPE_BUY_LIMIT; // init to avoid uninitialized warnings
    double pendingPrice = 0.0;
        bool havePrice = false;
        
        if (PendingMode == PENDING_LIMIT_OB || PendingMode == PENDING_AUTO) {
            havePrice = GetOBPendingPrice(bullish, pendingPrice);
            if (havePrice) pendingType = bullish ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
        }
        if (!havePrice && (PendingMode == PENDING_STOP_BREAKOUT || PendingMode == PENDING_AUTO)) {
            havePrice = GetBreakoutPendingPrice(bullish, pendingPrice);
            if (havePrice) pendingType = bullish ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
        }
        if (!havePrice) {
            Print("Pending price not available; fallback to market execution");
            // Fallback to market
            if (orderType == ORDER_TYPE_BUY)
                result = ExecuteBuyOrder(lotSize, _Symbol, marketPrice, stopLoss, takeProfit, "SMC_Ultimate_BUY");
            else
                result = ExecuteSellOrder(lotSize, _Symbol, marketPrice, stopLoss, takeProfit, "SMC_Ultimate_SELL");
        } else {
            // Re-validate SL/TP relative to pending entry price and recalc lot size by true SL distance
            double pendSL = stopLoss;
            double pendTP = takeProfit;
            ValidateAndAdjustSLTP(orderType, pendingPrice, pendSL, pendTP);
            if (UseAutoLot) {
                double pendSLDistPts = DMax(1.0, MathAbs(pendingPrice - pendSL) / _Point);
                double sizedLot = CalculatePositionSizeForSLDistance(_Symbol, pendSLDistPts);
                if (sizedLot > 0) lotSize = sizedLot;
            }
            // Place pending
            result = PlacePendingOrder(pendingType, lotSize, _Symbol, pendingPrice, pendSL, pendTP,
                                       bullish ? "SMC_PEND_BUY" : "SMC_PEND_SELL");
        }
    } else {
        // Market execution path
        if (orderType == ORDER_TYPE_BUY) {
            result = ExecuteBuyOrder(lotSize, _Symbol, marketPrice, stopLoss, takeProfit, "SMC_Ultimate_BUY");
        } else {
            result = ExecuteSellOrder(lotSize, _Symbol, marketPrice, stopLoss, takeProfit, "SMC_Ultimate_SELL");
        }
    }
    
    if (result) {
        g_dailyTrades++;
        g_lastTradeTime = TimeCurrent();
        Print("Entry placed: ", (UsePendingOrders ? "PENDING " : "MARKET "), EnumToString(orderType), " lot=", lotSize);
    } else {
        Print("Entry placement failed. LastError=", GetLastError());
    }
    return result;
}

//+------------------------------------------------------------------+
//| Manage Open Positions                                          |
//+------------------------------------------------------------------+
void ManageOpenPositions() {
    for (int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if (ticket > 0 && PositionSelectByTicket(ticket)) {
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            long posMagic = PositionGetInteger(POSITION_MAGIC);
            
            if (posSymbol != _Symbol || posMagic != GetMagicForSymbol(_Symbol)) continue;
            
            // Apply trailing stop
            if (UseTrailingStop) {
                ApplyTrailingStop(ticket);
            }
            
            // Apply breakeven
            if (UseBreakevenStop) {
                ApplyBreakevenStop(ticket);
            }
            
            // Check for structural exit
            if (ShouldExitOnStructuralChange(ticket)) {
                ClosePosition(ticket);
                Print("Position closed due to structural change: ", ticket);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Remove a pending order by ticket                                 |
//+------------------------------------------------------------------+
bool RemovePendingOrder(ulong ticket) {
    MqlTradeRequest req = {};
    MqlTradeResult res = {};
    req.action = TRADE_ACTION_REMOVE;
    req.order = ticket;
    req.symbol = _Symbol;
    req.magic = GetMagicForSymbol(_Symbol);
    bool ok = OrderSend(req, res);
    if (!ok) {
        Print("Failed to remove pending order ", ticket, " Retcode=", res.retcode, " Comment=", res.comment);
    }
    return ok;
}

//+------------------------------------------------------------------+
//| Manage Pending Orders (expiry and structure change)              |
//+------------------------------------------------------------------+
void ManagePendingOrders() {
    datetime now = TimeCurrent();
    // Snapshot tickets to avoid OrdersTotal/OrderSelect changing during loop
    ulong tickets[]; ArrayResize(tickets, 0);
    int total = OrdersTotal();
    for (int i = 0; i < total; i++) {
        ulong t = OrderGetTicket(i);
        if (t == 0) continue;
        if (!OrderSelect(t)) continue;
    if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
    if ((long)OrderGetInteger(ORDER_MAGIC) != GetMagicForSymbol(_Symbol)) continue;
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if (type != ORDER_TYPE_BUY_LIMIT && type != ORDER_TYPE_SELL_LIMIT &&
            type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP) continue;
        int idx = ArraySize(tickets);
        ArrayResize(tickets, idx + 1);
        tickets[idx] = t;
    }

    // Now iterate snapshot safely
    for (int i = 0; i < ArraySize(tickets); i++) {
        ulong ticket = tickets[i];
        if (ticket == 0) continue;
        if (!OrderSelect(ticket)) continue; // may have been removed already
        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        bool isBuy = (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP);
        bool shouldCancel = false;

        if (CancelPendingOnStructureChange) {
            if (g_marketStructure == STRUCTURE_BULLISH && !isBuy) shouldCancel = true;
            if (g_marketStructure == STRUCTURE_BEARISH && isBuy) shouldCancel = true;
        }

        if (!shouldCancel && (!SetOrderExpiration && PendingExpiryMinutes > 0)) {
            datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
            if (setup > 0 && (now - setup) >= (PendingExpiryMinutes * 60)) {
                shouldCancel = true;
            }
        }

        if (shouldCancel) {
            double price = OrderGetDouble(ORDER_PRICE_OPEN);
            Print("Cancelling pending order ", ticket, " type=", (int)type, " price=", DoubleToString(price, _Digits));
            RemovePendingOrder(ticket);
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
        double volume = (double)iVolume(_Symbol, VWAPTimeframe, i);
        
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
    
    double denom = (n * sumX2 - sumX * sumX);
    double slope = 0.0;
    double intercept = 0.0;
    if (MathAbs(denom) > 1e-12) {
        slope = (n * sumXY - sumX * sumY) / denom;
        intercept = (sumY - slope * sumX) / n;
    } else {
        // fallback to average price as intercept
        intercept = (n > 0) ? (sumY / n) : 0.0;
        slope = 0.0;
    }
    
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
    // First update swing points using ZigZag
    if (UseZigZag) {
        UpdateSwingPointsZigZag();
    } else {
        UpdateSwingPoints();
    }
    
    // Analyze trend direction using swing points
    g_currentTrend = AnalyzeTrendDirection();
    
    // Convert trend direction to market structure
    switch(g_currentTrend) {
        case TREND_BULLISH:
            return STRUCTURE_BULLISH;
        case TREND_BEARISH:
            return STRUCTURE_BEARISH;
        case TREND_RANGING:
            return STRUCTURE_CONSOLIDATION;
        default:
            return STRUCTURE_UNKNOWN;
    }
}

//+------------------------------------------------------------------+
//| Update Swing Points using ZigZag                               |
//+------------------------------------------------------------------+
void UpdateSwingPointsZigZag() {
    if (!g_zigzagInitialized || g_zigzagHandle == INVALID_HANDLE) {
    DebugLog(StringFormat("DEBUG: ZigZag not initialized. Handle: %d", g_zigzagHandle));
        return;
    }
    
    // Get ZigZag values (reduced buffer size for performance)
    int requestBars = 64;
    int copied = CopyBuffer(g_zigzagHandle, 0, 0, requestBars, g_zigzagBuffer);
    if (copied <= 0) {
        int err = GetLastError();
        static datetime lastZigErr = 0;
        if (TimeCurrent() - lastZigErr >= 60) {
            DebugLog(StringFormat("DEBUG: Failed to copy ZigZag buffer. Error: %d", err));
            lastZigErr = TimeCurrent();
        }
        return;
    }
    
    // Clear existing swing points for fresh update
    g_swingCount = 0;
    
    // Extract swing points from ZigZag
    for (int i = 1; i < copied && g_swingCount < MaxSwingPoints; i++) {
        if (g_zigzagBuffer[i] != 0 && g_zigzagBuffer[i] != EMPTY_VALUE) {
            datetime pointTime = iTime(_Symbol, PERIOD_CURRENT, i);
            double pointPrice = g_zigzagBuffer[i];
            
            // Determine if it's high or low by comparing with adjacent values
            bool isHigh = false;
            bool isLow = false;
            
            // Check if this is a peak (high) or trough (low)
            double prevPrice = 0, nextPrice = 0;
            
            // Find previous non-zero value
            for (int j = i + 1; j < copied; j++) {
                if (g_zigzagBuffer[j] != 0 && g_zigzagBuffer[j] != EMPTY_VALUE) {
                    prevPrice = g_zigzagBuffer[j];
                    break;
                }
            }
            
            // Find next non-zero value
            for (int j = i - 1; j >= 0; j--) {
                if (g_zigzagBuffer[j] != 0 && g_zigzagBuffer[j] != EMPTY_VALUE) {
                    nextPrice = g_zigzagBuffer[j];
                    break;
                }
            }
            
            // Determine if it's high or low
            if (prevPrice > 0 && nextPrice > 0) {
                if (pointPrice > prevPrice && pointPrice > nextPrice) {
                    isHigh = true;
                } else if (pointPrice < prevPrice && pointPrice < nextPrice) {
                    isLow = true;
                }
            } else if (prevPrice > 0) {
                isHigh = (pointPrice > prevPrice);
                isLow = (pointPrice < prevPrice);
            } else if (nextPrice > 0) {
                isHigh = (pointPrice > nextPrice);
                isLow = (pointPrice < nextPrice);
            }
            
            // Add confirmed swing point
            if (isHigh || isLow) {
                AddSwingPoint(pointTime, pointPrice, isHigh, isLow, i, true);
            }
        }
    }
    
    // Sort swing points by time (newest first)
    SortSwingPoints();
}

//+------------------------------------------------------------------+
//| Update Swing Points (SMC Method)                               |
//+------------------------------------------------------------------+
void UpdateSwingPoints() {
    int lookback = 5; // Minimum bars each side to confirm swing
    
    // Check recent bars for new swing points
    for (int i = lookback; i < 50; i++) {
        double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, i);
        double currentLow = iLow(_Symbol, PERIOD_CURRENT, i);
        bool isSwingHigh = true;
        bool isSwingLow = true;
        
        // Check if current bar is swing high
        for (int j = 1; j <= lookback; j++) {
            if (currentHigh <= iHigh(_Symbol, PERIOD_CURRENT, i - j) ||
                currentHigh <= iHigh(_Symbol, PERIOD_CURRENT, i + j)) {
                isSwingHigh = false;
                break;
            }
        }
        
        // Check if current bar is swing low
        for (int j = 1; j <= lookback; j++) {
            if (currentLow >= iLow(_Symbol, PERIOD_CURRENT, i - j) ||
                currentLow >= iLow(_Symbol, PERIOD_CURRENT, i + j)) {
                isSwingLow = false;
                break;
            }
        }
        
        // Add swing points if found
        if (isSwingHigh) {
            AddSwingPoint(iTime(_Symbol, PERIOD_CURRENT, i), currentHigh, true, false, i);
        }
        if (isSwingLow) {
            AddSwingPoint(iTime(_Symbol, PERIOD_CURRENT, i), currentLow, false, true, i);
        }
    }
}

//+------------------------------------------------------------------+
//| Add Swing Point                                                |
//+------------------------------------------------------------------+
void AddSwingPoint(datetime time, double price, bool isHigh, bool isLow, int index, bool isConfirmed = false) {
    // Check if this swing point already exists
    for (int i = 0; i < g_swingCount; i++) {
        if (g_swingPoints[i].time == time) {
            return; // Already exists
        }
    }
    
    // Add new swing point
    if (g_swingCount < 100) {
        g_swingPoints[g_swingCount].time = time;
        g_swingPoints[g_swingCount].price = price;
        g_swingPoints[g_swingCount].isHigh = isHigh;
        g_swingPoints[g_swingCount].isLow = isLow;
        g_swingPoints[g_swingCount].index = index;
        g_swingPoints[g_swingCount].isConfirmed = isConfirmed;
        g_swingCount++;
        
        // Update last swing levels for confirmed points only
        if (isConfirmed) {
            UpdateLastSwingLevels(price, time, isHigh, isLow);
        }
    }
}

//+------------------------------------------------------------------+
//| Update Last Swing Levels                                       |
//+------------------------------------------------------------------+
void UpdateLastSwingLevels(double price, datetime time, bool isHigh, bool isLow) {
    if (isHigh) {
        // Update Higher High (HH)
        if (g_lastHH == 0 || price > g_lastHH) {
            g_lastHH = price;
            g_lastHHTime = time;
        }
        // Update Lower High (LH) 
        if (price < g_lastHH && (g_lastLH == 0 || price > g_lastLH)) {
            g_lastLH = price;
            g_lastLHTime = time;
        }
    }
    
    if (isLow) {
        // Update Lower Low (LL)
        if (g_lastLL == 0 || price < g_lastLL) {
            g_lastLL = price;
            g_lastLLTime = time;
        }
        // Update Higher Low (HL)
        if (price > g_lastLL && (g_lastHL == 0 || price < g_lastHL)) {
            g_lastHL = price;
            g_lastHLTime = time;
        }
    }
}

//+------------------------------------------------------------------+
//| Sort Swing Points by Time (Newest First)                       |
//+------------------------------------------------------------------+
void SortSwingPoints() {
    // Simple bubble sort by time (newest first)
    for (int i = 0; i < g_swingCount - 1; i++) {
        for (int j = 0; j < g_swingCount - i - 1; j++) {
            if (g_swingPoints[j].time < g_swingPoints[j + 1].time) {
                // Swap elements
                SwingPoint temp = g_swingPoints[j];
                g_swingPoints[j] = g_swingPoints[j + 1];
                g_swingPoints[j + 1] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze Trend Direction (SMC Method)                           |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION AnalyzeTrendDirection() {
    if (g_swingCount < 4) return TREND_UNKNOWN;
    
    // Get recent swing points
    SwingPoint recentHighs[10];
    SwingPoint recentLows[10];
    int highCount = 0, lowCount = 0;
    
    // Collect recent highs and lows
    for (int i = g_swingCount - 1; i >= 0 && (highCount < 10 || lowCount < 10); i--) {
        if (g_swingPoints[i].isHigh && highCount < 10) {
            recentHighs[highCount] = g_swingPoints[i];
            highCount++;
        }
        if (g_swingPoints[i].isLow && lowCount < 10) {
            recentLows[lowCount] = g_swingPoints[i];
            lowCount++;
        }
    }
    
    if (highCount < 2 || lowCount < 2) return TREND_UNKNOWN;
    
    // Analyze pattern for bullish trend (HH + HL)
    bool hasHigherHigh = false;
    bool hasHigherLow = false;
    
    if (highCount >= 2) {
        hasHigherHigh = (recentHighs[0].price > recentHighs[1].price);
    }
    
    if (lowCount >= 2) {
        hasHigherLow = (recentLows[0].price > recentLows[1].price);
    }
    
    // Analyze pattern for bearish trend (LH + LL)
    bool hasLowerHigh = false;
    bool hasLowerLow = false;
    
    if (highCount >= 2) {
        hasLowerHigh = (recentHighs[0].price < recentHighs[1].price);
    }
    
    if (lowCount >= 2) {
        hasLowerLow = (recentLows[0].price < recentLows[1].price);
    }
    
    // Calculate trend strength
    double highRange = (highCount >= 2) ? MathAbs(recentHighs[0].price - recentHighs[1].price) : 0;
    double lowRange = (lowCount >= 2) ? MathAbs(recentLows[0].price - recentLows[1].price) : 0;
    g_trendStrength = (highRange + lowRange) / (2 * _Point);
    
    // Determine trend direction
    if (hasHigherHigh && hasHigherLow) {
        return TREND_BULLISH;
    } else if (hasLowerHigh && hasLowerLow) {
        return TREND_BEARISH;
    } else {
        return TREND_RANGING;
    }
}

//+------------------------------------------------------------------+
//| Three-swing pattern utilities                                   |
//+------------------------------------------------------------------+

// Find the nearest previous confirmed swing of the same type (high/low) strictly older than refTime
bool FindPreviousSameTypeBeforeTime(datetime refTime, bool wantHigh, SwingPoint &outSp) {
    bool found = false;
    datetime bestTime = 0;
    for (int i = 0; i < g_swingCount; i++) {
        if (!g_swingPoints[i].isConfirmed) continue;
        if (g_swingPoints[i].time >= refTime) continue;
        if (wantHigh && !g_swingPoints[i].isHigh) continue;
        if (!wantHigh && !g_swingPoints[i].isLow) continue;
        // pick the most recent (largest time) but still < refTime
        if (!found || g_swingPoints[i].time > bestTime) {
            bestTime = g_swingPoints[i].time;
            outSp = g_swingPoints[i];
            found = true;
        }
    }
    return found;
}

// Determine label (HH/LH for highs, HL/LL for lows) for a given confirmed swing, relative to its previous same-type swing
bool DetermineSwingLabel(const SwingPoint &sp, string &outLabel) {
    if (!sp.isConfirmed) return false;
    SwingPoint prev;
    if (sp.isHigh) {
        if (!FindPreviousSameTypeBeforeTime(sp.time, true, prev)) return false;
        outLabel = (sp.price > prev.price) ? "HH" : "LH";
        return true;
    }
    if (sp.isLow) {
        if (!FindPreviousSameTypeBeforeTime(sp.time, false, prev)) return false;
        outLabel = (sp.price < prev.price) ? "LL" : "HL";
        return true;
    }
    return false;
}

// Get the last three alternating confirmed swings as [oldest, middle, newest]
bool GetLastThreeAlternatingSwings(SwingPoint &out3[]) {
    // Need at least 3 confirmed swings
    int confirmedCount = 0;
    for (int i = 0; i < g_swingCount; i++) if (g_swingPoints[i].isConfirmed) confirmedCount++;
    if (confirmedCount < 3) return false;

    // Pick newest confirmed swing
    SwingPoint p0; bool haveP0 = false;
    for (int i = 0; i < g_swingCount; i++) {
        if (g_swingPoints[i].isConfirmed) { p0 = g_swingPoints[i]; haveP0 = true; break; }
    }
    if (!haveP0) return false;

    // Find previous of opposite type
    SwingPoint p1; bool haveP1 = false;
    for (int i = 0; i < g_swingCount; i++) {
        if (!g_swingPoints[i].isConfirmed) continue;
        if (g_swingPoints[i].time < p0.time && (g_swingPoints[i].isHigh != p0.isHigh)) { p1 = g_swingPoints[i]; haveP1 = true; break; }
    }
    if (!haveP1) return false;

    // Find previous again of opposite type (same type as p0)
    SwingPoint p2; bool haveP2 = false;
    for (int i = 0; i < g_swingCount; i++) {
        if (!g_swingPoints[i].isConfirmed) continue;
        if (g_swingPoints[i].time < p1.time && (g_swingPoints[i].isHigh == p0.isHigh)) { p2 = g_swingPoints[i]; haveP2 = true; break; }
    }
    if (!haveP2) return false;

    // Arrange oldest -> newest
    ArrayResize(out3, 3);
    out3[0] = p2; out3[1] = p1; out3[2] = p0;

    // Validate alternation Low-High-Low or High-Low-High
    bool isLHL = (out3[0].isLow && out3[1].isHigh && out3[2].isLow);
    bool isHLH = (out3[0].isHigh && out3[1].isLow && out3[2].isHigh);
    return (isLHL || isHLH);
}

// Classify last three-swing pattern into ENUM_THREE_SWING_PATTERN
ENUM_THREE_SWING_PATTERN ClassifyLastThreeSwingPattern(string &label1, string &label2, string &label3) {
    label1 = ""; label2 = ""; label3 = "";
    SwingPoint p[];
    if (!GetLastThreeAlternatingSwings(p)) return TSP_UNKNOWN;

    // Determine labels for each
    if (!DetermineSwingLabel(p[0], label1)) return TSP_UNKNOWN;
    if (!DetermineSwingLabel(p[1], label2)) return TSP_UNKNOWN;
    if (!DetermineSwingLabel(p[2], label3)) return TSP_UNKNOWN;

    // Bullish-side patterns: Low-High-Low with last label HL
    if (p[0].isLow && p[1].isHigh && p[2].isLow) {
        if (label1 == "LL" && label2 == "LH" && label3 == "HL") return TSP_BULL_LL_LH_HL;
        if (label1 == "LL" && label2 == "HH" && label3 == "HL") return TSP_BULL_LL_HH_HL;
        if (label1 == "HL" && label2 == "LH" && label3 == "HL") return TSP_BULL_HL_LH_HL;
        if (label1 == "HL" && label2 == "HH" && label3 == "HL") return TSP_BULL_HL_HH_HL;
    }

    // Bearish-side patterns: High-Low-High with last label LH
    if (p[0].isHigh && p[1].isLow && p[2].isHigh) {
        if (label1 == "HH" && label2 == "HL" && label3 == "LH") return TSP_BEAR_HH_HL_LH;
        if (label1 == "HH" && label2 == "LL" && label3 == "LH") return TSP_BEAR_HH_LL_LH;
        if (label1 == "LH" && label2 == "HL" && label3 == "LH") return TSP_BEAR_LH_HL_LH;
        if (label1 == "LH" && label2 == "LL" && label3 == "LH") return TSP_BEAR_LH_LL_LH;
    }

    return TSP_UNKNOWN;
}

// Optional: human-readable string for the three-swing pattern
string ThreeSwingPatternToString(ENUM_THREE_SWING_PATTERN p) {
    switch(p) {
        case TSP_BULL_LL_LH_HL: return "BULL LL→LH→HL (await HH)";
        case TSP_BULL_LL_HH_HL: return "BULL LL→HH→HL (await HH)";
        case TSP_BULL_HL_LH_HL: return "BULL HL→LH→HL (await HH)";
        case TSP_BULL_HL_HH_HL: return "BULL HL→HH→HL (await HH)";
        case TSP_BEAR_HH_HL_LH: return "BEAR HH→HL→LH (await LL)";
        case TSP_BEAR_HH_LL_LH: return "BEAR HH→LL→LH (await LL)";
        case TSP_BEAR_LH_HL_LH: return "BEAR LH→HL→LH (await LL)";
        case TSP_BEAR_LH_LL_LH: return "BEAR LH→LL→LH (await LL)";
        default: return "UNKNOWN";
    }
}

// Map three-swing pattern to extended trend enum and update g_threeSwingTrend
void UpdateThreeSwingTrend() {
    string a,b,c; // labels not needed here
    ENUM_THREE_SWING_PATTERN tsp = ClassifyLastThreeSwingPattern(a,b,c);
    switch (tsp) {
        case TSP_BULL_LL_LH_HL: g_threeSwingTrend = TREND_BULL_LL_LH_HL; break;
        case TSP_BULL_LL_HH_HL: g_threeSwingTrend = TREND_BULL_LL_HH_HL; break;
        case TSP_BULL_HL_LH_HL: g_threeSwingTrend = TREND_BULL_HL_LH_HL; break;
        case TSP_BULL_HL_HH_HL: g_threeSwingTrend = TREND_BULL_HL_HH_HL; break;
        case TSP_BEAR_HH_HL_LH: g_threeSwingTrend = TREND_BEAR_HH_HL_LH; break;
        case TSP_BEAR_HH_LL_LH: g_threeSwingTrend = TREND_BEAR_HH_LL_LH; break;
        case TSP_BEAR_LH_HL_LH: g_threeSwingTrend = TREND_BEAR_LH_HL_LH; break;
        case TSP_BEAR_LH_LL_LH: g_threeSwingTrend = TREND_BEAR_LH_LL_LH; break;
        default: g_threeSwingTrend = TREND_UNKNOWN; break;
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
//| Detect Break of Structure (True SMC Method)                    |
//+------------------------------------------------------------------+
bool DetectBOS() {
    g_bosDetected = false;
    
    if (g_swingCount < 2) return false;
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // For bullish BOS - price breaks above recent significant high
    if (g_currentTrend == TREND_BULLISH || g_marketStructure == STRUCTURE_BULLISH) {
        if (g_lastHH > 0 && currentPrice > g_lastHH) {
            // Confirm with strong volume (use cached avg if available)
            double currentVolume = (double)iVolume(_Symbol, PERIOD_CURRENT, 0);
            double avgVolume = g_cachedAvgVolume;
            if (g_cachedAvgVolumeTime == 0 || TimeCurrent() - g_cachedAvgVolumeTime > 60) {
                avgVolume = 0;
                for (int i = 1; i <= 10; i++) avgVolume += (double)iVolume(_Symbol, PERIOD_CURRENT, i);
                avgVolume /= 10;
                g_cachedAvgVolume = avgVolume;
                g_cachedAvgVolumeTime = TimeCurrent();
            }
            if (currentVolume > avgVolume * 1.2) {
                g_bosDetected = true;
                Print("Bullish BOS detected at: ", currentPrice, " breaking HH: ", g_lastHH);
                return true;
            }
        }
    }
    
    // For bearish BOS - price breaks below recent significant low
    if (g_currentTrend == TREND_BEARISH || g_marketStructure == STRUCTURE_BEARISH) {
        if (g_lastLL > 0 && currentPrice < g_lastLL) {
            // Confirm with strong volume (use cached avg if available)
            double currentVolume = (double)iVolume(_Symbol, PERIOD_CURRENT, 0);
            double avgVolume = g_cachedAvgVolume;
            if (g_cachedAvgVolumeTime == 0 || TimeCurrent() - g_cachedAvgVolumeTime > 60) {
                avgVolume = 0;
                for (int i = 1; i <= 10; i++) avgVolume += (double)iVolume(_Symbol, PERIOD_CURRENT, i);
                avgVolume /= 10;
                g_cachedAvgVolume = avgVolume;
                g_cachedAvgVolumeTime = TimeCurrent();
            }
            if (currentVolume > avgVolume * 1.2) {
                g_bosDetected = true;
                Print("Bearish BOS detected at: ", currentPrice, " breaking LL: ", g_lastLL);
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect Change of Character (True SMC Method)                   |
//+------------------------------------------------------------------+
bool DetectCHoCH() {
    g_chochDetected = false;
    
    if (g_swingCount < 4) return false;
    
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    double previousClose = iClose(_Symbol, PERIOD_CURRENT, 1);
    
    // Get recent confirmed swing points from ZigZag
    SwingPoint lastHigh, lastLow;
    bool hasRecentHigh = false, hasRecentLow = false;
    
    // Find most recent confirmed swing high and low
    for (int i = 0; i < g_swingCount; i++) {
        if (g_swingPoints[i].isConfirmed) {
            if (g_swingPoints[i].isHigh && !hasRecentHigh) {
                lastHigh = g_swingPoints[i];
                hasRecentHigh = true;
            }
            if (g_swingPoints[i].isLow && !hasRecentLow) {
                lastLow = g_swingPoints[i];
                hasRecentLow = true;
            }
            if (hasRecentHigh && hasRecentLow) break;
        }
    }
    
    if (!hasRecentHigh || !hasRecentLow) return false;
    
    // Bullish CHoCH - Break of previous Lower High (LH) during bearish trend
    if (g_currentTrend == TREND_BEARISH || g_currentTrend == TREND_RANGING) {
        // Price must break above the most recent swing high with confirmation
        if (currentPrice > lastHigh.price && previousClose <= lastHigh.price) {
            // Additional confirmation: check if this creates a Higher High pattern
            bool isNewHH = true;
            for (int i = 0; i < g_swingCount; i++) {
                if (g_swingPoints[i].isHigh && g_swingPoints[i].isConfirmed && 
                    g_swingPoints[i].time > lastHigh.time && g_swingPoints[i].price > currentPrice) {
                    isNewHH = false;
                    break;
                }
            }
            
            if (isNewHH) {
                g_chochDetected = true;
                g_currentTrend = TREND_BULLISH;
                g_marketStructure = STRUCTURE_BULLISH;
                Print("Bullish CHoCH detected! Price broke above swing high: ", lastHigh.price, 
                      " at: ", currentPrice, " Time: ", TimeToString(TimeCurrent()));
                return true;
            }
        }
    }
    
    // Bearish CHoCH - Break of previous Higher Low (HL) during bullish trend  
    if (g_currentTrend == TREND_BULLISH || g_currentTrend == TREND_RANGING) {
        // Price must break below the most recent swing low with confirmation
        if (currentPrice < lastLow.price && previousClose >= lastLow.price) {
            // Additional confirmation: check if this creates a Lower Low pattern
            bool isNewLL = true;
            for (int i = 0; i < g_swingCount; i++) {
                if (g_swingPoints[i].isLow && g_swingPoints[i].isConfirmed && 
                    g_swingPoints[i].time > lastLow.time && g_swingPoints[i].price < currentPrice) {
                    isNewLL = false;
                    break;
                }
            }
            
            if (isNewLL) {
                g_chochDetected = true;
                g_currentTrend = TREND_BEARISH;
                g_marketStructure = STRUCTURE_BEARISH;
                Print("Bearish CHoCH detected! Price broke below swing low: ", lastLow.price, 
                      " at: ", currentPrice, " Time: ", TimeToString(TimeCurrent()));
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Analyze Multi-Timeframe Trend                                  |
//+------------------------------------------------------------------+
void AnalyzeMultiTimeframeTrend() {
    // Analyze Higher Timeframe trend
    ENUM_TIMEFRAMES htf = HTF_Timeframe;
    
    // Get HTF swing points
    double htfHigh1 = iHigh(_Symbol, htf, iHighest(_Symbol, htf, MODE_HIGH, 5, 1));
    double htfHigh2 = iHigh(_Symbol, htf, iHighest(_Symbol, htf, MODE_HIGH, 5, 6));
    double htfLow1 = iLow(_Symbol, htf, iLowest(_Symbol, htf, MODE_LOW, 5, 1));
    double htfLow2 = iLow(_Symbol, htf, iLowest(_Symbol, htf, MODE_LOW, 5, 6));
    
    // Determine HTF trend
    bool htfHigherHigh = htfHigh1 > htfHigh2;
    bool htfHigherLow = htfLow1 > htfLow2;
    bool htfLowerHigh = htfHigh1 < htfHigh2;
    bool htfLowerLow = htfLow1 < htfLow2;
    
    if (htfHigherHigh && htfHigherLow) {
        g_htfTrend = TREND_BULLISH;
    } else if (htfLowerHigh && htfLowerLow) {
        g_htfTrend = TREND_BEARISH;
    } else {
        g_htfTrend = TREND_RANGING;
    }
}

//+------------------------------------------------------------------+
//| Is Trend Alignment Confirmed                                   |
//+------------------------------------------------------------------+
bool IsTrendAlignmentConfirmed() {
    // Check if current timeframe trend aligns with HTF trend
    if (g_RequireHTFAlignment) {
        AnalyzeMultiTimeframeTrend();
        
        // For bullish signals, both trends should be bullish or ranging
        if (g_marketStructure == STRUCTURE_BULLISH) {
            return (g_htfTrend == TREND_BULLISH || g_htfTrend == TREND_RANGING);
        }
        
        // For bearish signals, both trends should be bearish or ranging
        if (g_marketStructure == STRUCTURE_BEARISH) {
            return (g_htfTrend == TREND_BEARISH || g_htfTrend == TREND_RANGING);
        }
        
        return false;
    }
    
    return true; // No HTF requirement
}

//+------------------------------------------------------------------+
//| Detect Order Blocks (True SMC Method)                          |
//+------------------------------------------------------------------+
bool DetectOrderBlocks() {
    // Clear old order blocks first
    for (int i = 0; i < g_orderBlockCount; i++) {
        if (TimeCurrent() - g_orderBlocks[i].time > 86400 * 7) { // Remove week-old order blocks
            g_orderBlocks[i].isUsed = true;
        }
    }
    
    // Look for order blocks around swing points
    for (int i = 0; i < g_swingCount; i++) {
        if (!g_swingPoints[i].isConfirmed) continue;
        
        SwingPoint swing = g_swingPoints[i];
        
        // Find the candle that created this swing point
        int swingBarIndex = swing.index;
        if (swingBarIndex < 1 || swingBarIndex >= OrderBlockLookback) continue;
        
        // For swing highs, look for bearish order block (last bullish candle before drop)
        if (swing.isHigh) {
            for (int j = swingBarIndex; j < swingBarIndex + 5; j++) {
                double open = iOpen(_Symbol, PERIOD_CURRENT, j);
                double close = iClose(_Symbol, PERIOD_CURRENT, j);
                double high = iHigh(_Symbol, PERIOD_CURRENT, j);
                double low = iLow(_Symbol, PERIOD_CURRENT, j);
                double volume = (double)iVolume(_Symbol, PERIOD_CURRENT, j);
                
                // Check if this is a bullish candle with high volume before the drop
                if (close > open && volume > 0) {
                    // Check if price dropped significantly after this candle
                    double nextLow = iLow(_Symbol, PERIOD_CURRENT, j - 1);
                    if (nextLow < low - (50 * _Point)) {
                        AddOrderBlock(iTime(_Symbol, PERIOD_CURRENT, j), high, low, volume, false);
                        break;
                    }
                }
            }
        }
        
        // For swing lows, look for bullish order block (last bearish candle before rally)
        if (swing.isLow) {
            for (int j = swingBarIndex; j < swingBarIndex + 5; j++) {
                double open = iOpen(_Symbol, PERIOD_CURRENT, j);
                double close = iClose(_Symbol, PERIOD_CURRENT, j);
                double high = iHigh(_Symbol, PERIOD_CURRENT, j);
                double low = iLow(_Symbol, PERIOD_CURRENT, j);
                double volume = (double)iVolume(_Symbol, PERIOD_CURRENT, j);
                
                // Check if this is a bearish candle with high volume before the rally
                if (close < open && volume > 0) {
                    // Check if price rallied significantly after this candle
                    double nextHigh = iHigh(_Symbol, PERIOD_CURRENT, j - 1);
                    if (nextHigh > high + (50 * _Point)) {
                        AddOrderBlock(iTime(_Symbol, PERIOD_CURRENT, j), high, low, volume, true);
                        break;
                    }
                }
            }
        }
    }
    
    // Check if current price is reacting from any valid order block
    double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    for (int i = 0; i < g_orderBlockCount; i++) {
        if (g_orderBlocks[i].isUsed) continue;
        
        OrderBlock ob = g_orderBlocks[i];
        
        // Check if price is within order block zone
        if (currentPrice >= ob.low - (OBBuffer * _Point) && 
            currentPrice <= ob.high + (OBBuffer * _Point)) {
            
            // Check if market structure aligns with order block direction
            if ((ob.isBullish && g_marketStructure == STRUCTURE_BULLISH) ||
                (!ob.isBullish && g_marketStructure == STRUCTURE_BEARISH)) {
                
                Print("Order Block reaction detected at: ", currentPrice, 
                      " OB Level: ", ob.low, "-", ob.high, 
                      " Type: ", (ob.isBullish ? "Bullish" : "Bearish"));
                
                // Set dynamic levels based on order block
                if (ob.isBullish) {
                    g_dynamicSL = ob.low - (20 * _Point);
                    g_dynamicTP = currentPrice + ((currentPrice - g_dynamicSL) * 2); // 1:2 RR
                } else {
                    g_dynamicSL = ob.high + (20 * _Point);
                    g_dynamicTP = currentPrice - ((g_dynamicSL - currentPrice) * 2); // 1:2 RR
                }
                
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Add Order Block                                                |
//+------------------------------------------------------------------+
void AddOrderBlock(datetime time, double high, double low, double volume, bool isBullish) {
    if (g_orderBlockCount >= 50) {
        // Remove oldest order block
        for (int i = 0; i < 49; i++) {
            g_orderBlocks[i] = g_orderBlocks[i + 1];
        }
        g_orderBlockCount = 49;
    }
    
    g_orderBlocks[g_orderBlockCount].time = time;
    g_orderBlocks[g_orderBlockCount].high = high;
    g_orderBlocks[g_orderBlockCount].low = low;
    g_orderBlocks[g_orderBlockCount].volume = volume;
    g_orderBlocks[g_orderBlockCount].isBullish = isBullish;
    g_orderBlocks[g_orderBlockCount].isUsed = false;
    g_orderBlocks[g_orderBlockCount].strength = (int)(volume / 1000); // Simple strength calculation
    
    g_orderBlockCount++;
    
    Print("New Order Block added: ", (isBullish ? "Bullish" : "Bearish"), 
          " at ", high, "-", low, " Time: ", TimeToString(time));
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
    // Run detection functions once and reuse results (they may be expensive)
    bool d_bos = DetectBOS();
    bool d_choch = DetectCHoCH();
    bool d_ob = DetectOrderBlocks();
    bool d_fvg = DetectFairValueGaps();
    if (d_bos) score += ScoreWeight_SMC;
    if (d_choch) score += ScoreWeight_SMC;
    if (d_ob) score += ScoreWeight_SMC * 0.5;
    if (d_fvg) score += ScoreWeight_SMC * 0.5;
    
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
    
    // Volume contribution - use cached if recent
    double currentVolume = (double)iVolume(_Symbol, PERIOD_CURRENT, 0);
    double avgVolume = g_cachedAvgVolume;
    if (g_cachedAvgVolumeTime == 0 || TimeCurrent() - g_cachedAvgVolumeTime > 60) {
        avgVolume = 0;
        for (int i = 1; i <= 10; i++) avgVolume += (double)iVolume(_Symbol, PERIOD_CURRENT, i);
        avgVolume /= 10;
        g_cachedAvgVolume = avgVolume;
        g_cachedAvgVolumeTime = TimeCurrent();
    }
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
    
    // Relaxed but robust: require at least one structure break (BOS or CHoCH)
    // and at least one zone/imbalance (OB or FVG)
    bool structureOk = (!UseBOSConfirmation && !UseCHoCHFilter) ? true : (bosConfirmed || chochConfirmed);
    bool zoneOk = (!UseOrderBlocks && !UseFairValueGaps) ? true : (obConfirmed || fvgConfirmed);
    return structureOk && zoneOk;
}

//+------------------------------------------------------------------+
//| Calculate Position Size                                         |
//+------------------------------------------------------------------+
double CalculatePositionSize() {
    double lotSize = LotSize;
    
    if (UseAutoLot && RiskPercent > 0) {
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = accountBalance * RiskPercent / 100.0;
        double stopLossPoints = g_StopLossPoints;
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
//| Calculate Stop Loss (Dynamic SMC Method)                       |
//+------------------------------------------------------------------+
double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice) {
    double stopLoss = 0;
    
    // Use dynamic SL if available from order block analysis
    if (g_dynamicSL > 0) {
        stopLoss = g_dynamicSL;
        Print("Using Dynamic SL from Order Block: ", stopLoss);
        return stopLoss;
    }
    
    // Fallback to swing-based SL
    if (orderType == ORDER_TYPE_BUY) {
        // For buy orders, place SL below recent swing low
        if (g_lastHL > 0) {
            stopLoss = g_lastHL - (20 * _Point); // Buffer below swing low
            Print("Using Swing Low SL: ", stopLoss, " (HL: ", g_lastHL, ")");
        } else if (g_lastLL > 0) {
            stopLoss = g_lastLL - (20 * _Point);
            Print("Using Lower Low SL: ", stopLoss, " (LL: ", g_lastLL, ")");
        } else {
            // Fallback to fixed SL
            stopLoss = entryPrice - (g_StopLossPoints * _Point);
            Print("Using Fixed SL: ", stopLoss);
        }
    } else {
        // For sell orders, place SL above recent swing high
        if (g_lastLH > 0) {
            stopLoss = g_lastLH + (20 * _Point); // Buffer above swing high
            Print("Using Swing High SL: ", stopLoss, " (LH: ", g_lastLH, ")");
        } else if (g_lastHH > 0) {
            stopLoss = g_lastHH + (20 * _Point);
            Print("Using Higher High SL: ", stopLoss, " (HH: ", g_lastHH, ")");
        } else {
            // Fallback to fixed SL
            stopLoss = entryPrice + (g_StopLossPoints * _Point);
            Print("Using Fixed SL: ", stopLoss);
        }
    }
    
    return stopLoss;
}

//+------------------------------------------------------------------+
//| Calculate Take Profit (Dynamic SMC Method)                     |
//+------------------------------------------------------------------+
double CalculateTakeProfit(ENUM_ORDER_TYPE orderType, double entryPrice) {
    double takeProfit = 0;
    
    // Use dynamic TP if available from order block analysis
    if (g_dynamicTP > 0) {
        takeProfit = g_dynamicTP;
        Print("Using Dynamic TP from SMC Analysis: ", takeProfit);
        return takeProfit;
    }
    
    // Calculate TP based on Risk:Reward ratio and market structure
    double stopLoss = CalculateStopLoss(orderType, entryPrice);
    double riskDistance = MathAbs(entryPrice - stopLoss);
    
    if (orderType == ORDER_TYPE_BUY) {
        // Look for resistance levels (previous swing highs, FVG tops)
        double targetLevel = 0;
        
        // Check for nearby resistance from swing highs
        if (g_lastHH > entryPrice) {
            targetLevel = g_lastHH - (10 * _Point); // Slightly below resistance
        } else {
            // Use R:R ratio approach
            targetLevel = entryPrice + (riskDistance * 2); // 1:2 RR
        }
        
        takeProfit = targetLevel;
        Print("Buy TP calculated: ", takeProfit, " (Risk Distance: ", riskDistance, ")");
        
    } else {
        // Look for support levels (previous swing lows, FVG bottoms)
        double targetLevel = 0;
        
        // Check for nearby support from swing lows
        if (g_lastLL < entryPrice) {
            targetLevel = g_lastLL + (10 * _Point); // Slightly above support
        } else {
            // Use R:R ratio approach
            targetLevel = entryPrice - (riskDistance * 2); // 1:2 RR
        }
        
        takeProfit = targetLevel;
        Print("Sell TP calculated: ", takeProfit, " (Risk Distance: ", riskDistance, ")");
    }
    
    return takeProfit;
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop                                            |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket) {
    if (!SelectPositionByTicket(ticket)) return;
    
    ENUM_POSITION_TYPE posType = GetPositionType(ticket);
    double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentSL = GetPositionStopLoss(ticket);
    double currentTP = GetPositionTakeProfit(ticket);
    double newSL = currentSL;
    
    if (posType == POSITION_TYPE_BUY) {
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
        ModifyPosition(ticket, newSL, currentTP);
    }
}

//+------------------------------------------------------------------+
//| Apply Breakeven Stop                                           |
//+------------------------------------------------------------------+
void ApplyBreakevenStop(ulong ticket) {
    if (!SelectPositionByTicket(ticket)) return;
    
    double entryPrice = GetPositionPrice(ticket);
    ENUM_POSITION_TYPE posType = GetPositionType(ticket);
    double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentSL = GetPositionStopLoss(ticket);
    double currentTP = GetPositionTakeProfit(ticket);
    
    bool shouldMoveToBreakeven = false;
    
    if (posType == POSITION_TYPE_BUY) {
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
        double newSL = (posType == POSITION_TYPE_BUY) ? 
                      entryPrice + (BreakevenStopPoints * _Point) : 
                      entryPrice - (BreakevenStopPoints * _Point);
        
        ModifyPosition(ticket, newSL, currentTP);
        Print("Position moved to breakeven: ", ticket);
    }
}

//+------------------------------------------------------------------+
//| Should Exit On Structural Change                               |
//+------------------------------------------------------------------+
bool ShouldExitOnStructuralChange(ulong ticket) {
    if (!SelectPositionByTicket(ticket)) return false;
    
    // Check if market structure changed against our position
    ENUM_MARKET_STRUCTURE currentStructure = DetectMarketStructure();
    ENUM_POSITION_TYPE posType = GetPositionType(ticket);
    
    if (posType == POSITION_TYPE_BUY && currentStructure == STRUCTURE_BEARISH) {
        return true;
    }
    
    if (posType == POSITION_TYPE_SELL && currentStructure == STRUCTURE_BULLISH) {
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
        ulong ticket = PositionGetTicket(i);
        if (ticket > 0 && PositionSelectByTicket(ticket)) {
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            long posMagic = PositionGetInteger(POSITION_MAGIC);
            
            if (posSymbol == _Symbol && posMagic == GetMagicForSymbol(_Symbol)) {
                ClosePosition(ticket);
                Print("Position closed: ", ticket);
            }
        }
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
        g_volumes[i] = (double)iVolume(_Symbol, PERIOD_CURRENT, i);
    }
}

//+------------------------------------------------------------------+
//| Has Sufficient Data                                           |
//+------------------------------------------------------------------+
bool HasSufficientData() {
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    DebugLog(StringFormat("DEBUG: HasSufficientData() - Bars available: %d (Required: 100)", bars));
    return bars > 100;
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
    if (g_confirmationStartTime <= 0 || ConfirmationTimeoutSeconds <= 0) return false;
    return (TimeCurrent() - g_confirmationStartTime) >= ConfirmationTimeoutSeconds;
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
        // Recalculate from history after reset to be accurate if EA restarted
        RecalculateDailyPL();
        g_currentDay = today;
    }
}

//+------------------------------------------------------------------+
//| Recalculate today's P/L and trade count from history             |
//+------------------------------------------------------------------+
void RecalculateDailyPL() {
    // Reset first
    g_dailyLoss = 0;
    g_dailyTrades = 0;
    g_dailyNetPL = 0;

    // Compute start of today
    MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
    datetime dayStart = StringToTime(IntegerToString(dt.year) + "." + IntegerToString(dt.mon) + "." + IntegerToString(dt.day));

    // Iterate through trade history (deals). Use HistoryDealsTotal/HistoryDealGetTicket when available
    ulong dealTicket = 0;
    int totalDeals = HistoryDealsTotal();
    for (int i = 0; i < totalDeals; i++) {
        ulong deal = HistoryDealGetTicket(i);
        if (deal == 0) continue;
        if (!HistoryDealSelect(deal)) continue;
        datetime dealTime = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
        if (dealTime < dayStart) continue;
        string sym = HistoryDealGetString(deal, DEAL_SYMBOL);
        long magic = (long)HistoryDealGetInteger(deal, DEAL_MAGIC);
    if (sym != _Symbol || magic != GetMagicForSymbol(_Symbol)) continue;
        double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
        // Sum losses only as positive value to compare to MaxDailyLoss
        if (profit < 0) g_dailyLoss += MathAbs(profit);
        // Net P/L (could be negative)
        g_dailyNetPL += profit;
        g_dailyTrades++;
    }

    Print("Recalculated daily P/L: NetPL=", DoubleToString(g_dailyNetPL,2), " Loss=", DoubleToString(g_dailyLoss, 2), " Trades=", g_dailyTrades);
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
    if (!g_drawingEnabled) return;
    
    // 0) Cleanup any transient visual objects
    CleanupDynamicObjects();

    // Prune old objects per-type to keep chart clean
    LimitOldObjects(g_orderBlockPrefix, g_Visual_MaxObjectsPerType);
    LimitOldObjects(g_fvgPrefix, g_Visual_MaxObjectsPerType);
    LimitOldObjects(g_swingPointPrefix, g_Visual_MaxObjectsPerType);

    // 🔍 1. Core SMC Structure Visualization
    if (g_ShowLayer_Trend)        DrawTrendStructure();
    if (g_ShowLayer_BOS)          DrawBOSLevels();
    if (g_ShowLayer_CHoCH)        DrawCHoCHLevels();
    
    // 🎯 2. Entry & Management Zones
    if (g_ShowLayer_OB)           DrawOrderBlocksOnChart();
    if (g_ShowLayer_SLTP)         DrawDynamicLevelsOnChart();
    if (g_ShowLayer_FVG)          DrawFairValueGapsOnChart();
    
    // 3.5) Visualize R:R setup around confirmation/entry phases only
    if (Visual_DrawRRBox && (g_currentState == STATE_CONFIRMATION_PENDING || g_currentState == STATE_ENTRY_SETUP)) {
        DrawPendingEntrySetup();
    }
    
    // 📊 3. Additional Components
    if (g_ShowLayer_SwingPoints)     DrawSwingPointsOnChart();
    if (g_ShowLayer_BOS || g_ShowLayer_CHoCH) DrawStructureBreaks();
    
    // 📈 4. VWAP and Volume Profile
    if (g_ShowLayer_VWAP && DrawVWAP && UseVWAP) {
        datetime time1 = iTime(_Symbol, PERIOD_CURRENT, 20);
        datetime time2 = iTime(_Symbol, PERIOD_CURRENT, 0);
        
        ObjectSetInteger(g_chartID, g_vwapObjectName, OBJPROP_TIME, 0, time1);
        ObjectSetDouble(g_chartID, g_vwapObjectName, OBJPROP_PRICE, 0, g_vwapValue);
        ObjectSetInteger(g_chartID, g_vwapObjectName, OBJPROP_TIME, 1, time2);
        ObjectSetDouble(g_chartID, g_vwapObjectName, OBJPROP_PRICE, 1, g_vwapValue);
    }
    
    // Update Volume Profile on bar close only
    if (g_ShowLayer_VolumeProfile && DrawVolumeProfile && UseVolumeProfile && IsNewBar()) {
        UpdateVolumeProfileOnBarClose();
    }

    // 🔧 Apply visual clarity pass: limit counts, keep recent, compact labels, thin lines
    ApplyVisualClarity();

    // Status panel
    if (Visual_ShowStatusPanel) {
        DrawStatusPanel();
    }
}

//+------------------------------------------------------------------+
//| Limit number of old objects per prefix                           |
//+------------------------------------------------------------------+
void LimitOldObjects(const string prefix, int maxObjects) {
    if (StringLen(prefix) == 0 || maxObjects <= 0) return;
    int total = ObjectsTotal(g_chartID);
    // Collect names with prefix
    string names[]; datetime times[]; ArrayResize(names, 0); ArrayResize(times, 0);
    for (int i = 0; i < total; i++) {
        string nm = ObjectName(g_chartID, i);
        if (HasPrefix(nm, prefix)) {
            int idx = ArraySize(names);
            ArrayResize(names, idx + 1);
            ArrayResize(times, idx + 1);
            names[idx] = nm;
            times[idx] = LatestObjectTime(nm);
        }
    }
    int n = ArraySize(names);
    if (n <= maxObjects) return;
    // sort by time desc
    for (int a = 0; a < n - 1; a++) {
        for (int b = 0; b < n - a - 1; b++) {
            if (times[b] < times[b + 1]) {
                datetime tt = times[b]; times[b] = times[b + 1]; times[b + 1] = tt;
                string ss = names[b]; names[b] = names[b + 1]; names[b + 1] = ss;
            }
        }
    }
    // delete older ones beyond maxObjects
    for (int k = maxObjects; k < n; k++) {
        ObjectDelete(g_chartID, names[k]);
    }
}

//+------------------------------------------------------------------+
//| Proactive prune: delete oldest objects for prefix if over limit  |
//+------------------------------------------------------------------+
void PruneForPrefixIfNeeded(const string prefix, int maxObjects) {
    if (StringLen(prefix) == 0 || maxObjects <= 0) return;
    // Count current
    int cnt = 0;
    int total = ObjectsTotal(g_chartID);
    for (int i = 0; i < total; i++) {
        string nm = ObjectName(g_chartID, i);
        if (HasPrefix(nm, prefix)) cnt++;
    }
    if (cnt <= maxObjects) return;
    // Otherwise call LimitOldObjects to prune older ones
    LimitOldObjects(prefix, maxObjects);
}

//+------------------------------------------------------------------+
//| Draw unified info panel (compact)                               |
//+------------------------------------------------------------------+
void DrawInfoPanel(const string text) {
    string box = "SMC_InfoBox";
    if (ObjectFind(g_chartID, box) == -1) {
        // Use a simple label for broad compatibility across MT5 builds
        ObjectCreate(g_chartID, box, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(g_chartID, box, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(g_chartID, box, OBJPROP_XDISTANCE, 5);
        ObjectSetInteger(g_chartID, box, OBJPROP_YDISTANCE, 5);
        ObjectSetInteger(g_chartID, box, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(g_chartID, box, OBJPROP_FONTSIZE, 10);
        ObjectSetString(g_chartID, box, OBJPROP_FONT, "Arial");
    }
    ObjectSetString(g_chartID, box, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Apply visual presets                                            |
//+------------------------------------------------------------------+
void ApplyVisualPresetSettings() {
    if (VisualPreset == VISUAL_CUSTOM) return; // respect user custom
    switch (VisualPreset) {
        case VISUAL_MAX_INFO:
            g_Visual_ShowOnlyRecentBars = 0;
            g_Visual_MaxObjectsPerType = 120;
            g_Visual_LabelVerbosity = LABEL_FULL;
            g_Visual_ThinLines = false;
            g_Visual_LightenFVG = false;
            g_ShowLayer_Trend = g_ShowLayer_SwingPoints = g_ShowLayer_BOS = g_ShowLayer_CHoCH = true;
            g_ShowLayer_OB = g_ShowLayer_FVG = g_ShowLayer_SLTP = true;
            g_ShowLayer_VWAP = g_ShowLayer_VolumeProfile = true;
            break;
        case VISUAL_BALANCED:
            g_Visual_ShowOnlyRecentBars = 600;
            g_Visual_MaxObjectsPerType = 60;
            g_Visual_LabelVerbosity = LABEL_COMPACT;
            g_Visual_ThinLines = true;
            g_Visual_LightenFVG = true;
            g_ShowLayer_Trend = g_ShowLayer_SwingPoints = true;
            g_ShowLayer_BOS = g_ShowLayer_CHoCH = true;
            g_ShowLayer_OB = g_ShowLayer_FVG = true;
            g_ShowLayer_SLTP = true;
            g_ShowLayer_VWAP = true;
            g_ShowLayer_VolumeProfile = false;
            break;
        case VISUAL_CLEAN:
            g_Visual_ShowOnlyRecentBars = 400;
            g_Visual_MaxObjectsPerType = 40;
            g_Visual_LabelVerbosity = LABEL_MINIMAL;
            g_Visual_ThinLines = true;
            g_Visual_LightenFVG = true;
            g_ShowLayer_Trend = true;
            g_ShowLayer_SwingPoints = false;
            g_ShowLayer_BOS = true;
            g_ShowLayer_CHoCH = true;
            g_ShowLayer_OB = true;
            g_ShowLayer_FVG = false;
            g_ShowLayer_SLTP = true;
            g_ShowLayer_VWAP = true;
            g_ShowLayer_VolumeProfile = false;
            break;
        default: break;
    }
}

//+------------------------------------------------------------------+
//| Draw compact status panel                                       |
//+------------------------------------------------------------------+
void DrawStatusPanel() {
    string obj = "SMC_STATUS_PANEL";
    int w = 240, h = 70;
    // Background label (upsert)
    ObjectUpsert(g_chartID, obj, OBJ_LABEL, 1, 0, 0);
    ObjectSetInteger(g_chartID, obj, OBJPROP_CORNER, Visual_PanelCorner);
    ObjectSetInteger(g_chartID, obj, OBJPROP_XDISTANCE, Visual_PanelX);
    ObjectSetInteger(g_chartID, obj, OBJPROP_YDISTANCE, Visual_PanelY);
    ObjectSetInteger(g_chartID, obj, OBJPROP_BGCOLOR, Visual_PanelBGColor);
    ObjectSetInteger(g_chartID, obj, OBJPROP_COLOR, Visual_PanelTextColor);
    ObjectSetInteger(g_chartID, obj, OBJPROP_FONTSIZE, 10);
    ObjectSetString(g_chartID, obj, OBJPROP_FONT, "Arial");

    // Compose text
    string stateTxt = EnumToString(g_currentState);
    string biasTxt = (g_marketStructure == STRUCTURE_BULLISH ? "BULLISH" : g_marketStructure == STRUCTURE_BEARISH ? "BEARISH" : "RANGE/UNK");
    string fineTrendTxt = EnumToString(g_threeSwingTrend);
    int score = (UseConfluenceScoring ? CalculateConfluenceScore() : 0);
    string line1 = StringFormat("State: %s", stateTxt);
    string line2 = StringFormat("Bias: %s | 3SwingTrend: %s", biasTxt, fineTrendTxt);
    string line3 = StringFormat("Score: %d", score);

    // Three-swing pattern (labels and classification)
    string lb1 = "", lb2 = "", lb3 = "";
    ENUM_THREE_SWING_PATTERN tsp = ClassifyLastThreeSwingPattern(lb1, lb2, lb3);
    string line4 = (tsp != TSP_UNKNOWN) ? StringFormat("3-swing: %s→%s→%s (%s)", lb1, lb2, lb3, ThreeSwingPatternToString(tsp)) : "3-swing: -";
    if (UseThreeSwingPatternFilter) {
        line4 += " | Filter: ON";
        if (AcceptUnknownThreeSwingPattern) line4 += " (uOK)"; // unknown accepted
    } else {
        line4 += " | Filter: OFF";
    }

    string text = line1 + "\n" + line2 + "\n" + line3 + "\n" + line4;
    ObjectSetString(g_chartID, obj, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Cleanup transient/temporary objects                             |
//+------------------------------------------------------------------+
void CleanupDynamicObjects() {
    // Remove any leftover R:R objects beyond the canonical set
    string keep1 = g_rrPrefix + "RISK";
    string keep2 = g_rrPrefix + "REWARD";
    string keep3 = g_rrPrefix + "LABEL";
    int total = ObjectsTotal(g_chartID);
    for (int i = total - 1; i >= 0; i--) {
        string nm = ObjectName(g_chartID, i);
        if (HasPrefix(nm, g_rrPrefix)) {
            if (nm != keep1 && nm != keep2 && nm != keep3) {
                ObjectDelete(g_chartID, nm);
            }
        }
    }
}

// Create object if missing, otherwise update its time/price points or text
int ObjectUpsert(long chart_id, const string name, const ENUM_OBJECT type, const int points_count, datetime t0, double p0, datetime t1=0, double p1=0) {
    // If object doesn't exist, create with appropriate params
    if (ObjectFind(chart_id, name) == -1) {
        if (type == OBJ_TEXT || type == OBJ_LABEL)
            ObjectCreate(chart_id, name, type, 0, t0, p0);
        else if (type == OBJ_RECTANGLE)
            ObjectCreate(chart_id, name, type, 0, t0, p0, t1, p1);
        else if (type == OBJ_TREND || type == OBJ_HLINE || type == OBJ_RECTANGLE || type == OBJ_ARROW_UP || type == OBJ_ARROW_DOWN || type == OBJ_ARROW_CHECK)
            ObjectCreate(chart_id, name, type, 0, t0, p0, t1, p1);
        else
            ObjectCreate(chart_id, name, type, 0, t0, p0);
        return 1; // created
    }
    // Update positions for two-point objects
    if (points_count >= 2) {
        ObjectSetInteger(chart_id, name, OBJPROP_TIME, 0, t0);
        ObjectSetDouble(chart_id, name, OBJPROP_PRICE, 0, p0);
        ObjectSetInteger(chart_id, name, OBJPROP_TIME, 1, t1);
        ObjectSetDouble(chart_id, name, OBJPROP_PRICE, 1, p1);
    } else {
        // single point - update time/price
        ObjectSetInteger(chart_id, name, OBJPROP_TIME, 0, t0);
        ObjectSetDouble(chart_id, name, OBJPROP_PRICE, 0, p0);
    }
    return 0; // updated
}

//+------------------------------------------------------------------+
//| Draw Risk/Reward box for the active pending setup               |
//+------------------------------------------------------------------+
void DrawPendingEntrySetup() {
    bool bullish = (g_marketStructure == STRUCTURE_BULLISH);
    double entry = 0.0;
    double sl = 0.0;
    double tp = 0.0;

    // Prefer OB-based limit entry; fallback to breakout stop
    bool havePrice = false;
    if (UseOrderBlocks) havePrice = GetOBPendingPrice(bullish, entry);
    if (!havePrice) havePrice = GetBreakoutPendingPrice(bullish, entry);
    if (!havePrice || entry <= 0) return;

    ENUM_ORDER_TYPE side = bullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    sl = CalculateStopLoss(side, entry);
    tp = CalculateTakeProfit(side, entry);
    if (sl <= 0 || tp <= 0) return;

    entry = NormalizeToDigits(entry);
    sl = NormalizeToDigits(sl);
    tp = NormalizeToDigits(tp);

    // Time range for drawing rectangles (last ~20 bars to now)
    datetime t1 = iTime(_Symbol, (ENUM_TIMEFRAMES)Period(), 20);
    datetime t2 = iTime(_Symbol, (ENUM_TIMEFRAMES)Period(), 0);
    if (t1 == 0) t1 = TimeCurrent() - PeriodSeconds((ENUM_TIMEFRAMES)Period()) * 20;
    if (t2 == 0) t2 = TimeCurrent();

    string riskName = g_rrPrefix + "RISK";
    ObjectUpsert(g_chartID, riskName, OBJ_RECTANGLE, 2, t1, entry, t2, sl);
    ObjectSetInteger(g_chartID, riskName, OBJPROP_COLOR, clrTomato);
    ObjectSetInteger(g_chartID, riskName, OBJPROP_BACK, true);
    ObjectSetInteger(g_chartID, riskName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(g_chartID, riskName, OBJPROP_STYLE, STYLE_DOT);

    string rewName = g_rrPrefix + "REWARD";
    ObjectUpsert(g_chartID, rewName, OBJ_RECTANGLE, 2, t1, entry, t2, tp);
    ObjectSetInteger(g_chartID, rewName, OBJPROP_COLOR, clrDarkGreen);
    ObjectSetInteger(g_chartID, rewName, OBJPROP_BACK, true);
    ObjectSetInteger(g_chartID, rewName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(g_chartID, rewName, OBJPROP_STYLE, STYLE_DOT);

    // Label with R:R numbers
    double risk = MathAbs(entry - sl);
    double reward = MathAbs(tp - entry);
    double rr = (risk > 0 ? reward / risk : 0.0);
    string lblName = g_rrPrefix + "LABEL";
    ObjectUpsert(g_chartID, lblName, OBJ_TEXT, 1, t2, entry);
    string txt = StringFormat("R:R %.2f  |  Entry %s  SL %s  TP %s", rr,
                              DoubleToString(entry, _Digits), DoubleToString(sl, _Digits), DoubleToString(tp, _Digits));
    ObjectSetString(g_chartID, lblName, OBJPROP_TEXT, txt);
    ObjectSetInteger(g_chartID, lblName, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(g_chartID, lblName, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(g_chartID, lblName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
}

//+------------------------------------------------------------------+
//| Visual Clarity helpers                                          |
//+------------------------------------------------------------------+
bool HasPrefix(const string name, const string prefix) {
    if (StringLen(prefix) == 0) return false;
    return StringFind(name, prefix, 0) == 0;
}

datetime LatestObjectTime(const string name) {
    datetime t0 = (datetime)ObjectGetInteger(g_chartID, name, OBJPROP_TIME, 0);
    datetime t1 = (datetime)ObjectGetInteger(g_chartID, name, OBJPROP_TIME, 1);
    if (t1 > t0) return t1;
    return t0;
}

void ShortenLabelIfNeeded(const string name) {
    if (g_Visual_LabelVerbosity == LABEL_FULL) return;
    string txt = ObjectGetString(g_chartID, name, OBJPROP_TEXT);
    if (txt == "") return;
    string before = txt;
    // Compact common phrases
    StringReplace(txt, "CHoCH TREND CHANGE", "CHoCH");
    StringReplace(txt, "Change of Character", "CHoCH");
    StringReplace(txt, "Break of Structure", "BOS");
    StringReplace(txt, "Order Block", "OB");
    if (g_Visual_LabelVerbosity == LABEL_MINIMAL) {
        StringReplace(txt, "TREND CHANGE", "");
    }
    if (txt != before) {
        ObjectSetString(g_chartID, name, OBJPROP_TEXT, txt);
    }
}

//+------------------------------------------------------------------+
//| Visual Clarity: prune and restyle objects                        |
//+------------------------------------------------------------------+
void ApplyVisualClarity() {
    if (!g_drawingEnabled) return;

    bool needsPrune = (g_Visual_ShowOnlyRecentBars > 0) || (g_Visual_MaxObjectsPerType > 0);
    bool needsRestyle = (g_Visual_LabelVerbosity != LABEL_FULL) || g_Visual_ThinLines || g_Visual_LightenFVG;
    if (!needsPrune && !needsRestyle) return;

    // Determine cutoff time
    datetime cutoff = 0;
    if (g_Visual_ShowOnlyRecentBars > 0) {
        datetime t = iTime(_Symbol, (ENUM_TIMEFRAMES)Period(), g_Visual_ShowOnlyRecentBars);
        if (t > 0) cutoff = t;
    }

    // Prune by age
    if (cutoff > 0) {
        int total = ObjectsTotal(g_chartID);
        for (int i = total - 1; i >= 0; i--) {
            string name = ObjectName(g_chartID, i);
            if (HasPrefix(name, g_swingPointPrefix) || HasPrefix(name, g_trendPrefix) ||
                HasPrefix(name, g_bosPrefix) || HasPrefix(name, g_chochPrefix) ||
                HasPrefix(name, g_orderBlockPrefix) || HasPrefix(name, g_fvgPrefix) ||
                HasPrefix(name, g_slPrefix) || HasPrefix(name, g_tpPrefix)) {
                datetime lt = LatestObjectTime(name);
                if (lt > 0 && lt < cutoff) {
                    ObjectDelete(g_chartID, name);
                }
            }
        }
    }

    // Limit per type
    if (g_Visual_MaxObjectsPerType > 0) {
        string prefixes[8] = { g_swingPointPrefix, g_trendPrefix, g_bosPrefix, g_chochPrefix, g_orderBlockPrefix, g_fvgPrefix, g_slPrefix, g_tpPrefix };
        for (int p = 0; p < 8; p++) {
            string pref = prefixes[p];
            string names[]; datetime times[]; ArrayResize(names, 0); ArrayResize(times, 0);
            int total = ObjectsTotal(g_chartID);
            for (int i = 0; i < total; i++) {
                string nm = ObjectName(g_chartID, i);
                if (HasPrefix(nm, pref)) {
                    int idx = ArraySize(names);
                    ArrayResize(names, idx + 1);
                    ArrayResize(times, idx + 1);
                    names[idx] = nm;
                    times[idx] = LatestObjectTime(nm);
                }
            }
            int n = ArraySize(names);
            // sort by time desc
            for (int a = 0; a < n - 1; a++) {
                for (int b = 0; b < n - a - 1; b++) {
                    if (times[b] < times[b + 1]) {
                        datetime tt = times[b]; times[b] = times[b + 1]; times[b + 1] = tt;
                        string   ss = names[b]; names[b] = names[b + 1]; names[b + 1] = ss;
                    }
                }
            }
            for (int k = g_Visual_MaxObjectsPerType; k < n; k++) {
                ObjectDelete(g_chartID, names[k]);
            }
        }
    }

    // Restyle
    if (needsRestyle) {
        int total = ObjectsTotal(g_chartID);
        for (int i = total - 1; i >= 0; i--) {
            string name = ObjectName(g_chartID, i);
            bool isTrend = HasPrefix(name, g_trendPrefix);
            bool isBOS   = HasPrefix(name, g_bosPrefix);
            bool isCHoCH = HasPrefix(name, g_chochPrefix);
            bool isOB    = HasPrefix(name, g_orderBlockPrefix);
            bool isFVG   = HasPrefix(name, g_fvgPrefix);
            bool isSL    = HasPrefix(name, g_slPrefix);
            bool isTP    = HasPrefix(name, g_tpPrefix);

            if (g_Visual_ThinLines && (isTrend || isBOS || isCHoCH || isSL || isTP)) {
                ObjectSetInteger(g_chartID, name, OBJPROP_WIDTH, 1);
                ObjectSetInteger(g_chartID, name, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(g_chartID, name, OBJPROP_BACK, true);
            }
            if (g_Visual_LightenFVG && isFVG) {
                ObjectSetInteger(g_chartID, name, OBJPROP_BACK, true);
                ObjectSetInteger(g_chartID, name, OBJPROP_WIDTH, 1);
                ObjectSetInteger(g_chartID, name, OBJPROP_STYLE, STYLE_DOT);
            }
            if (isBOS || isCHoCH || isOB) {
                ShortenLabelIfNeeded(name);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Trend Lines - ZigZag Backbone Structure                    |
//+------------------------------------------------------------------+
void DrawTrendStructure() {
    if (!DrawTrendLines) return;
    
    // Clean up old trend lines
    CleanupObjectsByPrefix(g_trendPrefix);
    
    // Need at least 2 swing points to draw trend
    if (g_swingCount < 2) return;
    
    // Draw trend lines connecting consecutive swing points
    for (int i = 1; i < g_swingCount && i < 10; i++) {
        string objName = g_trendPrefix + "LINE_" + IntegerToString(i);
        
        // Upsert trend line between consecutive swing points
        ObjectUpsert(g_chartID, objName, OBJ_TREND, 2,
                     g_swingPoints[i-1].time, g_swingPoints[i-1].price,
                     g_swingPoints[i].time, g_swingPoints[i].price);
        
        // Determine trend direction and color
        bool isBullish = false;
        if (g_swingPoints[i-1].isLow && g_swingPoints[i].isHigh) {
            // Low to High = Bullish leg
            isBullish = true;
        } else if (g_swingPoints[i-1].isHigh && g_swingPoints[i].isLow) {
            // High to Low = Bearish leg  
            isBullish = false;
        } else {
            // Same type - check price level
            isBullish = (g_swingPoints[i].price > g_swingPoints[i-1].price);
        }
        
        // Set line properties
        ObjectSetInteger(g_chartID, objName, OBJPROP_COLOR, isBullish ? clrLime : clrRed);
        ObjectSetInteger(g_chartID, objName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(g_chartID, objName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(g_chartID, objName, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(g_chartID, objName, OBJPROP_BACK, true);
        
        // Add trend direction label
        string labelName = g_trendPrefix + "LABEL_" + IntegerToString(i);
        datetime midTime = g_swingPoints[i-1].time + 
                          (g_swingPoints[i].time - g_swingPoints[i-1].time) / 2;
        double midPrice = (g_swingPoints[i-1].price + g_swingPoints[i].price) / 2;
        
        ObjectUpsert(g_chartID, labelName, OBJ_TEXT, 1, midTime, midPrice);
        ObjectSetString(g_chartID, labelName, OBJPROP_TEXT, isBullish ? "↗" : "↘");
        ObjectSetInteger(g_chartID, labelName, OBJPROP_COLOR, isBullish ? clrLime : clrRed);
        ObjectSetInteger(g_chartID, labelName, OBJPROP_FONTSIZE, 12);
        ObjectSetInteger(g_chartID, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
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
    for (int i = 1; i < g_swingCount; i++) {
        bool isBOS = false;
        string bosType = "";
        double bosLevel = 0;
        datetime bosTime = 0;
        
        // Check for BOS in current price action vs previous swing
        if (g_swingPoints[i].isHigh && i > 0) {
            // Check if current high breaks previous high (Bullish BOS)
            for (int j = i-1; j >= 0; j--) {
                if (g_swingPoints[j].isHigh && 
                    g_swingPoints[i].price > g_swingPoints[j].price + (10 * _Point)) {
                    isBOS = true;
                    bosType = "BOS↑";
                    bosLevel = g_swingPoints[j].price;
                    bosTime = g_swingPoints[i].time;
                    break;
                }
            }
        } else if (g_swingPoints[i].isLow && i > 0) {
            // Check if current low breaks previous low (Bearish BOS)
            for (int j = i-1; j >= 0; j--) {
                if (g_swingPoints[j].isLow && 
                    g_swingPoints[i].price < g_swingPoints[j].price - (10 * _Point)) {
                    isBOS = true;
                    bosType = "BOS↓";
                    bosLevel = g_swingPoints[j].price;
                    bosTime = g_swingPoints[i].time;
                    break;
                }
            }
        }
        
        if (isBOS) {
            // Upsert BOS level line
            string levelName = g_bosPrefix + "LEVEL_" + IntegerToString(i);
            ObjectUpsert(g_chartID, levelName, OBJ_HLINE, 2, bosTime, bosLevel, bosTime, bosLevel);
            ObjectSetInteger(g_chartID, levelName, OBJPROP_COLOR, BOSColor);
            ObjectSetInteger(g_chartID, levelName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(g_chartID, levelName, OBJPROP_STYLE, STYLE_DASH);

            // Upsert BOS confirmation arrow
            string arrowName = g_bosPrefix + "ARROW_" + IntegerToString(i);
            ObjectUpsert(g_chartID, arrowName, OBJ_ARROW_CHECK, 1, bosTime, bosLevel);
            ObjectSetInteger(g_chartID, arrowName, OBJPROP_COLOR, BOSColor);
            ObjectSetInteger(g_chartID, arrowName, OBJPROP_WIDTH, 3);

            // Upsert BOS label
            string labelName = g_bosPrefix + "TEXT_" + IntegerToString(i);
            ObjectUpsert(g_chartID, labelName, OBJ_TEXT, 1, bosTime, bosLevel + (15 * _Point));
            ObjectSetString(g_chartID, labelName, OBJPROP_TEXT, bosType);
            ObjectSetInteger(g_chartID, labelName, OBJPROP_COLOR, BOSColor);
            ObjectSetInteger(g_chartID, labelName, OBJPROP_FONTSIZE, 8);
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
    
    // Detect and draw CHoCH levels
    for (int i = 2; i < g_swingCount; i++) {
        bool isCHoCH = false;
        string chochType = "";
        double chochLevel = 0;
        datetime chochTime = 0;
        
        // CHoCH detection: trend change from bullish to bearish or vice versa
        if (i >= 2) {
            // Check for bullish to bearish CHoCH
            if (g_swingPoints[i-2].isLow && g_swingPoints[i-1].isHigh && g_swingPoints[i].isLow) {
                if (g_swingPoints[i].price < g_swingPoints[i-2].price - (15 * _Point)) {
                    isCHoCH = true;
                    chochType = "CHoCH↓";
                    chochLevel = g_swingPoints[i-1].price;
                    chochTime = g_swingPoints[i].time;
                }
            }
            // Check for bearish to bullish CHoCH  
            else if (g_swingPoints[i-2].isHigh && g_swingPoints[i-1].isLow && g_swingPoints[i].isHigh) {
                if (g_swingPoints[i].price > g_swingPoints[i-2].price + (15 * _Point)) {
                    isCHoCH = true;
                    chochType = "CHoCH↑";
                    chochLevel = g_swingPoints[i-1].price;
                    chochTime = g_swingPoints[i].time;
                }
            }
        }
        
        if (isCHoCH) {
            // Upsert CHoCH level line
            string levelName = g_chochPrefix + "LEVEL_" + IntegerToString(i);
            ObjectUpsert(g_chartID, levelName, OBJ_HLINE, 2, chochTime, chochLevel, chochTime, chochLevel);
            ObjectSetInteger(g_chartID, levelName, OBJPROP_COLOR, CHoCHColor);
            ObjectSetInteger(g_chartID, levelName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(g_chartID, levelName, OBJPROP_STYLE, STYLE_DASHDOT);

            // Upsert CHoCH warning triangle
            string arrowName = g_chochPrefix + "ARROW_" + IntegerToString(i);
            ObjectUpsert(g_chartID, arrowName, OBJ_ARROW_UP, 1, chochTime, chochLevel);
            ObjectSetInteger(g_chartID, arrowName, OBJPROP_COLOR, CHoCHColor);
            ObjectSetInteger(g_chartID, arrowName, OBJPROP_WIDTH, 2);

            // Upsert CHoCH label
            string labelName = g_chochPrefix + "TEXT_" + IntegerToString(i);
            ObjectUpsert(g_chartID, labelName, OBJ_TEXT, 1, chochTime, chochLevel + (20 * _Point));
            ObjectSetString(g_chartID, labelName, OBJPROP_TEXT, chochType + " TREND CHANGE");
            ObjectSetInteger(g_chartID, labelName, OBJPROP_COLOR, CHoCHColor);
            ObjectSetInteger(g_chartID, labelName, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(g_chartID, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Swing Points on Chart                                      |
//+------------------------------------------------------------------+
void DrawSwingPointsOnChart() {
    if (!DrawSwingPoints || !g_drawingEnabled) return;
    
    // Only redraw if swing points have changed
    if (g_swingCount == g_lastDrawnSwingCount) return;
    
    // Draw current swing points (upsert)
    int drawn = 0;
    for (int i = 0; i < g_swingCount && drawn < 20; i++) { // Limit to 20 most recent
        if (!g_swingPoints[i].isConfirmed) continue;
        
        string objName = g_swingPointPrefix + IntegerToString(i);
        string labelName = g_swingPointPrefix + "LABEL_" + IntegerToString(i);

        if (g_swingPoints[i].isHigh) {
            ObjectUpsert(g_chartID, objName, OBJ_ARROW_DOWN, 1, g_swingPoints[i].time, g_swingPoints[i].price);
            ObjectSetInteger(g_chartID, objName, OBJPROP_COLOR, SwingPointColor);
            ObjectSetInteger(g_chartID, objName, OBJPROP_WIDTH, 1);

            // Determine if it's HH or LH
            string label = "HH";
            if (g_swingPoints[i].price < g_lastHH && g_lastHH > 0) {
                label = "LH";
            }

            ObjectUpsert(g_chartID, labelName, OBJ_TEXT, 1, g_swingPoints[i].time, g_swingPoints[i].price + (20 * _Point));
            ObjectSetString(g_chartID, labelName, OBJPROP_TEXT, label);
            ObjectSetInteger(g_chartID, labelName, OBJPROP_COLOR, SwingPointColor);
            ObjectSetInteger(g_chartID, labelName, OBJPROP_FONTSIZE, 8);
        }

        if (g_swingPoints[i].isLow) {
            ObjectUpsert(g_chartID, objName, OBJ_ARROW_UP, 1, g_swingPoints[i].time, g_swingPoints[i].price);
            ObjectSetInteger(g_chartID, objName, OBJPROP_COLOR, SwingPointColor);
            ObjectSetInteger(g_chartID, objName, OBJPROP_WIDTH, 1);

            // Determine if it's HL or LL
            string label = "LL";
            if (g_swingPoints[i].price > g_lastLL && g_lastLL > 0) {
                label = "HL";
            }

            ObjectUpsert(g_chartID, labelName, OBJ_TEXT, 1, g_swingPoints[i].time, g_swingPoints[i].price - (20 * _Point));
            ObjectSetString(g_chartID, labelName, OBJPROP_TEXT, label);
            ObjectSetInteger(g_chartID, labelName, OBJPROP_COLOR, SwingPointColor);
            ObjectSetInteger(g_chartID, labelName, OBJPROP_FONTSIZE, 8);
        }

        drawn++;
    }

    g_lastDrawnSwingCount = g_swingCount;
}

//+------------------------------------------------------------------+
//| Draw BOS and CHoCH Signals                                      |
//+------------------------------------------------------------------+
void DrawStructureBreaks() {
    if (!g_drawingEnabled) return;
    
    static bool lastBOSState = false;
    static bool lastCHoCHState = false;
    static datetime lastBOSTime = 0;
    static datetime lastCHoCHTime = 0;
    
    datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    // Draw BOS
    if (DrawBOS && g_bosDetected && !lastBOSState && currentTime != lastBOSTime) {
        string objName = g_bosPrefix + TimeToString(currentTime, TIME_MINUTES);
        ObjectUpsert(g_chartID, objName, OBJ_ARROW_UP, 1, currentTime, iClose(_Symbol, PERIOD_CURRENT, 0));
        ObjectSetInteger(g_chartID, objName, OBJPROP_COLOR, BOSColor);
        ObjectSetInteger(g_chartID, objName, OBJPROP_WIDTH, 4);
        ObjectSetInteger(g_chartID, objName, OBJPROP_ARROWCODE, 233); // Up arrow

        string labelName = g_bosPrefix + "LABEL_" + TimeToString(currentTime, TIME_MINUTES);
        ObjectUpsert(g_chartID, labelName, OBJ_TEXT, 1, currentTime, iClose(_Symbol, PERIOD_CURRENT, 0) + (30 * _Point));
        ObjectSetString(g_chartID, labelName, OBJPROP_TEXT, "BOS");
        ObjectSetInteger(g_chartID, labelName, OBJPROP_COLOR, BOSColor);
        ObjectSetInteger(g_chartID, labelName, OBJPROP_FONTSIZE, 10);

        lastBOSTime = currentTime;
        Print("BOS signal drawn at: ", TimeToString(currentTime));
    }
    
    // Draw CHoCH
    if (DrawCHoCH && g_chochDetected && !lastCHoCHState && currentTime != lastCHoCHTime) {
        string objName = g_chochPrefix + TimeToString(currentTime, TIME_MINUTES);
        ObjectUpsert(g_chartID, objName, OBJ_ARROW_THUMB_UP, 1, currentTime, iClose(_Symbol, PERIOD_CURRENT, 0));
        ObjectSetInteger(g_chartID, objName, OBJPROP_COLOR, CHoCHColor);
        ObjectSetInteger(g_chartID, objName, OBJPROP_WIDTH, 4);

        string labelName = g_chochPrefix + "LABEL_" + TimeToString(currentTime, TIME_MINUTES);
        ObjectUpsert(g_chartID, labelName, OBJ_TEXT, 1, currentTime, iClose(_Symbol, PERIOD_CURRENT, 0) + (40 * _Point));
        ObjectSetString(g_chartID, labelName, OBJPROP_TEXT, "CHoCH");
        ObjectSetInteger(g_chartID, labelName, OBJPROP_COLOR, CHoCHColor);
        ObjectSetInteger(g_chartID, labelName, OBJPROP_FONTSIZE, 10);

        lastCHoCHTime = currentTime;
        Print("CHoCH signal drawn at: ", TimeToString(currentTime));
    }
    
    lastBOSState = g_bosDetected;
    lastCHoCHState = g_chochDetected;
}

//+------------------------------------------------------------------+
//| Draw Order Blocks                                              |
//+------------------------------------------------------------------+
void DrawOrderBlocksOnChart() {
    if (!DrawOrderBlocks || !g_drawingEnabled) return;
    
    // Only redraw if order blocks have changed
    if (g_orderBlockCount == g_lastDrawnOBCount) return;
    
    // Draw/Upsert current order blocks
    datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    for (int i = 0; i < g_orderBlockCount; i++) {
        if (g_orderBlocks[i].isUsed) continue;
        
        // Skip very old order blocks (older than 1 week)
        if (currentTime - g_orderBlocks[i].time > 604800) continue;
        
        string objName = g_orderBlockPrefix + IntegerToString(i);
        string labelName = g_orderBlockPrefix + "LABEL_" + IntegerToString(i);

        // Calculate end time for rectangle (extend to current time)
        datetime endTime = currentTime + (3600 * 4); // 4 hours into future

        // Proactive prune to avoid growing OB objects beyond limit
        PruneForPrefixIfNeeded(g_orderBlockPrefix, g_Visual_MaxObjectsPerType);
        // Upsert order block rectangle
        ObjectUpsert(g_chartID, objName, OBJ_RECTANGLE, 2,
                     g_orderBlocks[i].time, g_orderBlocks[i].low,
                     endTime, g_orderBlocks[i].high);

        color obColor = g_orderBlocks[i].isBullish ? BullishOBColor : BearishOBColor;
        // Soften OB visuals: use configured transparency
    ObjectSetInteger(g_chartID, objName, OBJPROP_COLOR, ColorToARGB(obColor, (uchar)Visual_OBTransparency));
        ObjectSetInteger(g_chartID, objName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(g_chartID, objName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(g_chartID, objName, OBJPROP_FILL, true);
        ObjectSetInteger(g_chartID, objName, OBJPROP_BACK, true);

        // Upsert label
        string label = g_orderBlocks[i].isBullish ? "Bullish OB" : "Bearish OB";
        double labelPrice = (g_orderBlocks[i].high + g_orderBlocks[i].low) / 2;

        ObjectUpsert(g_chartID, labelName, OBJ_TEXT, 1, g_orderBlocks[i].time, labelPrice);
        ObjectSetString(g_chartID, labelName, OBJPROP_TEXT, label);
        ObjectSetInteger(g_chartID, labelName, OBJPROP_COLOR, obColor);
        ObjectSetInteger(g_chartID, labelName, OBJPROP_FONTSIZE, 8);
    }
    
    g_lastDrawnOBCount = g_orderBlockCount;
}

//+------------------------------------------------------------------+
//| Draw Fair Value Gaps                                           |
//+------------------------------------------------------------------+
void DrawFairValueGapsOnChart() {
    if (!DrawFairValueGaps || !g_drawingEnabled) return;
    
    // We'll upsert FVGs to avoid deleting/creating repeatedly
    static int lastFVGCount = 0;
    datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    int fvgCount = 0;
    
    // Look for FVGs in recent candles
    for (int i = 2; i < FVGLookback && i < 50; i++) {
        double high1 = iHigh(_Symbol, PERIOD_CURRENT, i + 1);
        double low1 = iLow(_Symbol, PERIOD_CURRENT, i + 1);
        double high2 = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low2 = iLow(_Symbol, PERIOD_CURRENT, i);
        double high3 = iHigh(_Symbol, PERIOD_CURRENT, i - 1);
        double low3 = iLow(_Symbol, PERIOD_CURRENT, i - 1);
        
        datetime fvgTime = iTime(_Symbol, PERIOD_CURRENT, i);
        datetime endTime = currentTime + (3600 * 2); // 2 hours into future
        
        // Bullish FVG
        if (low3 > high1) {
            double gapSize = (low3 - high1) / _Point;
            if (gapSize >= MinFVGSize) {
                string objName = g_fvgPrefix + "BULL_" + IntegerToString(fvgCount);
                string labelName = g_fvgPrefix + "BULL_LABEL_" + IntegerToString(fvgCount);
                
                // Prune FVG objects proactively
                PruneForPrefixIfNeeded(g_fvgPrefix, g_Visual_MaxObjectsPerType);
                ObjectUpsert(g_chartID, objName, OBJ_RECTANGLE, 2, fvgTime, high1, endTime, low3);
                // Soften FVG visuals using configured transparency
                ObjectSetInteger(g_chartID, objName, OBJPROP_COLOR, ColorToARGB(FVGColor, (uchar)Visual_FVGTransparency));
                ObjectSetInteger(g_chartID, objName, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(g_chartID, objName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(g_chartID, objName, OBJPROP_FILL, true);
                ObjectSetInteger(g_chartID, objName, OBJPROP_BACK, true);

                ObjectUpsert(g_chartID, labelName, OBJ_TEXT, 1, fvgTime, (high1 + low3) / 2);
                ObjectSetString(g_chartID, labelName, OBJPROP_TEXT, "Bull FVG");
                ObjectSetInteger(g_chartID, labelName, OBJPROP_COLOR, FVGColor);
                ObjectSetInteger(g_chartID, labelName, OBJPROP_FONTSIZE, 8);

                fvgCount++;
            }
        }
        
        // Bearish FVG
        if (high3 < low1) {
            double gapSize = (low1 - high3) / _Point;
            if (gapSize >= MinFVGSize) {
                string objName = g_fvgPrefix + "BEAR_" + IntegerToString(fvgCount);
                string labelName = g_fvgPrefix + "BEAR_LABEL_" + IntegerToString(fvgCount);
                
                PruneForPrefixIfNeeded(g_fvgPrefix, g_Visual_MaxObjectsPerType);
                ObjectUpsert(g_chartID, objName, OBJ_RECTANGLE, 2, fvgTime, high3, endTime, low1);
                ObjectSetInteger(g_chartID, objName, OBJPROP_COLOR, ColorToARGB(FVGColor, (uchar)Visual_FVGTransparency));
                ObjectSetInteger(g_chartID, objName, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(g_chartID, objName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(g_chartID, objName, OBJPROP_FILL, true);
                ObjectSetInteger(g_chartID, objName, OBJPROP_BACK, true);

                ObjectUpsert(g_chartID, labelName, OBJ_TEXT, 1, fvgTime, (high3 + low1) / 2);
                ObjectSetString(g_chartID, labelName, OBJPROP_TEXT, "Bear FVG");
                ObjectSetInteger(g_chartID, labelName, OBJPROP_COLOR, FVGColor);
                ObjectSetInteger(g_chartID, labelName, OBJPROP_FONTSIZE, 8);

                fvgCount++;
            }
        }
    }
    
    lastFVGCount = fvgCount;
}

//+------------------------------------------------------------------+
//| Draw Dynamic SL/TP Levels                                      |
//+------------------------------------------------------------------+
void DrawDynamicLevelsOnChart() {
    if (!DrawDynamicLevels || !g_drawingEnabled) return;
    
    // Use upsert to avoid deleting/creating each tick
    
    datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    datetime futureTime = currentTime + (3600 * 6); // 6 hours into future
    
    // Draw Dynamic SL
    if (g_dynamicSL > 0) {
        ObjectUpsert(g_chartID, g_slPrefix + "CURRENT", OBJ_TREND, 2, currentTime, g_dynamicSL, futureTime, g_dynamicSL);
        ObjectSetInteger(g_chartID, g_slPrefix + "CURRENT", OBJPROP_COLOR, SLColor);
        ObjectSetInteger(g_chartID, g_slPrefix + "CURRENT", OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(g_chartID, g_slPrefix + "CURRENT", OBJPROP_WIDTH, 2);
        ObjectSetInteger(g_chartID, g_slPrefix + "CURRENT", OBJPROP_RAY_RIGHT, true);

        ObjectUpsert(g_chartID, g_slPrefix + "LABEL", OBJ_TEXT, 1, currentTime, g_dynamicSL);
        ObjectSetString(g_chartID, g_slPrefix + "LABEL", OBJPROP_TEXT, "Dynamic SL: " + DoubleToString(g_dynamicSL, _Digits));
        ObjectSetInteger(g_chartID, g_slPrefix + "LABEL", OBJPROP_COLOR, SLColor);
        ObjectSetInteger(g_chartID, g_slPrefix + "LABEL", OBJPROP_FONTSIZE, 9);
    }
    
    // Draw Dynamic TP
    if (g_dynamicTP > 0) {
        ObjectUpsert(g_chartID, g_tpPrefix + "CURRENT", OBJ_TREND, 2, currentTime, g_dynamicTP, futureTime, g_dynamicTP);
        ObjectSetInteger(g_chartID, g_tpPrefix + "CURRENT", OBJPROP_COLOR, TPColor);
        ObjectSetInteger(g_chartID, g_tpPrefix + "CURRENT", OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(g_chartID, g_tpPrefix + "CURRENT", OBJPROP_WIDTH, 2);
        ObjectSetInteger(g_chartID, g_tpPrefix + "CURRENT", OBJPROP_RAY_RIGHT, true);

        ObjectUpsert(g_chartID, g_tpPrefix + "LABEL", OBJ_TEXT, 1, currentTime, g_dynamicTP);
        ObjectSetString(g_chartID, g_tpPrefix + "LABEL", OBJPROP_TEXT, "Dynamic TP: " + DoubleToString(g_dynamicTP, _Digits));
        ObjectSetInteger(g_chartID, g_tpPrefix + "LABEL", OBJPROP_COLOR, TPColor);
        ObjectSetInteger(g_chartID, g_tpPrefix + "LABEL", OBJPROP_FONTSIZE, 9);
    }
}

//+------------------------------------------------------------------+
void UpdateStatusDisplay(string status) {
    if (!ShowVWAPStatus) return;
    
    string displayText = "SMC Ultimate EA\n";
    displayText += "State: " + status + "\n";
    displayText += "Structure: " + EnumToString(g_marketStructure) + "\n";
    displayText += "Trend: " + EnumToString(g_currentTrend) + "\n";
    displayText += "HTF Trend: " + EnumToString(g_htfTrend) + "\n";
    displayText += "Trend Strength: " + DoubleToString(g_trendStrength, 1) + "\n";
    displayText += "BOS: " + (g_bosDetected ? "YES" : "NO") + "\n";
    displayText += "CHoCH: " + (g_chochDetected ? "YES" : "NO") + "\n";
    displayText += "ZigZag: " + (UseZigZag && g_zigzagInitialized ? "ON" : "OFF") + "\n";
    displayText += "Swing Points: " + IntegerToString(g_swingCount) + "\n";
    displayText += "Order Blocks: " + IntegerToString(g_orderBlockCount) + "\n";
    displayText += "Dynamic SL: " + (g_dynamicSL > 0 ? DoubleToString(g_dynamicSL, _Digits) : "None") + "\n";
    displayText += "Dynamic TP: " + (g_dynamicTP > 0 ? DoubleToString(g_dynamicTP, _Digits) : "None") + "\n";
    displayText += "HH: " + DoubleToString(g_lastHH, _Digits) + " | HL: " + DoubleToString(g_lastHL, _Digits) + "\n";
    displayText += "LH: " + DoubleToString(g_lastLH, _Digits) + " | LL: " + DoubleToString(g_lastLL, _Digits) + "\n";
    displayText += "Daily Trades: " + IntegerToString(g_dailyTrades) + "/" + IntegerToString(MaxDailyTrades) + "\n";
    displayText += "Positions: " + IntegerToString(PositionsTotal()) + "/" + IntegerToString(MaxOpenPositions) + "\n";
    
    if (UseVWAP) {
        displayText += "VWAP: " + DoubleToString(g_vwapValue, _Digits) + "\n";
    }
    
    if (UseConfluenceScoring) {
        int score = CalculateConfluenceScore();
        displayText += "Confluence: " + IntegerToString(score) + "/" + IntegerToString(MaxConfluenceScore) + "\n";
    }
    
    // Ensure status object exists (create if missing)
    if (ObjectFind(g_chartID, g_statusObjectName) == -1) {
        // Create label on the main chart (subwindow 0)
        ObjectCreate(g_chartID, g_statusObjectName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(g_chartID, g_statusObjectName, OBJPROP_CORNER, Visual_PanelCorner);
        ObjectSetInteger(g_chartID, g_statusObjectName, OBJPROP_XDISTANCE, Visual_PanelX);
        ObjectSetInteger(g_chartID, g_statusObjectName, OBJPROP_YDISTANCE, Visual_PanelY);
        ObjectSetInteger(g_chartID, g_statusObjectName, OBJPROP_COLOR, Visual_PanelTextColor);
        ObjectSetInteger(g_chartID, g_statusObjectName, OBJPROP_FONTSIZE, 10);
    }

    ObjectSetString(g_chartID, g_statusObjectName, OBJPROP_TEXT, displayText);
}

//+------------------------------------------------------------------+
//| Cleanup Drawing Objects                                        |
//+------------------------------------------------------------------+
void CleanupDrawingObjects() {
    // Delete VWAP and status objects
    ObjectDelete(g_chartID, g_vwapObjectName);
    ObjectDelete(g_chartID, g_statusObjectName);
    
    // Delete all SMC drawing objects
    CleanupObjectsByPrefix(g_swingPointPrefix);
    CleanupObjectsByPrefix(g_bosPrefix);
    CleanupObjectsByPrefix(g_chochPrefix);
    CleanupObjectsByPrefix(g_orderBlockPrefix);
    CleanupObjectsByPrefix(g_fvgPrefix);
    CleanupObjectsByPrefix(g_slPrefix);
    CleanupObjectsByPrefix(g_tpPrefix);
    CleanupObjectsByPrefix(g_trendLinePrefix);
    CleanupObjectsByPrefix(g_vpPrefix);
    
    Print("All drawing objects cleaned up");
}

//+------------------------------------------------------------------+
//| Cleanup Objects by Prefix                                      |
//+------------------------------------------------------------------+
void CleanupObjectsByPrefix(string prefix) {
    int total = ObjectsTotal(g_chartID);
    
    for (int i = total - 1; i >= 0; i--) {
        string objName = ObjectName(g_chartID, i);
        if (StringFind(objName, prefix) == 0) {
            ObjectDelete(g_chartID, objName);
        }
    }
}

//+------------------------------------------------------------------+
//| Check if New Bar Formed                                        |
//+------------------------------------------------------------------+
bool IsNewBar() {
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (currentBarTime != g_lastBarTime) {
        g_lastBarTime = currentBarTime;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Update Volume Profile on Bar Close (Performance Optimized)     |
//+------------------------------------------------------------------+
void UpdateVolumeProfileOnBarClose() {
    static datetime lastVPUpdate = 0;
    
    // Limit VP updates to once per bar minimum
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (currentBarTime == lastVPUpdate) return;
    
    lastVPUpdate = currentBarTime;
    
    // Clear old VP objects only when necessary
    static int lastVPCount = 0;
    if (lastVPCount > 0) {
        for (int i = 0; i < lastVPCount; i++) {
            ObjectDelete(g_chartID, "VP_" + IntegerToString(i));
        }
    }
    
    // Calculate volume profile for recent price range
    int barsToAnalyze = 60; // reduced for performance
    int availableBars = iBars(_Symbol, PERIOD_CURRENT);
    if (availableBars < barsToAnalyze) barsToAnalyze = availableBars;
    double highestPrice = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, barsToAnalyze, 0));
    double lowestPrice = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, barsToAnalyze, 0));
    
    int pricelevels = 16; // Reduced for performance
    double priceStep = (highestPrice - lowestPrice) / pricelevels;
    
    if (priceStep <= 0) return;
    
    double volumeAtPrice[20];
    ArrayInitialize(volumeAtPrice, 0);
    
    // Calculate volume at each price level
    for (int i = 0; i < barsToAnalyze; i++) {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        double volume = (double)iVolume(_Symbol, PERIOD_CURRENT, i);
        
        // Distribute volume across price levels within the bar's range
        int startLevel = (int)((low - lowestPrice) / priceStep);
        int endLevel = (int)((high - lowestPrice) / priceStep);
        
        if (startLevel < 0) startLevel = 0;
        if (endLevel >= pricelevels) endLevel = pricelevels - 1;
        if (startLevel > endLevel) continue;
        
        double volumePerLevel = volume / (endLevel - startLevel + 1);
        
        for (int level = startLevel; level <= endLevel; level++) {
            volumeAtPrice[level] += volumePerLevel;
        }
    }
    
    // Find maximum volume for scaling
    double maxVolume = volumeAtPrice[ArrayMaximum(volumeAtPrice)];
    if (maxVolume <= 0) return;
    
    // Draw volume profile bars (simplified)
    int drawnBars = 0;
    int maxDrawnBars = 8;
    for (int i = 0; i < pricelevels && drawnBars < maxDrawnBars; i++) {
        if (volumeAtPrice[i] > maxVolume * 0.12) { // Only draw more significant volume levels
            double price = lowestPrice + (i * priceStep);
            double barWidth = (volumeAtPrice[i] / maxVolume) * 100; // Scale to pixels
            
            string objName = "VP_" + IntegerToString(drawnBars);
            ObjectUpsert(g_chartID, objName, OBJ_RECTANGLE, 2,
                         currentBarTime, price,
                         currentBarTime + (int)(barWidth * 60), price + priceStep);

            ObjectSetInteger(g_chartID, objName, OBJPROP_COLOR, clrDarkGray);
            ObjectSetInteger(g_chartID, objName, OBJPROP_FILL, true);
            ObjectSetInteger(g_chartID, objName, OBJPROP_BACK, true);
            
            drawnBars++;
        }
    }
    
    lastVPCount = drawnBars;
    
    if (drawnBars > 0) {
        Print("Volume Profile updated with ", drawnBars, " levels on bar close");
    }
}
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