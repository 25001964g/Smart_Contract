// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//Stage 1: Token
contract Token {

    
    address payable public owner;

    //Event Handling
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Sell(address indexed from, uint256 value);

    //Token Information
    string private _name = "DiceRewardToken";
    string private _symbol = "TKN";
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    uint128 private _price = 600;
    
    // Token Contract Status
    bool private _isClosed = false;

    constructor() {
        owner = payable(msg.sender);
    }

    //Fallback Function
    receive() external payable {}  
    fallback() external payable {}   

    //View Function
    function totalSupply() public view returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view returns (uint256) { return _balances[account]; }
    function getName() public view returns (string memory) { return _name; }
    function getSymbol() public view returns (string memory) { return _symbol; }
    function getPrice() public view returns (uint128) { return _price; }

    //Transfer Token
    function transfer(address to, uint256 value) public returns (bool) {
        require(!_isClosed, "contract is closed");
        require(to != address(0), "transfer to zero address");
        require(_balances[msg.sender] >= value, "insufficient balance");

        _balances[msg.sender] -= value;
        _balances[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    //Mint Token
    function mint(address to, uint256 value) public returns (bool) {
        require(!_isClosed, "contract is closed");
        require(msg.sender == owner, "only owner can mint");
        require(to != address(0), "mint to zero address");

        _totalSupply += value;
        _balances[to] += value;
        emit Mint(to, value);
        return true;
    }


//Sell Token for wei
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

    //Close Contract
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
    uint8 private player1Ans;
    uint256 private player1PW;
    bytes32 private player1Hash;

    //player2
    address public player2;
    uint8 private player2Ans;
    uint256 private player2PW;
    bytes32 private player2Hash;

    //check player
    function isPlayer(address playerAddress) private view returns(bool){
        if(playerAddress == player1 || playerAddress == player2){
            return true;
        } else {
            return false;
        }
    }

    //Event Handling
    event create_game(address indexed gameCreator, string messgae);
    event join_game(address indexed gameJoiner, string message);
    event player_reveal(address indexed player, uint8 answer, string message);
    event game_result(address indexed winner, uint256 result, uint256 winnerReward, uint256 rewardTokenAmount, string message);
    event withdraw_token(address indexed player, uint256 tokenWithdraw, string message);

    //Game Status Handling
    enum gameStatus {
        noGameCreated, 
        gameStart, waitingPlayer, noPlayerJoin,
        waitingReveal, Player1_revealed, Player2_revealed, revealTimeout,
        rewardToBeClaimed, rewardClaimTimeout,
        noAction}
    gameStatus private gStatus;

    //token Status
    mapping(address => uint256) private tokenBalance;

    //Common
    address private winner;
    mapping(address => uint256) private gameCount;

    //Bet and Token requirement
    uint256 public betAmount = 5500000 gwei; //0.0055 ETH
    uint256 public basic_rewardTokenAmount = 5000000000; //token amount * 600 = 3000gwei
    uint256 private join_rewardTokenAmount;
    uint8 private join_rewardIncrease = 1;
    uint256 private total_rewardTokenAmount;
    uint256 public winnerReward = 10000000 gwei; //0.01 ETH, 0.001ETH is the entrance fee
    uint256 private pool;

//Reward for game involved: increased the bonus every 20 games. Total reward will be up to 6000gwei
    function joinTokenReward(address player) private {
        if(gameCount[player] % 20 == 0){
            join_rewardIncrease++;
        } else if (join_rewardIncrease > 10){
            join_rewardIncrease;
        }
        join_rewardTokenAmount=1000000000*(1-join_rewardIncrease);
    }

    //time limit handling
    uint256 private constant timeout = 1 minutes;
    uint256 private constant noPlayerTimeout = 10 minutes;
    uint256 private constant noActionTimeout = 2 minutes;
    uint256 private startTime;

    function actionTimer() private{
        startTime = block.timestamp;
    }
//Timeout Status Handler
    function noPlayerJoin_timeout() private{
        if (gStatus == gameStatus.waitingPlayer && block.timestamp >= startTime+timeout){
            gStatus = gameStatus.noPlayerJoin;
        } 
    }

    function reveal_timeout() private {
        if (gStatus == gameStatus.waitingReveal || gStatus == gameStatus.Player1_revealed || gStatus == gameStatus.Player2_revealed && block.timestamp >= startTime+timeout){
            gStatus = gameStatus.revealTimeout;
        } 
    }

    function reward_timeout() private{
         if (gStatus == gameStatus.rewardToBeClaimed && block.timestamp >= startTime+timeout){
            gStatus = gameStatus.rewardClaimTimeout;
        }        
    }

    function noAction_timeout() private{
        if (gStatus != gameStatus.noGameCreated && block.timestamp >= startTime+noActionTimeout) {
            gStatus = gameStatus.noAction;
        }
    }

    function viewTimeout() public view returns(string memory){
        if (gStatus == gameStatus.waitingPlayer && block.timestamp >= startTime+timeout) {
            return "No player Join timeout";
        } else if (gStatus == gameStatus.waitingReveal || gStatus == gameStatus.Player1_revealed || gStatus == gameStatus.Player2_revealed && block.timestamp >= startTime+timeout){
            return "Reveal timeout";
        } else if (gStatus == gameStatus.noAction) {
            return "No action timeout";
        } else {
            return "no timeout";
        }
    }

//Reset Game for next round
    function resetState() private {
        gStatus = gameStatus.noGameCreated;
        player1 = address (0);
        player2 = address(0);
    }

    constructor(address _tokenAddress) {
        rewardTokenAddress = IToken(_tokenAddress);
    }

//Game Function:
//Step 1: Once both game host (as a player) and player submit the Number, that means they agree to join the game
//The one who created game will be player 1
    //Hash function for commit and reveal
    //Limitation: There is not any on-chain randomness. Players need to be responsible for the security of Password. -> Development: Deploy a frontend in JavaScript and generate off-chain randomness.
    function playerHashing(uint8 _playerAns, uint256 _playerPW) private pure returns (bytes32){
        return keccak256(abi.encode(_playerAns, _playerPW));
    }

    function joinGame(uint8 _ans, uint256 _pw) public payable{
        noPlayerJoin_timeout();
        noAction_timeout();
        if (gStatus == gameStatus.noAction){ //if noone get refund from no player joining or claiming reward, the remaing eth will belongs to the contract owner
            resetState();
        }
        require(isPlayer(msg.sender) == false, "You have already join");
        require(gStatus == gameStatus.noGameCreated || gStatus == gameStatus.waitingPlayer && gStatus != gameStatus.noPlayerJoin, "The game has already started. If there is no action for 3 minutes, please claim timeout full refund for no player join.");
        require(gStatus != gameStatus.rewardToBeClaimed, "The game has finished.");
        require(msg.value == betAmount, "You must send exactly 0.005 ether (i.e. 500000 gwei) to bet");
        pool += msg.value;
        if (gStatus == gameStatus.noGameCreated){
        player1_info(_ans, _pw);
        startTime = block.timestamp;
        } else if(gStatus == gameStatus.waitingPlayer){
        player2_info(_ans, _pw);
        startTime = block.timestamp;
        } else {
            revert("The game has already had two players.");
        }
    }

    function player1_info(uint8 _player1Ans, uint256 _player1PW) private {
        player1 = msg.sender;
        player1Ans = _player1Ans;
        player1PW = _player1PW;
        player1Hash = playerHashing(player1Ans,player1PW);
        gStatus = gameStatus.waitingPlayer;
        gameCount[msg.sender]++;
        emit create_game(msg.sender, "Player 1 has joined.");
    }

// For the one who join the game is player 2
    function player2_info(uint8 _player2Ans, uint256 _player2PW) private {
        require(isPlayer(msg.sender) == false, "You already join the game");
        player2 = msg.sender;
        player2Ans = _player2Ans;
        player2PW = _player2PW;
        player2Hash = playerHashing(player2Ans,player2PW);
        gStatus = gameStatus.waitingReveal;
        gameCount[msg.sender]++;
        emit join_game(msg.sender, "Player 2 has joined.");
    }

//Step 2: Reveal to authenticate the identity of the one who submit
    function playerReveal(uint256 _pw_confirm) public{
        require(isPlayer(msg.sender)== true, "You are not the players of this game");
        require(gStatus == gameStatus.waitingReveal || gStatus == gameStatus.Player1_revealed || gStatus == gameStatus.Player2_revealed, "Reveal not allowed in current state");
        if (msg.sender == player1){
            player1Reveal(_pw_confirm);
            startTime = block.timestamp;
        } else if (msg.sender == player2){
            player2Reveal(_pw_confirm);
            startTime = block.timestamp;
        } else {
            revert ("Reveal Error");
        }
    }
    
    function player1Reveal(uint256 _player1PW_Confirm) private{
        require(gStatus != gameStatus.Player1_revealed, "You have already finished the reveal process.");
        bytes32 checkplayer1Hash = playerHashing(player1Ans, _player1PW_Confirm);
        require(checkplayer1Hash == player1Hash, "The Password is not correct, Please try again.");
            if (gStatus == gameStatus.Player2_revealed){
                gStatus = gameStatus.rewardToBeClaimed;
            } else {
                gStatus = gameStatus.Player1_revealed;
            }
            joinTokenReward(player1);
            tokenBalance[player1] += join_rewardTokenAmount;
            emit player_reveal(player1, player1Ans, "Reveal Successful");
    }

    function player2Reveal(uint256 _playerPW_Confirm) private{
        require(gStatus != gameStatus.Player2_revealed, "You have already finished the reveal process.");
        bytes32 checkplayer2Hash = playerHashing(player2Ans, _playerPW_Confirm);
        require(checkplayer2Hash == player2Hash, "The Password is not correct, Please try again.");
            if (gStatus == gameStatus.Player1_revealed){
                gStatus = gameStatus.rewardToBeClaimed;
            } else {
                gStatus = gameStatus.Player2_revealed;
            }
            joinTokenReward(player2);
            tokenBalance[player2] += join_rewardTokenAmount;
            emit player_reveal(player2, player2Ans, "Reveal Successful");
    }

//View Function for Answer
    function viewAnswer() public view returns(uint256){
        require(isPlayer(msg.sender)== true, "You are not the players of this game");
        require(gStatus != gameStatus.noGameCreated, "No Answer is submitted.");
         if (msg.sender == player1){
            return player1Ans;
        } else if (msg.sender == player2){
            return player2Ans;
        } else {
            revert ("View function Error");
        }
    }

//Step 3: View game result to know who is the winner
    function calculateGameResult() private view returns(uint256){
        uint256 result = (player1Ans+player2Ans)%6+1;
        return result;
    }

//player should view the result to confrim whether he/she can claim the reward, no gas fee should be payed
    function gameResult() public view returns(uint256, address, string memory){
        require(isPlayer(msg.sender)== true, "You are not the players of this game");
        require(gStatus == gameStatus.rewardToBeClaimed, "Both players must complete reveal first.");
        uint256 result = calculateGameResult();
        if (result<=3){
            return (result, player1, "The above player win, please confirm you are the Winner and get reward!");
        } else {
            return (result, player2, "The above player win, please confirm you are the Winner and get reward!");
        }
    }

//Step 4: Confirm Winner and Claim Reward
//Changing state for the winner to get reward more safety, and Winner should pay for the gas fee

    function claimReward() public payable{
        require(isPlayer(msg.sender)== true, "You are not the players of this game");
        require(gStatus != gameStatus.noGameCreated, "No game is created.");
        require(gStatus != gameStatus.waitingPlayer, "Game is not started.");
        require(gStatus != gameStatus.waitingReveal, "Please submit your answer to confirm your identity.");
        require(gStatus != gameStatus.Player1_revealed, "Please wait for player2 to submit answer to confirm identity.");
        require(gStatus != gameStatus.Player2_revealed, "Please wait for player1 to submit answer to confirm identity.");
        uint256 result = calculateGameResult();

        if (result <= 3) {
            require(msg.sender == player1, "Only player1 can confirm");         
            winner = player1;
        } else {
            require(msg.sender == player2, "Only player2 can confirm"); 
            winner = player2;
        }
        pool -= winnerReward;
        require(msg.value == winnerReward, "Winner Reward should be");
        //winner recieve rewards
        //ETH Bet
        (bool success, ) = payable(winner).call{value: winnerReward}("");
        require(success, "Reward payout failed");
        //Token
        tokenBalance[winner] += basic_rewardTokenAmount;
        emit game_result(msg.sender, result, winnerReward, total_rewardTokenAmount, "This round of game is finished.");
        resetState();
        }

    //out game function
    //View token amount
    function viewToken() public view returns(uint256){
        return tokenBalance[msg.sender];
    }

    function viewGameCount() public view returns(uint256){
        return gameCount[msg.sender];
    }

    //Withdraw token: only when using withdraw function, the game contract transfer token to player
    //** token will not be transfered when the game finished
    function withdrawToken() public{
        require(tokenBalance[msg.sender] >= tokenAmount, "Not enough token for withdraw.");
        tokenBalance[msg.sender] -= tokenAmount;
        bool tokenSuccess = rewardTokenAddress.transfer(winner, tokenAmount);
        require(tokenSuccess, "Not enough token in the game contract");
        emit withdraw_token(msg.sender, tokenAmount, "Withdrawed token");
    }

}