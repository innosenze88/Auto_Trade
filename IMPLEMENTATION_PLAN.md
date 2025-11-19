# MQL5 EA Implementation Plan
## SmartMoney_Pro_Clean_v2.0 - Complete Development Roadmap

**Project**: Auto_Trade - Professional SMC Trading EA with Time Filter System
**Language**: MQL5
**Target**: MetaTrader 5
**Version**: 2.0.0
**Status**: Planning Phase ✅

---

## 📋 Implementation Overview

This is a **14-phase development plan** to build a complete professional Smart Money Concepts (SMC) trading EA with time filter functionality. The architecture is modular, event-driven, and risk-managed.

### Key Statistics
- **Total Functions**: 50+
- **Input Parameter Groups**: 8
- **Core Data Structures**: 5
- **Supported Entry Methods**: 4
- **Global State Persistence**: Daily stats via GlobalVariables

---

## 🏗️ PHASE BREAKDOWN

### Phase 1️⃣: Foundation & Project Structure
**Objective**: Setup core architecture and data models
**Duration**: 1-2 days
**Dependencies**: None

#### Tasks:
- [ ] Create modular `.mqh` include files structure
  - `Enums.mqh` - All enumerations
  - `Structures.mqh` - All data structures
  - `Globals.mqh` - Global variables & arrays
  - `Constants.mqh` - Configuration constants

- [ ] Define Core Enumerations:
  ```
  ENUM_ENTRY_METHOD {
    ENTRY_BOS_IMMEDIATE,
    ENTRY_BOS_RETEST,
    ENTRY_CHOCH_REVERSAL,
    ENTRY_COMBINED
  }

  ENUM_STRUCTURE_STATE {
    NEUTRAL, UPTREND, DOWNTREND
  }

  ENUM_SIGNAL_TYPE {
    BOS_BULL, BOS_BEAR, CHOCH_BULL, CHOCH_BEAR, FVG, OB
  }
  ```

- [ ] Define Core Structures:
  - `MarketStructure` - Swing highs/lows + BOS/CHoCH flags
  - `FVGInfo` - Fair Value Gap data
  - `OrderBlockInfo` - Order Block data
  - `TradeSetup` - Entry/SL/TP calculations
  - `DailyStats` - W/L counts, profits, timestamps

- [ ] Initialize Trade Object & Indicators:
  - CTrade object for order execution
  - ZigZag indicator handle
  - ATR indicator handle

- [ ] Setup GlobalVariable persistence system:
  - Daily stats save/load functions
  - Unique key prefixing per symbol/magic

**Output**: Fully structured project with all data types defined

---

### Phase 2️⃣: Time Filter System 🕐
**Objective**: Implement session-aware trading filters
**Duration**: 1-2 days
**Dependencies**: Phase 1 ✅

#### Tasks:
- [ ] Implement `GetGMTTime() → datetime`
  - Convert server time to GMT
  - Account for DST differences

- [ ] Implement `GetCurrentSession() → string`
  - Identify London session (08:00-17:00 GMT)
  - Identify New York session (13:00-22:00 GMT)
  - Identify overlap period (13:00-17:00 GMT)
  - Return session name with emoji indicator

- [ ] Implement `CheckNewsAvoidance() → bool`
  - Detect NFP day (1st Friday of month)
  - Avoid trades 30/60/120 minutes around news events
  - Configurable avoidance window

- [ ] Implement `IsTradingAllowed() → bool`
  - Main filter function (gate for all trades)
  - Honor EnableTimeFilter toggle
  - Check session restrictions
  - Check news avoidance
  - Return: true if trading should be allowed

**Output**: Time-based trading gate system operational

---

### Phase 3️⃣: Market Structure Detection 📊
**Objective**: Detect swings, trends, and structural changes
**Duration**: 2-3 days
**Dependencies**: Phase 1 ✅, Phase 2 ✅

#### Tasks:
- [ ] Implement `UpdateMarketStructure(ENUM_TIMEFRAMES tf, MarketStructure &structure)`
  - Copy price data (High/Low arrays)
  - Route to ZigZag method if enabled + valid handle
  - Fallback to simple fractal detection
  - Call ProcessStructureChange on updates

