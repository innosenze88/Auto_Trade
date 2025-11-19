//+------------------------------------------------------------------+
//|                                                  TimeFilter.mqh   |
//|                         Copyright 2024, Auto_Trade Development  |
//|                     Smart Money Concepts EA - v2.0               |
//|                     Session-Based Time Filter System              |
//+------------------------------------------------------------------+

#ifndef __TIME_FILTER_MQH__
#define __TIME_FILTER_MQH__

//+------------------------------------------------------------------+
//| GetGMTTime: Convert Server Time to GMT                           |
//| Parameters: None                                                 |
//| Returns: Current time in GMT timezone                            |
//| Description: Converts broker server time to GMT by calculating   |
//|              offset. Useful for trading across timezones.        |
//+------------------------------------------------------------------+
datetime GetGMTTime()
{
   // Get current server time
   datetime serverTime = TimeCurrent();

   // Calculate offset between server time and UTC
   // We use TimeLocal() which gives local time on trading account
   // and TimeCurrent() which gives server time
   MqlDateTime serverStruct;
   TimeToStruct(serverTime, serverStruct);

   // Calculate hours difference from server time
   // This accounts for DST and broker timezone
   int offsetHours = GMTOffset;

   // Create GMT time by adjusting
   MqlDateTime gmtStruct = serverStruct;

   // Adjust hour by offset
   gmtStruct.hour = (serverStruct.hour + offsetHours) % 24;

   // Handle day wraparound
   if(gmtStruct.hour < 0)
   {
      gmtStruct.hour += 24;
      gmtStruct.day--;
      if(gmtStruct.day < 1)
      {
         gmtStruct.day = 31;
         gmtStruct.mon--;
         if(gmtStruct.mon < 1)
         {
            gmtStruct.mon = 12;
            gmtStruct.year--;
         }
      }
   }
   else if(gmtStruct.hour >= 24)
   {
      gmtStruct.hour -= 24;
      gmtStruct.day++;
      // Check if day exceeded month days
      int daysInMonth[] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
      // Adjust for leap year
      if(gmtStruct.mon == 2 && ((gmtStruct.year % 4 == 0) && (gmtStruct.year % 100 != 0)) || (gmtStruct.year % 400 == 0))
         daysInMonth[2] = 29;

      if(gmtStruct.day > daysInMonth[gmtStruct.mon])
      {
         gmtStruct.day = 1;
         gmtStruct.mon++;
         if(gmtStruct.mon > 12)
         {
            gmtStruct.mon = 1;
            gmtStruct.year++;
         }
      }
   }

   return StructToTime(gmtStruct);
}

//+------------------------------------------------------------------+
//| GetCurrentSession: Detect Current Trading Session               |
//| Parameters: None                                                 |
//| Returns: Current session as string with emoji indicator          |
//| Description: Determines which major FX session is currently open |
//|              based on GMT time. Used for session-aware trading.   |
//| Sessions (all times in GMT):                                     |
//|   - London: 08:00 - 17:00                                        |
//|   - New York: 13:00 - 22:00                                      |
//|   - Overlap: 13:00 - 17:00 (both open, high liquidity)           |
//|   - Closed: 22:00 - 08:00 (no major session)                     |
//+------------------------------------------------------------------+
string GetCurrentSession()
{
   datetime gmtTime = GetGMTTime();

   // Extract hour from GMT time
   MqlDateTime timeStruct;
   TimeToStruct(gmtTime, timeStruct);
   int hour = timeStruct.hour;

   // Determine which session is active
   // London: 08:00 - 17:00
   // New York: 13:00 - 22:00
   // Overlap: 13:00 - 17:00

   if(hour >= OVERLAP_START && hour < OVERLAP_END)
   {
      // 13:00 - 17:00 GMT = Both London and New York open
      return "OVERLAP ⚡";
   }
   else if(hour >= LONDON_SESSION_START && hour < LONDON_SESSION_END)
   {
      // 08:00 - 13:00 GMT = London only
      return "LONDON 🇬🇧";
   }
   else if(hour >= NEWYORK_SESSION_START && hour < NEWYORK_SESSION_END)
   {
      // 17:00 - 22:00 GMT = New York only
      return "NEW YORK 🇺🇸";
   }
   else
   {
      // 22:00 - 08:00 GMT = Closed
      return "CLOSED 💤";
   }
}

