
//+------------------------------------------------------------------+
//| Functions by Invest Friends                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 40600;
enum ENUM_INPUT_YES_NO
  {
   INPUT_YES   =  1, // Yes
   INPUT_NO    =  0  // No
  };
input ENUM_INPUT_YES_NO TradeOnAlternativeSymbol = INPUT_NO;
input string inTradeOnSymbol = "---";

input  group             "Configuration"
input ENUM_TIMEFRAMES chartTimeframe = PERIOD_CURRENT; // Timeframe of the EA
input TRADE_DIRECTION TradeDirection = LONG_TRADE;     // Trade direction. Long, Short, Both
   
input  group             "D. DAY TRADE"
sinput bool              inDayTrade = false;        // Day trade - will close the trade at the end of the day
input int                inStartHour = 10;          // Hour it can start trading
input int                inStartWaitMin = 0;       // Minutes it can start trading
input int                inStopHour = 16;           // Hour to stop trading
input int                inStopBeforeEndMin = 45;    // Minutes to stop trading

input  group             "Geldman!!"      // how much to trade
input Geldmann_Type Geldmann_type = GELD;
input double geldMann = 6000;

input  group             "Auto adjust stops in"
input AdjustBy AdjustByType = POINTS;

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

input group             "Bollinger Bandas %B"
input int    BBPeriod = 7;        // Period
input int    BBShift =  0;         // Shift
input double StdDeviation = 1.0;  // Standard Deviation
input ENUM_APPLIED_PRICE appliedprc=PRICE_CLOSE; //Applied Price
int BBHandle = -1;
double BBValue[];


int OnInit(void)
  {
  
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   startTime = (inStartHour * 60) + inStartWaitMin;
   stopTime = (inStopHour * 60) + inStopBeforeEndMin;
   
   /* Load EA Indicators */
   BBHandle = iCustom(_Symbol, chartTimeframe, "Bollinger_bands_1b", BBPeriod, BBShift, StdDeviation, PRICE_CLOSE);
   if (BBHandle < 0) {
      Print("Erro criando indicador BBHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(BBHandle, 2);
   ArraySetAsSeries(BBValue, true);
   
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);

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
   CopyRates(_Symbol, chartTimeframe, 0, 3, priceData);
 
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

   if (CopyBuffer(BBHandle, 0, 0, 4, BBValue) < 0)   {
      Print("Erro copiando buffer do indicador StochaticHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE &&
          BBValue[1] < -0.2 &&
          BBValue[2] < -0.2 &&
          BBValue[3] < -0.2) {
            signal = LONG;
      }
      if (onGoingTrade == LONG && BBValue[1] > 1) {
         signal_exit = SHORT;
      }
      Print("BB ", BBValue[1]);
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {

   }
   
   TradeMann(signal, signal_exit);

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
