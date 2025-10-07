//+------------------------------------------------------------------+
//| SMC Regression Channel HTF/CTF Alignment Expert Advisor        |
//| Copyright 2025, SMC Trading Systems                              |
//| ใช้ Linear Regression Channel สำหรับกำหนดทิศทาง HTF/CTF         |
//| Enhanced with BoS Detection and VWAP Drawing                    |
//+------------------------------------------------------------------+
#property copyright "SMC Trading Systems"
#property link      ""
#property version   "2.00"
#property description "Enhanced SMC EA with BoS Detection, VWAP, and Fibonacci"

// Required includes for trading functions
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

// Global trade objects
CTrade trade;
CPositionInfo positionInfo;
COrderInfo orderInfo;

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input group "=== HTF/CTF Analysis ==="
input ENUM_TIMEFRAMES HTF_Timeframe = PERIOD_H4;     // HTF สำหรับ Structure
input int HTF_Bars = 100;                            // จำนวนแท่งวิเคราะห์ HTF
input int CTF_Bars = 20;                             // จำนวนแท่งวิเคราะห์ CTF (ลดลงเพื่อ sensitivity)
input double Slope_Threshold = 0.00001;              // ค่าขั้นต่ำ slope สำหรับ trend
input bool Use_Dynamic_CTF = true;                   // ใช้ CTF Bars แบบ dynamic

input group "=== CTF Dynamic Options ==="
input int CTF_Min_Bars = 15;                         // CTF Bars ต่ำสุด
input int CTF_Max_Bars = 50;                         // CTF Bars สูงสุด

input group "=== VWAP Settings ==="
input bool Use_VWAP = true;                          // ใช้ VWAP ในการตัดสินใจ
input int VWAP_Period = 20;                          // จำนวนแท่งคำนวณ VWAP
input bool Draw_VWAP = true;                         // วาด VWAP บน chart
input color VWAP_Color = clrYellow;                  // สี VWAP line

input group "=== BoS Detection ==="
input bool Use_BoS_Detection = true;                 // เปิดใช้ BoS Detection
input int BoS_ConfirmBars = 2;                       // จำนวนแท่งยืนยัน BoS
input bool Auto_Draw_Fibo = true;                    // วาด Fibonacci อัตโนมัติเมื่อ BoS
input int Swing_Detection_Depth = 5;                 // ความลึกในการหา Swing Points
input int Swing_History_Bars = 100;                  // จำนวนแท่งย้อนหลังสำหรับหา Swing
input bool Draw_BoS_Lines = true;                    // วาดเส้น BoS
input color BoS_Bullish_Color = clrLime;             // สี BoS แบบขาขึ้น
input color BoS_Bearish_Color = clrRed;              // สี BoS แบบขาลง

input group "=== FVG Detection ==="
input bool Use_FVG_Detection = true;                 // เปิดใช้ FVG Detection
input bool Draw_FVG_Zones = true;                    // วาดโซน FVG
input color FVG_Bullish_Color = clrDodgerBlue;       // สี FVG แบบขาขึ้น
input color FVG_Bearish_Color = clrOrange;           // สี FVG แบบขาลง
input int FVG_History_Bars = 50;                     // จำนวนแท่งย้อนหลังสำหรับหา FVG

input group "=== Trading Logic Settings ==="
input bool Enable_Trading = false;                   // เปิดใช้การเทรดจริง (ปิดสำหรับ Demo)
input double Risk_Percent = 1.0;                     // เปอร์เซ็นต์ความเสี่ยงต่อการเทรด
input double Risk_Reward_Ratio = 2.0;                // อัตราส่วน Risk:Reward
input int Pullback_ConfirmBars = 1;                  // จำนวน bars ที่ใช้ confirm Pullback End
input int CHoCH_ConfirmBars = 2;                     // จำนวน bars ที่ใช้ confirm CHoCH
input double ATR_SL_Multiplier = 1.5;               // ATR multiplier สำหรับ Stop Loss
input bool Use_Breakeven = true;                     // ใช้ Breakeven เมื่อกำไร 1R
input bool Use_Trailing = true;                      // ใช้ Trailing Stop

input group "=== Advanced Filters & Sessions ==="
input int Max_Spread_Points = 20;                    // สเปรดสูงสุด (จุด)
input int Session_Start_Hour = 7;                    // เวลาเริ่มเทรด (ชั่วโมง)
input int Session_End_Hour = 22;                     // เวลาสิ้นสุดเทรด (ชั่วโมง)

input group "=== Entry Scoring (Confluence) ==="
input bool Use_Entry_Scoring = true;                 // เปิดใช้ระบบให้คะแนนสัญญาณ
input int Min_Entry_Score = 60;                      // คะแนนขั้นต่ำในการเข้าเทรด (0-100)
input int Score_OB = 25;                             // น้ำหนัก Order Block
input int Score_FVG = 20;                            // น้ำหนัก FVG
input int Score_Fibo = 15;                           // น้ำหนัก Fibonacci 50-61.8
input int Score_Rejection = 15;                      // น้ำหนัก Rejection Candle
input int Score_VWAP = 10;                           // น้ำหนักตำแหน่งเทียบกับ VWAP
input int Score_TrendAlign = 15;                     // น้ำหนัก Alignment (HTF/CTF)

input group "=== Partial Take Profit ==="
input bool Use_Partial_TP = true;                    // ปิดบางส่วนที่ 1R
input double Partial_TP_R = 1.0;                     // ระยะกำไร R สำหรับปิดบางส่วน
input double Partial_Close_Percent = 0.5;            // สัดส่วนปิดบางส่วน (0-1)

input group "=== Structural Exit ==="
input bool Exit_On_OB_Invalidation = true;           // ปิดเมื่อ OB ที่เข้าเทรดถูก invalidate
input double OB_Buffer_Points = 5.0;                 // บัฟเฟอร์เพิ่มเติมจากขอบ OB (จุด)

input group "=== Recovery (Add-on) ==="
input bool Enable_Recovery = false;                  // เปิดใช้การเสริมไม้เพื่อกู้สถานะ
input double Recovery_Trigger_R = 0.5;               // ทริกเมื่อขาดทุนถึง -R ที่กำหนด
input double Recovery_ExtraRisk_Percent = 50.0;      // เสริมความเสี่ยงคิดเป็น % ของ Risk_Percent เดิม
input int Max_Recovery_Adds = 1;                     // จำนวนครั้งสูงสุดของการเสริมไม้
input double Recovery_Target_R = 1.2;                // เป้ากำไร (R) หลังเฉลี่ยราคา

input group "=== Daily Limits ==="
input int Max_Trades_Per_Day = 3;                    // จำนวนเทรดต่อวันสูงสุด
input double Max_Daily_Loss_Percent = 3.0;           // ขาดทุนสูงสุดต่อวัน (%)

input group "=== Order Block Detection ==="
input bool Use_OB_Detection = true;                  // เปิดใช้ Order Block Detection
input bool Draw_OB_Zones = true;                     // วาดโซน Order Block
input color OB_Bullish_Color = clrMediumSeaGreen;    // สี OB แบบขาขึ้น
input color OB_Bearish_Color = clrCrimson;           // สี OB แบบขาลง
input double OB_MinBodySize = 0.6;                   // ขนาดตัวแท่งขั้นต่ำสำหรับ OB (เป็นสัดส่วน)
input int OB_History_Bars = 30;                      // จำนวนแท่งย้อนหลังสำหรับหา OB

input group "=== Risk Management ==="
input double RiskPercent = 1.0;                      // เปอร์เซ็นต์ความเสี่ยงต่อการเทรด
input double ATR_Multiplier = 1.5;                   // ตัวคูณ ATR สำหรับ SL/TP
input bool DemoMode = true;                           // โหมดทดสอบ (ไม่เทรดจริง)

//+------------------------------------------------------------------+
//| Enum สำหรับทิศทาง HTF Structure                                  |
//+------------------------------------------------------------------+
enum ENUM_HTF_TREND {
    HTF_UPTREND,      // ทิศทางขึ้น
    HTF_DOWNTREND,    // ทิศทางลง  
    HTF_SIDEWAYS      // ไซด์เวย์
};

//+------------------------------------------------------------------+
//| BoS Structure                                                    |
//+------------------------------------------------------------------+
struct BoSData {
    bool detected;
    double level;
    datetime time;
    bool is_bullish;
    int confirm_count;
    int swing_index;
};

//+------------------------------------------------------------------+
//| Swing Point Structure                                            |
//+------------------------------------------------------------------+
struct SwingPoint {
    datetime time;
    double price;
    bool isHigh;
    int shift;
};

//+------------------------------------------------------------------+
//| Fair Value Gap Structure                                         |
//+------------------------------------------------------------------+
struct FVGData {
    datetime time;
    double top;
    double bottom;
    bool is_bullish;
    bool is_filled;
    int candle_index;
    string object_name;
};

//+------------------------------------------------------------------+
//| SMC Trading State Structures                                    |
//+------------------------------------------------------------------+
enum ENUM_SMC_STATE {
    SMC_WAIT_ALIGNMENT,     // รอ HTF/CTF alignment
    SMC_DETECT_BOS,         // รอ Break of Structure
    SMC_ANALYZE_PULLBACK,   // วิเคราะห์ Pullback
    SMC_DETECT_CHOCH,       // รอ Change of Character  
    SMC_ENTRY_SETUP,        // เตรียม Entry ที่ OB/FVG
    SMC_IN_POSITION         // อยู่ในเทรด
};

struct PullbackData {
    bool detected;
    bool ended;
    double extreme_price;
    datetime start_time;
    datetime end_time;
    int bar_count;
};

struct CHoCHData {
    bool detected;
    double level;
    datetime time;
    bool is_bullish_choch;
    int swing_broken_index;
};

