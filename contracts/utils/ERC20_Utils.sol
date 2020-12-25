// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../models/_Interfaces.sol";
import "../libraries/Allowable.sol";

contract ERC20_Utils is Allowable {
    //ERC20_utils  
    function withdrawAnyToken(address _token) external onlyAllowed returns (bool) {
        uint256 _amount = IERC20(_token).balanceOf(address(this));
        _withdrawAnyToken(_msgSender(), _token, _amount);
        return true;
    } //get tokens sent by error to contract

    function _withdrawAnyToken(address _recipient, address _ERC20address, uint256 _amount) internal returns (bool) {
        IERC20(_ERC20address).transfer(_recipient, _amount); //use of the _ERC20 traditional transfer
        return true;
    } //get tokens sent by error

    function kill() public onlyAllowed{
        selfdestruct(_msgSender());
    } //frees space on the ETH chain
}