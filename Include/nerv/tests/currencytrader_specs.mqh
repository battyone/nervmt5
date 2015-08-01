
#include <nerv/unit/Testing.mqh>
#include <nerv/expert/CurrencyTrader.mqh>

BEGIN_TEST_PACKAGE(currencytrader_specs)

BEGIN_TEST_SUITE("CurrencyTrader class")

BEGIN_TEST_CASE("should be able to create a CurrencyTrader instance")
	nvCurrencyTrader ct("EURUSD");
	REQUIRE_EQUAL(ct.getSymbol(),"EURUSD");
END_TEST_CASE()

END_TEST_SUITE()

END_TEST_PACKAGE()
