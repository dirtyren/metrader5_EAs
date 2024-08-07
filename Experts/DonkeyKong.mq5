
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+//
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "EMA Fast"
input int EMAFastPeriod = 10;
int EMAFastHandle = -1;
double EMAFastBuffer[];

input  group             "EMA Slow"
input int EMASlowPeriod = 200;
int EMASlowHandle = -1;
double EMASlowBuffer[];

input  group             "Schaff Trend Cycle"
enum enPrices
  {
   pr_close,      // Close
   pr_open,       // Open
   pr_high,       // High
   pr_low,        // Low
   pr_median,     // Median
   pr_typical,    // Typical
   pr_weighted,   // Weighted
   pr_average,    // Average (high+low+open+close)/4
   pr_medianb,    // Average median body (open+close)/2
   pr_tbiased,    // Trend biased price
   pr_tbiased2,   // Trend biased (extreme) price
   pr_haclose,    // Heiken Ashi close
   pr_haopen ,    // Heiken Ashi open
   pr_hahigh,     // Heiken Ashi high
   pr_halow,      // Heiken Ashi low
   pr_hamedian,   // Heiken Ashi median
   pr_hatypical,  // Heiken Ashi typical
   pr_haweighted, // Heiken Ashi weighted
   pr_haaverage,  // Heiken Ashi average
   pr_hamedianb,  // Heiken Ashi median body
   pr_hatbiased,  // Heiken Ashi trend biased price
   pr_hatbiased2  // Heiken Ashi trend biased (extreme) price
  };
// input parameters
input int       SchaffPeriod = 32;       // Schaff period
input int       FastEma      = 23;       // Fast EMA period
input int       SlowEma      = 50;       // Slow EMA period
input double    SmoothPeriod = 3;        // Smoothing period
input enPrices  Price        = pr_close; // Price


int SchaffHandle = -1;
double Schaff[];

int OnInit(void)
  {

   EAVersion = "v1.4";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

   if(InitEA() == false) {
      return(INIT_FAILED);
   }
   
   EMAFastHandle = iMA(_Symbol,chartTimeframe,EMAFastPeriod,0,MODE_EMA , PRICE_CLOSE);
   if (EMAFastHandle == INVALID_HANDLE) {
      Print("Erro criando indicador EMAFastHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAFastHandle);
   ArraySetAsSeries(EMAFastBuffer, true);

   EMASlowHandle = iMA(_Symbol,chartTimeframe,EMASlowPeriod,0,MODE_EMA , PRICE_CLOSE);
   if (EMASlowHandle == INVALID_HANDLE) {
      Print("Erro criando indicador EMASlowHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMASlowHandle);
   ArraySetAsSeries(EMASlowBuffer, true);   

   SchaffHandle = iCustom(_Symbol,chartTimeframe,"Schaff Trend Cycle", SchaffPeriod, FastEma, SlowEma, SmoothPeriod, Price);
   if (SchaffHandle == INVALID_HANDLE) {
      Print("Erro SchaffHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(SchaffHandle);
   ArraySetAsSeries(Schaff, true);
   
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
      return(WFORockAndRoll);
   #endif
   return(INIT_SUCCEEDED);
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
   #ifdef WFO
      if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
         return 0.0;
      }
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
   
   ArraySetAsSeries(priceData, true);   
   CopyRates(_Symbol, chartTimeframe, 0, 3, priceData);
 
   /* Time current candle */   
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(EMAFastHandle, 0, 0, 3, EMAFastBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAFastHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(EMASlowHandle, 0, 0, 3, EMASlowBuffer) < 0) {
      Print("Erro copiando buffer do indicador EMASlowHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(SchaffHandle, 0, 0, 3, Schaff) < 0) {
      Print("Erro copiando buffer do indicador SchaffHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   
   
   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (EMAFastBuffer[1] > EMASlowBuffer[1] && EMAFastBuffer[2] < EMASlowBuffer[2]) {
            if (Schaff[1] > Schaff[2]) {
               signal = LONG;
            }
         }
      }

      /* Stops */
      if (onGoingTrade == LONG) {
         if (Schaff[1] < Schaff[2]) {
            signal_exit = SHORT;
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {

   }
   
   TradeMann(signal, signal_exit);

}
