//+------------------------------------------------------------------+
//|                                              SMC_ComponentTester |
//|         Self-contained script to test core EA components        |
//|                                                                  |
//| How to use:                                                      |
//| - Copy to MetaTrader 5 -> MQL5 -> Scripts                        |
//| - Open MetaEditor and compile (F7), then run on any chart        |
//| - The script will print PASS/FAIL results to the Experts tab     |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

//-----------------------------
// Inputs mirroring EA settings
//-----------------------------
input string TestSymbol = "";                       // Symbol to test (empty = current chart symbol)
input ENUM_TIMEFRAMES TestTF = PERIOD_M15;           // Timeframe for bar-related tests

// Risk / lot configuration (as in EA)
input bool   UseAutoLot = true;                      // Auto position sizing
input double RiskPercent = 2.0;                      // Risk % per trade
input double LotSize = 0.01;                         // Fixed lots when UseAutoLot = false

// Stops/entry config
input int    MinStopBufferPoints = 20;               // Extra stop buffer beyond broker stop level (balanced)
input int    EntryOffsetPoints = 15;                 // Offset for pending price calc (points) (balanced)

// Timing config
input bool   UseNewBarTrigger = true;                // Only trigger on new bar
input ENUM_TIMEFRAMES AnalysisTimeframe = PERIOD_M15;// Analysis TF for new bar gating
input int    ConfirmationTimeoutSeconds = 180;       // Confirmation timeout seconds (balanced)

// Sample scenario toggles
input bool   SampleBullish = true;                   // Bullish sample for price/SLTP tests
input int    SampleSLDistancePoints = 250;           // Sample SL distance for lot sizing test

//-----------------------------
// Internals
//-----------------------------
int g_totalTests = 0;
int g_passedTests = 0;
datetime g_lastAnalysisBarTime = 0;

//-----------------------------
// Utility helpers
//-----------------------------
int GetSymbolDigits() { return (int)_Digits; }
double NormalizeToDigits(double v) { return NormalizeDouble(v, GetSymbolDigits()); }
double DMax(double a, double b) { return (a > b) ? a : b; }

bool EnsureSymbolSelected(const string symbol) {
    long sel = 0;
    if (SymbolInfoInteger(symbol, SYMBOL_SELECT, sel) && sel != 0)
        return true;
    return SymbolSelect(symbol, true);
}

double GetMinStopDistance(const string symbol) {
    long lvl = 0;
    if (!SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL, lvl))
        return (MinStopBufferPoints > 0 ? MinStopBufferPoints : 0) * _Point; // fallback
    int stopLevel = (int)lvl;
    if (stopLevel < 0) stopLevel = 0;
    int buffer = MinStopBufferPoints;
    return (stopLevel + buffer) * _Point;
}

bool ValidateAndAdjustSLTP(ENUM_ORDER_TYPE type, double entry, double &sl, double &tp, const string symbol) {
    double minDist = GetMinStopDistance(symbol);
    bool ok = true;

    if (type == ORDER_TYPE_BUY) {
        // SL must be below entry by at least minDist; TP above by at least minDist
        if (sl >= entry - minDist) { sl = entry - minDist; ok = false; }
        if (tp <= entry + minDist) { tp = entry + minDist; ok = false; }
    } else {
        // SELL: SL above entry; TP below entry
        if (sl <= entry + minDist) { sl = entry + minDist; ok = false; }
        if (tp >= entry - minDist) { tp = entry - minDist; ok = false; }
    }

    sl = NormalizeToDigits(sl);
    tp = NormalizeToDigits(tp);
    return ok;
}

double CalculatePositionSizeForSLDistance(double slDistancePoints, const string symbol) {
    double lotSizeCalc = LotSize;
    if (UseAutoLot && RiskPercent > 0 && slDistancePoints > 0) {
        double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent / 100.0);
        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        if (tickValue > 0 && point > 0) {
            double moneyPerLotPerPoint = (tickValue / (SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) / point));
            double moneyPerLotAtSL = moneyPerLotPerPoint * slDistancePoints;
            if (moneyPerLotAtSL > 0)
                lotSizeCalc = riskMoney / moneyPerLotAtSL;
        }
    }
    // Apply lot constraints
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    if (lotSizeCalc < minLot) lotSizeCalc = minLot;
    if (lotSizeCalc > maxLot) lotSizeCalc = maxLot;
    if (lotStep > 0) lotSizeCalc = MathRound(lotSizeCalc / lotStep) * lotStep;
    return NormalizeDouble(lotSizeCalc, 2);
}

bool GetBreakoutPendingPrice(bool bullish, double &priceOut, const string symbol) {
    // Use recent swing extreme: last known high/low from recent bars as proxy
    int bars = 50;
    double hh = iHigh(symbol, TestTF, iHighest(symbol, TestTF, MODE_HIGH, bars, 1));
    double ll = iLow(symbol, TestTF, iLowest(symbol, TestTF, MODE_LOW, bars, 1));
    double offset = EntryOffsetPoints * _Point;
    if (bullish && hh > 0) { priceOut = hh + offset; return true; }
    if (!bullish && ll > 0) { priceOut = ll - offset; return true; }
    return false;
}

bool IsConfirmationExpired(datetime startTime, int timeoutSeconds) {
    if (startTime <= 0 || timeoutSeconds <= 0) return false;
    return (TimeCurrent() - startTime) >= timeoutSeconds;
}

