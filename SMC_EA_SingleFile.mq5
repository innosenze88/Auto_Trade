// SMC_EA_SingleFile.mq5
#include <Trade/Trade.mqh>
// #include <stdlib.mqh>
// #include <Math/Stat/Math.mqh> // For future RSI/MACD/ATR (F2.5)

// A single-file MT5 Expert Advisor implementing SMC workflow:
// - DetectMarketStructureShift (BOS/CHoCH)
// - IdentifyOrderBlock (OB)
// - FindFairValueGap (FVG)
// - AnalyzeSMC to summarize trend bias and pending order plan
// - Trading modes: SignalOnly, LocalAuto, WebhookOnly, Both

#property copyright "SMC EA"
#property version   "1.1" // Updated version after expansion

CTrade trade;

// ====== Enums and Data Structures ======
enum SMCShift
{
   No_Shift = 0,
   BOS_Bullish,
   BOS_Bearish,
   CHoCH_Bullish,
   CHoCH_Bearish
};

enum TrendBias
{
   Trend_Neutral = 0,
   Trend_Up      = 1,
   Trend_Down    = -1
};

enum TradingMode
{
   Mode_SignalOnly = 0,  // Show signals/zones only
   Mode_LocalAuto  = 1,  // Place pending orders locally (no webhook)
   Mode_WebhookOnly= 2,  // Send webhook only (no local orders)
   Mode_Both       = 3   // Send webhook and place local orders
};

struct OrderBlock
{
   bool   found;
   bool   bullish;
   int    index;       // bar index of OB
   double start;       // OB boundary (for bullish: high of the OB candle)
   double end;         // OB boundary (for bullish: low of the OB candle)
};

struct FVG
{
   bool   found;
   int    index;       // index of the 3rd candle in 1-2-3 pattern
   double high;        // upper bound of FVG zone
   double low;         // lower bound of FVG zone
};

struct PendingPlan
{
   bool   valid;
   bool   buy;     // true = BuyLimit, false = SellLimit
   double entry;
   double sl;
   double tp;
};

struct SMCResult
{
   TrendBias  trendBias;
   SMCShift   shift;
   double     bosLevel;
   int        brokenIndex;
   OrderBlock ob;
   FVG        fvg;
   PendingPlan plan;
   bool       rsiDivergence; // **F3.1: RSI Divergence Confirmation**
   bool       paConfirmation; // **F3.2: Price Action Confirmation**
};

// ====== Inputs ======
input string          InpSymbol = "EURUSD";
input ENUM_TIMEFRAMES InpTF = PERIOD_M15;
input int             InpLookback = 300;
input double          InpMinDisplacementPoints = 100; // candle body threshold (points) for displacement
input double          InpRiskPercent = 1.0;           // % of balance per trade
input double          InpRR = 2.0;                    // Risk:Reward
input int             InpSLBufferPoints = 20;         // SL buffer beyond OB (points)
input bool            InpUseFVG = true;               // Draw FVG zone
input string          InpOrderTag = "SMC_EA";
input TradingMode     InpTradingMode = Mode_LocalAuto; // Default: local trading without webhook

// HTF Analysis settings
input ENUM_TIMEFRAMES InpHTF = PERIOD_H4; // **F1.1: HTF for Bias**

// Export/Integration options
input bool            InpExportGlobals = true;         // Export values to global variables
input bool            InpExportWebhook = false;        // Send webhook (overridden by mode)
input string          InpWebhookUrl = "";             // Tools > Options > Expert Advisors must allow URL
input long            InpMagicNumber = 880015;         // Magic number for identification
input int             InpDeviationPoints = 10;         // Price deviation (points) used in requests
input int             InpMaxSpreadPoints = 0;          // 0=disabled; block placing orders if spread > this
input bool            InpDiagnostics = true;           // Print diagnostic logs in Experts tab
input bool            InpSelfTest = false;             // Run a one-time analysis on init for diagnostics

// Breakeven and partial close settings
input double InpBreakevenPips = 10.0; // **F5.1: B/E trigger (in pips)**
input double InpPartialClosePercent = 50.0; // **F5.2: Partial close % at TP1**

// Logging settings
input bool InpEnableLogging = true; // **F6.1: Trade Journal Logging**

// ====== Globals ======
datetime g_lastBarTime = 0;
int g_htfBias = Trend_Neutral;
double g_htfPivot = 0.0;
double g_totalProfitPips = 0.0;
double g_totalLossPips = 0.0;
int g_winCount = 0;
int g_lossCount = 0;
int g_hRSI, g_hMACD, g_hATR;

// ====== Utility helpers ======
bool IsBull(MqlRates &r) { return r.close > r.open; }
bool IsBear(MqlRates &r) { return r.close < r.open; }

// Find a recent swing high index prior to 'fromIndex' (series array assumed)
int FindSwingHigh(MqlRates &rates[], int bars, int fromIndex, int left=3, int right=3)
{
   for(int i=fromIndex - right; i>=left; --i)
   {
      bool ok = true;
      for(int l=1; l<=left; ++l)  { if(rates[i].high <= rates[i-l].high) { ok=false; break; } }
      if(!ok) continue;
      for(int r=1; r<=right; ++r) { if(rates[i].high <= rates[i+r].high) { ok=false; break; } }
      if(ok) return i;
   }
   return -1;
}

