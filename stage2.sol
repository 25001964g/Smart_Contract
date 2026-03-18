// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Game{

    address public owner;
    address public challenger;
    uint256 private ownerAns;
    uint256 private playerAns;

    constructor() {
        owner = msg.sender;
    }

    function joinGame() external {
        require(msg.sender != owner, "owner can not join Game");
        require(challenger == address(0), "there is already a player joined");

        challenger = msg.sender;
    }

    function ownerSubmit(uint256 _ownerAns) public view returns (uint256){
        require(msg.sender == owner, "only owner");
        require(challenger != address(0), "no player joined");
        ownerAns = _ownerAns;

    }

}