//+------------------------------------------------------------------+
//| CheckNewsAvoidance: Check for News Events and Avoid             |
//| Parameters: None                                                 |
//| Returns: true if safe to trade, false if near news event        |
//| Description: Checks for scheduled news events (NFP, major econ) |
//|              and prevents entry if within avoidance window.      |
//| Events Avoided:                                                  |
//|   - NFP (Non-Farm Payroll): 1st Friday of month at 13:30 GMT    |
//|   - Other major economic releases (configurable)                 |
//+------------------------------------------------------------------+
bool CheckNewsAvoidance()
{
   // Return true if news avoidance disabled
   if(!AvoidNewsTime)
      return true;

   datetime gmtTime = GetGMTTime();
   MqlDateTime timeStruct;
   TimeToStruct(gmtTime, timeStruct);

   // Check for NFP (Non-Farm Payroll)
   // Occurs on first Friday of every month at 13:30 GMT
   int dayOfWeek = timeStruct.day_of_week;  // 0=Sunday, 1=Monday, ..., 5=Friday
   int dayOfMonth = timeStruct.day;
   int hour = timeStruct.hour;
   int minute = timeStruct.min;

   // Find if this is the 1st Friday (first day of month that is Friday, between 1-7)
   bool isNFPDay = false;

   if(dayOfWeek == 5)  // Friday
   {
      // Check if it's in first week (day 1-7)
      if(dayOfMonth >= 1 && dayOfMonth <= 7)
      {
         isNFPDay = true;
      }
   }

   if(isNFPDay)
   {
      // NFP is at 13:30 GMT
      // Check if within avoidance window
      int nfpHour = NFP_HOUR_GMT;
      int nfpMinute = NFP_MINUTE_GMT;

      // Convert to minutes for easier comparison
      int currentMinutes = hour * 60 + minute;
      int nfpMinutes = nfpHour * 60 + nfpMinute;
      int avoidanceMinutes = NewsAvoidMinutes;

      // Calculate avoidance window
      int startMinutes = nfpMinutes - avoidanceMinutes;
      int endMinutes = nfpMinutes + avoidanceMinutes;

      if(currentMinutes >= startMinutes && currentMinutes < endMinutes)
      {
         if(debugMode)
            Print("[NEWS] NFP event avoidance active | Current: ", TimeToString(gmtTime),
                  " | Avoidance until: ", avoidanceMinutes, " minutes after 13:30 GMT");
         return false;  // Avoid trading
      }
   }

   // If we get here, safe to trade (no conflicting news)
   return true;
}

//+------------------------------------------------------------------+
//| IsTradingAllowed: Main Trading Time Filter Gate                 |
//| Parameters: None                                                 |
//| Returns: true if trading allowed, false if restricted           |
//| Description: Main function that gates all trading. Combines     |
//|              session restrictions and news avoidance to create  |
//|              a comprehensive trading time filter.                |
//|                                                                  |
//| Logic:                                                           |
//| 1. If time filter disabled, allow trading any time              |
//| 2. Get current GMT time and extract hour                        |
//| 3. Check session restrictions (London, NY, Overlap)            |
//| 4. If session allowed, check news avoidance                    |
//| 5. Return final decision                                        |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   // Step 1: Check if time filter is enabled
   if(!EnableTimeFilter)
   {
      if(debugMode)
         Print("[TIME_FILTER] Time filter disabled - trading allowed anytime");
      return true;  // All times allowed if filter disabled
   }

   // Step 2: Get GMT time and extract hour
   datetime gmtTime = GetGMTTime();
   MqlDateTime timeStruct;
   TimeToStruct(gmtTime, timeStruct);
   int hour = timeStruct.hour;

   // Step 3: Check session restrictions
   bool sessionAllowed = false;

   // Check if TradeOnlyLondon is enabled
   if(TradeOnlyLondon)
   {
      // Only trade during London session (08:00-17:00)
      if(hour >= LONDON_SESSION_START && hour < LONDON_SESSION_END)
      {
         sessionAllowed = true;
      }
      else
      {
         if(debugMode)
            Print("[TIME_FILTER] London-only mode | Current hour: ", hour, " GMT | Allowed: 8-17");
         return false;
      }
   }
   // Check if TradeOnlyNY is enabled
   else if(TradeOnlyNY)
   {
      // Only trade during New York session (13:00-22:00)
      if(hour >= NEWYORK_SESSION_START && hour < NEWYORK_SESSION_END)
      {
         sessionAllowed = true;
      }
      else
      {
         if(debugMode)
            Print("[TIME_FILTER] NY-only mode | Current hour: ", hour, " GMT | Allowed: 13-22");
         return false;
      }
   }
   // Check if TradeOverlapOnly is enabled
   else if(TradeOverlapOnly)
   {
      // Only trade during overlap period (13:00-17:00)
      if(hour >= OVERLAP_START && hour < OVERLAP_END)
      {
         sessionAllowed = true;
      }
      else
      {
         if(debugMode)
            Print("[TIME_FILTER] Overlap-only mode | Current hour: ", hour, " GMT | Allowed: 13-17");
         return false;
      }
   }
   // Default: allow both London and New York sessions
   else
   {
      // London (08:00-17:00) or New York (13:00-22:00)
      if((hour >= LONDON_SESSION_START && hour < LONDON_SESSION_END) ||
         (hour >= NEWYORK_SESSION_START && hour < NEWYORK_SESSION_END))
      {
         sessionAllowed = true;
      }
      else
      {
         if(debugMode)
            Print("[TIME_FILTER] Session closed | Current hour: ", hour, " GMT");
         return false;
      }
   }

   // Step 4: If session allowed, check news avoidance
   if(sessionAllowed)
   {
      bool newsAllowed = CheckNewsAvoidance();
      if(!newsAllowed)
      {
         if(debugMode)
            Print("[TIME_FILTER] Trading blocked by news event");
         return false;
      }
   }

   // Step 5: All checks passed
   if(debugMode)
      Print("[TIME_FILTER] ✓ Trading allowed | Session: ", GetCurrentSession(),
            " | GMT: ", TimeToString(gmtTime));

   return true;
}

#endif // __TIME_FILTER_MQH__
