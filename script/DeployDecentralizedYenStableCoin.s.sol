// SPDX-License-Identifier

pragma solidity ^0.8.21;

import { Script } from "forge-std/Script.sol";
import { DecentralizedYenStableCoin } from "../src/DecentralizedYenStableCoin.sol";
import { DYSCEngine } from "../src/DYSCEngine.sol";
import { HelperConfig } from "./HelperConfig.s.sol";

contract DeployDecentralizedYenStableCoin is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
	
    function run() external returns (DecentralizedYenStableCoin, DYSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address jpyUsdPriceFeed, address weth, address wbtc, uint256 deployerKey, address deployerAddress) = helperConfig.activeNetworkConfig();

	tokenAddresses = [weth, wbtc];
	priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];
	
	vm.startBroadcast(deployerKey);
        DecentralizedYenStableCoin decentralizedYenStableCoin = new DecentralizedYenStableCoin(deployerAddress);
	DYSCEngine dyscEngine = new DYSCEngine(tokenAddresses, priceFeedAddresses, jpyUsdPriceFeed, address(decentralizedYenStableCoin));
        decentralizedYenStableCoin.transferOwnership(address(dyscEngine));
	vm.stopBroadcast();
	
       	return (decentralizedYenStableCoin, dyscEngine, helperConfig);
    }
}
