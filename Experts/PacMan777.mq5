
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = 42500;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input group             "RSI"
input int RSIPeriod = 2;
input int RSILevelDown = 50;
input int RSILevelUp = 50;
double RSI[];
int RSIHandle;

input int CandlesToEnter = 2;
input double ExitPercent = 2;


int OnInit(void)
  {
   EAVersion = "v1.0";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);
   
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   RSIHandle = iRSI( _Symbol, chartTimeframe, RSIPeriod, PRICE_CLOSE);
   if (RSIHandle < 0) {
      Print("Erro criando indicadores - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(RSIHandle);
   ArraySetAsSeries(RSI, true);
   
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
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(RSIHandle, 0, 0, 3, RSI) < 0)   {
      Print("Erro copiando buffer do indicador RSIHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   
   /* Candle changed */
   if (timeStampCurrentCandle != priceData[0].time) {

   }
   
   /* Check if symbol needs to be changed */
   CheckAutoRollingSymbol();      

   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
  
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[2].close < priceData[2].open && priceData[1].close < priceData[1].open) {
            if (RSI[1] < RSILevelDown) {
               signal = LONG; 
            }
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG) {
         if (priceData[1].close > TakeProfitPrice && PositionCandlePosition > 0) {
            signal_exit = SHORT;
         }
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      //TradeEntryPrice = AskPrice;
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[2].close > priceData[2].open && priceData[1].close > priceData[1].open) {
            if (RSI[1] > RSILevelUp) {
               signal = SHORT;
            }
         }
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT) {
         if (priceData[1].close < TakeProfitPrice && PositionCandlePosition > 0) {
            signal_exit = LONG;
         }
      }
   }
   
   if (onGoingTrade == LONG) {
      if (priceData[1].high > priceData[2].high) {
         TakeProfitPrice = priceData[1].high;
      }
      else {
         TakeProfitPrice = priceData[2].high;
      }
      double exitAux = PositionPrice * ((ExitPercent /100) +1);
      if (TakeProfitPrice > exitAux) {
         TakeProfitPrice = exitAux;
      }
   }

   if (onGoingTrade == SHORT) {
      if (priceData[1].low < priceData[2].low) {
         TakeProfitPrice = priceData[1].low;
      }
      else {
         TakeProfitPrice = priceData[2].low;
      }
      double exitAux = PositionPrice - (PositionPrice * (ExitPercent /100));
      if (TakeProfitPrice < exitAux) {
         TakeProfitPrice = exitAux;
      }
   }      
   
   TradeMann(signal, signal_exit);
   
   Comment(EAName," Magic number: ", MyMagicNumber, " Symbol to trade ", TradeOnSymbol," - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