// Find a recent swing low index prior to 'fromIndex' (series array assumed)
int FindSwingLow(MqlRates &rates[], int bars, int fromIndex, int left=3, int right=3)
{
   for(int i=fromIndex - right; i>=left; --i)
   {
      bool ok = true;
      for(int l=1; l<=left; ++l)  { if(rates[i].low >= rates[i-l].low) { ok=false; break; } }
      if(!ok) continue;
      for(int r=1; r<=right; ++r) { if(rates[i].low >= rates[i+r].low) { ok=false; break; } }
      if(ok) return i;
   }
   return -1;
}

void FindTwoRecentSwings(MqlRates &rates[], int bars, int fromIndex, int &hi1, int &hi2, int &lo1, int &lo2)
{
   hi1 = FindSwingHigh(rates, bars, fromIndex);
   lo1 = FindSwingLow(rates, bars, fromIndex);
   hi2 = (hi1!=-1) ? FindSwingHigh(rates, bars, hi1) : -1;
   lo2 = (lo1!=-1) ? FindSwingLow(rates, bars, lo1) : -1;
}

int DetectTrendFromSwings(MqlRates &rates[], int hi1, int hi2, int lo1, int lo2)
{
   // return: 1 up, -1 down, 0 unknown
   if(hi1!=-1 && hi2!=-1 && lo1!=-1 && lo2!=-1)
   {
      bool highsUp = rates[hi1].high > rates[hi2].high;
      bool lowsUp  = rates[lo1].low  > rates[lo2].low;
      bool highsDn = rates[hi1].high < rates[hi2].high;
      bool lowsDn  = rates[lo1].low  < rates[lo2].low;

      if(highsUp && lowsUp) return 1;
      if(highsDn && lowsDn) return -1;
   }
   return 0;
}

// ====== Core 1: DetectMarketStructureShift ======
SMCShift DetectMarketStructureShift(MqlRates &rates[], int bars, int lookback, double &bosLevel, int &brokenIndex)
{
   if(bars < 100) { bosLevel=0; brokenIndex=-1; return No_Shift; }

   int fromIndex = (int)MathMax(10, (double)MathMin(bars-5, lookback));
   int hi1, hi2, lo1, lo2;
   FindTwoRecentSwings(rates, bars, fromIndex, hi1, hi2, lo1, lo2);

   int trend = DetectTrendFromSwings(rates, hi1, hi2, lo1, lo2);
   double c1 = rates[1].close; // last closed bar

   // Break High?
   if(hi1!=-1 && c1 > rates[hi1].high)
   {
      bosLevel   = rates[hi1].high;
      brokenIndex= hi1;
      if(trend >= 0) return BOS_Bullish; // continuation or neutral
      return CHoCH_Bullish;               // trend change
   }

   // Break Low?
   if(lo1!=-1 && c1 < rates[lo1].low)
   {
      bosLevel   = rates[lo1].low;
      brokenIndex= lo1;
      if(trend <= 0) return BOS_Bearish;
      return CHoCH_Bearish;
   }

   bosLevel = 0;
   brokenIndex = -1;
   return No_Shift;
}

// ====== Core 2: IdentifyOrderBlock ======
OrderBlock IdentifyOrderBlock(MqlRates &rates[], int bars, int breakIndex, bool bullish, double minDisplacementPoints, double point)
{
   OrderBlock ob; ob.found=false; ob.bullish=bullish; ob.index=-1; ob.start=0; ob.end=0;
   if(breakIndex < 5) return ob;

   for(int i=breakIndex-3; i>=MathMax(2, breakIndex-50); --i)
   {
      double bodyNext = MathAbs(rates[i+1].close - rates[i+1].open)/point;
      if(bodyNext < minDisplacementPoints) continue;

      if(bullish)
      {
         if(IsBear(rates[i]) && IsBull(rates[i+1]))
         {
            ob.found = true;
            ob.index = i;
            ob.start = rates[i].high; // top of OB zone
            ob.end   = rates[i].low;  // bottom of OB zone
            return ob;
         }
      }
      else
      {
         if(IsBull(rates[i]) && IsBear(rates[i+1]))
         {
            ob.found = true;
            ob.index = i;
            ob.start = rates[i].low;  // bottom of OB zone (sell)
            ob.end   = rates[i].high; // top of OB zone (sell)
            return ob;
         }
      }
   }
   return ob;
}

// ====== Core 3: FindFairValueGap ======
FVG FindFairValueGap(MqlRates &rates[], int bars, int displacementIndex)
{
   FVG f; f.found=false; f.index=-1; f.high=0; f.low=0;
   int i3 = displacementIndex; // use displacement bar as #3
   int i1 = i3-2, i2 = i3-1;
   if(i1 < 0 || i2 < 0 || i3 < 0) return f;

   // Bullish FVG: Low of #3 > High of #1
   if(rates[i3].low > rates[i1].high)
   {
      f.found = true;
      f.index = i3;
      f.low   = rates[i1].high;
      f.high  = rates[i3].low;
      return f;
   }

   // Bearish FVG: High of #3 < Low of #1
   if(rates[i3].high < rates[i1].low)
   {
      f.found = true;
      f.index = i3;
      f.low   = rates[i3].high;
      f.high  = rates[i1].low;
      return f;
   }

   return f;
}

