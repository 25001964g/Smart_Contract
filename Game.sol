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

    IToken public rewardTokenAddress;

    uint256 private tokenAmount;

    //player1
    address public player1;
    uint256 private player1Ans;
    uint256 private player1PW;
    bytes32 private player1Hash;

    //player2
    address public player2;
    uint256 private player2Ans;
    uint256 private player2PW;
    bytes32 private player2Hash;

    address private winner;

    //Game Status Handling
    enum gameStatus {
        noGameCreated, 
        gameStart, waitingPlayer, noPlayerJoin,
        waitingReveal, Player1_revealed, Player2_revealed, 
        rewardToBeClaimed, gameFinished, actionTimeout}
    gameStatus private gStatus;

    //token Status
    mapping(address => uint256) public tokenBalance;
    mapping(address => uint256) public gameCount;

    //Bet and Token requirement
    uint256 public betAmount = 5500000 gwei; //0.0055 ETH
    uint256 public rewardTokenAmount = 100;
    uint256 public winnerReward = 10000000 gwei; //0.01 ETH, 0.001ETH is the entrance fee
    uint256 private pool;

    //time limit handling
    uint256 public constant timeout = 3 minutes;
    uint256 public constant noPlayerTimeout = 10 minutes;
    mapping(address => uint256) private startTime;

    constructor(address _tokenAddress) {
            rewardTokenAddress = IToken(_tokenAddress);
    }

    function actionTimer() private{
        startTime[msg.sender] = block.timestamp;
    }

    function timeoutHandle() private {
    actionTimer();
    if (block.timestamp >= startTime[msg.sender]+timeout){
            gStatus = gameStatus.actionTimeout;
        } 
    }

    function noPlayerJoin() private{
        actionTimer();
        if (block.timestamp >= startTime[msg.sender]+timeout){
            gStatus = gameStatus.noPlayerJoin;
        } 
    }

//Game Function:
//Step 1: Once both game host (as a player) and player submit the Number, that means they agree to join the game
//The one who created game will be player 1
    //Hash function for commit and reveal
    //Limitation: There is not any on-chain randomness. Players need to be responsible for the security of Password. -> Development: Deploy a frontend in JavaScript and generate off-chain randomness.
    function playerHashing(uint256 _playerAns, uint256 _playerPW) private pure returns (bytes32){
        return keccak256(abi.encodePacked(_playerAns, _playerPW));
    }

    function createGame(uint256 _player1Ans, uint256 _player1PW) public payable returns (uint256) {
        require(gStatus == gameStatus.noGameCreated, "You have already running the game");
        require(msg.value == betAmount, "You must send exactly 0.005 ether (i.e. 500000 gwei) to bet");

        pool += msg.value;
        player1 = msg.sender;
        player1Ans = _player1Ans;
        player1PW = _player1PW;
        player1Hash = playerHashing(player1Ans,player1PW);
        gStatus = gameStatus.waitingPlayer;
        gameCount[msg.sender]++;
        return player1Ans;
    }

// For the one who join the game is player 2
    function joinGame(uint256 _player2Ans, uint256 _player2PW) public payable returns (uint256) {
        require(msg.sender != player1, "You already join the game");
        require(gStatus == gameStatus.waitingPlayer, "No game is created or Game is already started");
        require(msg.value == betAmount, "You must send exactly 0.02 ether to bet");

        pool += msg.value;
        player2 = msg.sender;
        player2Ans = _player2Ans;
        player2PW = _player2PW;
        player2Hash = playerHashing(player2Ans,player2PW);
        gStatus = gameStatus.gameStart;
        return player2Ans;
    }

//Step 2: Reveal to authenticate the identity of the one who submit
    function player1Reveal(uint256 _player1PW_Confirm) public returns (bool, string memory){
        require(msg.sender == player1, "Only player1 can submit Password.");
        require(gStatus != gameStatus.noGameCreated, "No game is created.");
        require(gStatus != gameStatus.waitingPlayer, "Please wait for player to join the game.");
        require(gStatus != gameStatus.Player1_revealed, "You have already finished the reveal process.");
        require(gStatus != gameStatus.rewardToBeClaimed, "This round of game has finished.");
        require(gStatus != gameStatus.gameFinished, "This round of game has finished.");
        bytes32 checkplayer1Hash = keccak256(abi.encodePacked(player1Ans, _player1PW_Confirm));
        require(checkplayer1Hash == player1Hash, "The Password is not correct, Please try again.");
            if (gStatus == gameStatus.Player2_revealed){
                gStatus = gameStatus.rewardToBeClaimed;
            } else {
                gStatus = gameStatus.Player1_revealed;
            }
            return (true, "Confirmed");
    }

    function player2Reveal(uint256 _playerPW_Confirm) public returns (bool, string memory){
        require(msg.sender == player2, "Only player can submit Password");
        require(gStatus != gameStatus.noGameCreated, "No game is created.");
        require(gStatus != gameStatus.Player2_revealed, "You have already finished the reveal process.");
        require(gStatus != gameStatus.rewardToBeClaimed, "This round of game has finished.");
        require(gStatus != gameStatus.gameFinished, "This round of game has finished.");
        bytes32 checkplayerHash = keccak256(abi.encodePacked(player2Ans, _playerPW_Confirm));
        require(checkplayerHash == player2Hash, "The Password is not correct, Please try again.");
            if (gStatus == gameStatus.Player1_revealed){
                gStatus = gameStatus.rewardToBeClaimed;
            } else {
                gStatus = gameStatus.Player2_revealed;
            }
            return (true, "Confirmed");
    }

