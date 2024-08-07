
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
input int EMAPeriod = 3;

input  group             "Distance from Price Close"
input int DistanceMA = 10;

int EMAHighHandle = -1;
double EMAHighBuffer[];

int EMAHandle = -1;
double EMABuffer[];

double LowPrice = EMPTY_VALUE;
double HighPrice = EMPTY_VALUE;

int OnInit(void)
  {
   EAVersion = "v3.5";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   EMAHighHandle = iMA(_Symbol,chartTimeframe,EMAPeriod,1,MODE_SMA , PRICE_HIGH);
   if (EMAHighHandle < 0) {
      Print("Erro criando indicador EMAHighHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAHighHandle);
   ArraySetAsSeries(EMAHighBuffer, true);
   
   EMAHandle = iMA(_Symbol,chartTimeframe,EMAPeriod,1,MODE_SMA , PRICE_LOW);
   if (EMAHandle < 0) {
      Print("Erro criando indicador EMAHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAHandle);
   ArraySetAsSeries(EMABuffer, true);
   
   /* Initialize reasl symbol if needed - load the indicators on it */
   CheckAutoRollingSymbol();
   //LoadIndicators();
   
   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      // wfo_setCloseTradesOnSeparationLine(true); // false by default
     
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
   
   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   ArraySetAsSeries(priceData, true);   
   CopyRates(TradeOnSymbol, chartTimeframe, 0, 3, priceData);
 
   MqlDateTime TimeCandle ;
   TimeToStruct(priceData[0].time,TimeCandle);
   
   /* New candle detected, clean pending orders */
   if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == NOTRADE) {
      removeOrders(ORDER_TYPE_BUY_LIMIT);
      removeOrders(ORDER_TYPE_SELL_LIMIT);      
   }

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   if (CheckAutoRollingSymbol() == true) {
      //LoadIndicators();
   }
  
   if (CopyBuffer(EMAHighHandle, 0, 0, 3, EMAHighBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAHighHandle1 - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(EMAHandle, 0, 0, 3, EMABuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;

   LowPrice = NormalizeDouble((priceData[1].close - DistanceMA), _Digits);
   HighPrice = NormalizeDouble((priceData[1].close + DistanceMA), _Digits);

   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
      drawLine("Long Entry Point", LowPrice, clrYellow);
      drawLine("Short Entry Point", HighPrice, clrYellow);
      removeLine("Short Pyramid");
      removeLine("Long Pyramid");
   }
   if (onGoingTrade != NOTRADE) {
      removeLine("Long Entry Point");
      removeLine("Short Entry Point");
   }


   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         TradeMannStopLimit(LowPrice, ORDER_TYPE_BUY_LIMIT);
         /*if (BidPrice < LowPrice) {
            signal = LONG;
         }*/
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (PositionCandlePosition > 0 && priceData[1].close > EMAHighBuffer[1]) {
            signal_exit = SHORT;
         }
      }
      
      /* Pyramid */
      if (onGoingTrade == LONG) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition > 0) {
            removeLine("Long Pyramid");
            drawLine("Long Pyramid", LowPrice, clrDarkViolet);
            if (BidPrice < (LowPrice + totalPosisions)) {
               TradeNewMann(LONG);
            }
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         TradeMannStopLimit(HighPrice, ORDER_TYPE_SELL_LIMIT);
         /*if (AskPrice > HighPrice) {
            signal = SHORT;
         }*/
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         if (PositionCandlePosition > 0 && priceData[1].close < EMABuffer[1]) {
            signal_exit = LONG;
         }
      }
      
      /* Pyramid */
      if (onGoingTrade == SHORT) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition > 0) {
            removeLine("Short Pyramid");
            drawLine("Short Pyramid", HighPrice, clrDarkViolet);
            TradeMannStopLimit((HighPrice - totalPosisions), ORDER_TYPE_SELL_LIMIT);
            if (AskPrice > (HighPrice - totalPosisions)) {
               //TradeNewMann(SHORT);
            }
         }
      }
   }

   TradeMann(signal, signal_exit);

}
