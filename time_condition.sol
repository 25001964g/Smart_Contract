// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract coolDownGame{

    //Game Status Handling
    enum gameStatus {
        noGameCreated, 
        gameStart, waitingPlayer, noPlayerJoin,
        waitingReveal, Player1_revealed, Player2_revealed, 
        rewardToBeClaimed, actionTimeout}
    gameStatus private gStatus;

    //time limit handling
    uint256 private constant timeout = 1 minutes;
    uint256 private constant noPlayerTimeout = 1 minutes;
    uint256 private startTime;

    function resetState() private {
        gStatus = gameStatus.noGameCreated;
        player1 = address (0);
        player2 = address(0);
        winner = address(0);
    }

    function timeoutHandle() private{
    if (gStatus == gameStatus.rewardToBeClaimed && block.timestamp >= startTime+timeout){
            gStatus = gameStatus.actionTimeout;
        } else if (gStatus == gameStatus.waitingPlayer && block.timestamp >= startTime+timeout){
            gStatus = gameStatus.noPlayerJoin;
        }   else {
            gStatus = gameStatus.rewardToBeClaimed;
        }  
    }

    function claimTimeout() public{
        
    }

    function viewTimeout() public view returns(string memory){
    if (gStatus == gameStatus.rewardToBeClaimed && block.timestamp >= startTime+timeout){
            return "rewardToBeClaimed timeout";
        } else if (gStatus == gameStatus.waitingPlayer && block.timestamp >= startTime+timeout){
            return "waitingPlayer timeout";
        } else {
            return "no timeout";
        }
    }

    address player1;
    uint8 p1_num;
    address player2;
    uint8 p2_num;
    address winner;
    mapping(address => uint8) private token;
    function joinGame() public{
        require (gStatus == gameStatus.noGameCreated || gStatus == gameStatus.waitingPlayer, "Invalid State for join");
        if(gStatus == gameStatus.noGameCreated){
            player1 = msg.sender;
            startTime = block.timestamp;
            gStatus = gameStatus.waitingPlayer;
        } else if (gStatus == gameStatus.waitingPlayer){
            player2 = msg.sender;
            miniGame();
        } 
        
    }

    function miniGame() private {      
        uint256 random = 1;
        if (random == 1){
            winner = player1;
        } else {
            winner = player2;
        }
        startTime = block.timestamp;
        gStatus = gameStatus.rewardToBeClaimed;
    }

    function viewWinner() public view returns(address){
        return winner;
    }

function claimReward() public {
    timeoutHandle();
    if(msg.sender == player1){
        if (gStatus == gameStatus.noPlayerJoin) {
            token[player1] += 100;
            resetState();
            return;
        } else {
            revert ("Error no Player");
        }
    }
    else if (msg.sender == winner){

        if (gStatus == gameStatus.rewardToBeClaimed || gStatus == gameStatus.actionTimeout) {
            token[msg.sender] += 200;
            resetState();
            return;      
        } else {
            revert ("Error Reward");
        }
    } else if (msg.sender != winner){
        if (gStatus == gameStatus.actionTimeout) {
            token[msg.sender] += 200;
            resetState();
            return;
        } else {
            revert ("Error non Winner");
        }
    }

}

    function viewToken() public view returns(uint8){
        return token[msg.sender];
    }

    function viewStatis() public view returns(gameStatus){
        return gStatus;
    }
}