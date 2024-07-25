//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./esToken.sol";
/*
编写一个质押挖矿合约，实现如下功能：

用户随时可以质押项目方代币 RNT(自定义的ERC20) ，开始赚取项目方Token(esRNT)；
可随时解押提取已质押的 RNT；
可随时领取esRNT奖励，每质押1个RNT每天可奖励 1 esRNT;
esRNT 是锁仓性的 RNT， 1 esRNT 在 30 天后可兑换 1 RNT，随时间线性释放，支持提前将 esRNT 兑换成 RNT，但锁定部分将被 burn 燃烧掉。

*/

contract TokenStakePool {
    IERC20 public token;
    EsToken public esToken;
    mapping(address => StakeInfo) public userStakeInfo;

    struct StakeInfo {
        uint stake;
        uint unclaimdReward;
        uint lastUpdateTime;
    }

    address public immutable tokenContract;

    uint public immutable REWARD_PER_DAY = 1;
    uint public immutable REWARD_TOTAL = 1_000_000 * 1E18;

    event UserStake(address indexed user, uint amount);
    event UserUnstake(address indexed user, uint amount);
    event UserClaim(address indexed user, uint amount);

    constructor(address _tokenContract) {
        tokenContract = _tokenContract;
        esToken = new EsToken("esToken", "esToken", _tokenContract);
        token = IERC20(_tokenContract);
    }

    function getStakeInfo(address user) public view returns (StakeInfo memory) {
        return userStakeInfo[user];
    }
    function stake(uint stakeAmount) public {
        require(stakeAmount > 0, "stake amount should be greater than 0");
        require(
            token.balanceOf(msg.sender) >= stakeAmount,
            "insufficient balance"
        );
        token.transferFrom(msg.sender, address(this), stakeAmount);

        if (userStakeInfo[msg.sender].stake > 0) {

            userStakeInfo[msg.sender].unclaimdReward = calculateReward(msg.sender);

        } else {
            userStakeInfo[msg.sender].unclaimdReward = 0;
        }

        userStakeInfo[msg.sender].stake += stakeAmount;
        userStakeInfo[msg.sender].lastUpdateTime = block.timestamp;
        emit UserStake(msg.sender, stakeAmount);
    }
    function unstake(uint unstakeAmount) public {
        require(
            userStakeInfo[msg.sender].stake >= unstakeAmount,
            "insufficient stake"
        );

        uint reward = calculateReward(msg.sender);
        token.transfer(msg.sender, unstakeAmount);
        userStakeInfo[msg.sender].stake =
            userStakeInfo[msg.sender].stake -
            unstakeAmount;
        userStakeInfo[msg.sender].lastUpdateTime = block.timestamp;
        userStakeInfo[msg.sender].unclaimdReward += reward;
        emit UserUnstake(msg.sender, unstakeAmount);
    }
    function claim() public {
        require(
            userStakeInfo[msg.sender].unclaimdReward > 0 ||
                userStakeInfo[msg.sender].stake > 0,
            "no reward to claim"
        );
        uint reward = calculateReward(msg.sender);
        esToken.mintEsToken(msg.sender, reward); //
        userStakeInfo[msg.sender].unclaimdReward = 0;
        userStakeInfo[msg.sender].lastUpdateTime = block.timestamp;
        emit UserClaim(msg.sender, reward);
    }

    function calculateReward(address user) public view returns (uint) {
        if (userStakeInfo[user].stake == 0) {
            return 0;
        }
        return
            userStakeInfo[user].unclaimdReward +
            ((block.timestamp - userStakeInfo[user].lastUpdateTime) *
                userStakeInfo[user].stake *
                REWARD_PER_DAY) /
            86400;
    }
}
