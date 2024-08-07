
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

double LowPrice = EMPTY_VALUE;
double HighPrice = EMPTY_VALUE;
double CandleSize = EMPTY_VALUE;
int    CandleDirection = NOTRADE;

double StartMinute = EMPTY_VALUE;
double StartMinuteDectection = EMPTY_VALUE;

input group             "Exit & Stop"
input int ExitPoints = 150;
input int ExitStopLoss = 300;


int OnInit(void)
  {
   EAVersion = "v1.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   if (InitEA() == false) {
      return(INIT_FAILED);
   }

   /* Initialize reasl symbol if needed - load the indicators on it */
   CheckAutoRollingSymbol();
   LoadIndicators();
   
   LowPrice = EMPTY_VALUE;
   HighPrice = EMPTY_VALUE;
   CandleSize = EMPTY_VALUE;
   CandleDirection = NOTRADE;

   int WFORockAndRoll = 0;
   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      // wfo_setCloseTradesOnSeparationLine(true); // false by default
     
      // this is the only required call in OnInit, all parameters come from the header
      WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);
   
      //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
      //wfo_setCustomPerformanceMeter(customEstimator);
   #endif
   
   return(WFORockAndRoll);
}
  
int LoadIndicators()
{
   
   ArraySetAsSeries(priceData, true);
   CopyRates(TradeOnSymbol, chartTimeframe, 0, 3, priceData);
   
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
   if (checkDayHasChanged()) {
      LowPrice = EMPTY_VALUE;
      HighPrice = EMPTY_VALUE;
      CandleSize = EMPTY_VALUE;
      CandleDirection = NOTRADE;
   }
     
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
   /* LowPrice = EMPTY_VALUE;
   HighPrice = EMPTY_VALUE; */
   if (StartMinute != EMPTY_VALUE && TimeCandle.hour == inStartHour && TimeCandle.min > 0) {
      string TimeToConvert = IntegerToString(inStartHour);
      string MinuteToConvert = IntegerToString((long)StartMinuteDectection - (long)StartMinute, 2);
      TimeToConvert = TimeToConvert + ":" + MinuteToConvert;
      Bar = iBarShift(Symbol(), Period(), StringToTime(TimeToConvert), true);
      
      LowPrice = iLow(TradeOnSymbol, Period(), Bar);
      HighPrice = iHigh(TradeOnSymbol, Period(), Bar);
      double ClosePrice = iClose(TradeOnSymbol, Period(), Bar);
      double OpenPrice = iOpen(TradeOnSymbol, Period(), Bar);
      if (ClosePrice > OpenPrice) {
         CandleDirection = LONG;
      }
      else if (ClosePrice < OpenPrice) {
         CandleDirection = SHORT;
      }
      CandleSize = HighPrice - LowPrice;
      drawLine("Low", LowPrice);
      drawLine("High", HighPrice);      
   }
   if (TimeCandle.hour == inStartHour && TimeCandle.min > StartMinute && Bar == -1) {  // Get High low first candle
      StartMinuteDectection = StartMinuteDectection + StartMinute;
   }
   
   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
/*   if (MQLInfoInteger(MQL_TESTER)) {
      if (PositionTakeProfit == EMPTY_VALUE && PositionCandlePosition > 0 && onGoingTrade == LONG) {
         if (EMAHighBuffer[0] < HighPrice) {
            setTakeProfit(EMAHighBuffer[0]);
         }
         else {
            setTakeProfit(HighPrice);
         }
      }
      if (PositionTakeProfit == EMPTY_VALUE && PositionCandlePosition > 0 && onGoingTrade == SHORT) {
         if (EMALowBuffer[0] < LowPrice) {
            setTakeProfit(EMALowBuffer[0]);
         }
         else {
            setTakeProfit(LowPrice);
         }
      }
      if (onGoingTrade == NOTRADE && priceData[0].time != timeStampCurrentCandle) {
         drawLine("Low", LowPrice);
         drawLine("High", HighPrice);
      }
      if (onGoingTrade == LONG && PositionCandlePosition > 0 && priceData[0].time != timeStampCurrentCandle) {
         removeLine("Low");
         removeLine("High");
         if (EMAHighBuffer[0] < HighPrice) {
            setTakeProfit(EMAHighBuffer[0]);
         }
         else {
            setTakeProfit(HighPrice);
         }
         //setTakeProfit(priceData[1].high+1);
      }
      if (onGoingTrade == SHORT && PositionCandlePosition > 0 && priceData[0].time != timeStampCurrentCandle) {
         removeLine("Low");
         removeLine("High");
         if (EMALowBuffer[0] < LowPrice) {
            setTakeProfit(EMALowBuffer[0]);
         }
         else {
            setTakeProfit(LowPrice);
         }
         //setTakeProfit(priceData[1].low-1);
      }
   }
   
   if (LowPrice != EMPTY_VALUE &&  HighPrice != EMPTY_VALUE) {
   }
*/

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   if (CheckAutoRollingSymbol() == true) {
      LoadIndicators();
   }

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   /*if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
   }
   else if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = HighPrice + (HighPrice - LowPrice);
      StopLossPrice = HighPrice - (HighPrice - LowPrice);
   }
   else if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = LowPrice - (HighPrice - LowPrice);
      StopLossPrice = LowPrice + (HighPrice - LowPrice);
   } 
   */  

   double tickSizeSlippage = 2 * SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (CandleSize >= 200 && CandleSize != EMPTY_VALUE) {
            if (CandleDirection == LONG) {
               /*if (MQLInfoInteger(MQL_TESTER)) {
                  if (priceData[0].open >= (HighPrice + tickSizeSlippage)) {
                     signal = LONG;
                  }
                  if (priceData[0].open < (HighPrice + tickSizeSlippage)) {
                     TradeMannStopLimit(HighPrice + tickSizeSlippage, ORDER_TYPE_BUY_LIMIT);
                  }
               }
               else {*/
                  if (priceData[0].close > (HighPrice + tickSizeSlippage)) {
                     signal = LONG;
                  }
               //}
            }
         }
      }
   
      /* LONG exit */
      /*if (onGoingTrade == LONG) {
         if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close > TakeProfitPrice) {
            signal_exit = SHORT;
         }
         if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close < StopLossPrice) {
            signal_exit = SHORT;
         }
      }*/
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (CandleSize >= 200 && CandleSize != EMPTY_VALUE) {
            if (CandleDirection == SHORT) {
               /*if (MQLInfoInteger(MQL_TESTER)) {
                  if (priceData[0].open <= (LowPrice - tickSizeSlippage)) {
                     signal = SHORT;
                  }
                  if (priceData[0].open > (LowPrice - tickSizeSlippage)) {
                     TradeMannStopLimit(LowPrice - tickSizeSlippage, ORDER_TYPE_SELL_LIMIT);
                  }
               }
               else {*/
                  if (priceData[0].close < (LowPrice - tickSizeSlippage)) {
                     signal = SHORT;
                  }
               //}
            }
         }
      }
   }
   
   TradeMann(signal, signal_exit);

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " tradeArmed ",tradeArmed, " Low/High first Candle ", LowPrice, " - ",HighPrice, " - StartMinute ", StartMinute);

}
