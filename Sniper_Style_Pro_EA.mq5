//+------------------------------------------------------------------+
//|                                             Sniper_Style_Pro_EA.mq5
//|  MT5 Expert Advisor based on the supplied Sniper-Style Pro logic |
//|  EMA crossover + RSI + ATR targets                                |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Sniper-Style Pro EA: EMA crossover, RSI, ATR SL/TP1/TP2/TP3, MTF trend panel and historical TP/SL labels."

#include <Trade/Trade.mqh>

CTrade trade;

input group "SIGNAL ENGINE"
input int      InpFastEMA            = 9;
input int      InpSlowEMA            = 21;
input int      InpRSILength          = 14;
input double   InpBullishRSI         = 52.0;
input double   InpBearishRSI         = 48.0;
input bool     InpRequireEMAAlignment = true;

input group "RISK / TARGETS"
input int      InpATRLength          = 14;
input double   InpStopDistanceATR    = 3.0;
input double   InpTP1R               = 0.5;
input double   InpTP2R               = 1.0;
input double   InpTP3R               = 1.5;
input double   InpLots               = 0.01;
input bool     InpUsePartialTP       = false;
input double   InpTP1ClosePercent    = 33.0;
input double   InpTP2ClosePercent    = 33.0;

input group "MTF TREND PANEL"
input ENUM_TIMEFRAMES InpTrendTF1    = PERIOD_M5;
input ENUM_TIMEFRAMES InpTrendTF2    = PERIOD_M15;
input ENUM_TIMEFRAMES InpTrendTF3    = PERIOD_M30;
input ENUM_TIMEFRAMES InpTrendTF4    = PERIOD_H1;
input bool     InpShowMTFPanel       = true;

input group "VISUALS"
input bool     InpShowEntryLevels    = true;
input bool     InpShowSignalLabels   = true;
input bool     InpShowResultLabels   = true;
input int      InpMaxResultLabels    = 200;
input bool     InpShowStats          = true;
input bool     InpDrawPastResults    = true;

input group "EXECUTION"
input bool     InpEnableTrading      = true;
input bool     InpOnePositionOnly    = true;
input ulong    InpMagicNumber        = 26100301;
input int      InpDeviationPoints    = 30;
input bool     InpOnlyNewBar         = true;

int hFast=INVALID_HANDLE,hSlow=INVALID_HANDLE,hRSI=INVALID_HANDLE,hATR=INVALID_HANDLE;
int hFastTF1=INVALID_HANDLE,hSlowTF1=INVALID_HANDLE,hFastTF2=INVALID_HANDLE,hSlowTF2=INVALID_HANDLE;
int hFastTF3=INVALID_HANDLE,hSlowTF3=INVALID_HANDLE,hFastTF4=INVALID_HANDLE,hSlowTF4=INVALID_HANDLE;

datetime g_lastBarTime=0;
ulong g_ticket=0;
int g_dir=0;
double g_entry=0,g_sl=0,g_tp1=0,g_tp2=0,g_tp3=0;
bool g_tp1Hit=false,g_tp2Hit=false;
int g_wins=0,g_losses=0;
string PREFIX="SNIPER_EA_";

double NormalizePrice(const double p){ return NormalizeDouble(p,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)); }

double NormalizeVolume(double v)
{
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st<=0) st=mn;
   v=MathMax(mn,MathMin(mx,v));
   v=MathFloor(v/st+1e-8)*st;
   if(v<mn) v=mn;
   return NormalizeDouble(v,2);
}

bool GetBufferValue(const int h,const int shift,double &v)
{
   double a[1];
   if(h==INVALID_HANDLE || CopyBuffer(h,0,shift,1,a)!=1) return false;
   v=a[0]; return true;
}

bool IsNewBar()
{
   datetime t=iTime(_Symbol,_Period,0);
   if(t==0) return false;
   if(g_lastBarTime==0){g_lastBarTime=t;return true;}
   if(t!=g_lastBarTime){g_lastBarTime=t;return true;}
   return false;
}

