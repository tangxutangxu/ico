var LongTermHoldingIncentiveProgram = artifacts.require("incentive_programs/LongTermHoldingIncentiveProgram.sol")
module.exports = function(deployer) {
  deployer.deploy(LongTermHoldingIncentiveProgram);
};
