#include <nerv/core.mqh>

#include <nerv/expert/PortfolioManager.mqh>
#include <nerv/expert/Market.mqh>

class nvCurrencyTrader;

/*
Class: nvDeal

This class represents a deal that was just completed.
It will provide information on how many points we have in profit,
when the deal was entered and exited, the current weight of the corresponding
trader, etc...
*/
class nvDeal : public nvObject
{
protected:
  // Currency trader holding this deal
  nvCurrencyTrader* _trader;

  // Number of points of profit received in this deal:
  double _numPoints;

  // profit of this deal in the same currency as the balance:
  double _profit;

  // utilities of all traders when the deal is initialized:
  double _utilities[];

  // Utility of the trader owning this deal when it is initialized:
  double _traderUtility;

  // Utility efficiency when this deal is initialized:
  double _utilityEfficiency;

  // price when entering this deal:
  double _entryPrice;

  // datetime of the entry of this deal:
  datetime _entryTime;

  // pricewhen exiting this deal:
  double _exitPrice;

  // datetime of the exit of this deal:
  datetime _exitTime;

  // order type of this deal:
  ENUM_ORDER_TYPE _orderType;

  // Boolean to check if this deal is done or not:
  bool _isDone;

  // Lot size for this deal:
  double _lotSize;

  // Symbol of this deal:
  string _symbol;

  // Market type for this deal:
  MarketType _marketType;

  // Stop loss price
  double _stopLossPrice;

public:
  /*
    Class constructor.
  */
  nvDeal()
  {
    _trader = NULL;
    _numPoints = 0.0; // No profit by default.
    _profit = 0.0;
    ArrayResize( _utilities, 0 ); // No utilities by default.
    _traderUtility = 0.0; // Default utility value.
    _utilityEfficiency = 1.0; // Default efficiency of the utility assignment.
    _entryPrice = 0.0;
    _entryTime = 0;
    _exitPrice = 0.0;
    _exitTime = 0;
    _orderType = 0;
    _isDone = false;
    _lotSize = 0.0;
    _marketType = MARKET_TYPE_UNKNOWN;
    _stopLossPrice = 0.0;
    _symbol = "";
  }

  /*
    Copy constructor
  */
  nvDeal(const nvDeal& rhs)
  {
    this = rhs;
  }

  /*
    assignment operator
  */
  void operator=(const nvDeal& rhs)
  {
    THROW("No copy assignment.")
  }

  /*
    Class destructor.
  */
  ~nvDeal()
  {
    // No op.
  }

  /*
  Function: getCurrencyTrader
  
  Retrieve currency trader owning this deal
  */
  nvCurrencyTrader* getCurrencyTrader()
  {
    CHECK_RET(_trader,NULL,"Invalid currency trader.")
    return _trader;
  }
  
  /*
  Function: setCurrencyTrader
  
  Assign the ID of the trader owning this deal
  */
  void setCurrencyTrader(nvCurrencyTrader* trader)
  {
    CHECK(_trader==NULL,"Currency trader already assigned.")
    CHECK(trader!=NULL,"Invalid currency trader.")

    _trader = trader;
    _symbol = trader.getSymbol();
  }

  /*
  Function: getNumPoints
  
  Retrieve the number of points of profit for this deal
  */
  double getNumPoints()
  {
    return _numPoints;
  }
  
  /*
  Function: setNumPoints
  
  Set the number of points of profit for this deal.
  */
  void setNumPoints(double points)
  {
    _numPoints = points;
  }
  
  /*
  Function: getProfit
  
  Retrieve the profit of this deal
  */
  double getProfit()
  {
    return _profit;
  }
  
  /*
  Function: getSymbol
  
  Retrieve the symbol of that deal
  */
  string getSymbol()
  {
    CHECK_RET(_symbol!="","","Invalid symbol")
    return _symbol;
  }
  
  /*
  Function: getOrderType
  
  Retrieve the position type of this deal
  */
  ENUM_ORDER_TYPE getOrderType()
  {
    return _orderType;
  }
  
  /*
  Function: setOrderType
  
  Set the order type for this deal
  */
  void setOrderType(ENUM_ORDER_TYPE otype)
  {
    _orderType = otype;
  }
  
  /*
  Function: setMarketType
  
  Assign the market type for this deal
  */
  void setMarketType(MarketType mtype)
  {
    _marketType = mtype;
  }
  
