//+------------------------------------------------------------------+
//|                                        Major_SMC_Breakout_EA.mq5 |
//|                         Copyright 2025, Gemini Auto_Trade Dev    |
//|                     Focus: Major BOS/CHoCH Drawing & Breakout    |
//+------------------------------------------------------------------+
#property copyright "Gemini Auto_Trade Development"
#property version   "1.01"
#property description "Detects and draws Major BOS/CHoCH levels and waits for bar close confirmation."
#property strict

#include <Trade\Trade.mqh> // สำหรับ CTrade
#include <Math\Math.mqh>   // สำหรับ Math utilities

//==================================================================
// 1. INPUT PARAMETERS
//==================================================================
input string   InpGroupName          = "--- Structure & Trading ---";
input double   InpLots               = 0.01;       // Lot Size (ตัวอย่าง)
input int      InpSwingLookbackBars  = 300;        // จำนวนแท่งเทียนที่ใช้มองหา Swing Points หลัก
input string   InpOrderTag           = "MBBOS";    // Comment Tag

//==================================================================
// 2. GLOBAL VARIABLES AND DATA STRUCTURES
//==================================================================
CTrade trade;
long   g_lastBarTime = 0;
string g_symbol;
ENUM_TIMEFRAMES g_timeframe;

// สถานะการ Breakout
enum BreakoutResult
{
    Breakout_None = 0,
    Breakout_BOS_Bullish,
    Breakout_CHoCH_Bullish,
    Breakout_BOS_Bearish,
    Breakout_CHoCH_Bearish
};

// โครงสร้างสำหรับเก็บระดับ Major Levels
struct MajorLevels
{
    double currentHigh;
    double currentLow;
    double bosLevel;    
    double chochLevel;  
};

//==================================================================
// 3. UTILITY FUNCTIONS (Swing Detection & Trend)
//==================================================================

// ฟังก์ชันหา High/Low ที่ extreme ที่สุดใน lookback (ใช้เป็น Major Structure)
void FindTwoRecentSwings(MqlRates &rates[], int bars, int lookback, int &hi1, int &hi2, int &lo1, int &lo2)
{
    hi1 = -1; lo1 = -1; hi2 = -1; lo2 = -1;
    double maxHigh = DBL_MIN;
    double minLow = DBL_MAX;
    
    // หา High/Low ที่ extreme ที่สุดใน Lookback
    for (int i = 1; i < MathMin(bars, lookback); i++)
    {
        if (rates[i].high > maxHigh) { maxHigh = rates[i].high; hi1 = i; }
        if (rates[i].low < minLow)   { minLow = rates[i].low; lo1 = i; }
    }
    
    // ตั้งค่า Swing Points (hi1/lo1 คือขอบเขตหลัก)
    if (hi1 != -1 && hi1 < bars - 10) hi2 = hi1 + 10; 
    if (lo1 != -1 && lo1 < bars - 10) lo2 = lo1 + 10;
}

// ฟังก์ชันหา Trend Bias (1=Up, -1=Down, 0=Neutral)
int DetectTrendFromSwings(MqlRates &rates[], int hi1, int hi2, int lo1, int lo2)
{
    if (hi1 != -1 && hi2 != -1 && lo1 != -1 && lo2 != -1 && hi2 < ArraySize(rates) && lo2 < ArraySize(rates))
    {
        bool highsUp = rates[hi1].high > rates[hi2].high;
        bool lowsUp  = rates[lo1].low  > rates[lo2].low;
        bool highsDn = rates[hi1].high < rates[hi2].high;
        bool lowsDn  = rates[lo1].low  < rates[lo2].low;

        if (highsUp && lowsUp) return 1;    // Trend Up (Bullish)
        if (highsDn && lowsDn) return -1;   // Trend Down (Bearish)
    }
    return 0; // Neutral
}

//==================================================================
// 4. DRAWING FUNCTION
//==================================================================

