//+------------------------------------------------------------------+
//|                                                   TradeLogic.mqh |
//|                        Copyright 2024, Auto_Trade Project        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Auto_Trade Project"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Trade Logic Library                                              |
//| Handles entry signals and trade decisions                        |
//+------------------------------------------------------------------+

//--- Input parameters for trade logic
input int FastMA_Period = 10;          // Fast Moving Average Period
input int SlowMA_Period = 30;          // Slow Moving Average Period
input int RSI_Period = 14;             // RSI Period
input double RSI_Oversold = 30.0;      // RSI Oversold Level
input double RSI_Overbought = 70.0;    // RSI Overbought Level

//--- Signal enumeration
enum ENUM_SIGNAL
{
   SIGNAL_NONE = 0,    // No signal
   SIGNAL_BUY = 1,     // Buy signal
   SIGNAL_SELL = -1    // Sell signal
};

//+------------------------------------------------------------------+
//| Check for buy signal                                             |
//+------------------------------------------------------------------+
bool CheckBuySignal()
{
   // Get Moving Averages
   double fastMA = iMA(_Symbol, PERIOD_CURRENT, FastMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   double slowMA = iMA(_Symbol, PERIOD_CURRENT, SlowMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   // Get RSI
   double rsi = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   
   // Buy signal: Fast MA crosses above Slow MA AND RSI is not overbought
   if(fastMA > slowMA && rsi < RSI_Overbought)
   {
      // Additional confirmation: check previous candle
      double prevFastMA = iMA(_Symbol, PERIOD_CURRENT, FastMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      double prevSlowMA = iMA(_Symbol, PERIOD_CURRENT, SlowMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      
      // Ensure it's a fresh cross
      if(prevFastMA <= prevSlowMA)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for sell signal                                            |
//+------------------------------------------------------------------+
bool CheckSellSignal()
{
   // Get Moving Averages
   double fastMA = iMA(_Symbol, PERIOD_CURRENT, FastMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   double slowMA = iMA(_Symbol, PERIOD_CURRENT, SlowMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   // Get RSI
   double rsi = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   
   // Sell signal: Fast MA crosses below Slow MA AND RSI is not oversold
   if(fastMA < slowMA && rsi > RSI_Oversold)
   {
      // Additional confirmation: check previous candle
      double prevFastMA = iMA(_Symbol, PERIOD_CURRENT, FastMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      double prevSlowMA = iMA(_Symbol, PERIOD_CURRENT, SlowMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      
      // Ensure it's a fresh cross
      if(prevFastMA >= prevSlowMA)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get trade signal                                                 |
//+------------------------------------------------------------------+
ENUM_SIGNAL GetTradeSignal()
{
   if(CheckBuySignal())
      return SIGNAL_BUY;
   else if(CheckSellSignal())
      return SIGNAL_SELL;
   else
      return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Calculate stop loss level                                        |
//+------------------------------------------------------------------+
double CalculateStopLoss(bool isBuy, int atrPeriod = 14, double atrMultiplier = 2.0)
{
   double atr = iATR(_Symbol, PERIOD_CURRENT, atrPeriod);
   double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double stopLoss = 0.0;
   if(isBuy)
      stopLoss = currentPrice - (atr * atrMultiplier);
   else
      stopLoss = currentPrice + (atr * atrMultiplier);
   
   return NormalizeDouble(stopLoss, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate take profit level                                      |
//+------------------------------------------------------------------+
double CalculateTakeProfit(bool isBuy, int atrPeriod = 14, double atrMultiplier = 3.0)
{
   double atr = iATR(_Symbol, PERIOD_CURRENT, atrPeriod);
   double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double takeProfit = 0.0;
   if(isBuy)
      takeProfit = currentPrice + (atr * atrMultiplier);
   else
      takeProfit = currentPrice - (atr * atrMultiplier);
   
   return NormalizeDouble(takeProfit, _Digits);
}

//+------------------------------------------------------------------+
//| Check if we should close position                                |
//+------------------------------------------------------------------+
bool ShouldClosePosition(ulong ticket)
{
   // Select the position
   if(!PositionSelectByTicket(ticket))
      return false;
   
   // Get position details
   long posType = PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Example: Close on opposite signal
   ENUM_SIGNAL signal = GetTradeSignal();
   
   if(posType == POSITION_TYPE_BUY && signal == SIGNAL_SELL)
      return true;
   if(posType == POSITION_TYPE_SELL && signal == SIGNAL_BUY)
      return true;
   
   return false;
}
