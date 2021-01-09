// SPDX-License-Identifier: DeFiat and Friends (Zeppelin, MIT...)

pragma solidity ^0.6.2;

import "./AnyStake_Libraries.sol";

//series of pool weighted by token price (using price oracles on chain)
contract AnyStake is AnyStake_Constants {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public GOV; //DeFiat GOV contract address pulled from the contract
    address public Vault; //where rewards are stored for distribution
    uint256 public pendingTreasuryRewards;


    // USERS METRICS
    struct UserInfo {
        uint256 amount; // How many tokens the user has provided.
        uint256 rewardPaid; // DFT already Paid. See explanation below.
        //  pending reward = (user.amount * pool.DFTPerShare) - user.rewardPaid
        uint256 rewardPaid2; // WETH already Paid. Same Logic.
        uint256 lastRewardBlock;
    }
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // POOL METRICS
    struct PoolInfo {
        address stakedToken; // Address of staked token contract.
        address lpToken; // uniswap LP token corresponding to the trading pair needed for price calculation
        uint256 allocPoint; // How many allocation points assigned to this pool. DFTs to distribute per block. (ETH = 2.3M blocks per year)
        uint256 accDFTPerShare; // Accumulated DFTs per share, times 1e18. See below.
        uint256 accWETHPerShare; // Accumulated DFTs per share, times 1e18. See below.
        uint256 lastRewardBlock;
        bool withdrawable; // Is this pool withdrawable or not (yes by default)
        bool isFotToken; // defines if fee on transfer token (default = false)
        bool isLpToken;
        bool manualAllocPoint; // forces a manual allocation point (for LP tokens)
        bool active;
        mapping(address => mapping(address => uint256)) allowance;
    }
    PoolInfo[] public poolInfo;

    uint256 stakingFee;

    uint256 public totalAllocPoint; // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public pendingDFTRewards; // pending DFT rewards awaiting anyone to massUpdate
    uint256 public pendingWETHRewards; // pending DFT rewards awaiting anyone to massUpdate

    uint256 public contractStartBlock;
    uint256 public epochCalculationStartBlock;
    uint256 public cumulativeRewardsSinceStart;
    uint256 public DFTrewardsInThisEpoch;
    uint256 public WETHrewardsInThisEpoch;
    uint256 public epoch;

    // EVENTS
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 _pid,
        uint256 value
    );

//SETUP
    // 1- create contract
    constructor() public {}
    
    // 2- create VAULT contract (separate contract)
    //
    
    // 3- run Initialize after the Vault has been created
    function initialize(address _Vault) public governanceLevel(2) {
        Vault = _Vault;
        GOV = IDeFiat(DFT).DeFiat_gov();
        stakingFee = 50; // 5%base 100
        contractStartBlock = block.number;
        
        setupPools();
    }
    
    // 4- create pools
    function setupPools() internal {
        
    //IVault(Vault).getTokenPrice(_stakedToken, _lpToken);
    //addPool(address _stakedToken, address _lpToken, bool _withdrawable, uint256 _allocPoint, bool _manualAllocPoint)
    uint256 price;
    
    
    
    //DFT-lp
    price = 100*1e18;
    //addPool( DFT-UNI,  address(0),  true,  price ,  false);
    
    //DFTP (NEW) -> worth x5 DFT price
    //addPool( DFTP, address(0), true, _allocPoint, false);
    
    //wBTC
    price = IVault(Vault).getTokenPrice(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, 0xBb2b8038a1640196FbE3e38816F3e67Cba72D940);
    addPool(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, 0xBb2b8038a1640196FbE3e38816F3e67Cba72D940,  true,  price ,  false);
    
    //USDC
    addPool(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc,   true,  price ,  false);

/*
    //USDT
    addPool(0xdAC17F958D2ee523a2206206994597C13D831ec7, 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852,   true,  price ,  false);
    //UNI
    addPool(address _stakedToken, address _lpToken,   true,  price ,  false);
    
    //YFI
    addPool(address _stakedToken, address _lpToken,   true,  price ,  false);
    
    //LINK
    addPool(address _stakedToken, address _lpToken,   true,  price ,  false);
    
    //MKR
    addPool(address _stakedToken, address _lpToken,   true,  price ,  false);
    
    //CEL
    addPool(address _stakedToken, address _lpToken,   true,  price ,  false);
    
    //SNX
    addPool(address _stakedToken, address _lpToken,   true,  price ,  false);
    
    //AAVE
    addPool(address _stakedToken, address _lpToken,   true,  price ,  false);
    
    //CORE
    addPool(address _stakedToken, address _lpToken,   true,  price ,  false);
    
    //AMPL
    addPool(address _stakedToken, address _lpToken,   true,  price ,  false);
    */
    }


