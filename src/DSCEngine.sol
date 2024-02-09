//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;
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
contract DSCEngine{
  function depositColleteralAndMintDsc() external{}
  function depositCollateral()external{}


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