pragma solidity ^0.6.2;

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

// Taken for WETH9 contract
// https://etherscan.io/address/0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2#code
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
    function deposit() external payable;
    function withdraw(uint wad) external;
    function totalSupply() external view returns (uint);
    function approve(address guy, uint wad) external returns (bool);
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}

interface IVault {
    function buyDFTWithETH() external;
    function buyETHWithToken(address _token) external returns (uint256);
    function pullRewards(address _token) external;
    function getTokenPrice(address _token, address _lpToken) external view returns (uint256);
}

interface IGov {
    function viewActorLevelOf(address _address) external view returns (uint256);
}

interface IDeFiat {
    function DeFiat_gov() external view returns (address);
}

