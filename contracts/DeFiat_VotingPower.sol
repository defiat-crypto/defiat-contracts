// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

// DeFiat Snapshot Voting Power Contract
// 
// This contract calculates the amount of votes (in 1e18) a user has.
// When using this contract with snapshot, we can fairly calculate each address's total network stake at a given block
//
// Voting Power Algorithm:
// MY_VOTING_POWER = DFT_BALANCE 
//  + (DFT_LP_BALANCE * PRICE_IN_DFT)
//  + TOTAL_DFT_STAKED 
//  + TOTAL_DFT_PENDING_REWARDS 
//  + (TOTAL_DFT_LP_STAKED * PRICE_IN_DFT)
//
// In order to compute LP voting power, we get the current price of the DFT LP token,
//  which is half ETH and half DFT, then convert the ETH into DFT, and add the two values


import "./_Interfaces.sol";
import "./SafeMath.sol";
import "./ERC20_Utils.sol";
import "./_ERC20.sol";
import "./Uni_Price_v2.sol";

contract DeFiat_VotingPower is ERC20_Utils, Uni_Price_v2 {
    using SafeMath for uint256;
    
    address public defiat;
    address public defiatLp;
    address public wethAddress;
    uint internal stackPointer; // pointer for staking pool stack
    
    struct PoolStruct {
        address poolAddress;
        address stakedAddress;
        address rewardAddress;
    }
    mapping (uint => PoolStruct) public stakingPools; // pools to calculate voting power from

    constructor() 
        Uni_Price_v2(
            0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, 
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        ) // MAINNET
        // Uni_Price_v2(
        //     0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f, 
        //     0xc778417E063141139Fce010982780140Aa0cD5Ab
        // ) // RINKEBY
    public {
        defiat = address(0xB6eE603933E024d8d53dDE3faa0bf98fE2a3d6f1); // MAINNET
        // defiat = address(0xB571d40e4A7087C1B73ce6a3f29EaDfCA022C5B2); // RINKEBY

        defiatLp = address(0xe2A1d215d03d7E9Fa0ed66355c86678561e4940a); // MAINNET
        // defiatLp = address(0xF7426EAcb2b00398D4cefb3E24115c91821d6fB0); // RINKEBY
    }

    function myVotingPower(address _address) public view returns (uint256) {
        // power initialized to DFT Balance
        uint256 _power;
        uint256 dftBalance = _ERC20(defiat).balanceOf(_address);
        uint256 dftLpBalance = _ERC20(defiatLp).balanceOf(_address);
        uint256 dftLpPower = getLiquidityTokenPower(defiatLp, dftLpBalance);
        for (uint i = 0; i < stackPointer; i++) {
            PoolStruct memory pool = stakingPools[i];
            // get base staked tokens
            uint256 stakedTokens = getStake(_address, pool.poolAddress);

            // if its an LP token, we convert to total DFT value of tokens
            // essentially x2 multiplier for LP votes
            if (isUniLiquidityToken(pool.stakedAddress)) {
                stakedTokens = getLiquidityTokenPower(pool.stakedAddress, stakedTokens);
            }

            // get reward tokens if the pool rewards in DFT
            uint256 rewardTokens;
            if (pool.rewardAddress == defiat) {
                rewardTokens = getRewards(_address, pool.poolAddress);
            }
            

            _power = _power.add(stakedTokens).add(rewardTokens);
        }

        return _power.add(dftBalance).add(dftLpPower);
    }

    function getLiquidityTokenPower(address tokenAddress, uint256 stakedTokens) public view returns (uint256) {
        uint112 tokenReserves;
        uint112 wethReserves;
        uint256 tokensPerEth; 
        address token0 = IUniswapV2Pair(tokenAddress).token0();
        address token1 = IUniswapV2Pair(tokenAddress).token1();
        
        if (token0 == wethAddress) {
            (wethReserves, tokenReserves, ) = IUniswapV2Pair(tokenAddress).getReserves();
            tokensPerEth = getUniPrice(token1);
        } else {
            (tokenReserves, wethReserves, ) = IUniswapV2Pair(tokenAddress).getReserves();
            tokensPerEth = getUniPrice(token0);
        }

        uint256 wethInTokens = uint256(wethReserves)
            .mul(tokensPerEth)
            .div(1e18);

        uint256 totalSupply = _ERC20(tokenAddress).totalSupply();
        uint256 tokensPerLiquidityToken = wethInTokens
            .add(uint256(tokenReserves))
            .mul(1e18)
            .div(totalSupply);

        return stakedTokens.mul(tokensPerLiquidityToken).div(1e18);
    }

    function getStake(address _address, address _poolAddress) internal view returns (uint256) {
        return IDungeon(_poolAddress).myStake(_address);
    }

    function getRewards(address _address, address _poolAddress) internal view returns (uint256) {
        return IDungeon(_poolAddress).myRewards(_address);
    }

    // Owner functions

    function pushStakingPool(address _poolAddress, address _stakedAddress, address _rewardAddress) external onlyOwner {
        stakingPools[stackPointer++] = PoolStruct(_poolAddress, _stakedAddress, _rewardAddress);
    }

    function popStakingPool() external onlyOwner {
        require(stackPointer > 0, "Nothing to pop!");
        delete(stakingPools[--stackPointer]);
    }

    function flushPools() external onlyOwner {
        require(stackPointer > 0, "Nothing to pop!");
        while (stackPointer > 0) {
            delete(stakingPools[--stackPointer]);
        }
    }
}