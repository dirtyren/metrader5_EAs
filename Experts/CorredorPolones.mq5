
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "MA"
input int EMAPeriod = 7;
int EMAHighHandle = -1;
double EMAHighBuffer[];
int EMALowHandle = -1;
double EMALowBuffer[];

double LowPrice = EMPTY_VALUE;
double HighPrice = EMPTY_VALUE;

double StartMinute = EMPTY_VALUE;
double StartMinuteDectection = EMPTY_VALUE;

int OnInit(void)
  {
   EAVersion = "v1.1";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   if (InitEA() == false) {
      return(INIT_FAILED);
   }

   
   EMAHighHandle = iMA(_Symbol,chartTimeframe,EMAPeriod,0,MODE_SMA , PRICE_HIGH);
   if (EMAHighHandle < 0) {
      Print("Erro criando indicador EMAHighHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAHighHandle);
   ArraySetAsSeries(EMAHighBuffer, true);
   
   EMALowHandle = iMA(_Symbol,chartTimeframe,EMAPeriod,0,MODE_SMA , PRICE_LOW);
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
   //AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);

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
   if (checkDayHasChanged() == true) {
      LowPrice = EMPTY_VALUE;
      HighPrice = EMPTY_VALUE;   
   }
     
   /* Tick time for EA */
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
         case PERIOD_H1: 
            StartMinute = 59;
            StartMinuteDectection = StartMinute;
            break;            
         default: 
            StartMinute = 5;
            StartMinuteDectection = StartMinute;
            break; 
      }
   }

   int Bar = 0;

   if (StartMinute != EMPTY_VALUE && TimeCandle.hour == inStartHour && TimeCandle.min >= StartMinute && LowPrice == EMPTY_VALUE) {
      string TimeToConvert = IntegerToString(inStartHour);
      string MinuteToConvert = IntegerToString((long)StartMinuteDectection - (long)StartMinute, 2);
      TimeToConvert = TimeToConvert + ":" + MinuteToConvert;
      Bar = iBarShift(Symbol(), Period(), StringToTime(TimeToConvert), true);
      
      LowPrice = iLow(_Symbol, Period(), Bar);
      HighPrice = iHigh(_Symbol, Period(), Bar);
      drawLine("Low", LowPrice);
      drawLine("High", HighPrice);      
   }
   if (TimeCandle.hour == inStartHour && TimeCandle.min > StartMinute && Bar == -1) {  // Get High low first candle
      StartMinuteDectection = StartMinuteDectection + StartMinute;
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
   
   /* New candle detected, clean pending orders */
   if (priceData[0].time != timeStampCurrentCandle) {
      removeOrders(ORDER_TYPE_BUY_LIMIT);
      removeOrders(ORDER_TYPE_SELL_LIMIT);
   }

   if (PositionTakeProfit == EMPTY_VALUE && onGoingTrade == LONG) {
      setTakeProfit(HighPrice);
   }
   if (onGoingTrade == NOTRADE && priceData[0].time != timeStampCurrentCandle) {
      drawLine("Low", LowPrice);
      drawLine("High", HighPrice);
   }
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (priceData[1].close > EMAHighBuffer[1]) {
     removeOrders(ORDER_TYPE_BUY_LIMIT);
     removeOrders(ORDER_TYPE_BUY_STOP);
   }   

   double tickSizeSlippage = 2 * SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);

   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close < EMALowBuffer[1] && LowPrice != EMPTY_VALUE) {
            if (priceData[0].close > LowPrice) {
               TradeMannStopLimit(LowPrice, ORDER_TYPE_BUY_LIMIT);
            }
            else {
               TradeMannStopLimit(LowPrice, ORDER_TYPE_BUY_STOP);
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (priceData[1].close > EMAHighBuffer[1]) {
            signal_exit = SHORT;
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      if (onGoingTrade == NOTRADE) {
         if (LowPrice != EMPTY_VALUE && HighPrice != EMPTY_VALUE) {
            if (priceData[1].close > EMAHighBuffer[1] && priceData[1].close >= (HighPrice)) {
               signal = SHORT;
            }
            /*if (priceData[1].close >= (HighPrice)) {
               TradeMann(SHORT, SHORT, (EMAHighBuffer[1] + 1), ORDER_TYPE_SELL_LIMIT);
            }*/
         }
      }
      /* LONG exit */
      if (onGoingTrade == SHORT && 
                        (priceData[1].close <= EMALowBuffer[1] || 
                         priceData[0].close <= LowPrice)) {
         signal_exit = LONG;
      }
   }
   
   TradeMann(signal, signal_exit);

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " tradeArmed ",tradeArmed, " Low/High first Candle ", LowPrice, " - ",HighPrice, " - StartMinute ", StartMinute);

}
