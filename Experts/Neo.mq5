
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = 5500;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "HMA"
input int                inpPeriod  = 45;          // Period
input double             inpDivisor = 2.0;         // Divisor ("speed")
input ENUM_APPLIED_PRICE inpPrice   = PRICE_CLOSE; // Price
int HMAHandle;
double HMA[];

input  group             "Trend direction and force"
input int       trendPeriod  = 20;      // Trend period
input int       smoothPeriod = 3;       // Smoothing period
input double    TriggerUp    =  0.05;   // Trigger up level
input double    TriggerDown  = -0.05;   // Trigger down level
int VolatilityHandle;
double Volatility[];
double VolatilityValue[];
int VolDirection1 = NOTRADE;
int VolDirection2 = NOTRADE;
int VolDirection3 = NOTRADE;

int OnInit(void)
  {
  
   EAVersion = "v1.1";
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

   VolatilityHandle = iCustom(_Symbol,chartTimeframe,"Trend direction and force - JMA smoothed", trendPeriod, smoothPeriod, TriggerUp, TriggerDown);
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

   int WFORockAndRoll = INIT_SUCCEEDED;
   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      wfo_setCloseTradesOnSeparationLine(true); // false by default
     
      // this is the only required call in OnInit, all parameters come from the header
      WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);
   
      //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
      //wfo_setCustomPerformanceMeter(customEstimator);
   #endif

   return(WFORockAndRoll);
}
  
/* double OnTester()
{
   return optpr();         // optimization parameter
}
*/

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
   
   CopyRates(_Symbol, chartTimeframe, 0, 30, priceData);

   /* Time current candle */   
   timeStampCurrentCandle = priceData[0].time;
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   /*if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }*/
   
   if (CopyBuffer(HMAHandle, 0, 0, 4, HMA) < 0)   {
      Print("Erro copiando buffer do indicador HMAHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(VolatilityHandle, 2, 0, 5, VolatilityValue) < 0)   {
      Print("Erro copiando buffer do indicador VolatilityHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(VolatilityHandle, 3, 0, 5, Volatility) < 0)   {
      Print("Erro copiando buffer do indicador VolatilityHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();

   VolDirection1 = NOTRADE;
   if (Volatility[1] == 2) {
      VolDirection1 = LONG;
   }
   else if (Volatility[1] == 1) {
      VolDirection1 = SHORT;
   }

   VolDirection2 = NOTRADE;
   if (Volatility[2] == 2) {
      VolDirection2 = LONG;
   }
   else if (Volatility[2] == 1) {
      VolDirection2 = SHORT;
   }

   VolDirection3 = NOTRADE;
   if (Volatility[3] == 2) {
      VolDirection3 = LONG;
   }
   else if (Volatility[3] == 1) {
      VolDirection3 = SHORT;
   }      

   onGoingTrade = checkPositionTypeOpen();
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if ( (HMA[1] > HMA[2] && HMA[2] < HMA[3] && VolDirection1 == LONG) || 
           (HMA[1] > HMA[2] && VolDirection1 == LONG && VolDirection2 != LONG)) {
          signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG && (VolDirection1 == SHORT)) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if ( (HMA[1] < HMA[2] && HMA[2] > HMA[3] && VolDirection1 == SHORT) || 
           (HMA[1] < HMA[2] && VolDirection1 == SHORT && VolDirection2 != SHORT)) {
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
