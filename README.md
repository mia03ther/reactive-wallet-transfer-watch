# Wallet Transfer Watch

**Track 2: Set It and Forget It · Solo project · Reactive Network Omni**

Wallet Transfer Watch monitors ERC-20 transfers **from one chosen wallet** on Ethereum Sepolia. When an outgoing transfer reaches a configured threshold, a Reactive contract on Lasna requests a callback. An authenticated callback contract on Sepolia records an alert event. The demo uses a test token only; it does not move funds, notify a phone, or assess whether a transfer was malicious.

Without Reactive, a user would need to run and maintain a bot that watches logs and submits alert transactions. Here the subscription and reaction run through Reactive Network. The tradeoffs are execution charges, prefunding on both chains, and the need to handle failed or delayed callbacks.

## Architecture

```text
Sepolia: WatchToken.Transfer(from = watched wallet, amount >= threshold)
    -> Lasna: WalletWatchReactive.react() validates the log and requests a callback
    -> Sepolia: Callback Proxy calls AlertRecorder.recordAlert()
    -> Sepolia: AlertRecorder emits LargeTransferAlert
```

The reactive contract subscribes to the token's `Transfer` topic with the watched address as `topic1`. It checks the chain, token, event, sender, log shape, and amount again in `react()`. After its first accepted event it unsubscribes. The callback accepts calls only from the configured proxy and reactive sender, and deduplicates by source transaction hash and log index.

## Live testnet deployment and evidence

The recorded end-to-end run used the original, three-argument **MVP v1** contract in [deployed/WalletWatchReactive.sol](deployed/WalletWatchReactive.sol). The current [src/WalletWatchReactive.sol](src/WalletWatchReactive.sol) is **v2**, with an explicit maximum amount and source-event deduplication. Its four-argument constructor produces different bytecode. The three transactions below prove v1, not a v2 deployment.

