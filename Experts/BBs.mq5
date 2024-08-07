
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = -1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "Bolinger Bands"
input int                inBandsPeriod = 20;
input double             inBandsDeviation = 2;
input ENUM_APPLIED_PRICE inBandsPrice = PRICE_CLOSE;
input int                inBandsShift = 1;
int bandsHandle = INVALID_HANDLE;
int bandsRealHandle = INVALID_HANDLE;
double meanVal[];      // Array dinamico para armazenar valores medios da banda de Bollinger
double upperVal[];     // Array dinamico para armazenar valores medios da banda superior
double lowerVal[];     // Array dinamico para armazenar valores medios da banda inferior

int OnInit(void)
  {
  
   EAVersion = "v3.1";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   bandsHandle = iBands(_Symbol, chartTimeframe, inBandsPeriod, inBandsShift, inBandsDeviation, inBandsPrice);
   if (bandsHandle < 0) {
      Print("Erro criando indicadores - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(bandsHandle);
   
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
   if (MQLInfoInteger(MQL_TESTER) && bandsRealHandle != INVALID_HANDLE) {
      return 0;
   }

   if (bandsRealHandle != INVALID_HANDLE) {
      IndicatorRelease(bandsRealHandle);
      bandsRealHandle = INVALID_HANDLE;
   }
 
   bandsRealHandle = iBands(TradeOnSymbol, chartTimeframe, inBandsPeriod, inBandsShift, inBandsDeviation, inBandsPrice);
   if (bandsRealHandle < 0) {
      if(GetLastError() == 4302)
         Print("Symbol needs to be added to the MarketWatch", GetLastError(), "!");
      else
         Print("Erro criando indicadores - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(meanVal, true);
   ArraySetAsSeries(upperVal, true);
   ArraySetAsSeries(lowerVal, true);
   
   ArraySetAsSeries(priceData, true);   
   CopyRates(TradeOnSymbol, chartTimeframe, 0, 3, priceData);
   
   Print("Indicator(s) loaded on the symbol ", TradeOnSymbol);

   return 0;
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
   CopyRates(TradeOnSymbol, chartTimeframe, 0, 3, priceData);

   /* Check candle changed and new trade is allowed to start */
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (MQLInfoInteger(MQL_TESTER)) {
      /* New candle detected, clean pending orders */
      if (priceData[0].time != timeStampCurrentCandle && onGoingTrade == NOTRADE) {
         removeOrders(ORDER_TYPE_BUY_LIMIT);
         removeOrders(ORDER_TYPE_SELL_LIMIT);      
      }
   
      if (onGoingTrade != NOTRADE && PositionTakeProfit == 0) {
         if (onGoingTrade == LONG) {
            setTakeProfit(meanVal[0]);
         }
         if (onGoingTrade == SHORT) {
            setTakeProfit(meanVal[0]);
         }
      }
      if (priceData[0].time != timeStampCurrentCandle && onGoingTrade != NOTRADE) {
         if (onGoingTrade == LONG) {
            setTakeProfit(meanVal[0]);
         }
         if (onGoingTrade == SHORT) {
            setTakeProfit(meanVal[0]);
         }
      }   
   }
   
   /* Check if symbol needs to be changed and set timeStampCurrentCandle */
   /* Symbol has changed or first time */
   if (CheckAutoRollingSymbol() == true) {
      LoadIndicators();
   }
   
   if (CopyBuffer(bandsRealHandle, 0, 0, 3, meanVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(bandsRealHandle, 1, 0, 3, upperVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(bandsRealHandle, 2, 0, 3, lowerVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close < lowerVal[1] && priceData[0].close < meanVal[0]) {
            signal = LONG;
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (MQLInfoInteger(MQL_TESTER) == false) {
            if (priceData[0].close >= meanVal[0]) {
               signal_exit = SHORT;
            }
         }
         if (priceData[1].close > meanVal[1]) {
            signal_exit = SHORT;
         }
      }
      
      /* Pyramid */
      if (onGoingTrade == LONG) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition >0) {
            if (priceData[1].close < lowerVal[1] && priceData[0].close < meanVal[0]) {
            //if (priceData[1].close < lowerVal[1] &&  priceData[1].close < priceData[2].close && priceData[0].close < meanVal[0]) {
               TradeNewMann(LONG);
            }
         }
      }
      
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[1].close > upperVal[1] && priceData[0].close > meanVal[0]) {
            signal = SHORT;
         }
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         if (MQLInfoInteger(MQL_TESTER) == false) {
            if (priceData[0].close <= meanVal[0]) {
               signal_exit = LONG;
            }
         }
         if (priceData[1].close < meanVal[1]) {
            signal_exit = LONG;
         }
      }
      
      /* Pyramid */
      if (onGoingTrade == SHORT) {
         if (MaxPyramidTrades > 0 && totalPosisions <= MaxPyramidTrades && PositionCandlePosition >0) {
            if (priceData[1].close > upperVal[1] && priceData[0].close > meanVal[0]) {
            //if (priceData[1].close > upperVal[1] && priceData[1].close > priceData[2].close && priceData[0].close > meanVal[0]) {
               TradeNewMann(SHORT);
            }
         }
      }
   }

   TradeMann(signal, signal_exit);

   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " Position Price ", PositionPrice, " PositionCandlePosition ", PositionCandlePosition);
}
