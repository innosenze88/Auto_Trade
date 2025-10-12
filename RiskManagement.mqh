//+------------------------------------------------------------------+
//|                                             RiskManagement.mqh   |
//|                        Copyright 2024, Auto_Trade Project        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Auto_Trade Project"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Risk Management Library                                          |
//| Handles lot sizing and risk calculations                         |
//+------------------------------------------------------------------+

//--- Input parameters for risk management
input double RiskPercent = 1.0;        // Risk per trade (% of account balance)
input double MaxLotSize = 10.0;        // Maximum lot size
input double MinLotSize = 0.01;        // Minimum lot size

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossPips)
{
   // Get account balance
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Calculate risk amount in account currency
   double riskAmount = accountBalance * (RiskPercent / 100.0);
   
   // Get point value for the current symbol
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculate pip value
   double pipValue = (tickValue / tickSize) * point * 10;
   
   // Calculate lot size
   double lotSize = 0.0;
   if(stopLossPips > 0 && pipValue > 0)
   {
      lotSize = riskAmount / (stopLossPips * pipValue);
   }
   
   // Normalize lot size
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Apply min/max limits
   lotSize = MathMax(lotSize, MinLotSize);
   lotSize = MathMin(lotSize, MaxLotSize);
   
   // Check symbol limits
   double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lotSize = MathMax(lotSize, minVolume);
   lotSize = MathMin(lotSize, maxVolume);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate risk-reward ratio                                      |
//+------------------------------------------------------------------+
double CalculateRiskRewardRatio(double entryPrice, double stopLoss, double takeProfit, bool isBuy)
{
   double risk = 0.0;
   double reward = 0.0;
   
   if(isBuy)
   {
      risk = entryPrice - stopLoss;
      reward = takeProfit - entryPrice;
   }
   else
   {
      risk = stopLoss - entryPrice;
      reward = entryPrice - takeProfit;
   }
   
   if(risk > 0)
      return reward / risk;
   else
      return 0.0;
}

//+------------------------------------------------------------------+
//| Validate trade parameters                                        |
//+------------------------------------------------------------------+
bool ValidateTradeParams(double lotSize, double stopLoss, double takeProfit)
{
   // Check lot size
   if(lotSize < MinLotSize || lotSize > MaxLotSize)
   {
      Print("Invalid lot size: ", lotSize);
      return false;
   }
   
   // Check stop loss and take profit
   if(stopLoss <= 0 || takeProfit <= 0)
   {
      Print("Invalid SL/TP values");
      return false;
   }
   
   return true;
}
