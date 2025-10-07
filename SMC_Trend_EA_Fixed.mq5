//+------------------------------------------------------------------+
//|                                           SMC_Trend_EA_Fixed.mq5 |
//|                                           Copyright 20XX, MyName |
//|                                          https://www.mysite.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 20XX, MyName"
#property link      "https://www.mysite.com/"
#property version   "1.000"

//=============================================================================
// Expert properties
#property strict
// ใช้งานคลาสเทรด MQL5
#include <Trade/Trade.mqh>

//=============================== Inputs =====================================
// === PRESET MODES (ลดความซับซ้อน) ===
enum PRESET_MODE
{
    PRESET_CONSERVATIVE,    // โหมดระมัดระวัง - กรองสัญญาณเข้มงวด
    PRESET_BALANCED,        // โหมดสมดุล - การตั้งค่าปกติ
    PRESET_AGGRESSIVE,      // โหมดก้าวร้าว - รับสัญญาณมาก
    PRESET_CUSTOM          // โหมดกำหนดเอง - ใช้ค่าที่ตั้งเอง
};

input PRESET_MODE     InpPresetMode = PRESET_BALANCED; // โหมดการทำงาน (ลดความซับซ้อน)
input string          InpPresetInfo = "=== Conservative: กรองเข้มงวด | Balanced: ปกติ | Aggressive: รับสัญญาณมาก ==="; // คำอธิบาย

// === การตั้งค่าพื้นฐาน ===
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // Timeframe สำหรับคำนวณ
input int             InpPrevIndex = 1;               // แท่งก่อนหน้า
input int             InpCurrIndex = 0;               // แท่งปัจจุบัน
input int             InpExtendBarsRight = 15;        // ขยายโซนไปทางขวากี่แท่ง
input bool            InpAutoDraw = true;             // วาด Fibo/Zone อัตโนมัติเมื่อมีสัญญาณ
input bool            InpOnlyOnNewBar = true;         // ทำงานเฉพาะเมื่อมีแท่งใหม่

// การเทรดจริง
input bool            InpEnableTrading   = true;      // เปิด/ปิดการส่งคำสั่งเทรดจริง
input double          InpLots            = 0.01;      // ขนาดล็อตคงที่
input int             InpMagic           = 20251007;  // Magic number
input int             InpDeviationPoints = 20;        // Slippage/Deviation (points)

// โซนระดับ Fibo และสี
input double          InpZoneLevelTop    = 0.786;     // ระดับบนของโซน (0..1)
input double          InpZoneLevelBottom = 0.618;     // ระดับล่างของโซน (0..1)
input color           InpFiboColorBull   = clrDodgerBlue;
input color           InpFiboColorBear   = clrTomato;
input color           InpZoneColorBuy    = clrLime;
input color           InpZoneColorSell   = clrRed;
input bool            InpClearPrevious   = true;      // ลบวัตถุเก่าเมื่อมีสัญญาณใหม่

// เส้นแนวนอนสำหรับ Entry
input bool            InpDrawEntryLine   = true;      // วาดเส้นแนวนอนเมื่อเกิดสัญญาณเข้า
input int             InpEntryLineWidth  = 1;         // ความหนาเส้นแนวนอน
input color           InpEntryBuyColor   = clrLime;   // สีเส้นสำหรับ BUY
input color           InpEntrySellColor  = clrRed;    // สีเส้นสำหรับ SELL

// การแจ้งเตือน
input bool            InpAlerts          = true;      // แสดง Alert เมื่อมีสัญญาณ
input bool            InpPush            = false;     // ส่ง Push Notification

// ตัวกรองสัญญาณ: Buffer/ATR
input bool            InpUseBufferPoints = true;      // ใช้ระยะ buffer (points)
input int             InpBufferPoints    = 10;        // ต้องมากกว่าเท่าหรือเท่ากับระยะนี้ (points)
input bool            InpUseATRFilter    = false;     // ใช้ ATR filter
input int             InpATRPeriod       = 14;        // ค่า ATR period
input double          InpATRMultiplier   = 0.5;       // ต้องมากกว่า ATR*Multiplier

// ตัวกรอง VWAP
input bool            InpUseVWAPFilter   = true;      // ใช้ VWAP filter
input int             InpVWAPPeriod      = 20;        // VWAP period (จำนวนแท่งย้อนหลัง)
input bool            InpDrawVWAP        = true;      // วาด VWAP บนกราฟ
input color           InpVWAPColor       = clrYellow; // สี VWAP line
input int             InpVWAPWidth       = 2;         // ความหนา VWAP line
input int             InpVWAPUpdateBars  = 5;         // อัปเดต VWAP ทุกกี่แท่ง (เพื่อประหยัดทรัพยากร)

// ตัวกรอง Volume Profile (POC)
input bool            InpUseVPFilter     = false;     // ใช้ Volume Profile POC filter
input int             InpVPLookback      = 50;        // จำนวนแท่งสำหรับคำนวณ Volume Profile
input int             InpVPPrecision     = 50;        // ความละเอียด Volume Profile (จำนวน level)
input double          InpPOCDistance     = 20.0;      // ระยะห่างจาก POC (points) ที่ยอมรับได้
input bool            InpDrawPOC         = true;      // วาดเส้น POC บนกราฟ
input color           InpPOCColor        = clrOrange; // สี POC line
input int             InpPOCWidth        = 2;         // ความหนา POC line
input bool            InpVPUseRange      = true;      // ใช้ช่วงเวลาจากเส้น VP begin/finish ในการคำนวณ
input bool            InpDrawVPBars      = false;     // วาดแท่ง Volume Profile (แท่งแนวนอน)
input double          InpVPBarsRatio     = 0.25;      // อัตราส่วนความยาวแท่ง VP ต่อความกว้างกราฟ
input color           InpVPBarsColor     = clrSlateGray; // สีของแท่ง VP

// ตัวเลือกสำหรับ Strategy Tester
input bool            InpTesterIgnoreSessions = true;  // (ทดสอบ) ข้ามการเช็ค session/permission บางส่วนใน Tester

// === PERFORMANCE OPTIMIZATION ===
input string          InpPerfInfo = "=== Performance Settings ==="; // ส่วนตั้งค่าประสิทธิภาพ
input bool            InpOptimizeDrawing = true;       // เพิ่มประสิทธิภาพการวาดกราฟิก
input int             InpMaxObjects = 50;              // จำนวนวัตถุสูงสุดบนกราฟ
input int             InpCalculationInterval = 3;      // คำนวณทุกกี่ tick (ลดการประมวลผล)
input bool            InpSmartRedraw = true;           // วาดใหม่เฉพาะเมื่อจำเป็น

//============================== State ========================================
// ENUM สำหรับสถานะการรอคอยและการตัดสินใจเทรด
enum TradeState
{
    STATE_NO_SIGNAL,            // ไม่มีสัญญาณ หรือรอแท่งใหม่
    STATE_PULLBACK_WAIT_BUY,    // รอให้ราคาวิ่งกลับมาที่ Buy Zone
    STATE_PULLBACK_WAIT_SELL    // รอให้ราคาวิ่งกลับมาที่ Sell Zone
};

static datetime s_lastBarTime = 0; // เก็บเวลาแท่งล่าสุดเพื่อเช็คแท่งใหม่
static CTrade   m_trade;           // ตัวช่วยส่งคำสั่งเทรด (สำรอง หากต้องการกลับไปใช้ CTrade)
static TradeState s_currentState = STATE_NO_SIGNAL; // สถานะปัจจุบันของ EA
static double     s_entryPrice   = 0.0;             // ราคา Entry กลางโซนที่ต้องรอ
static int        s_vwapUpdateCounter = 0;          // ตัวนับสำหรับอัปเดต VWAP ทุก N แท่ง
static double     s_lastPOC      = 0.0;             // ราคา POC ล่าสุดที่คำนวณได้

// === PERFORMANCE & FALSE SIGNAL PREVENTION ===
static int        s_tickCounter = 0;                // นับ tick เพื่อลดการประมวลผล
static int        s_objectCount = 0;                // นับจำนวนวัตถุบนกราฟ
static datetime   s_lastSignalTime = 0;             // เวลาสัญญาณล่าสุด (ป้องกันสัญญาณซ้ำ)
static double     s_lastSignalPrice = 0.0;          // ราคาสัญญาณล่าสุด
static int        s_signalConfirmationBars = 0;     // จำนวนแท่งยืนยันสัญญาณ
static bool       s_marketVolatileMode = false;     // โหมดตลาดผันผวน

// ENUM สำหรับแนวโน้ม (Trend)
enum TrendType
{
	 UPtrend,
	 Sideway,
	 Downtrend
};

// ENUM สำหรับการยืนยันสัญญาณ (Confirm Signal)
enum ConfirmSignalType
{
	 BOS_newhigh,
	 BOS_newlow,
	 Break_UPtrend,
	 Break_Downtrend,
     Waiting_Confirm_Signal
};

// ประเภทคำสั่งเทรดที่สังเคราะห์จากสัญญาณ (แยกออกจากการวาดและการส่งคำสั่งจริง)
enum TRadetype
{
	 No_Trade,
	 Buy_now,
	 Sell_now
};

//============================== Functions ===================================

// Forward declarations
double CalcATR(string symbol, ENUM_TIMEFRAMES tf, int period, int shift);
double CalcVWAP(string symbol, ENUM_TIMEFRAMES tf, int period, int shift);
double CalcPOCWithCurrentSetting();
double DrawFiboAndZoneBySignal(ConfirmSignalType signal, string symbol, ENUM_TIMEFRAMES timeframe, int prevIndex, int currIndex, int extendBarsRight=10);