// ====== String helpers ======
string ShiftToString(SMCShift s)
{
   if(s==BOS_Bullish)   return "BOS_Bullish";
   if(s==BOS_Bearish)   return "BOS_Bearish";
   if(s==CHoCH_Bullish) return "CHoCH_Bullish";
   if(s==CHoCH_Bearish) return "CHoCH_Bearish";
   return "No_Shift";
}

string TrendToString(TrendBias t)
{
   if(t==Trend_Up)   return "Up";
   if(t==Trend_Down) return "Down";
   return "Neutral";
}

string SMCResultToJson(const SMCResult &r, const string symbol, ENUM_TIMEFRAMES tf)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   string json;
   json += "{";
   json += "\"symbol\":\""+symbol+"\",";
   json += "\"timeframe\":"+IntegerToString((int)tf)+",";
   json += "\"trendBias\":\""+TrendToString(r.trendBias)+"\",";
   json += "\"shift\":\""+ShiftToString(r.shift)+"\",";
   json += "\"bosLevel\":"+DoubleToString(r.bosLevel, digits)+",";
   json += "\"ob\":{";
   json += "\"found\":"+(r.ob.found?"true":"false")+",";
   json += "\"type\":\""+(r.ob.bullish?"Bullish":"Bearish")+"\",";
   json += "\"start\":"+DoubleToString(r.ob.start,digits)+",";
   json += "\"end\":"+DoubleToString(r.ob.end,digits);
   json += "},";
   json += "\"fvg\":{";
   json += "\"found\":"+(r.fvg.found?"true":"false")+",";
   json += "\"high\":"+DoubleToString(r.fvg.high,digits)+",";
   json += "\"low\":"+DoubleToString(r.fvg.low,digits);
   json += "},";
   json += "\"pending\":{";
   json += "\"valid\":"+(r.plan.valid?"true":"false")+",";
   json += "\"side\":\""+(r.plan.buy?"BuyLimit":"SellLimit")+"\",";
   json += "\"entry\":"+DoubleToString(r.plan.entry,digits)+",";
   json += "\"sl\":"+DoubleToString(r.plan.sl,digits)+",";
   json += "\"tp\":"+DoubleToString(r.plan.tp,digits);
   json += "}";
   json += "}";
   return json;
}

// ====== Analyze and build trading plan ======
SMCResult AnalyzeSMC(MqlRates &rates[], int bars,
                     int lookback, double minDisplacementPoints,
                     double point, double rr, int slBufferPoints)
{
    SMCResult res;
    res.trendBias = Trend_Neutral;
    res.shift     = No_Shift;
    res.bosLevel  = 0;
    res.brokenIndex = -1;
    res.ob.found = false; res.fvg.found = false; res.plan.valid=false;
    res.rsiDivergence = false; res.paConfirmation = false;
    res.plan.lots = 0.0;
    if(bars < 100) return res;

    double bosLevel=0; int brokenIndex=-1;
    SMCShift shift = DetectMarketStructureShift(rates, bars, lookback, bosLevel, brokenIndex);
    res.shift = shift;
    res.bosLevel = bosLevel;
    res.brokenIndex = brokenIndex;

    if(shift != No_Shift)
    {
        res.ob = IdentifyOrderBlock(rates, bars, MathMax(3, brokenIndex), (shift == BOS_Bullish || shift == CHoCH_Bullish), minDisplacementPoints, point);
        if(res.ob.found) {
            res.fvg = FindFairValueGap(rates, bars, MathMax(3, brokenIndex+1));
        }
        res.rsiDivergence = ConfirmMomentumRSI(InpSymbol, InpTF, bars, rates, res.trendBias);
        res.paConfirmation = ConfirmCandlestickPattern(rates, 1, (shift == BOS_Bullish || shift == CHoCH_Bullish), point);
    }

    if((res.ob.found || res.fvg.found) && (res.rsiDivergence || res.paConfirmation))
    {
        double entryZonePrice = 0.0;
        if(res.ob.found) entryZonePrice = (res.ob.start + res.ob.end) / 2.0;
        else if(res.fvg.found) entryZonePrice = (res.fvg.high + res.fvg.low) / 2.0;

        if(shift == BOS_Bullish || shift == CHoCH_Bullish)
        {
            double entry = entryZonePrice;
            double sl    = entry - slBufferPoints*point;
            double risk  = entry - sl;
            double tp    = entry + rr*risk;
            res.plan.lots = CalcPositionSize(InpSymbol, entry, sl, InpRiskPercent);
            if (res.plan.lots > 0 && (tp - entry) / risk >= InpRR)
            {
                res.plan.valid=true; res.plan.buy=true; res.plan.entry=entry; res.plan.sl=sl; res.plan.tp=tp;
            }
        }
        else if(shift == BOS_Bearish || shift == CHoCH_Bearish)
        {
            double entry = entryZonePrice;
            double sl    = entry + slBufferPoints*point;
            double risk  = sl - entry;
            double tp    = entry - rr*risk;
            res.plan.lots = CalcPositionSize(InpSymbol, entry, sl, InpRiskPercent);
            if (res.plan.lots > 0 && (entry - tp) / risk >= InpRR)
            {
                res.plan.valid=true; res.plan.buy=false; res.plan.entry=entry; res.plan.sl=sl; res.plan.tp=tp;
            }
        }
    }
    return res;
}

