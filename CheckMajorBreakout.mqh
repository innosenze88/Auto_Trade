```mql
#pragma once

// Breakout type enumeration
enum BreakoutType
{
   BO_None = 0,
   BO_Bullish,
   BO_Bearish,
   BO_ChoCH_Bull,
   BO_ChoCH_Bear
};

// Result structure returned by CheckMajorBreakout
struct BreakoutResult
{
   BreakoutType type;     // ประเภทของ breakout
   double level;          // ระดับราคา BOS/CHoCH ที่เกี่ยวข้อง
   int level_bar_index;   // ดัชนีแท่งที่เป็นระดับ (เช่น hi1 / lo1)
   bool valid;            // ถ้าการคำนวณสำเร็จ
};

// ฟังก์ชันช่วยวาดเส้นระดับแนวนอน (OBJ_HLINE)
void DrawMajorLevelLine(const string name, const double price, const color clr, const ENUM_WIDTH width=WIDTH_THIN)
{
   // ลบ object เดิมถ้ามี
   if(ObjectFind(0, name) != -1)
   {
      ObjectDelete(0, name);
   }

   // สร้างเส้นแนวนอนใหม่
   if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
   {
      // failed create
      return;
   }

   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
}

// CheckMajorBreakout
// - rates: array of MqlRates (pass Rates array)
// - rates_total: จำนวนแท่งใน arrays
// - hi1_bar_index: ดัชนีแท่งที่เป็น Swing High ล่าสุด (ตาม FindTwoRecentSwings)
// - lo1_bar_index: ดัชนีแท่งที่เป็น Swing Low ล่าสุด (ตาม FindTwoRecentSwings)
// - draw_level: ถ้า true ให้วาดเส้นระดับบนกราฟ
// ผลลัพธ์: BreakoutResult บอกประเภทของ break และระดับที่เกี่ยวข้อง
BreakoutResult CheckMajorBreakout(const MqlRates &rates[], const int rates_total, const int hi1_bar_index, const int lo1_bar_index, const bool draw_level = true)
{
   BreakoutResult res;
   res.type = BO_None;
   res.level = 0.0;
   res.level_bar_index = -1;
   res.valid = false;

   // Validation inputs
   if(rates_total <= 2 || hi1_bar_index < 0 || lo1_bar_index < 0 || hi1_bar_index >= rates_total || lo1_bar_index >= rates_total)
      return res;

   // Use the most recently closed candle's close as confirmation
   double last_close = rates[1].close;

   // Get swing prices
   double swingHigh = rates[hi1_bar_index].high;
   double swingLow  = rates[lo1_bar_index].low;

   // Check bullish breakout (close above recent swing high)
   if(last_close > swingHigh)
   {
      res.type = BO_Bullish;
      res.level = swingHigh;
      res.level_bar_index = hi1_bar_index;
      res.valid = true;

      if(draw_level)
      {
         string name = "SMC_BOS_Bull_" + IntegerToString(TimeCurrent());
         DrawMajorLevelLine(name, res.level, clrGreen, WIDTH_MEDIUM);
      }

      return res;
   }

   // Check bearish breakout (close below recent swing low)
   if(last_close < swingLow)
   {
      res.type = BO_Bearish;
      res.level = swingLow;
      res.level_bar_index = lo1_bar_index;
      res.valid = true;

      if(draw_level)
      {
         string name = "SMC_BOS_Bear_" + IntegerToString(TimeCurrent());
         DrawMajorLevelLine(name, res.level, clrRed, WIDTH_MEDIUM);
      }

      return res;
   }

   // ถ้ายังไม่มี breakout ให้ return No break
   res.type = BO_None;
   res.valid = true;
   return res;
}
```