//View Function for Answer
    function player1ViewAns() public view returns(uint256){
        require(gStatus != gameStatus.noGameCreated, "No Answer is submitted.");
        require(msg.sender == player1, "only player1 can view the answer");
        return player1Ans;
    }

    function player2ViewAns() public view returns (uint256) {
        require(gStatus != gameStatus.noGameCreated || gStatus != gameStatus.waitingPlayer, "No Answer is submitted.");
        require(msg.sender == player2, "only player2 can view the answer");
        return player2Ans;
    }

//Step 3: View game result to know who is the winner
    function calculateGameResult() private view returns(uint256){
        uint256 result = (player1Ans+player2Ans)%6+1;
        return result;
    }

//player should view the result to confrim whether he/she can claim the reward, no gas fee should be payed
    function gameResult() public view returns(uint256, string memory){
        require(gStatus != gameStatus.noGameCreated, "No game is created.");
        require(gStatus != gameStatus.waitingPlayer, "Game is not started.");
        require(gStatus != gameStatus.waitingReveal, "Please submit your answer to confirm your identity.");
        require(gStatus != gameStatus.Player1_revealed, "Please wait for player2 to submit answer to confirm identity.");
        require(gStatus != gameStatus.Player2_revealed, "Please wait for player1 to submit answer to confirm identity.");
        uint256 result = calculateGameResult();
        if (result<=3){
            return (result, "Player1 win, please confirm you are the Winner and get reward!");
        } else {
            return (result, "Player2 win, please confirm you are the Winner and get reward!");
        }
    }

//Step 4: Confirm Winner and Claim Reward
//Changing state for the winner to get reward more safety, and Winner should pay for the gas fee
    function claimReward() public payable{
        require(gStatus != gameStatus.noGameCreated, "No game is created.");
        require(gStatus != gameStatus.waitingPlayer, "Game is not started.");
        require(gStatus != gameStatus.waitingReveal, "Please submit your answer to confirm your identity.");
        require(gStatus != gameStatus.Player1_revealed, "Please wait for player2 to submit answer to confirm identity.");
        require(gStatus != gameStatus.Player2_revealed, "Please wait for player1 to submit answer to confirm identity.");
        uint256 result = calculateGameResult();

        if (result <= 3) {
            require(msg.sender == player1, "Only player1 can confirm");         
            gStatus=gameStatus.gameFinished;
            winner = player1;
        } else {
            require(msg.sender == player2, "Only player2 can confirm"); 
            gStatus=gameStatus.gameFinished;
            winner = player2;
        }
        gStatus = gameStatus.gameFinished;
        pool -= winnerReward;
        require(msg.value == winnerReward, "Winner Reward should be");
        //winner recieve rewards
        //ETH Bet
        (bool success, ) = payable(winner).call{value: winnerReward}("");
        require(success, "Reward payout failed");
        //Token
        tokenBalance[winner] += rewardTokenAmount;
        }

    function resetState() private {
        gStatus = gameStatus.noGameCreated;
        player1 = address (0);
        player2 = address(0);
        gStatus = gameStatus.noGameCreated;
    }

    function restartGame(uint256 _ans, uint256 _PW) public payable{
        require(msg.sender == player1, "Only player1 can restart the game.");
        require(gStatus != gameStatus.noGameCreated, "No game is created.");
        require(gStatus != gameStatus.waitingPlayer, "Game is not started.");
        require(gStatus != gameStatus.waitingReveal, "Please submit your answer to confirm your identity.");
        require(gStatus != gameStatus.Player1_revealed, "Please wait for player2 to submit answer to confirm identity.");
        require(gStatus != gameStatus.Player2_revealed, "Please wait for player1 to submit answer to confirm identity.");
        require(gStatus != gameStatus.rewardToBeClaimed, "Reward is not yet claimed.");   
        require(msg.value == betAmount, "Bet required");
        resetState();
        createGame(_ans, _PW);
    }

    function closeGame() public{
        require(msg.sender == player1, "Only game creator can close the game.");
        require(gStatus == gameStatus.gameFinished, "Game is not finished or not created");
        resetState();
        gameCount[msg.sender] = 0;
    }

    //out game function
    //View token amount
    function viewToken() public view returns(uint256){
        return tokenBalance[msg.sender];
    }

    //Withdraw token: only when using withdraw function, the game contract transfer token to player
    //** token will not be transfered when the game finished
    function withdrawToken() public{
        require(tokenBalance[msg.sender] >= tokenAmount, "Not enough token for withdraw.");
        tokenBalance[msg.sender] -= tokenAmount;
        bool tokenSuccess = rewardTokenAddress.transfer(winner, rewardTokenAmount);
        require(tokenSuccess, "Not enough token in the game contract");
    }

}