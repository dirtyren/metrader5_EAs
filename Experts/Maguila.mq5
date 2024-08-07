
//+------------------------------------------------------------------+
//| Functions by Invest Friends                                             |
//+------------------------------------------------------------------+
//#define WDO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 32000;
enum ENUM_INPUT_YES_NO
  {
   INPUT_YES   =  1, // Yes
   INPUT_NO    =  0  // No
  };
input ENUM_INPUT_YES_NO TradeOnAlternativeSymbol = INPUT_NO;
input string inTradeOnSymbol = "---";

input  group             "Configuration"
input ENUM_TIMEFRAMES chartTimeframe = PERIOD_CURRENT; // Timeframe of the EA
input TRADE_DIRECTION TradeDirection = LONG_SHORT_TRADE;     // Trade direction. Long, Short, Both
   
input  group             "D. DAY TRADE"
sinput bool              inDayTrade = true;        // Day trade - will close the trade at the end of the day
input int                inStartHour = 9;          // Hour it can start trading
input int                inStartWaitMin = 0;       // Minutes it can start trading
input int                inStopHour = 17;           // Hour to stop trading
input int                inStopBeforeEndMin = 44;    // Minutes to stop trading

input  group             "Geldman!!"      // how much to trade
input Geldmann_Type Geldmann_type = LOTS;
input double geldMann = 1;

input  group             "Auto adjust stops in"
input AdjustBy AdjustByType = PERCENTAGE;

input  group             "Break even after"
input double BreakEven = 0.0; // Breakevent stop when hit AdjustByType

input  group             "Trailing"
input double TrailingStart = 0.0; // Trailing starts set in AdjustByType
input double TrailingPriceAdjustBy = 2; // How much to adjust price

input  group             "Takeprofit and Stoploss set in AdjustByType"
input double takeProfit = 0;
input double stopLoss = 0;

input  group             "Extras"
input double maxDailyLoss = 0;
input double maxDailyProfit = 0;
input int timeToSleep = 0;

/* ATR indicator must exists if you want the use set stops by ATR */
input  group             "ATR"
input int ATRPeriod = 14;

/* your indicator start here */
input  group             "RSI"
input int RSIPeriod = 2;
input int RSIMeanCandles = 10;
int RSIHandle = -1;
double RSI[];

int OnInit(void)
  {
  
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   /* ATR for stops ATR */
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);
   
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);
      
   /* Load EA Indicators */
   RSIHandle = iRSI(_Symbol,chartTimeframe,RSIPeriod, PRICE_CLOSE);
   if (RSIHandle < 0) {
      Print("Erro criando indicador RSIHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(RSIHandle, 1);
   ArraySetAsSeries(RSI, true);
   
   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      wfo_setCloseTradesOnSeparationLine(true); // false by default
     
      // this is the only required call in OnInit, all parameters come from the header
      int WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);
   
      //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
      //wfo_setCustomPerformanceMeter(customEstimator);
      return(WFORockAndRoll);
   #endif
   return(0);
}
  
void OnTesterInit()
{
   #ifdef WFO
      wfo_OnTesterInit(wfo_outputFile); // required
   #endif
}

void OnTesterDeinit()
{
   #ifdef WFO
      wfo_OnTesterDeinit(); // required
   #endif
}

void OnTesterPass()
{
   #ifdef WFO
      wfo_OnTesterPass(); // required
   #endif
}

double OnTester()
{
   if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
      return 0.0;
   }
   #ifdef WFO
      return wfo_OnTester(); // required
   #endif 
   return 0.0;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   DeInitEA();
}

void OnTick()
{

   #ifdef WFO
      int wfo = wfo_OnTick();
      if(wfo == -1)
      {
         // can do some non-trading stuff, such as gathering bar or ticks statistics
         return;
      }
      else if(wfo == +1)
      {
         // can do some non-trading stuff
         return;
      }
   #endif

   /* Tick time for EA */
   TimeToStruct(TimeCurrent(),now);
   timeNow = TimeCurrent();
   
   /* Get price bars */
   ArraySetAsSeries(priceData, true);   
   CopyRates(_Symbol, chartTimeframe, 0, RSIMeanCandles + 3, priceData);
 
   /* Time current candle */   
   timeStampCurrentCandle = priceData[0].time;
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(RSIHandle, 0, 0, RSIMeanCandles + 3, RSI) < 0)   {
      Print("Erro copiando buffer do indicador EMALowHandle2 - error:", GetLastError());
      ResetLastError();
      return;
   }

   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   onGoingTrade = checkPositionTypeOpen();
   
   /* Calculate RSI Mean */
   double RSIMean = 0;
   double RSILowest = 100;
   double RSIHighest = 0;
   for(int i = 2; i<=(RSIMeanCandles+1);i++) {
      RSIMean+=RSI[i];
      if (RSI[i] < RSILowest) {
         RSILowest = RSI[i];
      }
      if (RSI[i] > RSIHighest) {
         RSIHighest = RSI[i];
      }
   }
   RSIMean = RSIMean / RSIMeanCandles;
   
   /* Highest last PriceCandlesExit */
   double HighestPrice = 0;
   double LowestPrice = 999999999999999;
   for(int i = 2; i<=(RSIMeanCandles+1);i++) {
      if (priceData[i].high > HighestPrice) {
         HighestPrice = priceData[i].high;
      }
      if (priceData[i].low < LowestPrice) {
         LowestPrice = priceData[i].low;
      }
   }
   //drawLine("Highest", HighestPrice);
   //drawLine("LowestPrice", LowestPrice);

   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE &&  RSI[1] < LowestPrice) {
            signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG &&  (RSI[1] > RSIHighest)
         ) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE &&  RSI[1] > RSIHighest) {
            signal = SHORT;
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT &&  (RSI[1] < LowestPrice)
         ) {
         signal_exit = LONG;
      }
   }
   
   TradeMann(signal, signal_exit);

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " Profit ",Profit);

}
