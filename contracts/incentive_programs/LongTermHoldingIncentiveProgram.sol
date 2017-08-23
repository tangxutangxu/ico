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

/// @title Long-Team Holding Incentive Program
/// @author Daniel Wang - <daniel@loopring.org>, Kongliang Zhong - <kongliang@loopring.org>.
contract LongTermHoldingIncentiveProgram {
    using SafeMath for uint;
    
    address public constant LRC  = 0xEF68e7C694F40c8202821eDF525dE3782458639f;
    address public constant OWNER = 0x0;   // TODO: TBD

    // During the first 90 days of deployment, this contract opens for deposit of LRC
    // in exchange of ETH.
    uint public constant DEPOSIT_PERIOD           = 60 days;

    // For each address, its LRC can only be withdrawn between 180 and 270 days after LRC deposit,
    // which means:
    //    1) LRC are locked during the first 180 days,
    //    2) LRC will be sold to the `OWNER` with the specified `RATE` 270 days after the deposit.
    uint public constant LOCKDOWN_PERIOD     = 360 days;
    uint public constant WITHDRAWAL_PERIOD   = 180 days;

    // Some stats
    uint public lrcDeposited        = 0;
    uint public lrcWithdrawn        = 0;

    uint public depositStartTime    = 0;
    uint public depositStopTime     = 0;

    uint public depositIndex        = 0;
    uint public withdrawIndex       = 0;

    struct Record {
        uint lrcAmount;
        uint timestamp;
    }

    mapping (address => Record) records;
    
    /* 
     * EVENTS
     */

    /// Emitted for each sucuessful deposit.
    event LrcDeposit(uint issueIndex, address addr, uint lrcAmount);

    /// Emitted for each sucuessful deposit.
    event LrcWithdrawal(uint issueIndex, address addr, uint lrcAmount);

    /**
     * CONSTRUCTOR 
     * 
     * @dev Initialize the contract
     * Deposit period start right after this contract is deployed.
     */
    function LongTermHoldingIncentiveProgram() {
        depositStartTime = now;
        depositStopTime = depositStartTime + DEPOSIT_PERIOD;
    }

    /*
     * PUBLIC FUNCTIONS
     */

    /// @dev This default function allows simple usage.
    function () payable {
        require(msg.sender != OWNER);

        if (now <= depositStopTime) {
            depositLRC();
        } else if (now > depositStopTime){
            withdrawLRC();
        }
    }

    /// @dev Deposit LRC for ETH.
    function depositLRC() payable {
        require(msg.sender != OWNER);
        require(msg.value == 0);
        require(now <= depositStopTime);

        var lrcToken = Token(LRC);
        uint lrcAmount = lrcToken
            .allowance(msg.sender, address(this))
            .min256(lrcToken.balanceOf(msg.sender));

        require(lrcAmount >= 50000 ether);

        var record = records[msg.sender];
        record.lrcAmount += lrcAmount;
        record.timestamp = record.timestamp.max256(now);
        records[msg.sender] = record;

        lrcDeposited += lrcAmount;

        require(lrcToken.transferFrom(msg.sender, OWNER, lrcAmount));

        LrcDeposit(depositIndex++, msg.sender, lrcAmount);
    }

    /// @dev Withdrawal LRC with ETH transfer.
    function withdrawLRC() payable {
        require(msg.sender != OWNER);
        require(msg.value == 0);
        require(now > depositStopTime);

        var record = records[msg.sender];
        require(now >= record.timestamp + MIN_WITHDRAWAL_DELAY);
        require(now <= record.timestamp + MAX_WITHDRAWAL_DELAY);


        var lrcToken = Token(LRC);
        uint lrcTotal = lrcToken
            .allowance(OWNER, address(this))
            .min256(lrcTotal.balanceOf(OWNER));

        require(lrcTotal > 0);
        require(lrcDeposited > 0);
        require(record.ethAmount > 0);

        uint lrcAmount = lrcTotal.div(lrcDeposited).mul(record.ethAmount);

        record.ethAmount = 0;
        records[msg.sender] = record;

        lrcWithdrawn += lrcAmount;

        if (lrcAmount > 0)
          require(Token(LRC).transferFrom(OWNER, msg.sender, lrcAmount));
        }

        LrcWithdrawal(withdrawIndex++, msg.sender, lrcAmount);
    }
}

