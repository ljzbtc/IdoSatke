// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EsToken is ERC20, Ownable {
    IERC20 public token;
    address public immutable tokenContract;

    event UserClaimEsToken(address indexed user, uint amount);
    event UserBurnEsToken(address indexed user, uint amount);
    event UserClaimToken(address indexed user, uint amount);

    constructor(
        string memory name,
        string memory symbol,
        address _tokenContract

    ) ERC20(name, symbol) Ownable(msg.sender) {
        tokenContract = _tokenContract;
        token = IERC20(tokenContract);
    }

    struct LockedInfo {
        uint256 amount;
        uint256 lockedTime;
    }

    mapping(address => LockedInfo[]) public userLockedInfo;

    function mintEsToken(address to, uint256 amount) public onlyOwner {
        
        _mint(to, amount);
        token.transferFrom(msg.sender, address(this), amount);  
        LockedInfo memory lockedInfo = LockedInfo(amount, block.timestamp);
        userLockedInfo[to].push(lockedInfo);
        emit UserClaimEsToken(to, amount);
    }

    function burnEsTokenExchangeToken(uint unlockId) public {
        require(unlockId < userLockedInfo[msg.sender].length, "invalid unlockId");
        require(userLockedInfo[msg.sender][unlockId].amount > 0, "amount is 0");

        LockedInfo storage userLock = userLockedInfo[msg.sender][unlockId];
        uint lockedTime = block.timestamp - userLock.lockedTime;
        uint amount = userLock.amount;
        uint reward;

        if (lockedTime >= 30 days) {
            reward = amount;
        } else {
            reward = (amount * lockedTime) / 30 days;
        }
        userLock.amount = 0;

        IERC20(tokenContract).transfer(msg.sender, reward);
        _burn(msg.sender, amount);

        emit UserClaimToken(msg.sender, reward);
        emit UserBurnEsToken(msg.sender, amount);
    }
}