//==================================================================================================================================
//POOL

//view stuff
    function poolLength() external view returns (uint256) {
        return poolInfo.length; //number of pools (PiDs)
    }

    // Returns fees generated since start of this contract, DFT only
    function averageFeesPerBlockSinceStart()
        external
        view
        returns (uint256 averagePerBlock)
    {
        averagePerBlock = cumulativeRewardsSinceStart
            .add(DFTrewardsInThisEpoch)
            .div(block.number.sub(contractStartBlock));
    }

    // Returns averge fees in this epoch, DFT only
    function averageFeesPerBlockEpoch()
        external
        view
        returns (uint256 averagePerBlock)
    {
        averagePerBlock = DFTrewardsInThisEpoch.div(
            block.number.sub(epochCalculationStartBlock)
        );
    }

    // For easy graphing historical epoch rewards
    mapping(uint256 => uint256) public epochRewards;

//set stuff (govenrors -> level inherited from DeFiat via governance)

    // Add a new token pool. Can only be called by governors.
    function addPool(
        address _stakedToken,
        address _lpToken,
        bool _withdrawable,
        uint256 _allocPoint,
        bool _manualAllocPoint
    ) public governanceLevel(2) {
        nonWithdrawableByAdmin[_stakedToken] = true; // stakedToken is now non-widthrawable by the admins.

        massUpdatePools();

        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            require(
                poolInfo[pid].stakedToken != _stakedToken,
                "Error pool already added"
            );
        }

        //Update staked token
        poolInfo.push(
            PoolInfo({
                stakedToken: _stakedToken,
                lpToken: _lpToken,
                allocPoint: _allocPoint, //updates token price 1e18 and pool weight accordingly
                accDFTPerShare: 0,
                accWETHPerShare: 0,
                lastRewardBlock: block.number,
                withdrawable: _withdrawable,
                isFotToken: false,
                isLpToken: false,
                manualAllocPoint: _manualAllocPoint,
                active: true
            })
        );

        //forces automatic price at creation if manualAllocPoint is false
        if (!poolInfo[poolInfo.length].manualAllocPoint) {
            poolInfo[poolInfo.length].allocPoint = getPrice(poolInfo.length);
        }
    }

    // Updates the given pool's allocation points manually. Can only be called with right governance levels.
    function setPoolAllocPoints(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public governanceLevel(2) {
        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function setPoolTokenType(
        uint256 _pid,
        bool _isFotToken,
        bool _isLpToken,
        bool _manualAllocPoint
    ) public governanceLevel(2) {
        poolInfo[_pid].isFotToken = _isFotToken;
        poolInfo[_pid].isLpToken = _isLpToken;
        poolInfo[_pid].manualAllocPoint = _manualAllocPoint;
    }

    function activateDeactivatePool(uint256 _pid, bool _active)
        public governanceLevel(2)
    {
        poolInfo[_pid].active = _active;
    }

    function setPoolWithdrawable(uint256 _pid, bool _withdrawable)
        public governanceLevel(2)
    {
        poolInfo[_pid].withdrawable = _withdrawable;
    }

//set stuff (anybody)
    //Starts a new calculation epoch; Because average since start will not be accurate. DFT only
    function startNewEpoch() public {
        require(
            epochCalculationStartBlock + 50000 < block.number,
            "New epoch not ready yet"
        ); // 50k blocks = About a week
        epochRewards[epoch] = DFTrewardsInThisEpoch;
        cumulativeRewardsSinceStart = cumulativeRewardsSinceStart.add(
            DFTrewardsInThisEpoch
        );
        DFTrewardsInThisEpoch = 0;
        epochCalculationStartBlock = block.number;
        ++epoch;
    }

    // Updates the reward variables of the given pool
    function updatePool(uint256 _pid) internal returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];

        uint256 tokenSupply = IERC20(pool.stakedToken).balanceOf(address(this));
        if (tokenSupply == 0 || pool.lastRewardBlock <= block.number) {
            // avoids division by 0 errors, pools being distributed rewards multiple times in one block
            return 0;
        }

        //DFT
        uint256 DFTReward =
            pendingDFTRewards // Multiplies pending rewards by allocation point of this pool and then total allocation
                .mul(pool.allocPoint) // getting the percent of total pending rewards this pool should get
                .div(totalAllocPoint); // we can do this because pools are only mass updated

        pool.accDFTPerShare = pool.accDFTPerShare.add(
            DFTReward.mul(1e18).div(tokenSupply)
        );

        //WETH
        uint256 WETHReward =
            pendingWETHRewards // Multiplies pending rewards by allocation point of this pool and then total allocation
                .mul(pool.allocPoint) // getting the percent of total pending rewards this pool should get
                .div(totalAllocPoint); // we can do this because pools are only mass updated

        pool.accWETHPerShare = pool.accWETHPerShare.add(
            WETHReward.mul(1e18).div(tokenSupply)
        );

        pool.lastRewardBlock = block.number;

        if (!pool.manualAllocPoint) {
            pool.allocPoint = getPrice(_pid); //updates pricing-weights AFTER.
        }

        return DFTReward;
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;

        uint256 allDFTRewards;

        for (uint256 pid = 0; pid < length; ++pid) {
            allDFTRewards = allDFTRewards.add(updatePool(pid)); //calls updatePool(pid)
        }
        pendingDFTRewards = pendingDFTRewards.sub(allDFTRewards);

        uint256 allWETHRewards;
        for (uint256 pid = 0; pid < length; ++pid) {
            allWETHRewards = allWETHRewards.add(updatePool(pid)); //calls updatePool(pid)
        }
        pendingWETHRewards = pendingWETHRewards.sub(allWETHRewards);

        //update prices if manualupdate.
        for (uint256 pid = 0; pid < length; ++pid) {
            if (poolInfo[pid].manualAllocPoint) {
                poolInfo[pid].allocPoint = getPrice(pid);
            }
        }
    }

    //payout of DFT Rewards, uses SafeDFTTransfer
    function updateAndPayOutPending(uint256 _pid, address user) internal {
        massUpdatePools();

        uint256 pending = pendingDFT(_pid, user);
        uint256 pending2 = pendingWETH(_pid, user);

        safeDFTTransfer(user, pending);
        IERC20(WETH).transfer(user, pending2);
    }

    // Safe DFT transfer function, Manages rounding errors and fee on Transfer
    function safeDFTTransfer(address _to, uint256 _amount) internal {
        if (_amount == 0) return;

        uint256 DFTBal = IERC20(DFT).balanceOf(address(this));
        if (_amount >= DFTBal) {
            IERC20(DFT).safeTransfer(_to, DFTBal);
        } else {
            IERC20(DFT).safeTransfer(_to, _amount);
        }

        DFTBalance = IERC20(DFT).balanceOf(address(this));
    }

    /* @dev called by the vault on staking/unstaking/claim
     *       updates the pendingRewards and the rewardsInThisEpoch variables for DFT
     */
    modifier onlyVault() {
        require(msg.sender == Vault);
        _;
    }

    uint256 private DFTBalance;
    uint256 private WETHBalance;
    
    function updateRewards() external onlyVault {
        //DFT
        uint256 newDFTRewards =
            IERC20(DFT).balanceOf(address(this)).sub(DFTBalance); //delta vs previous balanceOf

        if (newDFTRewards > 0) {
            DFTBalance = IERC20(DFT).balanceOf(address(this)); //balance snapshot
            pendingDFTRewards = pendingDFTRewards.add(newDFTRewards);
            DFTrewardsInThisEpoch = DFTrewardsInThisEpoch.add(newDFTRewards);
        }

        //WETH
        uint256 newWETHRewards =
            IERC20(WETH).balanceOf(address(this)).sub(WETHBalance); //delta vs previous balanceOf

        if (newWETHRewards > 0) {
            WETHBalance = IERC20(WETH).balanceOf(address(this)); //balance snapshot
            pendingWETHRewards = pendingWETHRewards.add(newWETHRewards);
            WETHrewardsInThisEpoch = WETHrewardsInThisEpoch.add(newWETHRewards);
        }
    }

    //gets stakedToken price from the VAULT contract based on the pool PID
    // returns the price if token is not LP, otherwise returns 0;
    function getPrice(uint256 _pid) public view returns (uint256) {
        address _stakedToken = poolInfo[_pid].stakedToken;
        address _lpToken = poolInfo[_pid].lpToken;

        uint256 price = 0;
        if (!poolInfo[_pid].isLpToken) {
            price = IVault(Vault).getTokenPrice(_stakedToken, _lpToken);
        }
        return price;
    }

    //==================================================================================================================================
    //USERS

    /* protects from a potential reentrancy in Deposits and Withdraws
     * users can only make 1 deposit or 1 wd per block
     */

    modifier NoReentrant(uint256 _pid, address _address) {
        require(
            block.number > userInfo[_pid][_address].lastRewardBlock,
            "Wait 1 block between each deposit/withdrawal"
        );
        _;
    }