  /*
  Function: getMarketType
  
  Retrieve the market type for that deal
  */
  MarketType getMarketType()
  {
    return _marketType;
  }
  
  /*
  Function: getCurrentEquity
  
  Retrieve the current equity value in this deal
  */
  double getCurrentEquity(string currency = "")
  {
    CHECK_RET(_trader,0,"Invalid trader for deal");
    nvPriceManager* pm = _trader.getManager().getPriceManager();

    if(currency=="")
      currency = nvGetAccountCurrency();

    double npoints = 0.0;

    if(getOrderType()==ORDER_TYPE_BUY) {
      // When we buy, the entry price is the ask price,
      // then we are interested in the current bid price:
      npoints = (pm.getBidPrice(_symbol) - getEntryPrice())/nvGetPointSize(_symbol);
    }
    else if(getOrderType()==ORDER_TYPE_SELL) {
      npoints = (getEntryPrice() - pm.getAskPrice(_symbol))/nvGetPointSize(_symbol);
    }
    else {
      THROW("Unsupported order type: "<<(int)getOrderType());
    }

    double value = nvGetPointValue(_symbol,getLotSize())*npoints;

    // value is given in the quote currency:
    string quote = nvGetQuoteCurrency(_symbol);
    return pm.convertPrice(value,quote,currency);
  }
  
  /*
  Function: getUsedMargin
  
  Retrieve the margin used to open this position:
  */
  double getUsedMargin(string currency = "")
  {
    CHECK_RET(_trader,0,"Invalid trader for deal");
    nvPriceManager* pm = _trader.getManager().getPriceManager();

    if(currency=="")
      currency = nvGetAccountCurrency();
    
    if(getOrderType()==ORDER_TYPE_BUY) {
      // This is the value in the base currency:
      double value = nvGetContractValue(_symbol,getLotSize());

      // Value in the quote currency:
      value *= getEntryPrice();
  
      // value is given in the quote currency:
      string quote = nvGetQuoteCurrency(_symbol);
      return pm.convertPrice(value,quote,currency,getEntryTime());
    }        
    else if(getOrderType()==ORDER_TYPE_SELL) {
      // This is the value in the base currency:
      double value = nvGetContractValue(_symbol,getLotSize());

      string base = nvGetBaseCurrency(_symbol);
      return pm.convertPrice(value,base,currency,getEntryTime());
    }
    else {
      THROW("Unsupported order type: "<<(int)getOrderType());
    }

    return 0.0;
  }
  
  /*
  Function: getNominalProfit
  

  Retrieve the profit that would have been achieved with this deal
  if the trader weight was 1.0 when it was initiated
  and if there were no risk management layer on top of the trading system
  This method will simply divide the observed profit by the deal lot size
  at the trade entry time: in effect the lot size is a measure of the 
  trader weight combined with the current risk management multiplier.
  */
  double getNominalProfit()
  {
    CHECK_RET(_lotSize>0.0,0.0,"Invalid lot size.");
    return _profit/_lotSize;
  }
  
  /*
  Function: getTraderUtility
  
  Retrieve the utility of the trader at the time this deal was entered.
  */
  double getTraderUtility()
  {
    return _traderUtility;
  }
  
  /*
  Function: setProfit
  
  Set the profit of this deal, note that the profit
  must be specified in the account balance currency.
  */
  void setProfit(double profit)
  {
    _profit = profit;
  }

  /*
  Function: getUtilities
  
  Retrieve all the utilities from all traders by the time
  this deal is initialized.
  */
  void getUtilities(double& arr[])
  {
    int num = ArraySize( _utilities );
    ArrayResize( arr, num );
    if(num>0)
    {
      CHECK(ArrayCopy(arr, _utilities)==num,"Could not copy all utilities elements.");
    }
  }

  /*
  Function: open
  
  Method called when this deal should be opened.
  This method we retrieve the current settings from the currency trader
  and portfolio manager.
  */
  void open(nvCurrencyTrader* trader, ENUM_ORDER_TYPE orderType, double entryPrice, datetime entryTime, double lotsize)
  {
    setCurrencyTrader(trader);
    open(orderType,entryPrice,entryTime,lotsize);
  }
  
