
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 42705;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "Keltner Channels"
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

input int KeltnerPeriod = 10; //Period of averaging
input ENUM_MA_METHOD Keltner_MA_Method = MODE_SMA; //Method of averaging
input double KeltnerRatio = 1.0;
input Applied_price_ KeltnerPrice = PRICE_CLOSE_;//Price constant
/* , used for calculation of the indicator (1-CLOSE, 2-OPEN, 3-HIGH, 4-LOW, 
  5-MEDIAN, 6-TYPICAL, 7-WEIGHTED, 8-SIMPLE, 9-QUARTER, 10-TRENDFOLLOW, 11-0.5 * TRENDFOLLOW.) */
input int KeltnerShift=0; // Horizontal shift of the indicator in bars
//---+
//Indicator buffers
int KeltnerHandle = -1;
double upperVal[];
double meanVal[];
double lowerVal[];

int OnInit(void)
  {
   if (InitEA() == false) {
      return(INIT_FAILED);
   }

   KeltnerHandle = iCustom(_Symbol,chartTimeframe,"keltner_channel", KeltnerPeriod, Keltner_MA_Method, KeltnerRatio, KeltnerPrice, KeltnerShift);
   if (KeltnerHandle < 0) {
      Print("Erro KeltnerHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(KeltnerHandle);
   ArraySetAsSeries(upperVal, true);
   ArraySetAsSeries(meanVal, true);
   ArraySetAsSeries(lowerVal, true);

   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   // AddIndicator(ATRHandle, 4);
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
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(KeltnerHandle, 0, 0, 3, upperVal) < 0)   {
      Print("Erro copiando buffer do indicador KeltnerHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(KeltnerHandle, 1, 0, 3, meanVal) < 0)   {
      Print("Erro copiando buffer do indicador KeltnerHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(KeltnerHandle, 2, 0, 3, lowerVal) < 0)   {
      Print("Erro copiando buffer do indicador KeltnerHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   
   if (onGoingTrade != NOTRADE) {
      if (priceData[0].time > timeStampCurrentCandle) {
         //setTakeProfit(meanVal[0]);
      }
   }
   
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   CheckAutoRollingSymbol();   
   
   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (onGoingTrade != NOTRADE && PositionTakeProfit == EMPTY_VALUE) {
      //setTakeProfit(meanVal[0]);
   }
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[2].close < lowerVal[2] && priceData[1].close > lowerVal[1] && priceData[1].close < upperVal[1]) {
            if (priceData[2].high > priceData[1].high && priceData[0].close > priceData[1].high) {
               signal = LONG;
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (priceData[1].close < lowerVal[1] && PositionCandlePosition > 0) {
            signal_exit = SHORT;
         }
         if (priceData[1].close > upperVal[1] && PositionCandlePosition > 0) {
            signal_exit = SHORT;
         }

      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[2].close > upperVal[2] && priceData[1].close < upperVal[1] && priceData[1].close > lowerVal[1]) {
            if (priceData[2].low < priceData[1].low  && priceData[0].close < priceData[1].low) {
               signal = SHORT;
            }
         }
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         if (priceData[1].close > upperVal[1] && PositionCandlePosition > 0) {
            signal_exit = LONG;
         }
         if (priceData[1].close < lowerVal[1] && PositionCandlePosition > 0) {
            signal_exit = LONG;
         }
      }
   }
   
   TradeMann(signal, signal_exit);
   
   Comment("Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " Position Price ", PositionPrice, " PositionCandlePosition ", PositionCandlePosition);
}