// Deposit tokens to Vault to get allocation rewards
    function deposit(uint256 _pid, uint256 _amount) external NoReentrant(_pid, msg.sender) {
        require(_amount > 0, "cannot deposit zero tokens");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updateAndPayOutPending(_pid, msg.sender); //Transfer pending tokens, updates the pools

        

        // PID = 0 : DFTlp
        // PID = 1 : DFTP
        // PID = 2 : wETH (price = 1)
        // PID > 2 : all other tokens (wETH not supported, used as reward)
        
        uint256 stakingFeeAmount; 
        if (_pid <= 1) {stakingFeeAmount = 0;} //overides to zero if user is staking LP DFT-ETH tokens or DFTP tokens, _pid 0 and _pid 1
        else { stakingFeeAmount = _amount.mul(stakingFee).div(1000);}
       
        uint256 remainingUserAmount = _amount.sub(stakingFeeAmount);


    //Transfer the total amounts from user and update pool user.amount into the AnyStake contract
        IERC20(pool.stakedToken).transferFrom( msg.sender, address(this), _amount);



        //read the POOL struct to see if fee is taken, if fot token or etc...
        //TODO


        if(stakingFeeAmount != 0){
            
        // 1 - Anystake sends fee to Vault
            IERC20(pool.stakedToken).approve(Vault, 2**256 - 1); //Vault approved to take etokens from Anystake. note: could be at the add pool level to save gas
            IERC20(pool.stakedToken).transferFrom(address(this), Vault, stakingFeeAmount); //need permission -> initialize

        // 2- Anystake buys wETH with the fee (except if wETH = stakedToken)
        uint256 wETHBought = 0;
        if(pool.stakedToken != WETH){wETHBought = IVault(Vault).buyETHWithToken(pool.stakedToken, stakingFeeAmount);} 

        // 3- use 50% of wETH and buyDFT with them
        if (wETHBought != 0) {IVault(Vault).buyDFTWithETH(wETHBought.div(2));} //AMOUNT???!
        }

    //Finalize, update USER's metrics
        user.amount = user.amount.add(remainingUserAmount);
        user.rewardPaid = user.amount.mul(pool.accDFTPerShare).div(1e18);
        user.rewardPaid2 = user.amount.mul(pool.accWETHPerShare).div(1e18);
        user.lastRewardBlock = block.number;

        //update POOLS with 1% of Treasury
        IVault(Vault).pullRewards(DFT);
        IVault(Vault).pullRewards(WETH);

        emit Deposit(msg.sender, _pid, _amount);
    }


