//+------------------------------------------------------------------+
//|                                                    Copier_v2.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "2.01"
#property strict

extern string Accounts="1111^1.0_2222_3333^0.1_4444^2.0";
extern int MagicNumber = 777;
extern int MaxTakeProfit=0;
extern int MaxStopLoss=0;
extern bool ReverseMode = false;

int AccountNumbers[];
double AccountLotCoefficients[];

double orderTp=0, orderSl=0;

string metatraderMessagesFileName = "";
int messagesHandle;
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
      
      metatraderMessagesFileName = IntegerToString(AccountNumber()) + "\\metatrader_messages.txt";  
  
      string accountSeparator = "_";
      ushort uAccountSeparator = StringGetCharacter(accountSeparator, 0);
      
      string accountSettingsSeparator = "^";
      ushort uAccountSettingsSeparator = StringGetCharacter(accountSettingsSeparator, 0);
      
      string accountResults[];
      
      int accountsCount = StringSplit(Accounts, uAccountSeparator, accountResults);
      
      if(accountsCount > 0)
      {
         ArrayResize(AccountNumbers, accountsCount);
         ArrayResize(AccountLotCoefficients, accountsCount);
         
         for(int i=0; i < accountsCount; i++)
         {
            string accountSettingsResults[];
            int accountsSettingsCount = StringSplit(accountResults[i], uAccountSettingsSeparator, accountSettingsResults);
            
            AccountNumbers[i] = StrToInteger(accountSettingsResults[0]);
            if(accountsSettingsCount > 1)
            {
               AccountLotCoefficients[i] = StrToDouble(accountSettingsResults[1]);
            }
            else
            {
               AccountLotCoefficients[i] = 1.0;
            }
         }  
      }
      
      double pp;
      int pd;
      
      if (Digits < 4) {
         pp = 0.01;
         pd = 2;
      } else {
         pp = 0.0001;
         pd = 4;
      }
      
      orderTp = NormalizeDouble (MaxTakeProfit * pp , pd);
      orderSl = NormalizeDouble (MaxStopLoss * pp , pd);
      
      
      DeleteCommentsFromChart();
      
//--- create timer   
   EventSetTimer(1);
      
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
      DeleteCommentsFromChart();
//--- destroy timer
   EventKillTimer();
      
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---      
      if(ArraySize(AccountNumbers)==0)
      {
         Alert("Looking into the clouds.");
      }
      ShowCommentsOnChart();
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---      
      Copier();
  }
//+------------------------------------------------------------------+
void InitCopier()
{
   while(true)
   {
      Copier();
   }
}

void Copier()
{
   OpenOrders();
   
   CloseOrders();     
}

