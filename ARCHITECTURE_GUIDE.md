# SmartMoney_Pro v2.0 - Architecture & System Design

## 📐 System Architecture Overview

SmartMoney_Pro v2.0 is built on a **modular, layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                   METATRADER 5 PLATFORM                     │
├─────────────────────────────────────────────────────────────┤
│                    MAIN EA (SmartMoney_Pro_v2.mq5)           │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Event Handlers: OnInit, OnTick, OnDeinit, OnTradeTransaction
│  └────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                    FUNCTIONAL MODULES                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ LAYER 1: Foundation                                  │   │
│  │ ├─ Enums.mqh (7 enumerations)                       │   │
│  │ ├─ Structures.mqh (5 + 2 structures)                │   │
│  │ ├─ Constants.mqh (60+ constants)                    │   │
│  │ ├─ Globals.mqh (shared state)                       │   │
│  │ └─ InputParameters.mqh (40+ parameters)             │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ LAYER 2: Business Logic                              │   │
│  │ ├─ TimeFilter.mqh (Session & news)                  │   │
│  │ ├─ StructureDetection.mqh (Market structure)        │   │
│  │ ├─ PatternDetection.mqh (FVG & OB)                  │   │
│  │ ├─ EntrySignals.mqh (4 entry methods)               │   │
│  │ └─ RiskManagement.mqh (Daily limits)                │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ LAYER 3: Execution & Management                      │   │
│  │ ├─ TradeManagement.mqh (Setup & execute)            │   │
│  │ └─ PositionManagement.mqh (Breakeven, trailing)    │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ LAYER 4: Presentation & Utilities                    │   │
│  │ ├─ Visualization.mqh (Display & alerts)             │   │
│  │ └─ UtilityFunctions.mqh (Helpers)                   │   │
│  └──────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│                      DATA STORAGE                            │
│  ├─ Global Variables (persistent across restarts)          │
│  ├─ Static Variables (preserved in module scope)           │
│  ├─ Trade Object (CTrade - order execution)                │
│  └─ Indicator Handles (ZigZag, ATR)                        │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Data Flow & Processing Pipeline

### OnTick() Main Processing Loop

```
OnTick() called on every price tick
│
├─ ManagePositions()
│  ├─ ApplyBreakeven()    [if profit ≥ threshold]
│  ├─ ApplyTrailing()     [if profit ≥ threshold]
│  └─ ApplyPartialClose() [if profit ≥ threshold]
│
├─ UpdateFloatingPNL()
│  └─ Sum all open position profits
│
├─ CheckDailyLimits()
│  ├─ CheckAndResetDailyStats()
│  ├─ Verify trade count < Max
│  └─ Verify total P&L > Max Loss
│
├─ IF IsNewBar(LTF):
│  │
│  ├─ UpdateMarketStructure(HTF)
│  │  ├─ CopyHigh/Low data
│  │  ├─ Route to ZigZag or Simple detection
│  │  └─ DrawStructureLines()
│  │
│  ├─ UpdateMarketStructure(LTF)
│  │  └─ [Same as HTF]
│  │
│  ├─ DetectFVG()
│  │  ├─ Scan for 3-candle gaps
│  │  ├─ Check for filled FVGs
│  │  ├─ DrawFVGBox()
│  │  └─ CleanupOldFVGs()
│  │
│  └─ DetectOrderBlocks()
│     ├─ Scan for reversal patterns
│     ├─ DrawOrderBlock()
│     └─ CleanupOldOrderBlocks()
│
├─ IF (canOpenNew && IsTradingAllowed()):
│  │
│  └─ CheckEntrySignals()
│     ├─ IsSpreadAcceptable()
│     ├─ Check HTF confirmation
│     └─ Route based on EntryMethod:
│        ├─ CheckBOSImmediate()
│        ├─ CheckBOSRetest()
│        ├─ CheckCHOCHReversal()
│        └─ CheckCombinedSignals()
│           │
│           └─ IF Setup Valid:
│              └─ ExecuteTrade()
│                 ├─ trade.Buy() or trade.Sell()
│                 ├─ Update stats.tradeCount
│                 └─ SaveDailyStats()
│
└─ UpdateStatisticsPanel()
   └─ Display session, structure, stats
```

## 🕐 Time Filter System

### Session-Based Trading Gate

