pragma solidity ^0.6.0;

import "../_Vote.sol";

// contract must be given governor rights

contract FeeBurnRateVote is _Vote {
  constructor (
      address _DeFiat_Gov,
      address _rewardToken,
      address _uniFactoryAddress,
      address _wethAddress
  ) public 
    _Vote(
        _DeFiat_Gov,
        12, // 12 hr delay
        168, // 7 day duration
        "Fee Burn Rate Vote",
        3, // 3 choices
        0,
        _rewardToken, 
        5 * 1e18,
        _uniFactoryAddress,
        _wethAddress
    )
  {
  }

  function proposalAction(uint winningChoice) internal override returns (bool) {
    uint256 newRate;
    if (winningChoice == 0) {
      newRate = 0;
    } else if (winningChoice == 1) {
      newRate = 10;
    } else {
      newRate = 50;
    }

    IDeFiat_Gov(DeFiat_Gov).changeFeeRate(newRate);
    IDeFiat_Gov(DeFiat_Gov).changeBurnRate(newRate);

    return true;
  }
}