void OpenOrders()
{
   string sep="_";
   ushort uSep; 
   uSep=StringGetCharacter(sep,0);
      
   for(int i=0;i<ArraySize(AccountNumbers);i++)
   {     
      string fileName="";
      string fileFilter = StringConcatenate(IntegerToString(AccountNumbers[i]),"//*.csv");   
      
      long searchHandle=FileFindFirst(fileFilter,fileName, FILE_COMMON);
            
      if(searchHandle!=INVALID_HANDLE)
      {
         do
         {
            ResetLastError();
            FileIsExist(fileName);
            if(GetLastError()!=5018)//Directory
            {
               if(StringFind(fileName, "_CLOSED") > -1)
               {
                  continue;
               }
            
               string result[];
               int k=StringSplit(fileName,uSep,result);
               //Print(StringConcatenate(fileName,"=","[",result[0],"], ","[",result[1],"], ","[",result[2],"], ","[",result[3],"]"));
               string orderSymbol = result[0];
               int orderType=GetOrderType(result[1]);
               double orderLots=NormalizeDouble(StrToDouble(result[2]) * AccountLotCoefficients[i], 2);
               int orderTicket=StrToInteger(result[3]);
               double openPrice=StrToDouble(result[4]);
               
               string symbol = Symbol();
               if(StringCompare(orderSymbol,symbol,true)!=0) continue;
               
               if(ReverseMode){
                  if(orderType == OP_BUY){
                     orderType = OP_SELL;
                  }
                  else if(orderType == OP_SELL){
                     orderType = OP_BUY;
                  }
               }
               
               string copierOrderComment=GetCopierOrderComment(AccountNumbers[i],orderTicket,orderType, openPrice);
               
               if(!CheckPositionOpened(copierOrderComment))
               {
                  int orderTypeToOpen = orderType;
                  
                  double tp = 0, sl = 0, copierOpenPrice = 0;
                  
                  RefreshRates();
                  if (orderTypeToOpen == OP_BUY)
                  {
                     copierOpenPrice = NormalizeDouble(Ask, Digits);
                     
                     if(orderTp > 0.0) tp = NormalizeDouble(openPrice + orderTp, Digits);
                     if(orderSl > 0.0) sl = NormalizeDouble(openPrice - orderSl, Digits);
                  }
                  else if(orderTypeToOpen == OP_SELL)
                  {
                     copierOpenPrice = NormalizeDouble(Bid, Digits);
                      
                     if(orderTp > 0.0) tp = NormalizeDouble(openPrice - orderTp, Digits);
                     if(orderSl > 0.0) sl = NormalizeDouble(openPrice + orderSl, Digits);
                  }
                  
                  Print("Symbol()="+Symbol()+", orderSymbol="+orderSymbol+", orderTypeToOpen="+IntegerToString(orderTypeToOpen)+
                     ", orderLots="+DoubleToStr(orderLots)+
                     ", openPrice="+DoubleToStr(openPrice)+
                     ", copierOpenPrice="+DoubleToStr(copierOpenPrice)+", sl="+DoubleToStr(sl)+", tp="+DoubleToStr(tp));
                  int ticket = OrderSend(orderSymbol,orderTypeToOpen,orderLots,copierOpenPrice,3,sl,tp,copierOrderComment,MagicNumber,0,Blue);
                  if(ticket>0)
                  {
                     Print("Order #"+IntegerToString(ticket)+" successfully opened ("+copierOrderComment+"). Current Bid: "+DoubleToStr(Bid)+", Ask: "+DoubleToStr(Ask));
                  }
                  else
                  {
                     int error = GetLastError();
                     WriteErrorMessage("ERROR_OPENING_ORDER", error);
                     Print("Error opening order: "+ErrorDescription(error));
                  }      
                  
               }
            }
         }while(FileFindNext(searchHandle, fileName));
         
         FileFindClose(searchHandle);
      }
   }
}

int GetOrderType(string orderTypeStr){
   int orderType = -1;
   
   if(orderTypeStr == "BUY"){
      orderType = OP_BUY;
   }
   else if(orderTypeStr == "SELL"){
      orderType = OP_SELL;
   }
   
   return orderType;
}

string GetOrderTypeName(int orderType){
   string orderTypeName = "";
   
   if(orderType == OP_BUY){
      orderTypeName = "BUY";
   }
   else if(orderType == OP_SELL){
      orderTypeName = "SELL";
   }
   
   return orderTypeName;
}

