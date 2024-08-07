
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
#include<InvestFriends.mqh>

input  group             "The Harry Potter"
input ulong MyMagicNumber = 123;

/* Global parameters for all EAs */
#include<InvestFriends-parameters.mqh>

int OnInit(void)
  {
   
   TradeOnSymbol = _Symbol;

   cleanUPIndicators();
   trade.SetExpertMagicNumber(MyMagicNumber);
   
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

   datetime server_time=TimeTradeServer();
   datetime gmt_time=TimeGMT();
   
   int offset_in_seconds=(((int)server_time)-((int)gmt_time)) / 60 / 60;
   
   Print("Server time ", server_time);
   Print("GMT time ", gmt_time);
   Print("Server skew to GMT ", offset_in_seconds);


   ExpertRemove();
}
