// SPDX-License-Identifier: MIT

// This File narrows teh scope of out Invariant tests (sets order etc)

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { DYSCEngine } from "../../../src/DYSCEngine.sol";
import { DecentralizedYenStableCoin } from "../../../src/DecentralizedYenStableCoin.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { MockV3Aggregator } from "../../mocks/MockV3Aggregator.sol";
import { console } from "forge-std/console.sol";

contract ContinueOnRevertHandler is Test {

    /*State Variables*/
    DYSCEngine public dyscEngine;
    DecentralizedYenStableCoin public decentralizedYenStableCoin;
    MockV3Aggregator public wethUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    /* Ghost Variables */
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max; //allows to hit large number but not hit uint256 ceiling.


    /* Functions */
    constructor(DYSCEngine _dyscEngine, DecentralizedYenStableCoin _decentralizedYenStableCoin) {
        dyscEngine = _dyscEngine;
	decentralizedYenStableCoin = _decentralizedYenStableCoin;

	address[] memory collateralTokens = dyscEngine.getCollateralTokens();
	weth = ERC20Mock(collateralTokens[0]);
	wbtc = ERC20Mock(collateralTokens[1]);

	wethUsdPriceFeed = MockV3Aggregator(dyscEngine.getCollateralTokenPriceFeed(address(weth)));
	wbtcUsdPriceFeed = MockV3Aggregator(dyscEngine.getCollateralTokenPriceFeed(address(wbtc)));
    }

    /* Functions */

    /* Functions DYSCEngine */
    function depositCollateral (uint256 collateralSeed, uint256 amountCollateral) public {
	ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
	amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);

       	collateral.mint(msg.sender, amountCollateral);
	collateral.approve(address(dyscEngine), amountCollateral);
	dyscEngine.depositCollateral(address(collateral), amountCollateral);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
	ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);
	dyscEngine.redeemCollateral(address(collateral), amountCollateral);
    }

    function burnDysc(uint256 amountDysc) public {
        amountDysc = bound(amountDysc, 0, decentralizedYenStableCoin.balanceOf(msg.sender));
	dyscEngine.burnDysc(amountDysc);
    }

    function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
	ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
	dyscEngine.liquidate(address(collateral), userToBeLiquidated, debtToCover);
    }

    function mintDysc(uint256 amountDysc) public {
        amountDysc = bound(amountDysc, 0, MAX_DEPOSIT_SIZE);
	dyscEngine.mintDysc(amountDysc);
    }

    /* DYSC Functions */

    /* Aggregator */
    

    /* Helper Functions */
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0){
            return weth;
	}
        return wbtc;
    }

    function callSummary() external view {
	console.log("Weth total deposited", weth.balanceOf(address(dyscEngine)));
	console.log("Wbtc total deposited", wbtc.balanceOf(address(dyscEngine)));
	console.log("Total supply of DYSC", decentralizedYenStableCoin.totalSupply());
    }
}
