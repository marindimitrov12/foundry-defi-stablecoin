//SPDX-License-Identifier:MIT

pragma solidity 0.8.20;

import {Test}from "forge-std/Test.sol";
import {DeployDsc}from"../../script/DeployDsc.s.sol";
import {DSCEngine}from"../../src/DSCEngine.sol";
import{DecentralizedStableCoin}from "../../src/DecentralizedStableCoin.sol";
import{HelperConfig}from "../../script/HelperConfig.s.sol";
import{ERC20Mock}from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
contract DSCEngineTest is Test{
    DeployDsc deployer;
    DSCEngine engine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address ethUsdPriceFeed;
    address weth;
    address public USER=makeAddr("user");
    uint256 public constant AMOUNT_COLATERAL=10 ether;
    uint256 public constant STARTING_ERC20_BALANCE=10 ether;

    function setUp()public{
        deployer=new DeployDsc();
        (dsc,engine,config)=deployer.run();
        (ethUsdPriceFeed, ,weth, ,)=config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER,STARTING_ERC20_BALANCE);
    }
    ///////////////////
    // Price Test/////
    /////////////////

    function testGetUsdValue()public{
      uint256 ethAmount=15e18;
      // 15e18 *2000/ETH=30,000e18;
      uint256 expectedUsd=30000e9;
      uint256 actualUsd=engine.getUsdValue(weth,ethAmount);
      assertEq(expectedUsd,actualUsd);
    }
    function testRevertsIfCollateralZero()public{
      vm.startPrank(USER);
      ERC20Mock(weth).approve(address(engine),AMOUNT_COLATERAL);
      vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
      engine.depositCollateral(weth,0);
      vm.stopPrank();
    }
}