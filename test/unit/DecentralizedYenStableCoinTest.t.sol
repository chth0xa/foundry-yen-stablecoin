// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import { Test, console } from "forge-std/Test.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { DecentralizedYenStableCoin } from "../../src/DecentralizedYenStableCoin.sol";

contract  DecentralizedYenStableCoinTest is Test {
    DecentralizedYenStableCoin decentralizedYenStableCoin;

    address public USER1 = makeAddr("user1");
    address public USER2 = makeAddr("user2");
    uint256 public amountCollateral = 10 ether;
    uint256 public amountDyscToMint = 10000 ether;

    modifier userFunded() {
        vm.startPrank(decentralizedYenStableCoin.owner());
	decentralizedYenStableCoin.mint(USER2, amountDyscToMint);
	vm.stopPrank();
	_;
    }
	
    function setUp() external {
        decentralizedYenStableCoin = new DecentralizedYenStableCoin(USER1);
    }

    /* Only Owner Tests */
    error OwnableUnauthorizedAccount(address);

    function testGetContractOwner() public {
        address initialOwner = decentralizedYenStableCoin.owner();
	assertEq(USER1, initialOwner);
    }

    function testOnlyOwnerCanCallMint() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, USER2));
        vm.startPrank(USER2);
	decentralizedYenStableCoin.mint(msg.sender, amountDyscToMint);
	vm.stopPrank();
    }

    function testOnlyOwnerCanCallBurn() public userFunded {
   	vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, USER2));
        vm.startPrank(USER2);
    	decentralizedYenStableCoin.burn(amountDyscToMint);
    	vm.stopPrank();
	}

    /* Mint Tests */
    function testOwnerCanMintDysc() public {
        vm.startPrank(USER1);
	decentralizedYenStableCoin.mint(USER2, amountDyscToMint);
	vm.stopPrank();
	
	uint256 userBalance = decentralizedYenStableCoin.balanceOf(USER2);

	assertEq(userBalance, amountDyscToMint);
    }

    function testMustMintMoreThanZero() public {
	vm.expectRevert(DecentralizedYenStableCoin.DecentralizedYenStableCoin__MustBeMoreThanZero.selector);
        vm.startPrank(USER1);
	decentralizedYenStableCoin.mint(USER2, 0);
	vm.stopPrank();
    }

    function testCannotMintToZeroAddress() public {
	vm.expectRevert(DecentralizedYenStableCoin.DecentralizedYenStableCoin__NotToZeroAddress.selector);
        vm.startPrank(USER1);
	
	decentralizedYenStableCoin.mint(address(0), amountDyscToMint);
	vm.stopPrank();
    }

    /* Burn Tests */
    function testOwnerCanBurnToken() public {
        vm.startPrank(USER1);
	decentralizedYenStableCoin.mint(USER1, amountDyscToMint);
	vm.stopPrank;

	uint256 amountDyscToBurn = 4000 ether;
        uint256 extimatedDyscBalance = 6000 ether;
	
	vm.startPrank(USER1);
	decentralizedYenStableCoin.burn(amountDyscToBurn);
	vm.stopPrank;

	uint256 actualDyscBalance = decentralizedYenStableCoin.balanceOf(USER1);
	
	assertEq(extimatedDyscBalance, actualDyscBalance);
    }

    function testCannotBurnMoreTokensThanYouHave() public {
        vm.startPrank(USER1);
	decentralizedYenStableCoin.mint(USER1, amountDyscToMint);
	vm.stopPrank;

	uint256 amountDyscToBurn = 10001 ether;

	vm.expectRevert(DecentralizedYenStableCoin.DecentralizedYenStableCoin__BurnAmountExceedsBalance.selector);
	vm.startPrank(USER1);
	decentralizedYenStableCoin.burn(amountDyscToBurn);
	vm.stopPrank;

    }

    function testMustBurnMoreThanZero() public {
    	uint256 amountDyscToBurn = 0 ether;

	vm.expectRevert(DecentralizedYenStableCoin.DecentralizedYenStableCoin__MustBeMoreThanZero.selector);
	vm.startPrank(USER1);
	decentralizedYenStableCoin.burn(amountDyscToBurn);
	vm.stopPrank;
    }
}