// ====== Trading helpers ======
bool PendingExists(string symbol, string tag, bool buy, long magic=0)
{
   int total = OrdersTotal();
   for(int i=0; i<total; ++i)
   {
      if(OrderSelect(i))
      {
         long type = OrderGetInteger(ORDER_TYPE);
         string sym = OrderGetString(ORDER_SYMBOL);
         string cmt = OrderGetString(ORDER_COMMENT);
         long mgc = OrderGetInteger(ORDER_MAGIC);
         if(sym == symbol && (magic == 0 || mgc == magic) && StringFind(cmt, tag, 0) == 0)
         {
            if(buy && type == ORDER_TYPE_BUY_LIMIT) return true;
            if(!buy && type == ORDER_TYPE_SELL_LIMIT) return true;
         }
      }
   }
   return false;
}

double NormalizeVolume(const string symbol, double vol)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   vol = MathMax(minLot, MathMin(maxLot, vol));
   int steps = (int)MathFloor(vol/step + 1e-8);
   return steps * step;
}

double CalcPositionSize(const string symbol, double entry, double stop, double riskPercent)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * riskPercent/100.0;
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double riskPoints = MathAbs(entry - stop)/point;
   if(riskPoints < 1e-6) return 0.0;

   double moneyPerPointPerLot = (tickValue / tickSize);
   double riskMoneyPerLot     = riskPoints * moneyPerPointPerLot;

   double lots = riskMoney / riskMoneyPerLot;
   return NormalizeVolume(symbol, lots);
}

void DrawZone(string name, string symbol, ENUM_TIMEFRAMES tf, double price1, double price2, color clr, bool back=true)
{
   datetime t1 = TimeCurrent();
   datetime t2 = t1 + (datetime)(PeriodSeconds(tf) * 100);
   if(ObjectFind(0, name) == -1)
   {
      if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, price1, t2, price2))
      {
         ObjectSetInteger(0, name, 1000, back ? 1 : 0); // OBJPROP_BACK
         ObjectSetInteger(0, name, 6, clr); // OBJPROP_COLOR
         ObjectSetInteger(0, name, 7, STYLE_SOLID); // OBJPROP_STYLE
         ObjectSetInteger(0, name, 8, 1); // OBJPROP_WIDTH
      }
   }
   else
   {
      ObjectSetInteger(0, name, 9, t1); // OBJPROP_TIME1
      ObjectSetDouble(0, name, 10, price1); // OBJPROP_PRICE1
      ObjectSetInteger(0, name, 11, t2); // OBJPROP_TIME2
      ObjectSetDouble(0, name, 12, price2); // OBJPROP_PRICE2
      ObjectSetInteger(0, name, 6, clr); // OBJPROP_COLOR
   }
}

// Normalize price to tick size/precision and ensure broker min distance
double NormalizePrice(const string symbol, double price)
{
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   int    digits   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double ticks    = MathRound(price / tickSize);
   return NormalizeDouble(ticks * tickSize, digits);
}

// Place pending with explicit request to ensure comment/magic are set
bool PlacePendingLimit(const string symbol, bool buy, double lots, double entry, double sl, double tp, const string comment, long magic)
{
   MqlTradeRequest req; ZeroMemory(req);
   MqlTradeResult  res; ZeroMemory(res);
   req.action   = TRADE_ACTION_PENDING;
   req.symbol   = symbol;
   req.magic    = magic;
   req.deviation= InpDeviationPoints;
   req.comment  = comment;
   req.volume   = lots;
   req.type     = buy ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   req.type_time= ORDER_TIME_GTC;
   req.price    = NormalizePrice(symbol, entry);
   req.sl       = (sl>0 ? NormalizePrice(symbol, sl) : 0.0);
   req.tp       = (tp>0 ? NormalizePrice(symbol, tp) : 0.0);

   // Respect stops level
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int    stopsLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stopsLevel * pt;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

   bool adjusted = false;
   double origPrice = req.price, origSL = req.sl, origTP = req.tp;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   if(buy)
   {
      if((ask - req.price) < minDist) { req.price = NormalizePrice(symbol, ask - minDist); adjusted = true; }
      if(req.sl>0 && (req.price - req.sl) < minDist) { req.sl = NormalizePrice(symbol, req.price - minDist); adjusted = true; }
      if(req.tp>0 && (req.tp - req.price) < minDist) { req.tp = NormalizePrice(symbol, req.price + minDist); adjusted = true; }
   }
   else
   {
      if((req.price - bid) < minDist) { req.price = NormalizePrice(symbol, bid + minDist); adjusted = true; }
      if(req.sl>0 && (req.sl - req.price) < minDist) { req.sl = NormalizePrice(symbol, req.price + minDist); adjusted = true; }
      if(req.tp>0 && (req.price - req.tp) < minDist) { req.tp = NormalizePrice(symbol, req.price - minDist); adjusted = true; }
   }

   if(adjusted && InpDiagnostics)
   {
       Print("PlacePendingLimit: adjusted prices for stops-level. origPrice=", DoubleToString(origPrice, digits), " newPrice=", DoubleToString(req.price, digits),
             " origSL=", DoubleToString(origSL,digits), " newSL=", DoubleToString(req.sl,digits),
             " origTP=", DoubleToString(origTP,digits), " newTP=", DoubleToString(req.tp,digits));
   }

   bool ok = OrderSend(req, res);
   if(!ok)
   {
      Print("OrderSend failed: ", GetLastError(), " retcode=", res.retcode);
      return false;
   }
   if(res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_PLACED)
   {
      Print("OrderSend retcode: ", res.retcode);
      return false;
   }
   return true;
}

