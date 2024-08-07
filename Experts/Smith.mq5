
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 5800;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "HMA"
input int                inpPeriod  = 20;          // Period
input double             inpDivisor = 2.0;         // Divisor ("speed")
input ENUM_APPLIED_PRICE inpPrice   = PRICE_CLOSE; // Price
int HMAHandle;
double HMA[];

input  group             "Stochastic Momentum Index"
input int                SinpLength   = 13;        // Length
input int                SinpSmooth1  = 25;        // Smooth period 1
input int                SinpSmooth2  =  2;        // Smooth period 2
input int                SinpSignal   =  5;        // Signal period
input ENUM_APPLIED_PRICE SinpPrice=PRICE_CLOSE; // Price 
int StlHandle;
double ST[];
double STValue[];
int Momentum1 = NOTRADE;
int Momentum2 = NOTRADE;

int OnInit(void)
  {
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
   
   StlHandle = iCustom(_Symbol,chartTimeframe,"Stochastic Momentum Index", SinpLength, SinpSmooth1, SinpSmooth2, SinpSignal, SinpPrice);
   if (StlHandle < 0) {
      Print("Erro TrendHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(StlHandle, 1);
   ArraySetAsSeries(ST, true);
   ArraySetAsSeries(STValue, true);
   
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);

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
   
   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(HMAHandle, 0, 0, 4, HMA) < 0)   {
      Print("Erro copiando buffer do indicador HMAHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(StlHandle, 0, 0, 4, STValue) < 0)   {
      Print("Erro copiando buffer do indicador StlHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(StlHandle, 1, 0, 4, ST) < 0)   {
      Print("Erro copiando buffer do indicador StlHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   Momentum1 = NOTRADE;
   if (ST[1] == 1) {
      Momentum1 = LONG;
   }
   if (ST[1] == 2) {
      Momentum1 = SHORT;
   }
   Momentum2 = NOTRADE;   
   if (ST[2] == 1) {
      Momentum2 = LONG;
   }
   if (ST[2] == 2) {
      Momentum2 = SHORT;
   }

   onGoingTrade = checkPositionTypeOpen();
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if ( ((HMA[1] > HMA[2] && HMA[2] < HMA[3] && Momentum1 == LONG) || 
           (HMA[1] > HMA[2] && Momentum1 == LONG && Momentum2 != LONG))) {
          signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG && (Momentum1 == SHORT)) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if ( ((HMA[1] < HMA[2] && HMA[2] > HMA[3] && Momentum1 == SHORT) || 
           (HMA[1] < HMA[2] && Momentum1 == SHORT && Momentum2 != SHORT))) {
          signal = SHORT;
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT && (Momentum1 == LONG)) {
         signal_exit = LONG;
      }
   }
   
   if(MQLInfoInteger(MQL_TESTER) == 1) {
      TradeMann(signal, signal_exit, priceData[0].open);
   }
   else {
      TradeMann(signal, signal_exit);
   }
   
   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
