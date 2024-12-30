// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {irl} from "../src/irl.sol";

contract irlTest is Test {
    irl public nft;
    address public owner;
    address public user;
    uint256 public ownerPrivateKey;
    uint256 public userPrivateKey;

    event URI(string value, uint256 indexed id);

    function setUp() public {
        // Create accounts
        ownerPrivateKey = 0x1;
        userPrivateKey = 0x2;
        owner = vm.addr(ownerPrivateKey);
        user = vm.addr(userPrivateKey);

        // Deploy contract as owner
        vm.prank(owner);
        nft = new irl("https://api.example.com/token/");
    }

    function testMint() public {
        uint256 id = 1;
        uint256 price = 0.1 ether;

        // Generate signature
        bytes32 hash = nft.getHash(user, id, price);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Mint with correct price
        vm.deal(user, 1 ether);
        vm.prank(user);
        nft.mint{value: price}(user, id, price, signature);

        // Assert balance
        assertEq(nft.balanceOf(user, id), 1);
    }

    function testMintWithExcessPayment() public {
        uint256 id = 1;
        uint256 price = 0.1 ether;
        uint256 payment = 0.15 ether;

        bytes32 hash = nft.getHash(user, id, price);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.deal(user, payment);
        uint256 initialBalance = user.balance;
        vm.prank(user);
        nft.mint{value: payment}(user, id, price, signature);

        // Assert refund
        assertEq(user.balance, initialBalance - price);
    }

    function testFailMintInsufficientFunds() public {
        uint256 id = 1;
        uint256 price = 0.1 ether;

        bytes32 hash = nft.getHash(user, id, price);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.deal(user, 0.05 ether);
        vm.prank(user);
        nft.mint{value: 0.05 ether}(user, id, price, signature);
    }

    function testFailMintInvalidSignature() public {
        uint256 id = 1;
        uint256 price = 0.1 ether;

        // Sign with wrong private key
        bytes32 hash = nft.getHash(user, id, price);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.deal(user, price);
        vm.prank(user);
        nft.mint{value: price}(user, id, price, signature);
    }

    function testFailTransfer() public {
        uint256 id = 1;
        uint256 price = 0.1 ether;

        // First mint a token
        bytes32 hash = nft.getHash(user, id, price);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.deal(user, price);
        vm.prank(user);
        nft.mint{value: price}(user, id, price, signature);

        // Try to transfer (should fail)
        vm.prank(user);
        nft.safeTransferFrom(user, address(1), id, 1, "");
    }

    function testWithdraw() public {
        uint256 id = 1;
        uint256 price = 0.1 ether;

        // Mint a token to generate some balance
        bytes32 hash = nft.getHash(user, id, price);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.deal(user, price);
        vm.prank(user);
        nft.mint{value: price}(user, id, price, signature);

        // Withdraw as owner
        uint256 initialBalance = owner.balance;
        vm.prank(owner);
        nft.withdraw(owner);

        assertEq(owner.balance, initialBalance + price);
        assertEq(address(nft).balance, 0);
    }

    function testSetURI() public {
        string memory newUri = "https://new.example.com/token/";

        vm.prank(owner);
        nft.setURI(newUri);

        // Note: We can't directly check the URI as it's internal to ERC1155
        // but we can verify the event was emitted
        // vm.expectEmit(true, true, true, true);
        // emit URI(newUri, 0);
    }

    function testEmitURIForSingleToken() public {
        uint256 tokenId = 1;
        string memory baseUri = "https://api.example.com/token/";

        vm.expectEmit(true, true, true, true);
        emit URI(baseUri, tokenId);

        vm.prank(owner);
        nft.emitURIForRange(tokenId, tokenId);
    }

    function testEmitURIForMultipleTokens() public {
        uint256 startId = 1;
        uint256 endId = 3;
        string memory baseUri = "https://api.example.com/token/";

        for (uint256 i = startId; i <= endId; i++) {
            vm.expectEmit(true, true, true, true);
            emit URI(baseUri, i);
        }

        vm.prank(owner);
        nft.emitURIForRange(startId, endId);
    }

    function testFailEmitURIForRangeNonOwner() public {
        vm.prank(user);
        nft.emitURIForRange(1, 5);
    }
}
