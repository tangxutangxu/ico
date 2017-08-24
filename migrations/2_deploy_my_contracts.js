// var LoopringToken = artifacts.require("./LoopringToken.sol")
var TestToken = artifacts.require("./TestToken.sol")
var MidTerm = artifacts.require("incentive_programs/MidTermHoldingIncentiveProgram.sol")
var LongTerm = artifacts.require("incentive_programs/LongTermHoldingIncentiveProgram.sol")

module.exports = function(deployer, network, accounts) {
	console.log("network: " + network);
    if (network == "live") {
    	var lrcAddress = "0xEF68e7C694F40c8202821eDF525dE3782458639f";
        deployer.deploy(MidTerm, lrcAddress, "0xf51DF14e49DA86ABC6F1d8Ccc0B3A6b7b7C90Ca6"); // Change this address
        deployer.deploy(LongTerm, lrcAddress, "0xf51DF14e49DA86ABC6F1d8Ccc0B3A6b7b7C90Ca6"); // Change this address

    } else {
    	deployer.deploy(TestToken)
    	.then(function() {
		  	return deployer.deploy(
		  		MidTerm, 
		  		TestToken.address, 
		  		accounts[0]);
		})
		.then(function(){
			return deployer.deploy(
				LongTerm, 
				TestToken.address, 
				accounts[1]);
		});
    }
};