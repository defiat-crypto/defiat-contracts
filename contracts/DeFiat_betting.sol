/*
* Copyright (c) 2020 Will_It_Rug
*
* Be a Chad, don't get rugged without a failsafe.
*/ 

// File: @openzeppelin/contracts/math/Math.sol
//

// File: @openzeppelin/contracts/math/SafeMath.sol
pragma solidity ^0.6.0;

import "./models/_Interfaces.sol";
import "./libraries/SafeMath.sol";
import "./libraries/Ownable.sol";


contract RugVote is Ownable {
    using SafeMath for uint256;
    
    /**
    * @dev contract level variables 
    */
    uint256 private houseFee; //base 1,000
    uint256 private oracleFee; //base 1,000
    uint256 public rugRatio; //base 1000

    /**
    * @dev vote relative variables
    * currency needs to be an ERC20 address (use wETH instead of ETH)
    */
    address public UniPair;
    uint256 public closingDate;
    address public currency; 
    uint256 public votesYES;
    uint256 public votesNO;
    uint256 public reservesStart;
    bool public hasRugged;

    /**
    * @dev variables contain the anount of tokens on each vote.
    */
    struct MyVote {
        uint256 votesYES;
        uint256 votesNO;
    }
    mapping(address => MyVote) public myVote; //users can do 1 vote at a time to start with
    
    
// == constructor & modifers ===================================================================================

    /**
    * @dev simple time-based constructor for voteOpen
    * voteClose also checks if hasRugged == true
    * 
    * constructor is used by the factory to create a vote_contract.
    * inputs:
    *       _UniPair = UniSwap pair to watch
    *       _currency = erc20 token used to voteOpen
    *       _duractionDays = used to define closingDate;
    */
    modifier voteOpen() {
        require(block.timestamp <= closingDate, "The great Oracle of Rugs has spoken my son...");
        _;
    }
    modifier voteClosed() {
        require(block.timestamp >= closingDate || hasRugged == true, "There is still hopium here...");
        _;
    }
    
    constructor(address _creator, address _UniPair, uint256 _durationDays, address _currency) public {
    
    //declared
        UniPair = _UniPair;
        closingDate = block.timestamp.add(_durationDays.mul(86400));
        currency = _currency;
        
        reservesStart = reserves(_UniPair); //sum of TOKENS balances, independant of the decimals
        require(reservesStart > 0, "no reserves found for this pair");
        
    //hard coded
        houseFee = 4; //0.4$
        oracleFee = 1; //0.1%
        rugRatio = 50; //5% of reserves left = rug
        
        _transferOwnership(_creator); //contract creator is the new owner

    }
    
// == Rug Checker ===================================================================================
        
    /**
    * @dev we use the sum of reserves to measure the rug
    * rugCHeck performs a check based on the rugRatio 
    * if reserves at the end of the period are < certain % vs. the initial period
    * the rugCheck determines that there was a liquidity removal
    * 
    * Like houseFee and oracleReward, rugRatio is a base1000 numeral
    */
    function rugCheck() internal view returns(bool) {
        uint256 reservesNow = reserves(UniPair);
        uint256 _rugRatio = (reservesNow).mul(1000).div(reservesStart);
        
        bool _rug = false;
        if(_rugRatio < rugRatio){_rug = true;}
        return _rug;
    }

    function reserves(address _UniPair) internal view returns(uint256){
        uint112 r1; uint112 r2;
        (r1, r2, ) = IUniswapV2Pair(_UniPair).getReserves();
        return uint256(r1).add(uint256(r2));
    }
   
   
 // == THe Good, The Bad, and the Voter ===================================================================================
  
    function voteYES(uint256 _amount) public voteOpen {
   
        //transfer 1st (no reentrancy)
        IERC20(currency).transferFrom(_msgSender(), address(this), _amount);
       
        uint256 _feesAndReward = _amount.mul(houseFee.add(oracleFee)).div(1000);
        uint256 _netAmount = _amount.sub(_feesAndReward);
        
        // updates pool and users' metric
        votesNO = votesYES.add(_netAmount);
        myVote[_msgSender()].votesYES.add(_netAmount);
    }
    
    function voteNO(uint256 _amount) public voteOpen {

        //transfer 1st (no reentrancy)
        IERC20(currency).transferFrom(_msgSender(), address(this), _amount);
       
        uint256 _feesAndReward = _amount.mul(houseFee.add(oracleFee)).div(1000);
        uint256 _netAmount = _amount.sub(_feesAndReward);
        
        // updates pool and users' metric
        votesNO = votesNO.add(_netAmount);
        myVote[_msgSender()].votesNO.add(_netAmount);
    }
    
    function amountToPay(address _address) internal view returns(uint256) {
        uint256 _voteShare = 0;
        if(hasRugged == true){
            _voteShare = (myVote[_address].votesYES).mul(1e18).div(votesYES);
        }
        else if (hasRugged == false){
            _voteShare = (myVote[_address].votesNO).mul(1e18).div(votesNO);
        }
    
        return _voteShare.mul(votesYES.add(votesNO)).div(1e18);
    }
     
    function moneyTalks() public voteClosed {
        IERC20(currency).transfer(_msgSender(), amountToPay(_msgSender()));
    }


// == The Mighty Oracle of Rugs===================================================================================

    /**
    * @dev Behold the great Oracle of Rugs!
    */
    function oracleOfRugs() public voteOpen returns(bool) {
        hasRugged = false;
        
        if(rugCheck() == true){
            hasRugged = true;
            closingDate = block.timestamp.sub(10); //force closes pool. avoids reentrancy with voteOpen
            rewardOracle(_msgSender());
        }
        return hasRugged;
    }
        
    function rewardOracle(address _address) internal {
        require(hasRugged == true, "no rug... no reward");
        uint256 _reward = votesYES.add(votesNO).mul(oracleFee).div(1000);
        IERC20(currency).transfer(_address, _reward);
    }

// == The House ===================================================================================
    function CollectFees(address _address) public voteClosed onlyOwner{
        uint256 _fees = IERC20(currency).balanceOf(address(this)).mul(houseFee).div(1000);
        IERC20(currency).transfer(_address, _fees);
    }
    
    //this one is tricky as pool creators can flush the pool 1 week (604800 seconds) after the end of the vote.
    function flushPool(address _recipient, address _ERC20address) external onlyOwner {
        require(block.timestamp >= closingDate.add(604800), "Wait for end of grace period");
        uint256 _amount = IERC20(_ERC20address).balanceOf(address(this));
        IERC20(_ERC20address).transfer(_recipient, _amount); //use of the _ERC20 traditional transfer
    }
    
// == Getters ===================================================================================
    function getYESodds() public view returns(uint256){
        
    }

}


