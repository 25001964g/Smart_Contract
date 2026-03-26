// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Game{

    address public owner;
    address public challenger;
    uint256 private ownerAns;
    uint256 private playerAns;
    uint256 private result;
    string private ownerStatis;
    
    enum Status { None, Submitted }

    Status private playerStatus;
    Status private ownerStatus;


    constructor() {
        owner = msg.sender;
    }

    function joinGame() external {
        require(msg.sender != owner, "owner can not join Game");
        require(challenger == address(0), "there is already a player joined");

        challenger = msg.sender;
    }


    function ownerSubmit(uint256 _ownerAns) public returns (uint256) {
        require(msg.sender == owner, "only owner");
        require(challenger != address(0), "no player joined");

        ownerAns = _ownerAns;
        ownerStatus = Status.Submitted;
        return ownerAns;
    }

    function playerSubmit(uint256 _playerAns) public returns (uint256) {
        require(msg.sender == challenger, "only challenger");
        require(challenger != address(0), "you need to joined");

        playerAns = _playerAns;
        playerStatus = Status.Submitted;
        return playerAns;
    }

    function playerViewAns() public view returns(uint256){
        require(msg.sender == challenger, "only player");
        return playerAns;
    }

    

    function ownerViewAns() public view returns (uint256) {
        require(msg.sender == owner, "only owner");
        return ownerAns;
    }

    function gameResult() public view returns(uint256){
        require(playerStatus == Status.Submitted, "input the value");
        require(ownerStatus == Status.Submitted, "input the value");
        return (playerAns+ownerAns)%6+1;
    }


}