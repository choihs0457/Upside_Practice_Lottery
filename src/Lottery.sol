// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";

contract Lottery {
    enum Phase { Sell, Draw, Claim }

    uint public endTime;
    uint16 public winningNumber;
    Phase public phase;
    uint winnersCount;
    mapping(address => uint) rewardList;
    mapping(uint16 => address[]) public ticketHolders;

    uint public lotteryPrice = 0.1 ether;

    constructor() {
        endTime = block.timestamp + 24 hours;
        phase = Phase.Sell;
    }

    modifier onlyOnece(uint16 ticketNum) {
        bool alreadyBought = false;
        for (uint i = 0; i < ticketHolders[ticketNum].length; i++) {
            if (ticketHolders[ticketNum][i] == msg.sender) {
                alreadyBought = true;
                break;
            }
        }
        require(!alreadyBought, "Already Bought The Ticket");
        _;
    }

    modifier onlySellPhase() {
        require(phase == Phase.Sell, "Not Sell Phase");
        _;
    }
    
    modifier onlyDrawPhase() {
        require(phase == Phase.Draw, "Not Draw Phase");
        _;
    }

    modifier onlyClaimPhase() {
        require(phase == Phase.Claim, "Not Claim Phase");
        _;
    }
    
    modifier onlyInTime() {
        if (block.timestamp >= endTime) {
            if (phase == Phase.Sell) {
                phase = Phase.Draw;
            }
        }
        _;
    }

    function buy(uint16 ticketNum) external payable onlyInTime() onlyOnece(ticketNum) onlySellPhase {
        require(msg.value == lotteryPrice, "Price error");
        ticketHolders[ticketNum].push(msg.sender);
    }

    function draw() external onlyInTime() onlyDrawPhase() {
        winningNumber = uint16(uint256(keccak256(abi.encodePacked(block.timestamp))) % 65536);
        uint totalWinningAmount = address(this).balance;
        address[] memory winnerList = ticketHolders[winningNumber];
        uint count = winnerList.length;

        if (count > 0) {
            uint reward = totalWinningAmount / count;
            for (uint i = 0; i < count; i++) {
                rewardList[winnerList[i]] = reward;
        }
        winnersCount = count;
    }
        phase = Phase.Claim;
    }

    function claim() external onlyClaimPhase() {
        if(winnersCount > 0){
            uint reward = rewardList[msg.sender];
            if (reward != 0){
                rewardList[msg.sender] = 0;
                (bool success, ) = address(msg.sender).call{value: reward}("");
                winnersCount -= 1;
                if (winnersCount == 0){
                    phase = Phase.Sell;
                }
                require(success, "Transfer failed");
            }
        }else{
            endTime = block.timestamp + 24;
            phase = Phase.Sell;
        }
    }

    receive() external payable {}
}