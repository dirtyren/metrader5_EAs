
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 43100;
enum ENUM_INPUT_YES_NO
  {
   INPUT_YES   =  1, // Yes
   INPUT_NO    =  0  // No
  };
input ENUM_INPUT_YES_NO TradeOnAlternativeSymbol = INPUT_NO;
input string inTradeOnSymbol = "---";

input  group             "Configuration"
input ENUM_TIMEFRAMES chartTimeframe = PERIOD_M10;
input TRADE_DIRECTION TradeDirection = LONG_SHORT_TRADE;

input  group             "D. DAY TRADE"
sinput bool              inDayTrade = true;               // D.01 Operacao apenas como day trade
input int                inStartHour = 9;                 // D.02 Hora inicio negociacao
input int                inStartWaitMin = 0;              // D.03 Minutos a aguardar antes de iniciar operacoes
input int                inStopHour = 17;                 // D.04 Hora final negociacao
input int                inStopBeforeEndMin = 40;         // D.05 Minutos antes do fim para encerrar posicoes

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
input int MaxTradesDaily = 0;

input  group             "ATR"
input int ATRPeriod = 14;

input  group             "Bolinger Bands"
input int                inBandsPeriod = 17;
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
input int DistancePoints = 0;
input int ErrorMarginPoints = 0;

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

   trade.SetExpertMagicNumber(MyMagicNumber);
   
   onGoingTrade = checkPositionTypeOpen();
   totalPosisions = returnAllPositions();
   printf("onGoingTrade %d totalPosisions %d closedprofit %.2f", onGoingTrade, totalPosisions, closedProfitPeriod());
   Comment("Magic number: ", MyMagicNumber, " Profit ", closedProfitPeriod());

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
   double PricewithErrorMargin = EMPTY_VALUE;
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      PricewithErrorMargin = priceData[1].low - ErrorMarginPoints;
      /* LONG Signal */
      if (DistanceBBDown > DistancePoints &&
          TradeEntryPrice < PricewithErrorMargin) {
            signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG && PositionCandlePosition > 0 &&
          (priceData[1].close > PositionPrice || priceData[1].close > EMAHighBuffer[1]) ) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      PricewithErrorMargin = priceData[1].high + ErrorMarginPoints;
      /* SHORT Signal */
      if (DistanceBBUP > DistancePoints &&
          TakeProfitPrice > PricewithErrorMargin) {
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
