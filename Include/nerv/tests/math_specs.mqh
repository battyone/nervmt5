
#include <nerv/unit/Testing.mqh>
#include <nerv/math.mqh>

BEGIN_TEST_PACKAGE(math_specs)

BEGIN_TEST_SUITE("Math components")

BEGIN_TEST_SUITE("Vecd class")

BEGIN_TEST_CASE("should be able to create a vector")
  int len = 10;
  nvVecd vec(len);
  REQUIRE_EQUAL_MSG(vec.size(),len,"Invalid vector length");
END_TEST_CASE()

BEGIN_TEST_CASE("should use default provided value and implemente operator[]")
  int len = 10;
  double val = nv_random_real();
  //MESSAGE("Initial value is: "+(string)val);

  nvVecd vec(len,val);
  for(int i=0;i<len;++i) {
    REQUIRE_EQUAL(vec[i],val);
  }
END_TEST_CASE()

BEGIN_TEST_CASE("should support setting element value")
  int len = 10;
  double val = 1.0;
  nvVecd vec(len,val);

  REQUIRE_EQUAL(vec[0],val);
  vec.set(0,1.0);
  REQUIRE_EQUAL(vec.get(0),1.0);
END_TEST_CASE()

BEGIN_TEST_CASE("should have equality operator")
  int len = 10;
  double val = 1.0;
  nvVecd vec1(len,val);
  nvVecd vec2(len,val);

  REQUIRE(vec1==vec2);
  vec2.set(1,val+1.0);
  REQUIRE(vec1!=vec2);
END_TEST_CASE()

BEGIN_TEST_CASE("should have operator+")
  int len = 10;
  nvVecd vec1(len,1.0);
  nvVecd vec2(len,2.0);
  nvVecd vec3(len,3.0);

  REQUIRE(vec1+vec2==vec3);
END_TEST_CASE()

BEGIN_TEST_CASE("should have operator*")
  int len = 10;
  nvVecd vec1(len,1.0);
  nvVecd vec2(len,2.0);

  REQUIRE(vec1*2==vec2);
END_TEST_CASE()

BEGIN_TEST_CASE("should support construction from array")
  double arr[] = {1,2,3,4,5};
  nvVecd vec1(arr);

  REQUIRE(vec1.size()==5);
  REQUIRE(vec1[3]==4);
END_TEST_CASE()

BEGIN_TEST_CASE("should support push_back method")
  double arr[] = {1,2,3,4,5};
  double arr2[] = {2,3,4,5,6};
  nvVecd vec1(arr);
  nvVecd vec2(arr2);

  double val = vec1.push_back(6);
  REQUIRE(vec1==vec2);
  REQUIRE(val==1.0);
END_TEST_CASE()

BEGIN_TEST_CASE("should support push_front method")
  double arr[] = {1,2,3,4,5};
  double arr2[] = {6,1,2,3,4};
  nvVecd vec1(arr);
  nvVecd vec2(arr2);

  double val = vec1.push_front(6);
  REQUIRE(vec1==vec2);
  REQUIRE(val==5.0);
END_TEST_CASE()

BEGIN_TEST_CASE("should support toString method")
  double arr[] = {1,2,3,4,5};
  nvVecd vec1(arr);
  
  REQUIRE_EQUAL(vec1.toString(),"Vecd(1,2,3,4,5)");
  //string str = vec1<<"Vec is: ";
  //REQUIRE_EQUAL(str,"Vec is: Vecd(1,2,3,4,5)");
END_TEST_CASE()

BEGIN_TEST_CASE("should have assignment operator")
  double arr[] = {1,2,3,4,5};
  nvVecd vec1(arr);

  nvVecd vec2(5);
  vec2 = vec1;
  
  REQUIRE_EQUAL(vec2.size(),5);
  REQUIRE(vec1==vec2);
END_TEST_CASE()

BEGIN_TEST_CASE("should have operator-")
  int len = nv_random_int(1,100);
  nvVecd vec1(len,1.0);
  nvVecd vec2(len,2.0);
  nvVecd vec3(len,3.0);

  REQUIRE(vec3-vec2==vec1);
END_TEST_CASE()

BEGIN_TEST_CASE("should have unary operator-")
  int len = nv_random_int(1,100);
  nvVecd vec1(len,1.0);
  nvVecd vec2(len,-1.0);

  REQUIRE(-vec2==vec1);
END_TEST_CASE()


END_TEST_SUITE()

END_TEST_SUITE()

END_TEST_PACKAGE()
