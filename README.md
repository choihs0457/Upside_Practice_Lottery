# 문제 2: Lottery 컨트랙트 구현하기

> 💡 [GitHub Repository](https://github.com/Upside-Academy/Upside_Practice_Lottery)
> - `Lottery.sol`에 복권 컨트랙트를 구현하세요.
> - Rollover 등 생소할 수 있는 개념은 따로 찾아보시면 구현에 도움이 됩니다.

## 접근

- lottery라는 것을 보고 현실의 복권을 생각하면서 테케를 쭉 읽어봤는데 뭔가 흐름이 잘 그려지지 않아서 순서대로 구현을 하기로 했다. phase가 나눠지길래 require가 많을 것으로 생각돼서 modifier를 사용하기로 생각하고 구상을 시작했다.

## 문제 1

- getNextWinningNumber 함수의 revertTo를 잘 몰랐어서 draw를 할 때 winningNumber에 대한 선언을 뒤로 미웠었다. 처음에 주어진 값(0)을 가지고 정답을 맞춰야 된다고 생각했었다.
찾아보니 뽑힐 랜덤값을 가져와서 비교하기 위한 작업이었다. 아래 사진을 보면 스냅샷 시점으로 상태들을 되돌리는 함수라고 나와있다.

  ![Snapshot 기능 설명 이미지](https://prod-files-secure.s3.us-west-2.amazonaws.com/5b71d765-2c11-4a93-9f32-9955c1498ad7/14f538c5-4dcd-4beb-b4a6-47e0b9a918c6/image.png)

## 문제 2

- 위에서 랜덤값이라고 했지만 사실 유추가 가능한 값을 뱉어야 하기때문에 조금 찜찜한 부분이 있었다. 근데 또 진짜 랜덤에 가까운 값을 넣으면 테케를 통과 할 수 없을 것으로 보인다. 무엇이 정답인지 모르겟으나 일단 테케를 위한 답안을 작성했다.

## 문제 3

- 테케를 위해 코드를 작성하다 보니 조금 의문점이 들었다.(이 부분 때문에 사실 시간을 가장 많이 사용한 것 같다.) 실제 로또라고 생각하면 당첨금 수령 기간이 충분히 주어진다. 하지만 테케를 통과하기 위해선 당첨자의 수를 생각을 하고 클레임 시 당첨자가 0명이면 Sell Phase로 넘겨줘야 한다. 이 부분에서 충돌이 있어서 롤업 과 스플릿이 공존 할 수 없다는 생각에 사로잡혀 오랜 시간 고민을 했다.(구조체로 모든 사람들의 상태를 고려해서 따로 관리해야되나 등 많은 생각을 했다.)

## 후기

- 이 문제는 많은 생각을 하게 만들었으며, Solidity의 깊이 있는 이해가 필요하다고 느꼈습니다. 테스트 케이스를 통과하기 위해 코드를 작성하면서도 실제 상황에서의 로직과 충돌하는 부분들이 있어서 많은 고민을 하게 되었습니다.

##
```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";

contract Lottery {
    enum Phase { Sell, Draw, Claim }

    uint public endTime;                                // Sell Phase의 시간을 조절하기 위한 함수
    uint16 public winningNumber;                        // 로또 당첨번호가 저장 될 변수
    Phase public phase;                                 // 현재 어떤 페이즈 인지 저장 할 변수
    uint winnersCount;                                  // 클레임의 횟수를 확인하기 위한 담청자 수에 대한 변수
    mapping(address => uint) rewardList;                // 로또를 산 사람들 중 당첨된 사람들에게 금액을 배분 해 줄 매핑
    mapping(uint16 => address[]) public ticketHolders;  // 해당 번호의 로또를 산 사람들을 기록 할 매핑

    uint public lotteryPrice = 0.1 ether;               // 로또 금액

    /*
    SellPhase의 시간을 정하기 위해 블록타임을 기준으로 24시간을 설정
    */
    constructor() {
        endTime = block.timestamp + 24 hours;
    }

    /*
    require문이 많이 붙어있는게 별로여서 따로 다 빼둔 modifier
    onlyInTime에서 block.timestamp이 endTime을 넘어버리고 Sell Phase라면 DrawPhase로 넘긴다.
    onlyOnce에서 해다 티켓을 구매한 이력이 있는지 검증함
    나머지는 phase에 대한 검증
    */
    modifier onlyOnce(uint16 ticketNum) {
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

    /*
    modifier로 검증을 하고 금액에 대한 검증을 한 뒤 통과 한다면 해당티켓의 배열에 msg.sender를 추가한다.
    */
    function buy(uint16 ticketNum) external payable onlyInTime onlyOnce(ticketNum) onlySellPhase {
        require(msg.value == lotteryPrice, "Price error");
        ticketHolders[ticketNum].push(msg.sender);
    }

    /*
    winningNumber를 뽑고 당첨자에게 배분을 하기 위해 담청번호를 가지고 있는 
    사람들의 reward에 가지고 있는 금액에서 담청자수를 나눈 값 만큼 배분한다.
    */
    function draw() external onlyInTime onlyDrawPhase {
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

    /*
    당첨자가 있는지 확인을 하고 클레임을 요청한 사람이 당첨자 인 지 확인한다.
    당첨자라면 리워드를 지급하고 당첨자 카운트를 낮춘다.
    당첨자가 없다면 SellPhase로 넘어간다.
    */
    function claim() external onlyClaimPhase {
        if(winnersCount > 0){
            uint reward = rewardList[msg.sender];
            if (reward != 0){
                rewardList[msg.sender] = 0;
                (bool success, ) = address(msg.sender).call{value: reward}("");
                winnersCount -= 1;
                if (winnersCount == 0){
                    endTime = block.timestamp + 24;
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