// === PRESET MANAGEMENT ===
// ตั้งค่าตาม Preset Mode เพื่อลดความซับซ้อน
void ApplyPresetSettings()
{
    if(InpPresetMode == PRESET_CUSTOM) return; // ใช้ค่าที่ผู้ใช้ตั้งเอง
    
    // รีเซ็ตค่าเริ่มต้น
    bool useBuffer = true, useATR = false, useVWAP = true, useVP = false;
    int bufferPoints = 10, atrPeriod = 14, vwapPeriod = 20, vpLookback = 50;
    double atrMultiplier = 0.5, pocDistance = 20.0;
    
    switch(InpPresetMode)
    {
        case PRESET_CONSERVATIVE:
            // กรองสัญญาณเข้มงวด - ลด False Signal
            useBuffer = true; bufferPoints = 20;
            useATR = true; atrMultiplier = 1.0;
            useVWAP = true; vwapPeriod = 30;
            useVP = true; pocDistance = 15.0;
            s_signalConfirmationBars = 2; // ต้องยืนยัน 2 แท่ง
            break;
            
        case PRESET_BALANCED:
            // การตั้งค่าสมดุล
            useBuffer = true; bufferPoints = 10;
            useATR = false;
            useVWAP = true; vwapPeriod = 20;
            useVP = false;
            s_signalConfirmationBars = 1;
            break;
            
        case PRESET_AGGRESSIVE:
            // รับสัญญาณมากขึ้น
            useBuffer = true; bufferPoints = 5;
            useATR = false;
            useVWAP = false;
            useVP = false;
            s_signalConfirmationBars = 0;
            break;
    }
    
    PrintFormat("[PRESET] Applied %s mode - Buffer:%d ATR:%.1f VWAP:%s VP:%s Confirm:%d", 
               EnumToString(InpPresetMode), bufferPoints, atrMultiplier, 
               useVWAP?"ON":"OFF", useVP?"ON":"OFF", s_signalConfirmationBars);
}

// === PERFORMANCE OPTIMIZATION ===
// ตรวจสอบว่าควรประมวลผลหรือไม่ (ลดการใช้ทรัพยากร)
bool ShouldProcess()
{
    if(!InpOptimizeDrawing) return true;
    
    s_tickCounter++;
    if(s_tickCounter < InpCalculationInterval)
        return false;
        
    s_tickCounter = 0;
    return true;
}

// จัดการจำนวนวัตถุบนกราฟ
void ManageObjectCount()
{
    if(!InpOptimizeDrawing) return;
    
    s_objectCount = ObjectsTotal(0, 0, -1);
    if(s_objectCount > InpMaxObjects)
    {
        // ลบวัตถุเก่าบางส่วน
        ClearOldestObjects(s_objectCount - InpMaxObjects + 5);
        PrintFormat("[PERF] Cleaned %d old objects, current count: %d", 
                   s_objectCount - InpMaxObjects + 5, ObjectsTotal(0, 0, -1));
    }
}

// ลบวัตถุเก่าสุด
void ClearOldestObjects(int count)
{
    string objNames[];
    datetime objTimes[];
    int totalObjs = ObjectsTotal(0, 0, -1);
    
    ArrayResize(objNames, totalObjs);
    ArrayResize(objTimes, totalObjs);
    
    // เก็บชื่อและเวลาของวัตถุ
    for(int i = 0; i < totalObjs; i++)
    {
        objNames[i] = ObjectName(0, i, 0, -1);
        objTimes[i] = (datetime)ObjectGetInteger(0, objNames[i], OBJPROP_TIME);
    }
    
    // เรียงตามเวลา (เก่าสุดก่อน)
    ArraySort(objTimes);
    
    // ลบวัตถุเก่าสุด
    int deleted = 0;
    for(int i = 0; i < totalObjs && deleted < count; i++)
    {
        for(int j = 0; j < totalObjs; j++)
        {
            if(ObjectGetInteger(0, objNames[j], OBJPROP_TIME) == objTimes[i])
            {
                ObjectDelete(0, objNames[j]);
                deleted++;
                break;
            }
        }
    }
}

// === FALSE SIGNAL PREVENTION ===
// ตรวจสอบว่าสัญญาณซ้ำกับที่ผ่านมาหรือไม่
bool IsSignalTooSimilar(double currentPrice)
{
    if(s_lastSignalTime == 0) return false;
    
    // ตรวจสอบเวลา - ต้องห่างกันอย่างน้อย 5 แท่ง
    datetime currentTime = iTime(_Symbol, _Period, 0);
    if(currentTime - s_lastSignalTime < 5 * PeriodSeconds(_Period))
        return true;
        
    // ตรวจสอบราคา - ต้องห่างกันอย่างน้อย 20 points
    double priceDistance = MathAbs(currentPrice - s_lastSignalPrice);
    double minDistance = 20 * (_Point > 0 ? _Point : 0.0001);
    
    return priceDistance < minDistance;
}

// บันทึกสัญญาณใหม่
void RecordNewSignal(double price)
{
    s_lastSignalTime = iTime(_Symbol, _Period, 0);
    s_lastSignalPrice = price;
}

// ตรวจสอบความผันผวนของตลาด
void CheckMarketVolatility()
{
    double atr = CalcATR(_Symbol, _Period, 14, 0);
    double atrAvg = 0.0;
    
    // คำนวณ ATR เฉลี่ย 10 แท่ง
    for(int i = 1; i <= 10; i++)
    {
        atrAvg += CalcATR(_Symbol, _Period, 14, i);
    }
    atrAvg /= 10.0;
    
    // ถ้า ATR ปัจจุบันสูงกว่าเฉลี่ย 50% = ตลาดผันผวน
    s_marketVolatileMode = (atr > atrAvg * 1.5);
    
    if(s_marketVolatileMode)
    {
        // เพิ่มความระมัดระวังในโหมดผันผวน
        s_signalConfirmationBars = MathMax(s_signalConfirmationBars, 1);
    }
}

TrendType GetTrend(double priceHighPrev, double priceLowPrev, double priceHighCurr, double priceLowCurr)
  {
   if(priceHighCurr > priceHighPrev && priceLowCurr > priceLowPrev)
      return UPtrend;
   else if(priceHighCurr < priceHighPrev && priceLowCurr < priceLowPrev)
      return Downtrend;
   else
      return Sideway;
  }

// ฟังก์ชันแปลง TrendType เป็น ConfirmSignalType
ConfirmSignalType GetConfirmSignalByTrend(TrendType trend)
  {
	switch(trend)
	  {
		case UPtrend:
			return BOS_newhigh;
		case Downtrend:
			return BOS_newlow;
		case Sideway:
			return Waiting_Confirm_Signal;
		default:
			return Waiting_Confirm_Signal;
	  }
  }
// ฟังก์ชันตรวจจับการ Break ของแนวโน้ม
// - หากแนวโน้มเป็นขาขึ้น (UPtrend) แล้ว Low ปัจจุบันต่ำกว่า Low ก่อนหน้า => Break_UPtrend
// - หากแนวโน้มเป็นขาลง (Downtrend) แล้ว High ปัจจุบันสูงกว่า High ก่อนหน้า => Break_Downtrend
// - อื่นๆ ส่งกลับ Waiting_Confirm_Signal
ConfirmSignalType GetBreakSignal(TrendType trend,
																double prevHigh,
																double prevLow,
																double currHigh,
																double currLow)
	{
	 if(trend == UPtrend)
		 {
			if(currLow < prevLow)
				 return Break_UPtrend;
		 }
	 else if(trend == Downtrend)
		 {
			if(currHigh > prevHigh)
				 return Break_Downtrend;
		 }

	 return Waiting_Confirm_Signal;
	}

