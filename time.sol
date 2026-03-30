// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract coolDown{
    uint256 public constant timeout = 1 minutes;
    mapping(address => uint256) private startTime;
    function coolDownClock() public{
        startTime[msg.sender] = block.timestamp;
    }

    function messgae() public view returns (string memory) {
        if (startTime[msg.sender] == 0) {
            return "not start";
        } else if (block.timestamp >= startTime[msg.sender]+timeout){
            return "over 1 minute";
        } else {
            return "in progress";
        }
    }
}