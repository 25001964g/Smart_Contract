// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//Stage 1: Token
contract Token {

    
    address payable public owner;

    //event
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Sell(address indexed from, uint256 value);

    //token information
    string private _name = "DiceRewardToken";
    string private _symbol = "TKN";
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    uint128 private _price = 600;
    
    // token contract status
    bool private _isClosed = false;

    constructor() {
        owner = payable(msg.sender);
    }

    //fallback function
    receive() external payable {}  
    fallback() external payable {}   

    //View function
    function totalSupply() public view returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view returns (uint256) { return _balances[account]; }
    function getName() public view returns (string memory) { return _name; }
    function getSymbol() public view returns (string memory) { return _symbol; }
    function getPrice() public view returns (uint128) { return _price; }

    //transfer token
    function transfer(address to, uint256 value) public returns (bool) {
        require(!_isClosed, "contract is closed");
        require(to != address(0), "transfer to zero address");
        require(_balances[msg.sender] >= value, "insufficient balance");

        _balances[msg.sender] -= value;
        _balances[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    //mint token
    function mint(address to, uint256 value) public returns (bool) {
        require(!_isClosed, "contract is closed");
        require(msg.sender == owner, "only owner can mint");
        require(to != address(0), "mint to zero address");

        _totalSupply += value;
        _balances[to] += value;
        emit Mint(to, value);
        return true;
    }


//sell token for wei
    function sell(uint256 value) public returns (bool) {
        require(!_isClosed, "contract is closed");
        require(value > 0, "sell zero tokens");
        require(_balances[msg.sender] >= value, "insufficient balance");

        uint256 ethAmount = value * 600;
        require(address(this).balance >= ethAmount, "contract has insufficient ETH");

        _balances[msg.sender] -= value;
        _totalSupply -= value;
        emit Sell(msg.sender, value);

        (bool success, ) = payable(msg.sender).call{value: ethAmount}("");
        require(success, "ETH transfer failed");
        return true;
    }

    //close contract
    function close() public {
        require(msg.sender == owner, "only owner can close");
        require(!_isClosed, "already closed");
        _isClosed = true;

        uint256 remaining = address(this).balance;
        if (remaining > 0) {
            (bool sent, ) = owner.call{value: remaining}("");
            require(sent, "ETH transfer to owner failed");
        }
    }
}

interface IToken {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}


contract Game{

    //Owner
    address public owner;
    uint256 private ownerAns;
    uint256 private ownerPW;
    bytes32 private ownerHash;

    //Player
    address public player;
    uint256 private playerAns;
    uint256 private playerPW;
    bytes32 private playerHash;
    
    //Status Handling
    enum Status { None, Submitted, Confirmed, Winner }
    Status private playerStatus;
    Status private ownerStatus;

    //Bet and Token requirement
    uint256 public betAmount = 0.03 ether;
    uint256 public rewardTokenAmount = 100;
    uint256 public winnerReward = 0.05 ether;
    uint256 private pool;


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

    function ownerSubmit(uint256 _ownerAns, uint256 _ownerPW) public payable returns (uint256) {
        require(msg.sender == owner, "only owner");
        require(ownerStatus!= Status.Submitted, "You have already submitted");
        require(ownerStatus!= Status.Winner, "The game is finish, new submission is not allowed");
        require(msg.value == betAmount, "You must send exactly 0.02 ether to bet");

        pool += msg.value;
        ownerAns = _ownerAns;
        ownerPW = _ownerPW;
        ownerHash = ownerHashing(ownerAns,ownerPW);
        ownerStatus = Status.Submitted;
        return ownerAns;
    }

    function playerSubmit(uint256 _playerAns, uint256 _playerPW) public payable returns (uint256) {
        require(msg.sender != owner, "owner can not Submit player Answer");
        require(playerStatus!= Status.Submitted, "You have already submitted");
        require(playerStatus!= Status.Winner, "The game is finish, new submission is not allowed");
        require(msg.value == betAmount, "You must send exactly 0.02 ether to bet");

        pool += msg.value;
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
function confirmWinner() public payable{
    require(playerStatus == Status.Confirmed, "Player do not reveal");
    require(ownerStatus == Status.Confirmed, "Owner do not reveal");
    uint256 result = calculateGameResult();

    if (result <= 3) {
            require(msg.sender == owner, "Only owner can confirm");
            require(ownerStatus == Status.Confirmed, "You are not allow to confirm winner at this stage");

            ownerStatus = Status.Winner;
            pool -= winnerReward;
            require(msg.value == winnerReward, "");
        } else {
            require(msg.sender == player, "Only player can confirm");
            require(playerStatus == Status.Confirmed, "You are not allow to confirm winner at this stage");

            playerStatus = Status.Winner;
            pool -= winnerReward;
            require(msg.value == winnerReward, "");
        }
    }

}