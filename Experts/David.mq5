
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 36000;
enum ENUM_INPUT_YES_NO
  {
   INPUT_YES   =  1, // Yes
   INPUT_NO    =  0  // No
  };
input ENUM_INPUT_YES_NO TradeOnAlternativeSymbol = INPUT_NO;
input string inTradeOnSymbol = "---";

input  group             "Configuration"
input ENUM_TIMEFRAMES chartTimeframe = PERIOD_CURRENT;
input TRADE_DIRECTION TradeDirection = LONG_SHORT_TRADE;

input  group             "D. DAY TRADE"
sinput bool              inDayTrade = false;               // D.01 Operacao apenas como day trade
input int                inStartHour = 0;                 // D.02 Hora inicio negociacao
input int                inStartWaitMin = 0;              // D.03 Minutos a aguardar antes de iniciar operacoes
input int                inStopHour = 23;                 // D.04 Hora final negociacao
input int                inStopBeforeEndMin = 44;         // D.05 Minutos antes do fim para encerrar posicoes

input  group             "Geldman!!"
input Geldmann_Type Geldmann_type = LOTS;
input double geldMann = 1;

input  group             "Trailing"
input AdjustBy AdjustByType = PERCENTAGE;
input double TrailingStart = 0.0; // Trailing starts in percentage
input double TrailingPriceAdjustBy = 2; // How much to adjust price

input  group             "Takeprofit and Stoploss"
input double takeProfit = 0;
input double stopLoss = 0;

input  group             "Extras"
input double maxDailyLoss = 0;
input double maxDailyProfit = 0;
input int timeToSleep = 0;

input  group             "ATR"
input int ATRPeriod = 14;

input  group             "EMA Fast"
input int EMAFastPeriod = 8;
int EMAFastHandle = -1;
double EMAFastBuffer[];

input  group             "EMA Slow"
input int EMASlowPeriod = 20;
int EMASlowHandle = -1;
double EMASlowBuffer[];

int OnInit(void)
  {
   if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
      Print("Invalid trailing parameter ",TrailingStart, " ",TrailingStart);
      return(INIT_FAILED);
   }
   
   TradeOnSymbol = _Symbol;
   if (TradeOnAlternativeSymbol == INPUT_YES) {
      TradeOnSymbol = inTradeOnSymbol;
   }

   startTime = (inStartHour * 60) + inStartWaitMin;
   stopTime = (inStopHour * 60) + inStopBeforeEndMin;

   cleanUPIndicators();
   
   EMAFastHandle = iMA(_Symbol,chartTimeframe,EMAFastPeriod,0,MODE_EMA , PRICE_CLOSE);
   if (EMAFastHandle < 0) {
      Print("Erro criando indicador EMAFastHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMAFastHandle);
   ArraySetAsSeries(EMAFastBuffer, true);

   EMASlowHandle = iMA(_Symbol,chartTimeframe,EMASlowPeriod,0,MODE_EMA , PRICE_CLOSE);
   if (EMASlowHandle < 0) {
      Print("Erro criando indicador EMASlowHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMASlowHandle);
   ArraySetAsSeries(EMASlowBuffer, true);   
   
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

   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      wfo_setCloseTradesOnSeparationLine(false); // false by default
     
      // this is the only required call in OnInit, all parameters come from the header
      int WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);
   
      //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
      //wfo_setCustomPerformanceMeter(customEstimator);
      return(WFORockAndRoll);
   #endif
   return(0);
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
   CopyRates(_Symbol, chartTimeframe, 0, 5, priceData);
 
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
   
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   onGoingTrade = checkPositionTypeOpen();
   if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice + ((priceData[1].high - priceData[1].low)*2);
      StopLossPrice = priceData[1].low;
      setStops(StopLossPrice, TakeProfitPrice);
   }
   if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = PositionPrice - ((priceData[1].high - priceData[1].low)*2);
      StopLossPrice = priceData[1].high;
      setStops(StopLossPrice, TakeProfitPrice);
   }
   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
   }
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (EMAFastBuffer[1] > EMASlowBuffer[1] &&
          EMAFastBuffer[1] > EMAFastBuffer[2] &&
          EMASlowBuffer[1] > EMASlowBuffer[2] &&
          priceData[1].low < priceData[2].low &&
          priceData[1].low < priceData[3].low &&
          priceData[0].close > priceData[1].high) {
            signal = LONG;
      }
      //if (onGoingTrade == LONG && priceData[1].close < EMASlowBuffer[1]) {
      if (onGoingTrade == LONG &&  TakeProfitPrice != EMPTY_VALUE && 
                                   (PositionPriceCurrent >= TakeProfitPrice || PositionPriceCurrent <= StopLossPrice )) {
         signal_exit = SHORT;
         tradeArmed = false;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (EMAFastBuffer[1] < EMASlowBuffer[1] &&
          EMAFastBuffer[1] < EMAFastBuffer[2] &&
          EMASlowBuffer[1] < EMASlowBuffer[2] &&
          priceData[1].high > priceData[2].high &&
          priceData[1].high > priceData[3].high &&
          priceData[0].close < priceData[1].low) {
            signal = SHORT;
      }
      //if (onGoingTrade == LONG && priceData[1].close < EMASlowBuffer[1]) {
      if (onGoingTrade == SHORT &&  TakeProfitPrice != EMPTY_VALUE && 
                                   (PositionPriceCurrent <= TakeProfitPrice || PositionPriceCurrent >= StopLossPrice )) {
         signal_exit = LONG;
         tradeArmed = false;
      }
   }
   
   TradeMann(signal, signal_exit);   

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
