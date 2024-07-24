// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenIdoSale.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(uint256 initialSupply) ERC20("MockToken", "MTK") {
        _mint(msg.sender, initialSupply);
    }
}

contract TokenIdoSaleTest is Test {
    TokenIdoSale public idoSale;
    MockERC20 public token;
    address public projectOwner;
    address public user1;
    address public user2;

    uint256 public constant TOTAL_TOKEN_SALE = 1_000_000 * 1e18;
    uint256 public constant IDO_DURATION = 7 days;

    function setUp() public {
        projectOwner = address(1);
        user1 = address(2);
        user2 = address(3);

        vm.warp(block.timestamp);
        uint256 startTime = block.timestamp + 1 hours;
        uint256 endTime = startTime + IDO_DURATION;

        // 创建代币合约，并铸造足够的代币
        token = new MockERC20(TOTAL_TOKEN_SALE);

        // 创建 IDO 合约
        idoSale = new TokenIdoSale(
            address(token),
            projectOwner,
            startTime,
            endTime
        );

        // 将代币转移到 IDO 合约
        vm.prank(address(this));
        token.transfer(address(idoSale), TOTAL_TOKEN_SALE);

        // 验证 IDO 合约已经收到了正确数量的代币
        assertEq(token.balanceOf(address(idoSale)), TOTAL_TOKEN_SALE);
    }

    function testPreSale() public {
        vm.warp(idoSale.IDO_START_TIME() + 1 hours);

        vm.deal(user1, 10 ether);
        vm.prank(user1);
        idoSale.preSale{value: 1 ether}();

        assertEq(address(idoSale).balance, 1 ether);
        assertEq(idoSale.userEthAmount(user1), 1 ether);
    }

    function testPreSaleFailBeforeStart() public {
        vm.expectRevert(TokenIdoSale.NotValidIdoTime.selector);
        idoSale.preSale{value: 1 ether}();
    }

    function testPreSaleFailAfterEnd() public {
        vm.warp(idoSale.IDO_END_TIME() + 1);
        vm.expectRevert(TokenIdoSale.NotValidIdoTime.selector);
        idoSale.preSale{value: 1 ether}();
    }

    function testPreSaleFailLessThanMinimum() public {
        vm.warp(idoSale.IDO_START_TIME() + 1 hours);
        vm.expectRevert(TokenIdoSale.LessThanMinEthPerUser.selector);
        idoSale.preSale{value: 0.0009 ether}();
    }

    function testPreSaleFailMoreThanMaximum() public {
        vm.warp(idoSale.IDO_START_TIME() + 1 hours);
        vm.deal(user1, 11 ether);
        vm.startPrank(user1);
        idoSale.preSale{value: 5 ether}();
        vm.expectRevert(TokenIdoSale.MoreThanMaxEthPerUser.selector);
        idoSale.preSale{value: 0.1 ether}();
        vm.stopPrank();
    }

    function testWithdrawSuccess() public {
        // 设置 IDO 开始时间
        vm.warp(idoSale.IDO_START_TIME() + 1 hours);

        // 创建足够多的用户来达到最小募集额
        address[] memory users = new address[](20);
        for (uint i = 0; i < 20; i++) {
            users[i] = address(uint160(i + 1000));
            vm.deal(users[i], 5 ether);
            vm.prank(users[i]);
            idoSale.preSale{value: 5 ether}();
        }

        // 确保总募集额达到100 ether
        assertEq(address(idoSale).balance, 100 ether);

        // 移动时间到 IDO 结束后
        vm.warp(idoSale.IDO_END_TIME() + 1);

        // 项目所有者设置代币价格
        vm.prank(projectOwner);
        idoSale.calTotalContribution();

        // 记录项目所有者的初始余额
        uint256 balanceBefore = projectOwner.balance;

        // 项目所有者提取资金
        vm.prank(projectOwner);
        idoSale.withdraw();

        // 验证项目所有者收到了正确的金额
        assertEq(
            projectOwner.balance - balanceBefore,
            100 ether,
            "Withdrawal amount incorrect"
        );
    }

    function testClaimTokenSuccess() public {
        // 设置 IDO 开始时间
        vm.warp(idoSale.IDO_START_TIME() + 1 hours);

        uint userNum = 20;
        uint userPerEth =  5 ether;

        // 创建足够多的用户来达到最小募集额
        address[] memory users = new address[](userNum);
        for (uint i = 0; i < userNum; i++) {
            users[i] = address(uint160(i + 1000));
            vm.deal(users[i], userPerEth);
            vm.prank(users[i]);
            idoSale.preSale{value: userPerEth}();
        }

        // 确保总募集额达到100 ether
        assertEq(address(idoSale).balance, userNum * userPerEth);

        // 移动时间到 IDO 结束后
        vm.warp(idoSale.IDO_END_TIME() + 1);

        // 项目所有者设置代币价格
        vm.prank(projectOwner);
        idoSale.calTotalContribution();

        // 记录第一个用户的初始代币余额
        uint256 balanceBefore = token.balanceOf(users[0]);

        // console.log("token_price: ", idoSale._token_price());
        // console.log("token_price: ", idoSale._token_price());

        // 第一个用户认领代币
        vm.prank(users[0]);
        idoSale.claimToken();

        // 断言用户的代币余额增加
        assertGt(token.balanceOf(users[0]), balanceBefore);

        // 计算并验证用户应该收到的确切代币数量
        uint256 expectedTokens = (userPerEth) * TOTAL_TOKEN_SALE / idoSale.totalContribution() ;
        console.log("expectedTokens: ", expectedTokens);
        console.log("totalContribution: ", idoSale.totalContribution());
        assertEq(token.balanceOf(users[0]) - balanceBefore, expectedTokens);
    }

    function testRefundEthSuccess() public {
        vm.warp(idoSale.IDO_START_TIME() + 1 hours);
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        idoSale.preSale{value: 1 ether}();

        vm.warp(idoSale.IDO_END_TIME() + 1);

        uint256 balanceBefore = user1.balance;
        vm.prank(user1);
        idoSale.refundEth();

        assertEq(user1.balance - balanceBefore, 1 ether);
    }
}
