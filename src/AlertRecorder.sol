// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IPayable} from "@reactive/src/interfaces/IPayable.sol";
import {AbstractCallback} from "@reactive/src/base/AbstractCallback.sol";

/// @notice Stores authenticated alerts delivered by the Sepolia Callback Proxy.
contract AlertRecorder is AbstractCallback {
    uint256 public count;
    mapping(bytes32 => bool) public recorded;

    event LargeTransferAlert(
        uint256 indexed sourceTxHash, uint256 indexed logIndex,
        address indexed from, address to, uint256 amount
    );

    constructor(IPayable proxy_, address reactive_) payable AbstractCallback(proxy_, reactive_) {}

    function recordAlert(
        address reactive_, uint256 sourceTxHash, uint256 logIndex,
        address from, address to, uint256 amount
    ) external onlyServiceProvider onlyCallbackSender(reactive_) {
        bytes32 id = keccak256(abi.encode(sourceTxHash, logIndex));
        if (recorded[id]) return;
        recorded[id] = true;
        count += 1;
        emit LargeTransferAlert(sourceTxHash, logIndex, from, to, amount);
    }
}
