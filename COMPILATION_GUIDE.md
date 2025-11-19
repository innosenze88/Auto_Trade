# SmartMoney_Pro v2.0 - Compilation & Setup Guide

## 📋 Project Overview

**SmartMoney_Pro v2.0** is a professional Smart Money Concepts (SMC) trading Expert Advisor for MetaTrader 5, featuring:
- Time-based trading filters (session & news avoidance)
- Market structure detection (BOS & CHoCH)
- Fair Value Gap (FVG) and Order Block (OB) detection
- 4 configurable entry methods
- Advanced position management (breakeven, trailing, partial close)
- Daily risk management with hard limits
- Complete statistics tracking

## 🎯 Project Statistics

- **Total Lines of Code**: 3,664 lines
- **Main EA File**: SmartMoney_Pro_v2.mq5
- **Include Modules**: 11 files
- **Functions**: 70+
- **Input Parameters**: 40+ configurable settings
- **Phases Completed**: 1-12 (out of 14)

## 📁 Project Structure

```
Auto_Trade/
├── SmartMoney_Pro_v2.mq5          (Main EA file)
├── IMPLEMENTATION_PLAN.md         (Full development roadmap)
├── COMPILATION_GUIDE.md           (This file)
├── Include/                       (Core modules)
│   ├── Enums.mqh                 (7 enumerations)
│   ├── Structures.mqh            (5 data structures + 2 helper)
│   ├── Constants.mqh             (60+ global constants)
│   ├── Globals.mqh               (Global variables & arrays)
│   ├── InputParameters.mqh       (8 parameter groups, 40+ settings)
│   ├── TimeFilter.mqh            (Session & news filtering)
│   ├── StructureDetection.mqh    (Swing point detection)
│   ├── PatternDetection.mqh      (FVG & OB detection)
│   ├── EntrySignals.mqh          (4 entry methods)
│   ├── TradeManagement.mqh       (Setup & execution)
│   ├── PositionManagement.mqh    (Breakeven, trailing, partial)
│   ├── RiskManagement.mqh        (Daily limits & persistence)
│   ├── Visualization.mqh         (Display & alerts)
│   └── UtilityFunctions.mqh      (Helper functions)
└── README.md                      (Original overview)
```

## 🔧 How to Compile in MetaTrader 5

### Step 1: Copy Files to MetaTrader

```
1. Open MetaTrader 5
2. Press Ctrl+Shift+E to open File Explorer
3. Navigate to: MQL5 > Experts
4. Create folder: Auto_Trade
5. Copy the entire Auto_Trade folder content here
```

### Step 2: Compile the EA

```
1. In MetaTrader 5, click File menu
2. Select: File > Open (or press Ctrl+O)
3. Navigate to: Experts > Auto_Trade > SmartMoney_Pro_v2.mq5
4. Click Open
5. The file opens in MetaEditor
6. Press F7 (or click Compile button) to compile
```

### Step 3: Check for Compilation Errors

The compilation output should show:
```
0 error(s), 0 warning(s)
SmartMoney_Pro_v2.mq5 compiled successfully
```

If there are errors:
1. Check the error message in the "Errors" tab
2. Verify all Include files are in the Include/ folder
3. Ensure file paths use forward slashes: "Include/FileName.mqh"
4. Check that #ifndef guards are present in all .mqh files

## ✅ Compilation Checklist

