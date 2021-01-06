//// SPDX-License-Identifier: DEFIAT 2020


pragma solidity ^0.6.2;

// import "./AnyStake_Library.sol";
import "./AnyStake_Interfaces.sol";
import "../libraries/SafeMath.sol";
import "../libraries/SafeERC20.sol";

contract AnyStake {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public DFT; //DeFiat token address
    address public GOV; //DeFiat GOV contract address
    address public Treasury; //where rewards are stored for distribution
    uint256 public treasuryFee;
    uint256 public pendingTreasuryRewards;

    address public constant UniswapV2Router02 =
        address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public constant UniswapV2Factory =
        address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    // address public constant WETH = address(0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2); // MAINNET
    address public constant WETH =
        address(0xc778417E063141139Fce010982780140Aa0cD5Ab); // RINKEBY

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

    //INITIALIZE
    constructor(address _DFT, address _Treasury) public {
        DFT = _DFT;
        Treasury = _Treasury; // DFT Central
        GOV = IDeFiat(DFT).DeFiat_gov();

        stakingFee = 50; // 5%base 1000

        contractStartBlock = block.number;
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
    ) public {
        poolInfo[_pid].isFotToken = _isFotToken;
        poolInfo[_pid].isLpToken = _isLpToken;
        poolInfo[_pid].manualAllocPoint = _manualAllocPoint;
    }

    function activateDeactivatePool(uint256 _pid, bool _active)
        public
        governanceLevel(2)
    {
        poolInfo[_pid].active = _active;
    }

    function setPoolWithdrawable(uint256 _pid, bool _withdrawable)
        public
        governanceLevel(2)
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
        IWETH(WETH).transfer(user, pending2);
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
    modifier onlyTreasury() {
        require(msg.sender == Treasury);
        _;
    }

    uint256 private DFTBalance;
    uint256 private WETHBalance;

    function updateRewards() external onlyTreasury {
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
            price = IVault(Treasury).getTokenPrice(_stakedToken, _lpToken);
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
    function deposit(uint256 _pid, uint256 _amount)
        external
        NoReentrant(_pid, msg.sender)
    {
        require(_amount > 0, "cannot deposit zero tokens");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updateAndPayOutPending(_pid, msg.sender); //Transfer pending tokens, updates the pools

        // Calculate fees 95% default staking fee on non LP tokens)
        uint256 stakingFeeAmount = _amount.mul(stakingFee).div(1000);
        if (_pid <= 1) {
            stakingFeeAmount = 0;
        } //overides to zero if user is staking LP DFT-ETH tokens or DFT tokens, _pid 0 and _pid 1

        uint256 remainingUserAmount = _amount.sub(stakingFeeAmount);

        //Transfer the amounts from user and update pool user.amount
        IERC20(pool.stakedToken).transferFrom(
            msg.sender,
            address(this),
            _amount
        ); //GET ALL TOKENS FROM USER

        //read the POOL struct to see if fee is taken, if fot token or etc...
        //TODO

        //1st move = get fee to Vault
        IERC20(pool.stakedToken).transferFrom(
            address(this),
            Treasury,
            stakingFeeAmount
        ); //GET ALL TOKENS FROM USER

        //2- buy wETH with the token
        uint256 wETHBought = IVault(Treasury).buyETHWithToken(pool.stakedToken);

        //3- use 50% of wETH and buyDFT with them
        if (wETHBought != 0) {
            IVault(Treasury).buyDFTWithETH();
        }

        //Send fees to Treasury (for redistribution later)
        IERC20(pool.stakedToken).transfer(Treasury, stakingFeeAmount.div(2));

        //Finalize, update USER's metrics
        user.amount = user.amount.add(remainingUserAmount);
        user.rewardPaid = user.amount.mul(pool.accDFTPerShare).div(1e18);
        user.rewardPaid2 = user.amount.mul(pool.accWETHPerShare).div(1e18);
        user.lastRewardBlock = block.number;

        //update POOLS with 1% of Treasury
        IVault(Treasury).pullRewards(DFT);
        IVault(Treasury).pullRewards(WETH);

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw tokens from Vault.
    function withdraw(uint256 _pid, uint256 _amount)
        external
        NoReentrant(_pid, msg.sender)
    {
        _withdraw(_pid, _amount, msg.sender, msg.sender);
    }

    function claim(uint256 _pid) external NoReentrant(_pid, msg.sender) {
        _withdraw(_pid, 0, msg.sender, msg.sender);
    }

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
        IVault(Treasury).pullRewards(DFT);
        IVault(Treasury).pullRewards(WETH);

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
