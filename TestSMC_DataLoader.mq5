//+------------------------------------------------------------------+
//|                                         TestSMC_DataLoader.mq5 |
//|                                  Copyright 2024, SMC Tester    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, SMC Tester"
#property version   "1.00"
#property script_show_inputs

//--- Input parameters
input string CSVFile = "TestData_SMC_Patterns.csv";     // CSV file name
input bool   LoadToHistory = true;                      // Load data to history
input bool   RunEATest = true;                          // Run EA test after loading

//--- Global variables
struct PriceData
{
    datetime time;
    double   open;
    double   high;
    double   low;
    double   close;
    long     volume;
};

PriceData g_priceData[];

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== SMC EA Test Data Loader Started ===");
    
    // Load CSV data
    if (!LoadCSVData())
    {
        Print("ERROR: Failed to load CSV data");
        return;
    }
    
    Print("Successfully loaded ", ArraySize(g_priceData), " price records");
    
    // Test SMC pattern detection
    if (RunEATest)
    {
        TestSMCPatterns();
    }
    
    Print("=== SMC EA Test Completed ===");
}

//+------------------------------------------------------------------+
//| Load CSV data into price array                                  |
//+------------------------------------------------------------------+
bool LoadCSVData()
{
    string filename = CSVFile;
    int file_handle = FileOpen(filename, FILE_READ|FILE_CSV|FILE_TXT);
    
    if (file_handle == INVALID_HANDLE)
    {
        Print("ERROR: Cannot open file ", filename);
        return false;
    }
    
    // Skip header line
    string header = FileReadString(file_handle);
    Print("CSV Header: ", header);
    
    // Read data lines
    int count = 0;
    while (!FileIsEnding(file_handle))
    {
        string line = FileReadString(file_handle);
        if (line == "") continue;
        
        if (ParseCSVLine(line, count))
        {
            count++;
        }
    }
    
    FileClose(file_handle);
    
    ArrayResize(g_priceData, count);
    Print("Loaded ", count, " price records from CSV");
    
    return count > 0;
}

//+------------------------------------------------------------------+
//| Parse single CSV line                                           |
//+------------------------------------------------------------------+
bool ParseCSVLine(string line, int index)
{
    string parts[];
    int numParts = StringSplit(line, ',', parts);
    
    if (numParts < 7)
    {
        Print("WARNING: Invalid CSV line format: ", line);
        return false;
    }
    
    // Resize array if needed
    if (index >= ArraySize(g_priceData))
    {
        ArrayResize(g_priceData, index + 100);
    }
    
    // Parse date and time
    string dateStr = parts[0];
    string timeStr = parts[1];
    datetime dt = StringToTime(dateStr + " " + timeStr);
    
    // Parse OHLCV
    g_priceData[index].time = dt;
    g_priceData[index].open = StringToDouble(parts[2]);
    g_priceData[index].high = StringToDouble(parts[3]);
    g_priceData[index].low = StringToDouble(parts[4]);
    g_priceData[index].close = StringToDouble(parts[5]);
    g_priceData[index].volume = (long)StringToInteger(parts[6]);
    
    return true;
}

//+------------------------------------------------------------------+
//| Test SMC patterns with loaded data                              |
//+------------------------------------------------------------------+
void TestSMCPatterns()
{
    Print("\n=== Testing SMC Patterns ===");
    
    int dataCount = ArraySize(g_priceData);
    if (dataCount < 50)
    {
        Print("ERROR: Not enough data for testing (need at least 50 bars)");
        return;
    }
    
    // Test different market phases
    TestBullishTrend(0, 30);           // First 30 bars (uptrend)
    TestBearishTrend(30, 60);          // Next 30 bars (downtrend)  
    TestBullishReversal(60, 90);       // Next 30 bars (reversal)
    TestBearishCorrection(90, dataCount); // Remaining bars (correction)
    
    Print("=== SMC Pattern Testing Completed ===\n");
}

//+------------------------------------------------------------------+
//| Test bullish trend phase                                        |
//+------------------------------------------------------------------+
void TestBullishTrend(int startIdx, int endIdx)
{
    Print("\n--- Testing Bullish Trend Phase ---");
    Print("Data range: ", startIdx, " to ", endIdx);
    
    double highestHigh = 0;
    double lowestLow = 999999;
    int swingCount = 0;
    
    for (int i = startIdx; i < endIdx && i < ArraySize(g_priceData); i++)
    {
        if (g_priceData[i].high > highestHigh)
        {
            highestHigh = g_priceData[i].high;
        }
        if (g_priceData[i].low < lowestLow)
        {
            lowestLow = g_priceData[i].low;
        }
        
        // Detect potential swing points
        if (IsSwingHigh(i, 2) || IsSwingLow(i, 2))
        {
            swingCount++;
        }
    }
    
    Print("Bullish Phase Results:");
    Print("- Range: ", lowestLow, " to ", highestHigh);
    Print("- Range Size: ", (highestHigh - lowestLow), " points");
    Print("- Swing Points: ", swingCount);
    Print("- Market Structure: ", (highestHigh > g_priceData[startIdx].high ? "BULLISH" : "UNKNOWN"));
}