```
IsTradingAllowed()
│
├─ IF EnableTimeFilter = false:
│  └─ Return true [trading any time]
│
├─ GetGMTTime()
│  └─ Convert server time with GMTOffset
│
├─ GetCurrentSession()
│  ├─ London: 08:00-17:00 GMT  [🇬🇧]
│  ├─ New York: 13:00-22:00 GMT [🇺🇸]
│  └─ Overlap: 13:00-17:00 GMT  [⚡]
│
├─ Session Filtering:
│  ├─ IF TradeOnlyLondon: Allow 08:00-17:00 only
│  ├─ IF TradeOnlyNY: Allow 13:00-22:00 only
│  ├─ IF TradeOverlapOnly: Allow 13:00-17:00 only
│  └─ ELSE: Allow both London and NY
│
└─ CheckNewsAvoidance()
   ├─ IF AvoidNewsTime = false:
   │  └─ Return true
   │
   └─ Detect NFP (1st Friday of month, 13:30 GMT):
      └─ IF within NewsAvoidMinutes:
         └─ Block trading
```

## 📊 Market Structure Detection

### Swing Point Identification

```
UpdateMarketStructure()
│
├─ Copy price arrays (High, Low)
│
└─ Route to detection method:
   │
   ├─ IF UseZigZag && valid indicator:
   │  │
   │  └─ UpdateStructureFromZigZag()
   │     ├─ Copy ZigZag indicator buffer
   │     ├─ Find last 2 swing highs
   │     ├─ Find last 2 swing lows
   │     └─ ProcessStructureChange()
   │
   └─ ELSE:
      │
      └─ DetectSwingsSimple()
         ├─ Scan 30 bars for fractals
         │  ├─ Swing High: H[i] > H[i±1]
         │  └─ Swing Low: L[i] < L[i±1]
         └─ ProcessStructureChange()

ProcessStructureChange()
│
├─ Compare new swings to previous swings
│
├─ IF UPTREND:
│  ├─ newHigh > lastHigh = BOS ↑ (buy signal)
│  └─ newHigh < lastHigh = CHoCH ↓ (reversal)
│
├─ IF DOWNTREND:
│  ├─ newLow < lastLow = BOS ↓ (sell signal)
│  └─ newLow > lastLow = CHoCH ↑ (reversal)
│
└─ Send alerts if enabled
```

## 🎯 Entry Signal Generation (4 Methods)

### Method 1: BOS Immediate

```
IF BOS detected on LTF:
├─ Verify HTF trend confirmation (if required)
└─ Enter immediately
   ├─ Buy if LTF in uptrend (BOS ↑)
   └─ Sell if LTF in downtrend (BOS ↓)
```

### Method 2: BOS Retest

```
Check price position relative to previous swing:
├─ IF uptrend: Price near prevHigh ± RetestTolerance
│  └─ Buy (retest of previous resistance)
└─ IF downtrend: Price near prevLow ± RetestTolerance
   └─ Sell (retest of previous support)
```

### Method 3: CHoCH Reversal

```
IF CHoCH (Change of Character) detected:
├─ CHoCH indicates trend reversal
└─ Enter opposite direction:
   ├─ CHoCH ↑ = Trend reversal to buy
   └─ CHoCH ↓ = Trend reversal to sell
```

### Method 4: Combined Signals

```
Count concurrent signals (minimum 2 required):
├─ BOS signal
├─ CHoCH signal
├─ FVG zone (price in gap zone)
└─ OB zone (price in order block)

IF bullish signals ≥ 2:
└─ BUY with combined reason
IF bearish signals ≥ 2:
└─ SELL with combined reason
```

## 💰 Trade Execution Pipeline

### SetupTrade() Flow

```
SetupTrade(isBuy, signal, reason)
│
├─ 1. Get entry price (Ask for Buy, Bid for Sell)
├─ 2. Get ATR value
│
├─ 3. Calculate Stop Loss
│  ├─ BUY: Below lastLow (or ATR-based fallback)
│  └─ SELL: Above lastHigh (or ATR-based fallback)
│
├─ 4. Enforce MinSLPoints distance
├─ 5. Calculate Take Profit = Entry ± (SL × MinRiskRewardRatio)
├─ 6. ValidateStops() against broker STOPS_LEVEL
│
├─ 7. CalculateLotSize()
│  ├─ IF UseFixedLot: Use FixedLotSize
│  └─ ELSE: Risk-based calculation
│     ├─ riskAmount = Balance × RiskPercent
│     ├─ Cap at MaxRiskPerTrade
│     ├─ lotSize = riskAmount / (SLPoints × tickValue)
│     └─ Cap at MaxLotSize
│
├─ 8. Verify R:R ≥ MinRiskRewardRatio
└─ 9. Set currentSetup.isValid = true

ExecuteTrade()
│
├─ Verify setup is valid
├─ Re-check spread (IsSpreadAcceptable)
├─ Ensure no open position exists
├─ Build trade comment
│
└─ Execute order:
   ├─ trade.Buy(lots, symbol, entry, SL, TP, comment)
   └─ trade.Sell(lots, symbol, entry, SL, TP, comment)
      │
      ├─ On success:
      │  ├─ Increment stats.tradeCount
      │  ├─ SaveDailyStats()
      │  └─ SendAlert()
      │
      └─ On failure:
         └─ Print error details
```

