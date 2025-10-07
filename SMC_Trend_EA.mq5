//+------------------------------------------------------------------+
//| Expert Advisor: SMC Trend EA (Professional Version)             |
//| การเทรด SMC แบบสมบูรณ์: MA Trends + BOS + OB + FVG + CHoCH      |
//+------------------------------------------------------------------+
#property copyright "SMC Professional EA"
#property link      ""
#property version   "3.00"

// กำหนดค่าพื้นฐาน & Execution
input double MaxSpread = 3.0;          // Spread สูงสุดที่ยอมรับ (points)
input int DeviationPoints = 20;        // ค่า slippage/deviation ยอมรับได้ (points)

// Timeframe และ Trend detection (CTF เท่านั้น)
input ENUM_TIMEFRAMES CTF_Period = PERIOD_M15; // TF สำหรับวิเคราะห์และเทรด
input int MA_Fast = 20;                       // MA เร็ว (CTF)
input int MA_Slow = 50;                       // MA ช้า (CTF)
input bool EntryOnAlignment = false;          // เข้าเทรดเมื่อ Trend จัดแนว (ไม่รอ BOS/Pullback)

// Lot & Trailing
input bool UseFixedLot = true;         // ใช้ Fixed lot สำหรับทุกคำสั่ง
input double FixedLot = 0.10;          // ขนาด lot คงที่
input double RiskPercent = 2.0;        // เปอร์เซ็นต์ความเสี่ยง (ใช้เมื่อไม่ใช้ Fixed Lot)
input int RiskPoints = 100;            // ใช้คำนวณ lot เมือไม่ใช้ Fixed Lot (จุดสมมติ SL)
input int TrailingTriggerPoints = 50;  // เริ่มใช้ Trailing เมื่อกำไรเกินค่าที่กำหนด (points)
input int TrailingDistancePoints = 30; // ระยะห่างของ Trailing Stop (points)

// Grid ladder (add-ons)
input bool AllowAddOns = true;         // เปิดออเดอร์เพิ่มแบบกริดเมื่อเคลื่อนไหวสวนทาง
input bool GridRequireConditions = false; // ถ้า true: ตรวจเงื่อนไขเข้าเหมือนออเดอร์แรกก่อนเปิด Add-on
input int LossStepPoints = 50;         // ระยะห่างขั้น (points)
input int MaxAddOnOrders = 5;          // จำนวน Add-on สูงสุด
input double AddOnLotMultiplier = 1.0; // ตัวคูณ lot สำหรับแต่ละ Add-on (1.0 = เท่าเดิม)

// VWAP Filters
input bool UseVWAPFilter = true;                 // ใช้ VWAP เป็นตัวกรอง
input bool VWAP_Filter_Alignment = true;         // ใช้ VWAP ยืนยันอคติแนวโน้ม (Condition 1)
input bool VWAP_Filter_Pullback = true;          // ต้องใกล้ VWAP ตอนเข้า Pullback (Condition 3)
input int  VWAP_ProximityPoints = 30;            // ระยะใกล้ VWAP สำหรับเข้าจุด Pullback
input bool VWAP_Filter_StopAddOnOnCross = true;  // หยุด Add-on เมื่อราคาข้าม VWAP สวนทางออเดอร์หลัก
input int  VWAP_StopAddOnTolerancePoints = 10;   // ค่าความคลาดเคลื่อนสำหรับการข้าม VWAP (points)
input bool VWAP_Cross_CloseAll = false;          // ปิดออเดอร์ทั้งหมดเมื่อราคาข้าม VWAP สวนทางออเดอร์หลัก
input int  VWAP_Cross_CloseAllTolerance = 10;    // ค่าความคลาดเคลื่อน (points)

// VWAP drawing & status label
input bool  DrawVWAPLine = true;                 // วาดเส้น VWAP ปัจจุบัน (HLINE)
input color VWAPLineColor = clrAqua;             // สีเส้น VWAP
input int   VWAPLineWidth = 1;                   // ความหนาเส้น VWAP
input bool  DrawStatusLabel = true;              // แสดง Status Label
input int   StatusLabelCorner = 0;               // มุมแสดงผล Label: 0=LT,1=RT,2=LB,3=RB
input int   StatusLabelX = 10;                   // ระยะห่างแกน X
input int   StatusLabelY = 20;                   // ระยะห่างแกน Y
input color StatusTextColor = clrWhite;          // สีตัวอักษร
input int   StatusTextSize = 9;                  // ขนาดตัวอักษร

// Trend/Structure Enums
enum ENUM_TREND_DIRECTION { TREND_NONE=0, TREND_UPTREND=1, TREND_DOWNTREND=-1 };
enum ENUM_MARKET_STATE { MS_NONE=0, MS_BOS=1, MS_PULLBACK=2, MS_WARNING=3, MS_CHOCH=4 };

// ตัวแปร Trend/Structure
ENUM_TREND_DIRECTION g_CTF_Trend = TREND_NONE;
bool     g_CTF_OrderOK = false;
datetime g_LastCTFBarTime = 0;
bool     g_BOS_Detected = false;
double   g_BOS_High = 0.0;
double   g_BOS_Low = 0.0;
datetime g_BOS_Time = 0;
ENUM_MARKET_STATE g_MarketState = MS_NONE;

// Indicator handles สำหรับ Trend CTF
int g_MA_FastHandle = INVALID_HANDLE;
int g_MA_SlowHandle = INVALID_HANDLE;

// VWAP state
double   g_VWAP = 0.0;
datetime g_VWAP_LastBarTime = 0;

// 📌 Add-on tracking
double  g_AnchorPrice = 0.0;     // ราคาออเดอร์แรกสำหรับคำนวณขั้นขาดทุน
int     g_AnchorDirection = 0;   // 1=BUY, -1=SELL, 0=none
int     g_AddOnCount = 0;        // จำนวน Add-on ที่เปิดไปแล้ว
int     g_NextAddOnStep = 1;     // ขั้นถัดไปที่ต้องถึงเพื่อเปิด Add-on
bool    g_FirstOrderUsedAlignment = false; // บันทึกว่าออเดอร์แรกใช้โหมด Alignment หรือไม่

//+------------------------------------------------------------------+
//| Helper: แปลง ENUM_TIMEFRAMES เป็นข้อความ                         |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
    switch(tf)
    {
        case PERIOD_M1:  return "M1";
        case PERIOD_M2:  return "M2";
        case PERIOD_M3:  return "M3";
        case PERIOD_M4:  return "M4";
        case PERIOD_M5:  return "M5";
        case PERIOD_M6:  return "M6";
        case PERIOD_M10: return "M10";
        case PERIOD_M12: return "M12";
        case PERIOD_M15: return "M15";
        case PERIOD_M20: return "M20";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H2:  return "H2";
        case PERIOD_H3:  return "H3";
        case PERIOD_H4:  return "H4";
        case PERIOD_H6:  return "H6";
        case PERIOD_H8:  return "H8";
        case PERIOD_H12: return "H12";
        case PERIOD_D1:  return "D1";
        case PERIOD_W1:  return "W1";
        case PERIOD_MN1: return "MN";
        default:         return IntegerToString((int)tf);
    }
}

