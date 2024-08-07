
//+------------------------------------------------------------------+
//| Functions by Invest Friends                                             |
//+------------------------------------------------------------------+
//#define WFO 1
#include<InvestFriends.mqh>

string EAName = StringSubstr(__FILE__,0,StringLen(__FILE__)-4);

input  group             "The Harry Potter"
input ulong MyMagicNumber = 1;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

/* your indicator start here */
input  group             "MA 200"
input int EMAPeriod = 200;
input ENUM_APPLIED_PRICE EMAPrice1 = PRICE_CLOSE;
int EMALowHandle = -1;
double EMALowBuffer[];

input  group             "Stocastich"
input int Kperiod = 5;
input int Dperiod = 3;
input int Slowing = 3;
input int StoUp = 80;
input int StoDown = 20;
int StoHandle = -1;
double K[];
double D[];

input  group             "RSI"
input int RSIPeriod = 2;
input int RSIUp = 75;
input int RSIDown = 30;
int RSIHandle = -1;
double RSI[];

input  group             "StopGain same candle"
input int PointsGain = 500;

int OnInit(void)
  {
  
   if (InitEA() == false) {
      return(INIT_FAILED);
   }
   
   startTime = (inStartHour * 60) + inStartWaitMin;
   stopTime = (inStopHour * 60) + inStopBeforeEndMin;
   
   /* Load EA Indicators */
   EMALowHandle = iMA(_Symbol,chartTimeframe,EMAPeriod,0,  MODE_EMA , EMAPrice1);
   if (EMALowHandle < 0) {
      Print("Erro criando indicador EMALowHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(EMALowHandle);
   ArraySetAsSeries(EMALowBuffer, true);
   
   StoHandle = iStochastic(_Symbol, chartTimeframe, Kperiod, Dperiod, Slowing, MODE_EMA,STO_CLOSECLOSE);
   if (StoHandle < 0) {
      Print("Erro criando indicador StoHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(StoHandle, 1);
   ArraySetAsSeries(K, true);
   ArraySetAsSeries(D, true);
   
   RSIHandle = iRSI(_Symbol, chartTimeframe, RSIPeriod, PRICE_CLOSE);
   if (RSIHandle < 0) {
      Print("Erro criando indicador RSIHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(RSIHandle, 2);
   ArraySetAsSeries(RSI, true);
      
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
   
   if (CopyBuffer(StoHandle, 0, 0, 3, K) < 0)   {
      Print("Erro copiando buffer do indicador EMALowHandle2 - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(StoHandle, 1, 0, 3, D) < 0)   {
      Print("Erro copiando buffer do indicador EMALowHandle2 - error:", GetLastError());
      ResetLastError();
      return;
   }

   if (CopyBuffer(RSIHandle, 0, 0, 3, RSI) < 0)   {
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
      TakeProfitPrice = NormalizeDouble((PositionPrice + PointsGain), _Digits);
      setTakeProfit(TakeProfitPrice);
      StopLossPrice = NormalizeDouble(PositionPrice - (priceData[1].high - priceData[1].low), _Digits);
      setStopLoss(StopLossPrice);
   }
   if (onGoingTrade == SHORT && TakeProfitPrice == EMPTY_VALUE) {
      TakeProfitPrice = NormalizeDouble((PositionPrice - PointsGain), _Digits);
      setTakeProfit(TakeProfitPrice);
      StopLossPrice = NormalizeDouble(PositionPrice + (priceData[1].high - priceData[1].low), _Digits);
      setStopLoss(StopLossPrice);
   }   
   if (onGoingTrade == NOTRADE) {
      TakeProfitPrice = EMPTY_VALUE;
      PositionProfit = 0;
   }
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (onGoingTrade == NOTRADE &&
          priceData[1].close > EMALowBuffer[1] &&
          priceData[0].close < priceData[0].low &&
          D[1] < StoDown &&
          RSI[1] < RSIDown ) {
            signal = LONG;
      }
      /* LONG exit */
      if (onGoingTrade == LONG && PositionCandlePosition > 1) {
         PositionProfit = PositionPrice + 100;
         if (priceData[0].close >= PositionProfit) {
            signal_exit = SHORT;
         }
      }
      
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (onGoingTrade == NOTRADE &&
          priceData[1].close < EMALowBuffer[1] &&
          priceData[0].close > priceData[1].high &&
          D[1] > StoUp &&
          RSI[1] > RSIUp ) {
            signal = SHORT;
      }
      /* SHORT exit */
      if (onGoingTrade == SHORT && PositionCandlePosition > 1) {
         PositionProfit = PositionPrice - 100;
         if (priceData[0].close <= PositionProfit) {
            signal_exit = LONG;
         }
      }

   }
   
   if(MQLInfoInteger(MQL_TESTER) == 1) {
      TradeMann(signal, signal_exit, priceData[0].close);
   }
   else {
      TradeMann(signal, signal_exit);
   }

   Comment("Magic number: ", MyMagicNumber, " - Total trades: ", totalTrades, " - signal ", signal, " signal_exit ", signal_exit, " onGoingTrade ",onGoingTrade);

}
