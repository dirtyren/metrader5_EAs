
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
input int                inBandsPeriod = 17;
input double             inBandsDeviation = 2;
input ENUM_APPLIED_PRICE inBandsPrice = PRICE_CLOSE;
input int                inBandsShift = 0;
int bandsHandle = -1;
double meanVal[];      // Array dinamico para armazenar valores medios da banda de Bollinger
double upperVal[];     // Array dinamico para armazenar valores medios da banda superior
double lowerVal[];     // Array dinamico para armazenar valores medios da banda inferior

input  group             "Kelner Channels"
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
//input int KeltnerPeriod = inBandsPeriod; // Period of averaging
input ENUM_MA_METHOD Keltner_MA_Method = MODE_SMA; // Method of averaging
input double Keltner_Ratio = 1.0;
input Applied_price_ Keltner_IPC = PRICE_CLOSE_;//Price constant
/* , used for calculation of the indicator (1-CLOSE, 2-OPEN, 3-HIGH, 4-LOW, 
  5-MEDIAN, 6-TYPICAL, 7-WEIGHTED, 8-SIMPLE, 9-QUARTER, 10-TRENDFOLLOW, 11-0.5 * TRENDFOLLOW.) */
input int Keltner_Shift=0; // Horizontal shift of the indicator in bars
//---+
//Indicator buffers
double KUp[];
double KMiddle[];
double KLower[];
int KHandle;

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
input int DistancePoints = 0;
input bool UseBBSqueeze = true;

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
   
   KHandle = iCustom(_Symbol,chartTimeframe,"keltner_channel", inBandsPeriod, Keltner_MA_Method, Keltner_Ratio, Keltner_IPC, Keltner_Shift);
   if (KHandle < 0) {
      Print("Erro criando indicadores KHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(KHandle);
   ArraySetAsSeries(KUp, true);
   ArraySetAsSeries(KMiddle, true);
   ArraySetAsSeries(KLower, true);
   
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
   
   if (CopyBuffer(bandsHandle, 0, 0, 7, meanVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(bandsHandle, 1, 0, 7, upperVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(bandsHandle, 2, 0, 7, lowerVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(KHandle, 0, 0, 7, KUp) < 0)   {
      Print("Erro copiando buffer do indicador KHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(KHandle, 1, 0, 7, KMiddle) < 0)   {
      Print("Erro copiando buffer do indicador KHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(KHandle, 2, 0, 7, KLower) < 0)   {
      Print("Erro copiando buffer do indicador KHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   bool BBSqueze = false;
   if (UseBBSqueeze == true) {
      int i = 1;
      for(i = 1; i <= 5; i++) {
         if (KUp[i] > upperVal[i] && KLower[i] < lowerVal[i]) {
            BBSqueze = true;
         }
      }
   }

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   double DistanceBBDown = lowerVal[1] - priceData[1].close;
   double DistanceBBUP =  priceData[1].close - upperVal[1];

   TradeEntryPrice = priceData[0].close;
   TakeProfitPrice = priceData[0].close;
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (DistanceBBDown > DistancePoints && BBSqueze == false &&
          TradeEntryPrice < priceData[1].low) {
            signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG && PositionCandlePosition > 0 &&
          (priceData[1].close > PositionPrice || priceData[1].close > EMAHighBuffer[1]) ) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (DistanceBBUP > DistancePoints && BBSqueze == false &&
          TakeProfitPrice > priceData[1].high) {
            signal = SHORT;
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT && PositionCandlePosition > 0 &&
          (priceData[1].close < PositionPrice || priceData[1].close < EMALowBuffer[1]) ) {
         signal_exit = LONG;
      }
   }
   
   TradeMann(signal, signal_exit);
   
   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " Position Price ", PositionPrice, " PositionCandlePosition ", PositionCandlePosition);

}
