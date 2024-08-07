
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 15000;
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
sinput bool              inDayTrade = true;               // D.01 Operacao apenas como day trade
input int                inStartHour = 9;                 // D.02 Hora inicio negociacao
input int                inStartWaitMin = 0;              // D.03 Minutos a aguardar antes de iniciar operacoes
input int                inStopHour = 17;                 // D.04 Hora final negociacao
input int                inStopBeforeEndMin = 44;         // D.05 Minutos antes do fim para encerrar posicoes

input  group             "Geldman!!"
input Geldmann_Type Geldmann_type = LOTS;
input double geldMann = 1;

input  group             "Trailing"
input AdjustBy AdjustByType = POINTS;
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
input  group             "Keltner Channel"
input ENUM_TIMEFRAMES    TimeFrame       = PERIOD_CURRENT; // Time frame
input int                MAPeriod        = 20;             // Moving average period
input enMaModes          MAMethod        = ma_Simple;      // Moving average type
input enMaVisble         MAVisible       = mv_Visible;     // Midlle line visible ?
input enPrices           Price           = pr_typical;     // Moving average price 
input color              MaColorUp       = clrDeepSkyBlue; // Color for slope up
input color              MaColorDown     = clrPaleVioletRed; // Color for slope down
input int                AtrPeriod       = 20;             // Range period
input double             AtrMultiplier   = 1.8;            // Range multiplier
input enAtrMode          AtrMode         = atr_Rng;        // Range calculating mode 
input enCandleMode       ViewBars        = cm_None;        // View bars as :
input bool               Interpolate     = true;           // Interpolate mtf data
int KeltnerHandle;
double KeltnerUP[];
double KeltnerDOWN[];
double KeltnerMiddle[];

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

   KeltnerHandle = iCustom(_Symbol,chartTimeframe,"keltner_channel315", TimeFrame, MAPeriod, MAMethod, MAVisible, Price, MaColorUp, MaColorDown, AtrPeriod, AtrMultiplier, AtrMode, ViewBars, Interpolate);
   if (KeltnerHandle < 0) {
      Print("Erro KeltnerHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(KeltnerHandle);
   ArraySetAsSeries(KeltnerUP, true);
   ArraySetAsSeries(KeltnerDOWN, true);
   ArraySetAsSeries(KeltnerMiddle, true);
  
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
      wfo_setCloseTradesOnSeparationLine(false); // false by default
     
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
   timeStampCurrentCandle = priceData[1].time;
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }

   if (CopyBuffer(ATRHandle, 0, 0, 3, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(KeltnerHandle, 2, 0, 3, KeltnerUP) < 0)   {
      Print("Erro copiando buffer do indicador KeltnerHandle 4 - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(KeltnerHandle, 3, 0, 3, KeltnerDOWN) < 0) {
      Print("Erro copiando buffer do indicador KeltnerHandle 5  - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(KeltnerHandle, 0, 0, 3, KeltnerMiddle) < 0) {
      Print("Erro copiando buffer do indicador KeltnerHandle 3 - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   onGoingTrade = checkPositionTypeOpen();
   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (priceData[1].close < KeltnerDOWN[1])  {
            signal = LONG;
      }
      if (onGoingTrade == LONG && priceData[1].close > KeltnerUP[1]) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (priceData[1].close > KeltnerUP[1])  {
            signal = SHORT;
      }
      if (onGoingTrade == SHORT && priceData[1].close < KeltnerDOWN[1]) {
         signal_exit = LONG;
      }
   }
   
   TradeMann(signal, signal_exit);
   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
