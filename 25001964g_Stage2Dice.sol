// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IToken {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

//=========Stage 2: Dice Game=========
contract Game{

    IToken public rewardTokenAddress; //Show the token address to let the players know where to sell the token.
    address public gameOwner;

    constructor(address _tokenAddress) {
        rewardTokenAddress = IToken(_tokenAddress);
        gameOwner = msg.sender;
    }

    //Game Status Handling
    enum gameStatus {
        noGameCreated, //Empty Game Room Status
        waitingPlayer, noPlayerJoin, //Player Join Status
        waitingReveal, Player1_revealed, Player2_revealed, //Reveal Status
        player1_revealTimeout, player2_revealTimeout, noRevealTimeout,//Reveal Timeout Status
        rewardToBeClaimed, rewardClaimTimeout, //Claim Reward Status
        noAction, //There is no new action => avoid game stuck
        gameClosed //Admin closed the game
        }
    gameStatus private gStatus;

    //player1 game variables
    address public player1;
    uint8 private player1Ans;
    bytes32 private player1Hash;

    //player2 game variables
    address public player2;
    uint8 private player2Ans;
    bytes32 private player2Hash;

    //check whether sender is player
    function isPlayer(address playerAddress) private view returns(bool){
        if(playerAddress == player1 || playerAddress == player2){
            return true;
        } else {
            return false;
        }
    }

    //Hasing for reveal
    function playerHashing(address _player,uint8 _playerAns, uint256 _playerPW) private pure returns (bytes32){
        return keccak256(abi.encode(_player, _playerAns, _playerPW));
    }

    //In realworld, players should provide their hash with answer and password off chain when joining the game
    //This code is for testing purpose.
    function player_commit_hash( uint8 _playerAns, uint256 _playerPW) public view returns (bytes32){
        return playerHashing(msg.sender, _playerAns, _playerPW);
    }

    //Game calculation handling
    function calculateGameResult() private view returns(uint8){
        return (player1Ans+player2Ans)%6+1;
    }

    //Common State
    address private winner;
    mapping(address => uint256) private gameCount; //Player's game involved
    uint256 private tokenAmount; // Assigned token reward amount
    mapping(address => uint256) private tokenBalance; //Player's token balance

    //View token amount
    function view_token_balance() public view returns(uint256){
        return tokenBalance[msg.sender];
    }

    //View game count
    function view_game_count() public view returns(uint256){
        return gameCount[msg.sender];
    }

    //Bet and Token Requirement
    uint256 public betAmount = 5500000 gwei; //0.0055 ETH ~11USD
    uint256 public basic_rewardTokenAmount = 50000000000; //token amount * 600 = 30000gwei ~0.06USD
    uint256 private join_rewardTokenAmount;
    uint256 public winnerReward = 10000000 gwei; //0.01 ETH, ~20 USD
    uint256 private entryFee = 1000000 gwei; // 0.001ETH ~2USD
    uint256 private rewardAmount;

//Reward for game involved: increased the bonus with milestone method.
    function joinTokenReward(address player) private {
       if(gameCount[player] >= 640){
            join_rewardTokenAmount = 30000000000; //token amount * 600 = 18000gwei ~0.04USD
        } else if (gameCount[player] >= 320){
            join_rewardTokenAmount = 20000000000; //token amount * 600 = 12000gwei ~0.02USD
        } else if (gameCount[player] >= 160){
            join_rewardTokenAmount = 10000000000; //token amount * 600 = 6000gwei ~0.01USD
        } else if (gameCount[player] >= 80){
            join_rewardTokenAmount = 5000000000; //token amount * 600 = 3000gwei ~0.006USD
        } else if (gameCount[player] >= 40){
            join_rewardTokenAmount = 2000000000; // token amount * 600 = 1200gwei ~0.002USD
        } else {
            join_rewardTokenAmount = 0;
        }
    }

    //Time limit for game status
    uint256 private constant timeout = 20;
    uint256 private constant noPlayerTimeout = 100;
    uint256 private constant noActionTimeout = 200;
    uint256 private startTime;

    function actionTimer() private{
        startTime = block.timestamp;
    }
//Timeout Status Handler
//Timeout for only one player joined the game
    function noPlayerJoin_timeout() private{
        if (gStatus == gameStatus.waitingPlayer && block.timestamp >= startTime+noPlayerTimeout){
            gStatus = gameStatus.noPlayerJoin;
        } 
    }

//Timeout for failing to reveal
function reveal_timeout() private {
    if (gStatus == gameStatus.Player1_revealed && block.timestamp >= startTime + timeout) {
        gStatus = gameStatus.player2_revealTimeout; 
    } else if (gStatus == gameStatus.Player2_revealed && block.timestamp >= startTime + timeout) {
        gStatus = gameStatus.player1_revealTimeout;
    } else if (gStatus == gameStatus.waitingReveal && block.timestamp >= startTime + timeout) {
        gStatus = gameStatus.noRevealTimeout;
    }
}

//Timeout for failing to get winner's reward
    function reward_timeout() private{
         if (gStatus == gameStatus.rewardToBeClaimed && block.timestamp >= startTime+timeout){
            gStatus = gameStatus.rewardClaimTimeout;
        }        
    }

//Timeout for no action happening
    function noAction_timeout() private{
        if (gStatus != gameStatus.noGameCreated && block.timestamp >= startTime+noActionTimeout) {
            gStatus = gameStatus.noAction;
        }
    }

//View Timeout Status
    function view_timeout() public view returns(string memory){
        if (gStatus != gameStatus.noGameCreated && block.timestamp >= startTime+noActionTimeout) {
            return "No action timeout, please join another game.";
        } else if (gStatus == gameStatus.waitingPlayer && block.timestamp >= startTime+noPlayerTimeout) {
            return "No player Join timeout.";
        } else if (gStatus == gameStatus.Player1_revealed && block.timestamp >= startTime + timeout){
            return "Player 2 Reveal timeout.";
        } else if (gStatus == gameStatus.Player2_revealed && block.timestamp >= startTime + timeout){
            return "Player 1 Reveal timeout.";
        } else if (gStatus == gameStatus.waitingReveal && block.timestamp >= startTime + timeout) {
            return "No player reveal.";
        } else {
            return "no timeout";
        }
    }

//Reset Game for next round
    function resetState() private {
        gStatus = gameStatus.noGameCreated;
        player1 = address (0);
        player2 = address(0);
        winner = address(0);
        delete player1Hash;
        delete player2Hash;
        delete player1Ans;
        delete player2Ans;
    }

    //Event Handling
    //Game Operateion
    event join_game(address indexed gameJoiner, string message);
    event player_reveal(address indexed player, uint256 joinGameTokenReward, string message);
    event winner_Reward(address indexed winner, uint256 winnerReward, uint256 rewardTokenAmount, string message);
    event timeout_Refund(address indexed winner, uint256 reward, string message);
    event timeout_Reward(address indexed winner, uint256 winnerReward, uint256 rewardTokenAmount, string message);
    event reveal_timeout_Reward(address indexed winner, uint256 winnerReward, string message);
    event withdraw_token(address indexed player, uint256 tokenWithdraw, string message);
    event no_Action(string message);

    //Game Owner
    event ETH_Withdraw(address indexed owner, uint256 withdrawETH, string message);
    event game_Closed(address indexed gameOwner, string message);    

//Re-entrancy Lock modifier
    bool private locked;

    modifier reentrancyLock{
        require(!locked, "Reentrancy is called");
        locked = true; //Lock before running the function
        _; //Entire function
        locked = false; //Unlock after running the function
    }

//Normal Game Logic:
//Step 1:  When players submit the bet amount and hash, that means they agree to join the game
    function join_Game(bytes32 _hashCommit) public payable{
        require(gStatus != gameStatus.gameClosed, "This contract has been closed.");
        require(rewardTokenAddress.balanceOf(address(this)) >= 80000000000 /*Max Token Reward of one game */,"There is not enough token in the contract, new game is not available");
        //check timeout
        noPlayerJoin_timeout();
        noAction_timeout();

        //if both players from last round of game do not have any action during the game, 
        //the remaing eth will belongs to the contract owner.
        if (gStatus == gameStatus.noAction){
            resetState();
            emit no_Action("Game has been reset due to there is not any action for a long time.");
        }
        require(isPlayer(msg.sender) == false, "You have already join"); 
        require(gStatus == gameStatus.noGameCreated || gStatus == gameStatus.waitingPlayer && gStatus != gameStatus.noPlayerJoin, "The game has already started. If there is no action for 10 minutes, please claim timeout full refund for no player join.");
        require(msg.value == betAmount, "You must send exactly 0.005 ether (i.e. 500000 gwei) to bet");
        if (gStatus == gameStatus.noGameCreated){
        player1_info(_hashCommit);
        startTime = block.timestamp;
        } else if(gStatus == gameStatus.waitingPlayer){
        player2_info(_hashCommit);
        startTime = block.timestamp;
        } else {
            revert("The game has already had two players.");
        }
    }

    //Storing player 1 and player 2 information
    function player1_info(bytes32 _hashCommit) private {
        player1 = msg.sender;
        player1Hash = _hashCommit;
        gStatus = gameStatus.waitingPlayer;
        emit join_game(msg.sender, "Player 1 has joined.");
    }


    function player2_info(bytes32 _hashCommit) private {
        player2 = msg.sender;
        player2Hash = _hashCommit;
        gStatus = gameStatus.waitingReveal;
        emit join_game(msg.sender, "Player 2 has joined.");
    }

//Step 2: Reveal to authenticate the identity of the one who submit
    //Players should submit the answer and password for hashing function 
    //to compare the submitted hash is whether correct after hashing submitted answer and password at this step.
    function player_Reveal(uint8 _ans, uint256 _pw_confirm) public{
        require(gStatus != gameStatus.gameClosed, "This contract has been closed.");
        require(isPlayer(msg.sender)== true, "You are not the players of this game");
        require(gStatus == gameStatus.waitingReveal || gStatus == gameStatus.Player1_revealed || gStatus == gameStatus.Player2_revealed, "Reveal not allowed in current state");
        if (msg.sender == player1){
            player1Reveal(_ans,_pw_confirm);
            startTime = block.timestamp;
        } else if (msg.sender == player2){
            player2Reveal(_ans,_pw_confirm);
            startTime = block.timestamp;
        } else {
            revert ("Reveal Error");
        }
    }
    
    //Handling player1 reveal process
    function player1Reveal(uint8 _playerAns_Confirm, uint256 _playerPW_Confirm) private{
        require(gStatus != gameStatus.Player1_revealed, "You have already finished the reveal process.");
        bytes32 checkplayer1Hash = playerHashing(msg.sender, _playerAns_Confirm, _playerPW_Confirm);
        require(checkplayer1Hash == player1Hash, "The Password is not correct, Please try again.");
            if (gStatus == gameStatus.Player2_revealed){
                gStatus = gameStatus.rewardToBeClaimed;
            } else {
                gStatus = gameStatus.Player1_revealed;
            }
        player1Ans = _playerAns_Confirm;
        gameCount[msg.sender]++;
        joinTokenReward(msg.sender);
        tokenBalance[msg.sender] += join_rewardTokenAmount;
        emit player_reveal(msg.sender, join_rewardTokenAmount, "Reveal Successful, and Join game reward token is sent to the player");
    }

    //Handling player2 reveal process
    function player2Reveal(uint8 _playerAns_Confirm, uint256 _playerPW_Confirm) private{
        require(gStatus != gameStatus.Player2_revealed, "You have already finished the reveal process.");
        bytes32 checkplayer2Hash = playerHashing(msg.sender, _playerAns_Confirm, _playerPW_Confirm);
        require(checkplayer2Hash == player2Hash, "The Password is not correct, Please try again.");
            if (gStatus == gameStatus.Player1_revealed){
                gStatus = gameStatus.rewardToBeClaimed;
            } else {
                gStatus = gameStatus.Player2_revealed;
            }
        player2Ans = _playerAns_Confirm;
        gameCount[msg.sender]++;
        joinTokenReward(msg.sender);
        tokenBalance[msg.sender] += join_rewardTokenAmount;
        emit player_reveal(msg.sender, join_rewardTokenAmount, "Reveal Successful, and Join game reward token is sent to the player");
    }

//Step 3: View game result to know who is the winner
//Player can view the result to confrim whether that player can claim the reward before claiming reward.
    function game_Result() public view returns(uint256, address, string memory){
         require(gStatus != gameStatus.gameClosed, "This contract has been closed.");
        require(isPlayer(msg.sender)== true, "You are not the players of this game");
        require(gStatus == gameStatus.rewardToBeClaimed, "Both players must complete reveal first.");
        uint8 result = calculateGameResult();
        if (result <=3){
            return (result, player1, "The above player win, please confirm you are the Winner and get reward!");
        } else {
            return (result, player2, "The above player win, please confirm you are the Winner and get reward!");
        }
    }

//Step 4: Claim Reward
//Winner should pay for the gas fee

    function claim_Reward() public payable reentrancyLock{
         require(gStatus != gameStatus.gameClosed, "This contract has been closed.");
        require(isPlayer(msg.sender)== true, "You are not the players of this game");
        require(gStatus != gameStatus.noGameCreated, "No game is created.");
        require(gStatus != gameStatus.waitingPlayer, "Game is not started.");
        require(gStatus != gameStatus.waitingReveal, "Please submit your answer to confirm your identity.");
        require(gStatus != gameStatus.Player1_revealed, "Please wait for player2 to submit answer to confirm identity.");
        require(gStatus != gameStatus.Player2_revealed, "Please wait for player1 to submit answer to confirm identity.");
        require(address(this).balance >= winnerReward, "The contract do not have enough balance");
        uint8 result = calculateGameResult();
        if (result <= 3) {
            require(msg.sender == player1, "Only player1 can confirm");         
            winner = player1;
        } else {
            require(msg.sender == player2, "Only player2 can confirm"); 
            winner = player2;
        }
        //winner recieve rewards
        resetState();
        (bool success, ) = payable(msg.sender).call{value: winnerReward}("");
        require(success, "Reward payout failed");
        //Token
        tokenBalance[msg.sender] += basic_rewardTokenAmount;
        emit winner_Reward(msg.sender, winnerReward, basic_rewardTokenAmount, "Winner reward has been received.");
        }
// End of normal game logic

//Timeout Reward or Refund Handling
//When players do not do an action during a step, they can claim timeout rewards/refund regardless the game result
    function claim_Timeout_Reward() public payable reentrancyLock{
        require(gStatus != gameStatus.gameClosed, "This contract has been closed.");
        require(isPlayer(msg.sender) == true, "You are not the player in this game");
        noPlayerJoin_timeout();
        reveal_timeout();
        reward_timeout();
        noAction_timeout();
        require(gStatus != gameStatus.noRevealTimeout, "No player reveal yet, please remember to reveal.");
        require(gStatus != gameStatus.noAction, "The game is outdated, please join the next game.");
        
        if (gStatus == gameStatus.noPlayerJoin){
            require(msg.sender == player1, "You are not allow to claim the refund");
            require(address(this).balance >= betAmount, "The contract do not have enough balance");
            resetState(); //avoid reentrancy
            //ETH refund
            (bool success, ) = payable(msg.sender).call{value: betAmount}("");
            require(success, "Reward payout failed");
            emit timeout_Refund(msg.sender, betAmount, "Bet Refund has been received.");
        } else if (gStatus == gameStatus.player2_revealTimeout){ //player2 fail to reveal
            require(msg.sender == player1, "You are not allow to claim the refund");
            require(address(this).balance >= winnerReward, "The contract do not have enough balance");
            resetState();
            //ETH reward
            (bool success, ) = payable(msg.sender).call{value: winnerReward}("");
            require(success, "Reward payout failed");
            emit reveal_timeout_Reward(msg.sender, betAmount, "Winner reward has been received due to timeout.");
        } else if (gStatus == gameStatus.player1_revealTimeout){ //player1 fail to reveal
            require(msg.sender == player2, "You are not allow to claim the refund");
            require(address(this).balance >= winnerReward, "The contract do not have enough balance");
            resetState();
            //ETH reward
            (bool success, ) = payable(msg.sender).call{value: winnerReward}("");
            require(success, "Reward payout failed");
            emit reveal_timeout_Reward(msg.sender, betAmount, "Winner reward has been received due to timeout.");
        } else if (gStatus == gameStatus.rewardClaimTimeout){ //winner do not get reward on time, both players can get the reward
            require(address(this).balance >= winnerReward, "The contract do not have enough balance");
            resetState();
            //ETH reward
            (bool success, ) = payable(msg.sender).call{value: winnerReward}("");
            require(success, "Reward payout failed");
            //token reward
            tokenBalance[msg.sender] += basic_rewardTokenAmount;
            emit timeout_Reward(msg.sender, winnerReward, basic_rewardTokenAmount, "Timeout winner reward has been received.");
        } else {
            revert("No timout yet");
        }
    }

    //Withdraw token: only when using withdraw function, the game contract transfer token to player
    //** token will not be transfered when the game finished
    function withdraw_Token(uint256 _tokenAmount) public reentrancyLock{
        require(tokenBalance[msg.sender] >= _tokenAmount, "Not enough token for withdraw.");    
        tokenBalance[msg.sender] -= _tokenAmount;
        require(rewardTokenAddress.balanceOf(address(this)) >= _tokenAmount, "Not enough token in the game contract");
        bool tokenSuccess = rewardTokenAddress.transfer(msg.sender, _tokenAmount);
        require(tokenSuccess, "Token Withdraw Unsuccessful");
        emit withdraw_token(msg.sender, _tokenAmount, "Withdrawed token");
    }

//Funtions for gameOwner (i.e. Admin)
    function admin_withdraw_ETH(uint256 _withdrawETH)payable public reentrancyLock{
        require(msg.sender == gameOwner, "You have no permission to use the function");
        require(gStatus == gameStatus.noGameCreated || gStatus == gameStatus.noAction, "There is game still ongoing. You cannot close the game now."); // The game owner can only withdraw the ETH when there is not any game ongoing.
       //Require the admin to left remainings in the contract
        require(address(this).balance > _withdrawETH + winnerReward, "Not enough ETH for withraw.");
        (bool success, ) = msg.sender.call{value: _withdrawETH}(""); //transfer remainings to the owner
        require(success, "Transfer failed.");
        emit ETH_Withdraw(msg.sender, _withdrawETH, "Withdrawed ETH");
    }

    function admin_close_Game()public reentrancyLock{
        require(msg.sender == gameOwner, "You have no permission to use the function");
        require(gStatus == gameStatus.noGameCreated || gStatus == gameStatus.noAction, "There is game still ongoing. You cannot close the game now."); // The game owner can only close the game when there is not any game ongoing.
        gStatus = gameStatus.gameClosed;
        if (address(this).balance > 0){
            (bool success, ) = msg.sender.call{value: address(this).balance}(""); //transfer all the remainings to the owner
            require(success, "Transfer failed."); 
        } else {
            revert("There is not any remainings in the game contract");
        }
        emit ETH_Withdraw(msg.sender, address(this).balance, "Game is closed and withdrawed remaining ETH.");  
    }

}