//+------------------------------------------------------------------+
//|                                                        EA.mq5    |
//|                        Copyright 2024, Auto_Trade Project        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Auto_Trade Project"
#property link      ""
#property version   "1.00"
#property description "Modular Expert Advisor with Trade Logic and Risk Management"

//--- Include libraries
#include "TradeLogic.mqh"
#include "RiskManagement.mqh"

//--- Include MQL5 trade library
#include <Trade\Trade.mqh>

//--- Global variables
CTrade trade;
datetime lastBarTime = 0;

//--- EA Input Parameters
input int MagicNumber = 123456;        // Magic Number
input string EA_Comment = "Auto_Trade_EA"; // Trade Comment
input bool AllowBuy = true;            // Allow Buy Trades
input bool AllowSell = true;           // Allow Sell Trades
input int MaxOpenPositions = 1;        // Maximum Open Positions

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set trade parameters
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Print initialization message
   Print("EA Initialized Successfully");
   Print("Symbol: ", _Symbol);
   Print("Period: ", EnumToString(_Period));
   Print("Magic Number: ", MagicNumber);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if new bar has formed
   if(!IsNewBar())
      return;
   
   // Check for existing positions
   int openPositions = CountOpenPositions();
   
   if(openPositions >= MaxOpenPositions)
   {
      // Check if we should close existing positions
      CheckAndClosePositions();
      return;
   }
   
   // Get trade signal
   ENUM_SIGNAL signal = GetTradeSignal();
   
   // Process signals
   if(signal == SIGNAL_BUY && AllowBuy)
   {
      OpenBuyPosition();
   }
   else if(signal == SIGNAL_SELL && AllowSell)
   {
      OpenSellPosition();
   }
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                      |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Count open positions for this EA                                 |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            count++;
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Open buy position                                                 |
//+------------------------------------------------------------------+
void OpenBuyPosition()
{
   // Calculate stop loss and take profit
   double stopLoss = CalculateStopLoss(true);
   double takeProfit = CalculateTakeProfit(true);
   
   // Calculate stop loss in pips
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLossPips = (ask - stopLoss) / (point * 10);
   
   // Calculate lot size
   double lotSize = CalculateLotSize(stopLossPips);
   
   // Validate trade parameters
   if(!ValidateTradeParams(lotSize, stopLoss, takeProfit))
   {
      Print("Invalid trade parameters for BUY");
      return;
   }
   
   // Open buy position
   bool result = trade.Buy(lotSize, _Symbol, ask, stopLoss, takeProfit, EA_Comment);
   
   if(result)
   {
      Print("BUY Order Opened Successfully");
      Print("Lot Size: ", lotSize, " SL: ", stopLoss, " TP: ", takeProfit);
   }
   else
   {
      Print("Failed to open BUY order. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Open sell position                                                |
//+------------------------------------------------------------------+
void OpenSellPosition()
{
   // Calculate stop loss and take profit
   double stopLoss = CalculateStopLoss(false);
   double takeProfit = CalculateTakeProfit(false);
   
   // Calculate stop loss in pips
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLossPips = (stopLoss - bid) / (point * 10);
   
   // Calculate lot size
   double lotSize = CalculateLotSize(stopLossPips);
   
   // Validate trade parameters
   if(!ValidateTradeParams(lotSize, stopLoss, takeProfit))
   {
      Print("Invalid trade parameters for SELL");
      return;
   }
   
   // Open sell position
   bool result = trade.Sell(lotSize, _Symbol, bid, stopLoss, takeProfit, EA_Comment);
   
   if(result)
   {
      Print("SELL Order Opened Successfully");
      Print("Lot Size: ", lotSize, " SL: ", stopLoss, " TP: ", takeProfit);
   }
   else
   {
      Print("Failed to open SELL order. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Check and close positions if needed                              |
//+------------------------------------------------------------------+
void CheckAndClosePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            if(ShouldClosePosition(ticket))
            {
               if(trade.PositionClose(ticket))
               {
                  Print("Position closed: ", ticket);
               }
               else
               {
                  Print("Failed to close position: ", ticket, " Error: ", GetLastError());
               }
            }
         }
      }
   }
}