// ฟังก์ชันหลัก: ส่งค่ากลับสัญญาณ Break/BOS ตามแนวโน้มและ High/Low ของแท่งก่อนหน้า-ปัจจุบัน
// ลำดับความสำคัญ: ตรวจ break แนวโน้มก่อน จากนั้นค่อยพิจารณา BOS
// เพิ่มการป้องกัน False Signal
ConfirmSignalType GetPriceActionSignal(TrendType trend,
											 double prevHigh,
											 double prevLow,
											 double currHigh,
											 double currLow)
	{
	 // เน้นตามข้อกำหนด:
	 // - หาก Trend = UPtrend
	 //     • สร้าง new low (currLow < prevLow) => Break_UPtrend
	 //     • สร้าง new high (currHigh > prevHigh) => BOS_newhigh
	 // - หาก Trend = Downtrend (สมมาตร)
	 //     • สร้าง new high (currHigh > prevHigh) => Break_Downtrend
	 //     • สร้าง new low (currLow < prevLow) => BOS_newlow
	 // - อื่นๆ => Waiting_Confirm_Signal

		// คำนวณเงื่อนไข Buffer/ATR สำหรับยืนยันสัญญาณ
		double point = (_Point>0?_Point:0.0001);
		double bufferAbs = 0.0;
		if(InpUseBufferPoints)
			bufferAbs = MathMax(0.0, InpBufferPoints) * point;
		double atrAbs = 0.0;
		if(InpUseATRFilter)
			atrAbs = CalcATR(_Symbol, _Period, InpATRPeriod, 0) * MathMax(0.0, InpATRMultiplier);
		double threshold = MathMax(bufferAbs, atrAbs);

		// เพิ่มการป้องกัน False Signal ในตลาดผันผวน
		if(s_marketVolatileMode)
		{
			threshold *= 1.5; // เพิ่ม threshold ในตลาดผันผวน
		}

		// คำนวณ VWAP สำหรับกรองสัญญาณ
		double vwap = 0.0;
		if(InpUseVWAPFilter)
			vwap = CalcVWAP(_Symbol, _Period, InpVWAPPeriod, 0);

		// คำนวณ POC สำหรับกรองสัญญาณ (เพิ่มเติม)
		double poc = 0.0;
		bool pocFilter = false;
		if(InpUseVPFilter)
		{
			// ใช้การตั้งค่าปัจจุบัน: ช่วงเวลาจากเส้น หรือ lookback
			poc = CalcPOCWithCurrentSetting();
			if(poc > 0.0)
			{
				// ทำเครื่องหมายว่า POC พร้อมใช้งาน (หลีกเลี่ยงการคำนวณตัวแปรที่ไม่ได้ใช้งาน)
				pocFilter = true;
			}
		}

		// ตรวจสอบสัญญาณซ้ำ
		double currentPrice = (currHigh + currLow) / 2.0;
		if(IsSignalTooSimilar(currentPrice))
		{
			return Waiting_Confirm_Signal;
		}

		ConfirmSignalType potentialSignal = Waiting_Confirm_Signal;

		if(trend == UPtrend)
		{
			if(currLow < (prevLow - threshold))
			{
				// Break_UPtrend: ตรวจสอบ VWAP filter สำหรับ SELL signal
				if(InpUseVWAPFilter && vwap > 0.0)
				{
					double currentPrice = (currHigh + currLow + iClose(_Symbol, _Period, 0)) / 3.0;
					if(currentPrice >= vwap) // ราคายังอยู่เหนือ VWAP (ไม่เอาสัญญาณ SELL)
						return Waiting_Confirm_Signal;
				}
				
				// ตรวจสอบ Volume Profile POC filter สำหรับ SELL signal
				if(pocFilter)
				{
					double currentPrice = (currHigh + currLow + iClose(_Symbol, PERIOD_CURRENT, 0)) / 3.0;
					double pocDistancePoints = InpPOCDistance * (_Point > 0 ? _Point : 0.0001);
					// SELL signal ควรอยู่ใกล้ POC หรือสูงกว่า POC (resistance)
					if(MathAbs(currentPrice - poc) > pocDistancePoints && currentPrice < poc)
						return Waiting_Confirm_Signal;
				}
				
				potentialSignal = Break_UPtrend;
			}
			else if(currHigh > (prevHigh + threshold))
			{
				// BOS_newhigh: ตรวจสอบ VWAP filter สำหรับ BUY signal
				if(InpUseVWAPFilter && vwap > 0.0)
				{
					double currentPrice = (currHigh + currLow + iClose(_Symbol, _Period, 0)) / 3.0;
					if(currentPrice <= vwap) // ราคายังอยู่ใต้ VWAP (ไม่เอาสัญญาณ BUY)
						return Waiting_Confirm_Signal;
				}
				
				// ตรวจสอบ Volume Profile POC filter สำหรับ BUY signal
				if(pocFilter)
				{
					double currentPrice = (currHigh + currLow + iClose(_Symbol, PERIOD_CURRENT, 0)) / 3.0;
					double pocDistancePoints = InpPOCDistance * (_Point > 0 ? _Point : 0.0001);
					// BUY signal ควรอยู่ใกล้ POC หรือต่ำกว่า POC (support)
					if(MathAbs(currentPrice - poc) > pocDistancePoints && currentPrice > poc)
						return Waiting_Confirm_Signal;
				}
				
				potentialSignal = BOS_newhigh;
			}
		}
	 else if(trend == Downtrend)
		{
			if(currHigh > (prevHigh + threshold))
			{
				// Break_Downtrend: ตรวจสอบ VWAP filter สำหรับ BUY signal
				if(InpUseVWAPFilter && vwap > 0.0)
				{
					double currentPrice = (currHigh + currLow + iClose(_Symbol, _Period, 0)) / 3.0;
					if(currentPrice <= vwap) // ราคายังอยู่ใต้ VWAP (ไม่เอาสัญญาณ BUY)
						return Waiting_Confirm_Signal;
				}
				
				// ตรวจสอบ Volume Profile POC filter สำหรับ BUY signal
				if(pocFilter)
				{
					double currentPrice = (currHigh + currLow + iClose(_Symbol, PERIOD_CURRENT, 0)) / 3.0;
					double pocDistancePoints = InpPOCDistance * (_Point > 0 ? _Point : 0.0001);
					// BUY signal ควรอยู่ใกล้ POC หรือต่ำกว่า POC (support)
					if(MathAbs(currentPrice - poc) > pocDistancePoints && currentPrice > poc)
						return Waiting_Confirm_Signal;
				}
				
				potentialSignal = Break_Downtrend;
			}
			else if(currLow < (prevLow - threshold))
			{
				// BOS_newlow: ตรวจสอบ VWAP filter สำหรับ SELL signal
				if(InpUseVWAPFilter && vwap > 0.0)
				{
					double currentPrice = (currHigh + currLow + iClose(_Symbol, _Period, 0)) / 3.0;
					if(currentPrice >= vwap) // ราคายังอยู่เหนือ VWAP (ไม่เอาสัญญาณ SELL)
						return Waiting_Confirm_Signal;
				}
				
				// ตรวจสอบ Volume Profile POC filter สำหรับ SELL signal
				if(pocFilter)
				{
					double currentPrice = (currHigh + currLow + iClose(_Symbol, PERIOD_CURRENT, 0)) / 3.0;
					double pocDistancePoints = InpPOCDistance * (_Point > 0 ? _Point : 0.0001);
					// SELL signal ควรอยู่ใกล้ POC หรือสูงกว่า POC (resistance)
					if(MathAbs(currentPrice - poc) > pocDistancePoints && currentPrice < poc)
						return Waiting_Confirm_Signal;
				}
				
				potentialSignal = BOS_newlow;
			}
		}

		// ถ้ามีสัญญาณและผ่านการกรอง ให้บันทึกสัญญาณ
		if(potentialSignal != Waiting_Confirm_Signal)
		{
			RecordNewSignal(currentPrice);
			PrintFormat("[SIGNAL] %s detected at %.5f (Volatile: %s)", 
			           EnumToString(potentialSignal), currentPrice, 
			           s_marketVolatileMode ? "YES" : "NO");
		}

	 return potentialSignal;
	}

// ตัวช่วย: เรียกจาก symbol/timeframe โดยใช้ iHigh/iLow (รองรับ MQL5 EA/Indicator)
ConfirmSignalType GetPriceActionSignalFromSeries(TrendType trend,
													 string symbol,
													 ENUM_TIMEFRAMES timeframe,
													 int prevIndex=1,
													 int currIndex=0)
	{
	 double prevHigh=iHigh(symbol,timeframe,prevIndex);
	 double prevLow =iLow(symbol,timeframe,prevIndex);
	 double currHigh=iHigh(symbol,timeframe,currIndex);
	 double currLow =iLow(symbol,timeframe,currIndex);
	 return GetPriceActionSignal(trend, prevHigh, prevLow, currHigh, currLow);
	}

// ============================= Drawing Helpers =============================

// สร้างชื่ออ็อบเจกต์แบบ unique จาก prefix
string MakeUniqueName(string prefix)
	{
	 return prefix+"_"+IntegerToString((long)GetTickCount());
	}

// ชื่อ prefix สำหรับการจัดการลบ/รีเฟรช
string GetFiboPrefix(bool bullish){ return bullish?"SIG_FIBO_BUY":"SIG_FIBO_SELL"; }
string GetZonePrefix(bool bullish){ return bullish?"BUY_ZONE":"SELL_ZONE"; }

// ลบวัตถุเก่าตาม prefix
void ClearObjectsByPrefix(string prefix)
	{
	 long chart_id = ChartID();
	 int total = ObjectsTotal(chart_id, 0, -1);
	 for(int i=total-1;i>=0;i--)
		 {
			string name = ObjectName(chart_id, i, 0, -1);
			if(StringFind(name, prefix)==0) // เริ่มต้นด้วย prefix
				 ObjectDelete(chart_id, name);
		 }
	}

// สร้างเส้นแนวตั้งบนกราฟ
bool VLineCreate(const string          name,
					  datetime              time,
					  const color           clr=clrGreen,
					  const ENUM_LINE_STYLE style=STYLE_DOT,
					  const int             width=1,
					  const long            chart_ID=0,
					  const int             sub_window=0,
					  const bool            back=true,
					  const bool            selection=true,
					  const bool            ray=true,
					  const bool            hidden=false,
					  const long            z_order=0)
{
	if(time==0) time=TimeCurrent();
	ResetLastError();
	if(!ObjectCreate(chart_ID,name,OBJ_VLINE,sub_window,time,0))
	{
		Print(__FUNCTION__,": failed to create a vertical line! Error=",GetLastError());
		return false;
	}
	ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
	ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,(long)style);
	ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
	ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
	ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
	ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
	ObjectSetInteger(chart_ID,name,OBJPROP_RAY,ray);
	ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
	ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
	return true;
}

// วาดแท่งสี่เหลี่ยมแนวนอน (Rectangle Label) สำหรับแสดง Volume Profile bar
bool RectLabelCreate(const string           name,
							const int              x,
							const int              y,
							const int              width,
							const int              height,
							const color            clr,
							const color            back_clr=clrNONE,
							const ENUM_BORDER_TYPE border=BORDER_FLAT,
							const ENUM_BASE_CORNER corner=CORNER_LEFT_UPPER,
							const ENUM_LINE_STYLE  style=STYLE_SOLID,
							const int              line_width=1,
							const long             chart_ID=0,
							const int              sub_window=0,
							const bool             back=true,
							const bool             selection=false,
							const bool             hidden=true,
							const long             z_order=0)
{
	ResetLastError();
	if(!ObjectCreate(chart_ID,name,OBJ_RECTANGLE_LABEL,sub_window,0,0))
	{
		Print(__FUNCTION__,": failed to create a rectangle label! Error=",GetLastError());
		return false;
	}
	ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);
	ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);
	ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width);
	ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height);
	ObjectSetInteger(chart_ID,name,OBJPROP_BGCOLOR,back_clr);
	ObjectSetInteger(chart_ID,name,OBJPROP_BORDER_TYPE,border);
	ObjectSetInteger(chart_ID,name,OBJPROP_CORNER,corner);
	ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
	ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,(long)style);
	ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,line_width);
	ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
	ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
	ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
	ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
	ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
	return true;
}

