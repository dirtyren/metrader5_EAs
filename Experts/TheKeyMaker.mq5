
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = 5800;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "Keltner"

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

//
//
//
//
//

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

//
//
//
//
//

input ENUM_TIMEFRAMES    TimeFrame       = PERIOD_CURRENT; // Time frame
input int                MAPeriod        = 20;             // Moving average period
input enMaModes          MAMethod        = ma_Simple;      // Moving average type
input enMaVisble         MAVisible       = mv_Visible;     // Midlle line visible ?
input enPrices           Price           = pr_typical;     // Moving average price 
input color              MaColorUp       = clrDeepSkyBlue; // Color for slope up
input color              MaColorDown     = clrPaleVioletRed; // Color for slope down
input int                AtrPeriod       = 20;             // Range period
input double             AtrMultiplier   = 2.0;            // Range multiplier
input enAtrMode          AtrMode         = atr_Rng;        // Range calculating mode 
input enCandleMode       ViewBars        = cm_None;        // View bars as :
input bool               Interpolate     = true;           // Interpolate mtf data

int KeltmerHandle;
double Upper[];
double Middle[];
double Lower[];

int OnInit(void)
  {
   EAVersion = "v2.3";
   EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

   if (InitEA() == false) {
      return(INIT_FAILED);
   }

   KeltmerHandle = iCustom(_Symbol,chartTimeframe,"keltner_channel315", chartTimeframe, MAPeriod, MAMethod, MAVisible, Price, MaColorUp, MaColorDown, AtrPeriod, AtrMultiplier, AtrMode, ViewBars, Interpolate);
   if (KeltmerHandle < 0) {
      Print("Erro KeltmerHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(KeltmerHandle);
   ArraySetAsSeries(Upper, true);
   ArraySetAsSeries(Middle, true);
   ArraySetAsSeries(Lower, true);
   
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   //AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);

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
   
   /* if day changes, reset filters to not trade is one was openedd yesterday */
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
   
   if (CopyBuffer(ATRHandle, 0, 0, 5, ATRValue) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(KeltmerHandle, 2, 0, 3, Upper) < 0)   {
      Print("Erro copiando buffer do indicador HMAHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(KeltmerHandle, 1, 0, 5, Middle) < 0)   {
      Print("Erro copiando buffer do indicador HMAHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(KeltmerHandle, 3, 0, 3, Lower) < 0)   {
      Print("Erro copiando buffer do indicador HMAHandle - error:", GetLastError());
      ResetLastError();
      return;
   }

   /* Check if symbol needs to be changed */
   CheckAutoRollingSymbol();   

   onGoingTrade = checkPositionTypeOpen();
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[2].close < Lower[2] && priceData[1].close > Lower[1]) {
            signal = LONG;
         }
      }
      /* LONG exit */
      if (onGoingTrade == LONG && priceData[1].close > Upper[1]) {
         signal_exit = SHORT;
      }
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE) {
         if (priceData[2].close > Lower[2] && priceData[1].close < Lower[1]) {
            signal = SHORT;
         }
      }
      /* SHORT exit */
      /*if (onGoingTrade == SHORT && priceData[1].close > Upper[1]) {
         signal_exit = LONG;
      }*/
   }
   
   
   TradeMann(signal, signal_exit);

}
