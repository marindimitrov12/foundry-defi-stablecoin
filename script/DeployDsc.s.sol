//SPDX-License-Identifier:MIT

pragma solidity 0.8.18;

import {Script,console}from "forge-std/Script.sol";
import {DSCEngine}from "../src/DSCEngine.sol";
import {DecentralizedStableCoin}from "../src/DecentralizedStableCoin.sol";
import {HelperConfig}from"../script/HelperConfig.sol";

contract DeployDsc is Script{
address[] public tokenAddresses;
    address[] public priceFeedAddresses;
function run()external returns(DecentralizedStableCoin,DSCEngine){
    HelperConfig config=new HelperConfig();
      (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
       helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];
    vm.startBroadcast();
    DecentralizedStableCoin dsc=new DecentralizedStableCoin();
    DSCEngine engine=new DSCEngine(tokenAddresses,priceFeedAddresses,address(dsc));
    dsc.transferOwnership(address(engine));
    vm.stopBroadcast();
    return (dsc,engine);
}
}
