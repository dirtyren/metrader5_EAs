//+-------------------------------------------------------------------------------+
//|                                                Ren_MQL_Library_Parameters.mqh |
//|                                                   Alessandro Ren              |
//|                                                                               |
//+-------------------------------------------------------------------------------+

#property copyright "Copyright © 2023 Alessandro Ren"

enum ENUM_INPUT_YES_NO
{
   INPUT_YES   =  1, // Yes
   INPUT_NO    =  0  // No
};

input group "Trade on Symbol that is not the one on the Graph"
input ENUM_INPUT_YES_NO TradeOnAlternativeSymbol = INPUT_NO;
input string inTradeOnSymbol = "";

input group "Rolling futures - close on this one and open on the graph"
input string CloseTradeOnSymbol = "";

input group "Automatic symbol rolling - automatically select contract"
input ENUM_INPUT_YES_NO UseAutomaticSymbolRolling = INPUT_NO;
input Symbol_Choice_Filter_Type RollingMethod = PRICE;

input  group             "Configuration"
input ENUM_TIMEFRAMES chartTimeframe = PERIOD_CURRENT;
input TRADE_DIRECTION TradeDirection = LONG_SHORT_TRADE;

input  group             "D. DAY TRADE"
sinput bool              inDayTrade = false;          // D.01 day trades - closes all trades at the end of the day
input int                inStartHour = 0;             // D.02 Trade allowed at this hour
input int                inStartWaitMin = 0;          // D.03 Trade allowed at this minutes
input int                inStopHour = 23;             // D.04 End of the day hour
input int                inStopBeforeEndMin = 44;     // D.05 End of the day minutes
input int                inMaxStartHour = 23;         // D.04 Limit hour to open trades
input int                inMaxBeforeEndMin = 44;      // D.05 Limite time to open trades

input  group             "Geldman!! - trade size"
input Geldmann_Type Geldmann_type = LOTS;
input double geldMann = 1;

input  group             "Trailing"
input AdjustBy AdjustByType = PERCENTAGE; // Percentage, Points in net value or ATR
input double TrailingStart = 0.0; // Trailing starts in
input double TrailingPriceAdjustBy = 2; // How much to adjust price - 0 breakeven

input  group             "Takeprofit, Stoploss & setStopAtProfit"
input double takeProfit = 0;
input double stopLoss = 0;

input  group             "Extras"
input double maxDailyLoss = 0;
input double maxDailyProfit = 0;
input int timeToSleep = 0;
input int MaxTradesDaily = 0;

/* If and how many times should I start a new trade */
input  group             "The Great Pyramid of Giza"
input int MaxPyramidTrades = 0;
input bool UseRiskToPyramid = true;

input  group             "ATR"
input int ATRPeriod = 14;