// Withdraw & Claim tokens from Vault.
    function withdraw(uint256 _pid, uint256 _amount) external NoReentrant(_pid, msg.sender) {
        _withdraw(_pid, _amount, msg.sender, msg.sender);
    }
    function emergencyWithdrawAll() external {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            
            uint256 _amount = userInfo[pid][msg.sender].amount.mul(100).div(99);
            _withdraw(pid, _amount, msg.sender, msg.sender);
            
            EmergencyWithdraw(msg.sender, pid, _amount);
        }
        
    }
    
    function claim(uint256 _pid) external NoReentrant(_pid, msg.sender) {
        _withdraw(_pid, 0, msg.sender, msg.sender);
    }
    function claimAll() external {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            _withdraw(pid, 0, msg.sender, msg.sender);        }  
    }
    
    //internal
    function _withdraw(
        uint256 _pid,
        uint256 _amount,
        address from,
        address to
    ) internal {
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.withdrawable, "Withdrawing from this pool is disabled");

        UserInfo storage user = userInfo[_pid][from];
        require(user.amount >= _amount, "withdraw: user amount insufficient");

        updateAndPayOutPending(_pid, from); // //Transfer pending tokens, massupdates the pools

        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            IERC20(pool.stakedToken).safeTransfer(address(to), _amount);
        }
        user.rewardPaid = user.amount.mul(pool.accDFTPerShare).div(1e18);
        user.lastRewardBlock = block.number;

        //update POOLS with 1% of Treasury
        IVault(Vault).pullRewards(DFT);
        IVault(Vault).pullRewards(WETH);

        emit Withdraw(to, _pid, _amount);
    }



