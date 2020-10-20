// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface myPoints {
    // launch code "AT ADDRESS"  0xBac9EF6a9eBF7e109c1011C68b0Dbac8C309fCc6

    //see your points
    function balanceOf(address _address) external view returns(uint256);
    
    //see the discount of an address in base 1000 (20 = 2%)
    function viewDiscountOf(address _address) external view returns(uint256);
    
    //check the eligibility of a discount. Returns a "tranche" -> 1 = 10%, 2 = 20%
    function viewEligibilityOf(address _address) external view returns (uint256 tranche);
    
    //update my discount: check my eligibility and activates the highest discount I can get.
    function updateMyDiscountOf() external returns (bool);
    
    /*Discount Table nbLoyalty Points -> discount
    0       -> 0%
    5       -> 10%
    10      -> 20%
    25      -> 30%
    50      -> 40%
    100     -> 50%
    250     -> 60%
    500     -> 70%
    1000    -> 80%
    100000  -> 90%
    */
    
    
    //force discount: gives an arbitrary discount (should not work for the pleb... only governance):
    function overrideDiscount(address _address, uint256 _newDiscount) external;
}

interface Governance{
    // launch code "AT ADDRESS"  0x064FD7D9C228e8a4a2bF247b432a34D6E1CB9442

    //shows burn and fees rate. Base 1000 ( 1 = 0.1%   10 = 1%   100 = 10%)
    function viewBurnRate() external returns (uint256); 
    function viewFeeRate() external returns (uint256); 

    //for governors only (should not work with plebls)
    //use base1000 numbers. 1 = 0.1%, 10 = 1%
    function changeBurnRate(uint _burnRate) external;     //base 1000
    function changeFeeRate(uint _feeRate) external;   //base 1000
    function setFeeDestination(address _nextDest) external view;
}

interface IDeFiat_Gov {
    function setActorLevel(address _address, uint256 _newLevel) external;
    function changeBurnRate(uint _burnRate) external;
    function changeFeeRate(uint _feeRate) external;
    function setFeeDestination(address _nextDest) external;

    //== SET EXTERNAL VARIABLES on the DeFiat_Points contract ==  
    function setTxTreshold(uint _amount) external;
    function overrideDiscount(address _address, uint256 _newDiscount) external;
    function overrideLoyaltyPoints(address _address, uint256 _newPoints) external;
    function setDiscountTranches(uint256 _tranche, uint256 _pointsNeeded) external;
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
}

interface IUniswapV2Pair {
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface X_DFTfarming {
    // at address: 
    function stake(uint256 amount) external; //stake shitcoins
    function unStake(uint256 amount) external; //wd Stake only
    function takeReward() external; //wd reward

    function myRewards() external view returns(uint256);
    function myStake() external view returns(uint256);
    // 100000000000000000000 = 100 TOKENS
}

interface X_Defiat_Token {
    // at address: 0xB571d40e4A7087C1B73ce6a3f29EaDfCA022C5B2
    function balanceOf(address account) external view returns(uint256);
    function approve(address spender, uint256 amount) external;
}

interface X_Defiat_Points {
    // 0x70C7d7856E1558210CFbf27b7F17853655752453
    function overrideDiscount(address _address, uint256 _newDiscount) external;
    function overrideLoyaltyPoints(address _address, uint256 _newPoints) external;
    function approve(address spender, uint256 amount) external;
        //whitelist the Locking Contract at 100 (100%) discount
}

interface X_flusher {
    function flushPool(address _recipient, address _ERC20address) external;
}

interface IDungeon {
    function myStake(address _address) external view returns(uint256);
}

interface I_Defiat_Points {
    // 0x70c7d7856e1558210cfbf27b7f17853655752453
    function overrideDiscount(address _address, uint256 _newDiscount) external;
    //whitelist the Locking Contract at 100 (100%) discount
}

interface IDeFiat_Points {
    function setTxTreshold(uint _amount) external;
}
