// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}
abstract contract Ownable is Context {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);

    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract SolarChainICO is Ownable {
    error RefundNotInitiated();
    error NoTokensToClaim();
    error NotParticipated();
    error SoftCapNotReached();
    error AlreadyRefunded();
    error NotTime();
    error SoftCapReached();
    // error SoftCapNotReached();
    error InvalidPrice();
    error HardCapReached();
    error NotEnoughSCC();
    error AmountZero();
    error NotInitiated();
    error TFailed();
    error AlreadyInitiated();
    error InvalidTime();
    error InvalidCap();
    IERC20 private solarChainCoin;
    IERC20 private paymentToken;

    uint256 private tokenPrice;
    uint256 private hardCap;
    uint256 private softCap;
    uint256 private startTime;
    uint256 private endTime;
    uint256 private totalSold;
    bool private isInitiated;
    bool private isSoftCapReached;
    bool private isRefundInitiated;

    struct UserInfo {
        address user;
        uint256 tokensPurchased;
        uint256 tokensClaimed;
        uint256 remainToClaim;
        uint256 amountPaid;
    }

    mapping(address => UserInfo) private userInfo;

    event ICOInitiated(uint256 tokensDeposited);
    event TokensPurchased(
        address indexed buyer,
        uint256 usdtAmount,
        uint256 tokensReceived
    );

    constructor(
        address _coin,
        address _pToken,
        uint256 _tokenPrice
    ) Ownable(msg.sender) {
        solarChainCoin = IERC20(_coin);
        paymentToken = IERC20(_pToken);
        tokenPrice = _tokenPrice;
    }

    function initiateICO(
        uint256 _amount,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        if (_startTime < block.timestamp) {
            revert InvalidTime();
        }
        if (isInitiated) {
            revert AlreadyInitiated();
        }

        if (_amount <= 0) {
            revert AmountZero();
        }
        if (_softCap <= 0 || _hardCap <= 0) {
            revert InvalidCap();
        }
        softCap = _softCap;
        hardCap = _hardCap;
        startTime = _startTime;
        endTime = _endTime;
        bool success = solarChainCoin.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        if (!success) {
            revert TFailed();
        }

        isInitiated = true;
        emit ICOInitiated(_amount);
    }

    function buyTokens(uint256 _pTAmount) external {
        if (!isInitiated) {
            revert NotInitiated();
        }
        if (_pTAmount <= 0) {
            revert AmountZero();
        }

        uint256 tokensToReceive = _pTAmount * tokenPrice * 10 ** 18;

        if (tokensToReceive <= 0) {
            revert AmountZero();
        }

        if (solarChainCoin.balanceOf(address(this)) < tokensToReceive) {
            revert NotEnoughSCC();
        }

        bool pSuccess = paymentToken.transferFrom(
            msg.sender,
            owner(),
            _pTAmount
        );
        if (!pSuccess) {
            revert TFailed();
        }
        totalSold += tokensToReceive;

        if (totalSold >= softCap) {
            isSoftCapReached = true;
        }
        if (totalSold > hardCap) {
            revert HardCapReached();
        }
        UserInfo storage user = userInfo[msg.sender];
        if (user.user == address(0)) {
            user.user = msg.sender;
        }
        user.tokensPurchased += tokensToReceive;
        user.amountPaid += _pTAmount;
        if (isSoftCapReached) {
            bool tokenSuccess = solarChainCoin.transfer(
                msg.sender,
                tokensToReceive
            );
            if (!tokenSuccess) {
                revert TFailed();
            }
        } else {
            userInfo[msg.sender].remainToClaim += tokensToReceive;
        }

        emit TokensPurchased(msg.sender, _pTAmount, tokensToReceive);
    }

    function updateTokenPrice(uint256 _newPrice) external onlyOwner {
        if (_newPrice <= 0) {
            revert InvalidPrice();
        }
        tokenPrice = _newPrice;
    }

    function updateStartandEndTime(
        uint256 _newStartTime,
        uint256 _newEndTime
    ) external onlyOwner {
        startTime = _newStartTime;
        endTime = _newEndTime;
    }

    function emergencyWithdraw(
        address _tokenAddress,
        uint256 _amount
    ) external onlyOwner {
        if (totalSold < softCap) {
            revert SoftCapNotReached();
        }
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
    }

    function initiateRefundPolicy() external onlyOwner {
        if (isSoftCapReached) {
            revert SoftCapReached();
        }

        if (block.timestamp < endTime) {
            revert NotTime();
        }
        if (isRefundInitiated) {
            revert AlreadyRefunded();
        }
        isRefundInitiated = true;
    }

    function claimSCCoin() external {
        if (!isSoftCapReached) {
            revert SoftCapNotReached();
        }
        UserInfo storage user = userInfo[msg.sender];
        if (user.user == address(0)) {
            revert NotParticipated();
        }
        if (user.remainToClaim <= 0) {
            revert NoTokensToClaim();
        }
        uint256 tokensToClaim = user.remainToClaim;
        user.remainToClaim = 0;
        bool tokenSuccess = solarChainCoin.transfer(msg.sender, tokensToClaim);
        if (!tokenSuccess) {
            revert TFailed();
        }
    }

    function claimPaymentToken() external {
        if (!isRefundInitiated) {
            revert RefundNotInitiated();
        }
        UserInfo storage user = userInfo[msg.sender];
        if (user.user == address(0)) {
            revert NotParticipated();
        }
        if (user.amountPaid <= 0) {
            revert NoTokensToClaim();
        }
        uint256 amountToClaim = user.amountPaid;
        user.amountPaid = 0;
        bool tokenSuccess = paymentToken.transfer(msg.sender, amountToClaim);
        if (!tokenSuccess) {
            revert TFailed();
        }
    }

    function getUserInfo(
        address _user
    ) external view returns (UserInfo memory) {
        return userInfo[_user];
    }

    function getSolarChainCoin() external view returns (address) {
        return address(solarChainCoin);
    }

    function getPaymentToken() external view returns (address) {
        return address(paymentToken);
    }

    function getTokenPrice() external view returns (uint256) {
        return tokenPrice;
    }

    function getHardCap() external view returns (uint256) {
        return hardCap;
    }

    function getSoftCap() external view returns (uint256) {
        return softCap;
    }

    function getStartTime() external view returns (uint256) {
        return startTime;
    }

    function getEndTime() external view returns (uint256) {
        return endTime;
    }

    function getTotalSold() external view returns (uint256) {
        return totalSold;
    }

    function getIsInitiated() external view returns (bool) {
        return isInitiated;
    }

    function getIsSoftCapReached() external view returns (bool) {
        return isSoftCapReached;
    }

    function getIsRefundInitiated() external view returns (bool) {
        return isRefundInitiated;
    }
}
