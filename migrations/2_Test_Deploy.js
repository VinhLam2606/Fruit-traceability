const TestDeploy = artifacts.require("TestDeploy");

module.exports = function (deployer) {
    console.log(">>> Deploying TestDeploy...");
    deployer.deploy(TestDeploy);
};