void ExportGlobals(string symbol, SMCResult &r)
{
   GlobalVariableSet(symbol+".SMC.trendBias", (double)r.trendBias);
   GlobalVariableSet(symbol+".SMC.shift", (double)r.shift);
   GlobalVariableSet(symbol+".SMC.bosLevel", r.bosLevel);
   GlobalVariableSet(symbol+".SMC.ob.start", r.ob.start);
   GlobalVariableSet(symbol+".SMC.ob.end",   r.ob.end);
   GlobalVariableSet(symbol+".SMC.fvg.high", r.fvg.high);
   GlobalVariableSet(symbol+".SMC.fvg.low",  r.fvg.low);
   GlobalVariableSet(symbol+".SMC.plan.side", r.plan.valid ? (r.plan.buy?1.0: -1.0) : 0.0);
   GlobalVariableSet(symbol+".SMC.plan.entry", r.plan.entry);
   GlobalVariableSet(symbol+".SMC.plan.sl",    r.plan.sl);
   GlobalVariableSet(symbol+".SMC.plan.tp",    r.plan.tp);
}

void SendWebhook(string url, string json)
{
   if(url=="" || StringLen(url)<8) return;
   string headers = "Content-Type: application/json\r\n";
   uchar data[]; StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);
   uchar result[]; string result_headers;
   int status = WebRequest("POST", url, headers, "", 10000, data, ArraySize(data), result, result_headers);
   if(status<=0) { Print("Webhook failed, code: ", status, " err: ", GetLastError()); return; }
   Print("Webhook status: ", status);
}

// ====== I. HTF Analysis ======
void HTF_AnalyzeMarketStructure(string symbol, ENUM_TIMEFRAMES htf, int lookback, int &htfBias, double &htfPivot)
{
    MqlRates htfRates[]; ArraySetAsSeries(htfRates, true);
    int bars = CopyRates(symbol, htf, 0, lookback, htfRates);
    if(bars < 100) { htfBias=Trend_Neutral; htfPivot=0.0; return; }
    int hi1, hi2, lo1, lo2;
    FindTwoRecentSwings(htfRates, bars, bars-1, hi1, hi2, lo1, lo2);
    htfBias = DetectTrendFromSwings(htfRates, hi1, hi2, lo1, lo2);
    htfPivot = (htfRates[1].high + htfRates[1].low + htfRates[1].close) / 3.0; 
}

// ====== II. Confluence ======
void MarkLiquidityPools(MqlRates &rates[], int bars)
{
   // ระบุ PDH/PDL, Swing High/Low
   // ... (logic เพิ่มเติม)
}

bool DetectLiquiditySweep(MqlRates &rates[], int bars)
{
   // ตรวจสอบการกวาดสภาพคล่อง
   // ... (logic เพิ่มเติม)
   return false;
}

bool ConfirmMSS(MqlRates &rates[], int bars)
{
   // ตรวจสอบ MSS หลัง sweep
   // ... (logic เพิ่มเติม)
   return false;
}

// Updated ConfirmMomentumRSI to handle RSI divergence properly
bool ConfirmMomentumRSI(string symbol, ENUM_TIMEFRAMES tf, int bars, MqlRates &rates[], TrendBias bias)
{
    if(g_hRSI == INVALID_HANDLE) { g_hRSI = iRSI(symbol, tf, 14, PRICE_CLOSE); if(g_hRSI == INVALID_HANDLE) return false; }

    double rsiArr[]; ArraySetAsSeries(rsiArr, true);
    int copied = CopyBuffer(g_hRSI, 0, 0, 20, rsiArr);
    if(copied <= 6) return false;

    if(bias == Trend_Up)
    {
        if((rates[1].low < rates[5].low) && (rsiArr[1] > rsiArr[5])) return true;
    }
    else if(bias == Trend_Down)
    {
        if((rates[1].high > rates[5].high) && (rsiArr[1] < rsiArr[5])) return true;
    }
    return false;
}

bool ConfirmCandlestickPattern(MqlRates &rates[], int index, bool bullish, double point)
{
    if (index != 1 || index < 2) return false;
    if (bullish)
    {
        if (IsBear(rates[2]) && IsBull(rates[1]))
            return (rates[1].close > rates[2].open && rates[1].open < rates[2].close);
    }
    else
    {
        if (IsBull(rates[2]) && IsBear(rates[1]))
            return (rates[1].close < rates[2].open && rates[1].open > rates[2].close);
    }
    return false;
}

// ====== III. Risk Management ======
double CalcMaxDollarRisk(double equity, double riskPercent)
{
   // D_Risk = Equity * R%
   return equity * riskPercent / 100.0;
}

double LogicalSLPlacement(double entry, double zone, bool isBuy)
{
   // วาง SL หลัง OB/FVG หรือจุด sweep
   // ... (logic เพิ่มเติม)
   return isBuy ? (zone - 10) : (zone + 10); // ตัวอย่าง
}

double CalcTPFibo(double entry, double sl, double fiboRatio, bool isBuy)
{
   // TP = entry + fiboRatio * (entry - sl)
   return isBuy ? (entry + fiboRatio * (entry - sl)) : (entry - fiboRatio * (sl - entry));
}

// ====== IV. Execution Protocol ======
bool PreTradeChecklist(SMCResult &res)
{
   // ตรวจสอบ setup, trigger, SL, TP, RR
   // ... (logic เพิ่มเติม)
   return res.plan.valid && res.ob.found;
}