| Role | Network | Address |
| --- | --- | --- |
| [WatchToken](https://sepolia.etherscan.io/address/0x8c8e376E8fE1B7A866a8f29F442d2047df99Bc9E) | Ethereum Sepolia | `0x8c8e376E8fE1B7A866a8f29F442d2047df99Bc9E` |
| [WalletWatchReactive v1](https://lasna.reactscan.net/address/0xd99b9CAC45C478D24839B40150aC2607b9e327A5) | Lasna | `0xd99b9CAC45C478D24839B40150aC2607b9e327A5` |
| [AlertRecorder](https://sepolia.etherscan.io/address/0x806cE576BF65E68Bb8d6479E82fB255218539b8A) | Ethereum Sepolia | `0x806cE576BF65E68Bb8d6479E82fB255218539b8A` |

1. [Source: 150 WWTT transfer on Sepolia](https://sepolia.etherscan.io/tx/0x1a2b0d1b0bfc84f645b2a00ec3e7b46e1895f907b55e3205967e67c5afd2cdbe)
2. [Reaction: `react()` on Lasna](https://lasna.reactscan.net/tx/0x45200ea9a4af6a324eea94e0176c7e7291d823c6e1b2baec1ecfc14b1919df9c)
3. [Destination: `LargeTransferAlert` on Sepolia](https://sepolia.etherscan.io/tx/0xeb72216d529ede6bad86c9b33d02bdbb2995cc1e5e4bf33e4448268f3238db65)

The callback contract recorded one alert. The threshold in this run was 100 WWTT. The one-shot reaction then unsubscribed.

## Install and test

Requirements: Git and Foundry (`forge`, `cast`). Commands below use PowerShell. No wallet is needed for local tests.

```powershell
git clone --recurse-submodules https://github.com/mia03ther/reactive-wallet-transfer-watch.git
cd reactive-wallet-transfer-watch
forge test
```

The tests cover a qualifying transfer, a transfer below the threshold, a wrong sender, an oversized amount, duplicate delivery, unauthorized calls, and callback authentication. `test/WalletWatch.t.sol` tests the **v2 source**; the historical v1 run is verified by the three chain transactions above.

## Reproduce a fresh v2 run

Use a dedicated test wallet with Sepolia ETH and Lasna lREACT. The wallet signs each transaction in the Foundry browser flow; never put a private key or recovery phrase in the repository or command line. Check the **connected Foundry page's chain ID** before each signature: Sepolia is `11155111`, Lasna is `5318007`. The wallet asset filter does not change the page's connected chain.

```powershell
$watchWallet = "YOUR_TEST_WALLET_ADDRESS"
$sepoliaRpc = "https://11155111.rpc.thirdweb.com"
$lasnaRpc = "https://lasna-rpc.rnk.dev/"
$callbackProxy = "0xAa14d9Cd0f788Ca23d11805986C1d8bd035D23b4"
```

1. Connect the Foundry browser page to **Sepolia** and deploy the test token. The deployer receives 1,000 WWTT.

   ```powershell
   forge create src/WatchToken.sol:WatchToken --rpc-url $sepoliaRpc --from $watchWallet --broadcast --browser
   $tokenAddr = "TOKEN_ADDRESS_FROM_DEPLOYMENT_OUTPUT"
   ```

2. Connect to **Lasna** and deploy the funded v2 monitor. The threshold is 100 WWTT, the maximum accepted transfer is 1,000 WWTT, and the monitor accepts one event. Keep `--constructor-args` last.

   ```powershell
   forge create src/WalletWatchReactive.sol:WalletWatchReactive --rpc-url $lasnaRpc --from $watchWallet --value 0.3ether --legacy --gas-price 100gwei --gas-limit 1500000 --broadcast --browser --constructor-args $tokenAddr $watchWallet 100000000000000000000 1000000000000000000000
   $reactiveAddr = "REACTIVE_ADDRESS_FROM_DEPLOYMENT_OUTPUT"
   ```

3. Connect to **Sepolia** and deploy the funded callback contract, then connect to **Lasna** to set its address in the monitor.

   ```powershell
   forge create src/AlertRecorder.sol:AlertRecorder --rpc-url $sepoliaRpc --from $watchWallet --value 0.02ether --broadcast --browser --constructor-args $callbackProxy $reactiveAddr
   $recorderAddr = "RECORDER_ADDRESS_FROM_DEPLOYMENT_OUTPUT"
   cast send $reactiveAddr "setRecipient(address)" $recorderAddr --rpc-url $lasnaRpc --from $watchWallet --legacy --gas-price 100gwei --browser
   ```

4. Connect to **Sepolia** and send 150 WWTT to a test sink. Save the source transaction hash.

   ```powershell
   cast send $tokenAddr "transfer(address,uint256)" 0x000000000000000000000000000000000000dEaD 150000000000000000000 --rpc-url $sepoliaRpc --from $watchWallet --browser
   ```

5. Follow the source `Transfer` receipt, the Lasna `AlertRequested` event, and the destination `LargeTransferAlert` event. Check final state:

   ```powershell
   cast call $recorderAddr "count()(uint256)" --rpc-url $sepoliaRpc
   cast call $reactiveAddr "remaining()(uint256)" --rpc-url $lasnaRpc
   cast call 0x8888888888888888888888888888888888888888 "debt(address)(uint256)" $reactiveAddr --rpc-url $lasnaRpc
   cast call $callbackProxy "debt(address)(uint256)" $recorderAddr --rpc-url $sepoliaRpc
   ```

   Expected after a successful first alert: `count = 1`, `remaining = 0`, and no outstanding debt. A fresh v2 deployment requires **new transaction links**; do not represent the historical v1 links as v2 evidence.

## Safety limits and failure handling

The v2 monitor accepts transfers of **100–1,000 WWTT** from its configured wallet and token. It requests at most **one** callback, then unsubscribes. An event ID based on chain, source transaction hash, and log index prevents repeated processing; the callback also deduplicates. Callback gas is capped at 500,000. This project only records alerts, so the automated asset-transfer amount is zero.

If the Lasna monitor runs out of funds and accrues debt, Reactive stops calling `react()`. Funding the contract through the Lasna system contract's `depositTo(address)` can settle debt and allow future matching events. A plain token transfer to the monitor is not a substitute for settling debt. The Sepolia callback contract also needs native funds; its proxy has its own `depositTo(address)`. A failed reaction or callback may still be charged, and a failed callback is not automatically replayed. Inspect both receipts, fix the cause, and trigger a new test event or deploy a new instance. After the one-shot unsubscribe, topping up does not resubscribe; deploy a new monitor for another run.

## AI use and verification

I used **Codex, Claude Code, and Gemini Antigravity** as part of my personal development workflow for drafting, reviewing, and documenting this project. I chose the wallet-monitoring use case and testnet configuration, checked the contracts and commands, ran the Foundry tests, and verified the source event, Lasna reaction, and Sepolia callback against their transaction receipts. I reviewed wallet network, amount, and destination before signing testnet transactions. AI is **not** part of the running alert decision; `react()` applies deterministic on-chain conditions.

## Demo video

[Watch the 2-minute-18-second demo video (MP4)](https://github.com/mia03ther/reactive-wallet-transfer-watch/releases/download/v0.1.0-demo/reactive-wallet-transfer-watch.mp4). The [public release page](https://github.com/mia03ther/reactive-wallet-transfer-watch/releases/tag/v0.1.0-demo) also contains the video file. The [English recording script](docs/demo-script.md) lists each page shown in the walkthrough.

## References

- [Reactive contracts](https://dev.reactive.network/reactive-contracts)
- [Callback contracts](https://dev.reactive.network/callback-contracts)
- [Economy and system interactions](https://dev.reactive.network/economy)
- [Omni micro-demos](https://github.com/Reactive-Network/reactive-smart-contract-demos/tree/omni/src/micro-demos)

All deployments here use test networks and a test token.