- [ ] Implement `UpdateStructureFromZigZag()`
  - Copy ZigZag indicator buffers
  - Find last 2 swing highs
  - Find last 2 swing lows
  - Detect if structure changed
  - If changed: ProcessStructureChange() + redraw

- [ ] Implement `DetectSwingsSimple(tf, structure)`
  - Scan 30 bars backward
  - Identify swing highs (fractal: H[i] > H[i±1])
  - Identify swing lows (fractal: L[i] < L[i±1])
  - Store as lastHigh/Low + prevHigh/Low
  - If changed: ProcessStructureChange() + redraw

- [ ] Implement `ProcessStructureChange()`
  - Reset BOS/CHoCH flags
  - Compare new swings to previous swings
  - **Uptrend**: newHigh > lastHigh = BOS↑ | newHigh < lastHigh = CHoCH↓
  - **Downtrend**: newLow < lastLow = BOS↓ | newLow > lastLow = CHoCH↑
  - **Neutral**: Determine initial trend direction
  - Send alerts if enabled

**Output**: Accurate trend + BOS/CHoCH detection system

---

### Phase 4️⃣: Pattern Detection (FVG & Order Blocks) 🎯
**Objective**: Identify Fair Value Gaps and Order Blocks
**Duration**: 2-3 days
**Dependencies**: Phase 1 ✅

#### Tasks:
- [ ] Implement `DetectFVG()`
  - Copy OHLC data
  - **Bullish FVG**: Gap = Low[i] - High[i+3]
    - If gap > MinFVGPips: Add to array
    - Check if already exists
    - Draw FVG box + send alert
  - **Bearish FVG**: Gap = Low[i+3] - High[i]
    - Same logic, opposite direction
  - Monitor FVG "filled" status (price crosses zone)
  - Update visual status (solid → dotted)

- [ ] Implement `DetectOrderBlocks()`
  - Scan 2-15 bars back
  - **Bullish OB**: Strong bullish candle (close > open) preceded by bearish
  - **Bearish OB**: Strong bearish candle (close < open) preceded by bullish
  - Add to array + draw box + send alert
  - Store high/low range of OB

- [ ] Implement `CleanupOldFVGs()`
  - Remove FVGs older than 200 bars
  - Update array indices

- [ ] Implement `CleanupOldOrderBlocks()`
  - Remove OBs older than 200 bars
  - Update array indices

**Output**: FVG & Order Block detection + lifecycle management

---

### Phase 5️⃣: Entry Signal Generation ⚡
**Objective**: Generate trading signals from detected patterns
**Duration**: 2-3 days
**Dependencies**: Phase 3 ✅, Phase 4 ✅

#### Tasks:
- [ ] Implement `CheckEntrySignals()`
  - Main dispatcher function
  - Validate spread (IsSpreadAcceptable)
  - Check HTF confirmation (if required)
  - Switch on EntryMethod enum:
    1. `CheckBOSImmediate()`
    2. `CheckBOSRetest()`
    3. `CheckCHOCHReversal()`
    4. `CheckCombinedSignals()`
  - If currentSetup.isValid: ExecuteTrade()

- [ ] Implement `CheckBOSImmediate()`
  - Check if ltfStructure.hasBOS
  - Verify HTF trending in same direction
  - If uptrend: SetupTrade(BUY)
  - If downtrend: SetupTrade(SELL)
  - Reset BOS flag after trade

- [ ] Implement `CheckBOSRetest()`
  - Get previous swing level (prevHigh/Low)
  - Check if current price near retest level (±10 pips configurable)
  - If trending UP + near prevHigh: SetupTrade(BUY)
  - If trending DOWN + near prevLow: SetupTrade(SELL)

- [ ] Implement `CheckCHOCHReversal()`
  - Check if ltfStructure.hasCHOCH
  - CHoCH indicates trend reversal
  - SetupTrade opposite to previous trend
  - Reset CHoCH flag after trade