int SelectOrderType(bool strongMomentum)
{
   // 0 = Limit, 1 = Market
   return strongMomentum ? 1 : 0;
}

bool PlaceOCOOrder(string symbol, double entry, double sl, double tp, double lots, long magic, string comment)
{
   // วาง Entry + SL + TP พร้อมกัน
   // ... (logic เพิ่มเติม)
   return PlacePendingLimit(symbol, true, lots, entry, sl, tp, comment, magic);
}

// ====== V. Trade Management & Exit ======
void MoveSLToBreakeven(string symbol, long magic, double breakevenPips)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    for(int i=PositionsTotal()-1; i>=0; --i)
    {
        if(PositionSelect(i))
        {
            if (PositionGetString(POSITION_SYMBOL) != symbol || PositionGetInteger(POSITION_MAGIC) != magic || PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY && PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
            double entry = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double riskInPips = MathAbs(entry - sl) / point / 10.0;
            if (sl == 0.0 || ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) && (sl >= entry)) || ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) && (sl <= entry))) continue;
            double currentProfitPips = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? (bid - entry) / point / 10.0 : (entry - ask) / point / 10.0;
            double triggerPips = MathMax(riskInPips, breakevenPips / 10.0);
            if (currentProfitPips >= triggerPips)
            {
                double newSL = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? entry + point : entry - point;
                trade.PositionModify(PositionGetInteger(POSITION_TICKET), newSL, PositionGetDouble(POSITION_TP));
                if(InpDiagnostics) Print("INFO: Order #", (string)PositionGetInteger(POSITION_TICKET), " moved to Breakeven.");
            }
        }
    }
}

void PartialProfitTake(string symbol, long magic, double percent)
{
    if (percent <= 0.0 || percent >= 100.0) return;
    double closeRatio = percent / 100.0;
    for(int i=PositionsTotal()-1; i>=0; --i)
    {
        if(PositionSelect(i))
        {
            if (PositionGetString(POSITION_SYMBOL) != symbol || PositionGetInteger(POSITION_MAGIC) != magic || ((PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) && (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL))) continue;
            double lots = PositionGetDouble(POSITION_VOLUME);
            double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
            double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double entry = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            if(sl==0) continue; // cannot compute risk
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            double risk = MathAbs(entry - sl);
            double tp1 = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) ? (entry + risk) : (entry - risk); // 1R target

            // If TP1 reached or crossed, close partial
            if( (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY && bid >= tp1) || (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL && ask <= tp1) )
            {
                double closeLots = NormalizeVolume(symbol, lots * closeRatio);
                if (closeLots < lots)
                {
                    trade.PositionClosePartial(PositionGetInteger(POSITION_TICKET), closeLots);
                    if(InpDiagnostics) Print("INFO: Order #", (string)PositionGetInteger(POSITION_TICKET), " partial closed (", percent, "%) at TP1.");
                }
            }
        }
    }
}

void StructuralTrailingStop(string symbol, long magic, ENUM_TIMEFRAMES tf, int lookback)
{
    MqlRates rates[]; ArraySetAsSeries(rates, true);
    int bars = CopyRates(symbol, tf, 0, lookback, rates);
    if(bars < 10) return;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    for(int i=PositionsTotal()-1; i>=0; --i)
    {
        if(PositionSelect(i))
        {
            if (PositionGetString(POSITION_SYMBOL) != symbol || PositionGetInteger(POSITION_MAGIC) != magic || ((PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) && (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL))) continue;
            if (PositionGetDouble(POSITION_SL) == 0.0 || ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) && (PositionGetDouble(POSITION_SL) >= PositionGetDouble(POSITION_PRICE_OPEN)))) continue;
            int newSwingIndex = 0;
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                // Use wider swing detection (left/right = 5)
                newSwingIndex = FindSwingLow(rates, bars, 5, 5, 5);
                if (newSwingIndex != -1)
                {
                    double newSL = rates[newSwingIndex].low - 10 * point;
                    if (newSL > PositionGetDouble(POSITION_SL))
                    {
                        trade.PositionModify(PositionGetInteger(POSITION_TICKET), NormalizePrice(symbol, newSL), PositionGetDouble(POSITION_TP));
                        if(InpDiagnostics) Print("INFO: Order #", (string)PositionGetInteger(POSITION_TICKET), " trailed structurally (Buy).");
                    }
                }
            }
            else
            {
                newSwingIndex = FindSwingHigh(rates, bars, 5, 5, 5);
                if (newSwingIndex != -1)
                {
                    double newSL = rates[newSwingIndex].high + 10 * point;
                    if (newSL < PositionGetDouble(POSITION_SL))
                    {
                        trade.PositionModify(PositionGetInteger(POSITION_TICKET), NormalizePrice(symbol, newSL), PositionGetDouble(POSITION_TP));
                        if(InpDiagnostics) Print("INFO: Order #", (string)PositionGetInteger(POSITION_TICKET), " trailed structurally (Sell).");
                    }
                }
            }
        }
    }
}

void ExitTrade(string symbol, long magic)
{
   // ปิดสถานะเมื่อ trailing stop หรือ TP สุดท้าย
   // ... (logic เพิ่มเติม)
}