//+------------------------------------------------------------------+
//| Test bearish trend phase                                        |
//+------------------------------------------------------------------+
void TestBearishTrend(int startIdx, int endIdx)
{
    Print("\n--- Testing Bearish Trend Phase ---");
    Print("Data range: ", startIdx, " to ", endIdx);
    
    double highestHigh = 0;
    double lowestLow = 999999;
    int swingCount = 0;
    
    for (int i = startIdx; i < endIdx && i < ArraySize(g_priceData); i++)
    {
        if (g_priceData[i].high > highestHigh)
        {
            highestHigh = g_priceData[i].high;
        }
        if (g_priceData[i].low < lowestLow)
        {
            lowestLow = g_priceData[i].low;
        }
        
        if (IsSwingHigh(i, 2) || IsSwingLow(i, 2))
        {
            swingCount++;
        }
    }
    
    Print("Bearish Phase Results:");
    Print("- Range: ", lowestLow, " to ", highestHigh);
    Print("- Range Size: ", (highestHigh - lowestLow), " points");
    Print("- Swing Points: ", swingCount);
    Print("- Market Structure: ", (lowestLow < g_priceData[startIdx].low ? "BEARISH" : "UNKNOWN"));
}

//+------------------------------------------------------------------+
//| Test bullish reversal phase                                     |
//+------------------------------------------------------------------+
void TestBullishReversal(int startIdx, int endIdx)
{
    Print("\n--- Testing Bullish Reversal Phase ---");
    Print("Data range: ", startIdx, " to ", endIdx);
    
    double startPrice = g_priceData[startIdx].close;
    double endPrice = g_priceData[MathMin(endIdx-1, ArraySize(g_priceData)-1)].close;
    double priceChange = endPrice - startPrice;
    
    Print("Reversal Phase Results:");
    Print("- Start Price: ", startPrice);
    Print("- End Price: ", endPrice);
    Print("- Price Change: ", priceChange, " points");
    Print("- Change %: ", (priceChange/startPrice)*100, "%");
    Print("- Pattern: ", (priceChange > 0 ? "BULLISH REVERSAL" : "CONTINUED BEARISH"));
}

//+------------------------------------------------------------------+
//| Test bearish correction phase                                   |
//+------------------------------------------------------------------+
void TestBearishCorrection(int startIdx, int endIdx)
{
    Print("\n--- Testing Bearish Correction Phase ---");
    Print("Data range: ", startIdx, " to ", endIdx);
    
    double startPrice = g_priceData[startIdx].close;
    double endPrice = g_priceData[MathMin(endIdx-1, ArraySize(g_priceData)-1)].close;
    double priceChange = endPrice - startPrice;
    
    Print("Correction Phase Results:");
    Print("- Start Price: ", startPrice);
    Print("- End Price: ", endPrice);
    Print("- Price Change: ", priceChange, " points");
    Print("- Change %: ", (priceChange/startPrice)*100, "%");
    Print("- Pattern: ", (priceChange < 0 ? "BEARISH CORRECTION" : "BULLISH CONTINUATION"));
}

//+------------------------------------------------------------------+
//| Check if bar is swing high                                      |
//+------------------------------------------------------------------+
bool IsSwingHigh(int index, int lookback)
{
    if (index < lookback || index >= ArraySize(g_priceData) - lookback)
        return false;
    
    double currentHigh = g_priceData[index].high;
    
    // Check left side
    for (int i = index - lookback; i < index; i++)
    {
        if (g_priceData[i].high >= currentHigh)
            return false;
    }
    
    // Check right side
    for (int i = index + 1; i <= index + lookback; i++)
    {
        if (g_priceData[i].high >= currentHigh)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if bar is swing low                                       |
//+------------------------------------------------------------------+
bool IsSwingLow(int index, int lookback)
{
    if (index < lookback || index >= ArraySize(g_priceData) - lookback)
        return false;
    
    double currentLow = g_priceData[index].low;
    
    // Check left side
    for (int i = index - lookback; i < index; i++)
    {
        if (g_priceData[i].low <= currentLow)
            return false;
    }
    
    // Check right side
    for (int i = index + 1; i <= index + lookback; i++)
    {
        if (g_priceData[i].low <= currentLow)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+