- [ ] Implement `CheckCombinedSignals()`
  - Check for multiple concurrent signals
  - BOS + FVG + OB combination = stronger confirmation
  - Build composite signal reason string
  - Apply HTF filter
  - SetupTrade with combined reason

**Output**: Multi-method entry signal system

---

### Phase 6️⃣: Trade Setup & Execution 💰
**Objective**: Calculate trades and execute orders
**Duration**: 2-3 days
**Dependencies**: Phase 5 ✅, Phase 1 ✅

#### Tasks:
- [ ] Implement `SetupTrade(bool isBuy, ENUM_SIGNAL_TYPE signal, string reason)`
  - Reset currentSetup
  - Get Ask/Bid price
  - Get ATR value
  - **Calculate SL**:
    - Use structure level (lastLow for buy, lastHigh for sell)
    - Alternative: ATR-based method (price ± 2*ATR)
  - Enforce MinSLPoints minimum
  - **Calculate TP**:
    - TP = Entry ± (SL distance × MinRiskReward)
  - ValidateStops() to enforce broker requirements
  - CalculateLotSize(SL distance)
  - Verify R:R ≥ MinRiskRewardRatio
  - Set currentSetup.isValid = true

- [ ] Implement `ValidateStops(isBuy, entry, SL, TP)`
  - Get broker STOPS_LEVEL (in points)
  - Calculate required min distance
  - Adjust SL if too close to entry
  - Adjust TP if too close
  - Re-verify R:R after adjustment
  - Return success/fail

- [ ] Implement `CalculateLotSize(slPoints) → double`
  - If UseFixedLot: return FixedLotSize
  - Else (risk-based):
    - riskAmount = AccountBalance × RiskPercent
    - Cap at MaxRiskPerTrade
    - Calculate tick value (point × tickSize)
    - lotSize = riskAmount / (slPoints × tickValue)
    - Cap at MaxLotSize
  - Normalize to broker lot step (e.g., 0.01)
  - Return final lot size

- [ ] Implement `IsSpreadAcceptable() → bool`
  - Get Ask & Bid
  - Calculate spread in points
  - Compare with MaxSpreadPoints parameter
  - Return true if acceptable

- [ ] Implement `ExecuteTrade()`
  - Validate currentSetup
  - Re-check spread immediately
  - Ensure no position exists (one at a time)
  - Build trade comment string
  - Call CTrade.Buy() or CTrade.Sell()
  - If success:
    - Increment trade counter
    - SaveDailyStats()
    - Print confirmation
    - Send alert
  - If fail: Print error + reason

**Output**: Professional trade execution pipeline

---

### Phase 7️⃣: Position Management 📈
**Objective**: Manage open trades with profit protection
**Duration**: 1-2 days
**Dependencies**: Phase 6 ✅

#### Tasks:
- [ ] Implement `ManagePositions()`
  - Loop all positions with Magic + Symbol filter
  - Get position details (ticket, type, open price, current price)
  - Calculate profit in points
  - Apply management rules in order:
    1. ApplyBreakeven() if profit ≥ BreakevenPoints
    2. ApplyTrailing() if profit ≥ TrailingStartPoints
    3. ApplyPartialClose() if profit ≥ PartialClosePoints

- [ ] Implement `ApplyBreakeven(ticket, type, openPrice, currentSL)`
  - Check if already at breakeven (SL ≥ openPrice)
  - Calculate new SL = openPrice + BreakevenBuffer pips
  - Only apply if new SL is better than current
  - PositionModify() with new SL
  - Print confirmation

- [ ] Implement `ApplyTrailing(ticket, type, openPrice, currentPrice, currentSL, currentTP)`
  - Calculate new SL = currentPrice - TrailingStepPoints
  - Validate new SL:
    - Better than current SL
    - Never below/above open price (buy/sell)
  - PositionModify() with new SL only
  - Print confirmation

- [ ] Implement `ApplyPartialClose(ticket, type)`
  - Check if already partially closed (tracking variable)
  - Calculate closeVolume = currentVolume × PartialClosePercent
  - Ensure closeVolume ≥ minimum broker lot
  - PositionClosePartial() with calculated volume
  - Print confirmation
  - Mark as partial-closed

