pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/lifecycle/Pausable.sol";

contract Remittance is Pausable {
    using SafeMath for uint256;

    event LogRemittanceCreated(address indexed owner, uint256 indexed maxDeltaBlocks);
    event LogRemittanceSendFunds(address indexed caller, uint256 indexed amount, uint256 expBlock, bytes32 hash);
    event LogRemittanceWithdraw(address indexed caller, uint256 indexed amount, bytes32 hash);
    event LogRemittanceClaim(address indexed caller, uint256 indexed amount, bytes32 hash);
    
    struct Payment {
        address src;
        uint256 amount;
        uint256 expBlock;
    }

    uint256 public maxDeltaBlocks;
    mapping(bytes32 => Payment) public payments;

    constructor(uint256 _maxDeltaBlocks)  public {
       require(_maxDeltaBlocks != 0, "_maxDeltaBlocks is zero");

       maxDeltaBlocks = _maxDeltaBlocks;
       emit LogRemittanceCreated(msg.sender, _maxDeltaBlocks);
    }

    /*
    **   completeHash: bobSecret+CarolAddress
    */
    function sendFunds(bytes32 completeHash, uint256 deltaBlocks) public whenNotPaused payable {
       require(msg.value != 0, "sendFunds: msg.value is zero");
       require(completeHash != 0, "sendFunds: completeHash is zero");
       require(deltaBlocks > 0 && deltaBlocks <= maxDeltaBlocks , "sendFunds: deltaBlocks out of range");

       // check if entry is empty; password can not be reused
       Payment storage myPayment = payments[completeHash];
       require(myPayment.src == address(0)  , "sendFunds: user uses wrong hash");
	   
       uint256 expBlock = deltaBlocks.add(block.number);

       myPayment.src = msg.sender;
       myPayment.amount = msg.value;
       myPayment.expBlock = expBlock;
       emit LogRemittanceSendFunds(msg.sender, msg.value, expBlock, completeHash);
    }

    function withdraw(bytes32 password) public whenNotPaused {
        require(password != 0, "withdraw: password is zero");
		
        bytes32 completeHash = hash(password, msg.sender);
        Payment storage thePayment = payments[completeHash];

        require(block.number <= thePayment.expBlock, "withdraw: end of block reached");
        
        uint256 amount = thePayment.amount;
        require(amount > 0, "withdraw: payment amount is zero");
        
        thePayment.amount = 0;
        thePayment.expBlock = 0;

        emit LogRemittanceWithdraw(msg.sender, amount, completeHash);

        msg.sender.transfer(amount);
    }

   function claim(bytes32 completeHash) public whenNotPaused {
        require(completeHash != 0, "claim: completeHash is zero");

        Payment storage myPayment = payments[completeHash];

        require(msg.sender == myPayment.src, "claim: msg.sender is not src");
        require(block.number > myPayment.expBlock, "claim: block.number is not greater than endBlock");
        
        uint256 amount = myPayment.amount;
        require(amount > 0, "claim: payment amount is zero");

        myPayment.amount = 0;
        myPayment.expBlock = 0;

        emit LogRemittanceClaim(msg.sender, amount, completeHash);

        msg.sender.transfer(amount);
   }

   function hash(bytes32 hash1, address account) public view returns(bytes32 completeHash) {
       return keccak256(abi.encodePacked(this, hash1, account));
   }
}