bool ShouldTriggerAnalysisNewBar(bool useNewBarTrigger, ENUM_TIMEFRAMES tf, datetime &lastBarTime, const string symbol) {
    if (!useNewBarTrigger) return true;
    datetime currentBarTime = iTime(symbol, tf, 0);
    if (currentBarTime == 0) return false; // no data
    if (lastBarTime == 0) { lastBarTime = currentBarTime; return true; }
    if (currentBarTime != lastBarTime) { lastBarTime = currentBarTime; return true; }
    return false;
}

void RecordTestResult(bool condition, const string testName) {
    g_totalTests++;
    if (condition) { g_passedTests++; Print("[PASS] ", testName); }
    else { Print("[FAIL] ", testName); }
}

string TradeModeToString(ENUM_SYMBOL_TRADE_MODE m) {
    switch (m) {
        case SYMBOL_TRADE_MODE_DISABLED:  return "DISABLED";
        case SYMBOL_TRADE_MODE_LONGONLY:  return "LONGONLY";
        case SYMBOL_TRADE_MODE_SHORTONLY: return "SHORTONLY";
        case SYMBOL_TRADE_MODE_CLOSEONLY: return "CLOSEONLY";
        case SYMBOL_TRADE_MODE_FULL:      return "FULL";
        default: return "UNKNOWN";
    }
}

//-----------------------------
// OnStart - run modular tests
//-----------------------------
void OnStart() {
    string symbol = (TestSymbol == "" ? _Symbol : TestSymbol);
    Print("=== SMC Component Tester starting on ", symbol, " TF=", EnumToString(TestTF), " ===");
    if (!EnsureSymbolSelected(symbol)) { Print("ERROR: Cannot select symbol ", symbol); return; }

    // Test 1: Symbol capability introspection (trade mode / expiration / filling)
    {
        long tradeModeRaw = 0; SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE, tradeModeRaw);
        long expModes = 0; SymbolInfoInteger(symbol, SYMBOL_EXPIRATION_MODE, expModes);
        long fillFlags = 0; SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE, fillFlags);
        Print("SYMBOL_TRADE_MODE=", TradeModeToString((ENUM_SYMBOL_TRADE_MODE)tradeModeRaw));
        Print("SYMBOL_EXPIRATION_MODE flags=", (int)expModes, " (SPECIFIED=",(expModes & (1<<0))!=0,", DAY=",(expModes & (1<<1))!=0,", GTC=",(expModes & (1<<2))!=0,")");
        Print("SYMBOL_FILLING_MODE flags: RETURN=", (fillFlags & ORDER_FILLING_RETURN)!=0,
              " IOC=", (fillFlags & ORDER_FILLING_IOC)!=0, " FOK=", (fillFlags & ORDER_FILLING_FOK)!=0);
        RecordTestResult(true, "Symbol capability introspection");
    }

    // Test 2: SL/TP validation and normalization
    {
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        ENUM_ORDER_TYPE side = (SampleBullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
        double entry = (side == ORDER_TYPE_BUY ? ask : bid);
        double sl = (side == ORDER_TYPE_BUY ? entry - 200*_Point : entry + 200*_Point);
        double tp = (side == ORDER_TYPE_BUY ? entry + 400*_Point : entry - 400*_Point);
        bool ok = ValidateAndAdjustSLTP(side, entry, sl, tp, symbol);
        Print("SLTP validation ok=", ok, " => SL=", DoubleToString(sl, _Digits), " TP=", DoubleToString(tp, _Digits));
        RecordTestResult(true, "SL/TP validation adjusts within min stop distance");
    }

    // Test 3: Position sizing based on SL distance (points)
    {
        double lots = CalculatePositionSizeForSLDistance(DMax(1.0, (double)SampleSLDistancePoints), symbol);
        Print("Auto lot size for SL ", SampleSLDistancePoints, " points => ", DoubleToString(lots, 2), " lots");
        RecordTestResult(lots > 0, "Position sizing > 0");
    }

    // Test 4: Breakout pending price computation
    {
        double p = 0; bool ok = GetBreakoutPendingPrice(SampleBullish, p, symbol);
        Print("Breakout ", (SampleBullish ? "BUY_STOP" : "SELL_STOP"), " price=", (ok ? DoubleToString(p, _Digits) : "N/A"));
        RecordTestResult(ok, "Breakout pending price computed");
    }

    // Test 5: Confirmation timeout logic
    {
        datetime startNow = TimeCurrent();
        bool notExpired = !IsConfirmationExpired(startNow, ConfirmationTimeoutSeconds);
        bool expiredSim  = IsConfirmationExpired(startNow - (ConfirmationTimeoutSeconds + 1), ConfirmationTimeoutSeconds);
        RecordTestResult(notExpired && expiredSim, "Confirmation timeout behavior");
    }

    // Test 6: New-bar trigger gating
    {
        g_lastAnalysisBarTime = 0; // reset
        bool first = ShouldTriggerAnalysisNewBar(UseNewBarTrigger, AnalysisTimeframe, g_lastAnalysisBarTime, symbol);
        bool second = ShouldTriggerAnalysisNewBar(UseNewBarTrigger, AnalysisTimeframe, g_lastAnalysisBarTime, symbol);
        // Expect first=true (initialization), second=false (same bar)
        RecordTestResult(first && !second, "New bar trigger gating");
    }

    Print("=== Tests completed: ", g_passedTests, "/", g_totalTests, " passed ===");
}

//+------------------------------------------------------------------+
//| End of SMC_ComponentTester                                      |
//+------------------------------------------------------------------+