void CloseOrders()
{
   string sep="_";
   ushort uSep; 
   uSep=StringGetCharacter(sep,0);
   
   int total=OrdersTotal();
      
   for(int pos = 0;pos<total;pos++)
   {
      if(OrderSelect(pos, SELECT_BY_POS, MODE_TRADES))
      {
        bool foundFile = false;
        string orderComment=OrderComment();
        string result[];
        int k=StringSplit(orderComment,uSep,result);
        int account=StrToInteger(result[0]);
        int ticket=StrToInteger(result[1]);
        int orderType=GetOrderType(result[2]);
        double openPrice=StrToDouble(result[3]);

        if(ReverseMode){
            if(orderType == OP_BUY){
               orderType = OP_SELL;
            }
            else if(orderType == OP_SELL){
               orderType = OP_BUY;
            }
         }
         
         string orderFileName=GetOrderFileName(OrderSymbol(),orderType,OrderLots(),ticket,openPrice);
         
         string fileName="";
         string fileFilter = StringConcatenate(account,"//*.csv");
         long searchHandle=FileFindFirst(fileFilter,fileName, FILE_COMMON);
         
         if(searchHandle!=INVALID_HANDLE)
         {
            do
            {
               ResetLastError();
               FileIsExist(fileName, FILE_COMMON);
               if(GetLastError()!=5018)//Directory
               {
                  if(StringCompare(fileName, orderFileName, true)==0)
                  {
                     foundFile=true;
                     break;
                  }
               }
               
            }while(FileFindNext(searchHandle, fileName));
            
            FileFindClose(searchHandle);
         }
         
         if(!foundFile)
         {  
            double closePrice=0;
            RefreshRates();
            if (OrderType() == OP_SELL)
            {      
               closePrice = NormalizeDouble(Ask,Digits);
            }
            else if (OrderType() == OP_BUY)
            {
               closePrice = NormalizeDouble(Bid,Digits);
            }
            
            if(OrderClose(OrderTicket(),OrderLots(),closePrice,3,DeepPink))
            {   
               Print("Close order for: "+orderComment);
            }
            else
            {
               int error = GetLastError();
               WriteErrorMessage("ERROR_CLOSING_ORDER", error);
               Print("Error closing order for: "+orderComment+". "+ErrorDescription(error));
            }           
         }
      }
   }
}

string GetCopierOrderComment(int accountNumber,int orderTicket, int orderType, double openPrice)
{
   string orderComment=
      StringConcatenate(IntegerToString(accountNumber)
      ,"_",IntegerToString(orderTicket)
      ,"_",GetOrderTypeName(orderType)
      ,"_",DoubleToStr(openPrice,5));
   
   return orderComment;
}

bool CheckPositionOpened(string copierOrderComment)
{      
   int total = OrdersTotal();
   
   for(int pos = 0;pos<total;pos++)
   {
      if(OrderSelect(pos, SELECT_BY_POS, MODE_TRADES))
      {
          if(StringCompare(OrderComment(),copierOrderComment,true)== 0)
          {
            return true;
          }
      }
   }
   
   return false;
}

string GetOrderFileName(string orderSymbol, int orderType, double orderLots, int orderTicket, double openPrice)
{
   string fileName = 
      StringConcatenate(orderSymbol
      ,"_",GetOrderTypeName(orderType)
      ,"_", DoubleToString(orderLots, 2)
      ,"_",IntegerToString(orderTicket)
      ,"_",DoubleToStr(openPrice, 5)
      ,".csv");
      
   return fileName;
}

//+--------------------------------------------------------------------------------------------------------------+
//| Show comments on chart.
//|
//|
//|
//|
//|
//+--------------------------------------------------------------------------------------------------------------+

void DeleteCommentsFromChart()
{
   if (ObjectFind("BKGR") >= 0) ObjectDelete("BKGR");
   if (ObjectFind("BKGR2") >= 0) ObjectDelete("BKGR2");
   if (ObjectFind("BKGR3") >= 0) ObjectDelete("BKGR3");
   if (ObjectFind("LV") >= 0) ObjectDelete("LV");
}