// ฟังก์ชันวาดและอัปเดตเส้นแนวนอน (Horizontal Line)
void DrawMajorLevelLine(string name, double price, color clr, int width=2, ENUM_LINE_STYLE style=STYLE_DASH)
{
    int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
    double normalizedPrice = NormalizeDouble(price, digits);
    
    if(ObjectFind(0, name) == -1)
    {
        // ObjectCreate(chart_id, object_name, object_type, sub_window, time1, price1, ...)
        if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, normalizedPrice))
        {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
            ObjectSetInteger(0, name, OBJPROP_STYLE, style);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
            ObjectSetInteger(0, name, OBJPROP_BACK, false); 
            ObjectSetString(0, name, OBJPROP_TEXT, name); 
        }
    }
    else
    {
        // ObjectSetDouble(chart_id, object_name, prop_id, value)
        ObjectSetDouble(0, name, OBJPROP_PRICE1, normalizedPrice);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    }
}

//==================================================================
// 5. CORE LOGIC FUNCTION
//==================================================================

BreakoutResult CheckMajorBreakout(MqlRates &rates[], int bars)
{
    int hi1, hi2, lo1, lo2;
    FindTwoRecentSwings(rates, bars, InpSwingLookbackBars, hi1, hi2, lo1, lo2);
    
    if (hi1 == -1 || lo1 == -1) return Breakout_None;

    MajorLevels levels;
    levels.bosLevel = rates[hi1].high; // Swing High ล่าสุด = BOS
    levels.chochLevel = rates[lo1].low; // Swing Low ล่าสุด = CHoCH

    // 3. วาดเส้น Major Levels
    DrawMajorLevelLine("Major_BOS_Level", levels.bosLevel, clrGreen, 2, STYLE_DASH);
    DrawMajorLevelLine("Major_CHoCH_Level", levels.chochLevel, clrRed, 2, STYLE_DASH);

    // 4. ตรวจสอบ Breakout Confirmation (เมื่อแท่งเทียนปิด)
    double closePrice = NormalizeDouble(rates[1].close, (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS));
    int trend = DetectTrendFromSwings(rates, hi1, hi2, lo1, lo2);
    
    // A. Bullish Breakout
    if (closePrice > levels.bosLevel)
    {
        if (trend >= 0) return Breakout_BOS_Bullish;   
        if (trend == -1) return Breakout_CHoCH_Bullish; 
    }

    // B. Bearish Breakout
    if (closePrice < levels.chochLevel)
    {
        if (trend <= 0) return Breakout_BOS_Bearish;  
        if (trend == 1) return Breakout_CHoCH_Bearish; 
    }
    
    return Breakout_None;
}

//==================================================================
// 6. STANDARD EA FUNCTIONS (Lifecycle)
//==================================================================

int OnInit()
{
    if(!trade.IsInitialized())
    {
       if(!trade.Init(ChartID()))
       {
          Print("CTrade initialization failed. Error: ", trade.ResultRetcode());
          return INIT_FAILED;
       }
    }
    trade.SetExpertMagic(12345);
    g_symbol = Symbol();
    g_timeframe = Period();
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    ObjectDelete(0, "Major_BOS_Level");
    ObjectDelete(0, "Major_CHoCH_Level");
}

void OnTick()
{
    MqlRates rates[];
    if(CopyRates(g_symbol, g_timeframe, 0, InpSwingLookbackBars + 10, rates) <= 1) return;
    int bars = ArraySize(rates);
    ArraySetAsSeries(rates, true);
    
    // Logic ตรวจสอบ Bar Close
    if(g_lastBarTime == 0) { g_lastBarTime = rates[0].time; return; }
    if(rates[0].time == g_lastBarTime) return;
    g_lastBarTime = rates[0].time;

    // *** CORE EXECUTION ***
    BreakoutResult majorShift = CheckMajorBreakout(rates, bars);
    
    if (majorShift != Breakout_None)
    {
        string message = StringFormat("MAJOR SHIFT: %s Confirmed! Ready for entry.", EnumToString(majorShift));
        Print(message);
        Comment(message);
        
        // *** ใส่ Logic การวาง Pending Order หรือ Trade Action ที่นี่ ***
    }
}