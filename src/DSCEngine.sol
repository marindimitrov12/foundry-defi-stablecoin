//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin}from"./DecentralizedStableCoin.sol";
//import {ReentrancyGuard}from"@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20}from"@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface}from"@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
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
contract DSCEngine {
  ///////////////
  // Errors    //  
  /////////////// 
 error DSCEngine__NeedsMoreThanZero();
 error DSCEngine__TokenAddresessAndPriceFeedAddressesMustBeSameLength();
 error DSCEngine__NotAllowedToken();
 error DSCEngine__TransferFailed();
 error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
 error DSCEngine__MintFailed();
 error DSCEngine__HealthFactorOk();

  /////////////////////
  // State Variables //  
  ///////////////////// 
  uint256 private constant ADDITIONAL_FEED_PRECISION=10;
  uint256 private constant PRECISION=1e18;
  uint256 private constant LIQUIDATION_THRESHOLD=50;
  uint256 private constant LIQUIDATION_PRICISION=100;
  uint256 private constant MIN_HEALT_FACTOR=1e18;
  uint256 private constant LIQUIDATION_BONUS=10//this means 10% bonus

  mapping(address token=>address priceFeed)private s_priceFeeds;//tokenToPriceFeed
  mapping(address user=>mapping(address token=>uint256 amount))
  private s_collateralDeposited;
  DecentralizedStableCoin private immutable i_dsc;
  mapping (address user=>uint256 amountDscMinted)private s_DSCMinted;
  address[]private s_collateralTokens;
 /////////////////////
  // Events //  
  ///////////////////// 

 event CollateralDeposited(address indexed user,address indexed token,uint256 indexed amount);
 event CollateralRedeemed(address indexed user,uint256 indexed amountCollateral,address indexed tokenCollateralAddress);

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
        s_collateralTokens.push(tokenAddresses[i]);
     }
     i_dsc=DecentralizedStableCoin(dscAddress);
  }

  ////////////////////////
  // External Functions //  
  ////////////////////////

  /**
   * 
   * @param tokenCollateralAddress The address of the token to deposit as a collateral
   * @param amountColateral The amount of the collateral to deposit
   * @param amountDscToMint The amount of dsc to be minted
   * @notice This function will deposit collateral and mint dsc in one transaction.
   */
  function depositColleteralAndMintDsc(
    address tokenCollateralAddress,
    uint256 amountColateral,
    uint256 amountDscToMint) external{
       
       depositCollateral(tokenCollateralAddress,amountColateral);
       mintDsc(amountDscToMint);
    }
  /*
   * @notice follows CEI
   * @param tokenCollateralAddress The address of the token to deposit as collateral
   * @param amountCollateral The amount of collateral to deposit
   */
  function depositCollateral(
    address tokenCollateralAddress,
    uint256 amountCollateral)public 
    moreThanZero(amountCollateral) 
    isAllowedToken(tokenCollateralAddress)
    {
       s_collateralDeposited[msg.sender][tokenCollateralAddress]+=amountCollateral;
       emit CollateralDeposited(msg.sender,tokenCollateralAddress,amountCollateral);
       bool success=IERC20(tokenCollateralAddress).transferFrom(msg.sender,address(this),amountCollateral);
       if(!success){
         revert DSCEngine__TransferFailed();
       }
    }


  /**
   * 
   * @param tokenCollateralAddress The collateral address to redeem
   * @param amountCollateral The amount of collateral to redeem
   * @param amountDscToBurn The amount of DSC to burn
   * @notice This function burns DSC and redeems underlying collateral in one transaction
   */
  function redeemCollateralForDsc(address tokenCollateralAddress,
  uint256 amountCollateral,
  uint256 amountDscToBurn)external{
    burnDsc(amountDscToBurn);
    redeemCollateral(tokenCollateralAddress,amountCollateral);
    //redeemCollateral alreadychecks health factor.
  }
  //in order to redeem collateral:
  //1.health factor must be over 1 AFTER collatearl pulled
  //CEI:Checks,Effects,Interactions
  function redeemCollateral(address tokenCollateralAddress,uint256 amountCollateral)
  public moreThanZero(amountCollateral)
  {
    //this is internal accounting how much collateral they added.
     s_collateralDeposited[msg.sender][tokenCollateralAddress]-=amountCollateral;
     emit CollateralRedeemed(msg.sender,amountCollateral,tokenCollateralAddress);
     //_calculateHealthFactor();
     bool success=IERC20(tokenCollateralAddress).transfer(msg.sender,amountCollateral);

     if(!success){
        revert DSCEngine__TransferFailed();
     }
     _revertIfhealthFactorIsBroken(msg.sender);
  }
  /*
   * @notice follows CEI
   * @param amountDscToMint The amount of dsc to mint
   * @notice they must have more colateral value than the minimum threshold
   */
  function mintDsc(uint256 amountDscToMint)public moreThanZero(amountDscToMint){
      s_DSCMinted[msg.sender]+=amountDscToMint;
      _revertIfhealthFactorIsBroken(msg.sender);
      bool minted=i_dsc.mint(msg.sender,amountDscToMint);
      if(!minted){
          revert DSCEngine__MintFailed();
      }
  }
  function burnDsc(uint256 amount)public moreThanZero(amount){
    s_DSCMinted[msg.sender]-=amount;
    bool success=i_dsc.transferFrom(msg.sender,address(this),amount);
    if(!success){
      revert DSCEngine__TransferFailed();
    }
    i_dsc.burn(amount);
    _revertIfhealthFactorIsBroken(msg.sender);
  }

  //if someone is almost undercollateralized, we will pay you to liquidate them!
  /**
   * 
   * @param collateral The erc20 collateral address to liquidate from the user.
   * @param user The user who has broken the health factor.Their _healthFactor should be below MIN_HEALTH_FACTOR.
   * @param debtToCover The amount of debt you want to burn to improve the users health factor.
   * @notice You can partially liquidate a user.
   * @notice You will get a liquidation bonus for taking users funds.
   * @notice This function assumes the protocol will be roughly 200%
     over collateralized in order for this to work.
     Follows CEI:Checks,Effects,Interactions
   */
  function liquidate(address collateral,address user,uint256 debtToCover)
  external moreThanZero(debtToCover){
    //need to check the health factor of the user.
    uint256 startingUserHealthFactor=_healthFactor(user);
    if(startingUserHealthFactor>=MIN_HEALT_FACTOR){
       revert DSCEngine__HealthFactorOk();
    }
    //we want to burn their DSC "debt"
    //and take their collateral
    uint256 tokenAmountOfDebtCovered=getTokenAmountFromUsd(collateral,debtToCover);
    //And give them 10% bonus
    //So we are giving the liquidator $110 of WETH for 100 DSC
    uint256 bonusCollateral=(tokenAmountFromDebtCovered*LIQUIDATION_BONUS)/LIQUIDATION_PRICISION;
    uint256 totalCollateralToRedeem=tokenAmountFromDebtCovered+bonusCollateral;
        
  }
  function getHealthFactor()external view{
    


  }

  /////////////////////////////////////////
  // Private and Internal View Functions //
  /////////////////////////////////////////

  /*
   * Returns how close to liquidation a user is
   * @param user 
   * If a user goes below 1, then they can get liquidated
   */

  function _getAccountInformation(address user)
  private
   view 
   returns(uint256 totalDscMinted,uint256 collateralValueInUsd){
    totalDscMinted=s_DSCMinted[user];
    collateralValueInUsd=getAccountCollateralValue(user);
   }
  function _healthFactor(address user)private view returns (uint256){
    (uint256 totalDscMinted,uint256 collatearlValueInUsd)=_getAccountInformation(user);
    uint256 collateralAdjustedForThreshold=(collatearlValueInUsd*LIQUIDATION_THRESHOLD)/LIQUIDATION_PRICISION;
    return  (collateralAdjustedForThreshold*PRECISION/totalDscMinted); 
  }

  function _revertIfhealthFactorIsBroken(address user)internal view{
    uint256 userHealthFactor=_healthFactor(user);
    if(userHealthFactor<MIN_HEALT_FACTOR){
       revert DSCEngine__BreaksHealthFactor(userHealthFactor);
    }

  } 
  /////////////////////////////////////
  // Public & External View Function //
  /////////////////////////////////////

  function getTokenAmountFromUsd(address token,uint256 usdAmountInWei)public view returns(uint256){

     AggregatorV3Interface priceFeed=AggregatorV3Interface(s_priceFeeds[token]);
     (,int256 price,,,)=priceFeed.latestRoundData();
     return(usdAmountInWei*PRECISION)/(uint256(price)*ADDITIONAL_FEED_PRECISION);
  }

  function getAccountCollateralValue(address user)public view returns(uint256 totalCollateralValueInUsd ){
    
    for(uint256 i=0;i<s_collateralTokens.length;i++){
        address token =s_collateralTokens[i];
        uint256 amount=s_collateralDeposited[user][token];
        totalCollateralValueInUsd+=getUsdValue(token,amount);
    }
    return totalCollateralValueInUsd;
  }
  function getUsdValue(address token,uint256 amount)public view returns(uint256){
    AggregatorV3Interface priceFeed=AggregatorV3Interface(s_priceFeeds[token]);
    (,int256 price,,,)=priceFeed.latestRoundData();
    return ((uint256(price)*ADDITIONAL_FEED_PRECISION)*amount)/PRECISION;
  }
}