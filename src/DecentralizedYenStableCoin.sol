//  SPDX-License-Identifier: MIT

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

import { ERC20Burnable, ERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedYenStableCoin 
 * @author chthonios
 * Collateral: Exogenous (BTC & ETH)
 * Minting: algorithmic
 * Relative Stability pegged to JPY
 *
 * This contract is meant to be governed by DSCEngine.sol. This contract is the ERC20 implementaion of the stablecoin system.
 * 
*/

contract DecentralizedYenStableCoin is ERC20Burnable, Ownable {
    error DecentralizedYenStableCoin__MustBeMoreThanZero();
    error DecentralizedYenStableCoin__BurnAmountExceedsBalance();
    error DecentralizedYenStableCoin__NotToZeroAddress();
    
    constructor(address _initialOwner) ERC20("DectralizedYenStableCoin", "DYSC") Ownable(_initialOwner) {
    }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
	if (_amount <= 0 ){
            revert DecentralizedYenStableCoin__MustBeMoreThanZero();
	}
	if (balance < _amount) {
            revert DecentralizedYenStableCoin__BurnAmountExceedsBalance();
	}
	//super keyword = use .function from parent class
	super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
	if (_to == address(0)) {
            revert DecentralizedYenStableCoin__NotToZeroAddress();
	}
       	if (_amount <= 0) {
            revert DecentralizedYenStableCoin__MustBeMoreThanZero();
	}
	_mint(_to, _amount);
	return true;
    }
}
