# Auto_Trade

A modular MQL5 Expert Advisor (EA) project for automated trading.

## Project Description

Trend+BoS_Trend+Break_Trend+PullBack+FiboZone

This EA implements a modular architecture with separate components for trade logic and risk management, making it easy to maintain, test, and extend.

## Project Structure

```
Auto_Trade/
├── EA.mq5                   # Main Expert Advisor file (core logic)
├── TradeLogic.mqh           # Trade signal library (entry/exit signals)
├── RiskManagement.mqh       # Risk management library (lot sizing)
├── README.md                # This file
└── .gitignore              # Git ignore file for MQL5 projects
```

## File Descriptions

### EA.mq5 (Main Expert Advisor)
The core EA file that orchestrates the trading strategy. It:
- Initializes the EA and sets up trading parameters
- Monitors market conditions on each tick
- Calls trade signal functions from TradeLogic.mqh
- Uses risk management functions from RiskManagement.mqh
- Opens and closes positions based on signals
- Manages existing positions

**Key Features:**
- Configurable magic number and trade comment
- Controls for enabling/disabling buy/sell trades
- Maximum open positions limit
- New bar detection for signal generation

### TradeLogic.mqh (Trade Signal Library)
Handles all trading signal generation and entry/exit logic. Functions include:
- `GetTradeSignal()` - Returns buy/sell/none signal
- `CheckBuySignal()` - Checks for bullish entry conditions
- `CheckSellSignal()` - Checks for bearish entry conditions
- `CalculateStopLoss()` - Calculates stop loss using ATR
- `CalculateTakeProfit()` - Calculates take profit using ATR
- `ShouldClosePosition()` - Determines if a position should be closed

**Strategy:**
- Uses Moving Average crossover (Fast EMA vs Slow EMA)
- RSI filter to avoid overbought/oversold conditions
- ATR-based dynamic stop loss and take profit

### RiskManagement.mqh (Risk Management Library)
Manages position sizing and risk calculations. Functions include:
- `CalculateLotSize()` - Calculates lot size based on risk percentage
- `CalculateRiskRewardRatio()` - Computes risk-reward ratio
- `ValidateTradeParams()` - Validates trade parameters before execution

**Risk Parameters:**
- Risk per trade as percentage of account balance
- Minimum and maximum lot size limits
- Lot size normalization based on symbol specifications

## Configuration

### EA Parameters (EA.mq5)
- **MagicNumber**: Unique identifier for EA's trades (default: 123456)
- **EA_Comment**: Comment added to all trades
- **AllowBuy**: Enable/disable buy trades
- **AllowSell**: Enable/disable sell trades
- **MaxOpenPositions**: Maximum concurrent positions

### Trade Logic Parameters (TradeLogic.mqh)
- **FastMA_Period**: Fast Moving Average period (default: 10)
- **SlowMA_Period**: Slow Moving Average period (default: 30)
- **RSI_Period**: RSI indicator period (default: 14)
- **RSI_Oversold**: RSI oversold level (default: 30)
- **RSI_Overbought**: RSI overbought level (default: 70)

### Risk Management Parameters (RiskManagement.mqh)
- **RiskPercent**: Risk per trade as % of balance (default: 1.0%)
- **MaxLotSize**: Maximum lot size allowed (default: 10.0)
- **MinLotSize**: Minimum lot size allowed (default: 0.01)

## Installation

1. Copy all files to your MetaTrader 5 data folder:
   - `EA.mq5` → `MQL5/Experts/`
   - `TradeLogic.mqh` → `MQL5/Experts/` or `MQL5/Include/`
   - `RiskManagement.mqh` → `MQL5/Experts/` or `MQL5/Include/`

2. Open MetaEditor (F4 in MetaTrader 5)

3. Compile EA.mq5 (F7 or click Compile button)

4. The compiled EA will appear in the Navigator panel under Expert Advisors

## Usage

1. Drag the EA onto a chart in MetaTrader 5
2. Configure parameters in the EA properties dialog
3. Enable automated trading (Ctrl+E or click AutoTrading button)
4. Monitor the Experts tab for trade execution logs

## Testing

Use the MetaTrader 5 Strategy Tester to backtest the EA:
1. Open Strategy Tester (Ctrl+R)
2. Select the EA
3. Choose symbol, timeframe, and date range
4. Configure EA parameters
5. Run the test

## Customization

The modular structure allows easy customization:

- **Modify Trade Logic**: Edit `TradeLogic.mqh` to implement different entry/exit strategies
- **Adjust Risk Management**: Edit `RiskManagement.mqh` to change position sizing algorithms
- **Extend Functionality**: Add new .mqh library files and include them in EA.mq5

## Important Notes

- Always test on a demo account first
- Backtest thoroughly before live trading
- Monitor the EA regularly
- Adjust parameters based on market conditions
- Past performance does not guarantee future results

## License

Copyright 2024, Auto_Trade Project

## Support

For issues, questions, or contributions, please use the GitHub repository.

## Disclaimer

Trading financial instruments carries a high level of risk. This EA is provided for educational purposes. Use at your own risk.