void ShowCommentsOnChart()
{
   string ComSpacer = "";  
   int accountsCount = ArraySize(AccountNumbers);
   
   ComSpacer = ComSpacer
      + "\n " 
      + "\n "
      + "\n  MaxTakeProfit: " + IntegerToString(MaxTakeProfit)
      + "\n  MaxStopLoss: " + IntegerToString(MaxStopLoss)
      + "\n -----------------------------------------------"
      + "\n  Accounts count: " + IntegerToString (accountsCount)
      + "\n -----------------------------------------------";
   
   for(int accountIndex = 0; accountIndex < accountsCount; accountIndex++)
   {
      ComSpacer = ComSpacer
         + "\n  Account number: " + IntegerToString(AccountNumbers[accountIndex])
         + "\n  Lot coefficient: " + DoubleToString(AccountLotCoefficients[accountIndex], 2)
         + "\n ";
   }   

   ComSpacer = ComSpacer + "\n -----------------------------------------------";
   Comment(ComSpacer);
   
   if (ObjectFind("LV") < 0) {
      ObjectCreate("LV", OBJ_LABEL, 0, 0, 0);
      ObjectSetText("LV", "Copier_v2", 9, "Tahoma Bold", White);
      ObjectSet("LV", OBJPROP_CORNER, 0);
      ObjectSet("LV", OBJPROP_BACK, FALSE);
      ObjectSet("LV", OBJPROP_XDISTANCE, 13);
      ObjectSet("LV", OBJPROP_YDISTANCE, 23);
   }
   if (ObjectFind("BKGR") < 0) {
      ObjectCreate("BKGR", OBJ_LABEL, 0, 0, 0);
      ObjectSetText("BKGR", "g", 110, "Webdings", RoyalBlue);
      ObjectSet("BKGR", OBJPROP_CORNER, 0);
      ObjectSet("BKGR", OBJPROP_BACK, TRUE);
      ObjectSet("BKGR", OBJPROP_XDISTANCE, 5);
      ObjectSet("BKGR", OBJPROP_YDISTANCE, 15);
   }
   if (ObjectFind("BKGR2") < 0) {
      ObjectCreate("BKGR2", OBJ_LABEL, 0, 0, 0);
      ObjectSetText("BKGR2", "g", 110, "Webdings", SpringGreen);
      ObjectSet("BKGR2", OBJPROP_BACK, FALSE);
      ObjectSet("BKGR2", OBJPROP_XDISTANCE, 5);
      ObjectSet("BKGR2", OBJPROP_YDISTANCE, 45);
   }
   if (ObjectFind("BKGR3") < 0) {
      ObjectCreate("BKGR3", OBJ_LABEL, 0, 0, 0);
      ObjectSetText("BKGR3", "g", 110, "Webdings", SpringGreen);
      ObjectSet("BKGR3", OBJPROP_CORNER, 0);
      ObjectSet("BKGR3", OBJPROP_BACK, FALSE);
      ObjectSet("BKGR3", OBJPROP_XDISTANCE, 5);
      ObjectSet("BKGR3", OBJPROP_YDISTANCE, 180);
   }
}

void WriteErrorMessage(string errorType, int error){
   string jsonMessage = "{ \"Type\": \"METATRADER_ERROR\", \"ErrorType\": \"" + errorType + "\", \"ErrorCode\": " + IntegerToString(error) + ", \"ErrorDescription\": \"" + ErrorDescription(error) + "\" }";
   WriteMetatraderMessage(jsonMessage);
}

void WriteMetatraderMessage(string jsonMessage){
   messagesHandle=FileOpen(metatraderMessagesFileName, FILE_SHARE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON);
      
   if(messagesHandle != INVALID_HANDLE){
      Print(jsonMessage);
   
      FileSeek(messagesHandle,0,SEEK_END);
	   FileWrite(messagesHandle, "{ \"Time\": \"" + TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS) + "\", \"Message\": " + jsonMessage + "}");
	   FileFlush(messagesHandle);
	   FileClose(messagesHandle);
   }      
   else{
      Print("[Copier::WriteMetatraderMessage] error: ", ErrorDescription(GetLastError()));
   }
}

