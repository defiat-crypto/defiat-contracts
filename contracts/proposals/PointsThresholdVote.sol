pragma solidity ^0.6.0;

import "../voting/_Vote.sol";

// contract must be given governor rights

contract PointsThresholdVote is _Vote {
    address public DeFiat_Points;

    constructor (
        address _DeFiat_Points,
        address _DeFiat_Gov,
        address _rewardToken,
        address _uniFactoryAddress,
        address _wethAddress
    ) public 
        _Vote(
            _DeFiat_Gov, 
            168, // no delay
            168, // 4 days
            "Points Threshold Vote",
            3, // 3 choices
            0,
            _rewardToken, 
            5 * 1e18,
            _uniFactoryAddress,
            _wethAddress
        )
    {               
        DeFiat_Points = _DeFiat_Points;
    }

    function proposalAction(uint winningChoice) internal override returns (bool) {
        uint256 newRate;
        if (winningChoice == 0) {
            newRate = 10 * 1e18;
        } else if (winningChoice == 1) {
            newRate = 50 * 1e18;
        } else {
            newRate = 100 * 1e18;
        }

        IDeFiat_Points(DeFiat_Points).setTxTreshold(newRate);

        return true;
    }
}