## 🛡️ Position Management

### Profit Protection Strategy

```
ManagePositions() [called every tick]
│
└─ FOR EACH open position:
   │
   ├─ Calculate profit in points
   │
   ├─ 1. ApplyBreakeven()
   │  │  IF profit ≥ BreakevenPoints:
   │  │  └─ Move SL to entry + BreakevenBuffer
   │  │     [Protects capital, locks entry profit]
   │  │
   ├─ 2. ApplyTrailing()
   │  │  IF profit ≥ TrailingStartPoints:
   │  │  ├─ newSL = currentPrice - TrailingStepPoints
   │  │  └─ Update SL if better than current
   │  │     [Locks in profits during trends]
   │  │
   │  └─ 3. ApplyPartialClose()
   │     IF profit ≥ PartialClosePoints:
   │     ├─ Close PartialClosePercent of position
   │     └─ Keep remainder for trailing profits
   │        [Guarantees profit, keeps exposure]
```

## 📈 Risk Management System

### Daily Limits & Statistics

```
CheckDailyLimits() [called every tick]
│
├─ CheckAndResetDailyStats()
│  └─ IF new day: ResetDailyStats()
│
├─ Verify: stats.tradeCount < MaxDailyTrades
│  └─ IF exceeded: Return false [stop trading]
│
├─ Verify: stats.totalPnL > MaxDailyLoss
│  └─ IF loss too high: Return false [stop trading]
│
└─ Return true [trading allowed]

ResetDailyStats() [called at midnight]
│
├─ Calculate today's closed profit from history
├─ Count today's trades from history
├─ Reset win/loss counters
├─ Cleanup aged patterns (FVGs > 200 bars)
└─ SaveDailyStats() to GlobalVariables

SaveDailyStats() [called after each trade]
│
├─ Use GlobalVariableSet() for persistence
└─ Key structure:
   ├─ SMC_SYMBOL_STATS_CLOSED_PROFIT
   ├─ SMC_SYMBOL_STATS_FLOATING_PROFIT
   ├─ SMC_SYMBOL_STATS_TRADE_COUNT
   ├─ SMC_SYMBOL_STATS_WIN_COUNT
   ├─ SMC_SYMBOL_STATS_LOSS_COUNT
   └─ SMC_SYMBOL_STATS_LAST_RESET
```

## 🎨 Display & Notifications

### Statistics Panel

```
UpdateStatisticsPanel() [called every tick]
│
├─ Header: Version + Time Filter indicator
├─ Mode: Entry method + Timeframes
├─ Session Status:
│  ├─ GetCurrentSession() + emoji
│  ├─ GMT time
│  └─ Trading: ALLOWED / BLOCKED
├─ Structure State:
│  ├─ HTF: UPTREND ↑ / DOWNTREND ↓ / NEUTRAL ◆
│  └─ LTF: [same]
├─ Patterns:
│  ├─ FVG count
│  └─ Order Block count
└─ Daily Statistics:
   ├─ Trades: X / MaxDailyTrades
   ├─ Closed P&L
   ├─ Floating P&L
   ├─ Total P&L
   ├─ Win Rate %
   └─ Spread: X pips ✓/✗
```

### Alert System

```
SendAlert(title, message)
│
├─ Format message with EA name
├─ Send Alert() popup [always]
├─ Send Email [if EnableEmail]
├─ Send Push notification [if EnablePush]
├─ Play Sound [if EnableSound]
└─ Print to log
```

## 📊 Data Structures

### MarketStructure

```
struct MarketStructure {
   double lastHigh;           // Most recent swing high
   double lastLow;            // Most recent swing low
   double prevHigh;           // Previous swing high
   double prevLow;            // Previous swing low
   ENUM_STRUCTURE_STATE state; // UPTREND, DOWNTREND, NEUTRAL
   bool hasBOS;               // Break of Structure detected
   bool hasCHOCH;             // Change of Character detected
   datetime lastUpdateTime;   // When updated
   int lastUpdateBar;         // Bar index when updated
}
```

### TradeSetup

```
struct TradeSetup {
   bool isValid;              // Trade is ready to execute
   bool isBuy;                // Buy or Sell
   double entryPrice;         // Entry price
   double stopLoss;           // SL level
   double takeProfit;         // TP level
   double stopLossPoints;     // SL distance in points
   double takeProfitPoints;   // TP distance in points
   double riskRewardRatio;    // R:R ratio
   double lotSize;            // Position size
   double riskAmount;         // USD amount at risk
   ENUM_SIGNAL_TYPE signal;   // What triggered entry
   string reason;             // Detailed reason
   datetime setupTime;        // When setup created
}
```

