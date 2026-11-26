// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {IReactive} from "@reactive/src/interfaces/IReactive.sol";
import {IPayable} from "@reactive/src/interfaces/IPayable.sol";
import {ISystemContract} from "@reactive/src/interfaces/ISystemContract.sol";
import {WatchToken} from "../src/WatchToken.sol";
import {WalletWatchReactive} from "../src/WalletWatchReactive.sol";
import {AlertRecorder} from "../src/AlertRecorder.sol";

contract WatchSystemMock {
    uint256 public unsubscriptions;
    uint256 public requestCount;
    ISystemContract.CallbackConfiguration_V_1_0 public request;

    function subscribe(uint256, address, uint256, uint256, uint256, uint256) external {}
    function unsubscribe(uint256, address, uint256, uint256, uint256, uint256) external { unsubscriptions++; }
    function requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0 memory config) external {
        request = config;
        requestCount++;
    }
    function lastRequest() external view returns (ISystemContract.CallbackConfiguration_V_1_0 memory) { return request; }
}

contract WatchProxyMock {
    function deliver(address recipient, address reactive, bytes memory payload) external returns (bool ok) {
        assembly { mstore(add(payload, 36), reactive) }
        (ok,) = recipient.call(payload);
    }
}

contract WalletWatchTest is Test {
    address constant SYSTEM = 0x8888888888888888888888888888888888888888;
    address constant WATCHED = address(0xBEEF);
    address constant DEST = address(0xCAFE);
    WatchToken token;
    WalletWatchReactive monitor;
    AlertRecorder recorder;
    WatchSystemMock system;
    WatchProxyMock proxy;

    function setUp() public {
        WatchSystemMock mock = new WatchSystemMock();
        vm.etch(SYSTEM, address(mock).code);
        system = WatchSystemMock(SYSTEM);
        proxy = new WatchProxyMock();
        token = new WatchToken();
        monitor = new WalletWatchReactive{value: 0.1 ether}(address(token), WATCHED, 100 ether, 1_000 ether);
        recorder = new AlertRecorder{value: 0.02 ether}(IPayable(payable(address(proxy))), address(monitor));
        monitor.setRecipient(address(recorder));
    }

    function testThresholdAndCallback() public {
        IReactive.LogRecord memory low = _log(99 ether, 1);
        IReactive.LogRecord memory high = _log(150 ether, 2);
        vm.startPrank(SYSTEM);
        monitor.react(low);
        assertEq(monitor.remaining(), 1);
        monitor.react(high);
        vm.stopPrank();
        assertEq(monitor.remaining(), 0);
        assertEq(system.unsubscriptions(), 1);
        assertTrue(monitor.processed(keccak256(abi.encode(uint256(11155111), uint256(2), uint256(7)))));

        vm.prank(SYSTEM);
        monitor.react(high);
        assertEq(system.unsubscriptions(), 1);
        assertEq(system.requestCount(), 1);

        ISystemContract.CallbackConfiguration_V_1_0 memory config = system.lastRequest();
        assertEq(config.recipient, address(recorder));
        assertTrue(proxy.deliver(address(recorder), address(monitor), config.payload));
        assertEq(recorder.count(), 1);
        assertTrue(recorder.recorded(keccak256(abi.encode(uint256(2), uint256(7)))));
        assertTrue(proxy.deliver(address(recorder), address(monitor), config.payload));
        assertEq(recorder.count(), 1);
    }

    function testAmountCapBlocksOversizedTransfer() public {
        IReactive.LogRecord memory oversized = _log(1_001 ether, 3);
        vm.prank(SYSTEM);
        monitor.react(oversized);
        assertEq(monitor.remaining(), 1);
        assertEq(system.unsubscriptions(), 0);
        assertEq(system.requestCount(), 0);
    }

    function testUnauthorizedCallsAndWrongWallet() public {
        IReactive.LogRecord memory log_ = _log(150 ether, 2);
        vm.expectRevert();
        monitor.react(log_);
        log_.topic1 = uint256(uint160(address(0xDEAD)));
        vm.prank(SYSTEM);
        monitor.react(log_);
        assertEq(monitor.remaining(), 1);

        bytes memory payload = abi.encodeWithSignature(
            "recordAlert(address,uint256,uint256,address,address,uint256)",
            address(monitor), uint256(2), uint256(7), WATCHED, DEST, 150 ether
        );
        (bool ok,) = address(recorder).call(payload);
        assertFalse(ok);
    }

    function _log(uint256 amount, uint256 txHash) internal view returns (IReactive.LogRecord memory log_) {
        log_.chainId = 11155111;
        log_.contractAddress = address(token);
        log_.topic0 = monitor.TRANSFER_TOPIC();
        log_.topic1 = uint256(uint160(WATCHED));
        log_.topic2 = uint256(uint160(DEST));
        log_.data = abi.encode(amount);
        log_.opCode = 3;
        log_.txHash = txHash;
        log_.logIndex = 7;
    }
}