bool IsOurPosition()
{
   if(!PositionSelect(_Symbol)) return false;
   return (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber;
}

bool GetOurPosition(int &dir,double &vol,ulong &ticket)
{
   if(!IsOurPosition()) return false;
   dir=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : -1;
   vol=PositionGetDouble(POSITION_VOLUME);
   ticket=(ulong)PositionGetInteger(POSITION_TICKET);
   return true;
}

void DeleteObjectSafe(const string n){ if(ObjectFind(0,n)>=0) ObjectDelete(0,n); }

void DrawHLine(const string n,const double p,const color c,const ENUM_LINE_STYLE s=STYLE_DOT)
{
   DeleteObjectSafe(n);
   if(!ObjectCreate(0,n,OBJ_HLINE,0,0,p)) return;
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_STYLE,s);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,2);
}

void DrawTextAt(const string n,const datetime t,const double p,const string txt,const color c)
{
   DeleteObjectSafe(n);
   if(!ObjectCreate(0,n,OBJ_TEXT,0,t,p)) return;
   ObjectSetString(0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_LEFT);
}

void DrawTradeLevels()
{
   if(!InpShowEntryLevels) return;
   DrawHLine(PREFIX+"ENTRY",g_entry,clrSilver,STYLE_SOLID);
   DrawHLine(PREFIX+"SL",g_sl,clrCrimson);
   DrawHLine(PREFIX+"TP1",g_tp1,clrDeepSkyBlue);
   DrawHLine(PREFIX+"TP2",g_tp2,clrDeepSkyBlue);
   DrawHLine(PREFIX+"TP3",g_tp3,clrDeepSkyBlue);

   datetime t=iTime(_Symbol,_Period,0);
   DrawTextAt(PREFIX+"ENTRY_TXT",t,g_entry,(g_dir==1?"BUY: ":"SELL: ")+DoubleToString(g_entry,_Digits),g_dir==1?clrLimeGreen:clrCrimson);
   DrawTextAt(PREFIX+"SL_TXT",t,g_sl,"SL: "+DoubleToString(g_sl,_Digits),clrCrimson);
   DrawTextAt(PREFIX+"TP1_TXT",t,g_tp1,"TP1: "+DoubleToString(g_tp1,_Digits),clrDeepSkyBlue);
   DrawTextAt(PREFIX+"TP2_TXT",t,g_tp2,"TP2: "+DoubleToString(g_tp2,_Digits),clrDeepSkyBlue);
   DrawTextAt(PREFIX+"TP3_TXT",t,g_tp3,"TP3: "+DoubleToString(g_tp3,_Digits),clrDeepSkyBlue);
}

void DeleteActiveLevelObjects()
{
   string a[]={"ENTRY","SL","TP1","TP2","TP3","ENTRY_TXT","SL_TXT","TP1_TXT","TP2_TXT","TP3_TXT"};
   for(int i=0;i<ArraySize(a);i++) DeleteObjectSafe(PREFIX+a[i]);
}

void DrawSignalLabel(const bool buy,const datetime t,const double p)
{
   if(!InpShowSignalLabels) return;
   DrawTextAt(PREFIX+"SIGNAL_"+IntegerToString((long)t)+"_"+(buy?"BUY":"SELL"),t,p,buy?"BUY":"SELL",buy?clrLimeGreen:clrCrimson);
}

void DrawResultLabel(const bool win,const int dir,const datetime t,const double p)
{
   if(!InpShowResultLabels) return;
   string d=dir==1?"BUY":"SELL";
   DrawTextAt(PREFIX+"RESULT_"+IntegerToString((long)t)+"_"+d+"_"+(win?"TP":"SL"),t,p,d+" • "+(win?"TP3 HIT":"SL HIT"),win?clrLimeGreen:clrCrimson);
}