//+------------------------------------------------------------------+
//| คำนวณ VWAP ของวันปัจจุบัน (ปิดแท่งเท่านั้น)                      |
//+------------------------------------------------------------------+
void UpdateVWAP()
{
    // คำนวณใหม่เฉพาะเมื่อมีแท่งใหม่ของ CTF
    datetime barTime = iTime(_Symbol, CTF_Period, 0);
    if(barTime == g_VWAP_LastBarTime && g_VWAP > 0.0) return;

    // ใช้เวลาเปิดแท่ง Day ปัจจุบันเพื่อให้สอดคล้องกับโซนเวลาโบรกเกอร์
    datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
    if(dayStart <= 0)
    {
        // Fallback: ปัดเวลา bar ปัจจุบันลงเป็นเที่ยงคืนของวันเดียวกัน (ตาม server time)
        MqlDateTime mt; TimeToStruct(barTime, mt);
        mt.hour=0; mt.min=0; mt.sec=0;
        dayStart = StructToTime(mt);
    }

    // สะสมตั้งแต่แท่งปัจจุบันย้อนกลับถึงเปิดวัน (จำกัดสูงสุด 2000 แท่งเพื่อประสิทธิภาพ)
    double sumPV = 0.0; // sum(typical price * volume)
    double sumV  = 0.0; // sum(volume)
    double sumTP = 0.0; // สำหรับ fallback เมื่อ volume=0 ทั้งหมด
    int countTP  = 0;
    int bars = Bars(_Symbol, CTF_Period);
    if(bars <= 0) { g_VWAP = 0.0; g_VWAP_LastBarTime = barTime; return; }

    int limit = MathMin(bars, 2000);
    for(int i = 0; i < limit; ++i)
    {
        datetime t = iTime(_Symbol, CTF_Period, i);
        if(t < dayStart) break; // ถึงวันก่อนหน้าแล้ว หยุด
        double h = iHigh(_Symbol, CTF_Period, i);
        double l = iLow(_Symbol, CTF_Period, i);
        double c = iClose(_Symbol, CTF_Period, i);
        long   v = (long)iVolume(_Symbol, CTF_Period, i);
        double tp = (h + l + c) / 3.0;
        if(v > 0) { sumPV += tp * (double)v; sumV += (double)v; }
        // เก็บค่าเพื่อ fallback
        sumTP += tp; countTP++;
    }
    if(sumV > 0.0)
        g_VWAP = sumPV / sumV;
    else
        g_VWAP = (countTP>0) ? (sumTP / (double)countTP) : 0.0;
    g_VWAP_LastBarTime = barTime;
}

bool VWAPBiasOk()
{
    if(!UseVWAPFilter || !VWAP_Filter_Alignment) return true;
    if(g_VWAP <= 0) return true; // ไม่มีค่า → ไม่กรอง
    double close0 = iClose(_Symbol, CTF_Period, 0);
    if(g_CTF_Trend == TREND_UPTREND) return close0 >= g_VWAP;
    if(g_CTF_Trend == TREND_DOWNTREND) return close0 <= g_VWAP;
    return true;
}

bool PriceNearVWAP(int tolPoints)
{
    if(!UseVWAPFilter || !VWAP_Filter_Pullback) return true;
    if(g_VWAP <= 0) return true;
    double close0 = iClose(_Symbol, CTF_Period, 0);
    return MathAbs(close0 - g_VWAP) <= tolPoints * _Point;
}

bool CrossedVWAPAgainst(int tolPoints, int direction)
{
    if(!UseVWAPFilter) return false;
    if(g_VWAP <= 0) return false;
    double close0 = iClose(_Symbol, CTF_Period, 0);
    if(direction > 0) // BUY → ตรวจว่าต่ำกว่า VWAP - tol
        return (close0 <= g_VWAP - tolPoints * _Point);
    else if(direction < 0) // SELL → ตรวจว่าสูงกว่า VWAP + tol
        return (close0 >= g_VWAP + tolPoints * _Point);
    return false;
}

//+------------------------------------------------------------------+
//| Linear Regression Slope (ปิดแท่งเท่านั้น)                        |
//+------------------------------------------------------------------+
// (ลบ Regression/ATR สำหรับ HTF ออก)

//+------------------------------------------------------------------+
//| เลือก filling mode ตามที่สัญลักษณ์รองรับ                          |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING ChooseFillingMode()
{
    // SYMBOL_FILLING_MODE is a bit mask: 1=FOK, 2=IOC, 4=RETURN
    int mask = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    bool canFOK = (mask & 1) == 1;
    bool canIOC = (mask & 2) == 2;
    bool canRET = (mask & 4) == 4;
    if(canRET) return ORDER_FILLING_RETURN;
    if(canIOC) return ORDER_FILLING_IOC;
    if(canFOK) return ORDER_FILLING_FOK;
    // Fallback
    return ORDER_FILLING_RETURN;
}

