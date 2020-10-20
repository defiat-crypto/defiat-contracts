pragma solidity ^0.6.0;

import "./SafeMath.sol";
import "./_Interfaces.sol";


interface IAnyStake_Library {
    function tokenInfoLibrary(address _token) external view returns(
        string memory name, string memory symbol, uint8 decimals, uint256 spotPrice, bool activated, uint8 boost);
    
    function tokenPriceUpdate(address _token) external returns (uint256);
}
// File: @defiat-crypto/defiat/blob/master/contracts/XXXXXX.sol
/**
 * @dev Delegated Farming Contract.
 * Implements a conditoin on the DFT-DFT farming pool for users to generate more rewards
 */
contract DeFiat_AnyStake{
    using SafeMath for uint256;

    //Structs
    struct PoolMetrics {
        mapping(address => uint256) tokenStake;             // stakes per token 
        mapping(address => uint256) wETHtokenStake;         // wETH equivalent
        uint256 wETHStake;      // total stake in wETH Gwei (aggregated)
        uint256 stakingFee;     // entry fee
        
        uint256 stakingPoints;

        address rewardToken;
        uint256 rewards;        // current rewards in the pool
        uint256 totalRewards;

        uint256 startTime;      // when the pool opens
        uint256 closingTime;    // when the pool closes. 
        uint256 duration;       // duration of the staking
        uint256 lastEvent;      // last time metrics were updated.
        
        uint256  ratePerToken;  // CALCULATED pool reward Rate per Token (calculated based on total stake and time)
        
        address DftDungeon;     // used to calculate the DeFiatScore
    }
    PoolMetrics public poolMetrics;

    struct UserMetrics {
        mapping(address => uint256) tokenStake;             // stakes per token (nb of tokens)
        mapping(address => uint256) wETHtokenStake;         // wETH equivalent
        mapping(address => uint256) tokenPoints;
        mapping(address => uint256) tokenBoost;             // boost per token, depends on the nb of DFT staked (0 = no stakingPoints generated)
        
        uint256 wETHStake;          // total stake in wETH Gwei (aggregated)
        uint256 stakingPoints;  // total staking points at lastEvent
        uint256 poolPoints;     // pool point at lastEvent
        uint256 lastEvent;

        uint256 rewardAccrued;  // accrued rewards over time based on staking points
        uint256 rewardsPaid;    // for information only

        uint256 lastTxBlock;    // latest transaction from the user (antiSpam)
    }
    mapping(address => UserMetrics) public userMetrics;
    
    address public poolOperator; address public owner; address public AnyStake_Library;
        

//== constructor 
    constructor(address _rewardToken, uint256 _feeBase1000, uint256 _durationHours) public {
        owner = msg.sender;
        poolOperator = msg.sender;
        
        poolMetrics.rewardToken = address(_rewardToken);
        poolMetrics.stakingFee = _feeBase1000; //10 = 1%
        
        poolMetrics.duration = _durationHours.mul(3600); //
        poolMetrics.startTime = block.timestamp;
        poolMetrics.closingTime = poolMetrics.startTime + poolMetrics.duration;
        
        poolMetrics.stakingPoints = 1; //avoids div by 0 at start
    }

//== Events & Modifiers
    event PoolInitalized(uint256 amountAdded, string  _desc);
    event RewardTaken(address indexed user, uint256 reward, string  _desc);

    event userStaking(address indexed user, uint256 amount, string  _desc);
    event userWithdrawal(address indexed user, uint256 amount, string  _desc);


    modifier poolLive() {
        require(block.timestamp >= poolMetrics.startTime,"Pool not started Yet"); //good for delayed starts.
        require(block.timestamp <= poolMetrics.closingTime,"Pool closed"); //good for delayed starts.
        _;
    }
    modifier poolStarted() {
        require(block.timestamp >= poolMetrics.startTime,"Pool not started Yet"); //good for delayed starts.
        _;
    }
    modifier poolEnded() {
        require(block.timestamp > poolMetrics.closingTime,"Pool not ended Yet"); //good for delayed starts.
        _;
    }
    
    modifier antiSpam(uint256 _blocks) {
        require(block.number > userMetrics[msg.sender].lastTxBlock.add(_blocks), "Wait X BLOCKS between Transactions");
        userMetrics[msg.sender].lastTxBlock = block.number; //update
        _;
    } 
    modifier onlyPoolOperator() {
        require(msg.sender== poolOperator || msg.sender == owner, "msg.sender is not allowed to operate Pool");
        _;
    }
    modifier onlyOwner() {
        require(msg.sender== owner, "Only Owner");
        _;
    }
    modifier antiWhale(address _token, address _address) {
        require(myStakeShare(_token, _address) < 20000, "User stake% share too high. Leave some for the smaller guys ;-)"); //max 20%
        _;
    } 
    // avoids stakes being deposited once a user reached 20%. 
    // Simplistic implementation as if we calculate "futureStake" value very 1st stakers will not be able to deposit.
    
    modifier tokenListed(address _token) {
        (,,,,bool _activated,) = getTokenFromLibrary(_token);
        require(_activated == true, "token not Listed");
        _;
    }
    
    
//==Basics 
    function currentTime() public view returns (uint256) {
        return SafeMath.min(block.timestamp, poolMetrics.closingTime); //allows expiration
    } // SafeMath.min(now, endTime)
    function setPoolOperator(address _address) public onlyPoolOperator {
        poolOperator = _address;
    }
    
    /**
    * @dev Function gets the amount of DFT in the DFT dungeon farm 
    * to calculate a score that boosts the StakingRewards calculation
    * DFT requirements to get a boost are hard coded into the contract
    * 0DFT to 100 DFT staked respectfully generate a 0% to 100% bonus on Staking.
    * returned is a number between 50 and 100
    */
    /*
    function viewDftStaked(address _address) public view returns(uint256) {
        return  IDungeon(poolMetrics.DftDungeon).myStake(_address);
    }
    
    function viewTokenBoost(address _token, address _address) public view returns(uint256) {
        uint256 _userStake = viewDftStaked(_address);
        
        return 0;
    }
    */
    
    

//==Points locking    
    function viewPoolPoints() public view returns(uint256) {
        uint256 _previousPoints = poolMetrics.stakingPoints;    // previous points shapshot 
        uint256 _previousStake = poolMetrics.wETHStake;             // previous stake snapshot
        
        uint256 _timeHeld = currentTime().sub(
                    SafeMath.max(poolMetrics.lastEvent, poolMetrics.startTime)
                                                );                 // time held with _previous Event
                                                
        return  _previousPoints.add(_previousStake.mul(_timeHeld));    //generated points since event
    }

    function lockPoolPoints() internal returns (uint256) { //ON STAKE/UNSTAKE EVENT
        poolMetrics.stakingPoints = viewPoolPoints();
        poolMetrics.lastEvent = currentTime();   // update lastStakingEvent
        return poolMetrics.stakingPoints;
    } 
    
    function viewPointsOf(address _address) public view returns(uint256) {
        uint256 _previousPoints = userMetrics[_address].stakingPoints;    
        uint256 _previousStake = userMetrics[_address].wETHStake;
    
        uint256 _timeHeld = currentTime().sub(
                    SafeMath.max(userMetrics[_address].lastEvent, poolMetrics.startTime)
                                                );                          // time held since lastEvent (take RWD, STK, unSTK)
        
        uint256 _result = _previousPoints.add(_previousStake.mul(_timeHeld));   
        
        if(_result > poolMetrics.stakingPoints){_result = poolMetrics.stakingPoints;}
        
        
        return _result;
    }

    function lockPointsOf(address _address) internal returns (uint256) {
        userMetrics[_address].poolPoints = viewPoolPoints();  // snapshot of pool points at lockEvent
        userMetrics[_address].stakingPoints = viewPointsOf(_address); 
        userMetrics[_address].lastEvent = currentTime(); 

        return userMetrics[_address].stakingPoints;
    }

    function pointsSnapshot(address _address) public returns (bool) {
        lockPointsOf(_address);
        lockPoolPoints();
        return true;
    }
     
    //==Rewards
    function viewTrancheReward(uint256 _period) internal view returns(uint256) {
        uint256 _poolRewards = poolMetrics.totalRewards; 

        uint256 _timeRate = _period.mul(1e18).div(poolMetrics.duration);
        return _poolRewards.mul(_timeRate).div(1e18); //tranche of rewards on period
    }
    
    function userRateOnPeriod(address _address) public view returns (uint256){
        //calculates the delta of pool points and user points since last Event
        uint256 _deltaUser = viewPointsOf(_address).sub(userMetrics[_address].stakingPoints); // points generated since lastEvent
        uint256 _deltaPool = viewPoolPoints().sub(userMetrics[_address].poolPoints);          // pool points generated since lastEvent
        uint256 _rate = 0;
        if(_deltaUser == 0 || _deltaPool == 0 ){_rate = 0;} //rounding
        else {_rate = _deltaUser.mul(1e18).div(_deltaPool);}
        
        return _rate;
    }
    
    function viewAdditionalRewardOf(address _address) public view returns(uint256) { // rewards generated since last Event
        require(poolMetrics.rewards > 0, "No Rewards in the Pool");
        
        // user weighted average share of Pool since lastEvent
        uint256 _userRateOnPeriod = userRateOnPeriod(_address); //can drop if pool size increases within period -> slows rewards generation
        
        // Pool Yield Rate 
        uint256 _period = currentTime().sub(
                            SafeMath.max(userMetrics[_address].lastEvent, poolMetrics.startTime)  
                            );        // time elapsed since last reward or pool started (if never taken rewards)

        // Calculate reward
        uint256 _reward = viewTrancheReward(_period).mul(_userRateOnPeriod).div(1e18);  //user rate on pool rewards' tranche

        return _reward;
    }
    
    function lockRewardOf(address _address) public returns(uint256) {
        uint256 _additional = viewAdditionalRewardOf(_address); //stakeShare(sinceLastEvent) * poolRewards(sinceLastEvent)
        userMetrics[_address].rewardAccrued = userMetrics[_address].rewardAccrued.add(_additional); //snapshot rewards.
        
        pointsSnapshot(_address); //updates lastEvent and points
        return userMetrics[_address].rewardAccrued;
    }  
    
    function takeRewards() public poolStarted antiSpam(1) { //1 blocks between rewards
        require(poolMetrics.rewards > 0, "No Rewards in the Pool");
        
        uint256 _reward = lockRewardOf(msg.sender); //returns already accrued + additional (also resets time counters)

        userMetrics[msg.sender].rewardsPaid = _reward;   // update user paid rewards
        
        userMetrics[msg.sender].rewardAccrued = 0; //flush previously accrued rewards.
        
        poolMetrics.rewards = poolMetrics.rewards.sub(_reward);           // update pool rewards
            
        IERC20(poolMetrics.rewardToken).transfer(msg.sender, _reward);  // transfer
            
        pointsSnapshot(msg.sender); //updates lastEvent
        //lockRewardOf(msg.sender);
            
        emit RewardTaken(msg.sender, _reward, "Rewards Sent");          
    }
    
//==staking & unstaking

    //add condition on TOKEN IN AnyStake_Library
    function stake(address _token, uint256 _amount) public poolLive antiSpam(1) antiWhale(_token, msg.sender) tokenListed(_token){
        require(_amount > 0, "Cannot stake 0");
        
        //initialize
        userMetrics[msg.sender].rewardAccrued = lockRewardOf(msg.sender); //Locks previous eligible rewards based on lastRewardEvent and lastStakingEvent
        pointsSnapshot(msg.sender); //snapshot of wETHstakebalances

        //receive staked
        uint256 _balanceNow = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transferFrom(msg.sender, address(this), _amount); //will require allowance
        uint256 amount = IERC20(_token).balanceOf(address(this)).sub(_balanceNow); //actually received

        //fee stays in contract until period ends
        amount = amount.sub(amount.mul(poolMetrics.stakingFee).div(1000));
        
        //Manage stakes

            //per token (mb of tokens)
                poolMetrics.tokenStake[_token] = poolMetrics.tokenStake[_token].add(amount);
                userMetrics[msg.sender].tokenStake[_token] = userMetrics[msg.sender].tokenStake[_token].add(amount);
            
            //update wETHStake
                uint256 _tokenPerEth = getTokensPerETH(_token);
                uint256 _wETHstake = amount.mul(1e18).div(_tokenPerEth);
                _wETHstake = _wETHstake.mul(getTokenBoost(_token)).div(100); //add token BOOST
                poolMetrics.wETHStake = poolMetrics.wETHStake.add(_wETHstake);
                userMetrics[msg.sender].wETHStake = userMetrics[msg.sender].wETHStake.add(_wETHstake); //wETH stake updated
                
            
            //granular update (wETH stake per token, for users to measure stake impact and calculate avg price)
                poolMetrics.wETHtokenStake[_token] = poolMetrics.wETHtokenStake[_token].add(amount);
                userMetrics[msg.sender].wETHtokenStake[_token] = userMetrics[msg.sender].wETHtokenStake[_token].add(_wETHstake);


        //finalize
        pointsSnapshot(msg.sender); //updates lastEvent
        emit userStaking(msg.sender, amount, "Staking... ... ");
        
    } 
    
    function unStake(address _token, uint256 _amount) public poolStarted antiSpam(1) { 
        require(_amount > 0, "Cannot withdraw 0");
        require(_amount <= userMetrics[msg.sender].tokenStake[_token], "Cannot withdraw more than stake");

        //initialize
        userMetrics[msg.sender].rewardAccrued = lockRewardOf(msg.sender); //snapshot of  previous eligible rewards based on lastStakingEvent
        pointsSnapshot(msg.sender);

        uint256 amount = _amount;
        //Manage stakes
           
            /* @dev wETH average price is calculated from previous stakes
            *
            */
            //update wETHStake
                uint256 _avgPriceUser = userMetrics[msg.sender].tokenStake[_token].mul(1e18).div(userMetrics[msg.sender].wETHtokenStake[_token]);
                uint256 _wETHstake = amount.mul(1e18).div(_avgPriceUser);
                poolMetrics.wETHStake = poolMetrics.wETHStake.sub(_wETHstake);
                userMetrics[msg.sender].wETHStake = userMetrics[msg.sender].wETHStake.sub(_wETHstake); //wETH stake updated
                
            //per token (mb of tokens)
                poolMetrics.tokenStake[_token] = poolMetrics.tokenStake[_token].sub(amount);
                userMetrics[msg.sender].tokenStake[_token] = userMetrics[msg.sender].tokenStake[_token].sub(amount);
            

            //granular update (wETH stake per token, for users to measure stake impact)
                poolMetrics.wETHtokenStake[_token] = poolMetrics.wETHtokenStake[_token].sub(amount);
                userMetrics[msg.sender].wETHtokenStake[_token] = userMetrics[msg.sender].wETHtokenStake[_token].sub(_wETHstake);
        


        // transfer _amount. Put at the end of the function to avoid reentrancy.
        IERC20(_token).transfer(msg.sender, _amount);
        
        //finalize
        //check if snapshot needed with new points manangement
        emit userWithdrawal(msg.sender, _amount, "Widhtdrawal");
    }

    function myStake(address _token, address _address) public view returns(uint256) {
        return userMetrics[_address].tokenStake[_token];
    }

    
    function myStakeShare(address _token, address _address) public view returns(uint256) {
        if(poolMetrics.wETHStake == 0){return 0;}
        else {
        return (userMetrics[_address].wETHtokenStake[_token]).mul(100000).div(poolMetrics.wETHtokenStake[_token]);
        }
    } 

    function myPointsShare(address _address) public view returns(uint256) {  //weighted average of your stake over time vs the pool
        return viewPointsOf(_address).mul(100000).div(viewPoolPoints());
    } //base 100,000. Drops when taking rewards.=> Refills after (favors strong hands)

    function myRewards(address _address) public view returns(uint256) {
        if(block.timestamp <= poolMetrics.startTime || poolMetrics.rewards == 0){return 0;}
        else { return userMetrics[_address].rewardAccrued.add(viewAdditionalRewardOf(_address));} //previousLock + time based extra
    }
 
 
//== USER TOKEN MANAGEMENT FUNCTIONS

    //== Library     
    function getTokenFromLibrary(address _token) public view returns(
        string memory name, string memory symbol, uint8 decimals, uint256 spotPrice, bool activated, uint8 boost) {
        return IAnyStake_Library(AnyStake_Library).tokenInfoLibrary(_token);
    }
    
    function getTokensPerETH(address _token) public returns(uint256){
        return IAnyStake_Library(AnyStake_Library).tokenPriceUpdate(_token);
    }
    function getTokenBoost(address _token) public view returns(uint256){
        (,,,,,uint256 _boost) = getTokenFromLibrary(_token);
        return _boost;
    }
    
    //== userArray
    mapping(address => address[]) tokenList;  //array of tokens per user
    
    
    /* @dev: users manage they tokens staked array (list)
    * can only replace a token if stake is == 0 for the replaced token
    * max nb of tokens is 16 
    * token 0 is always DFT 
    *
    * Users need to add the token before they can Stake
    */

    function chgTokenIntoList(address _token, uint256 _rank) public {
        require(_rank > 0, "cannot change 1st token, DFT only");
        require(_rank <16, "maximum 16 tokens inclusing the token 0");
        require(myStake(viewMyToken(msg.sender, _rank), msg.sender) == 0, "cannot remove a token with existing stake");
        tokenList[msg.sender][_rank] = _token;
        tokenList[msg.sender][0] = address(0xB6eE603933E024d8d53dDE3faa0bf98fE2a3d6f1);
    }
    
    function viewMyToken(address _address, uint256 _rank) public view returns(address) {
        return tokenList[_address][_rank];
    }
    function viewMyTokenCount(address _address) public view returns(uint256) {
        return(tokenList[_address].length);
    }
    

//== OPERATOR FUNCTIONS ==

    function loadRewards(uint256 _amount) public onlyPoolOperator { //load tokens in the rewards pool.
        
        uint256 _balanceNow = IERC20(address(poolMetrics.rewardToken)).balanceOf(address(this));
        IERC20(address(poolMetrics.rewardToken)).transferFrom( msg.sender,  address(this),  _amount);
        uint256 amount = IERC20(address(poolMetrics.rewardToken)).balanceOf(address(this)).sub(_balanceNow); //actually received
        
        poolMetrics.rewards = SafeMath.add(poolMetrics.rewards,amount);
        poolMetrics.totalRewards = poolMetrics.totalRewards.add(_amount);
    }    

    function setFee(uint256 _fee) public onlyPoolOperator {
        poolMetrics.stakingFee = _fee;
    }
    
    
//== OWNER FUNCTIONS ==   

    function setAnyStake_Library(address _library) public onlyOwner {
        AnyStake_Library = _library;
    }
    
    function setDungeon(address _dungeon) public onlyOwner {
        poolMetrics.DftDungeon = _dungeon;
    }
    
    function flushPool(address _ERC20address, address _recipient) external onlyOwner poolEnded {
        uint256 _amount = IERC20(_ERC20address).balanceOf(address(this));
        IERC20(_ERC20address).transfer(_recipient, _amount); //use of the _ERC20 traditional transfer
    }

    function killPool() public onlyOwner poolEnded returns(bool) {
        selfdestruct(msg.sender);
    } //frees space on the ETH chain


}