void DrawTPHitLabel(const int n,const int dir,const datetime t,const double p)
{
   if(!InpShowResultLabels) return;
   string d=dir==1?"BUY":"SELL";
   DrawTextAt(PREFIX+"TP"+IntegerToString(n)+"_"+IntegerToString((long)t)+"_"+d,t,p,d+" • TP"+IntegerToString(n)+" HIT",clrDeepSkyBlue);
}

bool GetTrend(const int hf,const int hs)
{
   double f,s;
   if(!GetBufferValue(hf,1,f)||!GetBufferValue(hs,1,s)) return false;
   return f>s;
}

void UpdatePanel()
{
   if(!InpShowMTFPanel){Comment("");return;}
   bool b1=GetTrend(hFastTF1,hSlowTF1),b2=GetTrend(hFastTF2,hSlowTF2);
   bool b3=GetTrend(hFastTF3,hSlowTF3),b4=GetTrend(hFastTF4,hSlowTF4);

   string p="SNIPER-STYLE PRO EA\n";
   p+="TF1 "+EnumToString(InpTrendTF1)+": "+(b1?"Bullish":"Bearish")+"\n";
   p+="TF2 "+EnumToString(InpTrendTF2)+": "+(b2?"Bullish":"Bearish")+"\n";
   p+="TF3 "+EnumToString(InpTrendTF3)+": "+(b3?"Bullish":"Bearish")+"\n";
   p+="TF4 "+EnumToString(InpTrendTF4)+": "+(b4?"Bullish":"Bearish")+"\n";
   p+="Wins: "+IntegerToString(g_wins)+"   Losses: "+IntegerToString(g_losses);
   if(g_dir!=0)
      p+="\nActive: "+(g_dir==1?"BUY":"SELL")+" | Entry "+DoubleToString(g_entry,_Digits)+
        "\nSL "+DoubleToString(g_sl,_Digits)+" | TP1 "+DoubleToString(g_tp1,_Digits)+
        " | TP2 "+DoubleToString(g_tp2,_Digits)+" | TP3 "+DoubleToString(g_tp3,_Digits);
   Comment(p);
}

void ResetState()
{
   g_ticket=0;g_dir=0;g_entry=g_sl=g_tp1=g_tp2=g_tp3=0;g_tp1Hit=g_tp2Hit=false;
}

void LoadStateFromPosition()
{
   int d;double v;ulong t;
   if(!GetOurPosition(d,v,t)){ResetState();return;}
   g_ticket=t;g_dir=d;g_entry=PositionGetDouble(POSITION_PRICE_OPEN);g_sl=PositionGetDouble(POSITION_SL);
   double r=MathAbs(g_entry-g_sl);
   g_tp1=d==1?g_entry+r*InpTP1R:g_entry-r*InpTP1R;
   g_tp2=d==1?g_entry+r*InpTP2R:g_entry-r*InpTP2R;
   g_tp3=d==1?g_entry+r*InpTP3R:g_entry-r*InpTP3R;
}

bool ClosePartial(const double percent)
{
   if(!IsOurPosition()) return false;
   double cur=PositionGetDouble(POSITION_VOLUME);
   double minv=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double cv=NormalizeVolume(cur*percent/100.0);
   if(cv<minv) return false;
   if(cv>=cur) return trade.PositionClose(_Symbol);
   return trade.PositionClosePartial(_Symbol,cv,InpDeviationPoints);
}