bool OrderSendWithFillingFallback(MqlTradeRequest &request, MqlTradeResult &result)
{
    int mask = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    int modes[3]; int cnt=0;
    if((mask & 4)==4) modes[cnt++] = ORDER_FILLING_RETURN;
    if((mask & 2)==2) modes[cnt++] = ORDER_FILLING_IOC;
    if((mask & 1)==1) modes[cnt++] = ORDER_FILLING_FOK;
    if(cnt==0) { modes[cnt++] = ORDER_FILLING_RETURN; }
    Print("Filling mask=", mask, " → modes order: ", cnt>=1?modes[0]:-1, ",",
          cnt>=2?modes[1]:-1, ",", cnt>=3?modes[2]:-1);

    for(int i=0;i<cnt;i++)
    {
        request.type_filling = (ENUM_ORDER_TYPE_FILLING)modes[i];
        // refresh price before retry
        if(request.type==ORDER_TYPE_BUY)
        {
            double a = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(a>0) request.price = a;
        }
        else if(request.type==ORDER_TYPE_SELL)
        {
            double b = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(b>0) request.price = b;
        }
        bool ok = OrderSend(request, result);
        if(ok) return true;
        // 10030: TRADE_RETCODE_INVALID_FILL; 10031: UNSUPPORTED_FILLING_MODE (names vary by platform)
        if(result.retcode==10030 || result.retcode==10031)
        {
            Print("OrderSend failed due to filling mode (retcode=", result.retcode, ") → retry with next mode");
            continue;
        }
        else
        {
            // Other error → stop retrying
            break;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Swing helpers (ใช้เฉพาะแท่งปิดเท่านั้น)                         |
//+------------------------------------------------------------------+
// (ลบ Swing/SMC detection ทั้งหมด)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== SMC Trend EA v3.0 Professional Initialized ===");
    
    // สร้าง MA handles ตาม Timeframe ที่ผู้ใช้เลือก (CTF เท่านั้น)
    g_MA_FastHandle = iMA(_Symbol, CTF_Period, MA_Fast, 0, MODE_SMA, PRICE_CLOSE);
    g_MA_SlowHandle = iMA(_Symbol, CTF_Period, MA_Slow, 0, MODE_SMA, PRICE_CLOSE);
    
    // ตรวจสอบ handles
    if(g_MA_FastHandle == INVALID_HANDLE || g_MA_SlowHandle == INVALID_HANDLE)
    {
        Print("Error: Failed to create MA handles (CTF)");
        return INIT_FAILED;
    }
    
    Print("All indicators initialized successfully");
    Print("Selected Timeframe → CTF: ", TimeframeToString(CTF_Period));
    Print("Risk per trade: ", RiskPercent, "%");
    Print("SL/TP: OFF (Trailing-only mode)");

    // คำนวณและแสดง VWAP ทันทีเมื่อเริ่มต้น เพื่อไม่ให้ขึ้น n/a จนกว่าจะมีแท่งใหม่
    UpdateVWAP();
    DrawVWAPObjects();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // ลบ Objects ที่วาดบนชาร์ต
    ObjectsDeleteAll(0, "FIBO_");
    ObjectsDeleteAll(0, "BOS_");
    ObjectDelete(0, "BOS_LINE");
    ObjectDelete(0, "BREAK_LINE");
    // VWAP objects
    ObjectDelete(0, "VWAP_HLINE");
    ObjectDelete(0, "VWAP_STATUS");
    
    Print("SMC Trend EA deinitialized. Reason: ", reason);
    // reset add-on tracking
    g_AnchorPrice = 0.0;
    g_AnchorDirection = 0;
    g_AddOnCount = 0;
    g_NextAddOnStep = 1;
    g_FirstOrderUsedAlignment = false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 0. Trailing management if positions exist (but keep analyzing for add-ons)
    if(PositionsTotal() > 0)
    {
        ManageOpenPositions();
        // If price crosses VWAP against the anchor direction, optionally close all and reset
        if(VWAP_Cross_CloseAll && g_AnchorDirection!=0 && CrossedVWAPAgainst(VWAP_Cross_CloseAllTolerance, g_AnchorDirection))
        {
            Print("VWAP cross against position → close all and reset grid state");
            CloseAllOrders();
            // reset grid state only (keep BOS state)
            g_AnchorPrice=0.0; g_AnchorDirection=0; g_AddOnCount=0; g_NextAddOnStep=1; g_FirstOrderUsedAlignment=false;
        }
    }
    else
    {
        // reset tracking when flat
        if(g_AnchorDirection!=0){ g_AnchorPrice=0.0; g_AnchorDirection=0; g_AddOnCount=0; g_NextAddOnStep=1; g_FirstOrderUsedAlignment=false; }
    }
    // วิเคราะห์แนวโน้ม (อัปเดตเฉพาะเมื่อเกิดแท่งใหม่ใน TF นั้น) ด้วย MA CTF เท่านั้น
    datetime ctfTime = iTime(_Symbol, CTF_Period, 0);
    if(ctfTime != g_LastCTFBarTime)
    {
        g_CTF_Trend = DetectTrend(CTF_Period, g_MA_FastHandle, g_MA_SlowHandle);
        g_CTF_OrderOK = (g_CTF_Trend != TREND_NONE);
        g_LastCTFBarTime = ctfTime;
        UpdateVWAP(); // อัปเดต VWAP เมื่อมีแท่งใหม่
        // อัปเดตวัตถุ VWAP บนกราฟ
        DrawVWAPObjects();
    }

    // แสดง Timeframe ที่เลือกบนกราฟ
    // แสดงสถานะบนกราฟแบบย่อ รวมเงื่อนไขหลัก 4 ข้อ
    bool cond1_align = (g_CTF_Trend != TREND_NONE) && g_CTF_OrderOK && VWAPBiasOk();
    bool cond2_bos   = g_BOS_Detected;
    bool cond3_pb    = (g_MarketState == MS_PULLBACK) && PriceNearVWAP(VWAP_ProximityPoints);
    bool cond4_nopos = !HasOpenPosition();
    int cond_pass = (cond1_align?1:0) + (cond2_bos?1:0) + (cond3_pb?1:0) + (cond4_nopos?1:0);

    Comment(
        "SMC Trend EA v3\n",
        "CTF: ", TimeframeToString(CTF_Period), " (",
            g_CTF_Trend==TREND_UPTREND?"UP":g_CTF_Trend==TREND_DOWNTREND?"DOWN":"NONE",
        ")\n",
        "VWAP: ", g_VWAP>0?DoubleToString(g_VWAP, _Digits):"n/a",
        " | Cond1 Align(VWAP bias): ", cond1_align?"PASS":"FAIL",
        " | BOS: ", cond2_bos?"PASS":"FAIL",
        " | State: ", g_MarketState==MS_BOS?"BOS":g_MarketState==MS_PULLBACK?"PULLBACK":g_MarketState==MS_WARNING?"WARN":g_MarketState==MS_CHOCH?"CHOCH":"NONE",
        " | NoPos: ", cond4_nopos?"PASS":"FAIL",
        " | Result: ", cond_pass, "/4",
        EntryOnAlignment?" | Mode: ALIGN-ENTRY":""
    );
    
    // 🚀 === SMC ANALYSIS SEQUENCE (Minimal: Trend + BOS/CHOCH) ===

    // วาดเส้น Trend Confirmation หลังจากอัปเดต Trend
    DrawTrendConfirmationLines();
    
    // วาดเส้น BOS เมื่อ Trend Condition ผ่าน (CTF เท่านั้น)
    bool condition1 = (g_CTF_Trend != TREND_NONE) && g_CTF_OrderOK;
    static bool lastCondition1 = false;
    
    if(condition1 && !lastCondition1)
    {
        // เงื่อนไขที่ 1 ผ่าน - วาดเส้น BOS
        DrawBOSLines();
        Print("✅ Condition 1 PASSED - BOS lines drawn on chart");
    }
    else if(!condition1 && lastCondition1)
    {
        // เงื่อนไขที่ 1 ไม่ผ่าน - ลบเส้น BOS
        ClearBOSLines();
        ClearFibonacci();
        Print("❌ Condition 1 FAILED - BOS lines removed");
    }
    lastCondition1 = condition1;
    
    // ตรวจสอบ BOS
    DetectBOS();
    
    // ✅ เงื่อนไขที่ 2: ตรวจสอบการทะลุ BOS Line
    CheckBOSBreakout();
    
    // วิเคราะห์สถานะตลาด
    CheckMarketState();
    
    // ดำเนินการเทรด (เปิดออเดอร์แรกเมื่อยังไม่มี position)
    ExecuteTradingLogic();

    // พิจารณาเปิด Add-on เมื่อขาดทุนตามขั้น
    TryOpenAddOn();
    // อัปเดตสถานะบนกราฟทุก tick (สำหรับ Label)
    DrawVWAPObjects();
}

//+------------------------------------------------------------------+
//| วาดเส้น VWAP และ Status Label                                   |
//+------------------------------------------------------------------+
void DrawVWAPObjects()
{
    // เส้น VWAP (HLINE ที่ค่า g_VWAP ปัจจุบัน)
    if(DrawVWAPLine && g_VWAP>0)
    {
        if(ObjectFind(0, "VWAP_HLINE") < 0)
        {
            ObjectCreate(0, "VWAP_HLINE", OBJ_HLINE, 0, 0, g_VWAP);
        }
        ObjectSetDouble(0, "VWAP_HLINE", OBJPROP_PRICE, g_VWAP);
        ObjectSetInteger(0, "VWAP_HLINE", OBJPROP_COLOR, VWAPLineColor);
        ObjectSetInteger(0, "VWAP_HLINE", OBJPROP_WIDTH, VWAPLineWidth);
        ObjectSetInteger(0, "VWAP_HLINE", OBJPROP_STYLE, STYLE_DOT);
    }
    else
    {
        ObjectDelete(0, "VWAP_HLINE");
    }

    // Status Label
    if(DrawStatusLabel)
    {
        string name = "VWAP_STATUS";
        if(ObjectFind(0, name) < 0)
        {
            ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        }
        // Build text
        double close0 = iClose(_Symbol, CTF_Period, 0);
        double deltaPts = (g_VWAP>0) ? ((close0 - g_VWAP)/_Point) : 0.0;
        string biasStr = VWAPBiasOk()?"OK":"WARN";
        string dirStr = (g_AnchorDirection>0)?"BUY":(g_AnchorDirection<0)?"SELL":"NONE";
        string txt = StringFormat(
            "VWAP: %.*f | Δ: %.*f pts (%s)\nAnchor: %s @ %.*f | Add-ons: %d/%d (next step=%d x %dpts)\nTrend: %s | TF: %s",
            _Digits, g_VWAP,
            1, deltaPts, biasStr,
            dirStr, _Digits, g_AnchorPrice, g_AddOnCount, MaxAddOnOrders, g_NextAddOnStep, LossStepPoints,
            g_CTF_Trend==TREND_UPTREND?"UP":g_CTF_Trend==TREND_DOWNTREND?"DOWN":"NONE",
            TimeframeToString(CTF_Period)
        );

        ObjectSetString(0, name, OBJPROP_TEXT, txt);
        ObjectSetInteger(0, name, OBJPROP_COLOR, StatusTextColor);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, StatusTextSize);
        ObjectSetInteger(0, name, OBJPROP_CORNER, StatusLabelCorner);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, StatusLabelX);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, StatusLabelY);
    }
    else
    {
        ObjectDelete(0, "VWAP_STATUS");
    }
}