  /*
  Function: open
  
  Method called when this deal should be opened.
  This method we retrieve the current settings from the currency trader
  and portfolio manager.
  */
  void open(ENUM_ORDER_TYPE orderType, double entryPrice, datetime entryTime, double lotsize)
  {
    CHECK(entryPrice>0.0 && entryTime>0,"Invalid entry price and/or time");
    
    _entryPrice = entryPrice;
    _entryTime = entryTime;
    _orderType = orderType;
    _lotSize = lotsize;

    open();
  }
  
  /*
  Function: open
  
  Method called to record the data on the trade opening point
  */
  void open()
  {
    // We assume that the trader is available here:
    CHECK(_trader!=NULL,"Invalid currency trader");

    // Assign the current utility of the parent trader:
    _traderUtility = _trader.getUtility();

    // also keep a ref on the utitity efficiency:
    _utilityEfficiency = _trader.getManager().getUtilityEfficiency();

    // Also keep a list of all current utilities:
    _trader.getManager().getUtilities(_utilities);    
  }
  
  /*
  Function: close
  
  Method called to close this deal with a given price at a given time
  */
  void close(double exitPrice, datetime exitTime, double profit)
  {
    _exitPrice = exitPrice;
    _exitTime = exitTime;

    close();

    // override the profit value:
    _profit = profit;
  }
  
  /*
  Function: computeBuyProfit
  
  Method used to compute the profit on this deal in case it was a buy order
  */
  void computeBuyProfit()
  {
    CHECK(_orderType==ORDER_TYPE_BUY,"Incorrect order type");

    nvPriceManager* pm = _trader.getManager().getPriceManager();

    string baseCur = nvGetBaseCurrency(_symbol);
    string quoteCur = nvGetQuoteCurrency(_symbol);
    string accCur = nvGetAccountCurrency();

    logDEBUG("Entering buy profit method")

    // Check what quantity of the base currency we are considering here:
    double baseVal = nvGetContractValue(_symbol,_lotSize);
    logDEBUG("baseVal=" << baseVal)

    // Compute how much of the quote currency we need to buy this quantity of the base:
    double quoteVal = pm.convertPriceInv(baseVal,quoteCur,baseCur,_entryTime);
    logDEBUG("quoteVal=" << quoteVal)

    // Now compute the value of this position once opened:
    // we have baseVal, that we should convert back to quote currency at exit time
    double quoteVal2 = pm.convertPrice(baseVal,baseCur,quoteCur,_exitTime);
    logDEBUG("quoteVal2=" << quoteVal2)

    // Our profit in the quote currency is thus:
    double quoteProfit = quoteVal2 - quoteVal;
    logDEBUG("quoteProfit=" << quoteProfit)

    // Convert this profit into our account:
    // _profit = pm.convertPrice(quoteProfit,quoteCur,accCur,_exitTime);
    _profit = pm.convertPriceFlat(quoteProfit,quoteCur,accCur,_exitTime);
    logDEBUG("profit=" << _profit)

    // // Compute the initial value that we had to pay from our balance:
    // double Xold = pm.convertPriceInv(quoteVal,accCur,quoteCur,_entryTime);
    // logDEBUG("Xold=" << Xold)

    // Compute what quantity of the account currency we need to buy the previous quoteVal:
    // Don't forget to take the leverage into account:
    // margin = pm.convertPriceInv(quoteVal,accCur,quoteCur)/leverage;


    // // So now at exit time, we need to convert all the base value into our account currency:
    // double totalAccount = pm.convertPrice(baseVal,baseCur,accCur,_exitTime);

    // // Once this is done, we need to remove what is needed to refund the money we borrowed in the quote currency:
    // // Thus:
    // // quoteRefund = pm.convertPrice(accountRefund,accCur,quoteCur,_exitTime)
    // double accountRefund = pm.convertPriceInv(quoteVal,accCur,quoteCur,_exitTime);

    // // Then the profit is what is left in the account currency:
    // _profit = totalAccount - accountRefund;

    double cprofit = 0.0;
    CHECK(OrderCalcProfit(_orderType,_symbol,_lotSize,_entryPrice,_exitPrice,cprofit),"Cannot compute profit");
    logDEBUG("Computed buy profit is: "<<cprofit);


    // // Now compute the new value we have in the account currency:
    // double Xnew = pm.convertPrice(quoteVal2,quoteCur,accCur,_exitTime);
    // logDEBUG("Xnew=" << Xnew)

    // // finally compute the profit:
    // _profit = Xnew - Xold;

    // // From this value, we should refund what initially borrowed to place the deal:
    // // but note that this profit value is still expressed in te quote currency.
    // double profit = quoteVal2 - quoteVal;

    // // So finaly, we need to convert this into our account currency...
    // // If the profit is positive, then we convert back normally:
    // if(profit>0.0) {
    //   _profit = pm.convertPrice(profit,quoteCur,accCur,_exitTime);
    // }
    // else {
    //   // If the profit is negative then this rather means that we should convert from our account
    //   // currency to the quote currency to complete the refund:
    //   // We need to get "profit" in quote, by buying it from acc.
    //   // |profit| = pm.convertPrice(|equity|,accCur,quoteCur)
    //   _profit = - pm.convertPriceInv(-profit,accCur,quoteCur,_exitTime);
    // }

  }

