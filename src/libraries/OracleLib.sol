// SPDX-License-Identifier: MIT

pragma solidity ~0.8.21;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*
 * @title OraclelLib
 * author chthonios
 * @notice This library will check the chainlink Oracle price feed for stale data. 
 * If a price is stale, by design, the function will revert and the DYSCEngine contract will become unusable.
 *
 * If the chainlink network were to go tits up, any funds locked in the protocol will be lost.
 */

library OracleLib{

    /* State Variables */
    uint256 private constant TIMEOUT = 3 hours; // 3 * 60 * 60 = 10800 seconds

    /* Errors */ 
    error OracleLib__StalePrice();

    
    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed) public view returns (uint80, int256, uint256, uint256, uint80) {
	(uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if(secondsSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }
	return (roundId, answer, startedAt, updatedAt, answeredInRound); 
    }
}