// ====== VI. Review & Expectancy ======
void LogTradeJournal(const string symbol, datetime entryTime, double entryPrice, double exitPrice, 
                     double lots, double rr, bool isWin, double pipsGain, string exitReason)
{
    if (!InpEnableLogging) return;
    string fileName = "SMC_Trade_Log_" + symbol + "_" + EnumToString(InpTF) + ".csv";
    int fileHandle = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_READ, ';');
    if (fileHandle != INVALID_HANDLE)
    {
        string header = "Ticket;EntryTime;ExitTime;Side;Lots;Entry;Exit;RR;Pips;Result;Reason\n";
        if (FileTell(fileHandle) == 0) FileWrite(fileHandle, header);
        string logLine = StringFormat("%d;%s;%s;%s;%.2f;%.5f;%.5f;%.2f;%.1f;%s;%s\n",
                                      (int)TimeCurrent(), TimeToString(entryTime), TimeToString(TimeCurrent()), 
                                      "", lots, entryPrice, exitPrice, rr, pipsGain, (isWin?"WIN":"LOSS"), exitReason);
        FileWrite(fileHandle, logLine);
        FileClose(fileHandle);
    }
}

bool DisciplineCheck()
{
   // ตรวจสอบการทำตามกฎ risk/execution
   // ... (logic เพิ่มเติม)
   return true;
}

double CalcExpectancy(double winRate, double avgGain, double lossRate, double avgLoss)
{
   // E = (WR * AvgGain) - (LR * AvgLoss)
   return (winRate * avgGain) - (lossRate * avgLoss);
}

void OptimizeSystem(double expectancy)
{
    if (expectancy < 0.0)
    {
        if (InpDiagnostics) Print("WARNING: Expectancy is NEGATIVE. System needs optimization!");
    }
}

// ====== EA Lifecycle ======
int OnInit()
{
    trade.SetExpertMagic(InpMagicNumber);
    trade.SetDeviation(InpDeviationPoints);
    trade.SetComment(InpOrderTag);
    g_hRSI = iRSI(InpSymbol, InpTF, 14, PRICE_CLOSE);
    if(InpDiagnostics && InpSelfTest)
    {
        string symbol = InpSymbol;
        ENUM_TIMEFRAMES tf = InpTF;
        MqlRates rates[]; ArraySetAsSeries(rates, true);
        int bars = CopyRates(symbol, tf, 0, MathMax(InpLookback, 500), rates);
        if(bars>0)
        {
           double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
           SMCResult res = AnalyzeSMC(rates, bars, InpLookback, InpMinDisplacementPoints, point, InpRR, InpSLBufferPoints);
           string json = SMCResultToJson(res, symbol, tf);
           Print("[SelfTest] bars=", bars, " json=", json);
        }
        else
        {
           Print("[SelfTest] CopyRates returned no data for ", symbol, " ", EnumToString(tf));
        }
    }
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    IndicatorRelease(g_hRSI);
}

void OnTick()
{
    static bool initialized = false;
    if (!initialized)
    {
        DefineTradingRange();
        initialized = true;
    }

    ConfirmBreakout();
    MqlRates rates[]; ArraySetAsSeries(rates, true);
    int bars = CopyRates(InpSymbol, InpTF, 0, MathMax(InpLookback, 500), rates);
    if(bars < 10) return;

    if(rates[0].time == g_lastBarTime) return;
    g_lastBarTime = rates[0].time;

    // Call trade management functions after new-bar guard
    MoveSLToBreakeven(InpSymbol, InpMagicNumber, InpBreakevenPips);
    PartialProfitTake(InpSymbol, InpMagicNumber, InpPartialClosePercent);
    StructuralTrailingStop(InpSymbol, InpMagicNumber, InpTF, InpLookback);

    // Additional logic for new bar analysis...
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    SMCResult res = AnalyzeSMC(rates, bars, InpLookback, InpMinDisplacementPoints, point, InpRR, InpSLBufferPoints);

    double expectancy = CalcExpectancy(g_winCount/(double)MathMax(1, g_winCount+g_lossCount), 1.0, g_lossCount/(double)MathMax(1, g_winCount+g_lossCount), 1.0);
    string expectLine = StringFormat(" | Expectancy: %.2f (W: %d L: %d)", expectancy, g_winCount, g_lossCount);
    Comment(expectLine);
    OptimizeSystem(expectancy);
    bool doWebhook = (InpTradingMode==Mode_WebhookOnly || InpTradingMode==Mode_Both);
    bool doLocal   = (InpTradingMode==Mode_LocalAuto  || InpTradingMode==Mode_Both);
    if(doWebhook)
    {
       string json = SMCResultToJson(res, InpSymbol, InpTF);
       SendWebhook(InpWebhookUrl, json);
    }
    if(doLocal && res.plan.valid)
    {
       bool wantBuy = res.plan.buy;
       if(!PendingExists(InpSymbol, InpOrderTag, wantBuy, InpMagicNumber))
       {
          double lots = CalcPositionSize(InpSymbol, res.plan.entry, res.plan.sl, InpRiskPercent);
          if(lots > 0)
          {
             bool sent = PlacePendingLimit(InpSymbol, wantBuy, lots, res.plan.entry, res.plan.sl, res.plan.tp, InpOrderTag, InpMagicNumber);
             if(InpDiagnostics) Print("Pending order placed...");
          }
       }
    }

    // Analyze market structure and set trend bias
    AnalyzeMarketStructure();
}