  /*
  Function: computeSellProfit
  
  Method used to compute the profit on this deal in case it was a sell order
  */
  void computeSellProfit()
  {
    nvPriceManager* pm = _trader.getManager().getPriceManager();

    string baseCur = nvGetBaseCurrency(_symbol);
    string quoteCur = nvGetQuoteCurrency(_symbol);
    string accCur = nvGetAccountCurrency();

    // Check what quantity of the base currency we are considering here:
    double baseVal = nvGetContractValue(_symbol,_lotSize);

    // // First we have to compute how much we take from our current balance, to buy what 
    // // we need in the base currency:
    // // baseVal = convertPrice(X,Acc,Base):
    // double Xold = pm.convertPriceInv(baseVal,accCur,baseCur,_entryTime);

    // Compute how much of the quote currency we get when selling this quantity of the base:
    double quoteVal = pm.convertPrice(baseVal,baseCur,quoteCur,_entryTime);

    // Now compute the value we get back when rebuying the base
    // we have quoteVal, that we should convert back to base currency:
    double baseVal2 = pm.convertPrice(quoteVal,quoteCur,baseCur,_exitTime);

    double baseProfit = baseVal2 - baseVal;

    // Convert this profit into our account:
    // _profit = pm.convertPrice(baseProfit,baseCur,accCur,_exitTime);
    _profit = pm.convertPriceFlat(baseProfit,baseCur,accCur,_exitTime);

    logDEBUG("profit=" << _profit)
    
    // Compute what quantity of the account currency we need to buy the previous baseVal:
    // Don't forget to take the leverage into account:
    // margin = pm.convertPriceInv(baseVal,accCur,baseCur)/leverage;

    // // So now at exit time, we need to convert all the quote value into our account currency:
    // double totalAccount = pm.convertPrice(quoteVal,quoteCur,accCur,_exitTime);

    // // Once this is done, we need to remove what is needed to refund the money we borrowed in the base currency:
    // // Thus:
    // // quoteRefund = pm.convertPrice(accountRefund,accCur,quoteCur,_exitTime)
    // double accountRefund = pm.convertPriceInv(baseVal,accCur,baseCur,_exitTime);

    // // Then the profit is what is left in the account currency:
    // _profit = totalAccount - accountRefund;

    double cprofit = 0.0;
    CHECK(OrderCalcProfit(_orderType,_symbol,_lotSize,_entryPrice,_exitPrice,cprofit),"Cannot compute profit");
    logDEBUG("Computed sell profit is: "<<cprofit);


    // // We further convert this value back into our account currency:
    // double Xnew = pm.convertPrice(baseVal2,baseCur,accCur,_exitTime);

    // // Finally, our profit is what we have left:
    // _profit = Xnew - Xold;

    // // From this value, we should refund what initially borrowed to place the deal:
    // // but note that this profit value is still expressed in the base currency.
    // double profit = baseVal2 - baseVal;

    // // So finaly, we need to convert this into our account currency...
    // // If the profit is positive, then we convert back normally:
    // if(profit>0.0) {
    //   _profit = pm.convertPrice(profit,baseCur,accCur,_exitTime);
    // }
    // else {
    //   // If the profit is negative then this rather means that we should convert from our account
    //   // currency to the quote currency to complete the refund:
    //   // We need to get "profit" in base, by buying it from acc.
    //   // |profit| = pm.convertPrice(|equity|,accCur,baseCur)
    //   _profit = - pm.convertPriceInv(-profit,accCur,baseCur,_exitTime);
    // }   
  }

  
  /*
  Function: close
  
  Method called to finalize a deal when it is completed.
  */
  void close()
  {
    // Ensure that the deal was opened first:
    CHECK(_entryTime>0 && _entryPrice>0.0,"Cannot close not opened deal.");

    // Ensure that the timestamps are correct:
    CHECK(_entryTime<=_exitTime,"Invalid entry/exit times: "<<_entryTime<<">"<<_exitTime);

    // At this point we can also compute the profit in number of points:
    _numPoints = _orderType==ORDER_TYPE_BUY ? _exitPrice - _entryPrice : _entryPrice - _exitPrice;

    // Mark this deal as done:
    _isDone = true;  

    // We can also compute our profit value here:
    // First we compute the profit in the quote currency:
    // double profit = nvGetPointValue(_symbol,_lotSize)*_numPoints;

    // // Then we report it in the balance currency:
    // profit = _trader.getManager().getPriceManager().convertPrice(profit,nvGetQuoteCurrency(_symbol),nvGetAccountCurrency(),_exitTime);

    // setProfit(profit); 
    if(_orderType==ORDER_TYPE_BUY) {
      computeBuyProfit();
    } 
    else {
      computeSellProfit();
    }
  }
  
