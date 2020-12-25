pragma solidity ^0.6.0;

import "./models/_ERC20.sol";

contract DeFiat_Points is _ERC20{
    
    //global variables
    address public deFiat_Token;                        //DeFiat token address 
    mapping(address => bool) public deFiat_Gov;         //governing addresses
    
    uint256 public txThreshold; //min tansfer to generate points
    mapping (uint => uint256) public _discountTranches;
    mapping (address => uint256) private _discounts; //current discount (base100)


    //== modifiers ==
    modifier onlyGovernors {
        require(deFiat_Gov[msg.sender] == true, "Only governing contract");
        _;
    }
    modifier onlyToken {
        require(msg.sender == deFiat_Token, "Only token");
        _;
    }
    
    constructor() public { //token and governing contract
        deFiat_Gov[msg.sender] = true; //msg.sender is the 1st governor
        _constructor("DeFiat Points", "DFTP"); //calls the ERC20 "_constructor" to update token name
        //no minting. _totalSupply = 0
    }

    //== VIEW ==

    function viewDiscountOf(address _address) public view returns (uint256) {
        return _discounts[_address];
    }

    function viewEligibilityOf(address _address) public view returns (uint256 tranche) {
        uint256 _tranche = 0;
        for(uint256 i=0; i<=9; i++){ //from top to bottom 
           if(balanceOf(_address) >= _discountTranches[i]) { 
             _tranche = i;}
           else{break;} //break when 
        }
        return _tranche;
    }

    function discountPointsNeeded(uint _tranche) public view returns (uint256 pointsNeeded) {
        return( _discountTranches[_tranche]); //check the nb of points needed to access discount tranche
    }

    //== SET ==
    function updateMyDiscountOf() public returns (bool) {
        uint256 _tranche = viewEligibilityOf(msg.sender);
        _discounts[msg.sender] =  SafeMath.mul(10, _tranche); //update of discount base100
        return true;
    }  //users execute this function to upgrade a status level to the max tranche

    //== SET onlyGovernor ==
    function setDeFiatToken(address _token) external onlyGovernors returns(address){
        return deFiat_Token = _token;
    }
    
    function setGovernor(address _address, bool _rights) external onlyGovernors {
        require(msg.sender != _address); //prevents self stripping of rights
        deFiat_Gov[_address] = _rights;
    }
    
    function setTxTreshold(uint _amount) external onlyGovernors {
        txThreshold = _amount; 
    } //minimum amount of tokens to generate points per transaction

    function overrideDiscount(address _address, uint256 _newDiscount) external onlyGovernors {
        require(_newDiscount <= 100); //100 = 100% discount
        _discounts[_address]  = _newDiscount;
    }

    function overrideLoyaltyPoints(address _address, uint256 _newPoints) external onlyGovernors {
        _burn(_address, balanceOf(_address)); //burn all points
        _mint(_address, _newPoints); //mint new points
    }
    
    function setDiscountTranches(uint _tranche, uint256 _pointsNeeded) external onlyGovernors {
        require(_tranche <10, "max tranche is 9"); //tranche 9 = 90% discount
        _discountTranches[_tranche] = _pointsNeeded;
    }
    
    function setAll10DiscountTranches(
            uint256 _pointsNeeded1, uint256 _pointsNeeded2, uint256 _pointsNeeded3, uint256 _pointsNeeded4, 
            uint256 _pointsNeeded5, uint256 _pointsNeeded6, uint256 _pointsNeeded7, uint256 _pointsNeeded8, 
            uint256 _pointsNeeded9) public onlyGovernors {
        _discountTranches[0] = 0;
        _discountTranches[1] = _pointsNeeded1; //10%
        _discountTranches[2] = _pointsNeeded2; //20%
        _discountTranches[3] = _pointsNeeded3; //30%
        _discountTranches[4] = _pointsNeeded4; //40%
        _discountTranches[5] = _pointsNeeded5; //50%
        _discountTranches[6] = _pointsNeeded6; //60%
        _discountTranches[7] = _pointsNeeded7; //70%
        _discountTranches[8] = _pointsNeeded8; //80%
        _discountTranches[9] = _pointsNeeded9; //90%
    }
    
    //== MINT points onlyToken ==  
    function addPoints(address _address, uint256 _txSize, uint256 _points) external onlyToken {
        if(_txSize >= txThreshold){ _mint(_address, _points);}
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal override virtual {
        _ERC20._transfer(sender, recipient, amount);
        //force update discount
        uint256 _tranche = viewEligibilityOf(msg.sender);
        _discounts[msg.sender] =  SafeMath.mul(10, _tranche);
        
    }  //overriden to update discount at every points Transfer. Avoids passing tokens to get discounts.
    
} 
