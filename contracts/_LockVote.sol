// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./_Interfaces.sol";
import "./SafeMath.sol";
import "./ERC20_Utils.sol";

// This contract secures votes via locking of tokens in the contract
abstract contract _LockVote is ERC20_Utils {

  address public owner; // contract deployer
  address public DeFiat_Gov; //governance contract

  bytes32 public voteName; // name to describe the vote
  uint256 public voteStart; // UTC timestamp for voteStart
  uint256 public voteEnd; // UTC timestamp for voteEnd
  bool public decisionActivated; // track whether decision has been activated

  uint256 public quorum; // x / 100 = required % of votes / voting power for vote to be actionable
  uint256 public totalVotes; // total votes cast
  uint256[] public voteChoices; // array of choices to vote for 
  mapping (address => uint256) public votes; // address => user vote choice
  mapping (address => uint256) public votingTokens; // address => locked tokens

  address public votingPowerToken;
  address public rewardToken;
  uint256 public rewardAmount;

  event voteStarting(address _Defiat_Gov, uint256 _voteStart, uint256 _voteEnd, bytes32 _hash, bytes32 _voteName);

  modifier OnlyOwner() {
      require(msg.sender == owner);
      _;
  }

  modifier TokenHolder{
      require(IERC20(votingPowerToken).balanceOf(msg.sender) > 0, "Only holders can vote");
      _;
  }

  modifier VoteClosed() {
      require(now > voteEnd, "Vote is still open");
      require(decisionActivated, "Vote decision must be activated");
      _;
  }

  modifier VoteOpen() {
      require(now > voteStart, "Vote is not open");
      require(now < voteEnd, "Voting has expired");
      _;
  }

  modifier CanVote()   {
      require(votes[msg.sender] == 0, "Already voted"); //block time has not been updated
      _;
  }

  modifier QuorumReached {
    require(totalVotes > IERC20(votingPowerToken).totalSupply() * (quorum / 100), "Not enough votes have been cast");
    _;
  }

  constructor(
      address _DeFiat_Gov,
      uint256 _delayStartHours,
      uint256 _durationHours, 
      bytes32 _voteName,
      uint256 _voteChoices,
      uint256 _quorum,
      address _votingPowerToken, 
      address _rewardToken, 
      uint256 _rewardAmount
  ) public {
      owner = msg.sender;
      DeFiat_Gov = _DeFiat_Gov;
      voteStart = block.timestamp + (_delayStartHours * 3600);
      voteEnd = voteStart + (_durationHours * 3600);
      voteName = _voteName;
      voteChoices = new uint256[](_voteChoices);
      rewardToken = _rewardToken;
      rewardAmount = _rewardAmount;
      votingPowerToken = _votingPowerToken;
      quorum = _quorum;
      decisionActivated = false;

      bytes32 _hash = sha256(abi.encodePacked(DeFiat_Gov, voteEnd));
      emit voteStarting(DeFiat_Gov, voteStart, voteEnd,  _hash, voteName);
  }

  // 0 - define virtual proposal action function
  //    all new votes will override this method with the intended function to be activated on vote passing
  function proposalAction() public virtual returns (bool);

  //1- define ACTIVATION function
  function activateDecision() external { //anybody can activate this.
      require(voteEnd < now, "Voting still ongoing");
      require(!decisionActivated, "Vote decision has already been activated");

      decisionActivated = true; // mark decision activated
      proposalAction();
  }

  function vote(uint voteChoice, uint256 votePower) external VoteOpen CanVote TokenHolder {
      require(voteChoice < voteChoices.length, "Invalid vote choice");
      
      IERC20(votingPowerToken).transferFrom(msg.sender, address(this), votePower); // transfer tokens to contract
      votes[msg.sender] = voteChoice; // log of user vote 
      votingTokens[msg.sender] = votingTokens[msg.sender] + votePower; // increase locked token pointer
      voteChoices[voteChoice] = voteChoices[voteChoice] + votePower; // increase vote count
      totalVotes = totalVotes + votePower; // increase total votes

      _sendReward(msg.sender);
  }

  //3- reward voters
  function _sendReward(address _address) internal {
      if(IERC20(rewardToken).balanceOf(address(this)) >= rewardAmount){
        IERC20(rewardToken).transfer(_address, rewardAmount);
      }
  } //rewards if enough in the pool

  //4- claim tokens when vote is over
  function claimTokens() external VoteClosed {
      require(votingTokens[msg.sender] > 0, "No tokens to claim");

      uint256 votingPower = votingTokens[msg.sender];
      IERC20(votingPowerToken).transfer(msg.sender, votingPower);
      votingTokens[msg.sender] = votingTokens[msg.sender] - votingPower;
  } 
    
  //0- Misc functions
  function forceVoteEnd() external OnlyOwner {
      voteEnd = now;
  }

  function forceDecision(bool _decision) external OnlyOwner {
      decisionActivated = _decision;
  }

  function myVotingPower(address _address) internal view returns(uint256) {
    // simple 1:1 token to vote
      uint256 _power =  IERC20(votingPowerToken).balanceOf(_address);
      return _power;
  }
 
} //end contract
