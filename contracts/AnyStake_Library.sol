//SPDX-License-Identifier: stupid

//Compiles and clean
//needs to be tested on Rinkeby
//needs front end integration (getters)

pragma solidity >= 0.6;

import "./AnyPrice.sol";
import "./_ERC20.sol";
import "./Address.sol";

contract AnyStake_Library is Any_Price {
    
    using SafeMath for uint256;
    using Address for address;

    struct Token {
        string name;
        string symbol;
        uint8 decimals; 
        uint256 spotPrice;
        bool activated; 
        uint8 boost;
    }
    mapping(address => Token) public tokens;
    address[] tokenList;
    
    constructor() public {
        allowed[_msgSender()] = true;

        UNIfactory = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f); //mainnet 
        //0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; MAINNET ETH
        
       wETHaddress = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); //mainnet 
        //0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; MAINNET ETH
    }
    
//getters for AnyStake are in Any_Price

//Token Library Management
    
    function addToken(address _token, bool _activated) public onlyAllowed {
       
    //mapping update
        (tokens[_token].name,
        tokens[_token].symbol,
        tokens[_token].decimals,
        ,
        tokens[_token].spotPrice)
        = getTokenInfo(_token);
        
        tokens[_token].activated = _activated;
        tokens[_token].boost = 100; //no boost
        
    //array update
        tokenList.push(_token);
    }
    
    function removeToken(address _token) public onlyAllowed {
        manageActivation(_token, false);
        
        //find _token and delete array entry
        uint256 _rank;
        for(uint i=0;i<nbTokensAdded(); i++){
            if(tokenList[i] == _token){_rank = i;}
        }
        if(_rank !=0){delete tokenList[_rank];}
        
        
    }

    function nbTokensAdded() public view returns(uint256) {
        return tokenList.length;
    }
    
    function manageActivation(address _token, bool _activated) public onlyAllowed {
        tokens[_token].activated = _activated;
    }
    
   function manageBoost(address _token, uint8 _boost) public onlyAllowed {
        tokens[_token].boost = _boost;
    }
    
    function getTokenFromList(uint256 _rank) public view returns(
        string memory name, string memory symbol, uint8 decimals, uint256 spotPrice, bool activated, uint8 boost) {
            
            address _token = tokenList[_rank];
            return(
                tokens[_token].name,
                tokens[_token].symbol,
                tokens[_token].decimals,
                tokens[_token].spotPrice,
                tokens[_token].activated,
                tokens[_token].boost);
        }
  
    
}
