
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#include<Trade\Trade.mqh>
#include<InvestFriends-activtrades.mqh>
#include <WalkForwardOptimizer.mqh>
//#include <k_ratio.mqh>

typedef double (*FUNCPTR_WFO_CUSTOM)(const datetime startDate, const datetime splitDate, const double &map[/*WFO_STATS_MAP*/]);

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 9000;
enum ENUM_INPUT_YES_NO
  {
   INPUT_YES   =  1, // Yes
   INPUT_NO    =  0  // No
  };
input ENUM_INPUT_YES_NO TradeOnAlternativeSymbol = INPUT_NO;
input string inTradeOnSymbol = "---";

input  group             "Configuration"
input ENUM_TIMEFRAMES chartTimeframe = PERIOD_M10;
input TRADE_DIRECTION TradeDirection = LONG_TRADE;

input  group             "ATR"
input int ATRPeriod = 14;

input  group             "MA Low"
input int EMALowPeriod = 7;

input  group             "MA High"
input int EMAHighPeriod = 7;

input  group             "D. DAY TRADE"
sinput bool              inDayTrade = true;               // D.01 Operacao apenas como day trade
input int                inStartHour = 9;                 // D.02 Hora inicio negociacao
input int                inStartWaitMin = 0;              // D.03 Minutos a aguardar antes de iniciar operacoes
input int                inStopHour = 17;                 // D.04 Hora final negociacao
input int                inStopBeforeEndMin = 44;         // D.05 Minutos antes do fim para encerrar posicoes

input  group             "Geldman!!"
input Geldmann_Type Geldmann_type = LOTS;
input double geldMann = 1;

input  group             "Trailing"
input AdjustBy AdjustByType = POINTS;
input double TrailingStart = 0.0; // Trailing starts in percentage
input double TrailingPriceAdjustBy = 2; // How much to adjust price

input  group             "Takeprofit and Stoploss"
input double takeProfit = 5;
input double stopLoss = 5;

input  group             "Extras"
input double maxDailyLoss = 0;
input double maxDailyProfit = 0;
input int timeToSleep = 0;

int last_signal =  NOTRADE;

int EMAHighHandle = -1;
double EMAHighBuffer[];
int EMALowHandle = -1;
double EMALowBuffer[];

double LowPrice = EMPTY_VALUE;
double HighPrice = EMPTY_VALUE;

double StartMinute = EMPTY_VALUE;

bool LongDone = false;
bool ShortDone = false;

int OnInit(void)
  {
   if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
      Print("Invalid trailing parameter ",TrailingStart, " ",TrailingStart);
      return(INIT_FAILED);
   }
   
   TradeOnSymbol = _Symbol;
   if (TradeOnAlternativeSymbol == INPUT_YES) {
      TradeOnSymbol = inTradeOnSymbol;
   }

   startTime = (inStartHour * 60) + inStartWaitMin;
   stopTime = (inStopHour * 60) + inStopBeforeEndMin;

   cleanUPIndicators();
   
   EMAHighHandle = iMA(_Symbol,chartTimeframe,EMAHighPeriod,0,MODE_SMA , PRICE_HIGH);
   if (EMAHighHandle < 0) {
      Print("Erro criando indicador EMAHighHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAHighHandle);
   ArraySetAsSeries(EMAHighBuffer, true);
   
   EMALowHandle = iMA(_Symbol,chartTimeframe,EMALowPeriod,0,MODE_SMA , PRICE_LOW);
   if (EMALowHandle < 0) {
      Print("Erro criando indicador EMALowHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMALowHandle);
   ArraySetAsSeries(EMALowBuffer, true);
   
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);

   trade.SetExpertMagicNumber(MyMagicNumber);
   
   onGoingTrade = checkPostionTypeOpen();
   totalPosisions = returnAllPositions();
   printf("onGoingTrade %d totalPosisions %d closedprofit %.2f", onGoingTrade, totalPosisions, closedProfitPeriod());
   Comment("Magic number: ", MyMagicNumber, " Profit ", closedProfitPeriod());

   wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
   wfo_setPFmax(100); // DBL_MAX by default
   // wfo_setCloseTradesOnSeparationLine(true); // false by default
  
   // this is the only required call in OnInit, all parameters come from the header
   int WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);

   //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
   //wfo_setCustomPerformanceMeter(customEstimator);
   
   return(WFORockAndRoll);
  }
  
/* double OnTester()
{
   return optpr();         // optimization parameter
}
*/

void OnTesterInit()
{
  wfo_OnTesterInit(wfo_outputFile); // required
}

void OnTesterDeinit()
{
  wfo_OnTesterDeinit(); // required
}

void OnTesterPass()
{
  wfo_OnTesterPass(); // required
}

double OnTester()
{
   if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
      return 0.0;
   }
   return wfo_OnTester(); // required
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   cleanUPIndicators();
}

