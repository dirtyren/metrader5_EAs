
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = 5600;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "HMA"
input int                inpPeriod  = 45;          // Period
input double             inpDivisor = 2.0;         // Divisor ("speed")
input ENUM_APPLIED_PRICE inpPrice   = PRICE_CLOSE; // Price
int HMAHandle = INVALID_HANDLE;
int HMAHandleReal = INVALID_HANDLE;
double HMA[];

input  group             "Volatility Quality Zero Line"
input int             inpPriceSmoothing         = 18;         // Price smoothing period
input ENUM_MA_METHOD  inpPriceSmoothingMethod   = MODE_LWMA;  // Price smoothing method
input double          inpFilter                 = 7.5;        // Filter (% of ATR)
int VolatilityHandle = INVALID_HANDLE;
int VolatilityHandleReal = INVALID_HANDLE;
double Volatility[];
double VolatilityValue[];
int VolDirection1 = NOTRADE;
int VolDirection2 = NOTRADE;

int OnInit(void)
  {
   EAVersion = "v3.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   HMAHandle = iCustom(_Symbol,chartTimeframe,"Hull average 2", inpPeriod, inpDivisor, inpPrice);
   if (HMAHandle < 0) {
      Print("Erro HMAHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(HMAHandle);
   ArraySetAsSeries(HMA, true);

   VolatilityHandle = iCustom(_Symbol,chartTimeframe,"Volatility quality zero line", inpPriceSmoothing, inpPriceSmoothingMethod, inpFilter);
   if (VolatilityHandle < 0) {
      Print("Erro TrendHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(VolatilityHandle, 2);
   ArraySetAsSeries(Volatility, true);
   ArraySetAsSeries(VolatilityValue, true);
   
   /*ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);*/
   
   /* Initialize reasl symbol if needed - load the indicators on it */
   CheckAutoRollingSymbol();
      
   int WFORockAndRoll = 0;
   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      wfo_setCloseTradesOnSeparationLine(false); // false by default
     
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
   if (MQLInfoInteger(MQL_TESTER) && HMAHandleReal != INVALID_HANDLE) {
      return 0;
   }

   if (HMAHandleReal != INVALID_HANDLE) {
      IndicatorRelease(HMAHandleReal);
      IndicatorRelease(VolatilityHandleReal);
      HMAHandleReal = INVALID_HANDLE;
      VolatilityHandleReal = INVALID_HANDLE;
   }
 
   HMAHandleReal = iCustom(_Symbol,chartTimeframe,"Hull average 2", inpPeriod, inpDivisor, inpPrice);
   if (HMAHandleReal < 0) {
      Print("Erro HMAHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(HMA, true);

   VolatilityHandleReal = iCustom(_Symbol,chartTimeframe,"Volatility quality zero line", inpPriceSmoothing, inpPriceSmoothingMethod, inpFilter);
   if (VolatilityHandleReal < 0) {
      Print("Erro VolatilityHandleReal - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(Volatility, true);
   ArraySetAsSeries(VolatilityValue, true);
   
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
   
   /* if day changes, reset filters to not trade is one was openedd yesterday */
   checkDayHasChanged();
     
   /* Tick time for EA */
   TimeToStruct(TimeCurrent(),now);
   timeNow = TimeCurrent();
   
   ArraySetAsSeries(priceData, true);   
   CopyRates(_Symbol, chartTimeframe, 0, 3, priceData);

   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   CheckAutoRollingSymbol();
   
   if (CopyBuffer(HMAHandle, 0, 0, 4, HMA) < 0)   {
      Print("Erro copiando buffer do indicador HMAHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(VolatilityHandle, 0, 0, 4, VolatilityValue) < 0)   {
      Print("Erro copiando buffer do indicador VolatilityHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(VolatilityHandle, 1, 0, 4, Volatility) < 0)   {
      Print("Erro copiando buffer do indicador VolatilityHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   VolDirection1 = NOTRADE;
   if (Volatility[1] == 1) {
      VolDirection1 = LONG;
   }
   else if (Volatility[1] == 2) {
      VolDirection1 = SHORT;
   }
   VolDirection2 = NOTRADE;
   if (Volatility[2] == 1) {
      VolDirection2 = LONG;
   }
   else if (Volatility[2] == 2) {
      VolDirection2 = SHORT;
   }

   onGoingTrade = checkPositionTypeOpen();
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if ( ((HMA[1] > HMA[2] && HMA[2] < HMA[3] && VolDirection1 == LONG) || 
           (HMA[1] > HMA[2] && VolDirection1 == LONG && VolDirection2 != LONG))) {
           signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG && ( (VolDirection1 == SHORT))) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if ( ((HMA[1] < HMA[2] && HMA[2] > HMA[3] && VolDirection1 == SHORT) || 
           (HMA[1] < HMA[2] && VolDirection1 == SHORT && VolDirection2 != SHORT))) {
          signal = SHORT;
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT && (VolDirection1 == LONG)) {
         signal_exit = LONG;
      }
   }
   
   
   TradeMann(signal, signal_exit);

   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);
}
