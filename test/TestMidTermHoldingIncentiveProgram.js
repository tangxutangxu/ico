var TestToken = artifacts.require("TestToken");
var MidTerm = artifacts.require("MidTermHoldingIncentiveProgram");

contract('MidTermHoldingIncentiveProgram', function(accounts) {
  it("should allow owner to deposit and drain ETH", function() {
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
      }).then(function(){
        // accounts[0] is the owner, this is specified in `2_deploy_my_contracts.js`.
        return web3.eth.sendTransaction({from: accounts[0], to: program.address, value: web3.toWei(10) });
      }).then(function(){
        return web3.eth.getBalance(program.address);
      }).then(function(balance) {
        assert.equal(balance.toNumber(), web3.toWei(10));
        return program.drain(7);
      }).then(function(){
         return web3.eth.getBalance(program.address);
      }).then(function(balance){
        assert.equal(balance.toNumber(), web3.toWei(3));
        return program.drain(5);
      }).then(function(){
         return web3.eth.getBalance(program.address);
      }).then(function(balance){
        assert.equal(balance.toNumber(), web3.toWei(0));
      });
  });
});