// ตรวจและสร้างเส้นขอบช่วงสำหรับ Volume Profile ชนิด range
void EnsureVPRangeLines()
{
	if(!InpVPUseRange) return;
	// หากไม่มีให้สร้างเส้นเริ่มต้นและสิ้นสุดช่วง
	if(ObjectFind(0,"VP begin")<0)
	{
		datetime t0 = iTime(_Symbol, _Period, 60);
		if(t0==0) t0 = TimeCurrent() - (datetime)(61*PeriodSeconds(_Period));
		VLineCreate("VP begin", t0, clrGreen, STYLE_DOT, 1, 0, 0, true, true, true, false, 0);
	}
	if(ObjectFind(0,"VP finish")<0)
	{
		datetime t1 = iTime(_Symbol, _Period, 1);
		if(t1==0) t1 = TimeCurrent() - (datetime)(1*PeriodSeconds(_Period));
		VLineCreate("VP finish", t1, clrGreen, STYLE_DOT, 1, 0, 0, true, true, true, false, 0);
	}
}

// คำนวณ ATR
double CalcATR(string symbol, ENUM_TIMEFRAMES tf, int period, int shift)
	{
	 int handle = iATR(symbol, tf, period);
	 if(handle==INVALID_HANDLE) return 0.0;
	 double buf[];
	 ArraySetAsSeries(buf, true);
	 if(CopyBuffer(handle, 0, shift, 1, buf)<=0) 
	 {
		 IndicatorRelease(handle);
		 return 0.0;
	 }
	 double result = buf[0];
	 IndicatorRelease(handle);
	 return result;
	}

// คำนวณ VWAP (Volume Weighted Average Price)
double CalcVWAP(string symbol, ENUM_TIMEFRAMES tf, int period, int shift)
	{
	 double sumPV = 0.0;  // ผลรวมของ (Price * Volume)
	 double sumV = 0.0;   // ผลรวมของ Volume
	 
		for(int i = shift; i < shift + period; i++)
		 {
			double high = iHigh(symbol, tf, i);
			double low = iLow(symbol, tf, i);
			double close = iClose(symbol, tf, i);
			long volume = iRealVolume(symbol, tf, i);
			
			// หากไม่มี real volume ให้ใช้ tick volume
			if(volume == 0) volume = iTickVolume(symbol, tf, i);
			
			if(high == 0 || low == 0 || close == 0)
				continue;
				
			// Volume อาจเป็น 0 ในบางโบรกเกอร์/สินทรัพย์
			if(volume == 0) volume = 1; // ป้องกันหารด้วยศูนย์และกำหนด volume ต่ำสุด			// ราคาเฉลี่ย HLC/3 (Typical Price)
			double typicalPrice = (high + low + close) / 3.0;
			
			sumPV += typicalPrice * volume;
			sumV += (double)volume;
		 }
	 
	 if(sumV > 0)
		 return sumPV / sumV;
	 else
		 return 0.0;
	}

// คำนวณ Volume Profile และหา Point of Control (POC)
double CalcVolumeProfilePOC(string symbol, ENUM_TIMEFRAMES tf, int lookback, int precision, int shift = 0)
	{
	 // ตรวจสอบ parameters
	 if(lookback <= 0 || precision <= 0) return 0.0;
	 
	 // เตรียม arrays สำหรับข้อมูล
	 double high_array[], low_array[];
	 long volume_array[];
	 
	 ArrayResize(high_array, lookback);
	 ArrayResize(low_array, lookback);
	 ArrayResize(volume_array, lookback);
	 
	 // ดึงข้อมูล
	 if(CopyHigh(symbol, tf, shift, lookback, high_array) <= 0) return 0.0;
	 if(CopyLow(symbol, tf, shift, lookback, low_array) <= 0) return 0.0;
	 if(CopyRealVolume(symbol, tf, shift, lookback, volume_array) <= 0)
		 {
			// หากไม่มี real volume ให้ใช้ tick volume
			if(CopyTickVolume(symbol, tf, shift, lookback, volume_array) <= 0) return 0.0;
		 }
	 
	 // หา min-max price
	 double maxPrice = high_array[ArrayMaximum(high_array)];
	 double minPrice = low_array[ArrayMinimum(low_array)];
	 double priceRange = (maxPrice - minPrice) / precision;
	 
	 if(priceRange <= 0) return 0.0;
	 
	 // สร้าง Volume Profile array
	 double profile[];
	 ArrayResize(profile, precision);
	 ArrayInitialize(profile, 0.0);
	 
	 // คำนวณ Volume Profile
	 for(int i = 0; i < lookback; i++)
		 {
			if(volume_array[i] == 0) continue;
			
			double barHigh = high_array[i];
			double barLow = low_array[i];
			double barBody = barHigh - barLow;
			
			if(barBody <= 0) continue;
			
			int floorLevel = (int)MathFloor((barLow - minPrice) / priceRange);
			int ceilLevel = (int)MathFloor((barHigh - minPrice) / priceRange);
			
			// ป้องกัน index เกินขอบเขต
			floorLevel = MathMax(0, MathMin(floorLevel, precision - 1));
			ceilLevel = MathMax(0, MathMin(ceilLevel, precision - 1));
			
			for(int n = floorLevel; n <= ceilLevel; n++)
				{
				 double levelBottom = minPrice + n * priceRange;
				 double levelTop = minPrice + (n + 1) * priceRange;
				 double overlap = 0.0;
				 
				 if(floorLevel == ceilLevel)
					 {
						// แท่งทั้งหมดอยู่ใน level เดียว
						overlap = 1.0;
					 }
				 else if(n == floorLevel)
					 {
						// ส่วนล่างของแท่ง
						overlap = (levelTop - barLow) / barBody;
					 }
				 else if(n == ceilLevel)
					 {
						// ส่วนบนของแท่ง
						overlap = (barHigh - levelBottom) / barBody;
					 }
				 else
					 {
						// ส่วนกลางของแท่ง
						overlap = priceRange / barBody;
					 }
				 
				 profile[n] += (double)volume_array[i] * overlap;
				}
		 }
	 
	 // หา POC (Point of Control) - ระดับที่มี volume มากที่สุด
	 int maxVolumeIndex = ArrayMaximum(profile);
	 if(maxVolumeIndex < 0 || profile[maxVolumeIndex] <= 0) return 0.0;
	 
	 // คำนวณราคา POC (กึ่งกลางของ level ที่มี volume สูงสุด)
	 double pocPrice = minPrice + (maxVolumeIndex + 0.5) * priceRange;
	 
	 return pocPrice;
	}

// ดึงเวลาเริ่ม/สิ้นสุดจากเส้น "VP begin" และ "VP finish"
bool GetVPRangeTimes(datetime &t_begin, datetime &t_finish)
{
	if(ObjectFind(0, "VP begin")<0 || ObjectFind(0, "VP finish")<0)
		return false;
	t_begin = (datetime)ObjectGetInteger(0, "VP begin", OBJPROP_TIME);
	t_finish = (datetime)ObjectGetInteger(0, "VP finish", OBJPROP_TIME);
	if(t_begin==0 || t_finish==0) return false;
	if(t_finish < t_begin)
	{
		datetime tmp = t_begin; t_begin = t_finish; t_finish = tmp;
	}
	return true;
}

// สร้างโปรไฟล์ปริมาณในช่วงเวลาที่กำหนด และคืนค่า min/max/step พร้อม array โปรไฟล์
bool BuildVolumeProfileInRange(ENUM_TIMEFRAMES tf,
										 datetime t_begin,
										 datetime t_finish,
										 int precision,
										 double &minPrice,
										 double &maxPrice,
										 double &step,
										 double &profile[])
{
	if(precision<=0) return false;
	int idx_begin = iBarShift(_Symbol, tf, t_begin, false);
	int idx_finish = iBarShift(_Symbol, tf, t_finish, false);
	if(idx_begin<0 || idx_finish<0) return false;
	int start = MathMax(idx_begin, idx_finish);
	int end   = MathMin(idx_begin, idx_finish);
	int count = start - end + 1;
	if(count<=0) return false;

	double highs[]; double lows[]; long vols[];
	if(CopyHigh(_Symbol, tf, end, count, highs) != count) return false;
	if(CopyLow(_Symbol, tf, end, count, lows) != count) return false;
	if(CopyRealVolume(_Symbol, tf, end, count, vols) != count)
	{
		if(CopyTickVolume(_Symbol, tf, end, count, vols) != count) return false;
	}

	maxPrice = highs[ArrayMaximum(highs)];
	minPrice = lows[ArrayMinimum(lows)];
	if(maxPrice<=minPrice) return false;
	step = (maxPrice - minPrice) / precision;
	if(step<=0) return false;

	ArrayResize(profile, precision);
	ArrayInitialize(profile, 0.0);

	for(int i=0;i<count;i++)
	{
		double bh = highs[i];
		double bl = lows[i];
		long v = vols[i];
		if(v<=0) continue;
		double body = bh - bl;
		if(body<=0)
		{
			int k = (int)MathFloor((bl - minPrice)/step);
			k = MathMax(0, MathMin(k, precision-1));
			profile[k] += (double)v;
			continue;
		}
		int floorLevel = (int)MathFloor((bl - minPrice) / step);
		int ceilLevel  = (int)MathFloor((bh - minPrice) / step);
		floorLevel = MathMax(0, MathMin(floorLevel, precision-1));
		ceilLevel  = MathMax(0, MathMin(ceilLevel, precision-1));
		for(int n=floorLevel; n<=ceilLevel; n++)
		{
			double levelBottom = minPrice + n*step;
			double levelTop    = levelBottom + step;
			double overlap = 0.0;
			if(floorLevel==ceilLevel)
				overlap = 1.0;
			else if(n==floorLevel)
				overlap = (levelTop - bl) / body;
			else if(n==ceilLevel)
				overlap = (bh - levelBottom) / body;
			else
				overlap = step / body;
			profile[n] += (double)v * overlap;
		}
	}
	return true;
}

// คำนวณ POC price ในช่วงเวลาปัจจุบันจากเส้น VP begin/finish
double CalcPOCInRange(ENUM_TIMEFRAMES tf, datetime t_begin, datetime t_finish, int precision)
{
	double minP=0,maxP=0,step=0; double prof[];
	if(!BuildVolumeProfileInRange(tf, t_begin, t_finish, precision, minP, maxP, step, prof))
		return 0.0;
	int idx = ArrayMaximum(prof);
	if(idx<0 || prof[idx]<=0) return 0.0;
	return minP + (idx + 0.5) * step;
}

