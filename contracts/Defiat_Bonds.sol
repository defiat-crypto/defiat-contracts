//SPDX-Licence-Identifier: DeFiat.net

pragma solidity ^0.6.0;

import "./models/_Interfaces.sol";
import "./libraries/Context.sol";
import "./libraries/SafeMath.sol";

interface Dungeon {
    function myStake(address _address) external view returns(uint256);
}

contract DeFiat_Bonds is Context {

    using SafeMath for uint256;

    mapping(address => bool) public allowed;
    modifier onlyAllowed() {
        require(allowed[_msgSender()] == true, "onlyAllowed");
        _;
    }

    struct Bond {
        address token;
        uint256 duration;
        uint256 yield;
        uint256 penalty;    // base 100 penalty for exiting early.
        uint256 entryReq;   // entry requirement
        uint256 staked;     // total amount of tokens staked
    }
    Bond public bond;
    
    address public DefiatDungeon;
    
    
    struct Clients {
        uint256 deposited;  // needed to avoid people sending tokens without reseting the maturity.
        uint256 depositDate;
    }
    mapping(address => Clients) public clients;


    constructor(address _token, uint256 _nbDays, uint256 _yield, uint256 _penalty, uint256 _entryReq) public {
        
        bond.token = _token;
        bond.duration = 24*3600*_nbDays;
        bond.yield = _yield;                    // base 100 yield = 150 = +50%;
        bond.entryReq = _entryReq.mul(1e18);    // nb tokens staked in the DFT contract
        bond.penalty = _penalty;

        DefiatDungeon = address(0xB508Dd7EeD4517bc66462cd384c0849d99B160fc);
        allowed[_msgSender()] = true;
    }
    
    
    function myDungeonStake(address _address) public view returns(uint256) {
        return Dungeon(DefiatDungeon).myStake(_address);
    }
        
    modifier canParticpate(address _address) {
        require(myDungeonStake(_address)>= bond.entryReq, "Need to stake more in Dungeon");
        _;
    }
 
 
    /**
     * @dev allows clients to lock their tokens back + the bond's yield
     * at the end of the maturity period.
     * 
     * Every time a client deposits, it resets their maturity counter
     * If a client sent tokens to the contract, sending 0 tokens to it 
     * will have them to account in the bond.
     */
    function _deposit(address _address, uint256 _amount) internal canParticpate (_address){
        clients[_address].depositDate = block.timestamp; //before to avoid reentrancy
        IERC20(bond.token).transferFrom(_address, address(this), _amount);
        
        clients[_address].deposited = IERC20(bond.token).balanceOf(_address); //manages deflationary tokens
    }
    
    
    /**
     * @dev client's widthdrawal of tokens at the end of the maturity period
     * triggers yield for the bond.
     * 
     * The use of 'balanceOf' allows the users to retrive  tokens 
     * they may have sent to the contract instead of using the 'deposit' function.
     */
    function _widthdraw(address _address) internal {
        clients[_address].depositDate = block.timestamp;
        uint256 _yield = clients[_address].deposited.mul(bond.yield).div(100);
        IERC20(bond.token).transfer(_address, IERC20(bond.token).balanceOf(_address).add(_yield));
    }
    
    
    /**
     * @dev clients widthdrawal of tokens before the maturity period
     * incurs a penalty and no yield is generated.
     * 
     * The use of 'balanceOf' allows the users to retrive  tokens 
     * they may have sent to the contract instead of using the 'deposit' function.
     * 
     */
    function _cancel(address _address) internal {
        clients[_address].depositDate = block.timestamp;
        uint256 _amount = IERC20(bond.token).balanceOf(_address);
        uint256 _fee = _amount.mul(bond.penalty).div(100);
        IERC20(bond.token).transfer(_address, _amount.sub(_fee));
    }


//external functions
    function deposit(uint256 _amount) external canParticpate(_msgSender()) {
        _deposit(_msgSender(), _amount);
    }
    
    function withdraw() external canParticpate(_msgSender()) {
        require(canWithdraw(_msgSender()) == true);
        _widthdraw(_msgSender());
    }
    
    function cancel() external {
        _cancel(_msgSender());
    }

//getters
    function canWithdraw(address _address) public view returns(bool) {
      bool _canWd = false;
      if(block.timestamp >= maturity(_address)){_canWd = true;}
      return _canWd;
    }
    
    function maturity(address _address) public view returns(uint256) {
        return clients[_address].depositDate.add(bond.duration);
    }
}


