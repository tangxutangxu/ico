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
contract LRCLongTermHoldingContract {
    using SafeMath for uint;
    
    // During the first 90 days of deployment, this contract opens for deposit of LRC.
    uint public constant DEPOSIT_PERIOD             = 60 days; // = 2 months

    // 18 months after deposit, user can withdrawal all its LRC with bonus.
    // The bonus is this contract's last LRC balance, which can only increase, but not decrease.
    uint public constant LOCKDOWN_PERIOD            = 540 days; // = 1 year and 6 months
    
    // 0.01 ETH will authorize deposity of 10000LRC, so if you want to deposit `x` LRC,
    // send `x / 1000,000` ETH to this contract.
    uint public constant FEE_FACTOR = 1000000;

    address public lrcTokenAddress  = 0x0;
    address public owner            = 0x0;

    uint public lrcDeposited        = 0;

    uint public depositStartTime    = 0;
    uint public depositStopTime     = 0;

    struct Record {
        uint lrcAmount;
        uint timestamp;
    }

    mapping (address => Record) records;
    
    /* 
     * EVENTS
     */

    /// Emitted for each sucuessful deposit.
    uint public depositId = 0;
    event Deposit(uint _depositId, address _addr, uint _lrcAmount);

    /// Emitted for each sucuessful deposit.
    uint public withdrawId = 0;
    event Withdrawal(uint _withdrawId, address _addr, uint _lrcAmount);

    /// @dev Initialize the contract
    /// @param _lrcTokenAddress LRC ERC20 token address
    /// @param _owner Owner of this contract
    function LRCLongTermHoldingContract(address _lrcTokenAddress, address _owner) {
        require(_lrcTokenAddress != 0x0);
        require(_owner != 0x0);

        lrcTokenAddress = _lrcTokenAddress;
        owner = _owner;
        
        depositStartTime = now;
        depositStopTime = depositStartTime + DEPOSIT_PERIOD;
    }

    /*
     * PUBLIC FUNCTIONS
     */

    function () payable {
        require(msg.sender != owner);
        if (now <= depositStopTime) {
            depositLRC();
        } else if (now > depositStopTime){
            withdrawLRC();
        }
    }

    function drain() public payable {
        require(msg.sender == owner);
        require(this.balance > 0);
        require(owner.send(this.balance));
    }

    /// @dev Deposit LRC for ETH.
    function depositLRC() payable {
        require(msg.sender != owner);
        require(msg.value > 0);
        require(now <= depositStopTime);
        
        var lrcToken = Token(lrcTokenAddress);
        uint lrcAmount = msg.value.mul(FEE_FACTOR)
            .min256(lrcToken.balanceOf(msg.sender))
            .min256(lrcToken.allowance(msg.sender, address(this)));

        var record = records[msg.sender];
        record.lrcAmount += lrcAmount;
        record.timestamp = now;
        records[msg.sender] = record;

        lrcDeposited += lrcAmount;

        require(lrcToken.transferFrom(msg.sender, address(this), lrcAmount));
        Deposit(depositId++, msg.sender, lrcAmount);
    }

    /// @dev Withdrawal all LRC.
    function withdrawLRC() payable {
        require(msg.sender != owner);
        require(lrcDeposited > 0);

        var record = records[msg.sender];
        require(record.lrcAmount > 0);
        require(now >= record.timestamp + LOCKDOWN_PERIOD);

        var lrcToken = Token(lrcTokenAddress);
        uint lrcAmount = lrcToken
            .balanceOf(address(this))
            .div(lrcDeposited)
            .mul(record.lrcAmount);

        require(lrcAmount > 0);

        delete records[msg.sender];
        lrcDeposited -= lrcAmount;

        require(lrcToken.transfer(msg.sender, lrcAmount));

        Withdrawal(withdrawId++, msg.sender, lrcAmount);
    }
}


