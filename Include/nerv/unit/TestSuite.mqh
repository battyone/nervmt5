
#include "TestCase.mqh"
#include <Arrays/List.mqh>

class nvTestSuite : public CObject
{
protected:
  // Name of this test suite:
  string _name;

  // List of test cases contained in this suite:
  CList _cases;

  // List of children suites contained in this suite:
  nvTestSuite *_suites[];

  // Parent test suite:
  nvTestSuite *_parent;

public:
  nvTestSuite(string name, nvTestSuite *parent = NULL)
  {
    _name = name;
    _parent = parent;
    Print("Creating test suite ", _name);
    ArrayResize(_suites, 0); // Set the array size to zero
  }

  virtual ~nvTestSuite()
  {
    Print("Deleting test suite ", _name);
    // delete all the registered test cases:
    _cases.Clear();

    // delete all the registered test suites:
    int num = ArraySize(_suites);
    for (int i = 0; i < num; ++i)
    {
      delete _suites[i];
    }

    // Clear the buffer:
    ArrayFree(_suites);
  }

  // Add a new test case to this test suite:
  void addTestCase(nvTestCase *test)
  {
    _cases.Add(test);
  }

  string getName() const
  {
    return _name;
  }

  nvTestSuite *getParent() const
  {
    return _parent;
  }

  nvTestSuite *getOrCreateTestSuite(string sname)
  {
    // Check if we already have this suite in the list:
    int num = ArraySize(_suites);
    for (int i = 0; i < num; ++i)
    {
      if (_suites[i].getName() == sname)
      {
        Print("Retrieved existing test suite with name ", sname);
        return GetPointer(_suites[i]);
      }
    }

    // Create the new test suite:
    nvTestSuite *suite = new nvTestSuite(sname,GetPointer(this));

    // Add the new suite to the list:
    ArrayResize(_suites, num + 1); //
    _suites[num] = suite;

    // return the newly created test suite:
    return suite;
  }

  // Run the current test suite:
  void run(int& numPassed, int& numFailed)
  {
    Print("Entering Test Suite ", _name);
    numPassed = 0;
    numFailed = 0;

    // Execute all the children test suites:
    int num = ArraySize(_suites);
    int npass, nfail;
    for (int i = 0; i < num; ++i)
    {
      _suites[i].run(npass,nfail);

      // increment our own counters:
      numPassed += npass;
      numFailed += nfail;
    }

    // Execute all the test cases:
    nvTestCase* tcase = (nvTestCase*)_cases.GetFirstNode();
    while(tcase!=NULL) {
      Print(_name, ": ", tcase.getName());
      int res = tcase.doTest();
      if (res == TEST_PASSED)
      {
        numPassed++;
        Print("=> Test PASSED");
      }
      else
      {
        numFailed++;
        Print("=> Test FAILED");
      }
      tcase = (nvTestCase*)_cases.GetNextNode();
    }

    int total = numPassed+numFailed;

    Print("Leaving Test Suite ", _name, ": Success ratio: ",numPassed,"/",total);
  }
};
