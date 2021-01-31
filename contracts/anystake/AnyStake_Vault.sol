// SPDX-License-Identifier: DeFiat and Friends (Zeppelin, MIT...)

pragma solidity ^0.6.6;

import "./AnyStake_Constants.sol";
import "./AnyStake_Libraries.sol";


// Vault distributes tokens to AnyStake, get token prices (oracle) and performs buybacks operations.
contract AnyStakeVault is AnyStakeBase, IVault {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event DFTBuyback(address indexed token, uint256 tokenAmount, uint256 buybackAmount);
    event DistributedRewards(address indexed user, uint256 rewardAmount, uint256 bountyAmount);

    address public AnyStake;
    address public Regulator;
    uint256 public distributionBounty; // % of collected rewards paid for distributing to AnyStake pools

    modifier onlyAnyStake() {
        require(msg.sender == AnyStake);
        _;
    }
    
    constructor(address _anystake, address _regulator) public {
        AnyStake = _anystake;
        Regulator = _regulator;
        distributionBounty = 30; // 3%, base 100
    }
    
    function distributeRewards() external override {
        uint256 amount = IERC20(DFT).balanceOf(address(this));
        uint256 bountyAmount = amount.mul(distributionBounty).div(1000);
        uint256 rewardAmount = amount.sub(bountyAmount);

        IERC20(DFT).safeTransfer(AnyStake, rewardAmount);
        // IERC20(DFT).safeTransfer(Regulator, rewardAmount);

        IAnyStake(AnyStake).updateRewards(); // updates rewards
        IAnyStake(AnyStake).massUpdatePools();
        // IRegulator(Regulator).updatePool();

        if (bountyAmount > 0) {
            IERC20(DFT).safeTransfer(msg.sender, bountyAmount);
        }

        emit DistributedRewards(msg.sender, rewardAmount, bountyAmount);
    }
    
    
    // PRICE ORACLE

    // internal view function to view price of any token in ETH
    // return is 1e18. max Solidity is 1e77. 
    function getTokenPrice(address _token, address _lpToken) public override view returns (uint256) {
        if (_token == WETH) {
            return 1e18;
        }
        
        // USE VWAP TO AVOID FLASH LOAN ATTACKS 
        // https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/libraries/UniswapV2OracleLibrary.sol#L16
        uint256 tokenBalance = IERC20(_token).balanceOf(_lpToken);
        if (tokenBalance > 0) {
            uint256 wethBalance = IERC20(WETH).balanceOf(_lpToken);
            uint256 adjuster = 36 - uint256(IERC20(_token).decimals()); // handle non-base 18 tokens
            uint256 tokensPerEth = tokenBalance.mul(10**adjuster).div(wethBalance);
            return uint256(1e36).div(tokensPerEth); // price in gwei of token
        } else {
            return 0;
        }
    }
    
    
    // UNISWAP PURCHASES
    
    //Buyback tokens with the staked fees (returns amount of tokens bought)
    //send procees to treasury for redistribution
    function buyDFTWithETH(uint256 amount) external override onlyAnyStake {
        address[] memory UniSwapPath = new address[](2);
        UniSwapPath[0] = WETH;
        UniSwapPath[1] = DFT;
     
        uint256 amountBought = IERC20(DFT).balanceOf(address(this)); // snapshot
        
        IUniswapV2Router02(UniswapV2Router02).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0,
            UniSwapPath, 
            address(this), 
            1 days
        );
        
        //Calculate the amount of tokens Bought
        if (IERC20(DFT).balanceOf(address(this)) > amountBought) {
            amountBought = IERC20(DFT).balanceOf(address(this)).sub(amountBought);
        } else {
            amountBought = 0;
        }
        
        emit DFTBuyback(WETH, amount, amountBought);
    }

    function buyDFTWithTokens(address token, uint256 amount) external override onlyAnyStake {
        address[] memory UniSwapPath = new address[](3);
        UniSwapPath[0] = token; // ERC20 in
        UniSwapPath[1] = WETH; // WETH intermediary
        UniSwapPath[2] = DFT; // DFT out
     
        uint256 amountBought = IERC20(DFT).balanceOf(address(this)); // snapshot
        
        IUniswapV2Router02(UniswapV2Router02).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 
            0,
            UniSwapPath,
            address(this),
            1 days
        );
        
        // Calculate the amount of tokens Bought
        if (IERC20(DFT).balanceOf(address(this)) > amountBought) {
            amountBought = IERC20(WETH).balanceOf(address(this)).sub(amountBought);
        } else { 
            amountBought = 0;
        }
        
        emit DFTBuyback(token, amount, amountBought);
    }
}

// // Buyback tokens with the staked fees (returns amount of tokens bought)
// // send procees to treasury for redistribution
// function buyETHWithToken(address _token, uint256 _amountIN) internal returns(uint256){
//     address[] memory UniSwapPath = new address[](2);
//     UniSwapPath[0] = _token;   //token staked (fee taken)
//     UniSwapPath[1] = WETH;
    
//     uint256 amountBought = IERC20(WETH).balanceOf(address(this)); //snapshot
    
//     IUniswapV2Router02(UniswapV2Router02).swapExactTokensForTokensSupportingFeeOnTransferTokens(
//         _amountIN, 
//         0,
//         UniSwapPath,
//         address(this),
//         1 days
//     );
    
//     //Calculate the amount of tokens Bought
//     if (IERC20(WETH).balanceOf(address(this))> amountBought) {
//         amountBought = IERC20(WETH).balanceOf(address(this)).sub(amountBought);
//     } else { 
//         amountBought = 0;
//     }
    
//     return amountBought;
// }