//+------------------------------------------------------------------+
//| ตรวจสอบ Trend direction ด้วย MA                                 |
//+------------------------------------------------------------------+
ENUM_TREND_DIRECTION DetectTrend(ENUM_TIMEFRAMES timeframe, int ma20_handle, int ma50_handle)
{
    double ma20[2], ma50[2];
    
    // อ่านค่า MA
    if(CopyBuffer(ma20_handle, 0, 1, 2, ma20) <= 0 ||
       CopyBuffer(ma50_handle, 0, 1, 2, ma50) <= 0)
    {
        return TREND_NONE;
    }
    
    // ตรวจสอบ trend
    if(ma20[1] > ma50[1] && ma20[0] > ma20[1])  // MA20 อยู่เหนือ MA50 และกำลังเพิ่มขึ้น
        return TREND_UPTREND;
    else if(ma20[1] < ma50[1] && ma20[0] < ma20[1])  // MA20 อยู่ใต้ MA50 และกำลังลดลง
        return TREND_DOWNTREND;
    else
        return TREND_NONE;
}

//+------------------------------------------------------------------+
//| ตรวจสอบ Break of Structure                                       |
//+------------------------------------------------------------------+
void DetectBOS()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, CTF_Period, 0);
    
    // ตรวจสอบเฉพาะ bar ใหม่
    if(currentBarTime == lastBarTime)
        return;
    // อัปเดตเวลาแท่งล่าสุดและอ่านราคาปิดของแท่งก่อนหน้า
    lastBarTime = currentBarTime;
    double close1 = iClose(_Symbol, CTF_Period, 1);

    // ตรวจสอบ BOS สำหรับ Uptrend
    if(g_CTF_Trend == TREND_UPTREND && !g_BOS_Detected)
    {
        double swingHigh = 0;
        double swingLow = DBL_MAX;
        for(int i = 2; i <= 20; i++)
        {
            double high_i = iHigh(_Symbol, CTF_Period, i);
            double low_i  = iLow(_Symbol, CTF_Period, i);
            if(high_i > swingHigh) swingHigh = high_i;
            if(low_i  < swingLow)  swingLow  = low_i;
        }

        // BOS = ราคาเบรกเหนือ swing high, Break line = swing low ล่าสุด
        if(close1 > swingHigh && swingHigh > 0 && swingLow < DBL_MAX)
        {
            g_BOS_Detected = true;
            g_BOS_High = swingHigh;
            g_BOS_Low  = swingLow;   // ใช้เป็น Break line สำหรับ CHoCH
            g_BOS_Time = currentBarTime;
            Print("BOS Detected (UP): High=", swingHigh, " | BreakLow=", swingLow);
        }
    }
    // ตรวจสอบ BOS สำหรับ Downtrend
    else if(g_CTF_Trend == TREND_DOWNTREND && !g_BOS_Detected)
    {
        // ค้นหา swing low และ swing high ล่าสุด
        double swingLow = DBL_MAX;
        double swingHigh = 0;
        for(int i = 2; i <= 20; i++)
        {
            double low_i  = iLow(_Symbol, CTF_Period, i);
            double high_i = iHigh(_Symbol, CTF_Period, i);
            if(low_i  < swingLow)  swingLow  = low_i;
            if(high_i > swingHigh) swingHigh = high_i;
        }

        // BOS = ราคาเบรกใต้ swing low, Break line = swing high ล่าสุด
        if(close1 < swingLow && swingLow < DBL_MAX && swingHigh > 0)
        {
            g_BOS_Detected = true;
            g_BOS_Low  = swingLow;
            g_BOS_High = swingHigh;  // ใช้เป็น Break line สำหรับ CHoCH
            g_BOS_Time = currentBarTime;
            Print("BOS Detected (DOWN): Low=", swingLow, " | BreakHigh=", swingHigh);
        }
    }
}

//+------------------------------------------------------------------+
//| ตรวจสอบการทะลุ BOS Line (เงื่อนไขที่ 2)                           |
//+------------------------------------------------------------------+
void CheckBOSBreakout()
{
    double current_price = iClose(_Symbol, CTF_Period, 0);

    if(!g_BOS_Detected)
        return;

    // สำหรับ UPTREND
    if(g_CTF_Trend == TREND_UPTREND)
    {
        if(current_price > g_BOS_High) // ทะลุ BOS High → BOS จริง
        {
            Print("✅ BOS breakout confirmed (Uptrend) - Price: ", DoubleToString(current_price, _Digits));
            DrawFibonacciRetracement(g_BOS_Low, g_BOS_High); // วาด Fibo
        }
        else if(current_price <= g_BOS_Low) // แตะ/ทะลุ Break Line → CHoCH (ปิดทันที)
        {
            Print("❌ BOS Invalidated - CHoCH detected (Uptrend)");
            Alert("CHoCH Detected - Trend Change!");
            InvalidateBOS();
        }
    }
    // สำหรับ DOWNTREND
    else if(g_CTF_Trend == TREND_DOWNTREND)
    {
        if(current_price < g_BOS_Low) // ทะลุ BOS Low → BOS จริง
        {
            Print("✅ BOS breakout confirmed (Downtrend) - Price: ", DoubleToString(current_price, _Digits));
            DrawFibonacciRetracement(g_BOS_High, g_BOS_Low); // วาด Fibo (กลับกัน)
        }
        else if(current_price >= g_BOS_High) // แตะ/ทะลุ Break Line → CHoCH (ปิดทันที)
        {
            Print("❌ BOS Invalidated - CHoCH detected (Downtrend)");
            Alert("CHoCH Detected - Trend Change!");
            InvalidateBOS();
        }
    }
}