// คำนวณ POC ด้วยการตั้งค่าปัจจุบัน (ใช้ช่วง หรือ lookback)
double CalcPOCWithCurrentSetting()
{
	if(InpVPUseRange)
	{
		datetime tb=0, tf=0;
		if(GetVPRangeTimes(tb, tf))
			return CalcPOCInRange(InpTimeframe, tb, tf, InpVPPrecision);
	}
	return CalcVolumeProfilePOC(_Symbol, InpTimeframe, InpVPLookback, InpVPPrecision, 0);
}

// วาด VWAP line บนกราฟ โดยใช้เส้น TREND หลายเส้น
void DrawVWAPLine()
	{
	 if(!InpDrawVWAP) return;
	 
	 // ลบเส้น VWAP เก่า
	 ClearObjectsByPrefix("VWAP_LINE_");
	 
	 // กำหนดจำนวนแท่งที่ต้องการวาด
	 int barsToDraw = 100; 
	 int totalBars = Bars(_Symbol, InpTimeframe);
	 int bars = MathMin(barsToDraw, totalBars);
	 if(bars < 2) return;
	 
	 // วาดเส้น VWAP โดยใช้เส้น TREND ต่อกัน
	 for(int i = 1; i < bars; i++)
		 {
			double vwap1 = CalcVWAP(_Symbol, InpTimeframe, InpVWAPPeriod, i);
			double vwap2 = CalcVWAP(_Symbol, InpTimeframe, InpVWAPPeriod, i-1);
			
			if(vwap1 <= 0.0 || vwap2 <= 0.0) continue;
			
			datetime time1 = iTime(_Symbol, InpTimeframe, i);
			datetime time2 = iTime(_Symbol, InpTimeframe, i-1);
			
			if(time1 == 0 || time2 == 0) continue;
			
			string lineName = StringFormat("VWAP_LINE_%d", i);
			
			if(ObjectCreate(0, lineName, OBJ_TREND, 0, time1, vwap1, time2, vwap2))
			{
				ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpVWAPColor);
				ObjectSetInteger(0, lineName, OBJPROP_WIDTH, InpVWAPWidth);
				ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
				ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
				ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
				ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT, false);
				ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
			}
		 }
	 
	 ChartRedraw(0);
	}

// วาดเส้น POC (Point of Control) บนกราฟ
void DrawPOCLine()
	{
	 if(!InpDrawPOC || !InpUseVPFilter) return;
	 
	 // คำนวณ POC ปัจจุบัน (รองรับช่วงเวลา)
	 double currentPOC = CalcPOCWithCurrentSetting();
	 if(currentPOC <= 0.0) return;
	 
	 // อัปเดต POC ล่าสุด
	 s_lastPOC = currentPOC;
	 
	 string objectName = "POC_LINE";
	 
	 // ลบเส้นเก่าเพื่อวาดใหม่
	 ObjectDelete(0, objectName);
	 
	 // วาดเส้นแนวนอน POC
	 if(ObjectCreate(0, objectName, OBJ_HLINE, 0, 0, currentPOC))
		 {
			ObjectSetInteger(0, objectName, OBJPROP_COLOR, InpPOCColor);
			ObjectSetInteger(0, objectName, OBJPROP_WIDTH, InpPOCWidth);
			ObjectSetInteger(0, objectName, OBJPROP_STYLE, (long)STYLE_SOLID);
			ObjectSetInteger(0, objectName, OBJPROP_BACK, false);
			ObjectSetInteger(0, objectName, OBJPROP_SELECTABLE, false);
			
			ChartRedraw(0);
		 }
	}

// วาดแท่ง Volume Profile ภายในช่วงเวลา (ต้องตั้ง InpVPUseRange=true)
void DrawVPBarsInRange()
{
	if(!InpDrawVPBars || !InpVPUseRange) return;
	datetime tb=0, tf=0;
	if(!GetVPRangeTimes(tb, tf)) return;

	double minP=0,maxP=0,step=0; double prof[];
	if(!BuildVolumeProfileInRange(InpTimeframe, tb, tf, InpVPPrecision, minP, maxP, step, prof)) return;
	// ลบของเดิม
	ClearObjectsByPrefix("VP_BAR_");

	// หาค่าสูงสุดสำหรับ normalize ความยาวแท่ง
	int maxIdx = ArrayMaximum(prof);
	double maxVal = (maxIdx>=0? prof[maxIdx]:0.0);
	if(maxVal<=0) return;

	long chartId=0; int wnd=0;
	// ความกว้างสูงสุดเป็นสัดส่วนของความกว้างกราฟ
	long chartW = (long)ChartGetInteger(chartId, CHART_WIDTH_IN_PIXELS, wnd);
	int maxWidth = (int)MathRound((double)chartW * MathMax(0.0, MathMin(1.0, InpVPBarsRatio)));
	if(maxWidth<=1) maxWidth=1;

	// วาดแท่งสำหรับแต่ละ level
	for(int n=0; n<InpVPPrecision; n++)
	{
		if(prof[n]<=0) continue;
		// mid price และขอบเขตบน/ล่างของ level
		double levelBottom = minP + n*step;
		double levelTop    = levelBottom + step;
		double levelMid    = (levelBottom + levelTop) * 0.5;

		int x=0, yMid=0;
		if(!ChartTimePriceToXY(chartId, wnd, TimeCurrent(), levelMid, x, yMid))
		{
			// หากไม่ได้ y ให้ลองใช้เวลาล่าสุดอีกครั้ง
			int dummyx=0, dummyy=0;
			ChartTimePriceToXY(chartId, wnd, iTime(_Symbol, InpTimeframe, 0), levelMid, dummyx, yMid);
		}

		int yTop=0, yBot=0, dummyx=0;
		if(!ChartTimePriceToXY(chartId, wnd, TimeCurrent(), levelTop, dummyx, yTop)) continue;
		if(!ChartTimePriceToXY(chartId, wnd, TimeCurrent(), levelBottom, dummyx, yBot)) continue;
		int height = MathMax(1, MathAbs(yBot - yTop));

		int width = (int)MathRound(maxWidth * (prof[n]/maxVal));
		if(width<=0) continue;
		int baseX = 20; // เว้นระยะจากซ้ายเล็กน้อย
		int y = yTop;   // วางมุมซ้ายบนที่ yTop
		string name = StringFormat("VP_BAR_%d", n);
		color col = (n==maxIdx? InpPOCColor : InpVPBarsColor);
		RectLabelCreate(name, baseX, y, width, height, col, clrNONE, BORDER_FLAT, CORNER_LEFT_UPPER, STYLE_SOLID, 1, chartId, wnd, true, false, true, 0);
	}
	ChartRedraw(0);
}

// แจ้งเตือน
void NotifySignal(ConfirmSignalType signal)
	{
	string msg = StringFormat("Signal: %d on %s %s", (int)signal, _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period));
	 if(InpAlerts) Alert(msg);
	 if(InpPush)   SendNotification(msg);
	}

// แปลงสัญญาณเป็นข้อความฝั่ง
string SignalSide(ConfirmSignalType signal)
	{
	 if(signal==BOS_newhigh || signal==Break_Downtrend) return "BUY";
	 if(signal==BOS_newlow  || signal==Break_UPtrend)    return "SELL";
	 return "WAIT";
	}

// ปรับล็อตให้เป็นไปตามข้อกำหนดของสัญลักษณ์
double NormalizeLots(double lots, string symbol)
	{
	 double volMin=0, volMax=0, volStep=0;
	 SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN, volMin);
	 SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX, volMax);
	 SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP, volStep);
	 double v = MathMax(volMin, MathMin(lots, volMax));
	 if(volStep>0)
		 {
		 v = volMin + MathFloor((v - volMin)/volStep + 1e-8)*volStep;
		 }
	 // Clamp อีกครั้งเพื่อความปลอดภัย
	 if(v < volMin) v = volMin;
	 if(v > volMax) v = volMax;
	 return v;
	}

// ตรวจว่าอนุญาตให้เทรดหรือไม่ พร้อมพิมพ์สาเหตุ
bool IsTradingAvailable(string symbol)
	{
	if(MQLInfoInteger(MQL_TESTER) && InpTesterIgnoreSessions)
		return true; // ข้ามในโหมดทดสอบ
	 bool termAllowed = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
	 bool mqlAllowed  = (bool)MQLInfoInteger(MQL_TRADE_ALLOWED);
	 long tradeMode = 0;
	 bool gotMode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE, tradeMode);

	 if(!termAllowed) Print("[TRADE] Terminal trade not allowed");
	 if(!mqlAllowed)  Print("[TRADE] MQL trade not allowed (check Options > Expert Advisors)");
	 if(!gotMode)     Print("[TRADE] Cannot get SYMBOL_TRADE_MODE for ", symbol);

	 bool symAllowed = gotMode && (tradeMode != SYMBOL_TRADE_MODE_DISABLED) && (tradeMode != SYMBOL_TRADE_MODE_CLOSEONLY);
	 if(gotMode && !symAllowed)
		{
		 Print("[TRADE] Symbol ", symbol, " trade mode disallows opening new positions (mode=", (int)tradeMode, ")");
		}

	 return termAllowed && mqlAllowed && symAllowed;
	}

// ตรวจอนุญาตให้เปิดสถานะตามฝั่ง Buy/Sell จากโหมดการเทรดของสัญลักษณ์
bool IsTradeAllowedForSide(string symbol, bool isBuy)
	{
	if(MQLInfoInteger(MQL_TESTER) && InpTesterIgnoreSessions)
		return true; // ข้ามในโหมดทดสอบ
	 long mode = 0;
	 if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE, mode))
		{
		 Print("[TRADE] Cannot get SYMBOL_TRADE_MODE for ", symbol);
		 return false;
		}
	 if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_CLOSEONLY)
		 return false;
	 if(mode == SYMBOL_TRADE_MODE_FULL)
		 return true;
	 if(mode == SYMBOL_TRADE_MODE_LONGONLY)
		 return isBuy;
	 if(mode == SYMBOL_TRADE_MODE_SHORTONLY)
		 return !isBuy;
	 // เผื่อโหมดอื่นๆ ที่อาจเพิ่มในอนาคต
	 return true;
	}

