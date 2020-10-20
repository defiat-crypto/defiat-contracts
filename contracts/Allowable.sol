// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./Context.sol";

contract Allowable is Context {
    mapping(address => bool) allowed;
    
    modifier onlyAllowed() {
        require(allowed[_msgSender()] == true, "onlyAllowed");
        _;
    }
    function manageAllowed(address _address, bool _bool) public onlyAllowed {
        allowed[_address] = _bool;
    }
}