//+------------------------------------------------------------------+
//| ตรวจสอบสถานะตลาด                                                |
//+------------------------------------------------------------------+
void CheckMarketState()
{
    if(!g_BOS_Detected)
    {
        g_MarketState = MS_NONE;
        return;
    }
    
    double currentPrice = iClose(_Symbol, CTF_Period, 0);
    
    if(g_CTF_Trend == TREND_UPTREND)
    {
        // คำนวณ Fibonacci levels จาก BOS point
    double recent_low = GetRecentLow();
        double fibo_618 = g_BOS_High - (g_BOS_High - recent_low) * 0.618;
        
        if(currentPrice >= fibo_618 && currentPrice <= g_BOS_High)
        {
            g_MarketState = MS_PULLBACK;  // อยู่ในโซน Pullback
        }
        else if(currentPrice < fibo_618)
        {
            g_MarketState = MS_WARNING;   // Pullback ลึกเกินไป
        }
        else
        {
            g_MarketState = MS_BOS;       // ราคายังแข็งแกร่ง
        }
    }
    else if(g_CTF_Trend == TREND_DOWNTREND)
    {
        // คำนวณ Fibonacci levels จาก BOS point
    double recent_high = GetRecentHigh();
        double fibo_618 = g_BOS_Low + (recent_high - g_BOS_Low) * 0.618;
        
        if(currentPrice <= fibo_618 && currentPrice >= g_BOS_Low)
        {
            g_MarketState = MS_PULLBACK;  // อยู่ในโซน Pullback
        }
        else if(currentPrice > fibo_618)
        {
            g_MarketState = MS_WARNING;   // Pullback ลึกเกินไป
        }
        else
        {
            g_MarketState = MS_BOS;       // ราคายังแข็งแกร่ง
        }
    }
}

//+------------------------------------------------------------------+
//| Logic การเทรดหลัก + แสดงเงื่อนไข                                |
//+------------------------------------------------------------------+
void ExecuteTradingLogic()
{
    // ตรวจสอบเงื่อนไขการเทรดทั้ง 4 ข้อ + VWAP filters
    bool vwapBias = VWAPBiasOk();
    bool condition1 = (g_CTF_Trend != TREND_NONE) && g_CTF_OrderOK && vwapBias;  // CTF-only + VWAP bias
    bool condition2 = g_BOS_Detected;                                            // BOS Detection  
    bool nearVWAP = PriceNearVWAP(VWAP_ProximityPoints);
    bool condition3 = (g_MarketState == MS_PULLBACK) && nearVWAP;                // Pullback Zone + near VWAP
    bool condition4 = !HasOpenPosition();                                          // No Open Position
    
    // แสดงสถานะเงื่อนไขทุก 5 นาที
    static datetime lastLogTime = 0;
    datetime currentTime = TimeCurrent();
    
    if(currentTime - lastLogTime >= 300) // 300 วินาที = 5 นาที
    {
        lastLogTime = currentTime;
        
        Print("=== TRADE CONDITIONS SUMMARY ===");
        Print("Condition 1 - Trend Alignment: ", condition1 ? "[✓] PASS" : "[✗] FAIL");
    Print("   CTF Trend: ", g_CTF_Trend == TREND_UPTREND ? "UPTREND" : 
                                g_CTF_Trend == TREND_DOWNTREND ? "DOWNTREND" : "NONE");
        Print("Condition 2 - BOS Detected: ", condition2 ? "[✓] PASS" : "[✗] FAIL");
        Print("Condition 3 - Pullback Zone: ", condition3 ? "[✓] PASS" : "[✗] FAIL");
        Print("   Market State: ", g_MarketState == MS_BOS ? "BOS" :
                                   g_MarketState == MS_PULLBACK ? "PULLBACK" :
                                   g_MarketState == MS_WARNING ? "WARNING" :
                                   g_MarketState == MS_CHOCH ? "CHOCH" : "NONE");
        Print("Condition 4 - No Position: ", condition4 ? "[✓] PASS" : "[✗] FAIL");
        
        int passedCount = (condition1 ? 1 : 0) + (condition2 ? 1 : 0) + (condition3 ? 1 : 0) + (condition4 ? 1 : 0);
        Print("RESULT: ", passedCount, "/4 conditions passed");
        
        if(passedCount == 4)
            Print("🟢 READY TO TRADE!");
        else
            Print("🔴 Not ready to trade");
        Print("==================================");
    }
    
    // ตรวจสอบ spread
    double bid=SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask=SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    if(bid<=0 || ask<=0)
    {
        Print("Failed to get market prices for spread check");
        return;
    }
    double spread = (ask - bid) / _Point;
    if(spread > MaxSpread)
    {
        Print("Spread too wide: ", spread, " points (MaxSpread=", MaxSpread, ")");
        return;
    }
    // ตรวจ stops level ขั้นต่ำของโบรกเกอร์ (ข้อมูลประกอบ)
    int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    
    // โหมดเข้าเทรดทันทีเมื่อจัดแนว (Alignment) + CTF ยืนยัน
    if(EntryOnAlignment)
    {
        if(condition1 && condition4)
        {
            Print("ALIGNMENT ENTRY MODE → all alignment conditions met. Executing trade now.");
            double lotSize = CalculateLotSize();
            if(g_CTF_Trend == TREND_UPTREND)
            {
                Print("[ALIGN] BUY lot=", lotSize);
                OpenBuyOrder(lotSize);
            }
            else if(g_CTF_Trend == TREND_DOWNTREND)
            {
                Print("[ALIGN] SELL lot=", lotSize);
                OpenSellOrder(lotSize);
            }
            return; // ข้าม BOS/Pullback logic
        }
        // ถ้ายังไม่ครบ alignment ก็รอต่อไป
    }

    // ตรวจสอบ trend alignment (โหมดปกติ)
    if(!condition1)
        return;
    
    // ตรวจสอบ BOS
    if(!condition2)
        return;
    
    // ดำเนินการตาม Market State
    if(g_MarketState == MS_PULLBACK && nearVWAP && !HasOpenPosition())
    {
        Print("🚀 ALL CONDITIONS MET - EXECUTING TRADE!");
        double lotSize = CalculateLotSize();
        
        if(g_CTF_Trend == TREND_UPTREND)
        {
            Print("Executing BUY order with lot size=", lotSize,
                  " | spread=", spread,
                  " | stopsLevel=", stopsLevel,
                  " | deviation=", DeviationPoints);
            OpenBuyOrder(lotSize);
        }
        else if(g_CTF_Trend == TREND_DOWNTREND)
        {
            Print("Executing SELL order with lot size=", lotSize,
                  " | spread=", spread,
                  " | stopsLevel=", stopsLevel,
                  " | deviation=", DeviationPoints);
            OpenSellOrder(lotSize);
        }
    }
    else if(g_MarketState == MS_CHOCH)
    {
        Print("CHoCH Detected - Closing positions");
        CloseAllOrders();
        g_BOS_Detected = false;  // Reset BOS
    }
}