struct EntrySetupData {
    bool ob_found;
    bool fvg_found;
    bool fibo_zone;
    double entry_price;
    double stop_loss;
    double take_profit;
    bool rejection_candle;
};

//+------------------------------------------------------------------+
//| Order Block Structure                                            |
//+------------------------------------------------------------------+
struct OrderBlockData {
    datetime time;
    double top;
    double bottom;
    bool is_bullish;
    bool is_used;
    int candle_index;
    string object_name;
    double volume;
};

//+------------------------------------------------------------------+
//| Global variables สำหรับ HTF/CTF tracking                        |
//+------------------------------------------------------------------+
ENUM_HTF_TREND g_HTF_Structure = HTF_SIDEWAYS;
ENUM_HTF_TREND g_CTF_Structure = HTF_SIDEWAYS;
datetime g_lastHTFAnalysis = 0;
datetime g_lastBarTime = 0;
double g_HTF_Slope = 0;
double g_CTF_Slope = 0;

// VWAP Variables
double g_VWAP_Current = 0;
double g_VWAP_Previous = 0;
double g_vwapValue = 0;

// BoS Detection Variables
bool g_BoS_Detected = false;
double g_BoS_Level = 0;
datetime g_BoS_Time = 0;
double g_HTF_Upper_Channel = 0;       // เส้นบน HTF Regression Channel
double g_Previous_High = 0;           // High ก่อนหน้า
double g_Previous_Low = 0;            // Low ก่อนหน้า
datetime g_Previous_High_Time = 0;
datetime g_Previous_Low_Time = 0;

// BoS and Swing Point Arrays
BoSData g_BoSInfo;
SwingPoint g_swingPoints[];

// FVG and Order Block Arrays
FVGData g_fvgZones[];
OrderBlockData g_orderBlocks[];

