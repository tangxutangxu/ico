/*

  Copyright 2017 Loopring Foundation.

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

import "./StandardToken.sol";


/// @title Mid-Team Holding Incentive Program
/// @author Daniel Wang - <daniel@loopring.org>, Kongliang Zhong - <kongliang@loopring.org>.
contract MidTeamHoldingIncentiveProgram {
    string public constant LRC  = "0xEF68e7C694F40c8202821eDF525dE3782458639f";
    string public constant OWNER  = "0xEF68e7C694F40c8202821eDF525dE3782458639f";

    uint public const LENDING_PERIOD   = 90 days;
    uint public const MIN_PAYBACK_DELAY   = 180 days;
    uint public const MAX_PAYBACK_DELAY   = 270 days;
    uint public const PRICE = 7500;
    
    uint public lrcReceived = 0;
    uint public ethLent = 0;

    uint public lendingStartTimestamp = 0;
    uint public lendingStopTimestamp = 0;


    /// Event index starting from 0.
    uint public eventIndex = 0;
    bool public closed = false;

    struct Record {
        uint ethAmount;
        uint timestamp;
    }

    mapping (address => LendingRecord) records;
    
    /* 
     * EVENTS
     */


    /// Emitted only once after token sale ended (all token issued).
    event LendingEnded();

    /// Emitted when a function is invocated by unauthorized addresses.
    event InvalidCaller(address caller);

    /// Emitted when a function is invocated without the specified preconditions.
    /// This event will not come alone with an exception.
    event InvalidState(bytes msg);

    /// Emitted for each sucuessful token purchase.
    event Lending(uint issueIndex, address addr, uint ethAmount, uint tokenAmount);

    /// Emitted if the token sale succeeded.
    event SaleSucceeded();

    /// Emitted if the token sale failed.
    /// When token sale failed, all Ether will be return to the original purchasing
    /// address with a minor deduction of transaction fee（gas)
    event SaleFailed();

    event Closed(uint ethAmount, uint lrcAmount);

    /*
     * MODIFIERS
     */

    modifier isOwner {
        if (OWNER != msg.sender) throw;
    }

    modifier isLendable {
        if (now > lendingStopTimestamp) throw;
    }

    modifier isClosable {
       if (closed || now <= lendingStopTimestamp + MAX_PAYBACK_DELAY) throw;
    }

    /**
     * CONSTRUCTOR 
     * 
     * @dev Initialize the Loopring Token
     * @param _target The escrow account address, all ethers will
     * be sent to this address.
     * This address will be : 0x00073F7155459C9205010Cb3453a0f392a0C3210
     */
    function LoopringToken() {
        lendingStartTimestamp = now;
        lendingStopTimestamp = lendingStartTimestamp + LENDING_PERIOD;
    }

    /*
     * PUBLIC FUNCTIONS
     */


    /// @dev Triggers unsold tokens to be issued to `target` address.
    function close() public isOwner isClosable{
        var ethAmount = this.balance;
        if (!OWNER.send(this.balance)) throw;

        var lrc = Token(LRC);
        var lrcAmount = lrc.balanceOf(address(this));
        lrc.transfer(lrcAmount, OWNER);
        closed = true;
        Closed(ethAmount, lrcAmount);
    }

    /// @dev This default function allows token to be purchased by directly
    /// sending ether to this smart contract.
    function () payable {
        if (msg.sender == OWNER) {
           require(!closed);
        } else if (now <= lendingStopTimestamp) {
            lrcToEth(msg.sender);
        } else if (now <= lendingStopTimestamp){
            ethToLrc(msg.sender);
        }
    }

    /// @dev Issue token based on Ether received.
    /// @param recipient Address that newly issued token will be sent to.
    function lrcToEth(address recipient) payable isLendable {
        require(msg.value == 0);

        var lrc = Token(LRC);
        var lrcAmount = Token(LRC).allowance(address(this));
        var ethAmount = min(lrcAmount / PRICE, this.balance);
        lrcAmount = min(lrcAmount, ethAmount * PRICE)

        var record = records[recipient];
        record.ethAmount += ethAmount
        record.timestamp = now;
        records[recipient] = record;

        if (!recipient.send(ethAmount)) {
            throw;
        }

        Token(LRC).transferTo(address(this), lrcAmount)

        Lending(
             issueIndex++,
             recipient,
             -ethAmount,
             lrcAmount
        );      
    }

        /// @dev Issue token based on Ether received.
    /// @param recipient Address that newly issued token will be sent to.
    function ethToLrc(address recipient) payable {
        var record = records[recipient]
        require(
            msg.value >= 0.01 ether &&
            msg.value <= record.ethAmount &&
            now >= record.timestamp + MIN_PAYBACK_DELAY &&
            now <= record.timestamp + MAX_PAYBACK_DELAY);

        record.ethAmount -= msg.value;
        records[recipient] = record;

        var lrcAmount = msg.value * PRICE;

        Token(LRC).transfer(recipient, lrcAmount);

        Lending(
             issueIndex++,
             recipient,
             ethAmount,
             -lrcAmount
        ); 
    }
}

