const Migrations = artifacts.require("Migrations");

module.exports = async function (deployer) {
  console.log(">>> Deploying Migrations.sol...");
  await deployer.deploy(Migrations);
  console.log(">>> ✅ Migrations.sol deployed");
};
