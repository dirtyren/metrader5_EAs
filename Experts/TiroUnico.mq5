
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#include<Trade\Trade.mqh>
#include<InvestFriends-activtrades.mqh>
#include <WalkForwardOptimizer.mqh>
//#include <k_ratio.mqh>

typedef double (*FUNCPTR_WFO_CUSTOM)(const datetime startDate, const datetime splitDate, const double &map[/*WFO_STATS_MAP*/]);

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 9080;
enum ENUM_INPUT_YES_NO
  {
   INPUT_YES   =  1, // Yes
   INPUT_NO    =  0  // No
  };
input ENUM_INPUT_YES_NO TradeOnAlternativeSymbol = INPUT_NO;
input string inTradeOnSymbol = "---";

input  group             "Configuration"
input ENUM_TIMEFRAMES chartTimeframe = PERIOD_M5;
input TRADE_DIRECTION TradeDirection = LONG_SHORT_TRADE;

input  group             "ATR"
input int ATRPeriod = 14;

input  group             "Bolinger Bands"
enum enPrices
{
   pr_close,      // Close
   pr_open,       // Open
   pr_high,       // High
   pr_low,        // Low
   pr_median,     // Median
   pr_typical,    // Typical
   pr_weighted,   // Weighted
   pr_haclose,    // Heiken ashi close
   pr_haopen ,    // Heiken ashi open
   pr_hahigh,     // Heiken ashi high
   pr_halow,      // Heiken ashi low
   pr_hamedian,   // Heiken ashi median
   pr_hatypical,  // Heiken ashi typical
   pr_haweighted, // Heiken ashi weighted
   pr_haaverage   // Heiken ashi average
};

enum enMaModes
{
   ma_Simple,  // Simple moving average
   ma_Expo     // Exponential moving average
};
enum enMaVisble
{
   mv_Visible,    // Middle line visible
   mv_NotVisible  // Middle line not visible
};

enum enCandleMode
{
   cm_None,   // Do not draw candles nor bars
   cm_Bars,   // Draw as bars
   cm_Candles // Draw as candles
};

enum enAtrMode
{
   atr_Rng,   // Calculate using range
   atr_Atr    // Calculate using ATR
};

input int                MAPeriod        = 10;             // Moving average period
input enMaModes          MAMethod        = ma_Simple;      // Moving average type
input enMaVisble         MAVisible       = mv_Visible;     // Midlle line visible ?
input enPrices           Price           = pr_close;     // Moving average price 
input color              MaColorUp       = clrDeepSkyBlue; // Color for slope up
input color              MaColorDown     = clrPaleVioletRed; // Color for slope down
input int                AtrPeriod       = 10;             // Range period
input double             AtrMultiplier   = 2.0;            // Range multiplier
input enAtrMode          AtrMode         = atr_Rng;        // Range calculating mode 
input enCandleMode       ViewBars        = cm_None;        // View bars as :
input bool               Interpolate     = true;           // Interpolate mtf data

input  group             "EMA"
input int EMAPeriod = 17;


input  group             "D. DAY TRADE"
sinput bool              inDayTrade = true;               // D.01 Operacao apenas como day trade
input int                inStartHour = 9;                 // D.02 Hora inicio negociacao
input int                inStartWaitMin = 0;              // D.03 Minutos a aguardar antes de iniciar operacoes
input int                inStopHour = 17;                 // D.04 Hora final negociacao
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
input double stopLoss = 1.1;

input  group             "Extras"
input double maxDailyLoss = 0;
input double maxDailyProfit = 0;
input int timeToSleep = 0;

int last_signal =  NOTRADE;

static int bandsHandle;
double meanVal[];      // Array dinamico para armazenar valores medios da banda de Bollinger
double upperVal[];     // Array dinamico para armazenar valores medios da banda superior
double lowerVal[];     // Array dinamico para armazenar valores medios da banda inferior

int EMAHighHandle = -1;
double EMAHighBuffer[];

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

   bandsHandle = iCustom(_Symbol,chartTimeframe,"keltner_channel315",chartTimeframe,MAPeriod,MAMethod,MAVisible,Price,MaColorUp,MaColorDown,AtrPeriod,AtrMultiplier,AtrMode,ViewBars,Interpolate);
   if (bandsHandle < 0) {
      Print("Erro criando indicadores bandsHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(bandsHandle);
   ArraySetAsSeries(meanVal, true);
   ArraySetAsSeries(upperVal, true);
   ArraySetAsSeries(lowerVal, true);

   EMAHighHandle = iMA(_Symbol,chartTimeframe,EMAPeriod,0, MODE_EMA , PRICE_CLOSE);
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
   
   onGoingTrade = checkPostionTypeOpen();
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
   MqlDateTime now;
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
   
   if (CopyBuffer(bandsHandle, 0, 0, 3, meanVal) < 0)   {
      Print("Erro copiando buffer do indicador iBands - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(bandsHandle, 2, 0, 3, upperVal) < 0)   {
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

   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (priceData[1].close < lowerVal[1] &&
          priceData[0].close > lowerVal[0]) {
            signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG && (priceData[1].close > upperVal[1])) {
         signal_exit = SHORT;
         tradeArmed = false;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* if (priceData[1].close > upperVal[1]) {
            signal = SHORT;
      }
      if (onGoingTrade == SHORT && (priceData[1].close < EMAHighBuffer[1])) {
         signal_exit = LONG;
         tradeArmed = false;
      }*/
   }
   
   if (totalTrades >=1 ) {
      signal = NOTRADE;
   }
   
   onGoingTrade = checkPostionTypeOpen();
   if (onGoingTrade == NOTRADE  && (signal == NOTRADE || (last_signal == LONG && signal == SHORT) || (last_signal == SHORT && signal == LONG)) ) {
      tradeArmed = false;
   }
   
   /* Time not to trade */
   hourMinuteNow = (now.hour * 60) + now.min;
   if ( hourMinuteNow < startTime || hourMinuteNow > stopTime) {
      signal =  NOTRADE;
      Profit = 0;
      totalTrades = 0;
      if (returnAllPositions() > 0 && inDayTrade == true) { // trade open and daytrade mode, stop all when end of the day
         printf("%s End of the day close all trades - Total trades %d", _Symbol, totalTrades);
         closeAllPositions();
         totalTrades = 0;
         onGoingTrade = NOTRADE;
      }
   }
   /*else {
      tradeOnCandle = false;
   }*/

   /* error from backtest */
   if (priceData[1].close == 0) {
      signal =  NOTRADE;
   }

   totalPosisions = returnAllPositions();
   Profit = closedProfitPeriod();

   if (maxDailyLoss > 0 && Profit < 0) {
      double auxProfit = Profit * -1;
      if (auxProfit > maxDailyLoss) {
         closeAllPositions();
         signal =  NOTRADE;
      }
   }
   if (maxDailyProfit > 0 && Profit >= maxDailyProfit) {
      closeAllPositions();
      signal =  NOTRADE;
   }

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " tradeArmed ",tradeArmed);

   TradeMann(signal, signal_exit);
}