// Getter function to see pending DFT rewards per user.
    function pendingDFT(uint256 _pid, address _user)
        public
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDFTPerShare = pool.accDFTPerShare;

        return user.amount.mul(accDFTPerShare).div(1e18).sub(user.rewardPaid);
    }

    // Getter function to see pending wETH rewards per user.
    function pendingWETH(uint256 _pid, address _user)
        public
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accWETHPerShare = pool.accWETHPerShare;

        return user.amount.mul(accWETHPerShare).div(1e18).sub(user.rewardPaid);
    }

    //==================================================================================================================================
    //GOVERNANCE & UTILS

    // Governance inherited from governance levels of DFTVaultAddress
    function viewActorLevelOf(address _address) public view returns (uint256) {
        return IGov(GOV).viewActorLevelOf(_address);
    }

    // INHERIT FROM DEFIAT GOV
    modifier governanceLevel(uint8 _level) {
        require(
            viewActorLevelOf(msg.sender) >= _level,
            "Grow some mustache kiddo..."
        );
        _;
    }

    //Anti RUG and EXIT by admins protocols
    mapping(address => bool) nonWithdrawableByAdmin;

    function isNonWithdrawbleByAdmins(address _token)
        public
        view
        returns (bool)
    {
        return nonWithdrawableByAdmin[_token];
    }

    function _widthdrawAnyToken(
        address _recipient,
        address _ERC20address,
        uint256 _amount
    ) public governanceLevel(2) returns (bool) {
        require(_ERC20address != DFT, "Cannot withdraw DFT from the pools");
        require(
            !nonWithdrawableByAdmin[_ERC20address],
            "this token is into a pool an cannot we withdrawn"
        );
        IERC20(_ERC20address).safeTransfer(_recipient, _amount); //use of the _ERC20 traditional transfer
        return true;
    } //get tokens sent by error, excelt DFT and those used for Staking.
}