//+--------------------------------------------------------------------------------------------------------------+
//| ErrorDescription.
//+--------------------------------------------------------------------------------------------------------------+
string ErrorDescription(int error) {

   string ErrorNumber;
  
   switch (error) {
      case 0:	ErrorNumber = "No error returned. (ERR_NO_ERROR: 0)";	break;
      case 1:	ErrorNumber = "No error returned, but the result is unknown. (ERR_NO_RESULT: 1)";	break;
      case 2:	ErrorNumber = "Common error. (ERR_COMMON_ERROR: 2)";	break;
      case 3:	ErrorNumber = "Invalid trade parameters. (ERR_INVALID_TRADE_PARAMETERS: 3)";	break;
      case 4:	ErrorNumber = "Trade server is busy. (ERR_SERVER_BUSY: 4)";	break;
      case 5:	ErrorNumber = "Old version of the client terminal. (ERR_OLD_VERSION: 5)";	break;
      case 6:	ErrorNumber = "No connection with trade server. (ERR_NO_CONNECTION: 6)";	break;
      case 7:	ErrorNumber = "Not enough rights. (ERR_NOT_ENOUGH_RIGHTS: 7)";	break;
      case 8:	ErrorNumber = "Too frequent requests. (ERR_TOO_FREQUENT_REQUESTS: 8)";	break;
      case 9:	ErrorNumber = "Malfunctional trade operation. (ERR_MALFUNCTIONAL_TRADE: 9)";	break;
      case 64:	ErrorNumber = "Account disabled. (ERR_ACCOUNT_DISABLED: 64)";	break;
      case 65:	ErrorNumber = "Invalid account. (ERR_INVALID_ACCOUNT: 65)";	break;
      case 128:	ErrorNumber = "Trade timeout. (ERR_TRADE_TIMEOUT: 128)";	break;
      case 129:	ErrorNumber = "Invalid price. (ERR_INVALID_PRICE: 129)";	break;
      case 130:	ErrorNumber = "Invalid stops. (ERR_INVALID_STOPS: 130)";	break;
      case 131:	ErrorNumber = "Invalid trade volume. (ERR_INVALID_TRADE_VOLUME: 131)";	break;
      case 132:	ErrorNumber = "Market is closed. (ERR_MARKET_CLOSED: 132)";	break;
      case 133:	ErrorNumber = "Trade is disabled. (ERR_TRADE_DISABLED: 133)";	break;
      case 134:	ErrorNumber = "Not enough money. (ERR_NOT_ENOUGH_MONEY: 134)";	break;
      case 135:	ErrorNumber = "Price changed. (ERR_PRICE_CHANGED: 135)";	break;
      case 136:	ErrorNumber = "Off quotes. (ERR_OFF_QUOTES: 136)";	break;
      case 137:	ErrorNumber = "Broker is busy. (ERR_BROKER_BUSY: 137)";	break;
      case 138:	ErrorNumber = "Requote. (ERR_REQUOTE: 138)";	break;
      case 139:	ErrorNumber = "Order is locked. (ERR_ORDER_LOCKED: 139)";	break;
      case 140:	ErrorNumber = "Long positions only allowed. (ERR_LONG_POSITIONS_ONLY_ALLOWED: 140)";	break;
      case 141:	ErrorNumber = "Too many requests. (ERR_TOO_MANY_REQUESTS: 141)";	break;
      case 145:	ErrorNumber = "Modification denied because an order is too close to market. (ERR_TRADE_MODIFY_DENIED: 145)";	break;
      case 146:	ErrorNumber = "Trade context is busy. (ERR_TRADE_CONTEXT_BUSY: 146)";	break;
      case 147:	ErrorNumber = "Expirations are denied by broker. (ERR_TRADE_EXPIRATION_DENIED: 147)";	break;
      case 148:	ErrorNumber = "The amount of opened and pending orders has reached the limit set by a broker. (ERR_TRADE_TOO_MANY_ORDERS: 148)";	break;
      case 4000:	ErrorNumber = "No error. (ERR_NO_MQLERROR: 4000)";	break;
      case 4001:	ErrorNumber = "Wrong function pointer. (ERR_WRONG_FUNCTION_POINTER: 4001)";	break;
      case 4002:	ErrorNumber = "Array index is out of range. (ERR_ARRAY_INDEX_OUT_OF_RANGE: 4002)";	break;
      case 4003:	ErrorNumber = "No memory for function call stack. (ERR_NO_MEMORY_FOR_FUNCTION_CALL_STACK: 4003)";	break;
      case 4004:	ErrorNumber = "Recursive stack overflow. (ERR_RECURSIVE_STACK_OVERFLOW: 4004)";	break;
      case 4005:	ErrorNumber = "Not enough stack for parameter. (ERR_NOT_ENOUGH_STACK_FOR_PARAMETER: 4005)";	break;
      case 4006:	ErrorNumber = "No memory for parameter string. (ERR_NO_MEMORY_FOR_PARAMETER_STRING: 4006)";	break;
      case 4007:	ErrorNumber = "No memory for temp string. (ERR_NO_MEMORY_FOR_TEMP_STRING: 4007)";	break;
      case 4008:	ErrorNumber = "Not initialized string. (ERR_NOT_INITIALIZED_STRING: 4008)";	break;
      case 4009:	ErrorNumber = "Not initialized string in an array. (ERR_NOT_INITIALIZED_ARRAYSTRING: 4009)";	break;
      case 4010:	ErrorNumber = "No memory for an array string. (ERR_NO_MEMORY_FOR_ARRAYSTRING: 4010)";	break;
      case 4011:	ErrorNumber = "Too long string. (ERR_TOO_LONG_STRING: 4011)";	break;
      case 4012:	ErrorNumber = "Remainder from zero divide. (ERR_REMAINDER_FROM_ZERO_DIVIDE: 4012)";	break;
      case 4013:	ErrorNumber = "Zero divide. (ERR_ZERO_DIVIDE: 4013)";	break;
      case 4014:	ErrorNumber = "Unknown command. (ERR_UNKNOWN_COMMAND: 4014)";	break;
      case 4015:	ErrorNumber = "Wrong jump. (ERR_WRONG_JUMP: 4015)";	break;
      case 4016:	ErrorNumber = "Not initialized array. (ERR_NOT_INITIALIZED_ARRAY: 4016)";	break;
      case 4017:	ErrorNumber = "DLL calls are not allowed. (ERR_DLL_CALLS_NOT_ALLOWED: 4017)";	break;
      case 4018:	ErrorNumber = "Cannot load library. (ERR_CANNOT_LOAD_LIBRARY: 4018)";	break;
      case 4019:	ErrorNumber = "Cannot call function. (ERR_CANNOT_CALL_FUNCTION: 4019)";	break;
      case 4020:	ErrorNumber = "EA function calls are not allowed. (ERR_EXTERNAL_EXPERT_CALLS_NOT_ALLOWED: 4020)";	break;
      case 4021:	ErrorNumber = "Not enough memory for a string returned from a function. (ERR_NOT_ENOUGH_MEMORY_FOR_RETURNED_STRING: 4021)";	break;
      case 4022:	ErrorNumber = "System is busy. (ERR_SYSTEM_BUSY: 4022)";	break;
      case 4050:	ErrorNumber = "Invalid function parameters count. (ERR_INVALID_FUNCTION_PARAMETERS_COUNT: 4050)";	break;
      case 4051:	ErrorNumber = "Invalid function parameter value. (ERR_INVALID_FUNCTION_PARAMETER_VALUE: 4051)";	break;
      case 4052:	ErrorNumber = "String function internal error. (ERR_STRING_FUNCTION_INTERNAL_ERROR: 4052)";	break;
      case 4053:	ErrorNumber = "Some array error. (ERR_SOME_ARRAY_ERROR: 4053)";	break;
      case 4054:	ErrorNumber = "Incorrect series array using. (ERR_INCORRECT_SERIES_ARRAY_USING: 4054)";	break;
      case 4055:	ErrorNumber = "Custom indicator error. (ERR_CUSTOM_INDICATOR_ERROR: 4055)";	break;
      case 4056:	ErrorNumber = "Arrays are incompatible. (ERR_INCOMPATIBLE_ARRAYS: 4056)";	break;
      case 4057:	ErrorNumber = "Global variables processing error. (ERR_GLOBAL_VARIABLES_PROCESSING_ERROR: 4057)";	break;
      case 4058:	ErrorNumber = "Global variable not found. (ERR_GLOBAL_VARIABLE_NOT_FOUND: 4058)";	break;
      case 4059:	ErrorNumber = "Function is not allowed in testing mode. (ERR_FUNCTION_NOT_ALLOWED_IN_TESTING_MODE: 4059)";	break;
      case 4060:	ErrorNumber = "Function is not confirmed. (ERR_FUNCTION_NOT_CONFIRMED: 4060)";	break;
      case 4061:	ErrorNumber = "Mail sending error. (ERR_SEND_MAIL_ERROR: 4061)";	break;
      case 4062:	ErrorNumber = "String parameter expected. (ERR_STRING_PARAMETER_EXPECTED: 4062)";	break;
      case 4063:	ErrorNumber = "Integer parameter expected. (ERR_INTEGER_PARAMETER_EXPECTED: 4063)";	break;
      case 4064:	ErrorNumber = "Double parameter expected. (ERR_DOUBLE_PARAMETER_EXPECTED: 4064)";	break;
      case 4065:	ErrorNumber = "Array as parameter expected. (ERR_ARRAY_AS_PARAMETER_EXPECTED: 4065)";	break;
      case 4066:	ErrorNumber = "Requested history data in updating state. (ERR_HISTORY_WILL_UPDATED: 4066)";	break;
      case 4067:	ErrorNumber = "Some error in trade operation execution. (ERR_TRADE_ERROR: 4067)";	break;
      case 4099:	ErrorNumber = "End of a file. (ERR_END_OF_FILE: 4099)";	break;
      case 4100:	ErrorNumber = "Some file error. (ERR_SOME_FILE_ERROR: 4100)";	break;
      case 4101:	ErrorNumber = "Wrong file name. (ERR_WRONG_FILE_NAME: 4101)";	break;
      case 4102:	ErrorNumber = "Too many opened files. (ERR_TOO_MANY_OPENED_FILES: 4102)";	break;
      case 4103:	ErrorNumber = "Cannot open file. (ERR_CANNOT_OPEN_FILE: 4103)";	break;
      case 4104:	ErrorNumber = "Incompatible access to a file. (ERR_INCOMPATIBLE_ACCESS_TO_FILE: 4104)";	break;
      case 4105:	ErrorNumber = "No order selected. (ERR_NO_ORDER_SELECTED: 4105)";	break;
      case 4106:	ErrorNumber = "Unknown symbol. (ERR_UNKNOWN_SYMBOL: 4106)";	break;
      case 4107:	ErrorNumber = "Invalid price. (ERR_INVALID_PRICE_PARAM: 4107)";	break;
      case 4108:	ErrorNumber = "Invalid ticket. (ERR_INVALID_TICKET: 4108)";	break;
      case 4109:	ErrorNumber = "Trade is not allowed. (ERR_TRADE_NOT_ALLOWED: 4109)";	break;
      case 4110:	ErrorNumber = "Longs are not allowed. (ERR_LONGS_NOT_ALLOWED: 4110)";	break;
      case 4111:	ErrorNumber = "Shorts are not allowed. (ERR_SHORTS_NOT_ALLOWED: 4111)";	break;
      case 4200:	ErrorNumber = "Object already exists. (ERR_OBJECT_ALREADY_EXISTS: 4200)";	break;
      case 4201:	ErrorNumber = "Unknown object property. (ERR_UNKNOWN_OBJECT_PROPERTY: 4201)";	break;
      case 4202:	ErrorNumber = "Object does not exist. (ERR_OBJECT_DOES_NOT_EXIST: 4202)";	break;
      case 4203:	ErrorNumber = "Unknown object type. (ERR_UNKNOWN_OBJECT_TYPE: 4203)";	break;
      case 4204:	ErrorNumber = "No object name. (ERR_NO_OBJECT_NAME: 4204)";	break;
      case 4205:	ErrorNumber = "Object coordinates error. (ERR_OBJECT_COORDINATES_ERROR: 4205)";	break;
      case 4206:	ErrorNumber = "No specified subwindow. (ERR_NO_SPECIFIED_SUBWINDOW: 4206)";	break;
      case 4207:	ErrorNumber = "Some error in object operation. (ERR_SOME_OBJECT_ERROR: 4207)";	break;
      default:    ErrorNumber = "Unknown error occured (" + IntegerToString(error) + ")";
   }
   
   return (ErrorNumber);
}
