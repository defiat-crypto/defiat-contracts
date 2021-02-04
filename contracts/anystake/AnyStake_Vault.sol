// SPDX-License-Identifier: DeFiat and Friends (Zeppelin, MIT...)

pragma solidity ^0.6.6;

import "./AnyStake_Constants.sol";
import "./AnyStake_Libraries.sol";


// Vault distributes tokens to AnyStake, get token prices (oracle) and performs buybacks operations.
contract AnyStakeVault is AnyStakeBase, IVault {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event DFTBuyback(address indexed token, uint256 tokenAmount, uint256 buybackAmount);
    event DistributedRewards(address indexed user, uint256 anystakeAmount, uint256 regulatorAmount, uint256 bountyAmount);

    string public constant UNI_SYMBOL = "UNI-V2";

    address public AnyStake;
    address public Regulator;
    uint256 public distributionBounty; // % of collected rewards paid for distributing to AnyStake pools
    uint256 public distributionRate; // % of rewards which are sent to AnyStake
    uint256 public totalBuybackAmount;
    uint256 public totalRewardsDistributed;

    IERC20 DeFiat;
    IUniswapV2Router02 Router; 

    modifier onlyAnyStake() {
        require(msg.sender == AnyStake);
        _;
    }
    
    constructor(address router, address dft, address dftp, address anystake, address regulator) 
        public
        AnyStakeBase(router, dft, dftp)
    {
        AnyStake = anystake;
        Regulator = regulator;
        distributionBounty = 30; // 3%, base 100
        distributionRate = 800; // 80%, base 100
    }

    // Reward Distribution
    
    function distributeRewards() external override {
        uint256 amount = DeFiat.balanceOf(address(this));
        uint256 bountyAmount = amount.mul(distributionBounty).div(1000);
        uint256 rewardAmount = amount.sub(bountyAmount);
        uint256 anystakeAmount = rewardAmount.mul(distributionRate).div(1000);
        uint256 regulatorAmount = rewardAmount.sub(anystakeAmount);

        DeFiat.safeTransfer(AnyStake, anystakeAmount);
        DeFiat.safeTransfer(Regulator, regulatorAmount);

        IAnyStake(AnyStake).massUpdatePools();
        IRegulator(Regulator).updatePool();

        if (bountyAmount > 0) {
            DeFiat.safeTransfer(msg.sender, bountyAmount);
        }

        emit DistributedRewards(msg.sender, anystakeAmount, regulatorAmount, bountyAmount);
    }

    function setDistributionBounty(uint256 bounty) external governanceLevel(2) {
        require(bounty <= 1000, "Cannot be greater than 100%");
        distributionBounty = bounty;
    }

    function setDistributionRate(uint256 rate) external governanceLevel(2) {
        require(rate <= 1000, "Cannot be greater than 100%");
        distributionRate = rate;
    }
    
    
    // PRICE ORACLE

    // internal view function to view price of any token in ETH
    // return is 1e18. max Solidity is 1e77. 
    function getTokenPrice(address token, address lpToken) public override view returns (uint256) {
        if (token == WETH) {
            return 1e18;
        }
        
        bool isLpToken = isLiquidityToken(token);
        IUniswapV2Pair pair = isLpToken ? IUniswapV2Pair(token) : IUniswapV2Pair(lpToken);
        
        uint256 wethReserves;
        uint256 tokenReserves;
        if (pair.token0() == WETH) {
            (wethReserves, tokenReserves, ) = pair.getReserves();
        } else {
            (tokenReserves, wethReserves, ) = pair.getReserves();
        }
        
        if (tokenReserves == 0) {
            return 0;
        } else if (isLpToken) {
            return wethReserves.mul(2e18).div(IERC20(token).totalSupply());
        } else {
            uint256 adjuster = 36 - uint256(IERC20(token).decimals());
            uint256 tokensPerEth = tokenReserves.mul(10**adjuster).div(wethReserves);
            return uint256(1e36).div(tokensPerEth);
        }
    }

    function isLiquidityToken(address token) internal view returns (bool) {
        return keccak256(bytes(IERC20(token).symbol())) == keccak256(bytes(UNI_SYMBOL));
    }
    
    
    // UNISWAP PURCHASES
    
    //Buyback tokens with the staked fees (returns amount of tokens bought)
    //send procees to treasury for redistribution
    function buyDFTWithETH(uint256 amount) external override onlyAnyStake {
        if (amount == 0) {
            return;
        }

        address[] memory UniSwapPath = new address[](2);
        UniSwapPath[0] = WETH;
        UniSwapPath[1] = DFT;
     
        uint256 amountBefore = DeFiat.balanceOf(address(this));
        
        Router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amount
        }(
            0,
            UniSwapPath, 
            address(this), 
            block.timestamp + 5 minutes
        );

        uint256 amountAfter = DeFiat.balanceOf(address(this));
        
        emit DFTBuyback(WETH, amount, amountAfter.sub(amountBefore));
    }

    function buyDFTWithTokens(address token, uint256 amount) external override onlyAnyStake {
        if (amount == 0) {
            return;
        }
        
        address[] memory UniSwapPath = new address[](token == WETH ? 2 : 3);
        if (token == WETH) {
            UniSwapPath[0] = WETH; // WETH in
            UniSwapPath[1] = DFT; // DFT out
        } else {
            UniSwapPath[0] = token; // ERC20 in
            UniSwapPath[1] = WETH; // WETH intermediary
            UniSwapPath[2] = DFT; // DFT out
        }
     
        uint256 amountBefore = DeFiat.balanceOf(address(this)); // snapshot
        
        if (IERC20(token).allowance(address(this), UniswapV2Router02) == 0) {
            IERC20(token).approve(UniswapV2Router02, 2 ** 256 - 1);
        }

        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 
            0,
            UniSwapPath,
            address(this),
            block.timestamp + 5 minutes
        );

        uint256 amountAfter = DeFiat.balanceOf(address(this));
        
        emit DFTBuyback(token, amount, amountAfter.sub(amountBefore));
    }
}