void ManageActiveTrade()
{
   if(!IsOurPosition())
   {
      if(g_dir!=0) ResetState();
      return;
   }
   LoadStateFromPosition();

   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double px=g_dir==1?bid:ask;

   if(!g_tp1Hit && ((g_dir==1&&px>=g_tp1)||(g_dir==-1&&px<=g_tp1)))
   {
      g_tp1Hit=true; DrawTPHitLabel(1,g_dir,TimeCurrent(),g_tp1);
      if(InpUsePartialTP) ClosePartial(InpTP1ClosePercent);
   }
   if(!g_tp2Hit && ((g_dir==1&&px>=g_tp2)||(g_dir==-1&&px<=g_tp2)))
   {
      g_tp2Hit=true; DrawTPHitLabel(2,g_dir,TimeCurrent(),g_tp2);
      if(InpUsePartialTP) ClosePartial(InpTP2ClosePercent);
   }
}

bool GetSignal(bool &buy,bool &sell,double &atr)
{
   buy=false;sell=false;atr=0;
   double f1,f2,s1,s2,r;
   if(!GetBufferValue(hFast,1,f1)||!GetBufferValue(hFast,2,f2)||
      !GetBufferValue(hSlow,1,s1)||!GetBufferValue(hSlow,2,s2)||
      !GetBufferValue(hRSI,1,r)||!GetBufferValue(hATR,1,atr)) return false;

   bool bull=f1>s1,bear=f1<s1;
   buy=(f2<=s2&&f1>s1&&r>=InpBullishRSI&&(!InpRequireEMAAlignment||bull));
   sell=(f2>=s2&&f1<s1&&r<=InpBearishRSI&&(!InpRequireEMAAlignment||bear));
   return true;
}

bool OpenTrade(const bool buy,const double atr)
{
   if(!InpEnableTrading|| (InpOnePositionOnly&&IsOurPosition())) return false;

   double vol=NormalizeVolume(InpLots);
   if(vol<=0) return false;

   double price=buy?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double risk=atr*InpStopDistanceATR;
   if(risk<=0) return false;

   double sl=buy?price-risk:price+risk;
   double tp3=buy?price+risk*InpTP3R:price-risk*InpTP3R;
   double minDist=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;

   if(buy){if(price-sl<minDist)sl=price-minDist;if(tp3-price<minDist)tp3=price+minDist;}
   else{if(sl-price<minDist)sl=price+minDist;if(price-tp3<minDist)tp3=price-minDist;}

   sl=NormalizePrice(sl);tp3=NormalizePrice(tp3);
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   bool ok=buy?trade.Buy(vol,_Symbol,0,sl,tp3,"Sniper BUY"):trade.Sell(vol,_Symbol,0,sl,tp3,"Sniper SELL");
   if(!ok){Print("Order failed: ",trade.ResultRetcode()," ",trade.ResultRetcodeDescription());return false;}

   Sleep(50);
   LoadStateFromPosition();
   if(g_dir!=0){DrawTradeLevels();DrawSignalLabel(buy,TimeCurrent(),g_entry);}
   return true;
}

void CountHistoryResults()
{
   g_wins=0;g_losses=0;
   if(!HistorySelect(TimeCurrent()-365*24*60*60,TimeCurrent())) return;
   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
   {
      ulong d=HistoryDealGetTicket(i);if(!d)continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol)continue;
      if((ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagicNumber)continue;
      long e=HistoryDealGetInteger(d,DEAL_ENTRY);if(e!=DEAL_ENTRY_OUT&&e!=DEAL_ENTRY_OUT_BY)continue;
      long r=HistoryDealGetInteger(d,DEAL_REASON);
      if(r==DEAL_REASON_TP)g_wins++;else if(r==DEAL_REASON_SL)g_losses++;
   }
}

