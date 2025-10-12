//+------------------------------------------------------------------+
//|                                                        EA.mq5    |
//|                                              Auto_Trade Strategy |
//|                      Trend+BoS_Trend+Break_Trend+PullBack+FiboZone|
//+------------------------------------------------------------------+
#property copyright "Auto_Trade"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>
#include "TradeLogic.mqh"
#include "RiskManagement.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input int StopLossPips = 50;           // Stop Loss in pips
input int TakeProfitPips = 100;        // Take Profit in pips

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set magic number for the EA
   trade.SetExpertMagicNumber(123456);
   
   Print("EA initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EA deinitialized");
}

//+------------------------------------------------------------------+
//| Check if there is an active position                              |
//+------------------------------------------------------------------+
bool HasActivePosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if(PositionGetInteger(POSITION_MAGIC) == trade.RequestMagicNumber())
            {
               return true;
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Step 4: Ensure no new trade is opened if one is already active
   if(HasActivePosition())
   {
      return;
   }
   
   // Step 1: Call the signal functions from TradeLogic.mqh
   bool buySignal = CheckBuySignal();
   bool sellSignal = CheckSellSignal();
   
   // Get current prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Step 2: If a buy or sell signal is true, call CalculateLotSize()
   if(buySignal)
   {
      double lotSize = CalculateLotSize(StopLossPips);
      
      // Step 3: Use CTrade class to open a new trade with calculated lot size, SL, and TP
      double sl = ask - (StopLossPips * point * 10);
      double tp = ask + (TakeProfitPips * point * 10);
      
      if(trade.Buy(lotSize, _Symbol, ask, sl, tp, "Buy Signal"))
      {
         Print("Buy order opened successfully. Lot size: ", lotSize);
      }
      else
      {
         Print("Failed to open buy order. Error: ", GetLastError());
      }
   }
   else if(sellSignal)
   {
      double lotSize = CalculateLotSize(StopLossPips);
      
      // Step 3: Use CTrade class to open a new trade with calculated lot size, SL, and TP
      double sl = bid + (StopLossPips * point * 10);
      double tp = bid - (TakeProfitPips * point * 10);
      
      if(trade.Sell(lotSize, _Symbol, bid, sl, tp, "Sell Signal"))
      {
         Print("Sell order opened successfully. Lot size: ", lotSize);
      }
      else
      {
         Print("Failed to open sell order. Error: ", GetLastError());
      }
   }
}
//+------------------------------------------------------------------+
