var TestToken = artifacts.require("TestToken");
var MidTerm = artifacts.require("MidTermHoldingIncentiveProgram");

contract('MidTerm', function(accounts) {
  it("should not be able to start ico sale when not called by owner.", function() {
    console.log("\n" + "-".repeat(100) + "\n");
    var testToken;
    var program;
    var target;

    return TestToken.deployed()
      .then(function(instance){
        testToken = instance;
        return MidTerm.deployed();
      }).then(function(instance){
        program = instance;
      });
  });
});