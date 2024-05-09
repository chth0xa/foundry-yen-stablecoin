// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import { Test, console } from "forge-std/Test.sol"; 
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { DeployDecentralizedYenStableCoin } from "../../../script/DeployDecentralizedYenStableCoin.s.sol";
import { DYSCEngine } from "../../../src/DYSCEngine.sol"; 
import { DecentralizedYenStableCoin } from "../../../src/DecentralizedYenStableCoin.sol";
import { HelperConfig } from "../../../script/HelperConfig.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FailOnRevertHandler } from "./failOnRevertHandler.t.sol"; 

contract FailOnRevertInvariants is StdInvariant, Test {
    DYSCEngine public dyscEngine;
    DecentralizedYenStableCoin public decentralizedYenStableCoin;
    HelperConfig public helperConfig;
    FailOnRevertHandler public handler;
    
    address public weth;
    address public wbtc;
    
    function setUp() external {
        DeployDecentralizedYenStableCoin deployer = new DeployDecentralizedYenStableCoin();
    	(decentralizedYenStableCoin, dyscEngine, helperConfig) = deployer.run();
	(,,, weth, wbtc,,) = helperConfig.activeNetworkConfig();
	handler = new FailOnRevertHandler(dyscEngine, decentralizedYenStableCoin);
	targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // get value of all the collateral
	// compare it to all the debt
	uint256 totalSupply = decentralizedYenStableCoin.totalSupply();
	uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dyscEngine));
	uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dyscEngine));

	uint256 wethValue = dyscEngine.getJpyValue(weth, totalWethDeposited);
       	uint256 wbtcValue = dyscEngine.getJpyValue(wbtc, totalWbtcDeposited);

	console.log("weth vlaue:", wethValue);
	console.log("wbtc vlaue:", wbtcValue);
	console.log("total supply:", totalSupply);
	
	assert (wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShouldNotRevert() public view {
	//This should be all of our getter functions
        dyscEngine.getBaseFeedDecimals();
	dyscEngine.getAdditionalPriceFeedPrecision();
	dyscEngine.getPrecision();
	dyscEngine.getLiquidationThreshold();
	dyscEngine.getLiquidationPrecision();
	dyscEngine.getMinimumHealthFactor();
	dyscEngine.getLiquidationBonus();
	dyscEngine.getDysc();
	dyscEngine.getCollateralTokens();
    }
}
