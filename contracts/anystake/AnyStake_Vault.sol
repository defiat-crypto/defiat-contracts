// SPDX-License-Identifier: DeFiat and Friends (Zeppelin, MIT...)

pragma solidity ^0.6.6;

import "./AnyStake_Constants.sol";
import "./AnyStake_Libraries.sol";


// Vault distributes tokens to AnyStake, get token prices (oracle) and performs buybacks operations.
contract AnyStakeVault is AnyStake_Constants {
    using SafeMath for uint256;

    address public AnyStake;
    
    constructor(address _anystake) public {
        AnyStake = _anystake;
    }
    
    function pullRewards(address _token) external {
        require(msg.sender == AnyStake);
        uint256 _amount = IERC20(_token).balanceOf(address(this)).div(100); //1% of total treasury
        IERC20(_token).transfer(AnyStake, _amount);
        IAnyStake(AnyStake).updateRewards(); //updates rewards
    }
    
    
// PRICE ORACLE

    // internal view function to view price of any token in ETH
    function getTokenPrice(address _token, address _lpToken) public view returns (uint256) {
        
        if (_token == WETH) {
            return 1e18;
        }
        
        uint256 tokenBalance = IERC20(_token).balanceOf(_lpToken);
        if (tokenBalance > 0) {
            uint256 wethBalance = IERC20(WETH).balanceOf(_lpToken);
            uint256 adjuster = 36 - uint256(IERC20(_token).decimals()); // handle non-base 18 tokens
            uint256 tokensPerEth = tokenBalance.mul(10**adjuster).div(wethBalance);
            return uint256(1e36).div(tokensPerEth); // price in gwei of token
        } else {
            return 0;
        }
    //return is 1e18. max Solidity is 1e77. 
    }
    
    
// UNISWAP PURCHASES
        
    //Buyback tokens with the staked fees (returns amount of tokens bought)
    //send procees to treasury for redistribution
    function buyETHWithToken(address _token, uint256 _amountIN) internal returns(uint256){
        
        address[] memory UniSwapPath = new address[](2);
            UniSwapPath[0] = _token;   //token staked (fee taken)
            UniSwapPath[1] = WETH;
     
        uint256 amountBought = IERC20(WETH).balanceOf(address(this)); //snapshot
        
        IUniswapV2Router02(UniswapV2Router02).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIN, 0,UniSwapPath, address(this), 1 days);
        
        //Calculate the amount of tokens Bought
        if (IERC20(WETH).balanceOf(address(this))> amountBought) {
            amountBought = IERC20(WETH).balanceOf(address(this)).sub(amountBought);
        } else { 
            amountBought = 0;
        }
        
        return amountBought;
    }
    
    //Buyback tokens with the staked fees (returns amount of tokens bought)
    //send procees to treasury for redistribution
    function buyDFTWithETH(uint256 _amountETH) internal returns(uint256){
        address[] memory UniSwapPath = new address[](2);

        UniSwapPath[0] = WETH;
        UniSwapPath[1] = DFT;
     
        uint256 amountBought = IERC20(DFT).balanceOf(address(this)); // snapshot
        
        IUniswapV2Router02(UniswapV2Router02).swapExactETHForTokensSupportingFeeOnTransferTokens(
            _amountETH,UniSwapPath, address(this), 1 days);
        
        //Calculate the amount of tokens Bought
        if (IERC20(DFT).balanceOf(address(this)) > amountBought) {
            amountBought = IERC20(DFT).balanceOf(address(this)).sub(amountBought);
        } else {
            amountBought = 0;
        }
        
        return amountBought;
    }
    
}
