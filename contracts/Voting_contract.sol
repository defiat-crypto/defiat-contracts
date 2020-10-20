// SPDX-License-Identifier: stupid

/*Readme:
This contract needs to be registered as a "governor" in the governing contract.
Below are the functions that can be used to generate a vote


COPY PASTE THESE 
//== SET EXTERNAL VARIABLES on the DeFiat_Gov contract ==  
    function setActorLevel(address _address, uint256 _newLevel) external;
    function changeBurnRate(uint _burnRate) external;
    function changeFeeRate(uint _feeRate) external;
    function setFeeDestination(address _nextDest) external;
    
//== SET EXTERNAL VARIABLES on the DeFiat_Points contract ==  
    function setTxTreshold(uint _amount) external;
    function overrideDiscount(address _address, uint256 _newDiscount) external;
    function overrideLoyaltyPoints(address _address, uint256 _newPoints) external;
    function setDiscountTranches(uint256 _tranche, uint256 _pointsNeeded) external;
    }
*/

// SPDX-License-Identifier: stupid

pragma solidity ^0.6.0;

import "./_Interfaces.sol";
//import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/master/contracts/token/ERC20/IERC20.sol";
//used to give tokens as rewards (tokens need to be loaded on the contract 1st)

contract Vote {

    address public owner;
    address public DeFiat_gov; //governance contract
    uint256 public expirationDate;

    uint256 public votedValue1;
    //uint256 public votedValue2; //add as many as needed
    //...

    //uint256 public votedAddress; //if an address is required as input.

    bool public voteIsOpen;
    uint256 public votesYAY;
    uint256 public votesNAY;
    mapping (address => uint256) public votes; //votes (block.time)

    address public votingPowerToken;
    address public rewardToken;
    uint256 public rewardAmount;

    event voteStart(address _Defiat_Gov, uint256 _expirationDate, uint256 _value, bytes32 _hash, string _description);

    modifier OnlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier tokenHolder{
        require(IERC20(votingPowerToken).balanceOf(msg.sender) >0, "only holders can vote");
        _;
    }

    modifier VoteClosed() {
        require(voteIsOpen != true, "Vote is closed");
        _;
    }

    modifier VoteOpen() {
        require(voteIsOpen = true, "Vote is not Open");
        require(expirationDate > now, "Voting has expired");
        _;
    }

    modifier CanVote()   {
        require(votes[msg.sender] == 0, "Already Voted"); //block time has not been updated
        _;
    }

    modifier VotePassed {
        require(votesYAY > votesNAY, "Voted Against");
        require(expirationDate < now, "Voting still ongoing");

        _;
    }


// INITIALIZE
    /*function setupTokens(address _votingPowerToken, address _rewardToken, uint256 _rewardAmount) external OnlyOwner {
        rewardToken = _rewardToken;
        rewardAmount = _rewardAmount;
        votingPowerToken = _votingPowerToken;
    }*/
    constructor(address _DeFiat_gov, uint256 _delayHours, uint256 _value, 
    address _votingPowerToken, address _rewardToken, uint256 _rewardAmount) public {
        DeFiat_gov = _DeFiat_gov;
        expirationDate = now + (3600*_delayHours); //linux timestamp. No need for Safemath here.
        
        rewardToken = _rewardToken;
        rewardAmount = _rewardAmount;
        votingPowerToken = _votingPowerToken;
        
        
        
        owner = msg.sender;
        //set variables (as many as needed)
        votedValue1 = _value;
        //...
        //...
        //...
        
        //opens vote
        voteIsOpen = true; 
        bytes32 _hash = sha256(abi.encodePacked(DeFiat_gov, expirationDate, _value));
        emit voteStart(DeFiat_gov, expirationDate,_value,  _hash, "PROPOSAL FOR FEE RATE");
    }


//1- define ACTIVATION function
    function activateDecision() external VotePassed { //anybody can actovate this.
        require(expirationDate < now, "Voting still ongoing");
        
        voteIsOpen = false; //close vote
        
        //activate function (copy paste the correct one)
        IDeFiat_Gov(DeFiat_gov).changeFeeRate(votedValue1);
    }

//2- Gather votes
    function voteYAY() external VoteOpen CanVote tokenHolder{ //this can 
        votes[msg.sender] = block.number; //registers voteNAY
        votesYAY = votesYAY + myVotingPower(); //we can use external
        _sendReward(msg.sender);
    }
    function voteNAY() external VoteOpen CanVote tokenHolder{
        votes[msg.sender] = block.number; //registers voteNAY
        votesNAY = votesNAY + myVotingPower();
        _sendReward(msg.sender);
    }

//3- reward voters
    function _sendReward(address _address) internal {
       if(  IERC20(rewardToken).balanceOf(address(this)) >= rewardAmount){
       IERC20(rewardToken ).transfer(_address, rewardAmount);}
    } //rewards if enough in the pool
    
//0- Misc functions
    function forceVoteStatus(bool _open) external OnlyOwner {
        voteIsOpen = _open;
    }

    function myVotingPower() internal view returns(uint256) {
        uint256 _power =  IERC20(votingPowerToken).balanceOf(msg.sender);
        
        if(_power > 0){_power = 1;} //need tokens to vote.
        if(_power >= 10){_power = 10;} //max 10
        
        return _power;
    }
 
} //end contract