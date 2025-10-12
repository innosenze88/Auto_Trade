//+------------------------------------------------------------------+
//|                                              RiskManagement.mqh |
//|                                              Auto_Trade Strategy |
//|                                         Risk Management Module   |
//+------------------------------------------------------------------+
#property copyright "Auto_Trade"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Input Parameters for Risk Management                              |
//+------------------------------------------------------------------+
input double RiskPercent = 2.0;        // Risk per trade in percentage
input double DefaultLotSize = 0.01;    // Default lot size

//+------------------------------------------------------------------+
//| Calculate Lot Size based on risk percentage                       |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossPips)
{
   double lotSize = DefaultLotSize;
   
   // Get account balance
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Calculate risk amount in account currency
   double riskAmount = accountBalance * (RiskPercent / 100.0);
   
   // Get symbol information
   string symbol = _Symbol;
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Calculate lot size based on risk
   if(stopLossPips > 0 && point > 0)
   {
      double pipValue = tickValue * (point / tickSize);
      lotSize = riskAmount / (stopLossPips * pipValue);
      
      // Normalize lot size
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
   }
   
   return lotSize;
}
//+------------------------------------------------------------------+
