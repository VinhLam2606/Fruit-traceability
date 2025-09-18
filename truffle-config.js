module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*",  // accept mọi network id
      gas: 6000000,
      gasPrice: 20000000000
    }
  },
  contracts_directory: "./contracts",
  contracts_build_directory: "./build/contracts",
  compilers: {
    solc: {
      version: "0.8.13",   // 👈 downgrade về 0.8.13
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
};