**Output**: Automated profit protection system

---

### Phase 8️⃣: Risk Management & Daily Limits 🛡️
**Objective**: Enforce trading limits and track daily statistics
**Duration**: 2-3 days
**Dependencies**: Phase 1 ✅

#### Tasks:
- [ ] Implement `CheckDailyLimits() → bool`
  - Call CheckAndResetDailyStats()
  - If stats.tradeCount ≥ MaxDailyTrades: return false
  - Calculate total P&L = closedProfit + floatingProfit
  - If totalPnL ≤ -MaxDailyLossPoints: return false
  - Return true (trading allowed)

- [ ] Implement `CheckAndResetDailyStats()`
  - Get current date
  - Get stats.lastResetDate from GlobalVariables
  - If different day OR first run: ResetDailyStats()

- [ ] Implement `ResetDailyStats()`
  - Calculate CalculateTodayClosedProfit() from deal history
  - Set floatingProfit = 0 initially
  - Count = CountTodayTrades() from deal history
  - Reset stats.winCount = 0
  - Reset stats.lossCount = 0
  - Update stats.lastResetDate = current timestamp
  - CleanupOldFVGs() + CleanupOldOrderBlocks()
  - SaveDailyStats()

- [ ] Implement `UpdateFloatingPNL()`
  - Reset stats.floatingProfit = 0
  - Loop all open positions
  - Sum POSITION_PROFIT values
  - Store in stats.floatingProfit

- [ ] Implement `SaveDailyStats()`
  - Build unique key prefix: symbol_magic_date
  - GlobalVariableSet() for:
    - closedProfit, floatingProfit
    - tradeCount, winCount, lossCount
    - lastResetDate
  - All persisted across EA restarts

- [ ] Implement `LoadDailyStats()`
  - Build prefix key
  - If GlobalVariable exists: Load all stats
  - Print loaded values for verification
  - Else: Initialize to zeros

**Output**: Robust daily limit enforcement + persistent tracking

---

### Phase 9️⃣: Core Event Handlers 🎮
**Objective**: Implement main EA lifecycle
**Duration**: 2-3 days
**Dependencies**: Phases 1-8 ✅

#### Tasks:
- [ ] Implement `OnInit()`
  - Print initialization header
  - Create CTrade object with magic + slippage
  - Create indicator handles (ZigZag, ATR)
  - Reset both structures (HTF, LTF)
  - Resize FVG & OB arrays to expected size
  - LoadDailyStats() from GlobalVariables
  - Print initialized indicators + params
  - Return INIT_SUCCEEDED or INIT_FAILED

- [ ] Implement `OnDeinit(int reason)`
  - SaveDailyStats() to GlobalVariables
  - Release ZigZag & ATR handles
  - Delete all chart objects (lines, boxes)
  - Clear comment display
  - Print deinitialization reason

- [ ] Implement `OnTick()`
  - **Step 1**: ManagePositions()
    - Breakeven, trailing, partial close

  - **Step 2**: UpdateFloatingPNL()

  - **Step 3**: CheckDailyLimits()
    - Get canOpenNew flag
    - If false: return early

  - **Step 4**: If IsNewBar(LTF):
    - UpdateMarketStructure(HTF)
    - UpdateMarketStructure(LTF)
    - DetectFVG()
    - DetectOrderBlocks()

  - **Step 5**: If canOpenNew && IsTradingAllowed():
    - CheckEntrySignals()

  - **Step 6**: UpdateStatisticsPanel()

- [ ] Implement `OnTradeTransaction(MqlTradeTransaction &trans, MqlTradeRequest &req, MqlTradeResult &result)`
  - Monitor TRADE_TRANSACTION_DEAL_ADD
  - Detect position closures
  - Update stats.closedProfit
  - Increment stats.winCount or stats.lossCount
  - SaveDailyStats() immediately

**Output**: Complete EA lifecycle with event handling

---

