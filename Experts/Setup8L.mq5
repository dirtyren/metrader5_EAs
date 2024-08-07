
//+------------------------------------------------------------------+
//| Functions by Invest Friends                                             |
//+------------------------------------------------------------------+
#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 20000;
enum ENUM_INPUT_YES_NO
  {
   INPUT_YES   =  1, // Yes
   INPUT_NO    =  0  // No
  };
input ENUM_INPUT_YES_NO TradeOnAlternativeSymbol = INPUT_NO;
input string inTradeOnSymbol = "---";

input  group             "Configuration"
input ENUM_TIMEFRAMES chartTimeframe = PERIOD_CURRENT; // Timeframe of the EA
input TRADE_DIRECTION TradeDirection = LONG_TRADE;     // Trade direction. Long, Short, Both
   
input  group             "D. DAY TRADE"
sinput bool              inDayTrade = true;        // Day trade - will close the trade at the end of the day
input int                inStartHour = 10;          // Hour it can start trading
input int                inStartWaitMin = 0;       // Minutes it can start trading
input int                inStopHour = 16;           // Hour to stop trading
input int                inStopBeforeEndMin = 28;    // Minutes to stop trading

input  group             "Geldman!!"      // how much to trade
input Geldmann_Type Geldmann_type = GELD;
input double geldMann = 10000;

input  group             "Auto adjust stops in"
input AdjustBy AdjustByType = PERCENTAGE;

input  group             "Break even after"
input double BreakEven = 0.0; // Breakevent stop when hit AdjustByType

input  group             "Trailing"
input double TrailingStart = 0.0; // Trailing starts set in AdjustByType
input double TrailingPriceAdjustBy = 2; // How much to adjust price

input  group             "Takeprofit and Stoploss set in AdjustByType"
input double takeProfit = 0;
input double stopLoss = 0;

input  group             "Extras"
input double maxDailyLoss = 0;
input double maxDailyProfit = 0;
input int timeToSleep = 0;
input int MaxTradesDaily = 0;

/* ATR indicator must exists if you want the use set stops by ATR */
input  group             "ATR"
input int ATRPeriod = 14;

/* your indicator start here */
input  group             "MA Low"
input int EMAPeriod = 8;
int EMALowHandle = -1;
double EMALowBuffer[];

input group "Exit price adjust in %"
input double ExitAdjust = 0.5;

int OnInit(void)
  {
  
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   startTime = (inStartHour * 60) + inStartWaitMin;
   stopTime = (inStopHour * 60) + inStopBeforeEndMin;
   
   /* Load EA Indicators */
   EMALowHandle = iMA(_Symbol,chartTimeframe,EMAPeriod,0,  MODE_SMA , PRICE_LOW);
   if (EMALowHandle < 0) {
      Print("Erro criando indicador EMALowHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMALowHandle);
   ArraySetAsSeries(EMALowBuffer, true);
   
   ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);

   #ifdef WFO
      wfo_setEstimationMethod(wfo_estimation, wfo_formula); // wfo_built_in_loose by default
      wfo_setPFmax(100); // DBL_MAX by default
      wfo_setCloseTradesOnSeparationLine(true); // false by default
     
      // this is the only required call in OnInit, all parameters come from the header
      int WFORockAndRoll = wfo_OnInit(wfo_windowSize, wfo_stepSize, wfo_stepOffset, wfo_customWindowSizeDays, wfo_customStepSizePercent);
   
      //wfo_setCustomPerformanceMeter(FUNCPTR_WFO_CUSTOM funcptr)
      //wfo_setCustomPerformanceMeter(customEstimator);
      return(WFORockAndRoll);
   #endif
   return(0);
}
  
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
   DeInitEA();
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

   /* Tick time for EA */
   TimeToStruct(TimeCurrent(),now);
   timeNow = TimeCurrent();
   
   /* Get price bars */
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

   int signal = NOTRADE;
   int signal_exit = NOTRADE;
   
   onGoingTrade = checkPositionTypeOpen();
   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
   }
   /* set takeprofit price */
   if (onGoingTrade == LONG && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = NormalizeDouble(PositionPrice * (1 + (ExitAdjust / 100)), _Digits);
   }

   TradeEntryPrice = priceData[0].close;
   double PriceBid = priceData[0].close;
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      if (AskPrice > 0) {
         TradeEntryPrice = AskPrice;
      }
      if (BidPrice > 0) {
         PriceBid = BidPrice;
      }

      /* LONG Signal */
      if (onGoingTrade == NOTRADE && priceData[1].close < EMALowBuffer[1] &&
          (TradeEntryPrice < priceData[1].low)) {
            signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG && 
                 (priceData[1].close > EMALowBuffer[1] || 
                    (TakeProfitPrice != EMPTY_VALUE && PriceBid > TakeProfitPrice)) &&
                     TradeCandlePosition >= 2) {
         signal_exit = SHORT;
      }
      
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
   }
   
   TradeMann(signal, signal_exit);

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade, " tradeArmed ",tradeArmed, " TradeEntryPrice ", TradeEntryPrice, " TakeProfitPrice ",TakeProfitPrice, " TradeCandlePosition ", TradeCandlePosition, " PositionDateTime ", PositionDateTime);

}
