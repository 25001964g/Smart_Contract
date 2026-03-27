// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


contract A {
    receive() external payable {}

    function balance() external view returns (uint256) {
        return address(this).balance;
    }
}


interface IA {
    function balance() external view returns (uint256);
}


contract B {
    uint256 public constant entryFee = 2 ether;
    address payable public treasury;

    mapping(address => bool) public hasPlayed;
    mapping(address => uint256) public answers;

    constructor(address payable _treasury) {
        treasury = _treasury;
    }

    function playGame(uint256 _answer) external payable {
        // ✅ 1. Enforce fixed entry fee
        require(msg.value == entryFee, "Must send exactly 2 ETH");
        require(!hasPlayed[msg.sender], "Already played");

        // ✅ 2. Record the answer
        answers[msg.sender] = _answer;
        hasPlayed[msg.sender] = true;

        // ✅ 3. Forward ETH to treasury
        (bool ok, ) = treasury.call{value: msg.value}("");
        require(ok, "Transfer failed");
    }
}