### Phase 🔟: Display & Visualization 🎨
**Objective**: Implement visual feedback system
**Duration**: 1-2 days
**Dependencies**: Phase 3 ✅, Phase 4 ✅, Phase 2 ✅

#### Tasks:
- [ ] Implement `DrawStructureLines(ENUM_TIMEFRAMES tf, MarketStructure &structure)`
  - Draw lastHigh level (solid blue for uptrend)
  - Draw lastLow level (solid blue for downtrend)
  - Draw prevHigh level (dashed grey)
  - Draw prevLow level (dashed grey)
  - Use ObjectCreate/ObjectSetDouble

- [ ] Implement `DrawFVGBox(FVGInfo &fvg)`
  - Create rectangle object
  - Top = upper FVG boundary
  - Bottom = lower FVG boundary
  - Color: Green (bullish) or Red (bearish)
  - Transparency: 30%

- [ ] Implement `UpdateFVGBoxFilled(FVGInfo &fvg)`
  - Change style from solid to dotted
  - Indicates FVG has been filled

- [ ] Implement `DrawOrderBlock(OrderBlockInfo &ob)`
  - Create rectangle object
  - Range: ob.high to ob.low
  - Color: Light blue (bullish) or Light red (bearish)
  - Transparency: 20%

- [ ] Implement `UpdateStatisticsPanel()` ⭐ MODIFIED
  - Build comment string:
    1. Header: "SmartMoney_Pro v2.0 🕐"
    2. Mode info: Entry method + timeframes
    3. **Session Status** (NEW):
       - GetCurrentSession()
       - Display session name + emoji
       - Show GMT time
    4. HTF/LTF trend states
    5. Active FVG count
    6. Daily stats:
       - Trade count
       - Total P&L (closed + floating)
       - Win rate %
       - Open positions P&L
       - Current spread
  - Comment(info)

- [ ] Implement `SendAlert(string title, string message)`
  - Format: "[EA_NAME] title: message"
  - Alert() function
  - Optional: Email if configured
  - Optional: Push notification if configured
  - Optional: Sound if configured

**Output**: Professional visual feedback system

---

### Phase 1️⃣1️⃣: Utility & Helper Functions 🔧
**Objective**: Implement supporting utility functions
**Duration**: 1-2 days
**Dependencies**: Phase 1 ✅

#### Tasks:
- [ ] Implement `IsNewBar(ENUM_TIMEFRAMES tf) → bool`
  - Track last bar time per timeframe
  - Compare SeriesInfoInteger(SERIES_LASTBAR_DATE)
  - Return true on new bar
  - Static variable for tracking

- [ ] Implement `CalculateTodayClosedProfit() → double`
  - Scan deal history from midnight today
  - Sum profit from DEAL_ENTRY_IN deals
  - Sum loss from DEAL_ENTRY_OUT deals
  - Return net closed profit

- [ ] Implement `CountTodayTrades() → int`
  - Scan deal history from midnight today
  - Count DEAL_ENTRY_IN entries (opening trades)
  - Return count

- [ ] Implement `GetStateString(ENUM_STRUCTURE_STATE state) → string`
  - NEUTRAL → "NEUTRAL ◆"
  - UPTREND → "UPTREND ↑"
  - DOWNTREND → "DOWNTREND ↓"
  - Return formatted string

- [ ] Implement `GetSignalString(ENUM_SIGNAL_TYPE signal) → string`
  - BOS_BULL → "BOS ↑"
  - BOS_BEAR → "BOS ↓"
  - CHOCH_BULL → "CHoCH ↑"
  - CHOCH_BEAR → "CHoCH ↓"
  - FVG → "FVG ⊝"
  - OB → "OB ■"
  - Return formatted string

- [ ] Implement `ResetStructure(MarketStructure &structure)`
  - Initialize all fields to 0/NEUTRAL
  - Clear trend detection
  - Clear BOS/CHoCH flags

**Output**: Complete utility function set

---

### Phase 1️⃣2️⃣: Input Parameters Configuration ⚙️
**Objective**: Define all user-configurable parameters
**Duration**: 1 day
**Dependencies**: Phase 1 ✅

