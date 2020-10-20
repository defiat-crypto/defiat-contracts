// SPDX-License-Identifier: DeFiat 2020

pragma solidity ^0.6.0;
import "./_ERC20.sol";
import "./DeFiat_Governance.sol";
import "./DeFiat_Points.sol";

contract DeFiat_Token is _ERC20 {  //overrides the _transfer function and adds burn capabilities

    using SafeMath for uint;

//== Variables ==
    address private mastermind;     // token creator.
    address public DeFiat_gov;      // contract governing the Token
    address public DeFiat_points;   // ERC20 loyalty TOKEN

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    
    struct Transaction {
        address sender;
        address recipient;
        uint256 burnRate;
        uint256 feeRate;
        address feeDestination;
        uint256 senderDiscount;
        uint256 recipientDiscount;
        uint256 actualDiscount;
    }
    Transaction private transaction;
        
//== Modifiers ==
    modifier onlyMastermind {
        require(msg.sender == mastermind, "only Mastermind");
        _;
    }

    modifier onlyGovernor {
        require(msg.sender == mastermind || msg.sender == DeFiat_gov, "only Governance contract");
        _;
    } //only Governance managing contract

    modifier onlyPoints {
        require(msg.sender == mastermind || msg.sender == DeFiat_points, " only Points contract");
        _;
    }   //only Points managing contract

    //== Events ==
    event stdEvent(address _address, uint256 _number, bytes32 _signature, string _desc);
 
    //== Token generation ==
    constructor (address _gov, address _points) public {  //token requires that governance and points are up and running
        mastermind = msg.sender;
        _constructor("DeFiat","DFT"); //calls the ERC20 _constructor
        _mint(mastermind, 1e18 * 300000); //mint 300,000 tokens
        
        DeFiat_gov = _gov;      // contract governing the Token
        DeFiat_points = _points;   // ERC20 loyalty TOKEN
    }
    
//== mastermind ==
    function killContract() public onlyMastermind {
        selfdestruct(msg.sender); //destroys the contract
    } // TESTNET only Mastermind can kill contract
    
    function widthdrawAnyToken(address _recipient, address _ERC20address, uint256 _amount) public onlyGovernor returns (bool) {
        IERC20(_ERC20address).transfer(_recipient, _amount); //use of the _ERC20 traditional transfer
        return true;
    } //get tokens sent by error to contract

    function setGovernorContract(address _gov) external onlyGovernor {
        DeFiat_gov = _gov;
    }    // -> governance transfer
    
    function setPointsContract(address _pts) external onlyGovernor {
        DeFiat_points = _pts;
    }      // -> new points management contract
    
    function setMastermind(address _mastermind) external onlyMastermind {
        mastermind = _mastermind; //use the 0x0 address to resign
    }

    //== View variables from external contracts ==
    function _viewFeeRate() public view returns(uint256){
       return DeFiat_Gov(DeFiat_gov).viewFeeRate();
    }

    function _viewBurnRate() public view returns(uint256){
        return DeFiat_Gov(DeFiat_gov).viewBurnRate();
    }

    function _viewFeeDestination() public view returns(address){
        return DeFiat_Gov(DeFiat_gov).viewFeeDestination();
    }

    function _viewDiscountOf(address _address) public view returns(uint256){
        return DeFiat_Points(DeFiat_points).viewDiscountOf(_address);
    }

    function _viewPointsOf(address _address) public view returns(uint256){
        return DeFiat_Points(DeFiat_points).balanceOf(_address);
    }
  
    //== override _transfer function in the ERC20Simple contract ==    
    function updateTxStruct(address sender, address recipient) internal returns(bool){
        transaction.sender = sender;
        transaction.recipient = recipient;
        transaction.burnRate = _viewBurnRate();
        transaction.feeRate = _viewFeeRate();
        transaction.feeDestination = _viewFeeDestination();
        transaction.senderDiscount = _viewDiscountOf(sender);
        transaction.recipientDiscount = _viewDiscountOf(recipient);
        transaction.actualDiscount = SafeMath.max(transaction.senderDiscount, transaction.recipientDiscount);
        
         if( transaction.actualDiscount > 100){transaction.actualDiscount = 100;} //manages "forever pools"
    
        return true;
    } //struct used to prevent "stack too deep" error
    
    function addPoints(address sender, uint256 _amount) public {
        DeFiat_Points(DeFiat_points).addPoints(sender, _amount, 1e18); //Update user's loyalty points +1 = +1e18
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal override { //overrides the inherited ERC20 _transfer
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        
        //load transaction Struct (gets info from external contracts)
        updateTxStruct(sender, recipient);
        
        //get discounts and apply them. You get the MAX discounts of the sender x recipient. discount is base100
           
        uint256 dAmount = 
        SafeMath.div(
            SafeMath.mul(amount, 
                                SafeMath.sub(100, transaction.actualDiscount))
        ,100);     //amount discounted to calculate fees

    //Calculates burn and fees on discounted amount (burn and fees are 0.0X% ie base 10000)
        uint _toBurn = SafeMath.div(SafeMath.mul(dAmount,transaction.burnRate),10000); 
        uint _toFee = SafeMath.div(SafeMath.mul(dAmount,transaction.feeRate),10000); 
        uint _amount = SafeMath.sub(amount, SafeMath.add(_toBurn,_toFee)); //calculates the remaning amount to be sent
   
        //transfers -> forcing _ERC20 level
        if(_toFee > 0) {
        _ERC20._transfer(sender, transaction.feeDestination, _toFee); //native _transfer + emit
        } //transfer fee
        
        if(_toBurn > 0) {_ERC20._burn(sender,_toBurn);} //native _burn tokens from sender
        
        //transfer remaining amount. + emit
        _ERC20._transfer(sender, recipient, _amount); //native _transfer + emit

        //mint loyalty points and update lastTX
        if(sender != recipient){addPoints(sender, amount);} //uses the full amount to determine point minting

    }
}
