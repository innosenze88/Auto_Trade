# Copilot Instructions for Auto_Trade Repository

## Overview
The `Auto_Trade` repository implements an Expert Advisor (EA) for the MetaTrader 5 platform. The EA is designed to automate trading strategies based on trends, breakouts, pullbacks, and Fibonacci zones. The project is structured to ensure modularity and maintainability, with separate files for trade logic, risk management, and testing.

## Key Components

### 1. Core Files
- **`EA.mq5`**: The main entry point for the Expert Advisor. It initializes the EA, handles ticks, and manages trade execution.
- **`TradeLogic.mqh`**: Contains functions to generate buy and sell signals based on market conditions.
- **`RiskManagement.mqh`**: Implements risk management strategies, including lot size calculation.
- **`CheckMajorBreakout.mqh`**: Utility functions for detecting major market breakouts.

### 2. Testing Files
- **`SimpleSMCTester.mq5`**: A simplified tester for validating SMC patterns.
- **`SMC_ComponentTester.mq5`**: Tests individual components of the EA.
- **`TestSMC_DataLoader.mq5`**: Loads test data for SMC patterns from `TestData_SMC_Patterns.csv`.

### 3. Documentation
- **`README.md`**: Provides a high-level overview of the repository.
- **`SMC_EA_Installation_Guide.md`**: Step-by-step instructions for installing the EA.
- **`SMC_Testing_Guide.md`**: Guidelines for testing the EA.

## Developer Workflows

### 1. Building and Testing
- Open the `.mq5` files in the MetaEditor IDE.
- Compile the files to ensure there are no syntax errors.
- Use the MetaTrader 5 Strategy Tester to backtest the EA with historical data.

### 2. Debugging
- Use `Print()` statements to log variable values and execution flow.
- Check the `Experts` tab in MetaTrader 5 for runtime logs.

### 3. Adding New Features
- Add new signal functions to `TradeLogic.mqh`.
- Update `EA.mq5` to integrate the new signals.
- Write test cases in `SMC_ComponentTester.mq5` to validate the new functionality.

## Project-Specific Conventions

### 1. Code Structure
- Use `.mqh` files for reusable components.
- Keep the `OnTick()` function in `EA.mq5` concise by delegating logic to helper functions.

### 2. Naming Conventions
- Prefix input parameters with `input` (e.g., `input int StopLossPips`).
- Use descriptive names for functions and variables (e.g., `CalculateLotSize`, `CheckBuySignal`).

### 3. Error Handling
- Use `GetLastError()` to log errors when trade operations fail.
- Ensure all `PositionGet*` and `OrderSend*` calls are checked for success.

## Examples

### Signal Integration
To add a new signal:
1. Define the signal logic in `TradeLogic.mqh`:
   ```cpp
   bool CheckNewSignal()
   {
       // Signal logic here
       return true;
   }
   ```
2. Update `OnTick()` in `EA.mq5`:
   ```cpp
   bool newSignal = CheckNewSignal();
   if(newSignal)
   {
       // Execute trade
   }
   ```

### Risk Management
To modify lot size calculation:
1. Update `CalculateLotSize()` in `RiskManagement.mqh`.
2. Ensure the new logic adheres to the risk management rules.

## External Dependencies
- MetaTrader 5 platform.
- Historical data for backtesting.

## Notes
- Always test new features thoroughly using the Strategy Tester.
- Follow the project conventions to maintain code consistency.

---

Feel free to update this document as the project evolves.