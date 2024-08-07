
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "T3"
input uint                 InpVolFactor      =  70;            // Volume factor (in percent)
input uint                 InpPeriod         =  15;            // Period
input ENUM_APPLIED_PRICE   InpAppliedPrice   =  PRICE_CLOSE;   // Applied price

int T3Handle = INVALID_HANDLE;
int T3HandleReal = INVALID_HANDLE;
double T3[];

input group             "RSI"
input int RSIPeriod = 2;
input int RSILevelDown = 50;
input int RSILevelUp = 50;
double RSI[];
int RSIHandle = INVALID_HANDLE;
int RSIHandleReal = INVALID_HANDLE;


int OnInit(void)
  {
   EAVersion = "v1.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   if (InitEA() == false) {
      return(INIT_FAILED);
   }

   T3Handle = iCustom(_Symbol,chartTimeframe,"T3",InpVolFactor, InpPeriod,InpAppliedPrice);
   if (T3Handle < 0) {
      Print("Erro criando indicador T3Handle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(T3Handle);
   
   RSIHandle = iRSI( _Symbol, chartTimeframe, RSIPeriod, PRICE_CLOSE);
   if (RSIHandle < 0) {
      Print("Erro criando indicadores - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(RSIHandle, 1);
   
   /* Initialize reasl symbol if needed - load the indicators on it */
   CheckAutoRollingSymbol();
   LoadIndicators();
   
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
  
int LoadIndicators()
{
   /* if in test mode, no need to unload and load the indicador */
   if (MQLInfoInteger(MQL_TESTER) && T3HandleReal != INVALID_HANDLE) {
      return 0;
   }

   if (T3HandleReal != INVALID_HANDLE) {
      IndicatorRelease(T3HandleReal);
      IndicatorRelease(RSIHandleReal);
      T3HandleReal = INVALID_HANDLE;
      RSIHandleReal = INVALID_HANDLE;
   }
   
   T3HandleReal = iCustom(_Symbol,chartTimeframe,"T3",InpVolFactor, InpPeriod,InpAppliedPrice);
   if (T3HandleReal < 0) {
      Print("Erro criando indicador T3HandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(T3, true);
 
   RSIHandleReal = iRSI(TradeOnSymbol, chartTimeframe, RSIPeriod, PRICE_CLOSE);
   if (RSIHandleReal < 0) {
      Print("Erro criando indicadores - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(RSI, true);
   
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
   
   /*if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == LONG) {
      setTakeProfit(priceData[1].high);
      drawLine("TakeProfit", TakeProfitPrice, clrSpringGreen);
   }
   if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == SHORT) {
      setTakeProfit(priceData[1].low);
      drawLine("TakeProfit", TakeProfitPrice, clrSpringGreen);
   }*/

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   if (CheckAutoRollingSymbol() == true) {
      LoadIndicators();
      ArraySetAsSeries(priceData, true);   
      CopyRates(TradeOnSymbol, chartTimeframe, 0, 3, priceData);
   }
  
   if (CopyBuffer(T3HandleReal, 0, 0, 3, T3) < 0)   {
      Print("Erro copiando buffer do indicador VwapHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(RSIHandleReal, 0, 0, 5, RSI) < 0)   {
      Print("Erro copiando buffer do indicador RSIHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;

   /*if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = priceData[1].high + (priceData[1].high - priceData[1].low) / 2;
      StopLossPrice = priceData[1].high - (priceData[1].high - priceData[1].low);
      drawLine("TakeProfit", TakeProfitPrice, clrSpringGreen);
      setStops(StopLossPrice, TakeProfitPrice);
   }
   if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = priceData[1].low - (priceData[1].high - priceData[1].low) / 2;
      StopLossPrice = priceData[1].low + (priceData[1].high - priceData[1].low);
      drawLine("TakeProfit", TakeProfitPrice, clrSpringGreen);
      setStops(StopLossPrice, TakeProfitPrice);
   }
   if (onGoingTrade == NOTRADE) {   
      TakeProfitPrice = EMPTY_VALUE;
      removeLine("TakeProfit");
   }*/

   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close > T3[1] && priceData[2].close < T3[2]) {
            if (RSI[1] > RSILevelUp) {
               signal = LONG;
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
      }
      
      /* Pyramid */
      /*if (onGoingTrade == LONG) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition > 0) {
            if (priceData[1].close < priceData[2].close) {
               TradeNewMann(LONG);
            }
         }
      }*/
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close < T3[1] && priceData[2].close > T3[2]) {
            if (RSI[1] < RSILevelDown) {
               signal = SHORT;
            }
         }
      }
   }

   TradeMann(signal, signal_exit);
   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
