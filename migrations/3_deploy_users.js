const Users = artifacts.require("Users");

module.exports = async function (deployer) {
  console.log(">>> Deploying Users...");
  await deployer.deploy(Users);
};
