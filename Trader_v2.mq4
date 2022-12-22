//+------------------------------------------------------------------+
//|                                                    Trader_v2.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

extern bool ReverseMode=false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {        
   if(!FileIsExist("\\"+IntegerToString(AccountNumber())))
   {
      string folder= IntegerToString(AccountNumber());
      FolderCreate(folder,FILE_COMMON);
   }
  
//--- create timer
   EventSetTimer(1);
   //InitTrader();
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
      
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
      
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
      Trader();
  }
//+------------------------------------------------------------------+
void InitTrader()
{
   while(true)
   {
      Trader();
   }
}

void Trader()
{
   int total = OrdersTotal();
   
   for(int pos = 0;pos<total;pos++)
   {
      if(OrderSelect(pos, SELECT_BY_POS, MODE_TRADES))
      {
         int orderTypeToCopy = OrderType();
         if(ReverseMode){
            if(orderTypeToCopy == OP_BUY){
               orderTypeToCopy = OP_SELL;
            }
            else if(orderTypeToCopy == OP_SELL){
               orderTypeToCopy = OP_BUY;
            }
         }
      
         string orderFileName=GetOrderFileName(AccountNumber(), OrderSymbol(), orderTypeToCopy, OrderLots(), OrderTicket(), OrderOpenPrice());
         
          if(!FileIsExist(orderFileName, FILE_COMMON))
          {         
            int handle=FileOpen(orderFileName,FILE_WRITE|FILE_CSV|FILE_COMMON,"\t");
            FileWrite(handle,"test");
            FileClose(handle);   
            
            Print("Order file created: "+orderFileName);
          }
      }
   }
   
   string fileName="";
   string fileFilter = StringConcatenate(IntegerToString(AccountNumber()),"//*.csv");   

   long searchHandle=FileFindFirst(fileFilter,fileName, FILE_COMMON);
   string sep="_";
   ushort uSep; 
   uSep=StringGetCharacter(sep,0);

   if(searchHandle!=INVALID_HANDLE)
   {
      do
      {
         ResetLastError();
         FileIsExist(fileName, FILE_COMMON);
         if(GetLastError()!=5018)//Directory
         {
            string result[];
            int k=StringSplit(fileName,uSep,result);
            //Print(StringConcatenate(fileName,"=","[",result[0],"], ","[",result[1],"], ","[",result[2],"], ","[",result[3],"]"));
            string orderSymbol = result[0];
            int orderType=GetOrderType(result[1]);
            double orderLots=StrToDouble(result[2]);
            int orderTicket=StrToInteger(result[3]);
            double openPrice=StrToDouble(result[4]);
            
            if(!CheckPositionOpened(orderTicket))
            {
               string orderFileName=GetOrderFileName(AccountNumber(),orderSymbol,orderType,orderLots,orderTicket,openPrice);      
               if(FileDelete(orderFileName, FILE_COMMON))
               {
                  Print("Order file deleted: "+orderFileName);                  
               }
               else
               {
                  Print("Error deleting file "+orderFileName+" "+IntegerToString(GetLastError()));
               }
            }
         }
      }while(FileFindNext(searchHandle, fileName));
      
      FileFindClose(searchHandle);
   }
}

bool CheckPositionOpened(int orderTicket)
{   
   int total = OrdersTotal();
   
   for(int pos = 0;pos<total;pos++)
   {
      if(OrderSelect(pos, SELECT_BY_POS, MODE_TRADES))
      {
          if(OrderTicket()==orderTicket)
          {
            return true;
          }
      }
   }
   
   return false;
}

string GetOrderFileName(int accountNumber, string orderSymbol, int orderType, double orderLots, int orderTicket, double openPrice)
{
   string fileName = 
      StringConcatenate(IntegerToString(accountNumber), "\\"
         , orderSymbol
         ,"_", GetOrderTypeName(orderType)
         ,"_", DoubleToString(orderLots, 2)
         ,"_",IntegerToString(orderTicket)
         ,"_",DoubleToStr(openPrice, 5)
         ,".csv");
      
   return fileName;
}

int GetOrderType(string orderTypeStr){
   int orderType = -1;
   
   if(orderTypeStr == "B"){
      orderType = OP_BUY;
   }
   else if(orderTypeStr == "S"){
      orderType = OP_SELL;
   }
   
   return orderType;
}

string GetOrderTypeName(int orderType){
   string orderTypeName = "";
   
   if(orderType == OP_BUY){
      orderTypeName = "B";
   }
   else if(orderType == OP_SELL){
      orderTypeName = "S";
   }
   
   return orderTypeName;
}
