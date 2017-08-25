/*

  Copyright 2017 Loopring Project Ltd (Loopring Foundation).

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/
pragma solidity ^0.4.11;

import '../SafeMath.sol';
import './Token.sol';

/// @title Mid-Team Holding Incentive Program
/// @author Daniel Wang - <daniel@loopring.org>, Kongliang Zhong - <kongliang@loopring.org>.
contract LRCMidTermHoldingContract {
    using SafeMath for uint;

    // During the first 90 days of deployment, this contract opens for deposit of LRC
    // in exchange of ETH.
    uint public constant DEPOSIT_WINDOW                 = 60 days;

    // For each address, its LRC can only be withdrawn between 180 and 270 days after LRC deposit,
    // which means:
    //    1) LRC are locked during the first 180 days,
    //    2) LRC will be sold to the `owner` with the specified `RATE` 270 days after the deposit.
    uint public constant WITHDRAWAL_DELAY               = 180 days;
    uint public constant WITHDRAWAL_WINDOW              = 90  days;

    uint public constant MAX_LRC_DEPOSIT_PER_ADDRESS    = 150000 ether; // = 20 ETH

    // 7500 LRC for 1 ETH. This rate is the best token sale rate ever.
    uint public constant RATE       = 7500; 
    uint public constant FEE_FACTOR = 100;

    address public lrcTokenAddress  = 0x0;
    address public owner            = 0x0;

    // Some stats
    uint public lrcDeposited        = 0;
    uint public lrcWithdrawn        = 0;
    uint public ethReceived         = 0;
    uint public ethSent             = 0;

    uint public depositStartTime    = 0;
    uint public depositStopTime     = 0;
    uint public depositIndex        = 0;
    uint public withdrawIndex       = 0;
    bool public closed              = false;

    struct Record {
        uint ethAmount;
        uint timestamp;
    }

    mapping (address => Record) records;
    
    /* 
     * EVENTS
     */

    /// Emitted for each sucuessful deposit.
    event Deposit(uint issueIndex, address addr, uint ethAmount, uint lrcAmount);

    /// Emitted for each sucuessful withdrawal.
    event Withdrawal(uint issueIndex, address addr, uint ethAmount, uint lrcAmount);

    /// Emitted when this contract is closed.
    event Closed(uint ethAmount, uint lrcAmount);

    /// Emitted when ETH are drained.
    event Drained(uint ethAmount);

    
    /// CONSTRUCTOR 
    /// @dev Initialize and start the contract.
    /// @param _lrcTokenAddress LRC ERC20 token address
    /// @param _owner Owner of this contract
    function LRCMidTermHoldingContract(address _lrcTokenAddress, address _owner) {
        require(_lrcTokenAddress != 0x0);
        require(_owner != 0x0);

        lrcTokenAddress = _lrcTokenAddress;
        owner = _owner;

        depositStartTime = now;
        depositStopTime  = now + DEPOSIT_WINDOW;
    }

    /*
     * PUBLIC FUNCTIONS
     */

    /// @dev Get back ETH to `owner`.
    /// @param ethAmount Amount of ETH to drain back to owner
    function drain(uint ethAmount) public payable {
        require(ethAmount > 0);
        require(msg.sender == owner);

        uint amount = ethAmount.min256(this.balance);

        require(owner.send(amount));
        Drained(amount);
    }

    /// @dev Get all ETH and LRC back to `owner`.
    function close() public payable {
        require(!closed);
        require(msg.sender == owner);
        require(now > depositStopTime + WITHDRAWAL_DELAY + WITHDRAWAL_WINDOW); 

        var ethAmount = this.balance;
        if (ethAmount > 0) {
          require(owner.send(ethAmount));
        }

        var lrcToken = Token(lrcTokenAddress);
        var lrcAmount = lrcToken.balanceOf(address(this));
        if (lrcAmount > 0) {
          require(lrcToken.transfer(owner, lrcAmount));
        }

        closed = true;
        Closed(ethAmount, lrcAmount);
    }

    /// @dev This default function allows simple usage.
    function () payable {
        if (msg.sender == owner) {
           require(!closed);
        } else if (now <= depositStopTime) {
            depositLRC();
        } else if (now > depositStopTime){
            withdrawLRC();
        }
    }

  
    /// @dev Deposit LRC for ETH.
    /// If user send x ETH, this method will try to transfer `x * 100 * 6500` LRC from
    /// the user's address and send `x * 100` ETH to the user.
    function depositLRC() payable {
        require(!closed && msg.sender != owner);
        require(msg.value > 0);
        require(now <= depositStopTime);

        var record = records[msg.sender];
        var lrcToken = Token(lrcTokenAddress);

        var ethAmount = this.balance
            .min256(lrcToken.balanceOf(msg.sender).div(RATE))
            .min256(MAX_LRC_DEPOSIT_PER_ADDRESS.div(RATE) - record.ethAmount)
            .min256(msg.value.mul(FEE_FACTOR));

        require(ethAmount > 0);

        record.ethAmount += ethAmount;
        record.timestamp = now;
        records[msg.sender] = record;

        var lrcAmount = ethAmount.mul(RATE);

        lrcDeposited += lrcAmount;
        ethSent += ethAmount;

        require(msg.sender.send(ethAmount + msg.value - ethAmount.div(FEE_FACTOR)));
        require(lrcToken.transfer(address(this), lrcAmount));

        Deposit(
             depositIndex++,
             msg.sender,
             ethAmount,
             lrcAmount
        );      
    }

    /// @dev Withdrawal LRC with ETH transfer.
    function withdrawLRC() payable {
        require(!closed && msg.sender != owner);
        require(msg.value > 0);
        require(now > depositStopTime);

        var record = records[msg.sender];
        require(now >= record.timestamp + WITHDRAWAL_DELAY);
        require(now <= record.timestamp + WITHDRAWAL_DELAY + WITHDRAWAL_WINDOW);

        require(msg.value <= record.ethAmount);

        uint ethAmount = msg.value
            .min256(record.ethAmount)
            .min256(this.balance);

        record.ethAmount -= ethAmount;
        records[msg.sender] = record;

        var lrcAmount = ethAmount.mul(RATE);

        lrcWithdrawn += lrcAmount;
        ethReceived += ethAmount;

        require(owner.send(msg.value));
        require(Token(lrcTokenAddress).transfer(msg.sender, lrcAmount));

        uint ethToReturn = msg.value - ethAmount;
        if (ethToReturn > 0) {
            require(msg.sender.send(ethToReturn));
        }

        Withdrawal(
             withdrawIndex++,
             msg.sender,
             ethAmount,
             lrcAmount
        ); 
    }
}

