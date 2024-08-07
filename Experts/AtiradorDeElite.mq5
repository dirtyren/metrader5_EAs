
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "RSI"
int input  RSIPeriod = 2; // averaging period 
input ENUM_APPLIED_PRICE  RSIPrice = PRICE_CLOSE;      // type of price or handle 
int input LevelUP = 90;
int input LevelDown = 30;
int RSIHandle = -1;
int RSIHandleReal = -1;
double RSI[];

double LowPrice = EMPTY_VALUE;
double HighPrice = EMPTY_VALUE;

double StartMinute = EMPTY_VALUE;
double StartMinuteDectection = EMPTY_VALUE;

int OnInit(void) {

   EAVersion = "v1.1";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   RSIHandle = iRSI(_Symbol,chartTimeframe, RSIPeriod, RSIPrice);
   if (RSIHandle < 0) {
      Print("Erro RSIHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(RSIHandle, 1);

   /* Initialize reasl symbol if needed - load the indicators on it */
   CheckAutoRollingSymbol();
   LoadIndicators();

   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      wfo_setCloseTradesOnSeparationLine(false); // false by default
     
      // this is the only required call in OnInit, all parameters come from the header
      int WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);
   
      //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
      //wfo_setCustomPerformanceMeter(customEstimator);
      return(WFORockAndRoll);
   #endif
   return(0);
  }
  
int LoadIndicators()
{
   /* if in test mode, no need to unload and load the indicador */
   if (MQLInfoInteger(MQL_TESTER) && RSIHandleReal != INVALID_HANDLE) {
      return 0;
   }

   if (RSIHandleReal != INVALID_HANDLE) {
      IndicatorRelease(RSIHandleReal);
      RSIHandleReal = INVALID_HANDLE;
   }
 
   RSIHandleReal = iRSI(TradeOnSymbol,chartTimeframe, RSIPeriod, RSIPrice);
   if (RSIHandleReal < 0) {
      Print("Erro RSIHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(RSI, true);

   Print("Indicator(s) loaded on the symbol ", TradeOnSymbol);

   return 0;
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
   #ifdef WFO
      if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
         return 0.0;
      }
      return wfo_OnTester(); // required
   #endif
   return 0.0;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   cleanUPIndicators();
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

   /* if day changes, reset filters to not trade is one was opened yesterday */
   checkDayHasChanged();
     
   /* Tick time for EA */
   TimeToStruct(TimeCurrent(),now);
   timeNow = TimeCurrent();
   
   ArraySetAsSeries(priceData, true);   
   CopyRates(TradeOnSymbol, chartTimeframe, 0, 3, priceData);
   
   MqlDateTime TimeCandle ;
   TimeToStruct(priceData[0].time,TimeCandle);
   
   if (StartMinute == EMPTY_VALUE) {
      switch(Period()) 
      { 
         case PERIOD_M1: 
            StartMinute = 1;
            StartMinuteDectection = StartMinute;
            break; 
         case PERIOD_M2: 
            StartMinute = 2;
            StartMinuteDectection = StartMinute;
            break;
         case PERIOD_M3: 
            StartMinute = 3;
            StartMinuteDectection = StartMinute;
            break;
         case PERIOD_M4: 
            StartMinute = 4;
            StartMinuteDectection = StartMinute;
            break;
         case PERIOD_M5: 
            StartMinute = 5;
            StartMinuteDectection = StartMinute;
            break;
         case PERIOD_M6: 
            StartMinute = 6;
            StartMinuteDectection = StartMinute;
            break;
         case PERIOD_M10: 
            StartMinute = 10;
            StartMinuteDectection = StartMinute;
            break;
         case PERIOD_M15: 
            StartMinute = 15;
            StartMinuteDectection = StartMinute;
            break;
         case PERIOD_M20: 
            StartMinute = 20;
            StartMinuteDectection = StartMinute;
            break;
         case PERIOD_M30: 
            StartMinute = 30;
            StartMinuteDectection = StartMinute;
            break;
         default: 
            StartMinute = 5;
            StartMinuteDectection = StartMinute;
            break; 
      }
   }

   int Bar = 0;
   LowPrice = EMPTY_VALUE;
   HighPrice = EMPTY_VALUE;
   double CandleSize = EMPTY_VALUE;
   if (StartMinute != EMPTY_VALUE) {
      string TimeToConvert = IntegerToString(inStartHour);
      string MinuteToConvert = IntegerToString((long)StartMinuteDectection - (long)StartMinute, 2);
      TimeToConvert = TimeToConvert + ":" + MinuteToConvert;
      Bar = iBarShift(TradeOnSymbol, Period(), StringToTime(TimeToConvert), true);
      
      LowPrice = iLow(TradeOnSymbol, Period(), Bar);
      HighPrice = iHigh(TradeOnSymbol, Period(), Bar);
      CandleSize = HighPrice - LowPrice;
      drawLine("Low", LowPrice);
      drawLine("High", HighPrice);
   }
   if (TimeCandle.hour == inStartHour && TimeCandle.min > StartMinute && Bar == -1) {  // Get High low first candle
      StartMinuteDectection = StartMinuteDectection + StartMinute;
      LowPrice = EMPTY_VALUE;
      HighPrice = EMPTY_VALUE;
   }
   if ( (TimeCandle.hour < inStartHour) || (TimeCandle.hour == inStartHour && TimeCandle.min < StartMinuteDectection)) {
      LowPrice = EMPTY_VALUE;
      HighPrice = EMPTY_VALUE;
   }
   
   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(RSIHandleReal, 0, 0, 3, RSI) < 0)   {
      Print("Erro copiando buffer do indicador RSIHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   /* New candle detected, clean pending orders */
   if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == NOTRADE) {
      removeOrders(ORDER_TYPE_BUY_LIMIT);
      removeOrders(ORDER_TYPE_BUY_STOP);
      removeOrders(ORDER_TYPE_SELL_LIMIT);      
      removeOrders(ORDER_TYPE_SELL_STOP);
   }

   onGoingTrade = checkPositionTypeOpen();
   
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   if (CheckAutoRollingSymbol() == true) {
      LoadIndicators();
   }   

   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (onGoingTrade == NOTRADE) {
      StopLossPrice = EMPTY_VALUE;
      TakeProfitPrice = EMPTY_VALUE;   
   }
   if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice + ( (HighPrice - LowPrice) /2);
      StopLossPrice = PositionPrice - ((HighPrice - LowPrice) /2);
      setStops(StopLossPrice, TakeProfitPrice);
   }
   if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice - ( (HighPrice - LowPrice) /2);
      StopLossPrice = PositionPrice + ((HighPrice - LowPrice) /2);
      setStops(StopLossPrice, TakeProfitPrice);
   }

   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if ( onGoingTrade == NOTRADE) {
         if (LowPrice != EMPTY_VALUE && HighPrice != EMPTY_VALUE) {
            if (RSI[2] < LevelDown && priceData[1].close < LowPrice) {
               TradeMannStopLimit(LowPrice, ORDER_TYPE_BUY_STOP);
            }
         }
      }
      
      /* if (onGoingTrade == LONG && TakeProfitPrice != EMPTY_VALUE &&
            (priceData[0].close >= TakeProfitPrice || priceData[0].close <= StopLossPrice)) {
            signal_exit = SHORT;
      }*/
            

   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if ( onGoingTrade == NOTRADE) {
         if (LowPrice != EMPTY_VALUE && HighPrice != EMPTY_VALUE) {
            if (RSI[2] > LevelUP && priceData[1].close > HighPrice) {
               TradeMannStopLimit(HighPrice, ORDER_TYPE_SELL_STOP);
            }
         }
      }
      /*if (onGoingTrade == SHORT && TakeProfitPrice != EMPTY_VALUE &&
            (priceData[0].close <= TakeProfitPrice || priceData[0].close >= StopLossPrice)) {
            signal_exit = LONG;
      }*/

   }
   
   TradeMann(signal, signal_exit);   

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
