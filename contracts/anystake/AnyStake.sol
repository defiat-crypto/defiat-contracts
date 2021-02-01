// SPDX-License-Identifier: DeFiat and Friends (Zeppelin, MIT...)

pragma solidity ^0.6.2;

import "./AnyStake_Constants.sol";
import "./AnyStake_Libraries.sol";
import "hardhat/console.sol";

//series of pool weighted by token price (using price oracles on chain)
contract AnyStake is AnyStakeBase, IAnyStake {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // USERS METRICS
    // pending reward = (user.amount * pool.DFTPerShare) - user.rewardPaid
    struct UserInfo {
        uint256 amount; // How many tokens the user has provided.
        uint256 rewardPaid; // DFT already Paid. See explanation below.
        uint256 lastRewardBlock; // last pool interaction
    }

    // POOL METRICS
    struct PoolInfo {
        address stakedToken; // Address of staked token contract.
        address lpToken; // uniswap LP token corresponding to the trading pair needed for price calculation
        uint256 allocPoint; // How many allocation points assigned to this pool. DFTs to distribute per block. (ETH = 2.3M blocks per year)
        uint256 accDFTPerShare; // Accumulated DFTs per share, times 1e18. See below.
        uint256 lastRewardBlock; // last pool update
        uint256 valueLocked; // total value of tokens staked in pool (ETH), calculated every update
        bool active; // whether pool is accepting deposits (default = true)
    }

    // EVENTS
    event Claim(address indexed user, uint256 indexed pid, uint256 amount);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    address public Vault; //where rewards are stored for distribution

    PoolInfo[] public poolInfo; // array of AnyStake pools
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // mapping of (pid => (userAddress => userInfo))
    mapping(uint256 => uint256) public epochRewards; // For easy graphing historical epoch rewards
    mapping(address => uint256) public pids; // quick mapping for pool ids (staked_token => pid)
    mapping(address => bool) nonWithdrawableByAdmin; // Anti RUG and EXIT by admins protocols

    uint256 public stakingFee; // fee to stake ERC-20 tokens
    uint256 public totalAllocPoint; // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalValueLocked; // Total value locked in AnyStake (ETH)
    uint256 public pendingDFTRewards; // pending DFT rewards awaiting anyone to massUpdate
    uint256 public DFTBalance; // contract balance of DFT to track rewards

    uint256 public contractStartBlock;
    uint256 public epochCalculationStartBlock;
    uint256 public cumulativeRewardsSinceStart;
    uint256 public rewardsInThisEpoch;
    uint256 public epoch;

    /* protects from a potential reentrancy in Deposits and Withdraws
    * users can only make 1 deposit or 1 wd per block
    */
    modifier NoReentrant(uint256 pid, address user) {
        require(
            block.number > userInfo[pid][user].lastRewardBlock,
            "No Reentrancy: Must wait 1 block performing this operation"
        );
        _;
    }

    /* @dev called by the vault on staking/unstaking/claim
    *       updates the pendingRewards and the rewardsInThisEpoch variables for DFT
    */
    modifier onlyVault() {
        require(msg.sender == Vault);
        _;
    }

    constructor(address router, address dft, address dftp) public AnyStakeBase(router, dft, dftp) {
        stakingFee = 50; // 5%, base 100
    }
    
    // Initialize pools/rewards after the Vault has been setup
    function initialize(address _Vault) public governanceLevel(2) {
        Vault = _Vault;
        contractStartBlock = block.number;
        
        setupPools();
    }
    
    // 4- create pools
    function setupPools() internal {
        //DFT-LP
        //addPoolManual(DFTLP, address(0), 250);
        
        //DFTP-LP
        //addPoolManual(DFTPLP, address(0), 250);
        
        //wBTC
        addPool(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, 0xBb2b8038a1640196FbE3e38816F3e67Cba72D940);
        
        //USDC
        addPool(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);

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
        
        */
    }


    //==================================================================================================================================
    // POOL

    /// Views

    function poolLength() external view returns (uint256) {
        return poolInfo.length; // number of pools (pids)
    }

    // Returns fees generated since start of this contract, DFT only
    function averageFeesPerBlockSinceStart()
        external
        view
        returns (uint256 averagePerBlock)
    {
        averagePerBlock = cumulativeRewardsSinceStart
            .add(rewardsInThisEpoch)
            .div(block.number.sub(contractStartBlock));
    }

    // Returns averge fees in this epoch, DFT only
    function averageFeesPerBlockEpoch()
        external
        view
        returns (uint256 averagePerBlock)
    {
        averagePerBlock = rewardsInThisEpoch.div(
            block.number.sub(epochCalculationStartBlock)
        );
    }

    // Starts a new calculation epoch, return if too soon; Averages can become inaccurate over time
    // 50k blocks = About a week
    function startNewEpoch() public override {
        if (epochCalculationStartBlock + 50000 < block.number) {
            return;
        }

        epochRewards[epoch] = rewardsInThisEpoch;
        cumulativeRewardsSinceStart = cumulativeRewardsSinceStart.add(rewardsInThisEpoch);
        rewardsInThisEpoch = 0;
        epochCalculationStartBlock = block.number;
        ++epoch;
    }

    function addPool(address token, address lpToken) public governanceLevel(2) {
        _addPool(token, lpToken, 100);
    }

    function addPoolManual(address token, address lpToken, uint256 allocPoint) public governanceLevel(2) {
        _addPool(token, lpToken, allocPoint);
    }

    // Add a new token pool. Can only be called by governors.
    function _addPool(
        address stakedToken,
        address lpToken,
        uint256 allocPoint
    ) internal {
        require(pids[stakedToken] == 0, "Pool already added");
        pids[stakedToken] = poolInfo.length;
        nonWithdrawableByAdmin[stakedToken] = true; // stakedToken now non-withrawable by admins

        // Add new pool
        poolInfo.push(
            PoolInfo({
                stakedToken: stakedToken,
                lpToken: lpToken,
                allocPoint: allocPoint,
                lastRewardBlock: block.number,
                valueLocked: 0,
                accDFTPerShare: 0,
                active: true
            })
        );
    }

    /// Pool Configuration

    // Updates the given pool's allocation points manually. Can only be called with right governance levels.
    function setPoolAllocPoints(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public governanceLevel(2) {
        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function setPoolActive(uint256 _pid, bool _active)
        public governanceLevel(2)
    {
        poolInfo[_pid].active = _active;
    }

    // Updates the reward variables of the given pool
    // Only called from massUpdatePools()
    function updatePool(uint256 pid) internal returns (uint256) {
        PoolInfo storage pool = poolInfo[pid];

        uint256 tokenSupply = IERC20(pool.stakedToken).balanceOf(address(this));
        if (tokenSupply == 0 || pool.lastRewardBlock <= block.number) {
            // avoids division by 0 errors, pools being distributed rewards multiple times in one block
            return 0;
        }

        //DFT
        uint256 DFTReward = pendingDFTRewards // Multiplies pending rewards by allocation point of this pool and then total allocation
            .mul(pool.allocPoint.mul(pool.valueLocked)) // getting the percent of total pending rewards this pool should get
            .div(totalAllocPoint.mul(totalValueLocked)); // we can do this because pools are only mass updated

        // this math probably isnt going to work since tokenSupply is not necessarily 1e18
        pool.accDFTPerShare = pool.accDFTPerShare.add(DFTReward.mul(1e18).div(tokenSupply));
        pool.lastRewardBlock = block.number;

        return DFTReward;
    }

    function massUpdatePools() public override onlyVault {
        startNewEpoch(); // try to start a new rewards epoch
        updateRewards(); // update with new rewards

        // update pool total value locked vars
        uint length = poolInfo.length;
        totalValueLocked = 0;
        for (uint256 pid = 0; pid < length; ++pid) {
            uint256 price = getPrice(pid);
            poolInfo[pid].valueLocked = IERC20(poolInfo[pid].stakedToken).balanceOf(address(this)).mul(price);
            totalValueLocked = totalValueLocked.add(poolInfo[pid].valueLocked);
        }

        // calculate updated rewards
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
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
    
    function updateRewards() internal {
        uint256 newDFTRewards = IERC20(DFT).balanceOf(address(this)).sub(DFTBalance); // delta vs previous balanceOf

        if (newDFTRewards > 0) {
            DFTBalance = IERC20(DFT).balanceOf(address(this)); //balance snapshot
            pendingDFTRewards = pendingDFTRewards.add(newDFTRewards);
            rewardsInThisEpoch = rewardsInThisEpoch.add(newDFTRewards);
        }
    }

    // gets stakedToken price from the VAULT contract based on the pool PID
    // returns the price if token is not LP, otherwise returns 0;
    function getPrice(uint256 pid) public view returns (uint256) {
        address token = poolInfo[pid].stakedToken;
        address lpToken = poolInfo[pid].lpToken;

        return IVault(Vault).getTokenPrice(token, lpToken);
    }

    //==================================================================================================================================
    //USERS

    function claim(uint256 pid) external override NoReentrant(pid, msg.sender) {
        _claim(pid, msg.sender);
    }

    function claimAll() external override {
        for (uint256 pid = 0; pid < poolInfo.length; ++pid) {
            _claim(pid, msg.sender);
        }  
    }

    function _claim(uint256 pid, address user) internal {
        UserInfo storage _user = userInfo[pid][user];
        uint256 pending = pendingDFT(pid, user);

        if (pending == 0) {
            return;
        }

        safeDFTTransfer(user, pending);

        _user.rewardPaid = _user.amount.mul(poolInfo[pid].accDFTPerShare).div(1e18);
        _user.lastRewardBlock = block.number;
    }

    // Deposit tokens to Vault to get allocation rewards
    function deposit(uint256 pid, uint256 amount) external override NoReentrant(pid, msg.sender) {
        require(amount > 0, "Deposit: Cannot deposit zero tokens");
        require(poolInfo[pid].active, "Deposit: Pool is not active");

        _claim(pid, msg.sender); // Claim pending rewards

        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage user = userInfo[pid][msg.sender];

        // Transfer the total amounts from user and update pool user.amount into the AnyStake contract
        IERC20(pool.stakedToken).safeTransferFrom(msg.sender, address(this), amount);

        // PID = 0 : DFT-LP
        // PID = 1 : DFTP-LP
        // PID = 2 : wETH (price = 1e18)
        // PID > 2 : all other tokens
        // No fee on DFT-ETH, DFTP-ETH pools
        uint256 stakingFeeAmount = pid >= 2 ? amount.mul(stakingFee).div(1000) : 0; 
        uint256 remainingUserAmount = amount.sub(stakingFeeAmount);

        if(stakingFeeAmount > 0){
            // 1 - Send Fee to Vault
            IERC20(pool.stakedToken).safeTransfer(Vault, stakingFeeAmount);

            // 2 - Buy DFT with Fee
            if (pool.stakedToken == WETH) {
                IVault(Vault).buyDFTWithETH(stakingFeeAmount);
            } else {
                IVault(Vault).buyDFTWithTokens(pool.stakedToken, stakingFeeAmount);
            }
        }

        // Finalize, update POOL and USER metrics
        user.amount = user.amount.add(remainingUserAmount);
        user.rewardPaid = user.amount.mul(pool.accDFTPerShare).div(1e18);
        user.lastRewardBlock = block.number;

        emit Deposit(msg.sender, pid, amount);
    }


    // Withdraw & Claim tokens from Vault.
    function withdraw(uint256 pid, uint256 amount) external override NoReentrant(pid, msg.sender) {
        _withdraw(pid, msg.sender, amount);
    }
    
    // internal
    function _withdraw(
        uint256 pid,
        address user,
        uint256 amount
    ) internal {
        PoolInfo storage pool = poolInfo[pid];
        UserInfo storage _user = userInfo[pid][user];

        require(amount > 0, "Withdraw: amount must be greater than zero");
        require(_user.amount >= amount, "Withdraw: user amount insufficient");

        // updatePool(pid);
        _claim(pid, user);

        _user.amount = _user.amount.sub(amount);
        IERC20(pool.stakedToken).safeTransfer(user, amount);        

        emit Withdraw(user, pid, amount);
    }

    // function emergencyWithdrawAll() external {
    //     uint256 length = poolInfo.length;
    //     for (uint256 pid = 0; pid < length; ++pid) {
    //         uint256 amount = userInfo[pid][msg.sender].amount.mul(100).div(99);
    //         _withdraw(pid, amount, msg.sender, msg.sender);
            
    //         EmergencyWithdraw(msg.sender, pid, amount);
    //     }
    // }

    // Getter function to see pending DFT rewards per user.
    function pendingDFT(uint256 pid, address user)
        public
        view
        returns (uint256)
    {
        UserInfo memory _user = userInfo[pid][user];
        uint256 accDFTPerShare = poolInfo[pid].accDFTPerShare;

        // not sure if this will work with tokens non-1e18 decimals
        return _user.amount.mul(accDFTPerShare).div(1e18).sub(_user.rewardPaid);
    }

    //==================================================================================================================================
    //GOVERNANCE & UTILS

    function isNonWithdrawbleByAdmins(address _token)
        public
        view
        returns (bool)
    {
        return nonWithdrawableByAdmin[_token];
    }

    // Get tokens sent by error, except DFT and those used for Staking
    function withdrawAnyToken(
        address _recipient,
        address _token,
        uint256 _amount
    ) public governanceLevel(2) returns (bool) {
        require(_token != DFT, "Cannot withdraw DFT from AnyStake");
        require(!nonWithdrawableByAdmin[_token], "Cannot withdraw tokens that are staked in AnyStake");

        IERC20(_token).transfer(_recipient, _amount); //use of the _ERC20 traditional transfer
        return true;
    }
}