// ตรวจว่ามีราคา พร้อมเปิดใช้งานสัญลักษณ์ถ้ายังไม่พร้อม
bool EnsureSymbolReady(string symbol)
	{
	 if(!SymbolSelect(symbol,true))
		 {
			Print("[TRADE] SymbolSelect failed for ", symbol);
			return false;
		 }
	 MqlTick tick;
	 if(!SymbolInfoTick(symbol, tick))
		 {
			Print("[TRADE] No tick prices for ", symbol);
			return false;
		 }
	 return true;
	}

// ตั้งค่า filling mode ตามสัญลักษณ์ถ้าเป็นไปได้
void SetupFillingMode(string symbol)
	{
	 long fill=0;
	 if(SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE, fill))
		 {
			m_trade.SetTypeFilling((ENUM_ORDER_TYPE_FILLING)fill);
		 }
	}

// แสดงข้อมูลวินิจฉัยของสัญลักษณ์ (ช่วยตรวจสอบใน Tester)
void LogSymbolDiagnostics(string symbol)
	{
	 bool inTester = (bool)MQLInfoInteger(MQL_TESTER);
	 long mode=0; SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE, mode);
	 string modeName;
	 switch((int)mode)
		 {
			case SYMBOL_TRADE_MODE_DISABLED:  modeName="DISABLED";  break;
			case SYMBOL_TRADE_MODE_CLOSEONLY: modeName="CLOSEONLY"; break;
			case SYMBOL_TRADE_MODE_LONGONLY:  modeName="LONGONLY";  break;
			case SYMBOL_TRADE_MODE_SHORTONLY: modeName="SHORTONLY"; break;
			case SYMBOL_TRADE_MODE_FULL:      modeName="FULL";      break;
			default:                          modeName=IntegerToString((int)mode);
		 }
	 int digits=(int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
	 double pt=_Point;
	 double vmin=0,vmax=0,vstep=0; 
	 SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN, vmin);
	 SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX, vmax);
	 SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP, vstep);
	 PrintFormat("[SYMBOL] '%s' Tester=%s mode=%s digits=%d point=%.10f vol[min=%.2f max=%.2f step=%.2f]",
							 symbol, inTester?"yes":"no", modeName, digits, pt, vmin, vmax, vstep);
	}

// ช่วยปรับราคาให้ตรงจำนวนหลักของสัญลักษณ์
double NormalizePrice(string symbol, double price)
	{
	 int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
	 return NormalizeDouble(price, digits);
	}

// รอและดึงราคาที่ใช้ส่งคำสั่ง (BUY ใช้ Ask, SELL ใช้ Bid)
bool GetOrderPrice(string symbol, bool isBuy, double &priceOut, int timeoutMs=1500)
	{
	 uint start = GetTickCount();
	 MqlTick tick;
	 while((GetTickCount()-start) < (uint)timeoutMs)
		{
		 if(SymbolInfoTick(symbol, tick))
			{
			 double p = isBuy ? tick.ask : tick.bid;
			 if(p>0.0)
				{
				 priceOut = NormalizePrice(symbol, p);
				 return true;
				}
			}
		 // ลองดึงจาก SYMBOL_ASK/BID เป็นทางเลือก
		 double alt=0.0;
		 if(isBuy ? SymbolInfoDouble(symbol, SYMBOL_ASK, alt) : SymbolInfoDouble(symbol, SYMBOL_BID, alt))
			{
			 if(alt>0.0)
				{
				 priceOut = NormalizePrice(symbol, alt);
				 return true;
				}
			}
		 Sleep(100);
		}
	 return false;
	}

// วาดเส้นแนวนอนที่ราคา price ด้วยชื่อ name
bool DrawHLine(string name, double price, color col, int width=1)
  {
	long chart_id = ChartID();
	if(!ObjectCreate(chart_id, name, OBJ_HLINE, 0, 0, price))
		return false;
	ObjectSetInteger(chart_id, name, OBJPROP_COLOR, col);
	ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, width);
	ObjectSetInteger(chart_id, name, OBJPROP_BACK, false);
	return true;
  }

// เลือก filling mode สำหรับคำสั่ง ตามสัญลักษณ์ปัจจุบัน (fallback เป็น FOK)
ENUM_ORDER_TYPE_FILLING ChooseFillingMode()
	{
	 long fill=0;
	 if(SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE, fill))
			return (ENUM_ORDER_TYPE_FILLING)fill;
	 return ORDER_FILLING_FOK;
	}

// ส่งคำสั่งด้วยโอกาส fallback เล็กน้อย: อัปเดตราคาและลองใหม่เมื่อ REQUOTE/PRICE_OFF/TIMEOUT
bool OrderSendWithFillingFallback(MqlTradeRequest &request, MqlTradeResult &result, int attempts=3)
	{
	 for(int i=0;i<attempts;i++)
		 {
			// อัปเดตราคาตามฝั่งคำสั่งทุกครั้งก่อนส่ง
			double px=0.0;
			if(request.type==ORDER_TYPE_BUY)
				{
				 if(!SymbolInfoDouble(_Symbol, SYMBOL_ASK, px) || px<=0.0) { Sleep(100); continue; }
				}
			else if(request.type==ORDER_TYPE_SELL)
				{
				 if(!SymbolInfoDouble(_Symbol, SYMBOL_BID, px) || px<=0.0) { Sleep(100); continue; }
				}
			request.price = NormalizePrice(_Symbol, px);

			ZeroMemory(result);
			if(OrderSend(request, result))
				 return true;

			// ลองใหม่เฉพาะเคสชั่วคราว
			if(result.retcode==TRADE_RETCODE_REQUOTE || result.retcode==TRADE_RETCODE_PRICE_OFF || result.retcode==TRADE_RETCODE_TIMEOUT)
				{
				 PrintFormat("[REQ] Retry %d/%d due to retcode=%u", i+1, attempts, result.retcode);
				 Sleep(200);
				 continue;
				}

			// หากล้มเหลวด้วยเหตุผลอื่น ให้ลองเปลี่ยน filling mode สักครั้ง
			static const ENUM_ORDER_TYPE_FILLING altFills[3] = { ORDER_FILLING_RETURN, ORDER_FILLING_FOK, ORDER_FILLING_IOC };
			for(int k=0;k<3;k++)
				{
				 if(altFills[k]==request.type_filling) continue;
				 request.type_filling = altFills[k];
				 ZeroMemory(result);
				 if(OrderSend(request, result))
						return true;
				 if(result.retcode==TRADE_RETCODE_REQUOTE || result.retcode==TRADE_RETCODE_PRICE_OFF || result.retcode==TRADE_RETCODE_TIMEOUT)
					 {
						Sleep(150);
						continue;
					 }
				}
			// ออกจากลูปถ้าล้มเหลวและไม่ใช่เคสชั่วคราว
			break;
		 }
	 return false;
	}

// เปิด BUY ด้วย MqlTradeRequest (ไม่ตั้ง SL/TP)
bool OpenBuyOrder(double lots, string cmt)
	{
	 double ask = 0.0; if(!SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask) || ask<=0.0){ Print("OpenBuyOrder: failed to get ask price"); return false; }
	 MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
	 req.action       = TRADE_ACTION_DEAL;
	 req.symbol       = _Symbol;
	 req.volume       = lots;
	 req.type         = ORDER_TYPE_BUY;
	 req.price        = NormalizePrice(_Symbol, ask);
	 req.sl           = 0.0;
	 req.tp           = 0.0;
	 req.type_time    = ORDER_TIME_GTC;
	 req.type_filling = ChooseFillingMode();
	 req.deviation    = InpDeviationPoints;
	 req.comment      = cmt;
	 req.magic        = InpMagic;

	 bool ok = OrderSendWithFillingFallback(req, res, 3);
	 if(ok)
		 {
			PrintFormat("BUY ok: order=%I64u price=%.5f lots=%.2f", res.order, res.price, lots);
			return true;
		 }
	 PrintFormat("BUY failed: retcode=%u price=%.5f dev=%d", res.retcode, req.price, (int)req.deviation);
	 return false;
	}

// เปิด SELL ด้วย MqlTradeRequest (ไม่ตั้ง SL/TP)
bool OpenSellOrder(double lots, string cmt)
	{
	 double bid = 0.0; if(!SymbolInfoDouble(_Symbol, SYMBOL_BID, bid) || bid<=0.0){ Print("OpenSellOrder: failed to get bid price"); return false; }
	 MqlTradeRequest req; MqlTradeResult res; ZeroMemory(req); ZeroMemory(res);
	 req.action       = TRADE_ACTION_DEAL;
	 req.symbol       = _Symbol;
	 req.volume       = lots;
	 req.type         = ORDER_TYPE_SELL;
	 req.price        = NormalizePrice(_Symbol, bid);
	 req.sl           = 0.0;
	 req.tp           = 0.0;
	 req.type_time    = ORDER_TIME_GTC;
	 req.type_filling = ChooseFillingMode();
	 req.deviation    = InpDeviationPoints;
	 req.comment      = cmt;
	 req.magic        = InpMagic;

	 bool ok = OrderSendWithFillingFallback(req, res, 3);
	 if(ok)
		 {
			PrintFormat("SELL ok: order=%I64u price=%.5f lots=%.2f", res.order, res.price, lots);
			return true;
		 }
	 PrintFormat("SELL failed: retcode=%u price=%.5f dev=%d", res.retcode, req.price, (int)req.deviation);
	 return false;
	}

/* Deprecated: ใช้ ExecuteTradeByTRadetype แทน
bool ExecuteTradeBySignal(ConfirmSignalType signal) { return false; }
*/

