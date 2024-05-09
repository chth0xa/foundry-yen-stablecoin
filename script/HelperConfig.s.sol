// SPDX-License-Identifier

pragma solidity ^0.8.21;

import { Script } from "forge-std/Script.sol";
import { DeployDecentralizedYenStableCoin } from "./DeployDecentralizedYenStableCoin.s.sol";
import { MockV3Aggregator } from "../test/mocks/MockV3Aggregator.sol";
import { ERC20Mock }  from "../test/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address ethUsdPriceFeed;
	address btcUsdPriceFeed;
	address jpyUsdPriceFeed;
	address weth;
	address wbtc;
	uint256 deployerKey;
	address deployerAddress;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    int256 public constant JPY_USD_PRICE = 5e5;
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public constant ANVIL_DEPLOYER_ADDRESS = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
	} else {
            activeNetworkConfig = getOrCreateAnvilEthConfig(); 
	}
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if an Anvil network is already active
	if (activeNetworkConfig.ethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
	}

	vm.startBroadcast();
	MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(
	    DECIMALS,
            ETH_USD_PRICE
	);
	
	ERC20Mock wethMock = new ERC20Mock("WETH", "WETH");
	wethMock.mint(msg.sender, 1000e8);

	MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(
	    DECIMALS,
            BTC_USD_PRICE
	);
	
	ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC");
	wbtcMock.mint(msg.sender, 1000e8);
	vm.stopBroadcast();

	MockV3Aggregator jpyUsdPriceFeed = new MockV3Aggregator(
	    DECIMALS,
            JPY_USD_PRICE
	);
	
	return anvilNetworkConfig = NetworkConfig ({
            ethUsdPriceFeed: address(ethUsdPriceFeed),
	    btcUsdPriceFeed: address(btcUsdPriceFeed),
	    jpyUsdPriceFeed: address(jpyUsdPriceFeed),
	    weth: address(wethMock),
	    wbtc: address(wbtcMock),
	    deployerKey: DEFAULT_ANVIL_KEY,
	    deployerAddress: ANVIL_DEPLOYER_ADDRESS
        });
    }
	
    function getSepoliaEthConfig() public returns (NetworkConfig memory sepoliaNetworkConfig) {
	uint256 _deployerKey = vm.envUint("PRIVATE_KEY");
	address _deployerAddress = vm.rememberKey(_deployerKey);

	return sepoliaNetworkConfig = NetworkConfig({
            ethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
	    btcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
	    jpyUsdPriceFeed: 0x8A6af2B75F23831ADc973ce6288e5329F63D86c6,
	    weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
	    wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
	    deployerKey: _deployerKey,
	    deployerAddress: _deployerAddress 
	    });
    }

    function getMainnetEthConfig() public view {}
}
