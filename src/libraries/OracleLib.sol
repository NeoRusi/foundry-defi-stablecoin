// SPDX-License-Identifier: MIT
//This contract is needed in order to freeze the protocol if chainlink price feeds breaks
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
/**
 * @title OracleLib
 * @author Ruslan Cooliev
 * @notice Tjis library is used to check Chainlink Oracle for stale data
 * If a price is stale, the function will revert, and render the DSCengine unusable -> this is by design
 * We want dsce to freeze if prices becomes stale
 *
 * So if the chainlink network explodes you have a lot of money locked in the protocol
 */

library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
