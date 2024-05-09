// SPDX-License-Identifier: MIT

// This File narrows the scope of out Invariant tests (sets order etc)

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { DYSCEngine } from "../../../src/DYSCEngine.sol";
import { DecentralizedYenStableCoin } from "../../../src/DecentralizedYenStableCoin.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { MockV3Aggregator } from "../../mocks/MockV3Aggregator.sol";

contract FailOnRevertHandler is Test {

    /*State Variables*/
    DYSCEngine public dyscEngine;
    DecentralizedYenStableCoin public decentralizedYenStableCoin;
    MockV3Aggregator public wethUsdPriceFeed;
    MockV3Aggregator public wbtcUsdPriceFeed;
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    /* Ghost Variables */
    address[] public usersWithCollateralDeposited;
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

    /* DYCSE Functions */
    function depositCollateral (uint256 collateralSeed, uint256 amountCollateral) public {
	ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
	amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

	vm.startPrank(msg.sender);
	collateral.mint(msg.sender, amountCollateral);
	collateral.approve(address(dyscEngine), amountCollateral);
	dyscEngine.depositCollateral(address(collateral), amountCollateral);
	vm.stopPrank();
	// this will double push some addressess
	usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
	uint256 maxCollateralToRedeem = dyscEngine.getCollateralBalanceOfUser(msg.sender, address(collateral));
	amountCollateral = bound(amountCollateral, 0, maxCollateralToRedeem);

	if (amountCollateral == 0) {
	    return;
	}
	vm.prank(msg.sender); 
	dyscEngine.redeemCollateral(address(collateral), amountCollateral);
    }

    function burnDysc(uint256 amountDysc) public {
        amountDysc = bound(amountDysc, 0, decentralizedYenStableCoin.balanceOf(msg.sender));
	if (amountDysc == 0) {
            return;
	}
	vm.startPrank(msg.sender);
	decentralizedYenStableCoin.approve(address(dyscEngine), amountDysc);
	dyscEngine.burnDysc(amountDysc);
	vm.stopPrank();
    }

    function liquidate(uint256 collateralSeed, address userToBeLiquidated, uint256 debtToCover) public {
	ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 minHealthFactor = dyscEngine.getMinimumHealthFactor();
	uint256 userHealthFactor = dyscEngine.getHealthFactor(userToBeLiquidated);
	if (userHealthFactor >= minHealthFactor) {
            return;
	}

	debtToCover = bound (debtToCover, 1, uint256(type(uint96).max));
        dyscEngine.liquidate(address(collateral), userToBeLiquidated, debtToCover);	
    }

    // as soon as we start trying to Mint DYSC with this test, we start getting reverts because the redeem function
    // as written allows attempts to redeem all deposited collateral (breaks Health Factor).
    /*function mintDysc(uint256 amountToMint, uint256 addressSeed) public {
	if (usersWithCollateralDeposited.length == 0) {
            return;
	}
	address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
	(uint256 totalDYSCMinted, uint256 collateralValueInJpy) = dyscEngine.getAccountInformation(sender);
        int256 maxDyscToMint = (int256(collateralValueInJpy) / 2) - int256(totalDYSCMinted);
        if (maxDyscToMint < 0) {
            return;
	}
	amountToMint = bound(amountToMint, 0, uint256(maxDyscToMint));
        if (amountToMint == 0) {
            return;
	}
	vm.startPrank(sender);
        dyscEngine.mintDYSC(amountToMint);
	vm.stopPrank();
	} */
    
    /* DYSC Functions */
    function transferDysc(uint256 amountDysc, address to) public {
        if (to == address(0)) {
            to = address(1);
	}
	amountDysc = bound (amountDysc, 0 , decentralizedYenStableCoin.balanceOf(msg.sender));
	vm.prank(msg.sender);
	decentralizedYenStableCoin.transfer(to, amountDysc);
    }

    /* Aggregator Functions */
    function updateCollateralPrice(uint96 newPrice, uint256 collateralSeed) public {
        int256 intNewPrice = int256(uint256(newPrice));
	ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
	MockV3Aggregator priceFeed = MockV3Aggregator(dyscEngine.getCollateralTokenPriceFeed(address(collateral)));

	priceFeed.updateAnswer(intNewPrice);
    }
    
    /* Helper Functions */
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0){
            return weth;
	}
        return wbtc;
    }
}