// วาด Fibonacci จากจุด (t1,p1) ไป (t2,p2)
bool DrawFibo(string name, datetime t1, double p1, datetime t2, double p2, color col)
	{
	 long chart_id = ChartID();
	 if(!ObjectCreate(chart_id, name, OBJ_FIBO, 0, t1, p1, t2, p2))
			return false;
	 ObjectSetInteger(chart_id, name, OBJPROP_COLOR, col);
	 ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, true);
	 ObjectSetInteger(chart_id, name, OBJPROP_SELECTED, false);
	 ObjectSetInteger(chart_id, name, OBJPROP_BACK, false);
	 return true;
	}

// วาดโซนเข้าเทรดเป็นสี่เหลี่ยมจากเวลา-ราคา ซ้ายไปขวา
bool DrawZone(string name, datetime t_left, datetime t_right, double price_top, double price_bottom, color col, bool back=true)
	{
	 long chart_id = ChartID();
	 if(t_right < t_left)
		 {
			datetime tmp=t_left; t_left=t_right; t_right=tmp;
		 }
	 if(price_top < price_bottom)
		 {
			double tmp=price_top; price_top=price_bottom; price_bottom=tmp;
		 }
	 if(!ObjectCreate(chart_id, name, OBJ_RECTANGLE, 0, t_left, price_top, t_right, price_bottom))
			return false;
	 ObjectSetInteger(chart_id, name, OBJPROP_COLOR, col);
	 ObjectSetInteger(chart_id, name, OBJPROP_BACK, back);
	 ObjectSetInteger(chart_id, name, OBJPROP_WIDTH, 1);
	 return true;
	}

// ============================= Main Drawing API =============================

// วาด Fibonacci และโซนเข้าเทรดตามสัญญาณที่ได้รับ
// สำหรับสัญญาณฝั่ง Bullish (BOS_newhigh, Break_Downtrend):
//   - วาด Fibo จาก swingLow -> swingHigh
//   - วาดโซนเข้าซื้อระหว่าง 0.618 - 0.5 retracement
// สำหรับสัญญาณฝั่ง Bearish (BOS_newlow, Break_UPtrend):
//   - วาด Fibo จาก swingHigh -> swingLow
//   - วาดโซนเข้าขายระหว่าง 0.618 - 0.5 retracement
// หมายเหตุ: หาก Waiting_Confirm_Signal จะไม่วาดและคืน 0.0
 double DrawFiboAndZoneBySignal(ConfirmSignalType signal,
								 string symbol,
								 ENUM_TIMEFRAMES timeframe,
								 int prevIndex,
								 int currIndex,
								 int extendBarsRight=10)
    {
     if(signal==Waiting_Confirm_Signal)
	     return 0.0;

	 // ดึงข้อมูลแท่ง
	 double prevHigh=iHigh(symbol,timeframe,prevIndex);
	 double prevLow =iLow(symbol,timeframe,prevIndex);
	 double currHigh=iHigh(symbol,timeframe,currIndex);
	 double currLow =iLow(symbol,timeframe,currIndex);
	 datetime t1=iTime(symbol,timeframe,prevIndex);
	 datetime t2=iTime(symbol,timeframe,currIndex);
     if(prevHigh==0 || prevLow==0 || currHigh==0 || currLow==0)
	     return 0.0;

	 // หาความยาวบาร์เป็นวินาทีเพื่อขยายโซนไปทางขวา
	 int secPerBar = (int)PeriodSeconds(timeframe);
	 if(secPerBar<=0) secPerBar=60; // fallback
	 datetime t_right = t2 + (datetime)(secPerBar*extendBarsRight);

	 // กำหนด swing และทิศทางจาก signal
		bool bullish = (signal==BOS_newhigh || signal==Break_Downtrend);
	 double swingHigh = bullish ? currHigh : prevHigh;
	 double swingLow  = bullish ? prevLow  : currLow;

	 // ป้องกันค่าไม่เหมาะสม
	 double range = swingHigh - swingLow;
	if(range<=0) return 0.0;

	 // คำนวณระดับ fibo zone 0.618-0.5 สำหรับทิศทางที่เลือก
		 double zoneTop, zoneBottom;
	 if(bullish)
		 {
				// วัดจาก swingLow -> swingHigh โดยใช้ระดับโซนจาก input
				double upper = swingHigh - InpZoneLevelTop*range;
				double lower = swingHigh - InpZoneLevelBottom*range;
				zoneTop = MathMax(upper, lower);
				zoneBottom = MathMin(upper, lower);
		 }
	 else
		 {
				// วัดจาก swingHigh -> swingLow โดยใช้ระดับโซนจาก input
				double upper = swingLow + InpZoneLevelTop*range;
				double lower = swingLow + InpZoneLevelBottom*range;
				zoneTop = MathMax(upper, lower);
				zoneBottom = MathMin(upper, lower);
		 }

		 // ลบวัตถุเก่าหากกำหนด
		 if(InpClearPrevious)
			 {
				ClearObjectsByPrefix(GetFiboPrefix(bullish));
				ClearObjectsByPrefix(GetZonePrefix(bullish));
			 }

		 // สร้างชื่อวัตถุด้วย prefix เพื่อจัดการในอนาคต
		 string fibName = GetFiboPrefix(bullish)+"_"+MakeUniqueName("OBJ");
		 string zoneName = GetZonePrefix(bullish)+"_"+MakeUniqueName("OBJ");

	 // วาด Fibonacci
		bool okFibo = bullish
						  ? DrawFibo(fibName, t1, swingLow, t2, swingHigh, InpFiboColorBull)
						  : DrawFibo(fibName, t1, swingHigh, t2, swingLow, InpFiboColorBear);

		 // วาดโซน (ขยายจาก t1 ถึง t_right เพื่อให้เห็นพื้นที่อนาคต)
		 bool okZone = DrawZone(zoneName, t1, t_right, zoneTop, zoneBottom, bullish?InpZoneColorBuy:InpZoneColorSell, true);

			// วาดเส้นแนวนอน Entry ตำแหน่งกึ่งกลางโซน
			bool okLine=true;
		 if(InpDrawEntryLine)
			 {
				double entryPrice = (zoneTop + zoneBottom) * 0.5;
				string lineName = MakeUniqueName(bullish?"ENTRY_BUY":"ENTRY_SELL");
				okLine = DrawHLine(lineName, entryPrice, bullish?InpEntryBuyColor:InpEntrySellColor, InpEntryLineWidth);
				// แจ้งเตือนทันทีพร้อมระดับราคา
				if((InpAlerts || InpPush) && okLine)
					{
					 string side = bullish?"BUY":"SELL";
					 string msg = StringFormat("%s signal at %.5f on %s %s", side, entryPrice, _Symbol, EnumToString(timeframe));
					 if(InpAlerts) Alert(msg);
					 if(InpPush)   SendNotification(msg);
					}
			 }

			// คืนค่า Entry Price เมื่อวาดสำเร็จ
			if(okFibo && okZone && okLine)
				return (zoneTop + zoneBottom) * 0.5;
			return 0.0;
	}

	// Overload: ใช้ _Symbol และ _Period ให้เรียกง่ายขึ้น
	 double DrawFiboAndZoneBySignal(ConfirmSignalType signal,
											  int prevIndex=1,
											  int currIndex=0,
											  int extendBarsRight=10)
		{
		 return DrawFiboAndZoneBySignal(signal, _Symbol, _Period, prevIndex, currIndex, extendBarsRight);
		}

		// ============================= One-shot API =============================
		// วิเคราะห์เทรนด์ -> หา ConfirmSignal -> (ถ้ากำหนด) วาด Fibo/Zone แล้วคืนค่า TRadetype
		// วิเคราะห์เทรนด์ -> หา ConfirmSignal -> วาด Fibo/Zone และตั้งค่าสถานะการรอคอย
		bool AnalyzeTrendSignalAndDraw(string symbol,
									   ENUM_TIMEFRAMES timeframe,
									   int prevIndex=1,
									   int currIndex=0,
									   bool autoDraw=true,
									   int extendBarsRight=10)
		{
			double prevHigh=iHigh(symbol,timeframe,prevIndex);
			double prevLow =iLow(symbol,timeframe,prevIndex);
			double currHigh=iHigh(symbol,timeframe,currIndex);
			double currLow =iLow(symbol,timeframe,currIndex);
			if(prevHigh==0 || prevLow==0 || currHigh==0 || currLow==0)
				return false;

			// 1) วิเคราะห์เทรนด์
			TrendType trend = GetTrend(prevHigh, prevLow, currHigh, currLow);

			// 2) หา confirm signal
			ConfirmSignalType signal = GetPriceActionSignal(trend, prevHigh, prevLow, currHigh, currLow);

			// ตรวจสอบสัญญาณที่ต้องรอ Pullback
			bool isBuySignal = (signal == BOS_newhigh || signal == Break_Downtrend);
			bool isSellSignal = (signal == BOS_newlow || signal == Break_UPtrend);

			if(!isBuySignal && !isSellSignal)
			{
				// ถ้าไม่มีสัญญาณที่ต้องรอ ให้คงสถานะเดิมหรือเป็น NO_SIGNAL
				// s_currentState = STATE_NO_SIGNAL; // อาจจะแค่คงไว้
				return false;
			}

			// 3) วาด Fibo/Zone (รวมเส้นแนวนอน/การแจ้งเตือนที่เกี่ยวกับการวาด)
			double entryPrice = 0.0;
			if(autoDraw)
			{
				entryPrice = DrawFiboAndZoneBySignal(signal, symbol, timeframe, prevIndex, currIndex, extendBarsRight);
			}

			if(entryPrice > 0.0)
			{
				// 4) ตั้งค่าสถานะการรอคอย
				if(isBuySignal)
				{
					s_currentState = STATE_PULLBACK_WAIT_BUY;
					s_entryPrice = entryPrice;
					PrintFormat("[SIGNAL] Waiting BUY pullback at %.5f", s_entryPrice);
				}
				else if(isSellSignal)
				{
					s_currentState = STATE_PULLBACK_WAIT_SELL;
					s_entryPrice = entryPrice;
					PrintFormat("[SIGNAL] Waiting SELL pullback at %.5f", s_entryPrice);
				}
				return true;
			}

			return false;
		}
		// Overload
		bool AnalyzeTrendSignalAndDraw(int prevIndex=1, int currIndex=0, bool autoDraw=true, int extendBarsRight=10)
		{
			return AnalyzeTrendSignalAndDraw(_Symbol, _Period, prevIndex, currIndex, autoDraw, extendBarsRight);
		}

