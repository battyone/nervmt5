
#include <nerv/unit/Testing.mqh>
#include <nerv/expert/Deal.mqh>

BEGIN_TEST_PACKAGE(deal_specs)

BEGIN_TEST_SUITE("nvDeal class")

BEGIN_TEST_CASE("Should be able to create a new Deal object")
	nvDeal deal;
END_TEST_CASE()

BEGIN_TEST_CASE("Should provide trader ID")
  nvDeal deal;

  // By default TRADER ID should be invalid:
  REQUIRE_EQUAL(deal.getTraderID(),(int)INVALID_TRADER_ID);
  
  // Should throw an error if we use an invalid ID:
	BEGIN_REQUIRE_ERROR("Invalid trader ID")
	  deal.setTraderID(1);
	END_REQUIRE_ERROR();

  // Should also throw an error if the ID is valid, but the currency trader is not 
  // registered:
	BEGIN_REQUIRE_ERROR("Invalid trader ID")
	  nvCurrencyTrader ct("EURPJY");
	  deal.setTraderID(ct.getID());
	END_REQUIRE_ERROR();

	// Should not throw if the currency trader is properly registered:
	nvCurrencyTrader* ct = nvPortfolioManager::instance().addCurrencyTrader("EURJPY");
	deal.setTraderID(ct.getID());
  REQUIRE_EQUAL(deal.getTraderID(),ct.getID());

  // Reset the content:
  nvPortfolioManager::instance().removeAllCurrencyTraders();
END_TEST_CASE()

BEGIN_TEST_CASE("Should also provide a number of points of profit")
  nvDeal deal;

  // Default profit is 0.0:
  REQUIRE_EQUAL(deal.getNumPoints(),0.0);
  
  // Set the number of profit points:
  deal.setNumPoints(0.12345);
  REQUIRE_EQUAL(deal.getNumPoints(),0.12345);
END_TEST_CASE()

BEGIN_TEST_CASE("Should provide the profit value")
  nvDeal deal;

  // Default profit is 0.0:
  REQUIRE_EQUAL(deal.getProfit(),0.0);
  
  // Set the number of profit points:
  deal.setProfit(10.12);
  REQUIRE_EQUAL(deal.getProfit(),10.12);
END_TEST_CASE()

BEGIN_TEST_CASE("Should provide the list of utilities from all traders")
  nvDeal deal;

  // no utility values by default:
  double list[];
  deal.getUtilities(list);
  REQUIRE_EQUAL(ArraySize(list),0);
END_TEST_CASE()

BEGIN_TEST_CASE("Should be able to open a deal")
  nvDeal deal;

  nvPortfolioManager::instance().addCurrencyTrader("EURUSD");
	nvCurrencyTrader* ct = nvPortfolioManager::instance().addCurrencyTrader("EURJPY");

	datetime time = TimeLocal();
	deal.open(ct.getID(),ORDER_TYPE_BUY,1.23456,time,1.0);

	REQUIRE_EQUAL(deal.getEntryPrice(),1.23456);
	REQUIRE_EQUAL(deal.getEntryTime(),time);

  double list[];
  deal.getUtilities(list);
  REQUIRE_EQUAL(ArraySize(list),2);
  REQUIRE_EQUAL(list[0],0.0);
  REQUIRE_EQUAL(list[1],0.0);
  
  // Reset the content:
  nvPortfolioManager::instance().removeAllCurrencyTraders();	
END_TEST_CASE()

BEGIN_TEST_CASE("Should be able to close a deal and update number of points")
  nvDeal deal;

  nvPortfolioManager::instance().addCurrencyTrader("EURUSD");
	nvCurrencyTrader* ct = nvPortfolioManager::instance().addCurrencyTrader("EURJPY");

	datetime time = TimeLocal();
	deal.open(ct.getID(),ORDER_TYPE_BUY,1.23456,time,1.0);

	// Now close the deal:
	deal.close(1.23457,time+1,12.3);

	REQUIRE_EQUAL(deal.getExitPrice(),1.23457);
	REQUIRE_EQUAL(deal.getExitTime(),time+1);
	REQUIRE_EQUAL(deal.getProfit(),12.3);
	
	REQUIRE_EQUAL(NormalizeDouble(deal.getNumPoints(),5),0.00001);
	
  // Reset the content:
  nvPortfolioManager::instance().removeAllCurrencyTraders();	
END_TEST_CASE()

BEGIN_TEST_CASE("Should not be done until it is closed")
  nvDeal deal;

  nvPortfolioManager::instance().addCurrencyTrader("EURUSD");
	nvCurrencyTrader* ct = nvPortfolioManager::instance().addCurrencyTrader("EURJPY");

	REQUIRE_EQUAL(deal.isDone(),false);
	
	datetime time = TimeLocal();
	deal.open(ct.getID(),ORDER_TYPE_BUY,1.23456,time,1.0);

	REQUIRE_EQUAL(deal.isDone(),false);
	
	// Now close the deal:
	deal.close(1.23457,time+1,10.0);

	REQUIRE_EQUAL(deal.isDone(),true);
	
  // Reset the content:
  nvPortfolioManager::instance().removeAllCurrencyTraders();	  
END_TEST_CASE()

BEGIN_TEST_CASE("Should throw an error if trying to close an non opened deal")
  nvDeal deal;

	BEGIN_REQUIRE_ERROR("Cannot close not opened deal")
	  deal.close(1.23457,TimeLocal(),10.0);
	END_REQUIRE_ERROR();
END_TEST_CASE()

END_TEST_SUITE()

END_TEST_PACKAGE()