// SMC Trading State Variables
ENUM_SMC_STATE g_CurrentState = SMC_WAIT_ALIGNMENT;
PullbackData g_PullbackInfo;
CHoCHData g_CHoCHInfo; 
EntrySetupData g_EntryInfo;
bool g_TradeInProgress = false;
ulong g_CurrentTicket = 0;
double g_EntryPrice = 0;
double g_StopLoss = 0;
double g_TakeProfit = 0;
bool g_PartialTaken = false;
int g_TodayTrades = 0;
datetime g_CurrentDay = 0;
double g_DayStartEquity = 0;
int g_RecoveryAdds = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("SMC Regression Channel EA (Enhanced) initialized");
    Print("HTF Timeframe: ", EnumToString(HTF_Timeframe));
    Print("HTF Bars: ", HTF_Bars, ", CTF Bars: ", CTF_Bars);
    Print("Slope Threshold: ", Slope_Threshold);
    Print("BoS Detection: ", Use_BoS_Detection ? "Enabled" : "Disabled");
    Print("VWAP Drawing: ", Draw_VWAP ? "Enabled" : "Disabled");
    
    // Initialize trade objects
    trade.SetExpertMagicNumber(123456);
    trade.SetDeviationInPoints(3);
    
    // Initialize arrays
    ArrayResize(g_swingPoints, 0);
    ArrayResize(g_fvgZones, 0);
    ArrayResize(g_orderBlocks, 0);
    
    // Reset tracking structures
    ResetTrackingStructures();
    
    // วิเคราะห์ HTF เริ่มต้น
    g_HTF_Structure = AnalyzeHTF_RegressionChannel(HTF_Timeframe, HTF_Bars, Slope_Threshold);
    Print("Initial HTF Structure: ", EnumToString(g_HTF_Structure));
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    ObjectsDeleteAll(0, "HTF_");
    ObjectsDeleteAll(0, "CTF_");
    ObjectsDeleteAll(0, "ALIGNMENT_");
    ObjectsDeleteAll(0, "VWAP_");
    ObjectsDeleteAll(0, "BOS_");
    ObjectsDeleteAll(0, "FIBO_");
    ObjectsDeleteAll(0, "SWING_");
    ObjectsDeleteAll(0, "FVG_");
    ObjectsDeleteAll(0, "OB_");
    Comment("");
    Print("SMC Regression Channel EA (Enhanced) deinitialized");
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                     |
//+------------------------------------------------------------------+
bool IsNewBar() {
    datetime current_time = iTime(_Symbol, _Period, 0);
    if(current_time != g_lastBarTime) {
        g_lastBarTime = current_time;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Expert tick function - SMC Sequential Analysis (Enhanced)       |
//+------------------------------------------------------------------+
void OnTick() {
    // Priority 1: จัดการออเดอร์ที่เปิดอยู่ทุก tick (ไม่ต้องรอแท่งใหม่)
    if(positionInfo.Select(_Symbol)) {
        ManageOpenPositions();
        return;
    }

    // ทำงานเฉพาะแท่งปิดใหม่เท่านั้น (ตามหลักการ SMC)
    if(!IsNewBar()) return;
    
    // Priority 1: วิเคราะห์ HTF Structure และตรวจสอบการเปลี่ยนแปลง
    ENUM_HTF_TREND htf_new = AnalyzeHTF_RegressionChannel(HTF_Timeframe, HTF_Bars, Slope_Threshold);
    if(htf_new != g_HTF_Structure) {
        Print("HTF Structure changed: ", EnumToString(g_HTF_Structure), " -> ", EnumToString(htf_new));
        ClearFlowObjects();       // ล้าง SMC objects เก่า
        ResetTrackingStructures(); // รีเซ็ต states
        g_HTF_Structure = htf_new;
        return; // รอแท่งใหม่
    }
    
    // Priority 2: ตรวจสอบความสอดคล้องระหว่าง HTF และ CTF  
    bool aligned = IsCTFAlignedWithHTF();
    
    // Priority 3: VWAP calculation and drawing
    if(Use_VWAP) {
        CalculateVWAP();
        if(Draw_VWAP) DrawVWAPLine();
    }
    
    // Priority 4: BoS detection and drawing
    if(Use_BoS_Detection) {
        DetectAndDrawBoS();
    }
    
    // Priority 5: FVG detection and drawing
    if(Use_FVG_Detection) {
        DetectAndDrawFVG();
    }
    
    // Priority 6: Order Block detection and drawing
    if(Use_OB_Detection) {
        DetectAndDrawOrderBlocks();
    }
    
    // Priority 7: แสดงข้อมูลสำคัญ (Enhanced)
    UpdateStatusDisplay(aligned);
    
    // Priority 8: SMC Sequential Trading Logic
    if(aligned && Enable_Trading) {
        if(g_CurrentState == SMC_WAIT_ALIGNMENT) {
            g_CurrentState = SMC_DETECT_BOS; // เริ่มลำดับ SMC เมื่อโครงสร้างตรงกัน
        }
        ExecuteSMCSequentialLogic();
    } else if(aligned && !Enable_Trading) {
        Print("HTF/CTF Aligned - Ready for SMC Flow Analysis (Trading Disabled)");
    }
}

//+------------------------------------------------------------------+
//| Calculate VWAP                                                  |
//+------------------------------------------------------------------+
void CalculateVWAP() {
    double high[], low[], close[];
    long volume[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(volume, true);
    
    if(CopyHigh(_Symbol, _Period, 1, VWAP_Period, high) <= 0) return;
    if(CopyLow(_Symbol, _Period, 1, VWAP_Period, low) <= 0) return;
    if(CopyClose(_Symbol, _Period, 1, VWAP_Period, close) <= 0) return;
    if(CopyTickVolume(_Symbol, _Period, 1, VWAP_Period, volume) <= 0) return;
    
    double totalPriceVolume = 0;
    double totalVolume = 0;
    
    for(int i = 0; i < VWAP_Period; i++) {
        double typicalPrice = (high[i] + low[i] + close[i]) / 3.0;
        totalPriceVolume += typicalPrice * (double)volume[i];
        totalVolume += (double)volume[i];
    }
    
    if(totalVolume > 0) {
        g_vwapValue = totalPriceVolume / totalVolume;
    }
}

//+------------------------------------------------------------------+
//| Draw VWAP Line                                                  |
//+------------------------------------------------------------------+
void DrawVWAPLine() {
    if(g_vwapValue <= 0) return;
    
    string objName = "VWAP_LINE";
    datetime currentTime = iTime(_Symbol, _Period, 0);
    datetime startTime = iTime(_Symbol, _Period, VWAP_Period - 1);
    
    // Delete old line
    ObjectDelete(0, objName);
    
    // Create new VWAP line
    if(ObjectCreate(0, objName, OBJ_TREND, 0, startTime, g_vwapValue, currentTime, g_vwapValue)) {
        ObjectSetInteger(0, objName, OBJPROP_COLOR, VWAP_Color);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true);
        ObjectSetString(0, objName, OBJPROP_TOOLTIP, "VWAP: " + DoubleToString(g_vwapValue, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Utility: Trading session and spread filters                      |
//+------------------------------------------------------------------+
bool IsInTradingSession() {
    MqlDateTime t; TimeToStruct(iTime(_Symbol, _Period, 0), t);
    int hour = t.hour;
    if(Session_Start_Hour <= Session_End_Hour)
        return (hour >= Session_Start_Hour && hour < Session_End_Hour);
    // Overnight session (e.g., 22 -> 7)
    return (hour >= Session_Start_Hour || hour < Session_End_Hour);
}

bool IsSpreadOK() {
    double spreadPts = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
    return spreadPts <= Max_Spread_Points;
}

void EnsureDailyCounters() {
    MqlDateTime t; TimeToStruct(TimeCurrent(), t);
    MqlDateTime d; d.year=t.year; d.mon=t.mon; d.day=t.day; d.hour=0; d.min=0; d.sec=0;
    datetime dayStart = StructToTime(d);
    if(g_CurrentDay != dayStart) {
        g_CurrentDay = dayStart;
        g_TodayTrades = 0;
        g_DayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        g_RecoveryAdds = 0;
        g_PartialTaken = false;
    }
}

bool IsDailyLimitReached() {
    double eq = AccountInfoDouble(ACCOUNT_EQUITY);
    double ddPct = (g_DayStartEquity - eq) * 100.0 / MathMax(1e-6, g_DayStartEquity);
    if(g_TodayTrades >= Max_Trades_Per_Day) return true;
    if(ddPct >= Max_Daily_Loss_Percent) return true;
    return false;
}

int ComputeEntryScore(bool aligned) {
    if(!Use_Entry_Scoring) return 100;
    int score = 0;
    if(aligned) score += Score_TrendAlign;
    if(g_EntryInfo.ob_found) score += Score_OB;
    if(g_EntryInfo.fvg_found) score += Score_FVG;
    if(g_EntryInfo.fibo_zone) score += Score_Fibo;
    if(g_EntryInfo.rejection_candle) score += Score_Rejection;
    if(Use_VWAP && g_vwapValue > 0) {
        double price = iClose(_Symbol, _Period, 1);
        bool good = (g_CHoCHInfo.is_bullish_choch ? price >= g_vwapValue : price <= g_vwapValue);
        if(good) score += Score_VWAP;
    }
    return score;
}

//+------------------------------------------------------------------+
//| Find Swing Points                                               |
//+------------------------------------------------------------------+
void FindSwingPoints() {
    ArrayResize(g_swingPoints, 0);
    
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, _Period, 0, Swing_History_Bars, high) <= 0) return;
    if(CopyLow(_Symbol, _Period, 0, Swing_History_Bars, low) <= 0) return;
    
    // Find swing highs and lows
    for(int i = Swing_Detection_Depth; i < Swing_History_Bars - Swing_Detection_Depth; i++) {
        // Check for swing high
        bool isSwingHigh = true;
        for(int j = 1; j <= Swing_Detection_Depth; j++) {
            if(high[i] <= high[i-j] || high[i] <= high[i+j]) {
                isSwingHigh = false;
                break;
            }
        }
        
        if(isSwingHigh) {
            int size = ArraySize(g_swingPoints);
            ArrayResize(g_swingPoints, size + 1);
            g_swingPoints[size].time = iTime(_Symbol, _Period, i);
            g_swingPoints[size].price = high[i];
            g_swingPoints[size].isHigh = true;
            g_swingPoints[size].shift = i;
        }
        
        // Check for swing low
        bool isSwingLow = true;
        for(int j = 1; j <= Swing_Detection_Depth; j++) {
            if(low[i] >= low[i-j] || low[i] >= low[i+j]) {
                isSwingLow = false;
                break;
            }
        }
        
        if(isSwingLow) {
            int size = ArraySize(g_swingPoints);
            ArrayResize(g_swingPoints, size + 1);
            g_swingPoints[size].time = iTime(_Symbol, _Period, i);
            g_swingPoints[size].price = low[i];
            g_swingPoints[size].isHigh = false;
            g_swingPoints[size].shift = i;
        }
    }
    
    // Sort swing points by time (newest first)
    SortSwingPointsByTime();
}

//+------------------------------------------------------------------+
//| Sort Swing Points by Time                                       |
//+------------------------------------------------------------------+
void SortSwingPointsByTime() {
    int size = ArraySize(g_swingPoints);
    for(int i = 0; i < size - 1; i++) {
        for(int j = 0; j < size - i - 1; j++) {
            if(g_swingPoints[j].time < g_swingPoints[j+1].time) {
                SwingPoint temp = g_swingPoints[j];
                g_swingPoints[j] = g_swingPoints[j+1];
                g_swingPoints[j+1] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Detect and Draw Break of Structure                              |
//+------------------------------------------------------------------+
void DetectAndDrawBoS() {
    FindSwingPoints();
    
    if(ArraySize(g_swingPoints) < 4) return;
    
    // Get current price
    double currentPrice = iClose(_Symbol, _Period, 1); // Use closed bar
    
    // Separate swing highs and lows
    SwingPoint highPoints[], lowPoints[];
    
    for(int i = 0; i < ArraySize(g_swingPoints); i++) {
        if(g_swingPoints[i].isHigh) {
            int size = ArraySize(highPoints);
            ArrayResize(highPoints, size + 1);
            highPoints[size] = g_swingPoints[i];
        } else {
            int size = ArraySize(lowPoints);
            ArrayResize(lowPoints, size + 1);
            lowPoints[size] = g_swingPoints[i];
        }
    }
    
    if(ArraySize(highPoints) < 2 || ArraySize(lowPoints) < 2) return;
    
    // Check for Bullish BoS
    if(!g_BoS_Detected && currentPrice > highPoints[0].price) {
        if(ArraySize(highPoints) >= 3 && highPoints[1].price < highPoints[2].price) {
            g_BoSInfo.detected = true;
            g_BoSInfo.is_bullish = true;
            g_BoSInfo.level = highPoints[0].price;
            g_BoSInfo.time = iTime(_Symbol, _Period, 0);
            g_BoS_Detected = true;
            
            DrawBoSLine(g_BoSInfo.level, g_BoSInfo.is_bullish, g_BoSInfo.time);
            
            if(Auto_Draw_Fibo) {
                DrawFibonacciRetracement(highPoints[1].price, lowPoints[0].price, g_BoSInfo.time);
            }
            
            Print("Bullish BoS detected at level: ", DoubleToString(g_BoSInfo.level, _Digits));
        }
    }
    
    // Check for Bearish BoS
    if(!g_BoS_Detected && currentPrice < lowPoints[0].price) {
        if(ArraySize(lowPoints) >= 3 && lowPoints[1].price > lowPoints[2].price) {
            g_BoSInfo.detected = true;
            g_BoSInfo.is_bullish = false;
            g_BoSInfo.level = lowPoints[0].price;
            g_BoSInfo.time = iTime(_Symbol, _Period, 0);
            g_BoS_Detected = true;
            
            DrawBoSLine(g_BoSInfo.level, g_BoSInfo.is_bullish, g_BoSInfo.time);
            
            if(Auto_Draw_Fibo) {
                DrawFibonacciRetracement(lowPoints[1].price, highPoints[0].price, g_BoSInfo.time);
            }
            
            Print("Bearish BoS detected at level: ", DoubleToString(g_BoSInfo.level, _Digits));
        }
    }
}

//+------------------------------------------------------------------+
//| Detect and Draw Fair Value Gap                                  |
//+------------------------------------------------------------------+
void DetectAndDrawFVG() {
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, _Period, 0, FVG_History_Bars, high) <= 0) return;
    if(CopyLow(_Symbol, _Period, 0, FVG_History_Bars, low) <= 0) return;
    
    // Check for FVG in last few bars
    for(int i = 2; i < FVG_History_Bars - 1; i++) {
        // Bullish FVG: Low[i-1] > High[i+1] 
        if(low[i-1] > high[i+1]) {
            // Create FVG zone
            FVGData newFVG;
            newFVG.time = iTime(_Symbol, _Period, i);
            newFVG.top = low[i-1];
            newFVG.bottom = high[i+1];
            newFVG.is_bullish = true;
            newFVG.is_filled = false;
            newFVG.candle_index = i;
            newFVG.object_name = "FVG_BULL_" + TimeToString(newFVG.time, TIME_DATE|TIME_MINUTES);
            
            // Check if this FVG already exists
            if(!FVGExists(newFVG.object_name)) {
                AddFVG(newFVG);
                if(Draw_FVG_Zones) DrawFVGZone(newFVG);
            }
        }
        
        // Bearish FVG: High[i-1] < Low[i+1]
        if(high[i-1] < low[i+1]) {
            // Create FVG zone
            FVGData newFVG;
            newFVG.time = iTime(_Symbol, _Period, i);
            newFVG.top = low[i+1];
            newFVG.bottom = high[i-1];
            newFVG.is_bullish = false;
            newFVG.is_filled = false;
            newFVG.candle_index = i;
            newFVG.object_name = "FVG_BEAR_" + TimeToString(newFVG.time, TIME_DATE|TIME_MINUTES);
            
            // Check if this FVG already exists
            if(!FVGExists(newFVG.object_name)) {
                AddFVG(newFVG);
                if(Draw_FVG_Zones) DrawFVGZone(newFVG);
            }
        }
    }
    
    // Check if existing FVGs are filled
    CheckFVGsFilled();
}

//+------------------------------------------------------------------+
//| Check if FVG exists                                             |
//+------------------------------------------------------------------+
bool FVGExists(string objName) {
    for(int i = 0; i < ArraySize(g_fvgZones); i++) {
        if(g_fvgZones[i].object_name == objName) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add FVG to array                                                |
//+------------------------------------------------------------------+
void AddFVG(FVGData& fvg) {
    int size = ArraySize(g_fvgZones);
    ArrayResize(g_fvgZones, size + 1);
    g_fvgZones[size] = fvg;
}

//+------------------------------------------------------------------+
//| Draw FVG Zone                                                   |
//+------------------------------------------------------------------+
void DrawFVGZone(FVGData& fvg) {
    datetime startTime = fvg.time;
    datetime endTime = iTime(_Symbol, _Period, 0) + PeriodSeconds(_Period) * 20; // Extend to future
    
    if(ObjectCreate(0, fvg.object_name, OBJ_RECTANGLE, 0, startTime, fvg.top, endTime, fvg.bottom)) {
        ObjectSetInteger(0, fvg.object_name, OBJPROP_COLOR, fvg.is_bullish ? FVG_Bullish_Color : FVG_Bearish_Color);
        ObjectSetInteger(0, fvg.object_name, OBJPROP_FILL, true);
        ObjectSetInteger(0, fvg.object_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, fvg.object_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, fvg.object_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetString(0, fvg.object_name, OBJPROP_TOOLTIP, 
                       (fvg.is_bullish ? "Bullish" : "Bearish") + " FVG");
    }
}

//+------------------------------------------------------------------+
//| Check if FVGs are filled                                        |
//+------------------------------------------------------------------+
void CheckFVGsFilled() {
    double currentHigh = iHigh(_Symbol, _Period, 0);
    double currentLow = iLow(_Symbol, _Period, 0);
    
    for(int i = 0; i < ArraySize(g_fvgZones); i++) {
        if(!g_fvgZones[i].is_filled) {
            // Check if FVG is filled
            if(g_fvgZones[i].is_bullish) {
                // Bullish FVG is filled when price comes back down into the gap
                if(currentLow <= g_fvgZones[i].bottom) {
                    g_fvgZones[i].is_filled = true;
                    // Change color or remove object
                    ObjectSetInteger(0, g_fvgZones[i].object_name, OBJPROP_COLOR, clrGray);
                }
            } else {
                // Bearish FVG is filled when price comes back up into the gap
                if(currentHigh >= g_fvgZones[i].top) {
                    g_fvgZones[i].is_filled = true;
                    // Change color or remove object
                    ObjectSetInteger(0, g_fvgZones[i].object_name, OBJPROP_COLOR, clrGray);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Detect and Draw Order Blocks                                    |
//+------------------------------------------------------------------+
void DetectAndDrawOrderBlocks() {
    double high[], low[], open[], close[];
    long volume[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(volume, true);
    
    if(CopyHigh(_Symbol, _Period, 0, OB_History_Bars, high) <= 0) return;
    if(CopyLow(_Symbol, _Period, 0, OB_History_Bars, low) <= 0) return;
    if(CopyOpen(_Symbol, _Period, 0, OB_History_Bars, open) <= 0) return;
    if(CopyClose(_Symbol, _Period, 0, OB_History_Bars, close) <= 0) return;
    if(CopyTickVolume(_Symbol, _Period, 0, OB_History_Bars, volume) <= 0) return;
    
    // Look for Order Blocks
    for(int i = 1; i < OB_History_Bars - 1; i++) {
        double bodySize = MathAbs(close[i] - open[i]);
        double totalRange = high[i] - low[i];
        
        // Check if candle has significant body (Order Block criteria)
        if(totalRange > 0 && bodySize / totalRange >= OB_MinBodySize) {
            // Check for Bullish Order Block (strong bullish candle followed by continuation)
            if(close[i] > open[i] && close[i-1] > close[i]) { // Bullish candle with upward continuation
                OrderBlockData newOB;
                newOB.time = iTime(_Symbol, _Period, i);
                newOB.top = high[i];
                newOB.bottom = low[i];
                newOB.is_bullish = true;
                newOB.is_used = false;
                newOB.candle_index = i;
                newOB.volume = (double)volume[i];
                newOB.object_name = "OB_BULL_" + TimeToString(newOB.time, TIME_DATE|TIME_MINUTES);
                
                if(!OrderBlockExists(newOB.object_name)) {
                    AddOrderBlock(newOB);
                    if(Draw_OB_Zones) DrawOrderBlockZone(newOB);
                }
            }
            
            // Check for Bearish Order Block (strong bearish candle followed by continuation)
            if(close[i] < open[i] && close[i-1] < close[i]) { // Bearish candle with downward continuation
                OrderBlockData newOB;
                newOB.time = iTime(_Symbol, _Period, i);
                newOB.top = high[i];
                newOB.bottom = low[i];
                newOB.is_bullish = false;
                newOB.is_used = false;
                newOB.candle_index = i;
                newOB.volume = (double)volume[i];
                newOB.object_name = "OB_BEAR_" + TimeToString(newOB.time, TIME_DATE|TIME_MINUTES);
                
                if(!OrderBlockExists(newOB.object_name)) {
                    AddOrderBlock(newOB);
                    if(Draw_OB_Zones) DrawOrderBlockZone(newOB);
                }
            }
        }
    }
    
    // Check if Order Blocks are tested/used
    CheckOrderBlocksUsed();
}

//+------------------------------------------------------------------+
//| Check if Order Block exists                                     |
//+------------------------------------------------------------------+
bool OrderBlockExists(string objName) {
    for(int i = 0; i < ArraySize(g_orderBlocks); i++) {
        if(g_orderBlocks[i].object_name == objName) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Add Order Block to array                                        |
//+------------------------------------------------------------------+
void AddOrderBlock(OrderBlockData& ob) {
    int size = ArraySize(g_orderBlocks);
    ArrayResize(g_orderBlocks, size + 1);
    g_orderBlocks[size] = ob;
}

//+------------------------------------------------------------------+
//| Draw Order Block Zone                                           |
//+------------------------------------------------------------------+
void DrawOrderBlockZone(OrderBlockData& ob) {
    datetime startTime = ob.time;
    datetime endTime = iTime(_Symbol, _Period, 0) + PeriodSeconds(_Period) * 30; // Extend to future
    
    if(ObjectCreate(0, ob.object_name, OBJ_RECTANGLE, 0, startTime, ob.top, endTime, ob.bottom)) {
        ObjectSetInteger(0, ob.object_name, OBJPROP_COLOR, ob.is_bullish ? OB_Bullish_Color : OB_Bearish_Color);
        ObjectSetInteger(0, ob.object_name, OBJPROP_FILL, true);
        ObjectSetInteger(0, ob.object_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, ob.object_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, ob.object_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetString(0, ob.object_name, OBJPROP_TOOLTIP, 
                       (ob.is_bullish ? "Bullish" : "Bearish") + " Order Block");
    }
}

//+------------------------------------------------------------------+
//| Check if Order Blocks are used                                  |
//+------------------------------------------------------------------+
void CheckOrderBlocksUsed() {
    double currentHigh = iHigh(_Symbol, _Period, 0);
    double currentLow = iLow(_Symbol, _Period, 0);
    double currentClose = iClose(_Symbol, _Period, 0);
    
    for(int i = 0; i < ArraySize(g_orderBlocks); i++) {
        if(!g_orderBlocks[i].is_used) {
            // Check if Order Block is tested
            bool tested = false;
            if(g_orderBlocks[i].is_bullish) {
                // Bullish OB is tested when price comes back to the zone
                if(currentLow <= g_orderBlocks[i].top && currentHigh >= g_orderBlocks[i].bottom) {
                    tested = true;
                    // Check for rejection (price closes above the zone)
                    if(currentClose > g_orderBlocks[i].top) {
                        g_orderBlocks[i].is_used = true;
                        ObjectSetInteger(0, g_orderBlocks[i].object_name, OBJPROP_COLOR, clrGray);
                    }
                }
            } else {
                // Bearish OB is tested when price comes back to the zone
                if(currentHigh >= g_orderBlocks[i].bottom && currentLow <= g_orderBlocks[i].top) {
                    tested = true;
                    // Check for rejection (price closes below the zone)
                    if(currentClose < g_orderBlocks[i].bottom) {
                        g_orderBlocks[i].is_used = true;
                        ObjectSetInteger(0, g_orderBlocks[i].object_name, OBJPROP_COLOR, clrGray);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw BoS Line                                                   |
//+------------------------------------------------------------------+
void DrawBoSLine(double level, bool isBullish, datetime time) {
    string objName = "BOS_LINE_" + TimeToString(time, TIME_DATE|TIME_MINUTES);
    
    if(ObjectCreate(0, objName, OBJ_HLINE, 0, 0, level)) {
        ObjectSetInteger(0, objName, OBJPROP_COLOR, isBullish ? clrLime : clrRed);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetString(0, objName, OBJPROP_TOOLTIP, 
                       (isBullish ? "Bullish" : "Bearish") + " BoS: " + DoubleToString(level, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Draw Fibonacci Retracement                                      |
//+------------------------------------------------------------------+
void DrawFibonacciRetracement(double price1, double price2, datetime time) {
    string objName = "FIBO_" + TimeToString(time, TIME_DATE|TIME_MINUTES);
    datetime time1 = iTime(_Symbol, _Period, 10);
    datetime time2 = iTime(_Symbol, _Period, 0);
    
    if(ObjectCreate(0, objName, OBJ_FIBO, 0, time1, price1, time2, price2)) {
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGold);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, objName, OBJPROP_BACK, false);
        ObjectSetInteger(0, objName, OBJPROP_LEVELS, 9);
        
        // Set Fibonacci levels
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 0, 0.0);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 1, 0.236);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 2, 0.382);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 3, 0.5);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 4, 0.618);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 5, 0.786);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 6, 1.0);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 7, 1.272);
        ObjectSetDouble(0, objName, OBJPROP_LEVELVALUE, 8, 1.618);
        
        // Set level descriptions
        ObjectSetString(0, objName, OBJPROP_LEVELTEXT, 0, "0.0");
        ObjectSetString(0, objName, OBJPROP_LEVELTEXT, 1, "23.6");
        ObjectSetString(0, objName, OBJPROP_LEVELTEXT, 2, "38.2");
        ObjectSetString(0, objName, OBJPROP_LEVELTEXT, 3, "50.0");
        ObjectSetString(0, objName, OBJPROP_LEVELTEXT, 4, "61.8");
        ObjectSetString(0, objName, OBJPROP_LEVELTEXT, 5, "78.6");
        ObjectSetString(0, objName, OBJPROP_LEVELTEXT, 6, "100.0");
        ObjectSetString(0, objName, OBJPROP_LEVELTEXT, 7, "127.2");
        ObjectSetString(0, objName, OBJPROP_LEVELTEXT, 8, "161.8");
    }
}

//+------------------------------------------------------------------+
//| วิเคราะห์ HTF Structure ด้วย Regression Channel                  |
//+------------------------------------------------------------------+
ENUM_HTF_TREND AnalyzeHTF_RegressionChannel(
    ENUM_TIMEFRAMES htf_period = PERIOD_H4,
    int bars = 100,
    double slope_threshold = 0.00001
) {
    // ตรวจสอบการเปลี่ยนแปลง HTF (เฉพาะแท่งปิด)
    datetime htf_time = iTime(_Symbol, htf_period, 0);
    if(htf_time == g_lastHTFAnalysis) return g_HTF_Structure; // ยังไม่มีแท่งใหม่
    
    double price[];
    ArraySetAsSeries(price, true);
    if(CopyClose(_Symbol, htf_period, 1, bars, price) != bars) return HTF_SIDEWAYS;

    // คำนวณ Linear Regression
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    for(int i = 0; i < bars; i++) {
        sumX += i;
        sumY += price[i];
        sumXY += i * price[i];
        sumXX += i * i;
    }
    
    double slope = (bars * sumXY - sumX * sumY) / (bars * sumXX - sumX * sumX);
    g_HTF_Slope = slope;
    g_lastHTFAnalysis = htf_time;
    
    // กำหนดทิศทางตาม slope
    ENUM_HTF_TREND new_structure;
    if(slope > slope_threshold) {
        new_structure = HTF_UPTREND;
        DrawStdDevChannel("HTF", bars, htf_period, clrLime, clrLimeGreen, clrLimeGreen);
        Print("HTF Analysis: UPTREND (slope=", slope, ")");
    }
    else if(slope < -slope_threshold) {
        new_structure = HTF_DOWNTREND;
        DrawStdDevChannel("HTF", bars, htf_period, clrRed, clrCrimson, clrCrimson);
        Print("HTF Analysis: DOWNTREND (slope=", slope, ")");
    }
    else {
        new_structure = HTF_SIDEWAYS;
        DrawStdDevChannel("HTF", bars, htf_period, clrGray, clrSilver, clrSilver);
        Print("HTF Analysis: SIDEWAYS (slope=", slope, ")");
    }
    
    return new_structure;
}

//+------------------------------------------------------------------+
//| คำนวณ CTF Bars แบบ Dynamic ตามความผันผวน                        |
//+------------------------------------------------------------------+
int GetDynamicCTFBars() {
    if(!Use_Dynamic_CTF) return CTF_Bars;
    
    // คำนวณความผันผวนล่าสุด 10 แท่ง
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(_Symbol, _Period, 1, 10, high) != 10) return CTF_Bars;
    if(CopyLow(_Symbol, _Period, 1, 10, low) != 10) return CTF_Bars;
    
    double avg_range = 0;
    for(int i = 0; i < 10; i++) {
        avg_range += (high[i] - low[i]);
    }
    avg_range = avg_range / 10;
    
    // คำนวณ current range
    double current_range = iHigh(_Symbol, _Period, 1) - iLow(_Symbol, _Period, 1);
    double volatility_ratio = current_range / avg_range;
    
    // ถ้าความผันผวนสูง ใช้ bars น้อยลง, ถ้าต่ำ ใช้ bars มากขึ้น
    int dynamic_bars;
    if(volatility_ratio > 1.5) {
        dynamic_bars = CTF_Min_Bars; // ความผันผวนสูง -> sensitive มากขึ้น
    }
    else if(volatility_ratio < 0.7) {
        dynamic_bars = CTF_Max_Bars; // ความผันผวนต่ำ -> smooth มากขึ้น
    }
    else {
        dynamic_bars = CTF_Bars; // ใช้ค่าปกติ
    }
    
    return dynamic_bars;
}

//+------------------------------------------------------------------+
//| วิเคราะห์ CTF Structure ด้วย Regression Channel (Enhanced)       |
//+------------------------------------------------------------------+
ENUM_HTF_TREND AnalyzeCTF_RegressionChannel(
    int bars = 50,
    double slope_threshold = 0.00001
) {
    double price[];
    ArraySetAsSeries(price, true);
    if(CopyClose(_Symbol, _Period, 1, bars, price) != bars) return HTF_SIDEWAYS;

    // คำนวณ Linear Regression สำหรับ CTF
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    for(int i = 0; i < bars; i++) {
        sumX += i;
        sumY += price[i];
        sumXY += i * price[i];
        sumXX += i * i;
    }
    
    double slope = (bars * sumXY - sumX * sumY) / (bars * sumXX - sumX * sumX);
    g_CTF_Slope = slope;
    
    // กำหนดทิศทาง CTF
    if(slope > slope_threshold) {
        DrawStdDevChannel("CTF", bars, _Period, clrAqua, clrDeepSkyBlue, clrDeepSkyBlue);
        return HTF_UPTREND;
    }
    else if(slope < -slope_threshold) {
        DrawStdDevChannel("CTF", bars, _Period, clrOrange, clrOrangeRed, clrOrangeRed);
        return HTF_DOWNTREND;
    }
    else {
        DrawStdDevChannel("CTF", bars, _Period, clrYellow, clrGold, clrGold);
        return HTF_SIDEWAYS;
    }
}

//+------------------------------------------------------------------+
//| ตรวจสอบความสอดคล้องระหว่าง HTF และ CTF                           |
//+------------------------------------------------------------------+
bool IsCTFAlignedWithHTF() {
    // ใช้ Dynamic CTF Bars หรือค่าคงที่
    int ctf_bars_to_use = GetDynamicCTFBars();
    
    // อัปเดต CTF Structure ด้วย bars ที่ปรับแล้ว
    g_CTF_Structure = AnalyzeCTF_RegressionChannel(ctf_bars_to_use, Slope_Threshold);
    
    // ตรวจสอบความสอดคล้อง
    bool aligned = false;
    
    if(g_HTF_Structure == HTF_UPTREND && g_CTF_Structure == HTF_UPTREND) {
        aligned = true;
        Print("★ ALIGNMENT: BULLISH - HTF และ CTF ทั้งคู่เป็น UPTREND (CTF Bars: ", ctf_bars_to_use, ")");
    }
    else if(g_HTF_Structure == HTF_DOWNTREND && g_CTF_Structure == HTF_DOWNTREND) {
        aligned = true;
        Print("★ ALIGNMENT: BEARISH - HTF และ CTF ทั้งคู่เป็น DOWNTREND (CTF Bars: ", ctf_bars_to_use, ")");
    }
    else {
        Print("⚠ No Alignment - HTF: ", EnumToString(g_HTF_Structure), ", CTF: ", EnumToString(g_CTF_Structure), " (CTF Bars: ", ctf_bars_to_use, ")");
    }
    
    // วาด Status Label
    string status = aligned ? "ALIGNED" : "NOT ALIGNED";
    color statusColor = aligned ? clrLime : clrRed;
    DrawAlignmentStatus(status, statusColor, ctf_bars_to_use);
    
    return aligned;
}

//+------------------------------------------------------------------+
//| Enhanced Status Display                                         |
//+------------------------------------------------------------------+
void UpdateStatusDisplay(bool aligned) {
    string status = "=== SMC ENHANCED ANALYSIS ===\n";
    status += StringFormat("HTF (%s): %s (Slope: %.8f)\n", 
                          EnumToString(HTF_Timeframe), 
                          EnumToString(g_HTF_Structure), 
                          g_HTF_Slope);
    status += StringFormat("CTF (%s): %s (Slope: %.8f)\n", 
                          EnumToString(_Period),
                          EnumToString(g_CTF_Structure),
                          g_CTF_Slope);
    status += "Alignment: " + (aligned ? "ALIGNED ✓" : "NOT ALIGNED ✗") + "\n";
    
    if(Use_VWAP) {
        status += "VWAP: " + DoubleToString(g_vwapValue, _Digits) + "\n";
    }
    
    if(Use_BoS_Detection) {
        status += "BoS Detected: " + (g_BoS_Detected ? "YES" : "NO") + "\n";
        if(g_BoS_Detected) {
            status += "BoS Type: " + (g_BoSInfo.is_bullish ? "BULLISH" : "BEARISH") + "\n";
            status += "BoS Level: " + DoubleToString(g_BoSInfo.level, _Digits) + "\n";
        }
    }
    
    if(Use_FVG_Detection) {
        status += "FVG Zones: " + IntegerToString(ArraySize(g_fvgZones)) + "\n";
    }
    
    if(Use_OB_Detection) {
        status += "OB Zones: " + IntegerToString(ArraySize(g_orderBlocks)) + "\n";
    }
    
    status += "---\n";
    status += "Next Step: " + (aligned ? "Ready for SMC Analysis (BoS, Pullback, CHoCH)" : "Wait for HTF/CTF Alignment");
    
    Comment(status);
}

//+------------------------------------------------------------------+
//| วาด Status Alignment บนชาร์ต (Enhanced)                         |
//+------------------------------------------------------------------+
void DrawAlignmentStatus(string status, color clr, int ctf_bars_used = 0) {
    string objName = "ALIGNMENT_STATUS";
    ObjectDelete(0, objName);
    ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, objName, OBJPROP_TEXT, "HTF/CTF: " + status);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 50);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 12);
    ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
    
    // วาด Slope Values และ CTF Bars
    string slopeInfo = "SLOPE_INFO";
    ObjectDelete(0, slopeInfo);
    ObjectCreate(0, slopeInfo, OBJ_LABEL, 0, 0, 0);
    string info_text = StringFormat("HTF Slope: %.8f | CTF Slope: %.8f", g_HTF_Slope, g_CTF_Slope);
    if(ctf_bars_used > 0) {
        info_text += StringFormat(" | CTF Bars: %d", ctf_bars_used);
    }
    ObjectSetString(0, slopeInfo, OBJPROP_TEXT, info_text);
    ObjectSetInteger(0, slopeInfo, OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, slopeInfo, OBJPROP_YDISTANCE, 70);
    ObjectSetInteger(0, slopeInfo, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, slopeInfo, OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
//| วาด Standard Deviation Channel (Enhanced)                       |
//+------------------------------------------------------------------+
void DrawStdDevChannel(
    string prefix,
    int    bars,
    ENUM_TIMEFRAMES timeframe,
    color  clrMain = clrDodgerBlue,
    color  clrUpper = clrDeepSkyBlue,
    color  clrLower = clrDeepSkyBlue,
    int    width = 2
) {
    double price[];
    datetime times[];
    ArraySetAsSeries(price, true);
    ArraySetAsSeries(times, true);

    if(CopyClose(_Symbol, timeframe, 0, bars, price) != bars) return;
    if(CopyTime(_Symbol, timeframe, 0, bars, times) != bars) return;

    // Linear regression calculation
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    for(int i = 0; i < bars; i++) {
        sumX += i;
        sumY += price[i];
        sumXY += i * price[i];
        sumXX += i * i;
    }
    double slope = (bars * sumXY - sumX * sumY) / (bars * sumXX - sumX * sumX);
    double intercept = (sumY - slope * sumX) / bars;

    // Calculate regression line and stddev
    double reg[], dev = 0;
    ArrayResize(reg, bars);
    for(int i = 0; i < bars; i++) {
        reg[i] = intercept + slope * i;
        dev += MathPow(price[i] - reg[i], 2);
    }
    dev = MathSqrt(dev / bars);

    // Draw main regression line
    string objMain = prefix + "_REGRESSION_MAIN";
    ObjectDelete(0, objMain);
    ObjectCreate(0, objMain, OBJ_TREND, 0, times[bars-1], reg[bars-1], times[0], reg[0]);
    ObjectSetInteger(0, objMain, OBJPROP_COLOR, clrMain);
    ObjectSetInteger(0, objMain, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, objMain, OBJPROP_RAY_RIGHT, true);
    ObjectSetInteger(0, objMain, OBJPROP_STYLE, STYLE_SOLID);

    // Draw upper channel
    string objUpper = prefix + "_REGRESSION_UPPER";
    ObjectDelete(0, objUpper);
    ObjectCreate(0, objUpper, OBJ_TREND, 0, times[bars-1], reg[bars-1]+dev, times[0], reg[0]+dev);
    ObjectSetInteger(0, objUpper, OBJPROP_COLOR, clrUpper);
    ObjectSetInteger(0, objUpper, OBJPROP_WIDTH, width-1);
    ObjectSetInteger(0, objUpper, OBJPROP_RAY_RIGHT, true);
    ObjectSetInteger(0, objUpper, OBJPROP_STYLE, STYLE_DOT);

    // Draw lower channel
    string objLower = prefix + "_REGRESSION_LOWER";
    ObjectDelete(0, objLower);
    ObjectCreate(0, objLower, OBJ_TREND, 0, times[bars-1], reg[bars-1]-dev, times[0], reg[0]-dev);
    ObjectSetInteger(0, objLower, OBJPROP_COLOR, clrLower);
    ObjectSetInteger(0, objLower, OBJPROP_WIDTH, width-1);
    ObjectSetInteger(0, objLower, OBJPROP_RAY_RIGHT, true);
    ObjectSetInteger(0, objLower, OBJPROP_STYLE, STYLE_DOT);

    // Add channel label
    string objLabel = prefix + "_LABEL";
    ObjectDelete(0, objLabel);
    ObjectCreate(0, objLabel, OBJ_TEXT, 0, times[5], reg[5]);
    ObjectSetString(0, objLabel, OBJPROP_TEXT, prefix + " Channel");
    ObjectSetInteger(0, objLabel, OBJPROP_COLOR, clrMain);
    ObjectSetInteger(0, objLabel, OBJPROP_FONTSIZE, 8);
}

//+------------------------------------------------------------------+
//| ล้าง SMC Flow Objects (เรียกเมื่อ HTF เปลี่ยน)                   |
//+------------------------------------------------------------------+
void ClearFlowObjects() {
    ObjectsDeleteAll(0, "BOS_");
    ObjectsDeleteAll(0, "PULLBACK_");
    ObjectsDeleteAll(0, "CHOCH_");
    ObjectsDeleteAll(0, "OB_");
    ObjectsDeleteAll(0, "FIBO_");
    ObjectsDeleteAll(0, "STATUS_");
    ObjectsDeleteAll(0, "VWAP_");
    ObjectsDeleteAll(0, "SWING_");
    ObjectsDeleteAll(0, "FVG_");
    Print("SMC Flow Objects cleared due to HTF structure change");
}

//+------------------------------------------------------------------+
//| รีเซ็ต Tracking Structures (เรียกเมื่อ HTF เปลี่ยน)              |
//+------------------------------------------------------------------+
void ResetTrackingStructures() {
    // รีเซ็ตค่า global tracking variables ต่างๆ
    g_BoS_Detected = false;
    g_BoSInfo.detected = false;
    g_BoSInfo.level = 0;
    g_BoSInfo.time = 0;
    g_BoSInfo.is_bullish = false;
    g_BoSInfo.confirm_count = 0;
    g_BoSInfo.swing_index = 0;
    
    // Reset VWAP
    g_vwapValue = 0;
    g_VWAP_Current = 0;
    g_VWAP_Previous = 0;
    
    ArrayResize(g_swingPoints, 0);
    ArrayResize(g_fvgZones, 0);
    ArrayResize(g_orderBlocks, 0);
    
    // Reset SMC Trading States
    g_CurrentState = SMC_WAIT_ALIGNMENT;
    g_PullbackInfo.detected = false;
    g_PullbackInfo.ended = false;
    g_CHoCHInfo.detected = false;
    g_TradeInProgress = false;
    g_CurrentTicket = 0;
    
    Print("SMC Tracking Structures reset due to HTF structure change");
}

//+------------------------------------------------------------------+
//| SMC Sequential Trading Logic (Main State Machine)              |
//+------------------------------------------------------------------+
void ExecuteSMCSequentialLogic() {
    // State 1: Check for existing positions first
    if(positionInfo.Select(_Symbol)) {
        ManageOpenPositions();
        return;
    }
    EnsureDailyCounters();
    if(IsDailyLimitReached()) { Print("Daily limits reached."); return; }
    
    // State Machine Flow
    switch(g_CurrentState) {
        case SMC_WAIT_ALIGNMENT:
            // Already handled in main OnTick - should not reach here
            break;
            
        case SMC_DETECT_BOS:
            if(!g_BoSInfo.detected) {
                if(DetectBoS_MultiBarConfirm()) {
                    Print("BoS Detected - Level: ", g_BoSInfo.level, " Type: ", g_BoSInfo.is_bullish ? "BULLISH" : "BEARISH");
                    g_CurrentState = SMC_ANALYZE_PULLBACK;
                    ResetPullbackTracking();
                }
            } else {
                // Ensure swing index is populated for downstream CHoCH logic
                if(g_BoSInfo.swing_index < 1) {
                    DetectBoS_MultiBarConfirm();
                }
                g_CurrentState = SMC_ANALYZE_PULLBACK;
            }
            break;
            
        case SMC_ANALYZE_PULLBACK:
            AnalyzePullback();
            if(g_PullbackInfo.ended) {
                Print("Pullback Ended - Extreme: ", g_PullbackInfo.extreme_price);
                g_CurrentState = SMC_DETECT_CHOCH;
            }
            break;
            
        case SMC_DETECT_CHOCH:
            if(DetectCHoCH()) {
                Print("CHoCH Detected - Level: ", g_CHoCHInfo.level, " Type: ", g_CHoCHInfo.is_bullish_choch ? "BULLISH" : "BEARISH");
                g_CurrentState = SMC_ENTRY_SETUP;
                PrepareEntrySetup();
            }
            break;
            
        case SMC_ENTRY_SETUP:
            if(!IsInTradingSession()) { Print("Outside trading session"); break; }
            if(!IsSpreadOK()) { Print("Spread too wide"); break; }
            if(ValidateEntryConditions()) {
                int score = ComputeEntryScore(true);
                if(Use_Entry_Scoring && score < Min_Entry_Score) { Print("Entry score too low: ", score); break; }
                if(ExecuteMarketEntry()) {
                    g_CurrentState = SMC_IN_POSITION;
                    g_TradeInProgress = true;
                    g_TodayTrades++;
                    g_PartialTaken = false;
                    Print("Trade Executed Successfully");
                }
            }
            break;
            
        case SMC_IN_POSITION:
            ManageOpenPositions();
            break;
    }
}

//+------------------------------------------------------------------+
//| Detect BoS with Multi-Bar Confirmation                         |
//+------------------------------------------------------------------+
bool DetectBoS_MultiBarConfirm() {
    // Ensure swing points are up to date
    FindSwingPoints();
    if(ArraySize(g_swingPoints) < 2) return false;
    
    // Use most recent swing (array sorted newest first)
    int lastSwingIndex = 0;
    SwingPoint lastSwing = g_swingPoints[lastSwingIndex];
    
    // Check for BoS break with confirmation
    if(lastSwing.isHigh) {
        // Look for bullish BoS (break above swing high)
        bool breakConfirmed = true;
        for(int i = 1; i <= BoS_ConfirmBars; i++) {
            if(iClose(_Symbol, _Period, i) <= lastSwing.price) {
                breakConfirmed = false;
                break;
            }
        }
        
        if(breakConfirmed) {
            g_BoSInfo.detected = true;
            g_BoSInfo.level = lastSwing.price;
            g_BoSInfo.time = lastSwing.time;
            g_BoSInfo.is_bullish = true;
            g_BoSInfo.confirm_count = BoS_ConfirmBars;
            g_BoSInfo.swing_index = lastSwingIndex;
            return true;
        }
    } else {
        // Look for bearish BoS (break below swing low)  
        bool breakConfirmed = true;
        for(int i = 1; i <= BoS_ConfirmBars; i++) {
            if(iClose(_Symbol, _Period, i) >= lastSwing.price) {
                breakConfirmed = false;
                break;
            }
        }
        
        if(breakConfirmed) {
            g_BoSInfo.detected = true;
            g_BoSInfo.level = lastSwing.price;
            g_BoSInfo.time = lastSwing.time;
            g_BoSInfo.is_bullish = false;
            g_BoSInfo.confirm_count = BoS_ConfirmBars;
            g_BoSInfo.swing_index = lastSwingIndex;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Reset Pullback Tracking                                         |
//+------------------------------------------------------------------+
void ResetPullbackTracking() {
    g_PullbackInfo.detected = true;
    g_PullbackInfo.ended = false;
    g_PullbackInfo.extreme_price = g_BoSInfo.is_bullish ? iHigh(_Symbol, _Period, 1) : iLow(_Symbol, _Period, 1);
    g_PullbackInfo.start_time = iTime(_Symbol, _Period, 1);
    g_PullbackInfo.end_time = 0;
    g_PullbackInfo.bar_count = 0;
}

//+------------------------------------------------------------------+
//| Analyze Pullback Progress                                       |
//+------------------------------------------------------------------+
void AnalyzePullback() {
    if(!g_PullbackInfo.detected) return;
    
    g_PullbackInfo.bar_count++;
    
    // Update extreme price
    if(g_BoSInfo.is_bullish) {
        // Bullish BoS - track pullback low
        double currentLow = iLow(_Symbol, _Period, 1);
        if(currentLow < g_PullbackInfo.extreme_price) {
            g_PullbackInfo.extreme_price = currentLow;
        }
        
        // Check pullback end (price starts moving up)
        bool pullbackEnd = true;
        for(int i = 1; i <= Pullback_ConfirmBars; i++) {
            if(iClose(_Symbol, _Period, i) <= g_PullbackInfo.extreme_price) {
                pullbackEnd = false;
                break;
            }
        }
        
        if(pullbackEnd) {
            g_PullbackInfo.ended = true;
            g_PullbackInfo.end_time = iTime(_Symbol, _Period, 1);
        }
    } else {
        // Bearish BoS - track pullback high
        double currentHigh = iHigh(_Symbol, _Period, 1);
        if(currentHigh > g_PullbackInfo.extreme_price) {
            g_PullbackInfo.extreme_price = currentHigh;
        }
        
        // Check pullback end (price starts moving down)
        bool pullbackEnd = true;
        for(int i = 1; i <= Pullback_ConfirmBars; i++) {
            if(iClose(_Symbol, _Period, i) >= g_PullbackInfo.extreme_price) {
                pullbackEnd = false;
                break;
            }
        }
        
        if(pullbackEnd) {
            g_PullbackInfo.ended = true;
            g_PullbackInfo.end_time = iTime(_Symbol, _Period, 1);
        }
    }
}

//+------------------------------------------------------------------+
//| Detect Change of Character (CHoCH)                             |
//+------------------------------------------------------------------+
bool DetectCHoCH() {
    if(!g_PullbackInfo.ended) return false;
    
    // CHoCH occurs when price breaks the previous swing in opposite direction
    // For bullish BoS: CHoCH = break below previous swing low
    // For bearish BoS: CHoCH = break above previous swing high
    
    // Ensure we have enough swings relative to BoS swing index
    if(g_BoSInfo.swing_index < 1 || ArraySize(g_swingPoints) <= g_BoSInfo.swing_index - 1) return false;
    
    SwingPoint previousSwing = g_swingPoints[g_BoSInfo.swing_index - 1];
    
    if(g_BoSInfo.is_bullish) {
        // Look for break below previous swing low
        bool chochConfirmed = true;
        for(int i = 1; i <= CHoCH_ConfirmBars; i++) {
            if(iClose(_Symbol, _Period, i) >= previousSwing.price) {
                chochConfirmed = false;
                break;
            }
        }
        
        if(chochConfirmed) {
            g_CHoCHInfo.detected = true;
            g_CHoCHInfo.level = previousSwing.price;
            g_CHoCHInfo.time = iTime(_Symbol, _Period, 1);
            g_CHoCHInfo.is_bullish_choch = false; // Break below = bearish CHoCH
            g_CHoCHInfo.swing_broken_index = g_BoSInfo.swing_index - 1;
            return true;
        }
    } else {
        // Look for break above previous swing high
        bool chochConfirmed = true;
        for(int i = 1; i <= CHoCH_ConfirmBars; i++) {
            if(iClose(_Symbol, _Period, i) <= previousSwing.price) {
                chochConfirmed = false;
                break;
            }
        }
        
        if(chochConfirmed) {
            g_CHoCHInfo.detected = true;
            g_CHoCHInfo.level = previousSwing.price;
            g_CHoCHInfo.time = iTime(_Symbol, _Period, 1);
            g_CHoCHInfo.is_bullish_choch = true; // Break above = bullish CHoCH
            g_CHoCHInfo.swing_broken_index = g_BoSInfo.swing_index - 1;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Prepare Entry Setup                                             |
//+------------------------------------------------------------------+
void PrepareEntrySetup() {
    g_EntryInfo.ob_found = false;
    g_EntryInfo.fvg_found = false;
    g_EntryInfo.fibo_zone = false;
    g_EntryInfo.entry_price = 0;
    g_EntryInfo.stop_loss = 0;
    g_EntryInfo.take_profit = 0;
    g_EntryInfo.rejection_candle = false;
    
    // Look for Order Block in pullback zone
    CheckOrderBlockEntry();
    
    // Look for FVG in pullback zone
    CheckFVGEntry();
    
    // Calculate Fibonacci retracement zone (50%-61.8%)
    CalculateFibonacciEntry();
}

//+------------------------------------------------------------------+
//| Check Order Block Entry Opportunity                            |
//+------------------------------------------------------------------+
void CheckOrderBlockEntry() {
    double currentPrice = iClose(_Symbol, _Period, 1);
    
    for(int i = 0; i < ArraySize(g_orderBlocks); i++) {
        OrderBlockData ob = g_orderBlocks[i];
        if(ob.is_used) continue;
        
        // Check if current price is testing the OB zone
        if(g_CHoCHInfo.is_bullish_choch) {
            // Bullish CHoCH - look for bullish OB test
            if(ob.is_bullish && currentPrice >= ob.bottom && currentPrice <= ob.top) {
                g_EntryInfo.ob_found = true;
                g_EntryInfo.entry_price = ob.bottom; // Enter at OB support
                break;
            }
        } else {
            // Bearish CHoCH - look for bearish OB test  
            if(!ob.is_bullish && currentPrice >= ob.bottom && currentPrice <= ob.top) {
                g_EntryInfo.ob_found = true;
                g_EntryInfo.entry_price = ob.top; // Enter at OB resistance
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check FVG Entry Opportunity                                     |
//+------------------------------------------------------------------+
void CheckFVGEntry() {
    double currentPrice = iClose(_Symbol, _Period, 1);
    
    for(int i = 0; i < ArraySize(g_fvgZones); i++) {
        FVGData fvg = g_fvgZones[i];
        if(fvg.is_filled) continue;
        
        // Normalize FVG bounds and check if current price is testing the FVG zone
        double fvgLow = MathMin(fvg.bottom, fvg.top);
        double fvgHigh = MathMax(fvg.bottom, fvg.top);
        if(currentPrice >= fvgLow && currentPrice <= fvgHigh) {
            g_EntryInfo.fvg_found = true;
            if(!g_EntryInfo.ob_found) { // Use FVG entry if no OB found
                g_EntryInfo.entry_price = fvg.is_bullish ? fvg.bottom : fvg.top;
            }
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate Fibonacci Entry Zone                                  |
//+------------------------------------------------------------------+
void CalculateFibonacciEntry() {
    if(!g_PullbackInfo.ended) return;
    
    double high_point = g_BoSInfo.is_bullish ? g_PullbackInfo.extreme_price : g_BoSInfo.level;
    double low_point = g_BoSInfo.is_bullish ? g_BoSInfo.level : g_PullbackInfo.extreme_price;
    
    double range = high_point - low_point;
    double fib_50 = low_point + (range * 0.5);
    double fib_618 = low_point + (range * 0.618);
    
    double currentPrice = iClose(_Symbol, _Period, 1);
    
    // Check if price is in 50%-61.8% zone
    if(currentPrice >= fib_50 && currentPrice <= fib_618) {
        g_EntryInfo.fibo_zone = true;
        if(!g_EntryInfo.ob_found && !g_EntryInfo.fvg_found) {
            g_EntryInfo.entry_price = fib_618; // Enter at golden ratio
        }
    }
}

//+------------------------------------------------------------------+
//| Validate Entry Conditions                                       |
//+------------------------------------------------------------------+
bool ValidateEntryConditions() {
    // Must have at least one confluence
    if(!g_EntryInfo.ob_found && !g_EntryInfo.fvg_found && !g_EntryInfo.fibo_zone) {
        return false;
    }
    
    // Check for rejection candle
    CheckRejectionCandle();
    
    // Calculate stop loss and take profit
    CalculateStopLossAndTakeProfit();
    
    return g_EntryInfo.rejection_candle && g_EntryInfo.entry_price > 0 && g_EntryInfo.stop_loss > 0;
}

//+------------------------------------------------------------------+
//| Check for Rejection Candle                                     |
//+------------------------------------------------------------------+
void CheckRejectionCandle() {
    double open = iOpen(_Symbol, _Period, 1);
    double high = iHigh(_Symbol, _Period, 1);
    double low = iLow(_Symbol, _Period, 1);
    double close = iClose(_Symbol, _Period, 1);
    
    double body = MathAbs(close - open);
    double upperWick = high - MathMax(open, close);
    double lowerWick = MathMin(open, close) - low;
    
    if(g_CHoCHInfo.is_bullish_choch) {
        // Bullish entry - look for bullish rejection (long lower wick)
        g_EntryInfo.rejection_candle = (lowerWick > body * 1.5 && close > open);
    } else {
        // Bearish entry - look for bearish rejection (long upper wick)
        g_EntryInfo.rejection_candle = (upperWick > body * 1.5 && close < open);
    }
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss and Take Profit                            |
//+------------------------------------------------------------------+
void CalculateStopLossAndTakeProfit() {
    double atr = GetATR();
    
    if(g_CHoCHInfo.is_bullish_choch) {
        // Bullish entry
        g_EntryInfo.stop_loss = g_EntryInfo.entry_price - (atr * ATR_SL_Multiplier);
        double risk = g_EntryInfo.entry_price - g_EntryInfo.stop_loss;
        g_EntryInfo.take_profit = g_EntryInfo.entry_price + (risk * Risk_Reward_Ratio);
    } else {
        // Bearish entry
        g_EntryInfo.stop_loss = g_EntryInfo.entry_price + (atr * ATR_SL_Multiplier);
        double risk = g_EntryInfo.stop_loss - g_EntryInfo.entry_price;
        g_EntryInfo.take_profit = g_EntryInfo.entry_price - (risk * Risk_Reward_Ratio);
    }
}

//+------------------------------------------------------------------+
//| Execute Market Entry                                            |
//+------------------------------------------------------------------+
bool ExecuteMarketEntry() {
    // Calculate lot size based on risk management
    double lotSize = CalculateLotSize(g_EntryInfo.entry_price, g_EntryInfo.stop_loss);
    
    bool success = false;
    if(g_CHoCHInfo.is_bullish_choch) {
        success = trade.Buy(lotSize, _Symbol, 0, g_EntryInfo.stop_loss, g_EntryInfo.take_profit, "SMC BUY");
    } else {
        success = trade.Sell(lotSize, _Symbol, 0, g_EntryInfo.stop_loss, g_EntryInfo.take_profit, "SMC SELL");
    }
    
    if(success) {
        g_CurrentTicket = trade.ResultOrder();
        g_EntryPrice = trade.ResultPrice();
        g_StopLoss = g_EntryInfo.stop_loss;
        g_TakeProfit = g_EntryInfo.take_profit;
        
        Print("Trade executed: SMC ", (g_CHoCHInfo.is_bullish_choch ? "BUY" : "SELL"), " at ", g_EntryPrice, " SL: ", g_StopLoss, " TP: ", g_TakeProfit);
        return true;
    } else {
        Print("Order failed: ", trade.ResultRetcode(), " - ", trade.ResultComment());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk Management                     |
//+------------------------------------------------------------------+
double CalculateLotSize(double entry, double stopLoss) {
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * Risk_Percent / 100.0;
    double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    double pipsRisk = MathAbs(entry - stopLoss) / pointSize;
    double lotSize = riskAmount / (pipsRisk * pointValue);
    
    // Apply broker constraints
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    lotSize = NormalizeDouble(lotSize / stepLot, 0) * stepLot;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Manage Open Positions                                           |
//+------------------------------------------------------------------+
void ManageOpenPositions() {
    if(!positionInfo.Select(_Symbol)) {
        // Position closed - reset state
        g_CurrentState = SMC_DETECT_BOS;
        g_TradeInProgress = false;
        g_CurrentTicket = 0;
        ResetSMCStates();
        Print("Position closed - Resetting SMC states");
        return;
    }
    
    double currentPrice = g_CHoCHInfo.is_bullish_choch ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double positionProfit = positionInfo.Profit();
    double entryPrice = positionInfo.PriceOpen();
    double sl = positionInfo.StopLoss();
    double tp = positionInfo.TakeProfit();
    double risk = MathAbs(entryPrice - sl);
    
    // Breakeven management
    if(Use_Breakeven && positionProfit > 0) {
        if(MathAbs(currentPrice - entryPrice) >= risk) { // 1R profit
            if(MathAbs(g_StopLoss - g_EntryPrice) > _Point) { // Not already at breakeven
                ModifyStopLoss(g_EntryPrice + (g_CHoCHInfo.is_bullish_choch ? _Point : -_Point));
                Print("Moved to Breakeven");
            }
        }
    }
    
    // Partial TP at R multiple
    if(Use_Partial_TP && !g_PartialTaken) {
        double targetMove = risk * Partial_TP_R;
        bool hit = g_CHoCHInfo.is_bullish_choch ? (currentPrice - entryPrice >= targetMove) : (entryPrice - currentPrice >= targetMove);
        if(hit) {
            double vol = positionInfo.Volume();
            double closeVol = MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), vol * Partial_Close_Percent);
            closeVol = NormalizeDouble(closeVol / SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP), 0) * SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            if(closeVol < vol) {
                if(trade.PositionClosePartial(_Symbol, closeVol)) {
                    g_PartialTaken = true;
                    Print("Partial TP executed: ", closeVol);
                }
            }
        }
    }

    // Structural exit: OB invalidation
    if(Exit_On_OB_Invalidation && g_EntryInfo.ob_found) {
        for(int i = 0; i < ArraySize(g_orderBlocks); i++) {
            OrderBlockData ob = g_orderBlocks[i];
            if(g_CHoCHInfo.is_bullish_choch && ob.is_bullish) {
                double buffer = OB_Buffer_Points * _Point;
                if(currentPrice < (ob.bottom - buffer)) {
                    trade.PositionClose(_Symbol);
                    Print("Exit on OB invalidation (bullish)");
                    return;
                }
            } else if(!g_CHoCHInfo.is_bullish_choch && !ob.is_bullish) {
                double buffer = OB_Buffer_Points * _Point;
                if(currentPrice > (ob.top + buffer)) {
                    trade.PositionClose(_Symbol);
                    Print("Exit on OB invalidation (bearish)");
                    return;
                }
            }
        }
    }

    // Recovery add-on: Average down/up with capped risk
    if(Enable_Recovery && g_RecoveryAdds < Max_Recovery_Adds) {
        double move = MathAbs(currentPrice - entryPrice);
        bool trigger = move >= (Recovery_Trigger_R * risk);
        if(trigger) {
            double baseRiskAmt = AccountInfoDouble(ACCOUNT_BALANCE) * Risk_Percent / 100.0;
            double extraRiskAmt = baseRiskAmt * (Recovery_ExtraRisk_Percent/100.0);
            double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
            double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double pipsRisk = risk / pointSize;
            double addLots = extraRiskAmt / (pipsRisk * pointValue);
            double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            addLots = NormalizeDouble(addLots / stepLot, 0) * stepLot;
            if(addLots >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
                bool ok = g_CHoCHInfo.is_bullish_choch ? trade.Buy(addLots, _Symbol) : trade.Sell(addLots, _Symbol);
                if(ok) {
                    g_RecoveryAdds++;
                    // Optionally adjust TP to Recovery_Target_R from new weighted avg (kept simple here)
                    Print("Recovery add executed: ", addLots);
                }
            }
        }
    }

    // Trailing stop management
    if(Use_Trailing && positionProfit > 0) {
        double atr = GetATR();
        double trailDistance = atr * ATR_SL_Multiplier;
        
        if(g_CHoCHInfo.is_bullish_choch) {
            double newSL = currentPrice - trailDistance;
            if(newSL > g_StopLoss + _Point) {
                ModifyStopLoss(newSL);
                Print("Trailing stop updated to: ", newSL);
            }
        } else {
            double newSL = currentPrice + trailDistance;
            if(newSL < g_StopLoss - _Point) {
                ModifyStopLoss(newSL);
                Print("Trailing stop updated to: ", newSL);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Modify Stop Loss                                                |
//+------------------------------------------------------------------+
void ModifyStopLoss(double newSL) {
    if(trade.PositionModify(_Symbol, newSL, g_TakeProfit)) {
        g_StopLoss = newSL;
        Print("Stop Loss modified to: ", newSL);
    } else {
        Print("Failed to modify SL: ", trade.ResultRetcode());
    }
}

//+------------------------------------------------------------------+
//| Reset SMC States for New Cycle                                 |
//+------------------------------------------------------------------+
void ResetSMCStates() {
    g_BoSInfo.detected = false;
    g_PullbackInfo.detected = false;
    g_PullbackInfo.ended = false;
    g_CHoCHInfo.detected = false;
    
    // Mark used zones
    for(int i = 0; i < ArraySize(g_orderBlocks); i++) {
        if(g_EntryInfo.ob_found) {
            g_orderBlocks[i].is_used = true;
        }
    }
    
    for(int i = 0; i < ArraySize(g_fvgZones); i++) {
        if(g_EntryInfo.fvg_found) {
            g_fvgZones[i].is_filled = true;
        }
    }
}

//+------------------------------------------------------------------+
//| Get ATR Value                                                   |
//+------------------------------------------------------------------+
double GetATR() {
    double atr[];
    int atrHandle = iATR(_Symbol, _Period, 14);
    if(CopyBuffer(atrHandle, 0, 1, 1, atr) > 0) {
        return atr[0];
    }
    return 0.001; // Fallback value
}

//+------------------------------------------------------------------+
//| End of Enhanced SMC Regression Channel HTF/CTF Analysis EA      |
//+------------------------------------------------------------------+