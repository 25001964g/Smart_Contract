// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Game{

    address public owner;
    uint256 private ownerAns;
    uint256 private ownerPW;
    bytes32 private ownerHash;

    address public player;
    uint256 private playerAns;
    uint256 private playerPW;
    bytes32 private playerHash;
    
    enum Status { None, Submitted, Confirmed, Winner }

    Status private playerStatus;
    Status private ownerStatus;


    constructor() {
        owner = msg.sender;
    }

//Step 1: Once both game host and player submit the Number, that means they agree to join the game

    //Hash function for commit and reveal
    //Limitation: There is not any on-chain randomness. Owner and Player need to be responsible for the security of Password. -> Development: Deploy a frontend in JavaScript and generate off-chain randomness.
    function ownerHashing(uint256 _ownerAns, uint256 _ownerPW) private pure returns (bytes32){
        return keccak256(abi.encodePacked(_ownerAns, _ownerPW));
    }

    function playerHashing(uint256 _playerAns, uint256 _playerPW) private pure returns (bytes32){
        return keccak256(abi.encodePacked(_playerAns, _playerPW));
    }

    function ownerSubmit(uint256 _ownerAns, uint256 _ownerPW) public returns (uint256) {
        require(msg.sender == owner, "only owner");
        require(ownerStatus!= Status.Submitted, "You have already submitted");
        require(ownerStatus!= Status.Winner, "The game is finish, new submission is not allowed");

        ownerAns = _ownerAns;
        ownerPW = _ownerPW;
        ownerHash = ownerHashing(ownerAns,ownerPW);
        ownerStatus = Status.Submitted;
        return ownerAns;
    }

    function playerSubmit(uint256 _playerAns, uint256 _playerPW) public returns (uint256) {
        require(msg.sender != owner, "owner can not Submit player Answer");
        require(playerStatus!= Status.Submitted, "You have already submitted");
        require(playerStatus!= Status.Winner, "The game is finish, new submission is not allowed");

        player = msg.sender;
        playerAns = _playerAns;
        playerPW = _playerPW;
        playerHash = playerHashing(playerAns,playerPW);
        playerStatus = Status.Submitted;
        return playerAns;
    }

//Step 2: Reveal to authenticate the identity of the one who submit
    function ownerReveal(uint256 _ownerPW_Confirm) public returns (bool, string memory){
        require(msg.sender == owner, "Only owner can submit Password");
        bytes32 checkOwnerHash = keccak256(abi.encodePacked(ownerAns, _ownerPW_Confirm));
        require(checkOwnerHash == ownerHash, "The Password is not correct, Please try again.");
            ownerStatus = Status.Confirmed;
            return (true, "Confirmed");
    }

    function playerReveal(uint256 _playerPW_Confirm) public returns (bool, string memory){
        require(msg.sender == player, "Only player can submit Password");
        bytes32 checkplayerHash = keccak256(abi.encodePacked(playerAns, _playerPW_Confirm));
        require(checkplayerHash == playerHash, "The Password is not correct, Please try again.");
            playerStatus = Status.Confirmed;
            return (true, "Confirmed");
    }

//View Function for Answer
    function playerViewAns() public view returns(uint256){
        require(msg.sender == player, "only player can view the answer");
        return playerAns;
    }

    function ownerViewAns() public view returns (uint256) {
        require(msg.sender == owner, "only owner can view the answer");
        return ownerAns;
    }

//Step 3: View game result to know who is the winner
    function calculateGameResult() private view returns(uint256){
        uint256 result = (playerAns+ownerAns)%6+1;
        return result;
    }

    function gameResult() public view returns(uint256, string memory){
        require(playerStatus == Status.Confirmed, "Player do not reveal");
        require(ownerStatus == Status.Confirmed, "Owner do not reveal");
        uint256 result = calculateGameResult();
        if (result<=3){
            return (result, "Owner win, please confirm you are the Winner and get reward!");
        } else {
            return (result, "Player win, please confirm you are the Winner and get reward!");
        }
    }

//Step 4: Confirm Winner and Get Reward
//Changing state for the winner to get reward more safety, and Winner should pay for the gas fee
function confirmWinner() public {
    require(playerStatus == Status.Confirmed, "Player do not reveal");
    require(ownerStatus == Status.Confirmed, "Owner do not reveal");
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