// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenStakePool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000_000 * 10 ** 18);
    }
}

contract TokenStakePoolTest is Test {
    TokenStakePool public stakePool;
    MockERC20 public token;
    EsToken public esToken;
    address public alice = address(1);
    address public bob = address(2);

    uint256 constant DECIMALS = 10 ** 18;
    uint256 constant INITIAL_BALANCE = 10000 * DECIMALS;
    uint256 constant REWARD_TOTAL = 1_000_000 * DECIMALS;
    uint256 constant ONE_DAY = 1 days;

    event UserStake(address indexed user, uint amount);
    event UserUnstake(address indexed user, uint amount);
    event UserClaim(address indexed user, uint amount);

    function setUp() public {
        token = new MockERC20("Test Token", "TT");
        stakePool = new TokenStakePool(address(token));
        esToken = EsToken(stakePool.esToken());

        token.approve(address(stakePool), REWARD_TOTAL);
        vm.prank(address(this));
        token.transfer(address(stakePool), REWARD_TOTAL);

        token.transfer(alice, INITIAL_BALANCE);
        token.transfer(bob, INITIAL_BALANCE);

        vm.prank(address(stakePool));
        token.approve(address(esToken), REWARD_TOTAL);

        assertEq(token.balanceOf(address(stakePool)), REWARD_TOTAL, "StakePool should have correct token balance");
        assertEq(token.allowance(address(stakePool), address(esToken)), REWARD_TOTAL, "EsToken should have correct allowance");
    }

    function testStake() public {
        uint256 stakeAmount = 1000 * DECIMALS;
        vm.startPrank(alice);
        token.approve(address(stakePool), stakeAmount);
        
        vm.expectEmit(true, false, false, true);
        emit UserStake(alice, stakeAmount);
        stakePool.stake(stakeAmount);
        
        vm.stopPrank();

        (uint256 stake, , ) = stakePool.userStakeInfo(alice);
        assertEq(stake, stakeAmount, "Stake amount should match");
    }

    function testUnstake() public {
        uint256 stakeAmount = 1000 * DECIMALS;
        vm.startPrank(alice);
        token.approve(address(stakePool), stakeAmount);
        stakePool.stake(stakeAmount);

        vm.warp(block.timestamp + ONE_DAY);

        uint256 unstakeAmount = 500 * DECIMALS;
        
        vm.expectEmit(true, false, false, true);
        emit UserUnstake(alice, unstakeAmount);
        stakePool.unstake(unstakeAmount);
        
        vm.stopPrank();

        (uint256 stake, , ) = stakePool.userStakeInfo(alice);
        assertEq(stake, stakeAmount - unstakeAmount, "Remaining stake should match");
    }

    function testClaim() public {
        uint256 stakeAmount = 2 * DECIMALS;

        vm.startPrank(alice);
        token.approve(address(stakePool), stakeAmount);
        stakePool.stake(stakeAmount);

        vm.warp(block.timestamp + 36 hours);

        uint256 expectedReward = stakePool.calculateReward(alice);
        
        vm.expectEmit(true, false, false, true);
        emit UserClaim(alice, expectedReward);
        stakePool.claim();
        
        vm.stopPrank();

        assertEq(esToken.balanceOf(alice), expectedReward, "Claimed reward should match");
    }

    function testBurnEsTokenExchangeToken() public {
        uint256 stakeAmount = 1000 * DECIMALS;

        vm.startPrank(alice);
        token.approve(address(stakePool), stakeAmount);
        stakePool.stake(stakeAmount);

        vm.warp(block.timestamp + ONE_DAY);
        stakePool.claim();

        uint256 esTokenBalance = esToken.balanceOf(alice);
        assertEq(esTokenBalance, stakeAmount, "Alice should have received 1000 esTokens when staking 1000 tokens for 1 day");

        vm.warp(block.timestamp + ONE_DAY);
        uint256 initialTokenBalance = token.balanceOf(alice);
        esToken.burnEsTokenExchangeToken(0);
        uint256 tokenAfterBurn = token.balanceOf(alice);
        uint256 expectedReward = (esTokenBalance * ONE_DAY) / 30 days;
        assertApproxEqRel(tokenAfterBurn - initialTokenBalance, expectedReward, 1e16, "Should receive about 1/30 of tokens");

        uint256 secondStakeAmount = 1000 * DECIMALS;
        stakePool.unstake(stakeAmount);
        token.approve(address(stakePool), secondStakeAmount);
        stakePool.stake(secondStakeAmount);
        vm.warp(block.timestamp + ONE_DAY);
        stakePool.claim();

        vm.warp(block.timestamp + 30 days);

        initialTokenBalance = token.balanceOf(alice);
        esToken.burnEsTokenExchangeToken(1);
        tokenAfterBurn = token.balanceOf(alice);
        assertEq(tokenAfterBurn - initialTokenBalance, stakeAmount, "Should receive full amount of tokens after 30 days");

        vm.stopPrank();
    }

    function testStakeZeroAmount() public {
        vm.startPrank(alice);
        vm.expectRevert("stake amount should be greater than 0");
        stakePool.stake(0);
        vm.stopPrank();
    }

    function testUnstakeMoreThanStaked() public {
        uint256 stakeAmount = 1000 * DECIMALS;
        vm.startPrank(alice);
        token.approve(address(stakePool), stakeAmount);
        stakePool.stake(stakeAmount);

        vm.expectRevert("insufficient stake");
        stakePool.unstake(stakeAmount + 1);
        vm.stopPrank();
    }

    function testClaimWithNoReward() public {
        vm.startPrank(alice);
        vm.expectRevert("no reward to claim");
        stakePool.claim();
        vm.stopPrank();
    }
}