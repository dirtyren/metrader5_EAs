
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = 7000;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

input  group             "MACD"

enum colorswitch                                         // use single or multi-color display of Histogram
  {
   MultiColor=0,
   SingleColor=1
  };


//--- input parameters
input int                  InpFastEMA=12;                // Fast EMA period
input int                  InpSlowEMA=26;                // Slow EMA period
input int                  InpSignalMA=9;                // Signal MA period
input ENUM_MA_METHOD       InpAppliedSignalMA=MODE_SMA;  // Applied MA method for signal line
input colorswitch          InpUseMultiColor=MultiColor;  // Use multi-color or single-color histogram
input ENUM_APPLIED_PRICE   InpAppliedPrice=PRICE_CLOSE;  // Applied price

int MACDHandle;
double MMain[];
double MSignal[];

input  group             "Stop ATR"

//--- input parameters
input uint     InpPeriod   =  5;   // Period
input double   InpCoeff    =  1.0;  // Coefficient

int StopATRHandle;
double StopUP[];
double StopDown[];

int OnInit(void)
  {
   if (InitEA() == false) {
      return(INIT_FAILED);
   }

   MACDHandle = iCustom(_Symbol,chartTimeframe,"macd_histogram_mc", InpFastEMA, InpSlowEMA, InpSignalMA, InpAppliedSignalMA, InpUseMultiColor, InpAppliedPrice);
   if (MACDHandle < 0) {
      Print("Erro MACDHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(MACDHandle, 1);
   ArraySetAsSeries(MMain, true);
   ArraySetAsSeries(MSignal, true);
   
   StopATRHandle = iCustom(_Symbol,chartTimeframe,"Mod ATR Trailing Stop MT5 Indicator", InpPeriod, InpCoeff);
   if (StopATRHandle < 0) {
      Print("Erro StopATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(StopATRHandle);
   ArraySetAsSeries(StopDown, true);
   ArraySetAsSeries(StopUP, true);   
   
   /*ATRHandle = iATR(_Symbol, chartTimeframe, ATRPeriod);
   if (ATRHandle < 0) {
      Print("Erro ATRHandle - error: ", GetLastError(), "!");
      return(INIT_FAILED);
   }
   AddIndicator(ATRHandle, 4);
   ArraySetAsSeries(ATRValue, true);*/

   return(INIT_SUCCEEDED);
  }
  
/* double OnTester()
{
   return optpr();         // optimization parameter
}
*/

double OnTester()
{
   if (TrailingStart > 0 && TrailingStart <= TrailingPriceAdjustBy) {
      return 0.0;
   }
  
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

   /* if day changes, reset filters to not trade is one was openedd yesterday */
   checkDayHasChanged();
     
   /* Tick time for EA */
   TimeToStruct(TimeCurrent(),now);
   timeNow = TimeCurrent();
   
   CopyRates(_Symbol, chartTimeframe, 0, 30, priceData);

   /* Time current candle */   
   timeStampCurrentCandle = priceData[0].time;
   if (tradeOnCandle == true && timeLastTrade != timeStampCurrentCandle) {
      tradeOnCandle = false;
   }
   
   if (CopyBuffer(MACDHandle, 0, 0, 3, MMain) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   if (CopyBuffer(MACDHandle, 1, 0, 3, MSignal) < 0)   {
      Print("Erro copiando buffer do indicador ATRHandle - error:", GetLastError());
      ResetLastError();
      return;
   }   

   if (CopyBuffer(StopATRHandle, 0, 0, 3, StopUP) < 0) {
      Print("Erro copiando buffer do indicador VolatilityHandle - error:", GetLastError());
      ResetLastError();
      return;
   }   
   if (CopyBuffer(StopATRHandle, 1, 0, 3, StopDown) < 0) {
      Print("Erro copiando buffer do indicador VolatilityHandle - error:", GetLastError());
      ResetLastError();
      return;
   }
   
   int signal =  NOTRADE;
   int signal_exit =  NOTRADE;
   
   if (TradeDirection == LONG_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* LONG Signal */
      if (MMain[1] > MSignal[1]) {
         if (StopDown[1] != EMPTY_VALUE && StopDown[2] == EMPTY_VALUE) {
            signal = LONG;
         }
      }
      if (MMain[1] > MSignal[1] && MMain[2] < MSignal[2]) {
         if (StopDown[1] != EMPTY_VALUE) {
            signal = LONG;
         }
      }      
      if (onGoingTrade == LONG) {
         if (StopDown[1] == EMPTY_VALUE) {
            signal_exit = SHORT;
         }
      }
      
      /*if (onGoingTrade == LONG && MaxPyramidTrades > 0 &&
          totalPosisions <= MaxPyramidTrades &&
          HeikenDirection[2] == 0 && HeikenDirection[1] == 0) {
          
          if (UseRiskToPyramid == true) {
            if (priceData[2].close < priceData[1].close) {
               TradeNewMann(LONG);
            }
          }
          else {
            TradeNewMann(LONG);
          }
      }*/
      
   }
   
   if (TradeDirection == SHORT_TRADE || TradeDirection == LONG_SHORT_TRADE) {
      /* SHORT Signal */
      if (MMain[1] < MSignal[1]) {
         if (StopUP[1] != EMPTY_VALUE && StopUP[2] == EMPTY_VALUE) {
            signal = SHORT;
         }
      }
      if (onGoingTrade == SHORT) {
         if (StopUP[1] == EMPTY_VALUE) {
            signal_exit = LONG;
         }
      }      
      
      /*if (onGoingTrade == SHORT && MaxPyramidTrades > 0 &&
          totalPosisions <= MaxPyramidTrades &&
          HeikenDirection[2] == 1 && HeikenDirection[1] == 1) {
          
          if (UseRiskToPyramid == true) {
            if (priceData[2].close > priceData[1].close) {
               TradeNewMann(SHORT);
            }
          }
          else {
            TradeNewMann(SHORT);
          }
      }*/
   }
   

   TradeMann(signal, signal_exit);
  
}