//+------------------------------------------------------------------+
//| วาดเส้น Trend Confirmation (รองรับทั้ง Uptrend และ Downtrend)      |
//+------------------------------------------------------------------+
void DrawTrendConfirmationLines()
{
    // ลบเส้นเก่า
    ObjectDelete(0, "BOS_LINE");
    ObjectDelete(0, "BREAK_LINE");

    // ตรวจสอบเงื่อนไข - ใช้ CTF เท่านั้น
    bool trendsAligned = (g_CTF_Trend != TREND_NONE) && g_CTF_OrderOK;
    
    if(!trendsAligned || !g_BOS_Detected)
        return;

    if(g_CTF_Trend == TREND_UPTREND)
    {
        // สำหรับ UPTREND
        // วาดเส้น BOS ที่ Swing High ล่าสุด (เส้นเขียว)
        ObjectCreate(0, "BOS_LINE", OBJ_HLINE, 0, 0, g_BOS_High);
        ObjectSetInteger(0, "BOS_LINE", OBJPROP_COLOR, clrLime);
        ObjectSetInteger(0, "BOS_LINE", OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, "BOS_LINE", OBJPROP_STYLE, STYLE_SOLID);
    // Note: OBJ_HLINE doesn't support OBJPROP_TEXT

        // วาดเส้น Break Uptrend ที่ Swing Low ล่าสุด (เส้นแดงประ)
        ObjectCreate(0, "BREAK_LINE", OBJ_HLINE, 0, 0, g_BOS_Low);
        ObjectSetInteger(0, "BREAK_LINE", OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, "BREAK_LINE", OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, "BREAK_LINE", OBJPROP_STYLE, STYLE_DASH);
    // Note: OBJ_HLINE doesn't support OBJPROP_TEXT
        
        Print("📈 UPTREND Confirmation Lines: BOS=", DoubleToString(g_BOS_High, _Digits), 
              " | Break=", DoubleToString(g_BOS_Low, _Digits));
    }
    else if(g_CTF_Trend == TREND_DOWNTREND)
    {
        // สำหรับ DOWNTREND
        // วาดเส้น BOS ที่ Swing Low ล่าสุด (เส้นแดง)
        ObjectCreate(0, "BOS_LINE", OBJ_HLINE, 0, 0, g_BOS_Low);
        ObjectSetInteger(0, "BOS_LINE", OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, "BOS_LINE", OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, "BOS_LINE", OBJPROP_STYLE, STYLE_SOLID);
    // Note: OBJ_HLINE doesn't support OBJPROP_TEXT

        // วาดเส้น Break Downtrend ที่ Swing High ล่าสุด (เส้นเขียวประ)
        ObjectCreate(0, "BREAK_LINE", OBJ_HLINE, 0, 0, g_BOS_High);
        ObjectSetInteger(0, "BREAK_LINE", OBJPROP_COLOR, clrLime);
        ObjectSetInteger(0, "BREAK_LINE", OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, "BREAK_LINE", OBJPROP_STYLE, STYLE_DASH);
    // Note: OBJ_HLINE doesn't support OBJPROP_TEXT
        
        Print("📉 DOWNTREND Confirmation Lines: BOS=", DoubleToString(g_BOS_Low, _Digits), 
              " | Break=", DoubleToString(g_BOS_High, _Digits));
    }
    
    Print("✅ Trend confirmation lines drawn for ", g_CTF_Trend == TREND_UPTREND ? "UPTREND" : "DOWNTREND");
}

//+------------------------------------------------------------------+
//| วาด Fibonacci Retracement แบบละเอียด                              |
//+------------------------------------------------------------------+
void DrawFibonacciRetracement(double swingLow, double swingHigh)
{
    string fibo_name = "FIBO_" + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
    
    // ลบ Fibo เก่า
    ClearFibonacci();

    // วาด Fibonacci
    datetime currentTime = TimeCurrent();
    ObjectCreate(0, fibo_name, OBJ_FIBO, 0, currentTime - 3600, swingLow, currentTime, swingHigh);

    // ตั้งค่า Level
    ObjectSetDouble(0, fibo_name, OBJPROP_LEVELVALUE, 0, 0.0);     // 0%
    ObjectSetDouble(0, fibo_name, OBJPROP_LEVELVALUE, 1, 0.5);     // 50%
    ObjectSetDouble(0, fibo_name, OBJPROP_LEVELVALUE, 2, 0.618);   // 61.8%
    ObjectSetDouble(0, fibo_name, OBJPROP_LEVELVALUE, 3, 1.0);     // 100%

    // ปรับสไตล์
    ObjectSetInteger(0, fibo_name, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, fibo_name, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, fibo_name, OBJPROP_WIDTH, 1);
    
    Print("📐 Fibonacci drawn: ", fibo_name, 
          " Low=", DoubleToString(swingLow, _Digits), 
          " High=", DoubleToString(swingHigh, _Digits));
}

//+------------------------------------------------------------------+
//| วาดเส้น BOS บนกราฟตามเทรนด์                                       |
//+------------------------------------------------------------------+
void DrawBOSLines()
{
    // ลบเส้นเก่าก่อน
    ClearBOSLines();
    
    if(g_CTF_Trend == TREND_UPTREND)
    {
        // หา Swing High ล่าสุดสำหรับ Uptrend
        double swingHigh = 0.0;
        
        for(int i = 2; i <= 20; i++)
        {
            double high = iHigh(_Symbol, CTF_Period, i);
            if(high > swingHigh)
                swingHigh = high;
        }
        
        if(swingHigh > 0)
        {
            // วาดเส้น BOS Uptrend (Swing High) - เส้นสีเขียว
            string bosLineName = "BOS_UPTREND_HIGH";
            ObjectCreate(0, bosLineName, OBJ_HLINE, 0, 0, swingHigh);
            ObjectSetInteger(0, bosLineName, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, bosLineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, bosLineName, OBJPROP_WIDTH, 2);
            ObjectSetString(0, bosLineName, OBJPROP_TEXT, "BOS Uptrend: " + DoubleToString(swingHigh, _Digits));
            
            // วาดเส้น Break Uptrend (Swing Low) - เส้นสีแดงแบบประ
            double swingLow = DBL_MAX;
            for(int i = 2; i <= 20; i++)
            {
                double low = iLow(_Symbol, CTF_Period, i);
                if(low < swingLow)
                    swingLow = low;
            }
            
            if(swingLow < DBL_MAX)
            {
                string breakLineName = "BREAK_UPTREND_LOW";
                ObjectCreate(0, breakLineName, OBJ_HLINE, 0, 0, swingLow);
                ObjectSetInteger(0, breakLineName, OBJPROP_COLOR, clrRed);
                ObjectSetInteger(0, breakLineName, OBJPROP_STYLE, STYLE_DASH);
                ObjectSetInteger(0, breakLineName, OBJPROP_WIDTH, 2);
                ObjectSetString(0, breakLineName, OBJPROP_TEXT, "Break Uptrend: " + DoubleToString(swingLow, _Digits));
            }
            
            Print("📈 UPTREND Lines Drawn - BOS: ", DoubleToString(swingHigh, _Digits), 
                  " | Break: ", DoubleToString(swingLow, _Digits));
        }
    }
    else if(g_CTF_Trend == TREND_DOWNTREND)
    {
        // หา Swing Low ล่าสุดสำหรับ Downtrend
        double swingLow = DBL_MAX;
        
        for(int i = 2; i <= 20; i++)
        {
            double low = iLow(_Symbol, CTF_Period, i);
            if(low < swingLow)
                swingLow = low;
        }
        
        if(swingLow < DBL_MAX)
        {
            // วาดเส้น BOS Downtrend (Swing Low) - เส้นสีแดง
            string bosLineName = "BOS_DOWNTREND_LOW";
            ObjectCreate(0, bosLineName, OBJ_HLINE, 0, 0, swingLow);
            ObjectSetInteger(0, bosLineName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, bosLineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, bosLineName, OBJPROP_WIDTH, 2);
            ObjectSetString(0, bosLineName, OBJPROP_TEXT, "BOS Downtrend: " + DoubleToString(swingLow, _Digits));
            
            // วาดเส้น Break Downtrend (Swing High) - เส้นสีเขียวแบบประ
            double swingHigh = 0.0;
            for(int i = 2; i <= 20; i++)
            {
                double high = iHigh(_Symbol, CTF_Period, i);
                if(high > swingHigh)
                    swingHigh = high;
            }
            
            if(swingHigh > 0)
            {
                string breakLineName = "BREAK_DOWNTREND_HIGH";
                ObjectCreate(0, breakLineName, OBJ_HLINE, 0, 0, swingHigh);
                ObjectSetInteger(0, breakLineName, OBJPROP_COLOR, clrLime);
                ObjectSetInteger(0, breakLineName, OBJPROP_STYLE, STYLE_DASH);
                ObjectSetInteger(0, breakLineName, OBJPROP_WIDTH, 2);
                ObjectSetString(0, breakLineName, OBJPROP_TEXT, "Break Downtrend: " + DoubleToString(swingHigh, _Digits));
            }
            
            Print("📉 DOWNTREND Lines Drawn - BOS: ", DoubleToString(swingLow, _Digits), 
                  " | Break: ", DoubleToString(swingHigh, _Digits));
        }
    }
}

