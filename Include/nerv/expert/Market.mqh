#include <nerv/core.mqh>

class nvDeal;

enum MarketType
{
  MARKET_TYPE_UNKNOWN,
  MARKET_TYPE_REAL,
  MARKET_TYPE_VIRTUAL,
};

enum PositionType
{
  POS_NONE,
  POS_LONG,
  POS_SHORT,
};

/*
Class: nvMarket

Base class used to represent a market on which currency trader can open/close positions
*/
class nvMarket : public nvObject
{
protected:
  // The type of this market
  MarketType _marketType;

  // Currently opened positions:
  nvDeal* _currentDeals[];

public:
  /*
    Class constructor.
  */
  nvMarket()
  {
    _marketType = MARKET_TYPE_UNKNOWN;
  }

  /*
    Copy constructor
  */
  nvMarket(const nvMarket& rhs)
  {
    this = rhs;
  }

  /*
    assignment operator
  */
  void operator=(const nvMarket& rhs)
  {
    THROW("No copy assignment.")
  }

  /*
    Class destructor.
  */
  ~nvMarket()
  {
    // No op.
  }

  /*
  Function: getMarketType
  
  Retrieve the type of this market
  */
  MarketType getMarketType()
  {
    return _marketType;
  }
  
  /*
  Function: openPosition
  
  Method called to open a position this market for a given symbol.
  Must be reimplemented by derived classes.
  */
  void openPosition(string symbol, ENUM_ORDER_TYPE otype, double lot, double sl = 0.0)
  {
    // Close any previous position on this symbol:
    closePosition(symbol);

    // Create a new deal for this trade opening:
    nvDeal* deal = new nvDeal();
    deal.setSymbol(symbol);
    deal.setPositionType(otype==ORDER_TYPE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
    deal.setMarketType(_marketType);

    // Perform the actual opening of the position:
    if(doOpenPosition(deal))
    {
      // The deal is opened properly, we keep a reference on it:
      nvAppendArrayElement(_currentDeals,deal);
    }
    else {
      // something went wrong, we discard this deal:
      RELEASE_PTR(deal);
    }
  }
  
  /*
  Function: closePosition
  
  Method called to close a position on a given symbol on that market.
  Must be reimplemented by derived classes.
  */
  virtual void closePosition(string symbol)
  {
    // Check if we have a position on that symbol:
    nvDeal* deal = getCurrentDeal(symbol);
    if(!deal)
    {
      // There is nothing to close.
      return;
    }

    // Perform the actual close operation if needed.
    doClosePosition(deal);

    // Remove this deal from the list of current positions:
    nvRemoveArrayElement(_currentDeals,deal);

    // We should notify a deal to the currency trader corresponding to that symbol:
    nvCurrencyTrader* ct = nvPortfolioManager::instance().getCurrencyTrader(symbol);
    CHECK(ct,"Invalid currency trader for symbol "<<symbol);
    ct.onDeal(deal); // Now the currency trader will take ownership of that deal.
  }
  
  /*
  Function: doClosePosition
  
  Method called to actually close a position on a given symbol on that market.
  Must be reimplemented by derived classes.
  */
  virtual void doClosePosition(nvDeal* deal)
  {
    THROW("No implementation");
  }

  /*
  Function: doClosePosition
  
  Method called to actually open a position on a given symbol on that market.
  Must be reimplemented by derived classes.
  */
  virtual bool doOpenPosition(nvDeal* deal)
  {
    THROW("No implementation");
    return false;
  }

  /*
  Function:   
  
  Retrieve the current deal on a given symbol is any.
  */
  nvDeal* getCurrentDeal(string symbol)
  {
    int num = ArraySize(_currentDeals);
    for(int i=0;i<num;++i)
    {
      if(_currentDeals[i].getSymbol()==symbol)
        return _currentDeals[i];
    }

    return NULL;
  }
  
  /*
  Function: getPositionType
  
  Retrieve the current position type on a symbol.
  Must be reimplemented by derived classes.
  */
  PositionType getPositionType(string symbol)
  {
    nvDeal* deal = getCurrentDeal(symbol);
    if(deal)
    {
      return deal.getPositionType()==POSITION_TYPE_BUY ? POS_LONG : POS_SHORT;
    }

    return POS_NONE;
  }
  
  /*
  Function: hasOpenPosition
  
  Method used to check if there is currently an open position for a given symbol on this market.
  */
  bool hasOpenPosition(string symbol)
  {
    return getPositionType(symbol)!=POS_NONE;
  }
  
};
