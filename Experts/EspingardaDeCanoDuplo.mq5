
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 40300;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "Bolinger Bands"
enum enMaTypes
  {
   ma_sma,    // Simple moving average
   ma_ema,    // Exponential moving average
   ma_smma,   // Smoothed MA
   ma_lwma    // Linear weighted MA
  };
input int                 inpPeriods    = 17;           // Bollinger bands period
input double              inpDeviations = 1.0;          // Bollinger bands deviations
input enMaTypes           inpMaMethod   = ma_ema;       // Bands median average method
input ENUM_APPLIED_PRICE  inpPrice      = PRICE_CLOSE;  // Price
static int bandsHandle;
double meanVal[];      // Array dinamico para armazenar valores medios da banda de Bollinger
double upperVal[];     // Array dinamico para armazenar valores medios da banda superior
double lowerVal[];     // Array dinamico para armazenar valores medios da banda inferior

input group "Deviation from BB and Exit price in %"
double DeviationFromBB = 0.5;

input  group             "EMA"
input int EMAPeriod = 17;
input int EMAShift = 1;
input ENUM_APPLIED_PRICE  EMAPrice      = PRICE_OPEN;  // Price
int EMAHighHandle = -1;
double EMAHighBuffer[];

int OnInit(void)
  {
   if (InitEA() == false) {
      return(INIT_FAILED);
   }

   bandsHandle = iCustom(_Symbol,chartTimeframe,"Bollinger bands - EMA deviation",inpPeriods, inpDeviations, inpMaMethod, inpPrice);
   if (bandsHandle < 0) {
      Print("Erro criando indicadores bandsHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(bandsHandle);
   ArraySetAsSeries(meanVal, true);
   ArraySetAsSeries(upperVal, true);
   ArraySetAsSeries(lowerVal, true);

   EMAHighHandle = iMA(_Symbol,chartTimeframe,EMAPeriod,EMAShift, MODE_EMA , PRICE_OPEN);
   if (EMAHighHandle < 0) {
      Print("Erro criando indicador EMAHighHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAHighHandle);
   ArraySetAsSeries(EMAHighBuffer, true);
  
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);

   trade.SetExpertMagicNumber(MyMagicNumber);
   
   onGoingTrade = checkPositionTypeOpen();
   totalPosisions = returnAllPositions();
   printf("onGoingTrade %d totalPosisions %d closedprofit %.2f", onGoingTrade, totalPosisions, closedProfitPeriod());
   Comment("Magic number: ", MyMagicNumber, " Profit ", closedProfitPeriod());

   wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
   wfo_setPFmax(100); // DBL_MAX by default
   // wfo_setCloseTradesOnSeparationLine(true); // false by default
  
   // this is the only required call in OnInit, all parameters come from the header
   int WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);

   //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
   //wfo_setCustomPerformanceMeter(customEstimator);
   
   return(WFORockAndRoll);
  }
  
/* double OnTester()
{
   return optpr();         // optimization parameter
}
*/

void OnTesterInit()
{
  wfo_OnTesterInit(wfo_outputFile); // required
}

void OnTesterDeinit()
{
  wfo_OnTesterDeinit(); // required
}

void OnTesterPass()
{
  wfo_OnTesterPass(); // required
}

double OnTester()
{
   if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
      return 0.0;
   }
   return wfo_OnTester(); // required
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   cleanUPIndicators();
}

void OnTick()
{

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

   /* if day changes, reset filters to not trade is one was opened yesterday */
   checkDayHasChanged();
     
   /* Tick time for EA */
   TimeToStruct(TimeCurrent(),now);
   timeNow = TimeCurrent();
   
   ArraySetAsSeries(priceData, true);   
   CopyRates(_Symbol, chartTimeframe, 0, 3, priceData);
 

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
   
   if (CopyBuffer(EMAHighHandle, 0, 0, 4, EMAHighBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMAHighHandle1 - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(bandsHandle, 4, 0, 3, meanVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(bandsHandle, 0, 0, 3, upperVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(bandsHandle, 3, 0, 3, lowerVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   onGoingTrade = checkPositionTypeOpen();
   
   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
   }
   if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice + (PositionPrice * DeviationFromBB / 100);
   }   
   if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice - (PositionPrice * DeviationFromBB / 100);
   }   
   
   double BBEntryPrice = 0;

   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      BBEntryPrice = lowerVal[1] - (lowerVal[1] * DeviationFromBB / 100);
      /* LONG Signal */
      if (priceData[1].close < BBEntryPrice &&
          priceData[1].close < EMAHighBuffer[1]) {
            signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG && priceData[0].close >= EMAHighBuffer[1]) {
         signal_exit = SHORT;
      }
      if (onGoingTrade == LONG && TakeProfitPrice != EMPTY_VALUE && priceData[1].close >= TakeProfitPrice) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      BBEntryPrice = upperVal[1] + (upperVal[1] * DeviationFromBB / 100);
      /* SHORT Signal */
      if (priceData[1].close > BBEntryPrice &&
          priceData[1].close > EMAHighBuffer[1]) {
            signal = SHORT;
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT && priceData[0].close <= EMAHighBuffer[1]) {
         signal_exit = LONG;
      }
      if (onGoingTrade == SHORT && TakeProfitPrice != EMPTY_VALUE && priceData[1].close <= TakeProfitPrice) {
         signal_exit = LONG;
      }
   }
   
   TradeMann(signal, signal_exit);
      
   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