// ตรวจสอบราคา Pullback และดำเนินการเปิดออเดอร์ (เรียกใน OnTick ทุกครั้ง)
void CheckAndExecutePullback()
{
	if (!InpEnableTrading || s_currentState == STATE_NO_SIGNAL || s_entryPrice <= 0.0)
		return;

	if (!EnsureSymbolReady(_Symbol)) 
		return;

	MqlTick tick;
	if (!SymbolInfoTick(_Symbol, tick))
		return;
    
	double lots = NormalizeLots(InpLots, _Symbol);
	if(lots<=0) return;
	string cmt = "SMC_AT Entry"; 
    
	bool isTradeExecuted = false;

	// ตรรกะการเข้า BUY (Pullback)
	if (s_currentState == STATE_PULLBACK_WAIT_BUY)
	{
		// ตรวจสอบว่า Bid (ราคาที่คุณจะเข้าซื้อ) ต่ำกว่าหรือเท่ากับ Entry Price หรือไม่
		if (tick.bid <= s_entryPrice) 
		{
			// ตรวจสอบสิทธิ์ (ถ้าไม่ใช้ Tester)
			if(MQLInfoInteger(MQL_TESTER) || (IsTradingAvailable(_Symbol) && IsTradeAllowedForSide(_Symbol, true)))
			{
				isTradeExecuted = OpenBuyOrder(lots, cmt + " BUY");
			}
		}
	}
	// ตรรกะการเข้า SELL (Pullback)
	else if (s_currentState == STATE_PULLBACK_WAIT_SELL)
	{
		// ตรวจสอบว่า Ask (ราคาที่คุณจะเข้าขาย) สูงกว่าหรือเท่ากับ Entry Price หรือไม่
		if (tick.ask >= s_entryPrice)
		{
			// ตรวจสอบสิทธิ์ (ถ้าไม่ใช้ Tester)
			if(MQLInfoInteger(MQL_TESTER) || (IsTradingAvailable(_Symbol) && IsTradeAllowedForSide(_Symbol, false)))
			{
				isTradeExecuted = OpenSellOrder(lots, cmt + " SELL");
			}
		}
	}
	// เมื่อเปิดออเดอร์สำเร็จ ให้รีเซ็ตสถานะเพื่อป้องกันการเปิดซ้ำ
	if (isTradeExecuted)
	{
		PrintFormat("[EXECUTE] Order filled at pullback price %.5f. Resetting state.", s_entryPrice);
		s_currentState = STATE_NO_SIGNAL;
		s_entryPrice = 0.0;
		// หากต้องการลบ Fibo/Zone ทันทีที่เปิดออเดอร์ให้เพิ่ม Logic การลบตรงนี้
	}
}

// void ExecuteTradeByTRadetype(TRadetype tradeType) { /* ไม่จำเป็นต้องใช้แล้ว */ }

	//=============================================================================
	// Event handlers
	int OnInit()
		{
		 s_lastBarTime = 0;
		 s_vwapUpdateCounter = 0;  // รีเซ็ตตัวนับ VWAP
		 s_lastPOC = 0.0;          // รีเซ็ต POC
		 s_tickCounter = 0;        // รีเซ็ตตัวนับ tick
		 s_objectCount = 0;        // รีเซ็ตตัวนับวัตถุ
		 s_lastSignalTime = 0;     // รีเซ็ตเวลาสัญญาณล่าสุด
		 s_lastSignalPrice = 0.0;  // รีเซ็ตราคาสัญญาณล่าสุด
		 s_signalConfirmationBars = 1; // ค่าเริ่มต้น
		 s_marketVolatileMode = false; // โหมดปกติ
		 
		 // ตั้งค่าตาม Preset Mode
		 ApplyPresetSettings();
		 
		 LogSymbolDiagnostics(_Symbol);

			// สร้างเส้นกำหนดช่วง Volume Profile หากเลือกใช้
			EnsureVPRangeLines();
		
		// วาด VWAP เริ่มต้น
		if(InpDrawVWAP)
			DrawVWAPLine();
			
		// วาด POC เริ่มต้น
		if(InpUseVPFilter && InpDrawPOC)
			DrawPOCLine();

		// วาดแท่ง VP เริ่มต้น (ถ้าเปิดใช้งาน)
		if(InpVPUseRange && InpDrawVPBars)
			DrawVPBarsInRange();
		
		Print("[INIT] SMC Trend EA initialized successfully with ", EnumToString(InpPresetMode), " preset");
		Print("[INIT] Performance optimization: ", InpOptimizeDrawing ? "ENABLED" : "DISABLED");
			
		 return(INIT_SUCCEEDED);
		}

	void OnDeinit(const int reason)
		{
		 // รายงานสถิติการใช้งาน
		 Print("[DEINIT] Performance Statistics:");
		 Print("  - Final object count: ", ObjectsTotal(0, 0, -1));
		 Print("  - Last signal time: ", TimeToString(s_lastSignalTime));
		 Print("  - Market volatile mode: ", s_marketVolatileMode ? "YES" : "NO");
		 Print("  - Preset mode used: ", EnumToString(InpPresetMode));
		 
		 // ลบ VWAP lines เมื่อ EA หยุดทำงาน
		 ClearObjectsByPrefix("VWAP_LINE_");
		 
		 // ลบ POC line เมื่อ EA หยุดทำงาน
		 ObjectDelete(0, "POC_LINE");

		 // ลบเส้นกำหนดช่วง VP หากถูกสร้างไว้ (ไม่บังคับ)
		 if(InpVPUseRange)
		 {
			ObjectDelete(0, "VP begin");
			ObjectDelete(0, "VP finish");
		 }
		 // ลบแท่ง VP ที่วาดด้วย prefix
		 ClearObjectsByPrefix("VP_BAR_");
		 
		 Print("[DEINIT] SMC Trend EA cleanup completed");
		 
		 // สามารถลบอ็อบเจกต์เก่าๆ หากต้องการ
		}

	void OnTick()
		{
			// Performance optimization - ลดการประมวลผลที่ไม่จำเป็น
			if(!ShouldProcess()) 
			{
				// ยังคงตรวจสอบ Pullback ทุก tick เพื่อไม่พลาดโอกาสเข้าเทรด
				CheckAndExecutePullback();
				return;
			}
			
			ENUM_TIMEFRAMES tf = InpTimeframe;
			bool isNewBar = false;

			// ตรวจแท่งใหม่ (หากกำหนด OnlyOnNewBar)
			datetime currBarTime = iTime(_Symbol, tf, 0);
			if (currBarTime != s_lastBarTime)
			{
				isNewBar = true;
				s_lastBarTime = currBarTime;
				
				// ตรวจสอบความผันผวนของตลาดเมื่อมีแท่งใหม่
				CheckMarketVolatility();
				
				// จัดการจำนวนวัตถุบนกราฟ
				ManageObjectCount();
			}

			// 1. Logic การวิเคราะห์และตั้งค่าสถานะ (รันเมื่อมีแท่งใหม่ หรือรันตลอดเวลาถ้าไม่ได้กำหนด InpOnlyOnNewBar)
			if (isNewBar || !InpOnlyOnNewBar)
			{
				AnalyzeTrendSignalAndDraw(_Symbol, tf, InpPrevIndex, InpCurrIndex, InpAutoDraw, InpExtendBarsRight);
				
				// วาด VWAP บนกราฟ (ทุก InpVWAPUpdateBars แท่งเพื่อประหยัดทรัพยากร)
				if(isNewBar)
				{
					s_vwapUpdateCounter++;
					if(s_vwapUpdateCounter >= InpVWAPUpdateBars)
					{
						if(InpDrawVWAP && (!InpOptimizeDrawing || !InpSmartRedraw || s_objectCount < InpMaxObjects))
							DrawVWAPLine();
						s_vwapUpdateCounter = 0;
					}
					
					// วาด POC line (ทุกแท่งใหม่เพื่อติดตาม Volume Profile)
					if(InpUseVPFilter && InpDrawPOC && (!InpOptimizeDrawing || !InpSmartRedraw))
					{
						DrawPOCLine();
					}

					// อัปเดต VP bars เมื่อแท่งใหม่ (สำหรับช่วง range ที่เลือก)
					if(InpVPUseRange && InpDrawVPBars && (!InpOptimizeDrawing || !InpSmartRedraw))
					{
						DrawVPBarsInRange();
					}
				}
			}

			// 2. Logic การตรวจสอบราคาและส่งคำสั่งเทรด (รันในทุก TICK เพื่อจับราคาเข้า)
			CheckAndExecutePullback();
		}

// รับเหตุการณ์ลากเส้นช่วงเพื่อคำนวณ VP ใหม่
void OnChartEvent(const int id,
						const long &lparam,
						const double &dparam,
						const string &sparam)
{
	if(!InpVPUseRange) return;
	if(id==CHARTEVENT_OBJECT_DRAG || id==CHARTEVENT_OBJECT_CHANGE)
	{
		if(sparam=="VP begin" || sparam=="VP finish")
		{
			if(InpUseVPFilter && InpDrawPOC)
				DrawPOCLine();
			if(InpDrawVPBars)
				DrawVPBarsInRange();
		}
	}
		else if(id==CHARTEVENT_CHART_CHANGE)
		{
			// เมื่อซูม/เลื่อนกราฟ ให้จัดวางแท่ง VP ใหม่ตามพิกัดจอภาพ
			if(InpVPUseRange && InpDrawVPBars)
				DrawVPBarsInRange();
		}
}