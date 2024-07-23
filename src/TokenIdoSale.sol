// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*

题目#1
编写 IDO 合约，实现 Token 预售，需要实现如下功能：

开启预售: 支持对给定的任意ERC20开启预售，设定预售价格，募集ETH目标，超募上限，预售时长。
任意用户可支付ETH参与预售；
预售结束后，如果没有达到募集目标，则用户可领会退款；
预售成功，用户可领取 Token，且项目方可提现募集的ETH；
提交要求

编写 IDO 合约 和对应的测试合约
截图 foundry test 测试执行结果
提供 github IDO合约源码链接

*/

contract TokenIdoSale {
    IERC20 token;

    bool public isTotalSet = false;
    uint public totalContribution; //
    uint public immutable MAX_ETH_RAISE = 200 ether; // 200 ETH
    uint public immutable MINMUM_ETH_RAISE = 100 ether; // 100 ETH
    uint public immutable TOTAL_TOKEN_SALE = 1_000_000 * 1E18; // 1_000_000
    uint public immutable MINMUM_ETH_PER_USER = 0.001 ether; // 0.001 ETH
    uint public immutable MAX_ETH_PER_USER = 5 ether; // 10 ETH
    uint public immutable IDO_START_TIME; //
    uint public immutable IDO_END_TIME; //
    address public immutable TOKEN_CONTRACT;
    address public immutable PROJECT_OWNER;

    event UserDeposit(address indexed user, uint amount);
    event ProjectOwnerWithdraw(address indexed user, uint amount);
    event ClaimToken(address indexed user, uint amount);
    event URefund(address indexed user, uint amount);

    error NotValidIdoTime();
    error LessThanMinEthPerUser();
    error MoreThanMaxEthPerUser();
    error ReachHardCap();

    mapping(address => uint) public userEthAmount;

    constructor(
        address _tokenContract,
        address _projectOwner,
        uint _idoStartTime,
        uint _idoEndTime
    ) {
        TOKEN_CONTRACT = _tokenContract;
        PROJECT_OWNER = _projectOwner;
        IDO_START_TIME = _idoStartTime;
        IDO_END_TIME = _idoEndTime;
        token = IERC20(_tokenContract);
    }

    function preSale() public payable {
        if (address(this).balance >= MAX_ETH_RAISE) {
            revert ReachHardCap();
        }

        if (
            block.timestamp < IDO_START_TIME || block.timestamp > IDO_END_TIME
        ) {
            revert NotValidIdoTime();
        }

        if (msg.value < MINMUM_ETH_PER_USER) {
            revert LessThanMinEthPerUser();
        }
        userEthAmount[msg.sender] += msg.value;

        if (userEthAmount[msg.sender] > MAX_ETH_PER_USER) {
            revert MoreThanMaxEthPerUser();
        }

        emit UserDeposit(msg.sender, msg.value);
    }

    function withdraw() public {
        require(isTotalSet, "Price not set");
        require(_idoMeetedMinmumEthRaise(), "IDO not met minmum eth raise");
        require(block.timestamp > IDO_END_TIME, "IDO not ended");
        (bool success, ) = payable(PROJECT_OWNER).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed");
        emit ProjectOwnerWithdraw(PROJECT_OWNER, address(this).balance);
    }
    function claimToken() public {
        require(_idoMeetedMinmumEthRaise(), "IDO not met minimum eth raise");
        require(block.timestamp > IDO_END_TIME, "IDO not ended");
        require(userEthAmount[msg.sender] > 0, "Not a valid user");

        uint256 userContribution = userEthAmount[msg.sender];
        uint256 userShare = (userContribution * TOTAL_TOKEN_SALE) /
            totalContribution;

        userEthAmount[msg.sender] = 0;

        // 使用 call 来转移代币
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                msg.sender,
                userShare
            )
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Token transfer failed"
        );

        emit ClaimToken(msg.sender, userShare);
    }
    function refundEth() public {
        require(block.timestamp > IDO_END_TIME, "IDO not ended");
        require(
            address(this).balance < MINMUM_ETH_RAISE,
            "IDO met minmum eth raise"
        );
        uint amount = userEthAmount[msg.sender];
        userEthAmount[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function _idoMeetedMinmumEthRaise() private view returns (bool) {
        return address(this).balance >= MINMUM_ETH_RAISE;
    }

    function calTotalContribution() public {
        require(!isTotalSet, "Total already set");
        require(_idoMeetedMinmumEthRaise(), "IDO not met minmum eth raise");
        require(
            IERC20(TOKEN_CONTRACT).balanceOf(address(this)) == TOTAL_TOKEN_SALE,
            "Not enough erc token in contract"
        );
        if (block.timestamp < IDO_END_TIME) {
            revert NotValidIdoTime();
        }
        totalContribution = address(this).balance;

        isTotalSet = true;
    }
}
