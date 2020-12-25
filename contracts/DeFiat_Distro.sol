// SPDX-License-Identifier: DeFiat

pragma solidity ^0.6.0;

import "./models/_Interfaces.sol";

contract Donation {
    
    address public token; //token address
    address private owner;
    uint256 public deadline;
    
    struct Participant {
        uint256 price;
        uint256 amount;
        uint256 lastTXblock;
    }
    mapping(address => Participant) private participant;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    modifier onlyParticipant {
        require(participant[msg.sender].amount > 0);
        _;
    }
    modifier antiSpam {
        require(block.number > participant[msg.sender].lastTXblock + 1, "no spam here"); //nb blocks between transactions
        _;
    }
    modifier donationsEnded {
        require(block.timestamp > deadline, "donation period not over"); //nb blocks between transactions
        _;
    }
        
    event ValueReceived(address user, uint amount);


    constructor(address _token, uint256 _durationDays) public {
      assert(1 ether == 1e18); //not sure we will use
      token = _token;
      owner = msg.sender;
      deadline = block.timestamp + _durationDays*(24*3600);
    }
    
    function setParticipant(address _address, uint256 _maxETH, uint256 _nbTokens1ETH) public onlyOwner{
        participant[_address].price = _nbTokens1ETH; //price ratio (500 base value)
        participant[_address].amount = _maxETH * _nbTokens1ETH* 1e18; //max nb tokens to distribute
        participant[_address].lastTXblock = block.number; //init
    }
    
    function viewMyAllocation(address _address) public view returns(uint256){
        return participant[_address].amount;
    }
    function viewMyPrice(address _address) public view returns(uint256) {
         return participant[_address].price;
    }
     
    receive() external payable antiSpam{    //use of pragme ^0.6.0 functions to receive ETH
    //update participant functions
        address _address = msg.sender;
        participant[_address].lastTXblock = block.number; //init
                
        uint256 _allocation = participant[_address].amount;
        uint256 _nbTokens1ETH = participant[_address].price;
        
        uint256 _toSend = msg.value * _nbTokens1ETH; //nb tokens to send
        require(_toSend > 0 && _toSend <= _allocation);
        
        participant[_address].amount = (_allocation - _toSend); //use safeMath no needed as check done before.

    //transfer tokens
    IERC20(token).transfer(msg.sender, _toSend);     
    }
    
    fallback() external payable {
        //do nothing
    }
    
    
    
//== onlyOwner functions
    function widthdrawAllTokens(address _ERC20address) public onlyOwner donationsEnded returns (bool) {
        uint256 _amount = IERC20(_ERC20address).balanceOf(address(this));
        _widthdrawAnyToken(msg.sender, _ERC20address, _amount);
        return true;
    } //get tokens sent by error to contract
    
    function _widthdrawETH() public onlyOwner donationsEnded returns (bool) {
        msg.sender.transfer(address(this).balance);        
        return true;
    }
        
    function _widthdrawAnyToken(address _recipient, address _ERC20address, uint256 _amount) 
        public onlyOwner donationsEnded returns (bool) {
        IERC20(_ERC20address).transfer(_recipient, _amount); //use of the _ERC20 traditional transfer
        return true;
    } //get tokens sent by error to contract
    
    function _killContract() public onlyOwner donationsEnded returns (bool) {
        widthdrawAllTokens(address(token));
        _widthdrawETH ();
        selfdestruct(msg.sender);
        
        return true;
    } //get tokens sent by error to contract
    
}
