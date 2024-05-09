// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { DeployDecentralizedYenStableCoin } from "../../../script/DeployDecentralizedYenStableCoin.s.sol";
import { DYSCEngine } from "../../../src/DYSCEngine.sol";
import { DecentralizedYenStableCoin } from "../../../src/DecentralizedYenStableCoin.sol";
import { HelperConfig } from "../../../script/HelperConfig.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ContinueOnRevertHandler } from "./continueOnRevertHandler.t.sol"; 
import { console } from "forge-std/console.sol";

contract ContinueOnRevertInvariants is StdInvariant, Test {
    DYSCEngine dyscEngine;
    DecentralizedYenStableCoin decentralizedYenStableCoin;
    HelperConfig helperConfig;
    ContinueOnRevertHandler handler;

    address weth;
    address wbtc;
    
    function setUp() external {
        DeployDecentralizedYenStableCoin deployer = new DeployDecentralizedYenStableCoin();
    	(decentralizedYenStableCoin, dyscEngine, helperConfig) = deployer.run();
	(,,, weth, wbtc,,) = helperConfig.activeNetworkConfig();
	handler = new ContinueOnRevertHandler(dyscEngine, decentralizedYenStableCoin);
	targetContract(address(handler));
    }

    /// forge-config: default.invariant.fail-on-revert = false
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

    /// forge-config: default.invariant.fail-on-revert = false
    function invariant_callSummary() public view {
	handler.callSummary();
    }
    
}
