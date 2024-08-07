
//+------------------------------------------------------------------+
//| Expert tick function                           7                  |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "Keltner"
//+-----------------------------------+
//|  INDICATOR INPUT PARAMETERS       |
//+-----------------------------------+
enum Applied_price_ //Type of constant
  {
   PRICE_CLOSE_ = 1,     //PRICE_CLOSE
   PRICE_OPEN_,          //PRICE_OPEN
   PRICE_HIGH_,          //PRICE_HIGH
   PRICE_LOW_,           //PRICE_LOW
   PRICE_MEDIAN_,        //PRICE_MEDIAN
   PRICE_TYPICAL_,       //PRICE_TYPICAL
   PRICE_WEIGHTED_,      //PRICE_WEIGHTED
   PRICE_SIMPLE_,        //PRICE_SIMPLE
   PRICE_QUARTER_,       //PRICE_QUARTER_
   PRICE_TRENDFOLLOW0_,  //PRICE_TRENDFOLLOW0_
   PRICE_TRENDFOLLOW1_   //PRICE_TRENDFOLLOW1_
  };
input int KeltnerPeriod = 22; //Period of averaging
input ENUM_MA_METHOD MA_Method_ = MODE_EMA; //Method of averaging
input double Ratio = 2.0;
input Applied_price_ IPC = PRICE_CLOSE_;//Price constant
/* , used for calculation of the indicator (1-CLOSE, 2-OPEN, 3-HIGH, 4-LOW, 
  5-MEDIAN, 6-TYPICAL, 7-WEIGHTED, 8-SIMPLE, 9-QUARTER, 10-TRENDFOLLOW, 11-0.5 * TRENDFOLLOW.) */
input int Shift=0; // Horizontal shift of the indicator in bars
//---+
//Indicator buffers
double UpperBuffer[];
double MiddleBuffer[];
double LowerBuffer[];

int KHandle = INVALID_HANDLE;
int KHandleReal = INVALID_HANDLE;

input group             "Exit & Stop"
input double ExitPoints = 3;
//input double ExitStopLoss = 400;
input double DistanceToEnter = 1;
input int MinimalCandleSizetoEnter = 5;

int OnInit(void)
  {
   EAVersion = "v1.2";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   KHandle = iCustom(_Symbol,chartTimeframe,"keltner_channel", KeltnerPeriod, MA_Method_, Ratio, IPC, Shift);
   if (KHandle == INVALID_HANDLE) {
      Print("Erro KHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(KHandle);
   
   /* Initialize reasl symbol if needed - load the indicators on it */
   CheckAutoRollingSymbol();
   LoadIndicators();

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
   if (MQLInfoInteger(MQL_TESTER) && KHandleReal != INVALID_HANDLE) {
      return 0;
   }
   
   if (KHandleReal != INVALID_HANDLE) {
      IndicatorRelease(KHandleReal);
      KHandleReal = INVALID_HANDLE;
   }
   
   KHandleReal = iCustom(TradeOnSymbol,chartTimeframe,"keltner_channel", KeltnerPeriod, MA_Method_, Ratio, IPC, Shift);
   if (KHandleReal == INVALID_HANDLE) {
      Print("Erro KHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(UpperBuffer, true);
   ArraySetAsSeries(MiddleBuffer, true);
   ArraySetAsSeries(LowerBuffer, true);

   ArraySetAsSeries(priceData, true);
   CopyRates(TradeOnSymbol, chartTimeframe, 0, 5, priceData);
   
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
   CopyRates(TradeOnSymbol, chartTimeframe, 0, 5, priceData);

   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }

   double tickSizeSlippage = DistanceToEnter * SymbolInfoDouble(TradeOnSymbol,SYMBOL_TRADE_TICK_SIZE);   
   /* New candle detected */
   if (priceData[0].time != timeStampCurrentCandle) {
      if (onGoingTrade == LONG) {
         StopLossPrice =  priceData[1].low - tickSizeSlippage;
      }
      if (onGoingTrade == SHORT) {
         StopLossPrice =  priceData[1].high + tickSizeSlippage;
      }
      removeOrders(ORDER_TYPE_BUY_LIMIT);
      removeOrders(ORDER_TYPE_SELL_LIMIT);      
   }
   
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   if (CheckAutoRollingSymbol() == true) {
      LoadIndicators();
   }

   if (CopyBuffer(KHandleReal, 0, 0, 5, UpperBuffer) < 0)   {
      Print("Erro copiando buffer do indicador KHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(KHandleReal, 1, 0, 5, MiddleBuffer) < 0)   {
      Print("Erro copiando buffer do indicador KHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(KHandleReal, 2, 0, 5, LowerBuffer) < 0)   {
      Print("Erro copiando buffer do indicador KHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice + ExitPoints;
      StopLossPrice =  priceData[1].low - tickSizeSlippage;
      if (MQLInfoInteger(MQL_TESTER)) {
         setTakeProfit(TakeProfitPrice);
         setStopLoss(StopLossPrice);
      }
      drawLine("TP", TakeProfitPrice, clrGreen);
      drawLine("SL", StopLossPrice, clrRed);
   }
   if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice - ExitPoints;
      StopLossPrice =  priceData[1].high + tickSizeSlippage;
      if (MQLInfoInteger(MQL_TESTER)) {
         setTakeProfit(TakeProfitPrice);
         setStopLoss(StopLossPrice);         
      }
      drawLine("TP", TakeProfitPrice, clrGreen);
      drawLine("SL", StopLossPrice, clrRed);
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
         if (priceData[3].close < LowerBuffer[3] && priceData[2].close < LowerBuffer[2]) {
            if (priceData[1].close > LowerBuffer[1]) {
               if (getCandlesize(priceData[1]) >= MinimalCandleSizetoEnter) {
                  signal = LONG;
               }
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (MQLInfoInteger(MQL_TESTER) == false) {
            if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close >= TakeProfitPrice) {
               signal_exit = SHORT;
            }
            if (StopLossPrice != EMPTY_VALUE && priceData[0].close <= StopLossPrice) {
               signal_exit = SHORT;
            }
         }
      }
      
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[3].close > UpperBuffer[3] && priceData[2].close > UpperBuffer[2]) {
            if (priceData[1].close < UpperBuffer[1]) {
               if (getCandlesize(priceData[1]) >= MinimalCandleSizetoEnter) {
                  signal = SHORT;
               }
            }
         }
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         removeLine("Entry Price");
         if (MQLInfoInteger(MQL_TESTER) == false) {
            if (TakeProfitPrice != EMPTY_VALUE && priceData[0].close <= TakeProfitPrice) {
               signal_exit = LONG;
            }
            if (StopLossPrice != EMPTY_VALUE && priceData[0].close >= StopLossPrice) {
               signal_exit = LONG;
            }
         }
      }
     
   }
   
   TradeMann(signal, signal_exit);

}