void OnTick()
{

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

   /* if day changes, reset filters to not trade is one was opened yesterday */
   checkDayHasChanged();
     
   /* Tick time for EA */
   MqlDateTime now;
   TimeToStruct(TimeCurrent(),now);
   timeNow = TimeCurrent();
   
   ArraySetAsSeries(priceData, true);   
   CopyRates(_Symbol, chartTimeframe, 0, 3, priceData);
 
   MqlDateTime TimeCandle ;
   TimeToStruct(priceData[0].time,TimeCandle);
   
   if (StartMinute == EMPTY_VALUE) {
      switch(Period()) 
      { 
         case PERIOD_M1: 
            StartMinute = 1; 
            break; 
         case PERIOD_M2: 
            StartMinute = 2; 
            break;
         case PERIOD_M3: 
            StartMinute = 3; 
            break;
         case PERIOD_M4: 
            StartMinute = 4; 
            break;
         case PERIOD_M5: 
            StartMinute = 4; 
            break;
         case PERIOD_M6: 
            StartMinute = 6; 
            break;
         case PERIOD_M10: 
            StartMinute = 10; 
            break;
         case PERIOD_M15: 
            StartMinute = 15;
            break;
         case PERIOD_M20: 
            StartMinute = 20;
            break;
         case PERIOD_M30: 
            StartMinute = 30;
            break;
         default: 
            StartMinute = 5;
            break; 
      }
   }

   int Bar = 0;
   if (LowPrice == EMPTY_VALUE || HighPrice == EMPTY_VALUE) {
      string TimeToConvert = IntegerToString(inStartHour);
      TimeToConvert = TimeToConvert + ":00";
      Bar = iBarShift(Symbol(), Period(), StringToTime(TimeToConvert));
   }

   if (TimeCandle.hour == inStartHour && TimeCandle.min == StartMinute) {  // Get High low first candle
      LowPrice = priceData[1].low;
      HighPrice = priceData[1].high;
      drawLine("Low", LowPrice);
      drawLine("High", HighPrice);
   }
   else if (TimeCandle.hour <= inStartHour && TimeCandle.min < StartMinute) {  // Get High low first candle
      LowPrice = EMPTY_VALUE;
      HighPrice = EMPTY_VALUE;
   }
   else if (Bar > 0 && (LowPrice == EMPTY_VALUE || HighPrice == EMPTY_VALUE)) {
      LowPrice = iLow(_Symbol, Period(), Bar);
      HighPrice = iHigh(_Symbol, Period(), Bar);
      drawLine("Low", LowPrice);
      drawLine("High", HighPrice);
   }
   
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
   
   if (CopyBuffer(EMAHighHandle, 0, 0, 3, EMAHighBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAHighHandle1 - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(EMALowHandle, 0, 0, 3, EMALowBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMALowHandle2 - error:", GetLastError());
      ResetLastError();
      return;
   }

   int signal = NOTRADE;
   int signal_exit = NOTRADE;

   if (LongDone == false && (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE)) {
      if (priceData[0].close > HighPrice &&
          priceData[1].close <= HighPrice) {
            signal = LONG;
            LongDone = true;
       }
      /* LONG exit */
      /* if (onGoingTrade == LONG && (priceData[0].close > EMAHighBuffer[1])) {
         signal_exit = SHORT;
         tradeArmed = false;
      }*/
   }
   
   if (ShortDone == false && (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE)) {
      if (priceData[0].close < LowPrice &&
          priceData[1].close >= LowPrice) {
            signal = SHORT;
            ShortDone = true;
       }
   }
   
   tradeArmed = false;
   if (totalTrades >= 2) {
      signal = NOTRADE;
   }
   
   onGoingTrade = checkPostionTypeOpen();
   if (onGoingTrade == NOTRADE  && (signal == NOTRADE || (last_signal == LONG && signal == SHORT) || (last_signal == SHORT && signal == LONG)) ) {
      tradeArmed = false;
   }
   
   if (LowPrice == EMPTY_VALUE || HighPrice == EMPTY_VALUE) {  // No Trade
      signal = NOTRADE;
      signal_exit = NOTRADE;
   }

   /* Time not to trade */
   hourMinuteNow = (now.hour * 60) + now.min;
   if ( hourMinuteNow < startTime || hourMinuteNow > stopTime) {
      LowPrice = EMPTY_VALUE;
      HighPrice = EMPTY_VALUE;
      StartMinute = EMPTY_VALUE;
      signal =  NOTRADE;
      totalTrades = 0;
      LongDone = false;
      ShortDone = false;
      Profit = 0;
      if (returnAllPositions() > 0 && inDayTrade == true) { // trade open and daytrade mode, stop all when end of the day
         printf("%s End of the day close all trades - Total trades %d", _Symbol, totalTrades);
         closeAllPositions();
         totalTrades = 0;
         onGoingTrade = NOTRADE;
      }
   }
   /*else {
      tradeOnCandle = false;
   }*/

   /* error from backtest */
   if (priceData[1].close == 0) {
      signal =  NOTRADE;
   }

   totalPosisions = returnAllPositions();
   Profit = closedProfitPeriod();

   if (maxDailyLoss > 0 && Profit < 0) {
      double auxProfit = Profit * -1;
      if (auxProfit > maxDailyLoss) {
         closeAllPositions();
         signal =  NOTRADE;
      }
   }
   if (maxDailyProfit > 0 && Profit >= maxDailyProfit) {
      closeAllPositions();
      signal =  NOTRADE;
   }

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " tradeArmed ",tradeArmed, " Low/High first Candle ", LowPrice, " - ",HighPrice, " - StartMinute ", StartMinute);

   TradeMann(signal, signal_exit);
}
