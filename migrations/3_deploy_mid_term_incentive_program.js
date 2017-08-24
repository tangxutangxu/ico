var MidTermHoldingIncentiveProgram = artifacts.require("incentive_programs/MidTermHoldingIncentiveProgram.sol")
module.exports = function(deployer) {
  deployer.deploy(MidTermHoldingIncentiveProgram);
};