#### Task: Define 8 Input Groups

```
//--- Group 1: Timeframe Settings
input ENUM_TIMEFRAMES HTF = PERIOD_H4;           // Higher Timeframe
input ENUM_TIMEFRAMES LTF = PERIOD_H1;           // Lower Timeframe
input int ZigZagDepth = 12;                      // ZigZag Deviation %
input bool UseZigZag = true;                     // Use ZigZag Indicator

//--- Group 2: Entry Method
input ENUM_ENTRY_METHOD EntryMethod = ENTRY_BOS_IMMEDIATE;
input bool RequireHTFConfirmation = true;

//--- Group 3: Risk Management
input bool UseFixedLot = false;
input double FixedLotSize = 0.1;
input double RiskPercent = 2.0;                  // Risk % per trade
input double MinRiskRewardRatio = 1.5;
input double MaxLotSize = 1.0;
input double MaxRiskPerTrade = 100.0;            // USD
input int MaxSpreadPoints = 10;

//--- Group 4: SMC Settings
input bool EnableFVGDetection = true;
input bool EnableOBDetection = true;
input int MinFVGPips = 5;
input int MinOBPips = 5;

//--- Group 5: Profit Protection
input int BreakevenPoints = 20;
input int BreakevenBuffer = 2;
input int TrailingStartPoints = 50;
input int TrailingStepPoints = 10;
input int PartialClosePoints = 30;
input double PartialClosePercent = 0.5;         // 50% volume

//--- Group 6: Visual Settings
input color LineColor = clrBlue;
input int LineWidth = 1;
input bool ShowStructure = true;
input bool ShowFVG = true;
input bool ShowOB = true;
input bool ShowPanel = true;

//--- Group 7: Alert Settings
input bool EnableAlerts = true;
input bool EnableEmail = false;
input bool EnablePush = false;
input bool EnableSound = true;

//--- Group 8: Time Filter Settings (NEW)
input bool EnableTimeFilter = true;
input bool TradeOnlyLondon = false;              // Restrict to London session
input bool TradeOnlyNY = false;                  // Restrict to NY session
input bool TradeOverlapOnly = true;              // Restrict to 13:00-17:00 GMT
input bool AvoidNewsTime = true;
input int NewsAvoidMinutes = 60;                 // Minutes before/after news
input int MaxDailyTrades = 5;
input int MaxDailyLossPoints = -500;
```

**Output**: Fully parameterized EA with 8 input groups

---

### Phase 1️⃣3️⃣: Testing & Validation 🧪
**Objective**: Ensure all systems work correctly
**Duration**: 3-5 days
**Dependencies**: Phases 1-12 ✅

#### Tasks:
- [ ] Compile EA
  - Fix any syntax errors
  - Resolve warnings
  - Verify all includes load correctly

- [ ] Unit test each function independently
  - Test time conversion (GetGMTTime)
  - Test session detection (GetCurrentSession)
  - Test swing detection logic
  - Test lot size calculation
  - Test stop validation
  - Verify all return values

- [ ] Integration testing
  - Deploy to MT5 demo account
  - Attach to chart
  - Verify indicators load
  - Verify statistics panel displays
  - Verify structure detection working
  - Check OnTick execution every tick

- [ ] Backtest all entry methods
  - Test on 1-month historical data
  - BOS Immediate method
  - BOS Retest method
  - CHoCH Reversal method
  - Combined Signals method
  - Review trade statistics

- [ ] Verify time filter logic
  - Test GMT conversion accuracy
  - Test session detection (London, NY, overlap)
  - Test news avoidance on NFP days
  - Test trading disabled outside sessions

- [ ] Paper trade (1-2 weeks)
  - Trade on live quotes with no money
  - Monitor for 10+ trades
  - Verify all systems:
    - Entry signals
    - Position management
    - Risk management
    - Daily limits
    - Alert system

**Output**: Production-ready, fully tested EA

---

### Phase 1️⃣4️⃣: Code Organization & Documentation 📚
**Objective**: Professional code structure and documentation
**Duration**: 1-2 days
**Dependencies**: Phases 1-13 ✅

