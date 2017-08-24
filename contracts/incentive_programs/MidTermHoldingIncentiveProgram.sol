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
contract MidTermHoldingIncentiveProgram {
    using SafeMath for uint;

    // During the first 90 days of deployment, this contract opens for deposit of LRC
    // in exchange of ETH.
    uint public constant DEPOSIT_PERIOD           = 90 days;

    // For each address, its LRC can only be withdrawn between 180 and 270 days after LRC deposit,
    // which means:
    //    1) LRC are locked during the first 180 days,
    //    2) LRC will be sold to the `owner` with the specified `RATE` 270 days after the deposit.
    uint public constant MIN_WITHDRAWAL_DELAY     = 180 days;
    uint public constant MAX_WITHDRAWAL_DELAY     = 270 days;

    uint public constant MAX_LRC_DEPOSIT     = 150000 ether; // = 20 ETH

    // 7500 LRC for 1 ETH. This rate is the best token sale rate ever.
    uint public constant RATE = 7500; 

    address public lrcAddress  = 0x0;
    address public owner = 0x0;

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
    event MDeposit(uint issueIndex, address addr, uint ethAmount, uint lrcAmount);

    /// Emitted for each sucuessful deposit.
    event MWithdrawal(uint issueIndex, address addr, uint ethAmount, uint lrcAmount);

    /// When this contract is closed.
    event MClosed(uint ethAmount, uint lrcAmount);

    /// Emitted when some ETH are drained.
    event MDrained(uint ethAmount);

    /**
     * CONSTRUCTOR 
     * 
     * @dev Initialize the contract
     * Deposit period start right after this contract is deployed.
     */
    function MidTermHoldingIncentiveProgram(address _lrcAddress, address _owner) {
        require(_lrcAddress != 0x0);
        require(_owner != 0x0);

        lrcAddress = _lrcAddress;
        owner = _owner;

        depositStartTime = now;
        depositStopTime = depositStartTime + DEPOSIT_PERIOD;
    }

    /*
     * PUBLIC FUNCTIONS
     */

    /// @dev Get back ETH to `owner`.
    function drain(uint ethAmount) payable {
        require(ethAmount > 0);
        require(msg.sender == owner);

        uint amount = ethAmount.min256(this.balance);

        require(owner.send(amount));
        MDrained(amount);
    }

    /// @dev Get all ETH and LRC back to `owner`.
    function close() payable {
        require(!closed);
        require(msg.sender == owner);
        require(now > depositStopTime + MAX_WITHDRAWAL_DELAY); 

        var ethAmount = this.balance;
        if (ethAmount > 0) {
          require(owner.send(ethAmount));
        }

        var lrcToken = Token(lrcAddress);
        var lrcAmount = lrcToken.balanceOf(address(this));
        if (lrcAmount > 0) {
          require(lrcToken.transfer(owner, lrcAmount));
        }

        closed = true;
        MClosed(ethAmount, lrcAmount);
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
    function depositLRC() payable {
        require(!closed && msg.sender != owner);
        require(msg.value == 0);
        require(now <= depositStopTime);

        uint lrcAmount = bytesToUint(msg.data).mul(1E18);
        
        var lrcToken = Token(lrcAddress);
        lrcAmount = lrcToken.balanceOf(msg.sender).min256(lrcAmount);

        uint ethAmount = lrcAmount.div(RATE).min256(this.balance);
        lrcAmount = ethAmount.mul(RATE);

        require(ethAmount > 0 && lrcAmount > 0 && lrcAmount <= MAX_LRC_DEPOSIT);

        var record = records[msg.sender];
        record.ethAmount += ethAmount;
        record.timestamp = now;
        records[msg.sender] = record;

        lrcDeposited += lrcAmount;
        ethSent += ethAmount;

        require(msg.sender.send(ethAmount));
        require(lrcToken.transfer(address(this), lrcAmount));

        MDeposit(
             depositIndex++,
             msg.sender,
             ethAmount,
             lrcAmount
        );      
    }

    /// @dev Withdrawal LRC with ETH transfer.
    function withdrawLRC() payable {
        require(!closed && msg.sender != owner);
        require(msg.value >= 0.01 ether);
        require(now > depositStopTime);

        var record = records[msg.sender];
        require(msg.value <= record.ethAmount);
        require(now >= record.timestamp + MIN_WITHDRAWAL_DELAY);
        require(now <= record.timestamp + MAX_WITHDRAWAL_DELAY);

        record.ethAmount -= msg.value;
        records[msg.sender] = record;

        var lrcAmount = msg.value.mul(RATE);

        lrcWithdrawn += lrcAmount;
        ethReceived += msg.value;

        require(owner.send(msg.value));
        require(Token(lrcAddress).transfer(msg.sender, lrcAmount));

        MWithdrawal(
             withdrawIndex++,
             msg.sender,
             msg.value,
             lrcAmount
        ); 
    }


    function bytesToUint(bytes v) constant returns (uint value) {
        uint d;
        for (uint i = 0; i < v.length; i++) {
            d = uint(v[i]);
            require(d >= 48 && d < 57);
            value = value * 10 + d - 48;
        }
        return value;
    }
}

