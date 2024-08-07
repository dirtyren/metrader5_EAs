
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "EMA Fast"
input int EMAFastPeriod = 200;
int EMAFastHandle = INVALID_HANDLE;
int EMAFastHandleReal = INVALID_HANDLE;
double EMAFastBuffer[];

input group             "RSI"
input int RSIPeriod = 2;
input int RSILevelDown = 25;
input int RSILevelUp = 90;
double RSI[];
int RSIHandle = INVALID_HANDLE;
int RSIHandleReal = INVALID_HANDLE;

input group             "RSI Trend"
input int RSITrendPeriod = 2;
input int RSITrendLevelDown = 50;
input int RSITrendLevelUp = 50;
double RSITrend[];
int RSITrendHandle = INVALID_HANDLE;
int RSITrendHandleReal = INVALID_HANDLE;

int OnInit(void)
  {
   EAVersion = "v4.1";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   EMAFastHandle = iMA(_Symbol,chartTimeframe,EMAFastPeriod,0,MODE_EMA , PRICE_CLOSE);
   if (EMAFastHandle == INVALID_HANDLE) {
      Print("Erro criando indicador EMAFastHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAFastHandle);
   
   RSIHandle = iRSI( _Symbol, chartTimeframe, RSIPeriod, PRICE_CLOSE);
   if (RSIHandle < 0) {
      Print("Erro criando indicadores - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(RSIHandle, 1);
   
   RSITrendHandle = iRSI( _Symbol, chartTimeframe, RSITrendPeriod, PRICE_CLOSE);
   if (RSITrendHandle < 0) {
      Print("Erro criando indicadores RSITrendHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(RSITrendHandle, 1);

   /* Symbol has changed or first time, load on real symbol the indicator */
   if (CheckAutoRollingSymbol() == true) {
      LoadIndicators();
   }

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
   /* if in test mode, no need to unload and load the indicador */
   if (MQLInfoInteger(MQL_TESTER) && RSIHandleReal != INVALID_HANDLE) {
      return 0;
   }

   if (RSIHandleReal != INVALID_HANDLE) {
      IndicatorRelease(RSIHandleReal);
      IndicatorRelease(RSITrendHandleReal);
      IndicatorRelease(EMAFastHandleReal);
      RSIHandleReal = INVALID_HANDLE;
      EMAFastHandleReal = INVALID_HANDLE;
      RSITrendHandleReal = INVALID_HANDLE;
   }
 
   EMAFastHandleReal = iMA(TradeOnSymbol,chartTimeframe,EMAFastPeriod,0,MODE_EMA , PRICE_CLOSE);
   if (EMAFastHandleReal == INVALID_HANDLE) {
      Print("Erro criando indicador EMAFastHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(EMAFastBuffer, true);   
   
   RSIHandleReal = iRSI(TradeOnSymbol, chartTimeframe, RSIPeriod, PRICE_CLOSE);
   if (RSIHandleReal < 0) {
      Print("Erro criando indicadores - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(RSI, true);
   
   RSITrendHandleReal = iRSI(TradeOnSymbol, chartTimeframe, RSITrendPeriod, PRICE_CLOSE);
   if (RSITrendHandleReal < 0) {
      Print("Erro criando indicadores RSITrendHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(RSITrend, true);
   
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

void OnTrade()
{

   closePositionBy();

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
   CopyRates(_Symbol, chartTimeframe, 0, 5, priceData);

   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(EMAFastHandleReal, 0, 0, 5, EMAFastBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAFastHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(RSIHandleReal, 0, 0, 5, RSI) < 0)   {
      Print("Erro copiando buffer do indicador RSIHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(RSITrendHandle, 0, 0, 5, RSITrend) < 0)   {
      Print("Erro copiando buffer do indicador RSITrendHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   /* Candle changed */
   if (timeStampCurrentCandle != priceData[0].time) {
   }

   if (MQLInfoInteger(MQL_TESTER)) {
      /* New candle detected, clean pending orders */
      /*if (priceData[0].time != timeStampCurrentCandle) {
         if (onGoingTrade != NOTRADE) {
            setTakeProfit(EMAFastBuffer[0]);
         }
      }*/

      /* if (PositionTakeProfit == 0 && TakeProfitPrice != EMPTY_VALUE) {
         if (onGoingTrade == SHORT || onGoingTrade == LONG) {
            setTakeProfit(TakeProfitPrice);
            setStopLoss(StopLossPrice);
         }
      }
      if (onGoingTrade == NOTRADE) {
         TakeProfitPrice = EMPTY_VALUE;
         StopLossPrice = EMPTY_VALUE;
         PositionTakeProfit = EMPTY_VALUE;
      }*/
   }
   
   /* New candle detected, clean pending orders */
   if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == NOTRADE) {
      removeOrders(ORDER_TYPE_BUY_LIMIT);
      removeOrders(ORDER_TYPE_SELL_LIMIT);      
   }
   
  
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   if (CheckAutoRollingSymbol() == true) {
      LoadIndicators();
   }

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      SetHighLowPriceCandles(2, 1, chartTimeframe, 0);
      TakeProfitPrice = HighestPrice + SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);
      //StopLossPrice =  PositionPrice - ExitStopLoss;
      setTakeProfit(TakeProfitPrice);
      //setStopLoss(StopLossPrice);
      drawLine("TP", TakeProfitPrice, clrGreen);
      //drawLine("SL", StopLossPrice, clrRed);
   }
   if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
   }   
   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
      StopLossPrice = EMPTY_VALUE;
      removeLine("TP");
      removeLine("SL");
   }
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (RSITrend[1] > RSITrendLevelUp) {
            if (RSI[1] < RSILevelDown) {
               signal = LONG;
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
   }
   
   TradeMann(signal, signal_exit);
 
   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