#### Tasks:
- [ ] Modularize into include files:
  - `Enums.mqh` - All enumerations (500 lines)
  - `Structures.mqh` - All structures (300 lines)
  - `Globals.mqh` - Global arrays + variables (400 lines)
  - `TimeFilter.mqh` - Time-based functions (200 lines)
  - `StructureDetection.mqh` - Structure detection (400 lines)
  - `PatternDetection.mqh` - FVG + OB detection (300 lines)
  - `EntrySignals.mqh` - Entry signal logic (400 lines)
  - `TradeManagement.mqh` - Position management (300 lines)
  - `RiskManagement.mqh` - Daily limits (200 lines)
  - `Visualization.mqh` - Drawing functions (300 lines)
  - `UtilityFunctions.mqh` - Helper functions (200 lines)

- [ ] Add comprehensive inline documentation:
  - Function purpose, parameters, return values
  - Logic explanations
  - Important edge cases
  - Configuration notes

- [ ] Create User Manual:
  - Installation instructions
  - Parameter guide with examples
  - Trading session explanation
  - Screenshots of dashboard
  - Troubleshooting section

- [ ] Create Parameter Customization Guide:
  - Risk management settings
  - Entry method selection
  - Time filter setup
  - Visual customization
  - Alert configuration

- [ ] Version control strategy:
  - Clear commit messages
  - One feature per commit
  - Tag each stable version
  - Document breaking changes

**Output**: Professional, maintainable codebase with documentation

---

## 📊 Development Timeline Estimate

| Phase | Description | Duration | Cumulative |
|-------|-------------|----------|-----------|
| 1 | Foundation & Structure | 1-2 days | 1-2 |
| 2 | Time Filter System | 1-2 days | 2-4 |
| 3 | Market Structure Detection | 2-3 days | 4-7 |
| 4 | Pattern Detection | 2-3 days | 6-10 |
| 5 | Entry Signals | 2-3 days | 8-13 |
| 6 | Trade Setup & Execution | 2-3 days | 10-16 |
| 7 | Position Management | 1-2 days | 11-18 |
| 8 | Risk Management | 2-3 days | 13-21 |
| 9 | Event Handlers | 2-3 days | 15-24 |
| 10 | Display & Visualization | 1-2 days | 16-26 |
| 11 | Utility Functions | 1-2 days | 17-28 |
| 12 | Input Parameters | 1 day | 18-29 |
| 13 | Testing & Validation | 3-5 days | 21-34 |
| 14 | Documentation | 1-2 days | 22-36 |

**Total**: 22-36 days (realistic estimate with testing buffer)

---

## 🎯 Success Criteria

A successful implementation will have:

✅ **Functionality**
- All 50+ functions implemented and working
- Time filter system enforcing session constraints
- SMC pattern detection (BOS, CHoCH, FVG, OB)
- Multiple entry methods functional
- Position management with 3 protection strategies
- Daily risk limits enforced
- Statistics tracking + persistence

✅ **Robustness**
- Compiles without warnings
- Handles edge cases (no positions, invalid indicators, etc.)
- Survives 10+ consecutive trades
- Daily stats reset correctly
- Persists data across EA restarts

✅ **Professional Quality**
- Modular, readable code structure
- Comprehensive inline documentation
- User-friendly parameter interface
- Clear visual dashboard display
- Professional error handling

✅ **Testing**
- Passes unit tests on core functions
- Backtests show positive risk/reward
- Paper-trades successfully for 1-2 weeks
- Time filter logic verified on live market

---

## 🚀 Next Steps

1. **Start Phase 1**: Create include file structure + define enums/structures
2. **Commit regularly**: Small commits, clear messages
3. **Test incrementally**: Unit test as you go
4. **Document progress**: Keep this plan updated
5. **Push to branch**: `claude/organize-mq5-structure-01L8PBfDDQuz1xdZrYEop4xo`

---

**Created**: 2025-11-19
**Version**: 1.0 (Planning)
**Status**: Ready for Implementation ✅
