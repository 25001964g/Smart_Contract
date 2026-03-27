// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Game{

    address public owner;
    address public player;
    uint256 private ownerAns;
    uint256 private playerAns;
    
    enum Status { None, Submitted, Winner }

    Status private playerStatus;
    Status private ownerStatus;


    constructor() {
        owner = msg.sender;
    }

//Step 1: Once both game host and player submit the Number, that means they agree to join the game
    function hashing(uint _ownerAns) private returns(uint256){
        bytes32 salt = ethers.randomBytes(32);
    }
    
    function ownerSubmit(uint256 _ownerAns) public returns (uint256) {
        require(msg.sender == owner, "only owner");
        require(ownerStatus!= Status.Submitted, "You have already submitted");
        require(ownerStatus!= Status.Winner, "The game is finish, new submission is not allowed");

        ownerAns = _ownerAns;
        ownerStatus = Status.Submitted;
        return ownerAns;
    }

    function playerSubmit(uint256 _playerAns) public returns (uint256) {
        require(msg.sender != owner, "owner can not Submit player Answer");
        require(playerStatus!= Status.Submitted, "You have already submitted");
        require(playerStatus!= Status.Winner, "The game is finish, new submission is not allowed");

        player = msg.sender;
        playerAns = _playerAns;
        playerStatus = Status.Submitted;
        return playerAns;
    }

//View Function for Answer
    function playerViewAns() public view returns(uint256){
        require(msg.sender == player, "only player");
        return playerAns;
    }

    function ownerViewAns() public view returns (uint256) {
        require(msg.sender == owner, "only owner");
        return ownerAns;
    }

//Step 3: View game result to know who is the winner
    function calculateGameResult() private view returns(uint256){
        uint256 result = (playerAns+ownerAns)%6+1;
        return result;
    }

    function gameResult() public view returns(uint256, string memory){
        require(playerStatus == Status.Submitted, "Player do not submit");
        require(ownerStatus == Status.Submitted, "Owner do not submit");
        uint256 result = calculateGameResult();
        if (result<=3){
            return (result, "Owner win, please confirm you are the Winner and get reward!");
        } else {
            return (result, "Player win, please confirm you are the Winner and get reward!");
        }
    }

//Step 4: Confirm Winner and Get Reward
//Changing state for the winner to get reward more safety
function confirmWinner() public {
    uint256 result = calculateGameResult();

    if (result <= 3) {
            require(msg.sender == owner, "Only owner can confirm");
            require(ownerStatus == Status.Submitted, "You are not allow to confirm winner at this stage");

            ownerStatus = Status.Winner;
        } else {
            require(msg.sender == player, "Only player can confirm");
            require(playerStatus == Status.Submitted, "You are not allow to confirm winner at this stage");

            playerStatus = Status.Winner;
        }
    }

}