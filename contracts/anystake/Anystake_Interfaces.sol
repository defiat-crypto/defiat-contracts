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
}


//== UNISWAP SPECIFIC ==

// Taken for WETH contract https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2#code
interface IWETH {
    // string public name     = "Wrapped Ether";
    // string public symbol   = "WETH";
    // uint8  public decimals = 18;

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);
    event  Deposit(address indexed dst, uint wad);
    event  Withdrawal(address indexed src, uint wad);

    function balanceOf(address _address) external view returns (uint);
    // mapping (address => mapping (address => uint))  public  allowance;
    
    
    function deposit() external payable; //wrapping
    function withdraw(uint wad) external; //unwrapping
    
    
    function totalSupply() external view returns (uint);
    function approve(address guy, uint wad) external returns (bool);
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
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



//== ANYSTAKE SPECIFIC ==
interface IAnyStake {
    function updateRewards() external;
}

interface IVault {
    function buyDFTWithETH() external;
    function buyETHWithToken(address _token) external returns (uint256);
    
    function pullRewards(address _token) external;
    function getTokenPrice(address _token, address _lpToken) external view returns (uint256);
}

