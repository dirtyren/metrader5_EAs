
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

//input  group             "MA"
//input int EMAHighPeriod = 9;

input  group             "MA"
input int EMAPeriod = 9;

input  group             "Target Points"
input int TargetPoints = 500;

input  group             "Distance from Low MA"
input int DistanceMA = 10;


int EMAHighHandle = -1;
double EMAHighBuffer[];

int EMAHandle = -1;
double EMABuffer[];

input group             "MACD"
//--- enum variables
enum colorswitch                                         // use single or multi-color display of Histogram
  {
   MultiColor=0,
   SingleColor=1
  };
input int                  InpFastEMA=12;                // Fast EMA period
input int                  InpSlowEMA=26;                // Slow EMA period
input int                  InpSignalMA=9;                // Signal MA period
input ENUM_MA_METHOD       InpAppliedSignalMA=MODE_SMA;  // Applied MA method for signal line
input colorswitch          InpUseMultiColor=MultiColor;  // Use multi-color or single-color histogram
input ENUM_APPLIED_PRICE   InpAppliedPrice=PRICE_CLOSE;  // Applied price
//--- indicator buffers

int MACDHandle = INVALID_HANDLE;
double MainLine[];
double SignalLine[];

double LowPrice = EMPTY_VALUE;
double LowPriceBellow = EMPTY_VALUE;

int OnInit(void)
  {
   EAVersion = "v3.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   MACDHandle = iCustom(_Symbol,chartTimeframe,"macd_histogram_mc", InpFastEMA, InpSlowEMA, InpSignalMA, InpAppliedSignalMA, InpUseMultiColor, InpAppliedPrice);
   if (MACDHandle == INVALID_HANDLE) {
      Print("Erro MACDHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(MACDHandle, 1);
   ArraySetAsSeries(MainLine, true);
   ArraySetAsSeries(SignalLine, true);
   
   EMAHighHandle = iMA(_Symbol,chartTimeframe,EMAPeriod,1,MODE_EMA , PRICE_HIGH);
   if (EMAHighHandle < 0) {
      Print("Erro criando indicador EMAHighHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAHighHandle);
   ArraySetAsSeries(EMAHighBuffer, true);
   
   EMAHandle = iMA(_Symbol,chartTimeframe,EMAPeriod,1,MODE_EMA , PRICE_LOW);
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
      removeOrders(ORDER_TYPE_BUY_STOP);
      removeOrders(ORDER_TYPE_BUY_LIMIT);
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
   
   if (CopyBuffer(MACDHandle, 0, 0, 3, MainLine) < 0)   {
      Print("Erro copiando buffer do indicador STOHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(MACDHandle, 1, 0, 3, SignalLine) < 0)   {
      Print("Erro copiando buffer do indicador STOHandleReal - error:", GetLastError());
      ResetLastError();
      return;
   }      

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;

   if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE && TargetPoints > 0) {
      drawLine("TakeProfit", TakeProfitPrice, clrSpringGreen);
      TakeProfitPrice = PositionPrice + TargetPoints;
      setTakeProfit(TakeProfitPrice);
      TakeProfitPrice = PositionPrice + TargetPoints + 1;
   }
   
   LowPrice = NormalizeDouble((EMABuffer[1] - DistanceMA), _Digits);

   if (onGoingTrade == NOTRADE) {

   }
   if (onGoingTrade != NOTRADE) {
   }


   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (MainLine[1] > SignalLine[1] && MainLine[2] < SignalLine[2] ) {
            signal = LONG;
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (MainLine[1] < SignalLine[1]) {
            signal_exit = SHORT;
         }
      }
      
      /* Pyramid */
      if (onGoingTrade == LONG) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition > 0) {
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
   }

   TradeMann(signal, signal_exit);

}
