// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// CONTRACT A: The address you want to link
contract ContractA {
    string public name = "I am Contract A";
}

// CONTRACT B: Maps A during its own deployment
contract ContractB {
    // This mapping will store the address provided at deployment
    mapping(address => bool) public isMapped;
    address public initialA;

    // The Constructor takes the address of A as an input
    constructor(address _addressOfA) {
        // This automatically maps A the moment B is created
        isMapped[_addressOfA] = true;
        
        // Optional: Save it to a variable to see it easily in the UI
        initialA = _addressOfA;
    }

    // Test function to verify if an address is the one mapped at deployment
    function checkMapping(address _test) public view returns (bool) {
        return isMapped[_test];
    }
}

contract C{}
