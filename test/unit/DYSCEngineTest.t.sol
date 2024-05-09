// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import { Test, console } from "forge-std/Test.sol";
import { DeployDecentralizedYenStableCoin } from "../../script/DeployDecentralizedYenStableCoin.s.sol";
import { DecentralizedYenStableCoin } from "../../src/DecentralizedYenStableCoin.sol";
import { DYSCEngine } from "../../src/DYSCEngine.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";
import { MockFailedTransferFrom } from "../mocks/MockFailedTransferFrom.sol";
import { MockMoreDebtDYSC } from "../mocks/MockMoreDebtDYSC.sol";
import { MockFailedMintDYSC } from "../mocks/MockFailedMintDYSC.sol";

contract DYSCEngineTest is Test {
    DeployDecentralizedYenStableCoin deployDecentralizedYenStableCoin;
    DecentralizedYenStableCoin decentralizedYenStableCoin;
    DYSCEngine dyscEngine;
    HelperConfig helperConfig;

    address public weth;
    address public wbtc;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public jpyUsdPriceFeed;
    uint256 public jpyToWeth;

    address public USER = makeAddr("user");
    address public ALTUSER = makeAddr("altuser");
    uint256 public amountCollateral = 10 ether;
    uint256 public dyscToMint;
    // liquidation
    uint256 public liquidateDyscToMint = 20000 ether;
    uint256 public amountCollateralToCover = 20 ether;

    //math
    uint256 public calcPrecision = 1e18;
    
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount);
    
    function setUp() external {
        deployDecentralizedYenStableCoin = new DeployDecentralizedYenStableCoin();
	(decentralizedYenStableCoin, dyscEngine, helperConfig) = deployDecentralizedYenStableCoin.run();
	//(wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, deployerKey, deployerAddress) = helperConfig.activeNetworkConfig();
	// saved the above in incase we need to rearrange or add things back in later to the code below.
	(ethUsdPriceFeed, btcUsdPriceFeed, jpyUsdPriceFeed, weth, wbtc,,) = helperConfig.activeNetworkConfig();
	ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
	
        // getUsdValueOfWETH
        MockV3Aggregator wethPriceFeed = MockV3Aggregator(ethUsdPriceFeed);
	(,int256 wethPrice,,,) = wethPriceFeed.latestRoundData();
	// getJpyToUsd
        MockV3Aggregator jpyPriceFeed = MockV3Aggregator(jpyUsdPriceFeed);
	(,int256 jpyPrice,,,) = jpyPriceFeed.latestRoundData();

	jpyToWeth = ((((uint256(wethPrice) * 1e8) / uint256(jpyPrice)) * 1e10) * 1 ether) / 1e18;
	dyscToMint = ((amountCollateral / 2) * jpyToWeth) / calcPrecision; 
    }

    modifier depositedCollateral() {
	vm.startPrank(USER);
	ERC20Mock(weth).approve(address(dyscEngine), amountCollateral);
	dyscEngine.depositCollateral(address(weth), amountCollateral);
	vm.stopPrank();
	_;
    }

    modifier mintedDysc() {
        vm.startPrank(USER);
	dyscEngine.mintDysc(dyscToMint);
	vm.stopPrank();
	_;
    }

    /* DYSC Owner Test */
    function testDeployScriptsSetsDYSCEngineAsDyscOwner() public {
        address owner = decentralizedYenStableCoin.owner();
	assertEq(owner, address(dyscEngine));
    }
    
    /* Constructor Test */
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    
    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
	priceFeedAddresses.push(ethUsdPriceFeed);
	priceFeedAddresses.push(btcUsdPriceFeed);

	vm.expectRevert(DYSCEngine.DYSCEngine__TokenArrayMustBeSameLengthAsPriceFeedAddressArray.selector);
	new DYSCEngine(tokenAddresses, priceFeedAddresses, jpyUsdPriceFeed, address(decentralizedYenStableCoin));
    }

    /* Variable Getter Function Tests */
    function testGetCollateralTokens() public {
	address[] memory collateralTokenAddresses = dyscEngine.getCollateralTokens();

	assertEq(collateralTokenAddresses[0], weth);
	assertEq(collateralTokenAddresses[1], wbtc);
    }

    function testGetDyscAddress() public {
        address dyscAddress = dyscEngine.getDysc();

	assertEq(dyscAddress, address(decentralizedYenStableCoin));
    }

    function testGetCollateralTokenPriceFeed() public {
        address priceFeedAddress = dyscEngine.getCollateralTokenPriceFeed(weth);

	assertEq(priceFeedAddress, ethUsdPriceFeed);
    }
    
    function testGetBaseFeedDecimals() public {
        uint256 precision = dyscEngine.getBaseFeedDecimals();

	assertEq(precision, 1e8);
    }

    function testGetCollateralBalanceOfUser() public depositedCollateral {
        uint256 userBalance = dyscEngine.getCollateralBalanceOfUser(USER, weth);

	assertEq(userBalance, amountCollateral);
    }
    
    function testGetAdditionalPriceFeedPrecision() public {
        uint256 additionPriceFeedPrecision = dyscEngine.getAdditionalPriceFeedPrecision();

	assertEq(additionPriceFeedPrecision, 1e10);
    }

    function testGetPrecision() public {
        uint256 precision = dyscEngine.getPrecision();

	assertEq(precision, 1e18);
    }

    function testGetLiquidationThreshold() public {
        uint256 liquidationThreshold = dyscEngine.getLiquidationThreshold();

	assertEq(liquidationThreshold, 50);
    }
    
    function testGetLiquidationPrecision() public {
        uint256 liquidationPrecision = dyscEngine.getLiquidationPrecision();

	assertEq(liquidationPrecision, 100);
    }

    function testGetMinimumHealthFactor() public {
        uint256 minimumHealthFactor = dyscEngine.getMinimumHealthFactor();

	assertEq(minimumHealthFactor, 1e18);
    }

    function testGetLiquidationBonus() public {
        uint256 liquidationBonus = dyscEngine.getLiquidationBonus();

	assertEq(liquidationBonus, 10);
    }

    function testCalculateHealthFactor() public {
	uint256 expectedHealthFactor = dyscEngine.getMinimumHealthFactor();
	uint256 collateralValueInJpy = dyscEngine.getJpyValue(weth, amountCollateral);
        uint256 calculatedHealthFactor = dyscEngine.calculateHealthFactor(dyscToMint, collateralValueInJpy);
	assertEq(calculatedHealthFactor, expectedHealthFactor); 
    }
    
    /* PriceFeed Tests */
    function testGetJpyValue() public returns (uint256) {
        uint256 ethAmount = 1 ether;
	uint256 expectedJpy = 400000 ether;
	uint256 actualJpy = dyscEngine.getJpyValue(weth, ethAmount);
	assertEq(actualJpy, expectedJpy);
	assertEq(actualJpy, jpyToWeth);
	return dyscToMint;
    }

    function testGetTokenAmountFromJpy() public {
        uint256 jpyAmount = 20000 ether;
	// $2000 / ETH, $100 = 0.05
	uint256 expectedWeth = 0.05 ether;
	uint256 actualWeth = dyscEngine.getTokenAmountFromJpy(weth, jpyAmount);
	assertEq(actualWeth, expectedWeth);
    }

    function testGetAccountCollateralValue() public depositedCollateral {
	uint256 actualCollateralValueInJpy = dyscEngine.getAccountCollateralValue(USER);
	uint256 expectedCollateralValueInJpy = dyscEngine.getJpyValue(weth, amountCollateral);
	
	assertEq(actualCollateralValueInJpy, expectedCollateralValueInJpy);
    }

    /* Deposit Collateral Tests */
    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
	// Deposit Collateral Calls transferFrom, so DYSCEngine must be approved.
	ERC20Mock(weth).approve(address(dyscEngine), amountCollateral);

	vm.expectRevert(DYSCEngine.DYSCEngine__MustBeMoreThanZero.selector);
	dyscEngine.depositCollateral(weth, 0);
	vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock badToken = new ERC20Mock("BAD", "BAD");
	badToken.mint(USER, amountCollateral);
	vm.expectRevert(DYSCEngine.DYSCEngine__TokenNotAllowed.selector);
	vm.startPrank(USER);
	dyscEngine.depositCollateral(address(badToken), amountCollateral);
	vm.stopPrank();
    }
    
    function testCanDepositCollateralAndGetAccountInfo() public {
	vm.startPrank(USER);
	ERC20Mock(weth).approve(address(dyscEngine), amountCollateral);
	dyscEngine.depositCollateral(address(weth), amountCollateral);
	vm.stopPrank();
	
        (uint256 totalDyscMinted, uint256 collateralValueInUsd) = dyscEngine.getAccountInformation(USER);

	uint256 expectedTotalDyscMinted = 0;
	uint256 expectedDepositAmount = dyscEngine.getTokenAmountFromJpy(weth, collateralValueInUsd);
	
	assertEq(totalDyscMinted, expectedTotalDyscMinted);
	assertEq(amountCollateral, expectedDepositAmount);
    }

    function testDepositCollateralEmitsCorrectInfo() public {
	address tokenCollateralAddress = weth;
	uint256 emitAmountCollateral =  amountCollateral;
	    
        vm.startPrank(USER);
	ERC20Mock(weth).approve(address(dyscEngine), amountCollateral);
	vm.expectEmit(true, true, true, false, address(dyscEngine));
	emit CollateralDeposited(USER, tokenCollateralAddress, emitAmountCollateral);
	dyscEngine.depositCollateral(address(weth), amountCollateral);
	vm.stopPrank();
    }

    function testDepositCollateralRevertsIfTransferFails() public {
        address owner = msg.sender;
	vm.prank(owner);
	MockFailedTransferFrom mockDysc = new MockFailedTransferFrom(owner);
	tokenAddresses = [address(mockDysc)];
	priceFeedAddresses = [ethUsdPriceFeed];

	vm.startPrank(owner);
	DYSCEngine mockDysce = new DYSCEngine(
	    tokenAddresses,
	    priceFeedAddresses,
	    jpyUsdPriceFeed,
	    address(mockDysc)
	);
	mockDysc.mint(USER, amountCollateral);

        mockDysc.transferOwnership(address(mockDysce));
        vm.stopPrank();	

	vm.startPrank(USER);
	ERC20Mock(address(mockDysc)).approve(address(mockDysce), amountCollateral);
	
	vm.expectRevert(DYSCEngine.DYSCEngine__TranferFailed.selector);
	mockDysce.depositCollateral(address(mockDysc), amountCollateral);
	vm.stopPrank();
    }

    /* Deposit Collateral And Mint DYSC */
     function testdepositCollateralAndMintDYSC() public {
	uint256 expectedTotalDyscMinted = (5 ether * jpyToWeth) / calcPrecision;
	uint256 expectedCollateralValueinJpy = (amountCollateral * jpyToWeth) / calcPrecision;

	vm.startPrank(USER);
	ERC20Mock(weth).approve(address(dyscEngine), amountCollateral);
	dyscEngine.depositCollateralAndMintDysc(address(weth), amountCollateral, dyscToMint);
	vm.stopPrank();

	( uint256 actualtotalDYSCMinted, uint256 actualCollateralValueinJpy) = dyscEngine.getAccountInformation(USER);
	uint256 actualHealthFactor = dyscEngine.getHealthFactor(USER);

	uint256 expectedHealthFactor = 1e18;
		
	assertEq(expectedHealthFactor, actualHealthFactor);
	assertEq(actualtotalDYSCMinted, expectedTotalDyscMinted);
	assertEq(actualCollateralValueinJpy, expectedCollateralValueinJpy);
    }    

    /* Redeem Collateral Tests */
    function testRedeemCollateralRedeemsCollateralAsExpected() public depositedCollateral {
        uint256 amountDyscToMint = 2000 ether;
	uint256 valueCollateralToRedeem = 1 ether;

	vm.startPrank(USER);
	dyscEngine.mintDysc(amountDyscToMint);
	dyscEngine.redeemCollateral(weth, valueCollateralToRedeem);
        vm.stopPrank();

	uint256 estimatedCollateralValue = 3600000 ether;
	uint256 estimatedDyscValue = 2000 ether;

	( uint256 actualDyscValue, uint256 actualCollateralValue) = dyscEngine.getAccountInformation(USER);

	assertEq(actualCollateralValue, estimatedCollateralValue);
	assertEq(actualDyscValue, estimatedDyscValue);
    }
     
    function testRedeemCollateralRevertsIfHealthFactorIsBroken() public depositedCollateral mintedDysc {
	uint256 valueCollateralToRedeem = 1 ether;
	uint256 amountToRedeemInJpy = dyscEngine.getJpyValue(weth, valueCollateralToRedeem);
	(uint256 totalDyscMinted, uint256 collateraValueInJpy) = dyscEngine.getAccountInformation(USER);
        uint256 adjustedCollateralValueInJpy = collateraValueInJpy - amountToRedeemInJpy;
	
	uint256 expectedHealthFactor = dyscEngine.calculateHealthFactor(totalDyscMinted, adjustedCollateralValueInJpy);
	 
	vm.startPrank(USER);
        vm.expectRevert(abi.encodeWithSelector(DYSCEngine.DYSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
	dyscEngine.redeemCollateral(weth, valueCollateralToRedeem);
        vm.stopPrank();

	uint256 collateralBalance = dyscEngine.getCollateralBalanceOfUser(USER, weth);
	assertEq(amountCollateral, collateralBalance);
    }

    // this causes panic underfow or overflow
    function testRedeemCollateralRevertsIfNotEnoughCollateralToRedeem() public depositedCollateral {
	uint256 valueCollateralToRedeem = 11 ether;

	vm.startPrank(USER);
	vm.expectRevert();
	dyscEngine.redeemCollateral(weth, valueCollateralToRedeem);
        vm.stopPrank();
    }
    
    /* Redeem Collateral For DYSC Tests */
    function testRedeemCollateralForDYSCRedeemsCollateralandBurnsDYSC() public depositedCollateral mintedDysc {
        uint256 amountCollateralToRedeem = 2 ether;
	uint256 amountDyscToBurn = (amountCollateralToRedeem * jpyToWeth) / calcPrecision;
	    
	vm.startPrank(USER);
	decentralizedYenStableCoin.approve(address(dyscEngine), amountDyscToBurn);
        dyscEngine.redeemCollateralForDysc(weth, amountCollateralToRedeem, amountDyscToBurn);
	vm.stopPrank();

	// 1200000 ether on anvil
	uint256 estimatedDyscRemaining = dyscToMint - amountDyscToBurn;
	// 32000000 ether on anvil
	uint256 estimatedCollateralValueInJpy = ((amountCollateral - amountCollateralToRedeem) * jpyToWeth) / calcPrecision;
	(uint256 actualDyscRemaining,uint256 actualCollateralValueInJpy) = dyscEngine.getAccountInformation(USER);
        
        assertEq(actualDyscRemaining, estimatedDyscRemaining);
	assertEq(actualCollateralValueInJpy, estimatedCollateralValueInJpy);
    } 
    
    /* Liquidate Collateral Test */
    function testLiqudateRevertsIfHealthFactorIsNotBroken() public depositedCollateral mintedDysc {
        deal(weth, ALTUSER, amountCollateral);

	vm.expectRevert(DYSCEngine.DYSCEngine__HealthFactorOkay.selector);
        vm.startPrank(ALTUSER);
	dyscEngine.liquidate(weth, USER, 5 ether);
	vm.stopPrank();
    }

    function testLiquidationMustImproveHealthFactor() public {
	// Arrange Mock
	address owner = msg.sender;
        MockMoreDebtDYSC mockDysc = new MockMoreDebtDYSC(ethUsdPriceFeed, owner);
	tokenAddresses = [weth];
	priceFeedAddresses = [ethUsdPriceFeed];
	vm.startPrank(owner);
	DYSCEngine mockDysce = new DYSCEngine(
	    tokenAddresses,
	    priceFeedAddresses,
	    jpyUsdPriceFeed,
	    address (mockDysc)
	);
	mockDysc.transferOwnership(address(mockDysce));
	vm.stopPrank();
	
	// Arrange User
	vm.startPrank(USER);
	ERC20Mock(weth).approve(address(mockDysce), amountCollateral);
   	mockDysce.depositCollateralAndMintDysc(weth, amountCollateral, dyscToMint);
	vm.stopPrank();

	// Arrange Liquidator
	uint256 collateralToCover = 1 ether;
	uint256 amountToMint = 100 ether;
        uint256 debtToCover = 10 ether;
	deal(weth, ALTUSER, collateralToCover);

	vm.startPrank(ALTUSER);
	ERC20Mock(weth).approve(address(mockDysce), collateralToCover);
	mockDysce.depositCollateralAndMintDysc(weth, collateralToCover, amountToMint);
	mockDysc.approve(address(mockDysce), debtToCover);

	//Act
	int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
	MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

	//Act Assert
	vm.expectRevert(DYSCEngine.DYSCEngine__HealthFactorNotImproved.selector);
	mockDysce.liquidate(weth, USER, debtToCover);
	vm.stopPrank();
    }
  
    modifier liquidated() {
	deal(weth, ALTUSER,  amountCollateralToCover);

	vm.startPrank(USER);
	ERC20Mock(weth).approve(address(dyscEngine), amountCollateral);
	dyscEngine.depositCollateralAndMintDysc(weth, amountCollateral, liquidateDyscToMint);
	vm.stopPrank();
	int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

	MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
	uint256 userHealthFactor = dyscEngine.getHealthFactor(USER);
        (uint256 totalDYSCMinted, uint256 collateralValueInJpy) = dyscEngine.getAccountInformation(USER);
	
	vm.startPrank(ALTUSER);
        ERC20Mock(weth).approve(address(dyscEngine), amountCollateralToCover);
	dyscEngine.depositCollateralAndMintDysc(weth, amountCollateralToCover, liquidateDyscToMint);
	decentralizedYenStableCoin.approve(address(dyscEngine), liquidateDyscToMint);
	dyscEngine.liquidate(weth, USER, liquidateDyscToMint); // We are covering entire debt
	vm.stopPrank();
        _;
    }
    
    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 altUserWethBalance = ERC20Mock(weth).balanceOf(ALTUSER);
    	uint256 expectedWeth = dyscEngine.getTokenAmountFromJpy(weth, liquidateDyscToMint)
    	    + (dyscEngine.getTokenAmountFromJpy(weth, liquidateDyscToMint) / dyscEngine.getLiquidationBonus());
	uint256 hardCodedExpected = 6111111111111111110;
	assertEq(altUserWethBalance, hardCodedExpected);
	assertEq(altUserWethBalance, expectedWeth);
    }
    
    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
	// How much did USER lose?
        uint256 amountLiquidated = dyscEngine.getTokenAmountFromJpy(weth, liquidateDyscToMint)
	+ (dyscEngine.getTokenAmountFromJpy(weth, liquidateDyscToMint) / dyscEngine.getLiquidationBonus());

	uint256 jpyAmountLiquidated = dyscEngine.getJpyValue(weth, amountLiquidated);
	uint256 expectedUserCollateralValueInJpy = dyscEngine.getJpyValue(weth, amountCollateral) - (jpyAmountLiquidated);

	(, uint256 userCollateralValueInJpy) = dyscEngine.getAccountInformation(USER);
	uint256 hardCodedExpectedValue = 14000000000000000004000;
	assertEq(userCollateralValueInJpy, expectedUserCollateralValueInJpy);
	assertEq(userCollateralValueInJpy, hardCodedExpectedValue);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorDyscMinted,) = dyscEngine.getAccountInformation(ALTUSER);
        assertEq(liquidatorDyscMinted, liquidateDyscToMint);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userDyscMinted,) = dyscEngine.getAccountInformation(USER);
	assertEq(userDyscMinted, 0);
    }
    
    /* Mint DYSC Tests */
    function testCanMintDYSCWithEnoughCollateral() public depositedCollateral {
        uint256 expectedDyscBalance = (5 ether * jpyToWeth) / calcPrecision;
	vm.startPrank(USER);
	dyscEngine.mintDysc(dyscToMint);
	vm.stopPrank();
	
	//uint256 expectedDyscBalance = amountDyscToMint;
	uint256 actualDyscBalance = decentralizedYenStableCoin.balanceOf(USER);
	 
	assertEq(actualDyscBalance, expectedDyscBalance);
    }
 
    function testMintRevertsIfNotGreaterThanZero() public depositedCollateral {
	uint256 amountToMint = 0;
        vm.expectRevert(DYSCEngine.DYSCEngine__MustBeMoreThanZero.selector);
	vm.startPrank(USER);
	dyscEngine.mintDysc(amountToMint);
	vm.stopPrank();
    }

    function testMintRevertsIfHealthFactorIsBroken() public depositedCollateral {
        uint256 amountToMint = (((amountCollateral / 2) + 1) * jpyToWeth) / calcPrecision;
	(uint256 existingDyscMinted, uint256 collateraValueInJyp) = dyscEngine.getAccountInformation(USER);
	uint256 expectedHealthFactor = dyscEngine.calculateHealthFactor((amountToMint + existingDyscMinted), collateraValueInJyp);
	
        vm.expectRevert(abi.encodeWithSelector(DYSCEngine.DYSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
	vm.startPrank(USER);
	dyscEngine.mintDysc(amountToMint);
	vm.stopPrank();
    }

    function testRevertsIfMintFails() public {
        //Arrange setup
	address owner = msg.sender;
	tokenAddresses = [weth];
	priceFeedAddresses = [ethUsdPriceFeed];
	MockFailedMintDYSC mockDysc = new MockFailedMintDYSC(owner);
	vm.startPrank(owner);
        DYSCEngine mockDysce = new DYSCEngine(
	    tokenAddresses,
	    priceFeedAddresses,
	    jpyUsdPriceFeed,
	    address(mockDysc)
	);
	mockDysc.transferOwnership(address(mockDysce));
        vm.stopPrank();
	    
	//Arrange user
	vm.startPrank(USER);
	ERC20Mock(weth).approve(address(mockDysce), amountCollateral);

	vm.expectRevert(DYSCEngine.DYSCEngine__MintFailed.selector);
	mockDysce.depositCollateralAndMintDysc(weth, amountCollateral, dyscToMint);
	vm.stopPrank();
    }

    /* Burn DYSC tests */
    function testBurnDYSCMustBurnMoreThanZero() public depositedCollateral mintedDysc {
	uint256 burnAmount = 0;
	vm.expectRevert(DYSCEngine.DYSCEngine__MustBeMoreThanZero.selector);
        dyscEngine.burnDysc(burnAmount);
    }

    function testCanBurnDYSCAndItImprovesHealthFactor() public depositedCollateral mintedDysc {
	(uint256 totalDyscMinted,) = dyscEngine.getAccountInformation(USER);
        uint256 startingHealthFactor = dyscEngine.getHealthFactor(USER);
        uint256 burnAmount = totalDyscMinted / 2;
	
	vm.startPrank(USER);
	decentralizedYenStableCoin.approve(address(dyscEngine), burnAmount);
	dyscEngine.burnDysc(burnAmount);
	vm.stopPrank();
	
	uint256 endingHealthFactor = dyscEngine.getHealthFactor(USER);
        uint256 endingDyscBalance = decentralizedYenStableCoin.balanceOf(USER);
	
	assert(endingHealthFactor > startingHealthFactor);
	assertEq((totalDyscMinted / 2), endingDyscBalance);
    }

    function testCannotBurnMoreDYSCThanHas() public depositedCollateral mintedDysc {
	(uint256 totalDyscMinted,) = dyscEngine.getAccountInformation(USER);
        uint256 burnAmount = totalDyscMinted + 1 ether;

	vm.startPrank(USER);
	decentralizedYenStableCoin.approve(address(dyscEngine), burnAmount);
        vm.expectRevert(); // arithmetic underflow or overflow
	dyscEngine.burnDysc(burnAmount);
	vm.stopPrank();
    }

    /////
    
    /////
    /*
     *I cant think of a way to make this work. Mint will always trigger the
     *failed transferFrom before I can try to trigger with burn.
     *
    function testRevertsIfBurnFails() public {
        //Arrange setup
	address owner = msg.sender;
	vm.prank(owner);
	MockFailedTransferFrom mockDysc = new MockFailedTransferFrom(owner);
	tokenAddresses = [address(mockDysc)];
	priceFeedAddresses = [ethUsdPriceFeed];

	vm.startPrank(owner);
	DYSCEngine mockDysce = new DYSCEngine(
	    tokenAddresses,
	    priceFeedAddresses,
	    jpyUsdPriceFeed,
	    address(mockDysc)
	);
	mockDysc.mint(USER, amountCollateral);
	    
	//Arrange user
	vm.startPrank(USER);
	ERC20Mock(weth).approve(address(mockDysce), amountCollateral);

	vm.expectRevert(DYSCEngine.DYSCEngine__TranferFailed.selector);
	mockDysce.burnDysc(dyscToMint);
	vm.stopPrank();
    }
    ////
    ////
    */
    
    /* getHealthFactor Tests */
    function testGetHealthFactorReturnsExpectedResult() public depositedCollateral mintedDysc {
       	uint256 expectedHealthFactor = 1e18; //  1000000000000000000
	uint256 actualHealthFactor = dyscEngine.getHealthFactor(USER);
	
	assertEq(expectedHealthFactor, actualHealthFactor);
    }

    function testHealthFactorCalculationDoesNotPanicOnZeroDyscMinted() public depositedCollateral {
        uint256 expectedHealthFactor = type(uint256).max;
        uint256 actualHealthFactor = dyscEngine.getHealthFactor(USER);
    
    	assertEq(expectedHealthFactor, actualHealthFactor);
    }
}