//+------------------------------------------------------------------+
//| ลบเส้น BOS ทั้งหมดออกจากกราฟ                                      |
//+------------------------------------------------------------------+
void ClearBOSLines()
{
    ObjectDelete(0, "BOS_UPTREND_HIGH");
    ObjectDelete(0, "BREAK_UPTREND_LOW");
    ObjectDelete(0, "BOS_DOWNTREND_LOW");
    ObjectDelete(0, "BREAK_DOWNTREND_HIGH");
    
    Print("🧹 BOS Lines cleared from chart");
}

//+------------------------------------------------------------------+
//| ลบ Fibonacci ออกจากกราฟ                                          |
//+------------------------------------------------------------------+
void ClearFibonacci()
{
    ObjectsDeleteAll(0, "FIBO_");
    Print("🧹 Fibonacci cleared from chart");
}

//+------------------------------------------------------------------+
//| รีเซ็ต BOS และลบเส้นทั้งหมด (เมื่อเกิด CHoCH)                      |
//+------------------------------------------------------------------+
void InvalidateBOS()
{
    // รีเซ็ต BOS data
    g_BOS_Detected = false;
    g_BOS_High = 0.0;
    g_BOS_Low = 0.0;
    g_BOS_Time = 0;
    g_MarketState = MS_NONE;
    
    // ลบเส้นและ objects ทั้งหมด
    ClearBOSLines();
    ClearFibonacci();
    ObjectDelete(0, "BOS_LINE");
    ObjectDelete(0, "BREAK_LINE");
    
    // ปิดออร์เดอร์ทั้งหมด
    CloseAllOrders();
    
    // รีเซ็ตสถานะ Grid/Add-on หลังปิดทั้งหมด
    g_AnchorPrice = 0.0;
    g_AnchorDirection = 0;
    g_AddOnCount = 0;
    g_NextAddOnStep = 1;
    g_FirstOrderUsedAlignment = false;
    
    Print("🔄 BOS invalidated - All lines cleared, positions closed");
}

//+------------------------------------------------------------------+
//| คำนวณ Lot Size ตาม Risk Management                              |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    if(UseFixedLot)
        return FixedLot;

    // คำนวณจาก RiskPoints (สมมติ SL)
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * RiskPercent / 100.0;
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double points = MathMax(1, RiskPoints);
    double lotSize = riskAmount / (points * tickValue / tickSize);
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;
    return lotSize;
}

// (ลบฟังก์ชันคำนวณ SL/TP เดิมออก เนื่องจากโหมด Trailing-only)

// แก้ไข SL/TP ของ position
bool ModifyPositionSLTP(ulong positionTicket, double newSL, double newTP)
{
    MqlTradeRequest req = {};
    MqlTradeResult res = {};
    req.action = TRADE_ACTION_SLTP;
    req.position = positionTicket;
    req.symbol = _Symbol;
    req.sl = newSL;
    req.tp = newTP;
    bool ok = OrderSend(req, res);
    if(!ok)
        Print("ModifyPositionSLTP failed: ticket=", positionTicket, " retcode=", res.retcode);
    return ok;
}

// จัดการ Breakeven + ATR Trailing ของ positions ปัจจุบัน
void ManageOpenPositions()
{
    // Trailing แบบกำหนดจุด: เริ่มทำงานเมื่อกำไร (points) >= TrailingTriggerPoints
    if(!PositionSelect(_Symbol)) return; // ทำงานเฉพาะ position ของสัญลักษณ์นี้
    int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
    int type = (int)PositionGetInteger(POSITION_TYPE);
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double sl = PositionGetDouble(POSITION_SL);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double cur = (type==POSITION_TYPE_BUY) ? bid : ask;
    double profitPts = ((type==POSITION_TYPE_BUY) ? (cur - entry) : (entry - cur)) / _Point;
    if(profitPts >= TrailingTriggerPoints)
    {
        double trailDist = TrailingDistancePoints * _Point;
        double newSL = (type==POSITION_TYPE_BUY) ? (cur - trailDist) : (cur + trailDist);
        bool improve = (type==POSITION_TYPE_BUY) ? (sl==0 || newSL>sl) : (sl==0 || newSL<sl);
        if(improve)
        {
            // เคารพ stops level
            if(stopsLevel<=0 || MathAbs(cur - newSL)/_Point >= stopsLevel)
            {
                ModifyPositionSLTP(ticket, newSL, 0.0 /* tp off */);
            }
        }
    }
}

// นับจำนวน positions ของสัญลักษณ์ปัจจุบัน
int SymbolPositionsCount()
{
    // ในบัญชี Netting จะมีได้สูงสุด 1 position ต่อสัญลักษณ์
    return PositionSelect(_Symbol) ? 1 : 0;
}

// ตรวจเงื่อนไขการเข้าเหมือนออเดอร์แรก (ไม่รวม NoPos)
bool EntryConditionsOkForAddOn(bool usedAlignment)
{
    bool cond1 = (g_CTF_Trend != TREND_NONE) && g_CTF_OrderOK;
    bool biasOk = VWAPBiasOk();
    if(usedAlignment)
    {
        // โหมด Alignment: ต้องผ่าน Trend + VWAP Bias
        return cond1 && biasOk;
    }
    // โหมดปกติ: ต้องผ่าน Trend + BOS + Pullback (+ ใกล้ VWAP เมื่อเปิดใช้)
    bool cond2 = g_BOS_Detected;
    bool cond3 = (g_MarketState == MS_PULLBACK);
    bool nearVWAP = PriceNearVWAP(VWAP_ProximityPoints);
    if(UseVWAPFilter)
        return cond1 && biasOk && cond2 && cond3 && nearVWAP;
    return cond1 && cond2 && cond3;
}

