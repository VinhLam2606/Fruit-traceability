const Chain = artifacts.require("Chain");

module.exports = async function (deployer) {
  console.log(">>> Deploying Chain.sol...");
  await deployer.deploy(Chain);
  console.log(">>> ✅ Chain.sol deployed");
};
