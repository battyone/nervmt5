
#include <nerv/unit/Testing.mqh>
#include <nerv/expert/TradingAgent.mqh>

BEGIN_TEST_PACKAGE(tradingagent_specs)

BEGIN_TEST_SUITE("TradingAgent class")

BEGIN_TEST_CASE("should be able to create a TradingAgent instance")
	nvTradingAgent agent;
END_TEST_CASE()

END_TEST_SUITE()

END_TEST_PACKAGE()