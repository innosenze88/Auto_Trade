# Auto_Trade EA Implementation

## Overview
This Expert Advisor implements a trading strategy based on Trend+BoS_Trend+Break_Trend+PullBack+FiboZone analysis.

## Files

### EA.mq5
The main Expert Advisor file that contains:
- **OnInit()**: Initializes the EA and sets up the CTrade object with a magic number
- **OnTick()**: Main trading logic that executes on every tick:
  1. Checks if there's already an active position (prevents multiple simultaneous trades)
  2. Calls signal functions from TradeLogic.mqh
  3. If a signal is detected, calculates the appropriate lot size using RiskManagement.mqh
  4. Opens a trade using the CTrade class with calculated lot size, SL, and TP
- **HasActivePosition()**: Helper function to check if there's an active position for this EA

### TradeLogic.mqh
Contains the trading signal functions:
- **CheckBuySignal()**: Returns true when conditions for a buy are met (placeholder implementation)
- **CheckSellSignal()**: Returns true when conditions for a sell are met (placeholder implementation)

### RiskManagement.mqh
Contains risk management functionality:
- **CalculateLotSize()**: Calculates the appropriate lot size based on:
  - Account balance
  - Risk percentage (default: 2%)
  - Stop loss in pips
  - Symbol specifications (min/max lot, lot step)

## Input Parameters

### EA.mq5
- `StopLossPips`: Stop Loss in pips (default: 50)
- `TakeProfitPips`: Take Profit in pips (default: 100)

### RiskManagement.mqh
- `RiskPercent`: Risk per trade as percentage of account balance (default: 2.0%)
- `DefaultLotSize`: Fallback lot size if calculation fails (default: 0.01)

## Installation
1. Copy all files to your MetaTrader 5 `MQL5/Experts` directory
2. Compile EA.mq5 in MetaEditor
3. Attach the EA to a chart in MetaTrader 5

## Trading Logic Flow
1. OnTick() is called on every price update
2. Check if there's already an active position - if yes, exit
3. Check for buy or sell signals
4. If signal detected:
   - Calculate lot size based on risk management rules
   - Calculate SL and TP levels
   - Open trade using CTrade class
   - Log the result

## Notes
- The signal functions in TradeLogic.mqh are placeholders and need to be implemented with the actual strategy logic
- The EA uses a magic number (123456) to identify its own positions
- Only one position per symbol is allowed at a time
- Risk is calculated as a percentage of account balance
