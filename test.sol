// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

contract diceGame{

    address payable public owner;

    //events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Sell(address indexed from, uint256 value);

    string private _name = "AAA";
    string private _symbol = "A";
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    uint128 private _price = 600;   // 600 wei per token as required by sell

    //view Functions for token information
    function totalSupply() public view returns (uint256){
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256){
        return _balances[account];
    }

    function getName() public view returns (string memory){
        return _name;
    }

    function getSymbol() public view returns (string memory){
        return _symbol;
    }

    function getPrice() public view returns (uint128){
        return _price;
    }
}




