// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IReactive} from "@reactive/src/interfaces/IReactive.sol";
import {ISystemContract} from "@reactive/src/interfaces/ISystemContract.sol";
import {AbstractReactive} from "@reactive/src/base/AbstractReactive.sol";

/// @notice Watches a specific wallet's test-token outflows and requests one alert callback.
contract WalletWatchReactive is AbstractReactive {
    uint256 public constant SEPOLIA = 11155111;
    uint256 public constant TRANSFER_TOPIC =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    uint64 public constant CALLBACK_GAS = 500_000;

    address public immutable owner;
    address public immutable token;
    address public immutable watched;
    uint256 public immutable threshold;
    address public recipient;
    uint256 public remaining = 1;

    event AlertRequested(uint256 indexed sourceTxHash, uint256 indexed logIndex, address to, uint256 amount);

    constructor(address token_, address watched_, uint256 threshold_) payable {
        require(token_ != address(0) && watched_ != address(0), "zero address");
        require(threshold_ > 0 && msg.value > 0, "invalid configuration");
        owner = msg.sender;
        token = token_;
        watched = watched_;
        threshold = threshold_;
        SYSTEM.subscribe(SEPOLIA, token_, TRANSFER_TOPIC, uint256(uint160(watched_)), REACTIVE_IGNORE, REACTIVE_IGNORE);
    }

    function setRecipient(address recipient_) external {
        require(msg.sender == owner, "not owner");
        require(recipient_ != address(0), "zero recipient");
        recipient = recipient_;
    }

    /// @inheritdoc IReactive
    function react(LogRecord calldata log_) external onlySystem {
        if (remaining == 0 || recipient == address(0) || log_.chainId != SEPOLIA ||
            log_.contractAddress != token || log_.topic0 != TRANSFER_TOPIC ||
            log_.opCode != 3 || log_.topic1 != uint256(uint160(watched)) ||
            log_.topic2 >> 160 != 0 ||
            log_.data.length != 32) return;

        uint256 amount = abi.decode(log_.data, (uint256));
        if (amount < threshold) return;
        address to = address(uint160(log_.topic2));

        remaining = 0;
        emit AlertRequested(log_.txHash, log_.logIndex, to, amount);
        SYSTEM.unsubscribe(SEPOLIA, token, TRANSFER_TOPIC, uint256(uint160(watched)), REACTIVE_IGNORE, REACTIVE_IGNORE);

        bytes memory payload = abi.encodeWithSignature(
            "recordAlert(address,uint256,uint256,address,address,uint256)",
            address(0), log_.txHash, log_.logIndex, watched, to, amount
        );
        SYSTEM.requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0({
            chainId: SEPOLIA, recipient: recipient, gasLimit: CALLBACK_GAS, payload: payload
        }));
    }
}
