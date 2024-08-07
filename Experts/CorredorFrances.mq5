//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Functions by Invest Friends                                             |
//+------------------------------------------------------------------+
// #define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input group "MM"
input int EMALongPeriod = 70;
int EMALongHandle = -1;
double EMALongBuffer[];

input group "MM High"
input int EMAHighPeriod = 2;
int EMAHighHandle = -1;
double EMAHigh[];

input group "MM Low"
input int EMALowPeriod = 3;
int EMALowHandle = -1;
double EMALow[];

input group "Distance in points"
input int DistanceToEnter = 3000;

double LowPrice = EMPTY_VALUE;
double HighPrice = EMPTY_VALUE;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit(void)
  {

   EAVersion = "v1.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
     
   EMALongHandle = iMA(_Symbol,chartTimeframe,EMALongPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(EMALongHandle < 0) {
      Print("Erro criando indicador EMALongHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMALongHandle);
   ArraySetAsSeries(EMALongBuffer, true);
   
   EMALowHandle = iMA(_Symbol,chartTimeframe, EMALowPeriod, 1, MODE_SMA, PRICE_LOW);
   if(EMALowHandle < 0) {
      Print("Erro criando indicador EMALowHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMALowHandle);
   ArraySetAsSeries(EMALow, true);
   
   EMAHighHandle = iMA(_Symbol,chartTimeframe, EMAHighPeriod, 1, MODE_SMA, PRICE_HIGH);
   if(EMAHighHandle < 0) {
      Print("Erro criando indicador EMAHighHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAHighHandle);
   ArraySetAsSeries(EMAHigh, true);   

   /* Initialize reasl symbol if needed - load the indicators on it */
   CheckAutoRollingSymbol();
   //LoadIndicators();

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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTesterInit()
  {
#ifdef WFO
   wfo_OnTesterInit(wfo_outputFile); // required
#endif
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTesterDeinit()
  {
#ifdef WFO
   wfo_OnTesterDeinit(); // required
#endif
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTesterPass()
  {
#ifdef WFO
   wfo_OnTesterPass(); // required
#endif
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
   if(TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
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
void OnDeinit(const int reason)
  {
   DeInitEA();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {

   #ifdef WFO
      int wfo = wfo_OnTick();
      if(wfo == -1) {
         // can do some non-trading stuff, such as gathering bar or ticks statistics
         return;
      }
      else if(wfo == +1)  {
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
   if(tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }

   if (CopyBuffer(EMALongHandle, 0, 0, 3, EMALongBuffer) < 0) {
      Print("Erro copiando buffer do indicador EMALongHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(EMALowHandle, 0, 0, 3, EMALow) < 0) {
      Print("Erro copiando buffer do indicador EMALowHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(EMAHighHandle, 0, 0, 3, EMAHigh) < 0) {
      Print("Erro copiando buffer do indicador EMAHighHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   /* New candle detected, clean pending orders */
   if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == NOTRADE) {
      removeOrders(ORDER_TYPE_BUY_LIMIT);
      removeOrders(ORDER_TYPE_SELL_LIMIT);
      LowPrice = EMPTY_VALUE;
      HighPrice = EMPTY_VALUE;
   }

   if (HighPrice == EMPTY_VALUE) {
      LowPrice = EMALow[1] - DistanceToEnter;
      HighPrice = EMAHigh[1] + DistanceToEnter;
      TradeMannStopLimit(LowPrice, ORDER_TYPE_BUY_LIMIT);
      TradeMannStopLimit(HighPrice, ORDER_TYPE_SELL_LIMIT);
   }

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if(TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */

      /* Stops */
      if(onGoingTrade == LONG) {
         if (PositionCandlePosition > 0 && priceData[1].close > PositionPrice) {
            signal_exit = SHORT;
         }
         if (priceData[1].close > priceData[2].high) {
            signal_exit = SHORT;
         }
      }
   }

   if(TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE)
     {
      /* SHORT Signal */

      /* Stops */
      if(onGoingTrade == SHORT) {
         if (PositionCandlePosition > 0 && priceData[1].close < PositionPrice) {
            signal_exit = LONG;
         }
         if (priceData[1].close < priceData[2].low) {
            signal_exit = LONG;
         }
      }
   }

   TradeMann(signal, signal_exit);

   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);
}
//+------------------------------------------------------------------+