### DailyStats

```
struct DailyStats {
   double closedProfit;       // Closed P&L today
   double floatingProfit;     // Open positions P&L
   int tradeCount;            // Trades opened today
   int winCount;              // Winning trades
   int lossCount;             // Losing trades
   datetime lastResetDate;    // When stats reset
   double totalPnL;           // closedProfit + floatingProfit
   double winRate;            // winCount / tradeCount %
}
```

## 🔗 Module Dependencies

```
SmartMoney_Pro_v2.mq5
 ├─ <Trade/Trade.mqh> [MT5 library]
 │
 ├─ Enums.mqh [defines enumerations]
 │  └─ used by: all modules
 │
 ├─ Structures.mqh [defines structures]
 │  ├─ depends on: Enums.mqh
 │  └─ used by: all modules
 │
 ├─ Constants.mqh [defines constants]
 │  └─ used by: all modules
 │
 ├─ Globals.mqh [global variables]
 │  ├─ depends on: Structures.mqh, Constants.mqh
 │  └─ used by: all modules
 │
 ├─ InputParameters.mqh [input declarations]
 │  ├─ depends on: Enums.mqh
 │  └─ input parameters accessed by: TimeFilter, others
 │
 ├─ TimeFilter.mqh [session & news]
 │  └─ depends on: Enums, Constants
 │
 ├─ StructureDetection.mqh [swing detection]
 │  ├─ depends on: Structures, Constants, Globals
 │  └─ used by: OnTick()
 │
 ├─ PatternDetection.mqh [FVG & OB]
 │  ├─ depends on: Structures, Constants, Globals
 │  └─ used by: OnTick()
 │
 ├─ EntrySignals.mqh [entry methods]
 │  ├─ depends on: Structures, Enums
 │  └─ calls: SetupTrade()
 │
 ├─ TradeManagement.mqh [setup & execute]
 │  ├─ depends on: Structures, Constants, Globals, Enums
 │  └─ calls: CTrade methods, ValidateStops, CalculateLotSize
 │
 ├─ PositionManagement.mqh [breakeven, trailing, partial]
 │  ├─ depends on: Enums, Constants, Globals
 │  └─ modifies: positions via CTrade
 │
 ├─ RiskManagement.mqh [daily limits, stats]
 │  ├─ depends on: Structures, Constants, Globals
 │  └─ calls: GlobalVariableSet/Get, history functions
 │
 ├─ Visualization.mqh [display & alerts]
 │  ├─ depends on: Structures, Enums, Constants, Globals
 │  └─ uses: ObjectCreate, Comment, Alert, SendMail, SendNotification
 │
 └─ UtilityFunctions.mqh [helper functions]
    └─ depends on: Enums, Structures, Constants
```

## 🔄 State Management

### Persistent State (GlobalVariables)

```
Key Format: SMC_{Symbol}_{Variable}

Daily Stats (persist across restarts):
├─ SMC_EURUSD_STATS_CLOSED_PROFIT
├─ SMC_EURUSD_STATS_FLOATING_PROFIT
├─ SMC_EURUSD_STATS_TRADE_COUNT
├─ SMC_EURUSD_STATS_WIN_COUNT
├─ SMC_EURUSD_STATS_LOSS_COUNT
└─ SMC_EURUSD_STATS_LAST_RESET
```

### Runtime State (Globals & Statics)

```
Market Structures:
├─ structureHTF [struct MarketStructure]
└─ structureLTF [struct MarketStructure]

Pattern Arrays:
├─ fvgArray[] [FVGInfo - dynamic list]
├─ obArray[] [OrderBlockInfo - dynamic list]
├─ fvgCount [current number of FVGs]
└─ obCount [current number of OBs]

Current Setup:
└─ currentSetup [struct TradeSetup]

Daily Statistics:
└─ stats [struct DailyStats]

New Bar Detection:
├─ lastBarTimeHTF [static per module]
└─ lastBarTimeLTF [static per module]
```

---

## 📚 Additional Resources

For detailed implementations, see:
- **TimeFilter.mqh**: Lines 1-150 (Session & news logic)
- **StructureDetection.mqh**: Lines 1-200 (Swing detection)
- **EntrySignals.mqh**: Lines 1-250 (Entry methods)
- **TradeManagement.mqh**: Lines 1-300 (Setup & execution)
- **IMPLEMENTATION_PLAN.md**: Full function specifications

---

**Architecture Version**: 2.0.0
**Created**: 2025-11-19
**Status**: Production Ready
