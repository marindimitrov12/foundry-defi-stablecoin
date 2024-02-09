//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin}from"./DecentralizedStableCoin.sol";
import {ReentrancyGuard}from"@openzeppelin/contracts/security/ReentrancyGuard.sol";
/**
 * @title DSCEngine
 * @author Marin Dimitrov
 * 
 * This system is designed to be as minimal as possible, and have the tokens maintain 1
  token==$1 peg.
 *This stablecoin has the properties:
 *-Exogenous Collateral
 *-Dollar Pegged
 *-Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance,no fees,and was only backed by WETH and WBTC.
 * 
 * Our DSC system should always be "overcollateralized".At no point, should the value of all 
 * collateral<=the $ backed value of all the DSC.
 * @notice This contract is the core of the DSC System.It handles all the logic for mining
 * and redeeming DSC, as well as depositing & withdrawing collateral.
 * @notice  This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
 */
contract DSCEngine is ReentrancyGuard{
  ///////////////
  // Errors    //  
  /////////////// 
 error DSCEngine__NeedsMoreThanZero();
 error DSCEngine__TokenAddresessAndPriceFeedAddressesMustBeSameLength();
 error DSCEngine__NotAllowedToken();

  /////////////////////
  // State Variables //  
  ///////////////////// 
  mapping(address token=>address priceFeed)private s_priceFeeds;//tokenToPriceFeed
  mapping(address user=>mapping(address token=>uint256 amount))
  private s_collateralDeposited;
  DecentralizedStableCoin private immutable i_dsc;
   ///////////////
  // Modifiers //  
  /////////////// 

  modifier moreThanZero(uint256 amount) {
    if(amount==0){
      revert DSCEngine__NeedsMoreThanZero();
    }
    _;
  }
  modifier isAllowedToken(address token){
       if(s_priceFeeds[token]==address(0)){
        revert DSCEngine__NotAllowedToken();
       }
       _;
  }
  ///////////////
  // Functions //  
  ///////////////

  constructor(
    address[]memory tokenAddresses,
    address[]memory priceFeedAddresses,
    address dscAddress){
     if(tokenAddresses.length!=priceFeedAddresses.length){
        revert DSCEngine__TokenAddresessAndPriceFeedAddressesMustBeSameLength();
     }
     for(uint256 i=0;i<tokenAddresses.length;i++){
        s_priceFeeds[tokenAddresses[i]]=priceFeedAddresses[i];
     }
     i_dsc=DecentralizedStableCoin(dscAddress);
  }

  ////////////////////////
  // External Functions //  
  ////////////////////////
  function depositColleteralAndMintDsc() external{}
  /*
   * 
   * @param tokenCollateralAddress The address of the token to deposit as collateral
   * @param amountCollateral The amount of collateral to deposit
   */
  function depositCollateral(
    address tokenCollateralAddress,
    uint256 amountCollateral)external 
    moreThanZero(amountCollateral) 
    isAllowedToken(tokenCollateralAddress)
    nonReentrant{
       s_collateralDeposited[msg.sender][tokenCollateralAddress]+=amountCollateral;
    }


  function redeemCollateralForDsc()external{

  }
  function redeemCollateral()external{}
  function mintDsc()external{}
  function burnDsc()external {
  }
  function liquidate()external{

  }
  function getHealthFactor()external view{

  }

}