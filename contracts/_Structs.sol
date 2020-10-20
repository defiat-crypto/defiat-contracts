// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

//Structs
struct PoolMetrics {
    address stakedToken;
    uint256 staked;             // sum of tokens staked in the contract
    uint256 stakingFee;         // entry fee
    
    uint256 stakingPoints;

    address rewardToken;
    uint256 rewards;        // current rewards in the pool

    uint256 startTime;      // when the pool opens
    uint256 closingTime;    // when the pool closes. 
    uint256 duration;       // duration of the staking
    uint256 lastEvent;   // last time metrics were updated.
    
    uint256  ratePerToken;      // CALCULATED pool reward Rate per Token (calculated based on total stake and time)
}

struct UserMetrics {
    uint256 stake;          // native token stake (balanceOf)
    uint256 stakingPoints;  // staking points at lastEvent
    uint256 poolPoints;     // pool point at lastEvent
    uint256 lastEvent;

    uint256 rewardAccrued;  // accrued rewards over time based on staking points
    uint256 rewardsPaid;    // for information only

    uint256 lastTxBlock;    // latest transaction from the user (antiSpam)
}