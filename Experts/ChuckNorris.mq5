
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 40900;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "Bolinger Bands"
input int                inBandsPeriod = 30;
input double             inBandsDeviation = 2;
input ENUM_APPLIED_PRICE inBandsPrice = PRICE_CLOSE;
input int                inBandsShift = 0;
int bandsHandle = -1;
double meanVal[];      // Array dinamico para armazenar valores medios da banda de Bollinger
double upperVal[];     // Array dinamico para armazenar valores medios da banda superior
double lowerVal[];     // Array dinamico para armazenar valores medios da banda inferior

/* your indicator start here */
input  group             "MA Low / High"
input int EMAPeriodLow = 3;
input int EMAPeriodHigh = 3;
input ENUM_APPLIED_PRICE EMAPrice1 = PRICE_LOW;
input ENUM_APPLIED_PRICE EMAPrice2 = PRICE_HIGH;
int EMALowHandle = -1;
double EMALowBuffer[];
int EMAHighHandle = -1;
double EMAHighBuffer[];

input group "Close distance from BB"
input int DistancePoints = 100;
input int CandlesToStop = 1;

int OnInit(void)
  {
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   /* Load EA Indicators */
   EMALowHandle = iMA(_Symbol,chartTimeframe,EMAPeriodLow,0,  MODE_SMA , EMAPrice1);
   if (EMALowHandle < 0) {
      Print("Erro criando indicador EMALowHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMALowHandle);
   ArraySetAsSeries(EMALowBuffer, true);

   EMAHighHandle = iMA(_Symbol,chartTimeframe,EMAPeriodHigh,0,  MODE_SMA , EMAPrice2);
   if (EMAHighHandle < 0) {
      Print("Erro criando indicador EMAHighHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAHighHandle);
   ArraySetAsSeries(EMAHighBuffer, true);   
   
   bandsHandle = iBands(_Symbol, chartTimeframe, inBandsPeriod, inBandsShift, inBandsDeviation, inBandsPrice);
   if (bandsHandle < 0) {
      Print("Erro criando indicadores - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(bandsHandle);
   ArraySetAsSeries(meanVal, true);
   ArraySetAsSeries(upperVal, true);
   ArraySetAsSeries(lowerVal, true);
   
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
      // wfo_setCloseTradesOnSeparationLine(true); // false by default
     
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
   
   if (CopyBuffer(EMALowHandle, 0, 0, 3, EMALowBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMALowHandle2 - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(EMAHighHandle, 0, 0, 3, EMAHighBuffer) < 0)   {
      Print("Erro copiando buffer do indicador EMALowHandle2 - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(bandsHandle, 0, 0, 3, meanVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(bandsHandle, 1, 0, 3, upperVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(bandsHandle, 2, 0, 3, lowerVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   double DistanceBBDown = lowerVal[1] - priceData[1].close;
   double DistanceBBUP =  priceData[1].close - upperVal[1];
   
   TradeEntryPrice = priceData[0].close;
   TakeProfitPrice = priceData[0].close;
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      //TradeEntryPrice = BidPrice;
      /* LONG Signal */
      if (DistanceBBDown > DistancePoints &&
          TradeEntryPrice < priceData[1].low) {
            signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (PositionCandlePosition > 0 &&
             (priceData[1].close > PositionPrice || priceData[1].close > EMAHighBuffer[1]) ) {
            signal_exit = SHORT;
         }
         if (CandlesToStop > 0 && PositionCandlePosition > CandlesToStop) {
            signal_exit = SHORT;
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      //TradeEntryPrice = AskPrice;
      /* SHORT Signal */
      if (DistanceBBUP > DistancePoints &&
          TakeProfitPrice > priceData[1].high) {
            signal = SHORT;
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         if (PositionCandlePosition > 0 &&
             (priceData[1].close < PositionPrice || priceData[1].close < EMALowBuffer[1]) ) {
            signal_exit = LONG;
         }
         if (CandlesToStop > 0 && PositionCandlePosition > CandlesToStop) {
            signal_exit = LONG;
         }
      }
   }
   
   //TradeMann(signal, signal_exit,priceData[0].close);
   //TradeMann(signal, signal_exit);
   
   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " Position Price ", PositionPrice, " PositionCandlePosition ", PositionCandlePosition);

}