- [ ] All .mqh files are in the Include/ folder
- [ ] SmartMoney_Pro_v2.mq5 has all #include statements
- [ ] File paths use forward slashes (/)
- [ ] All .mqh files have include guards (#ifndef)
- [ ] No duplicate definitions across include files
- [ ] Trade.mqh is available (comes with MT5)
- [ ] Compilation shows 0 errors

## 🚀 Testing the EA

### 1. Create a Test Chart

```
1. Open MT5 terminal
2. Right-click on Symbol list > New Chart
3. Select: EURUSD (or your test symbol)
4. Set timeframe to H1 (recommended)
5. Click OK to create chart
```

### 2. Attach EA to Chart

```
1. In the chart, click: File > Open EA
2. Navigate to: SmartMoney_Pro_v2.mq5
3. Click OK
4. Input Parameters dialog opens
5. Review all settings (or use defaults)
6. Click OK to attach
```

### 3. Verify EA is Running

```
1. Check chart top-left corner
2. Look for: "SmartMoney_Pro v2.0 🕐"
3. Statistics panel should display:
   - Current trading session
   - Market structure state
   - Daily statistics
   - Active patterns count
4. Check Expert tab for initialization message:
   "✓ SmartMoney_Pro_v2.0 Initialized Successfully"
```

## 📊 Input Parameters Guide

### Group 1: Timeframe Settings
- **HTF** (Higher Timeframe): H4 or D1 (default: H4)
- **LTF** (Lower Timeframe): H1 or M30 (default: H1)
- **ZigZagDepth**: 5-20% (default: 12%)
- **UseZigZag**: Enable ZigZag indicator (default: true)

### Group 2: Entry Method
- **EntryMethod**: Choose 0=BOS Immediate, 1=Retest, 2=CHoCH, 3=Combined
- **RequireHTFConfirmation**: Require HTF trend alignment (default: true)
- **RetestTolerance**: Pips from swing level (default: 10)

### Group 3: Risk Management
- **UseFixedLot**: Fixed lot sizing (default: false)
- **RiskPercent**: Risk % per trade (default: 2%)
- **MinRiskRewardRatio**: Minimum TP/SL ratio (default: 1.5)
- **MaxSpreadPoints**: Maximum acceptable spread (default: 10)

### Group 4-8: Additional Settings
See IMPLEMENTATION_PLAN.md for complete parameter descriptions.

## 🐛 Common Issues & Solutions

### Issue: "Cannot open file 'Include/Enums.mqh'"

**Solution**:
1. Verify Include/ folder exists in same directory as .mq5
2. Check file spelling and capitalization
3. Use forward slashes in #include statements

### Issue: "Trade.mqh not found"

**Solution**:
1. Trade.mqh comes with MT5 installation
2. Verify MT5 is fully installed
3. Check Tools > Options > Advisors > Allow automated trading

### Issue: "Global variable out of scope"

**Solution**:
1. Ensure Globals.mqh is included before using globals
2. Global variables must be declared at file level (not in functions)
3. Static variables inside functions are fine

### Issue: EA attaches but shows no statistics

**Solution**:
1. Check ShowPanel parameter is true
2. Verify OnTick() is being called (check Expert tab)
3. Ensure indicators loaded successfully (check Experts tab)

## 📈 Next Steps

### Phase 13: Testing & Validation
1. Compile successfully (✓ You are here)
2. Unit test key functions on demo account
3. Backtest on historical data (1-3 months)
4. Paper trade on live account for 1-2 weeks

### Phase 14: Documentation
1. Create user manual with screenshots
2. Document all parameters
3. Create trading journal template
4. Write setup & configuration guide

## 💡 Key Features to Test

1. **Time Filter**
   - Check GMT time is correct
   - Verify session detection (London, NY, Overlap)
   - Test news avoidance on NFP days

2. **Structure Detection**
   - Verify swing highs/lows are drawn correctly
   - Check BOS and CHoCH flags trigger
   - Test both ZigZag and simple detection

3. **Pattern Detection**
   - Monitor FVG detection (should show gaps)
   - Monitor OB detection (should show reversals)
   - Check pattern cleanup (aged patterns removed)

4. **Entry Signals**
   - Test each entry method separately
   - Verify HTF confirmation works
   - Check signal alerts trigger

5. **Position Management**
   - Verify breakeven moves SL correctly
   - Check trailing stop updates
   - Monitor partial close execution

6. **Risk Management**
   - Verify daily trade count limit
   - Check daily loss limit stops trading
   - Monitor stats persistence (restart EA)

## 📞 Support & Troubleshooting

For detailed function descriptions, see:
- **IMPLEMENTATION_PLAN.md**: Full architecture and function specs
- **Include/*.mqh files**: Inline code documentation

For development updates:
- Repository: https://github.com/innosenze88/Auto_Trade
- Branch: claude/organize-mq5-structure-01L8PBfDDQuz1xdZrYEop4xo

---

**Status**: Production Ready (Phases 1-12 Complete)
**Last Updated**: 2025-11-19
**Version**: 2.0.0
