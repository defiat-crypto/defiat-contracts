// SPDX-License-Identifier: DeFiat and Friends (Zeppelin, MIT...)

pragma solidity ^0.6.2;

//== GENERIC ==
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

//== UNISWAP SPECIFIC ==

// Taken for WETH contract https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2#code
interface IWETH {
    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);

    function balanceOf(address _address) external view returns (uint);
    // mapping (address => mapping (address => uint))  public  allowance;

    function deposit() external payable; //wrapping
    function withdraw(uint wad) external; //unwrapping    
    
    function totalSupply() external view returns (uint);
    function approve(address guy, uint wad) external returns (bool);
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}

interface IUniswapV2Pair {
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
    function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
} 
    
interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactETHForTokensSupportingFeeOnTransferTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens( uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
}

//== DEFIAT SPECIFIC ==

interface IGov {
    function viewActorLevelOf(address _address) external view returns (uint256);
}

interface IDeFiat {
    function DeFiat_gov() external view returns (address);
}

interface IPoints {
    function overrideLoyaltyPoints(address _address, uint256 _newPoints) external; 
}

//== ANYSTAKE SPECIFIC ==

interface IAnyStake {
    function massUpdatePools() external;
    function startNewEpoch() external;
    function claim(uint256 pid) external;
    function claimAll() external;
    function deposit(uint256 pid, uint256 amount) external;
    function withdraw(uint256 pid, uint256 amount) external;
}

interface IRegulator {
    function updatePool() external;
    function claim() external;
    function deposit(uint256 amount) external;
}

interface IVault {
    event DFTBuyback(address indexed token, uint256 tokenAmount, uint256 buybackAmount);
    event DistributedRewards(address indexed user, uint256 rewardAmount, uint256 bountyAmount);

    function buyDFTWithETH(uint256 amount) external;
    function buyDFTWithTokens(address token, uint256 amount) external;
    function distributeRewards() external;
    function getTokenPrice(address token, address lpToken) external view returns (uint256);
}