  /*
  Function: isDone
  
  Check if this deal is done or not.
  */
  bool isDone()
  {
    return _isDone;
  }
  
  /*
  Function: getEntryPrice
  
  Retrieve the entry price of this deal
  */
  double getEntryPrice()
  {
    return _entryPrice;
  }
  
  /*
  Function: setEntryPrice
  
  Assign the entry price of this deal
  */
  void setEntryPrice(double price)
  {
    _entryPrice = price;
  }
  
  /*
  Function: getEntryTime
  
  Retrieve the entry time of that deal
  */
  datetime getEntryTime()
  {
    return _entryTime;
  }
  
  /*
  Function: setEntryTime
  
  Assign the entry time for this deal
  */
  void setEntryTime(datetime time)
  {
    _entryTime = time;
  }
  
  /*
  Function: getExitPrice
  
  Retrieve the exit price of this deal:
  */
  double getExitPrice()
  {
    return _exitPrice;
  }
  
  /*
  Function: setExitPrice
  
  Assign the exit price for this deal
  */
  void setExitPrice(double price)
  {
    _exitPrice = price;
  }
  
  /*
  Function: getExitTime
  
  Retrieve the exit time of this deal
  */
  datetime getExitTime()
  {
    return _exitTime;
  }

  /*
  Function: setExitTime
  
  Assign the exit time for this deal
  */
  void setExitTime(datetime time)
  {
    _exitTime = time;
  }
  
  /*
  Function: getLotSize
  
  Retrieve the lot size used for this deal
  */
  double getLotSize()
  {
    return _lotSize;
  }
  
  /*
  Function: setLotSize
  
  Assign the lot size used for this deal
  */
  void setLotSize(double size)
  {
    _lotSize = size;
  }
  
  /*
  Function: getStopLossPrice
  
  Retrieve the stop loss price (if any)
  */
  double getStopLossPrice()
  {
    return _stopLossPrice;
  }
  
  /*
  Function: setStopLossPrice
  
  Assign the stop loss price
  */
  void setStopLossPrice(double price)
  {
    _stopLossPrice = price;
  }
  
  /*
  Function: getProfitDerivative
  
  Retrieve the profit derivative at a given utility efficiency point
  for this deal
  */
  double getProfitDerivative(double alpha)
  {
    double P = getNominalProfit();

    // Compute the weight derivative:
    int num = ArraySize( _utilities );
    double ui = _traderUtility;
    double sum_e = 0.0;
    double sum_ue = 0.0;
    double val;
    double u;
    for(int i=0;i<num;++i)
    {
      u = _utilities[i];
      val = exp(alpha*u);
      sum_e += val;
      sum_ue += u*val;
    }

    double deriv = exp(alpha*ui)*(ui*sum_e - sum_ue)/(sum_e*sum_e);
    return P*deriv;
  }
  
  /*
  Function: getProfitValue
  
  Compute the hypothetical profit value for a given efficiency factor alpha
  */
  double getProfitValue(double alpha)
  {
    double P = getNominalProfit();
    int num = ArraySize( _utilities );
    double ui = _traderUtility;
    double sum_e = 0.0;
    for(int i=0;i<num;++i)
    {
      sum_e += exp(alpha*_utilities[i]);
    }

    double w = exp(alpha*ui)/sum_e;
    return P*w;
  }
  
};