void DrawPastTradeResults()
{
   if(!InpDrawPastResults||!InpShowResultLabels)return;
   if(!HistorySelect(TimeCurrent()-365*24*60*60,TimeCurrent()))return;

   int total=HistoryDealsTotal(),drawn=0;
   for(int i=0;i<total&&drawn<InpMaxResultLabels;i++)
   {
      ulong d=HistoryDealGetTicket(i);if(!d)continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol)continue;
      if((ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagicNumber)continue;
      long e=HistoryDealGetInteger(d,DEAL_ENTRY);if(e!=DEAL_ENTRY_OUT&&e!=DEAL_ENTRY_OUT_BY)continue;
      long r=HistoryDealGetInteger(d,DEAL_REASON);
      if(r!=DEAL_REASON_TP&&r!=DEAL_REASON_SL)continue;

      datetime t=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
      double p=HistoryDealGetDouble(d,DEAL_PRICE);
      long type=HistoryDealGetInteger(d,DEAL_TYPE);
      int dir=(type==DEAL_TYPE_SELL?1:-1);
      DrawResultLabel(r==DEAL_REASON_TP,dir,t,p);drawn++;
   }
}

int OnInit()
{
   hFast=iMA(_Symbol,_Period,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);
   hSlow=iMA(_Symbol,_Period,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   hRSI=iRSI(_Symbol,_Period,InpRSILength,PRICE_CLOSE);
   hATR=iATR(_Symbol,_Period,InpATRLength);

   if(hFast==INVALID_HANDLE||hSlow==INVALID_HANDLE||hRSI==INVALID_HANDLE||hATR==INVALID_HANDLE)return INIT_FAILED;

   hFastTF1=iMA(_Symbol,InpTrendTF1,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);hSlowTF1=iMA(_Symbol,InpTrendTF1,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   hFastTF2=iMA(_Symbol,InpTrendTF2,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);hSlowTF2=iMA(_Symbol,InpTrendTF2,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   hFastTF3=iMA(_Symbol,InpTrendTF3,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);hSlowTF3=iMA(_Symbol,InpTrendTF3,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);
   hFastTF4=iMA(_Symbol,InpTrendTF4,InpFastEMA,0,MODE_EMA,PRICE_CLOSE);hSlowTF4=iMA(_Symbol,InpTrendTF4,InpSlowEMA,0,MODE_EMA,PRICE_CLOSE);

   trade.SetExpertMagicNumber(InpMagicNumber);trade.SetDeviationInPoints(InpDeviationPoints);trade.SetTypeFillingBySymbol(_Symbol);

   CountHistoryResults();DrawPastTradeResults();LoadStateFromPosition();
   g_lastBarTime=iTime(_Symbol,_Period,0);UpdatePanel();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Comment("");
   int hs[]={hFast,hSlow,hRSI,hATR,hFastTF1,hSlowTF1,hFastTF2,hSlowTF2,hFastTF3,hSlowTF3,hFastTF4,hSlowTF4};
   for(int i=0;i<ArraySize(hs);i++)if(hs[i]!=INVALID_HANDLE)IndicatorRelease(hs[i]);
}

void OnTick()
{
   ManageActiveTrade();
   bool evaluate=!InpOnlyNewBar||IsNewBar();

   if(evaluate)
   {
      bool buy=false,sell=false;double atr=0;
      if(GetSignal(buy,sell,atr)&&(buy||sell)&&!IsOurPosition())
         OpenTrade(buy,atr);
   }
   UpdatePanel();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD)return;
   ulong d=trans.deal;if(!d||!HistoryDealSelect(d))return;
   if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol)return;
   if((ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagicNumber)return;

   long e=HistoryDealGetInteger(d,DEAL_ENTRY);
   if(e!=DEAL_ENTRY_OUT&&e!=DEAL_ENTRY_OUT_BY)return;

   long r=HistoryDealGetInteger(d,DEAL_REASON);
   if(r!=DEAL_REASON_TP&&r!=DEAL_REASON_SL)return;

   bool win=(r==DEAL_REASON_TP);
   long type=HistoryDealGetInteger(d,DEAL_TYPE);
   int dir=(type==DEAL_TYPE_SELL?1:-1);
   datetime t=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
   double p=HistoryDealGetDouble(d,DEAL_PRICE);

   if(win)g_wins++;else g_losses++;
   DrawResultLabel(win,dir,t,p);
   ResetState();UpdatePanel();
}