contract VoteFactory is Ownable {
    
    RugVote public rugVote;
    
    address[] public allVotes;
    uint256 public nbVotes; 
    
    mapping(address => address[]) public myVotes;

   
    constructor() public {
        //call ownable constructor
    }
   
    /**
    * @dev Creates a voting contract where the owner = creator
    */
    function createVote(address _UniPair, address _currency, uint256 _durationDays) public {
    address _rugVote = address(new RugVote(_msgSender(),  _UniPair, _durationDays, _currency));
   
    allVotes.push(_rugVote);
    nbVotes = allVotes.length;
    
    myVotes[_msgSender()].push(_rugVote);
    }
    
    //not sure about that one... let users delete their previous votes.
    function deleteVote(uint256 _index) public {
        uint256 _closingDate;
        address _rugVote = myVotes[_msgSender()][_index];
        (_closingDate,,,,,) =  getVoteInfo( _rugVote);
        
        require(block.timestamp < _closingDate, "only remove closed");
        
        delete myVotes[_msgSender()][_index];
    }
    
    function nbVotesOf(address _address) public view returns(uint256) {
        return myVotes[_address].length;
    }
    
    function votesOf(address _address,uint256 _index) public view returns(address) {
        return myVotes[_address][_index];
    }
    
    
    function getVoteInfo(address _rugVote) public view returns(uint256, address, uint256, uint256, uint256, bool){
            return(
                RugVote(_rugVote).closingDate(),
                RugVote(_rugVote).currency(),
                RugVote(_rugVote).votesYES(),
                RugVote(_rugVote).votesNO(),
                RugVote(_rugVote).reservesStart(),
                RugVote(_rugVote).hasRugged()
                );
        }
} 
    
