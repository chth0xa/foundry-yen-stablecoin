// SPDX-License-Identifier: MIT

// Layout of SRC:
// Pragma statements
// Import statements
// Events
// Errors
// Interfaces
// Libraries
// Contracts

// Layout of Contracts:
// Type declarations
// State variables
// Events
// Errors
// Modifiers
// Functions

// Order of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

pragma solidity ^0.8.21;

import { DecentralizedYenStableCoin } from "./DecentralizedYenStableCoin.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import { OracleLib } from "./libraries/OracleLib.sol";

/**
 * @title DYSCEngine
 * @author chthonios
 * The system is designed to be as minimal as possible, and maintain a 1 token == 1¥ peg.
 * this stablecin has the properties:
 * - Exogenous collateral
 * - Yen Pegged
 * - Algorythmially Stable
 *
 * It is similar to DIA, if DAI had no governance, had no fees, and wa only backed by WETH & WTC
 *
 * This DYSC system should always be "overcollateralized". At no point should the value of all collateral <= the yen backed value of all DYSC.
 *
 * @notice This contract is the core of the DYSC System. It handles all the logic of minting and redeeming DYSC, as well as the depositing and withdrawing of collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
 */
contract DYSCEngine is ReentrancyGuard {

    /* Types */
    using OracleLib for AggregatorV3Interface;
    
    /* State Variables */
    uint256 private constant BASE_FEED_DECIMALS = 1e8;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // means you need 200% over-collateralization
    uint256 private constant LIQUIDATION_PRECISION = 100; 
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // this means 10% bonus
    
    mapping(address token => address pricefeed) private s_priceFeeds;
    mapping(address user => mapping (address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDyscMinted) private s_DyscMinted;
    address[] private s_collateralTokens;
    
    DecentralizedYenStableCoin private immutable i_dysc;
    address private immutable i_jpyToUsd;

    /* Events */
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount);
	
    /* Errors */
    error DYSCEngine__MustBeMoreThanZero();
    error DYSCEngine__TokenNotAllowed();
    error DYSCEngine__TokenArrayMustBeSameLengthAsPriceFeedAddressArray();
    error DYSCEngine__TranferFailed();
    error DYSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DYSCEngine__MintFailed();
    error DYSCEngine__HealthFactorOkay();
    error DYSCEngine__HealthFactorNotImproved();
    
    /* Modifiers */
    modifier moreThanZero(uint256 amount) {
 	if (amount == 0) {
	     revert DYSCEngine__MustBeMoreThanZero();
	}
	_;
    }

    modifier tokenIsAllowed(address token) {
        if (s_priceFeeds[token] == address(0)) {
	    revert DYSCEngine__TokenNotAllowed();
    	}
    	_;
    }
	
    /* Functions */
    constructor(
        address[] memory tokenAddresses,
	address[] memory priceFeedAddresses,
	address jpyToUsd,
	address dyscAddress
    )  {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DYSCEngine__TokenArrayMustBeSameLengthAsPriceFeedAddressArray();
	}
	for (uint256 i = 0; i< tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
	    s_collateralTokens.push(tokenAddresses[i]);
	}

	i_dysc = DecentralizedYenStableCoin(dyscAddress);
	i_jpyToUsd = jpyToUsd;
    }

    /* External Functions */

    /**
     * @param tokenCollateralAddress: The address of the token to deposit as collateral
     * @param amountCollateral: The amount of collateral to deposit
     * @param amountDyscToMint: The amount of decentralized yen stablecoin to mint
     * @notice This function will deposit your collateral and mint DYSC in one transaction
     */
    function depositCollateralAndMintDysc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDyscToMint) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
	mintDysc(amountDyscToMint);
    }

    /**
     * @param amountCollateral: The amount of collateral to redeem
     * @param amountDyscToBurn: The amount of decentralized yen stablecoin to redeem
     * @param amountDyscToBurn: The amount of DYSC to Burn
     * This function burns DYSC and redeems underlying collateral in one transaction
     */
    function redeemCollateralForDysc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDyscToBurn)
	external
	moreThanZero(amountCollateral)
        tokenIsAllowed(tokenCollateralAddress)	
    {
        burnDysc(amountDyscToBurn);
	redeemCollateral(tokenCollateralAddress, amountCollateral);
	// redeemCollateral checks the health factor
    }

        /**
     *
     * @param collateral: The ERC20 collateral address of the collateral to liquidate from the user
     * @param user: The user who has a broken health factor. Their health factor should be below the MIN_HEATH_FACTOR 
     * @param debtToCover: The amount of the user's ERC20 to burn in order to improve the user's health factor
     * 
     * @notice You can partially liquidate a user
     * @notice You will receive a liquidation bonus for liquidating teh user's funds
     * @notice This function assumes the protocol will be roughly 200% overcollateralized to work.
     * @notice A known bug would be if the protocol were 100% or less collateralized, then we wouldnt be able to incentivise liquidators
     * For example, if the price of collateral plummets before anyone could be liquidated
     */
    function liquidate(address collateral, address user, uint256 debtToCover) external moreThanZero(debtToCover) nonReentrant {
	// Need user health factor
        uint256 startingUserHealthFactor = _healthFactor(user);
	if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DYSCEngine__HealthFactorOkay();
	}
	uint256 tokenAmountFromDebtCovered = getTokenAmountFromJpy(collateral, debtToCover);
	uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
	uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
	_redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
	_burnDysc(debtToCover, user, msg.sender);

	uint256 endingUserHealthFactor = _healthFactor(user);
	if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DYSCEngine__HealthFactorNotImproved();
	}
	_revertIfHealthFactorIsBroken(msg.sender);
    }

    function getAccountInformation(address user) external view returns (uint256 totalDyscMinted, uint256 collateralValueInJpy) {
        (totalDyscMinted, collateralValueInJpy) =  _getAccountInformation(user);
    }
    
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getJpyValue(address token, uint256 amount) external view returns (uint256) {
        return _getJpyValue(token, amount);
    }
    
    function getDysc() external view returns (address) {
        return address(i_dysc);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }
	
    function getBaseFeedDecimals() external pure returns (uint256) {
        return BASE_FEED_DECIMALS;
    }
    
    function getAdditionalPriceFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
	return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinimumHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getLiquidationBonus() external pure returns (uint256) {
	return LIQUIDATION_BONUS;
    }

    function calculateHealthFactor(uint256 totalDyscMinted, uint256 collateralValueInJpy) external pure returns (uint256) {
        return _calculateHealthFactor(totalDyscMinted, collateralValueInJpy);
    }
     
    /* Public Functions */
    /**
     * follows CEI(Checks, Effects & Interactions)  
     * @param tokenCollateralAddress: The address of the token to deposit as collateral 
     * @param amountCollateral: The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
	public
	moreThanZero(amountCollateral)
	tokenIsAllowed(tokenCollateralAddress)
	nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
	emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
	bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success){
            revert DYSCEngine__TranferFailed();
	}
    }
    
    // health factor must be over 1 after collateral is removed
    // DRY: Dont repeat yourself
    // CEI: Checks Effects Interactions
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
	public
	moreThanZero(amountCollateral)
        tokenIsAllowed(tokenCollateralAddress)
	nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
	_revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * follows CEI(Checks, Effects & Interactions)  
     * @param amountDyscToMint: The amount of decentralized yen stablecoin to mint 
     * @notice The collateral value must be greater than the minimum threshold
     */
    function mintDysc(uint256 amountDyscToMint) public moreThanZero(amountDyscToMint) nonReentrant {
        s_DyscMinted[msg.sender] += amountDyscToMint;
	_revertIfHealthFactorIsBroken(msg.sender);
	bool minted = i_dysc.mint(msg.sender, amountDyscToMint);
        if (!minted) {
            revert DYSCEngine__MintFailed();
	}	
    }

    function burnDysc(uint256 amount) public moreThanZero(amount) {
	_burnDysc(amount, msg.sender, msg.sender);
	_revertIfHealthFactorIsBroken(msg.sender); //Dont think this will ever hit.
    }

    // this is the number of tokens from Jpy Value
    // Now need to convert to get Jpy Value
    function getTokenAmountFromJpy(address token, uint256 jpyAmountInWei) public view returns (uint256) {
        uint256 units = 1e18;
	uint256 jpyPrice = _getJpyValue(token, units);
        // calculate number of token from Jpy
	return (jpyAmountInWei * PRECISION) / jpyPrice;
    }
	
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInJpy) {
        for(uint256 i = 0; i< s_collateralTokens.length; i++) {
	    address token = s_collateralTokens[i];
	    uint256 amount = s_collateralDeposited[user][token];
	    totalCollateralValueInJpy += _getJpyValue(token, amount); 
	}
	return totalCollateralValueInJpy;
    }

    /* Internal Functions */
    function _revertIfHealthFactorIsBroken(address user) internal view {
	uint256 userHealthFactor = _healthFactor(user);
	if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DYSCEngine__BreaksHealthFactor(userHealthFactor);
	}
    }

    function _getJpyValue(address token, uint256 amount) internal view returns (uint256) {
        // getUsdValueOfToken
        AggregatorV3Interface tokenPriceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 tokenPrice,,,) = tokenPriceFeed.staleCheckLatestRoundData();
	// getJpyToUsd
	AggregatorV3Interface jpyPriceFeed = AggregatorV3Interface(i_jpyToUsd);
        (,int256 jpyPrice,,,) = jpyPriceFeed.staleCheckLatestRoundData();
	// calculateJpyFromUsdValue
	return ((((uint256(tokenPrice) * BASE_FEED_DECIMALS) / uint256(jpyPrice)) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }
    
    function _calculateHealthFactor(uint256 totalDyscMinted, uint256 collateralValueInJpy) internal pure returns (uint256) {
	if (totalDyscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInJpy * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
	return  (collateralAdjustedForThreshold * PRECISION) / totalDyscMinted;
    }

    /* Private Functions */
    /**
     * @dev Low level internal function, do not call unless the function callin is checking for health
     * factor being broken
     *
     */   
    function _burnDysc(uint256 amountDyscToBurn, address onBehalfOf, address dyscFrom) private {
        s_DyscMinted[onBehalfOf] -= amountDyscToBurn;
	bool success = i_dysc.transferFrom(dyscFrom, address(this), amountDyscToBurn);
	if (!success){
            revert DYSCEngine__TranferFailed();
	}
	i_dysc.burn(amountDyscToBurn);
    }
    
    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
	emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
	bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
	if (!success){
            revert DYSCEngine__TranferFailed();
	}
    }

    function _getAccountInformation(address user) private view returns (uint256 totalDyscMinted, uint256 collateralValueInJpy) {
        totalDyscMinted = s_DyscMinted[user];
	collateralValueInJpy = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalDyscMinted, uint256 collateralValueInJpy) = _getAccountInformation(user);
	return _calculateHealthFactor(totalDyscMinted, collateralValueInJpy);
    }
}
