var CryptoPlaceMarket = artifacts.require("./CryptoPlaceMarket.sol");

module.exports = function(deployer) {
  deployer.deploy(CryptoPlaceMarket);
};
