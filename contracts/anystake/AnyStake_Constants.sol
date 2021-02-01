// SPDX-License-Identifier: DeFiat and Friends (Zeppelin, MIT...)

pragma solidity ^0.6.2;

import {IGov, IDeFiat, IUniswapV2Router02, IUniswapV2Factory} from "./AnyStake_Interfaces.sol";

abstract contract AnyStakeBase {
  
    address public immutable UniswapV2Router02;
    address public immutable UniswapV2Factory;
    address public immutable WETH;
    address public immutable DFT;
    address public immutable DFTP;
    address public immutable DFT_LP;
    address public immutable DFTP_LP;

    constructor(address router, address dft, address dftp) public {
        UniswapV2Router02 = router;
        DFT = dft;
        DFTP = dftp;
         
        address weth = IUniswapV2Router02(router).WETH();
        address factory = IUniswapV2Router02(router).factory();
        WETH = weth;
        UniswapV2Factory = factory; 
        DFT_LP = IUniswapV2Factory(factory).getPair(dft, weth);
        DFTP_LP = IUniswapV2Factory(factory).getPair(dftp, weth);
    }

    // address public constant UniswapV2Router02 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    
    // address public constant UniswapV2Factory = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    // address public constant WETH = address(0xc778417E063141139Fce010982780140Aa0cD5Ab); // RINKEBY
    
    // address public constant DFT = address(0xB571d40e4A7087C1B73ce6a3f29EaDfCA022C5B2); //RINKEBY
    
    // address public constant DFTP = address(0x70C7d7856E1558210CFbf27b7F17853655752453);  //RINKEBY

    // address public constant DFT_LP = address(0x70C7d7856E1558210CFbf27b7F17853655752453);  //RINKEBY

    // address public constant DFTP_LP = address(0x70C7d7856E1558210CFbf27b7F17853655752453);  //RINKEBY
    
    // address public constant _2ND = address(0x88e6Eca53FBBD5e1a81C0029Ad01F8e6827C8f78); //RINKEBY

    function viewActorLevelOf(address _address) public view returns (uint256) {
        return IGov(IDeFiat(DFT).DeFiat_gov()).viewActorLevelOf(_address);
    }

    // INHERIT FROM DEFIAT GOV
    modifier governanceLevel(uint8 _level) {
        require(
            viewActorLevelOf(msg.sender) >= _level,
            "Grow some mustache kiddo..."
        );
        _;
    }
}