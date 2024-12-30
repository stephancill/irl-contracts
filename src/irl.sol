// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {SignatureChecker} from "lib/openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract irl is ERC1155, Ownable {
    error InsufficientFunds();
    error InvalidSignature();
    error RefundFailed();
    error WithdrawFailed();
    error TransfersDisabled();

    uint256 startTimestamp;
    uint256 maxId;

    constructor(string memory _uri) ERC1155(_uri) Ownable(msg.sender) {
        startTimestamp = block.timestamp;
    }

    function mint(address to, uint256 id, uint256 price, bytes memory signature) external payable {
        if (msg.value < price) revert InsufficientFunds();

        bytes32 _hash = getHash(to, id, price);

        if (!SignatureChecker.isValidSignatureNow(owner(), _hash, signature)) {
            revert InvalidSignature();
        }

        if (msg.value > price) {
            (bool success,) = msg.sender.call{value: msg.value - price}("");
            if (!success) revert RefundFailed();
        }

        if (id > maxId) maxId = id;

        _mint(to, id, 1, "");
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public override {
        revert TransfersDisabled();
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public override {
        revert TransfersDisabled();
    }

    function withdraw(address to) external onlyOwner {
        (bool success,) = payable(to).call{value: address(this).balance}("");
        if (!success) revert WithdrawFailed();
    }

    function setURI(string memory _uri) external onlyOwner {
        _setURI(_uri);
    }

    function emitURIForRange(uint256 from, uint256 to) external onlyOwner {
        for (uint256 i = from; i <= to; i++) {
            emit URI(uri(i), i);
        }
    }

    function getHash(address to, uint256 id, uint256 price) public view returns (bytes32) {
        return keccak256(abi.encode("mint", to, id, price, address(this)));
    }
}
