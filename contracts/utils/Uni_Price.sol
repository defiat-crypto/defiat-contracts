//SPDX-License-Identifier: stupid

pragma solidity >= 0.6;

import "../libraries/SafeMath.sol";
import "../models/_Interfaces.sol";
import "../models/_ERC20.sol";

contract Uni_Price {
    using SafeMath for uint112;
    using SafeMath for uint256;
    
    address public UNIfactory;
    address public wETHaddress;
    address public owner;
 
    modifier onlyOwner {
        require(msg.sender == owner, "only owner");
        _;
    }
    
    constructor(address _UNIfactory, address _wETHaddress) public {
        owner = msg.sender;
        UNIfactory = _UNIfactory; 
        //0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; MAINNET ETH
        //0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f; RINKEBY ETH

        wETHaddress = _wETHaddress; 
        //0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2; MAINNET ETH
        //0xc778417E063141139Fce010982780140Aa0cD5Ab; RINKEBY ETH
    }
    
    
    function getUNIpair(address _token) internal view returns(address) {
        return IUniswapV2Factory(UNIfactory).getPair(_token, wETHaddress);
    }
    function _getUint256Reserves(address _token) internal view returns(uint256 rToken, uint256 rWETH) {
        address _UNIpair = getUNIpair(_token);
                
        address _token0 = IUniswapV2Pair(_UNIpair).token0(); 
        address _token1 = IUniswapV2Pair(_UNIpair).token1(); 
        require(_token0 == wETHaddress || _token1 == wETHaddress);
        
        uint112 _rTKN; uint112 _rWETH;
        
        if(_token0 == wETHaddress) {
        (_rWETH, _rTKN, ) = IUniswapV2Pair(_UNIpair).getReserves(); //returns r0, r1, time
        }
        else {
        (_rTKN, _rWETH, ) = IUniswapV2Pair(_UNIpair).getReserves();
        }
        
        return (uint256(_rTKN),uint256(_rWETH)); //price in gwei, needs to be corrected by nb of decimals of _token
         //price of 1 token in GWEI
    }  
    
    function adjuster(address _token) internal view returns(uint256) {
        uint8 _decimals = _ERC20(_token).decimals();
        require(_decimals <= 18,"OverFlow risk, not supported");
        uint256 _temp = 36 - uint256(_decimals);
        return 10**_temp;
    }
    
    function getUNIprice(address _token) internal view returns(uint) {

        uint256 rToken; uint256 rWETH; uint256 _adjuster;
        (rToken, rWETH) = _getUint256Reserves(_token);
        _adjuster = adjuster(_token);
        

        return ( (rToken).mul(_adjuster) ).div(rWETH);       //IN GWEI
    }
    
    function getTokenInfo(address _token) public view returns(
        string memory name, string memory symbol, uint8 decimals, address uniPair, uint256 tokensPerETH) {
        return(
            _ERC20(_token).name(), 
            _ERC20(_token).symbol(), 
            _ERC20(_token).decimals(), 
            getUNIpair(_token), 
            getUNIprice(_token)
            ); //normalized as if every token is 18 decimals
    }
  
//ERC20_utils  
    function widthdrawAnyToken(address _token) external onlyOwner returns (bool) {
        uint256 _amount = _ERC20(_token).balanceOf(address(this));
        _widthdrawAnyToken(msg.sender, _token, _amount);
        return true;
    } //get tokens sent by error to contract

    function _widthdrawAnyToken(address _recipient, address _ERC20address, uint256 _amount) internal returns (bool) {
        _ERC20(_ERC20address).transfer(_recipient, _amount); //use of the _ERC20 traditional transfer
        return true;
    } //get tokens sent by error

    function kill() public onlyOwner{
        selfdestruct(msg.sender);
    } //frees space on the ETH chain
}