// Helper function to find the most recent swing high
int FindRecentSwingHigh(MqlRates &rates[], int bars, int left = 3, int right = 3)
{
    for (int i = bars - left - 1; i >= right; i--)
    {
        bool isSwingHigh = true;
        for (int j = 1; j <= left; j++)
            if (rates[i].high <= rates[i - j].high)
                isSwingHigh = false;
        for (int j = 1; j <= right; j++)
            if (rates[i].high <= rates[i + j].high)
                isSwingHigh = false;
        if (isSwingHigh)
            return i;
    }
    return -1;
}

// Helper function to find the most recent swing low
int FindRecentSwingLow(MqlRates &rates[], int bars, int left = 3, int right = 3)
{
    for (int i = bars - left - 1; i >= right; i--)
    {
        bool isSwingLow = true;
        for (int j = 1; j <= left; j++)
            if (rates[i].low >= rates[i - j].low)
                isSwingLow = false;
        for (int j = 1; j <= right; j++)
            if (rates[i].low >= rates[i + j].low)
                isSwingLow = false;
        if (isSwingLow)
            return i;
    }
    return -1;
}

// Function to analyze market structure and set trend bias
void AnalyzeMarketStructure()
{
    MqlRates rates[100];
    int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, 100, rates);
    if (copied < 100)
    {
        Print("Failed to load enough candle data.");
        return;
    }

    int swingHighIndex = FindRecentSwingHigh(rates, copied);
    int swingLowIndex = FindRecentSwingLow(rates, copied);

    if (swingHighIndex == -1 || swingLowIndex == -1)
    {
        Print("Failed to find swing points.");
        return;
    }

    double bosLevel = rates[swingHighIndex].high;
    double chochLevel = rates[swingLowIndex].low;

    // Draw BoS and CHoCH lines
    ObjectCreate(0, "BoS_Line", OBJ_HLINE, 0, 0, bosLevel);
    ObjectSetInteger(0, "BoS_Line", OBJPROP_COLOR, clrLime);

    ObjectCreate(0, "CHoCH_Line", OBJ_HLINE, 0, 0, chochLevel);
    ObjectSetInteger(0, "CHoCH_Line", OBJPROP_COLOR, clrRed);

    // Monitor price action for confirmation
    double closePrice = rates[0].close;
    if (closePrice > bosLevel)
    {
        Print("Bullish Confirm: Price closed above BoS.");
        g_htfBias = Trend_Up;
        FindOrderBlockAndFVG(true);
    }
    else if (closePrice < chochLevel)
    {
        Print("Bearish Confirm: Price closed below CHoCH.");
        g_htfBias = Trend_Down;
        FindOrderBlockAndFVG(false);
    }
}

// Function to find Order Block and FVG
void FindOrderBlockAndFVG(bool isBullish)
{
    // Placeholder for OB and FVG detection logic
    Print("Finding Order Block and FVG...");
    // Implement OB and FVG detection here
}

// Function to define trading range and levels
void DefineTradingRange()
{
    MqlRates rates[100];
    int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, 100, rates);
    if (copied < 100)
    {
        Print("Failed to load enough candle data.");
        return;
    }

    int swingHighIndex = FindRecentSwingHigh(rates, copied);
    int swingLowIndex = FindRecentSwingLow(rates, copied);

    if (swingHighIndex == -1 || swingLowIndex == -1)
    {
        Print("Failed to find swing points.");
        return;
    }

    double bosLevel = rates[swingHighIndex].high;
    double chochLevel = rates[swingLowIndex].low;

    // Draw Major Levels
    ObjectCreate(0, "Major_BOS_Level", OBJ_HLINE, 0, 0, bosLevel);
    ObjectSetInteger(0, "Major_BOS_Level", OBJPROP_COLOR, clrLime);

    ObjectCreate(0, "Major_CHoCH_Level", OBJ_HLINE, 0, 0, chochLevel);
    ObjectSetInteger(0, "Major_CHoCH_Level", OBJPROP_COLOR, clrRed);

    Print("Trading range defined: BOS Level = ", bosLevel, ", CHoCH Level = ", chochLevel);
}

// Function to confirm breakout and set trend bias
void ConfirmBreakout()
{
    double bosLevel = ObjectGetDouble(0, "Major_BOS_Level", OBJPROP_PRICE);
    double chochLevel = ObjectGetDouble(0, "Major_CHoCH_Level", OBJPROP_PRICE);

    MqlRates rates[1];
    CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates);

    double closePrice = rates[0].close;

    if (closePrice > bosLevel)
    {
        Print("Bullish Confirm: Price closed above BOS Level.");
        g_htfBias = Trend_Up;
        HuntEntryZone(true);
    }
    else if (closePrice < chochLevel)
    {
        Print("Bearish Confirm: Price closed below CHoCH Level.");
        g_htfBias = Trend_Down;
        HuntEntryZone(false);
    }
    else
    {
        Print("Waiting for confirmation: Price within range.");
    }
}

// Function to hunt entry zones (OB and FVG)
void HuntEntryZone(bool isBullish)
{
    Print("Hunting entry zones...");

    if (isBullish)
    {
        // Find Demand Zone (OB and FVG below current price)
        Print("Looking for Demand Zone...");
        // Placeholder for OB/FVG detection logic
    }
    else
    {
        // Find Supply Zone (OB and FVG above current price)
        Print("Looking for Supply Zone...");
        // Placeholder for OB/FVG detection logic
    }
}