void TryOpenAddOn()
{
    // Guard: ต้องมี position, อนุญาต Add-on และยังไม่ถึงจำนวนสูงสุด
    if(!(PositionsTotal() > 0 && g_AddOnCount < MaxAddOnOrders && AllowAddOns)) return;
    if(g_AnchorDirection==0 || g_AnchorPrice<=0) return;

    // ตรวจสอบ VWAP Filter ก่อนเปิด Add-on
    if(VWAP_Filter_StopAddOnOnCross && CrossedVWAPAgainst(VWAP_StopAddOnTolerancePoints, g_AnchorDirection))
    {
        Print("VWAP Filter: Price crossed VWAP against anchor direction. Stopping all Add-ons.");
        return; // ออกจากฟังก์ชัน ไม่เปิด Add-on
    }

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double cur = (g_AnchorDirection==1) ? bid : ask;
    double adversePts = (g_AnchorDirection==1) ? (g_AnchorPrice - cur) / _Point
                                               : (cur - g_AnchorPrice) / _Point;
    int needed = g_NextAddOnStep * LossStepPoints;
    if(adversePts < needed) return;

    // ตรวจเงื่อนไขเข้าแบบเดียวกับออเดอร์แรก (ถ้าเลือก)
    if(GridRequireConditions)
    {
        if(!EntryConditionsOkForAddOn(g_FirstOrderUsedAlignment)) return;
    }

    // คำนวณ lot สำหรับ Add-on
    double baseLot = UseFixedLot ? FixedLot : CalculateLotSize();
    double lot = baseLot * MathPow(AddOnLotMultiplier, g_AddOnCount+1);

    if(g_AnchorDirection==1)
    {
        Print("[ADD-ON] BUY at step=", g_NextAddOnStep, " lot=", lot);
        OpenBuyOrder(lot);
    }
    else if(g_AnchorDirection==-1)
    {
        Print("[ADD-ON] SELL at step=", g_NextAddOnStep, " lot=", lot);
        OpenSellOrder(lot);
    }
    // อัปเดตตัวนับเมื่อสั่งเปิดแล้ว (จะเพิ่มอีกครั้งหลังได้รับยืนยัน ticket ก็ได้ แต่เอาง่ายที่นี่)
    g_AddOnCount++;
    g_NextAddOnStep++;
}

//+------------------------------------------------------------------+
//| ตรวจสอบว่ามี position เปิดอยู่หรือไม่                            |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
    return PositionSelect(_Symbol);
}

//+------------------------------------------------------------------+
//| เปิด BUY order                                                   |
//+------------------------------------------------------------------+
void OpenBuyOrder(double lots)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    // Get current market price
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    if(ask<=0) { Print("OpenBuyOrder: failed to get ask price"); return; }
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lots;
    request.type = ORDER_TYPE_BUY;
    request.price = ask;
    // ไม่ตั้ง SL/TP ตอนส่งคำสั่ง (Trailing-only)
    request.sl = 0.0;
    request.tp = 0.0;
    request.type_time = ORDER_TIME_GTC;
    request.type_filling = ChooseFillingMode();
    request.deviation = DeviationPoints;
    request.comment = "SMC BUY";
    request.magic = 123456;
    
    if(OrderSendWithFillingFallback(request, result))
    {
        Print("BUY order successful: Ticket=", result.order);
        // ตั้ง Anchor ถ้ายังไม่มี (ออเดอร์แรก)
        if(g_AnchorDirection==0 && SymbolPositionsCount()>0)
        {
            g_AnchorDirection = 1;
            g_AnchorPrice = ask; // ใช้ราคาปัจจุบันเป็นจุดอ้างอิง
            g_AddOnCount = 0;
            g_NextAddOnStep = 1;
            g_FirstOrderUsedAlignment = EntryOnAlignment;
        }
    }
    else
    {
        Print("BUY order failed: retcode=", result.retcode, " price=", DoubleToString(request.price, _Digits),
              " sl=0 tp=0",
              " deviation=", request.deviation);
    }
}

//+------------------------------------------------------------------+
//| เปิด SELL order                                                  |
//+------------------------------------------------------------------+
void OpenSellOrder(double lots)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    // Get current market price
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(bid<=0) { Print("OpenSellOrder: failed to get bid price"); return; }
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lots;
    request.type = ORDER_TYPE_SELL;
    request.price = bid;
    // ไม่ตั้ง SL/TP ตอนส่งคำสั่ง (Trailing-only)
    request.sl = 0.0;
    request.tp = 0.0;
    request.type_time = ORDER_TIME_GTC;
    request.type_filling = ChooseFillingMode();
    request.deviation = DeviationPoints;
    request.comment = "SMC SELL";
    request.magic = 123456;
    
    if(OrderSendWithFillingFallback(request, result))
    {
        Print("SELL order successful: Ticket=", result.order);
        // ตั้ง Anchor ถ้ายังไม่มี (ออเดอร์แรก)
        if(g_AnchorDirection==0 && SymbolPositionsCount()>0)
        {
            g_AnchorDirection = -1;
            g_AnchorPrice = bid; // ใช้ราคาปัจจุบันเป็นจุดอ้างอิง
            g_AddOnCount = 0;
            g_NextAddOnStep = 1;
            g_FirstOrderUsedAlignment = EntryOnAlignment;
        }
    }
    else
    {
        Print("SELL order failed: retcode=", result.retcode, " price=", DoubleToString(request.price, _Digits),
              " sl=0 tp=0",
              " deviation=", request.deviation);
    }
}

//+------------------------------------------------------------------+
//| ปิด order ทั้งหมด                                                |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
    if(!PositionSelect(_Symbol)) return;
    // ปิดเฉพาะ position ของสัญลักษณ์นี้ (รองรับ Netting)
    ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
    double volume = PositionGetDouble(POSITION_VOLUME);
    int ptype = (int)PositionGetInteger(POSITION_TYPE);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    if(bid<=0 || ask<=0) { Print("CloseAllOrders: failed to get prices"); return; }
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = volume;
    request.position = ticket;
    request.type = (ptype == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (ptype == POSITION_TYPE_BUY) ? bid : ask;
    if(!OrderSend(request, result))
    {
        Print("CloseAllOrders: close failed, ticket=", ticket, " retcode=", result.retcode);
    }
}

//+------------------------------------------------------------------+
//| หา Recent Low                                                    |
//+------------------------------------------------------------------+
double GetRecentLow()
{
    double low = DBL_MAX;
    for(int i = 1; i <= 10; i++)
    {
        double low_i = iLow(_Symbol, CTF_Period, i);
        if(low_i < low)
            low = low_i;
    }
    return low;
}

//+------------------------------------------------------------------+
//| หา Recent High                                                   |
//+------------------------------------------------------------------+
double GetRecentHigh()
{
    double high = 0;
    for(int i = 1; i <= 10; i++)
    {
        double high_i = iHigh(_Symbol, CTF_Period, i);
        if(high_i > high)
            high = high_i;
    }
    return high;
}

// (Order Blocks and FVG systems removed in Grid + CHoCH simplified EA)

//+------------------------------------------------------------------+
//| End of Expert Advisor                                            |
//+------------------------------------------------------------------+