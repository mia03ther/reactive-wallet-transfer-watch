# Wallet Transfer Watch — 90-Second Demo Script

Record your screen and speak the lines below in English. Open these four pages in separate tabs before recording:

1. [Project README](https://github.com/mia03ther/reactive-wallet-transfer-watch)
2. [Sepolia source transaction](https://sepolia.etherscan.io/tx/0x1a2b0d1b0bfc84f645b2a00ec3e7b46e1895f907b55e3205967e67c5afd2cdbe)
3. [Lasna reaction transaction](https://lasna.reactscan.net/tx/0x45200ea9a4af6a324eea94e0176c7e7291d823c6e1b2baec1ecfc14b1919df9c)
4. [Sepolia callback transaction](https://sepolia.etherscan.io/tx/0xeb72216d529ede6bad86c9b33d02bdbb2995cc1e5e4bf33e4448268f3238db65)

## 0:00–0:15 — Project

**Show:** Project README and the four-line architecture.

**Say:** “Hi, I’m MIA_Ether. This is Wallet Transfer Watch, my solo project for the Set It and Forget It track. It watches outgoing test-token transfers from one wallet and records an on-chain alert when a transfer reaches a threshold.”

## 0:15–0:35 — Source event

**Open:** [Sepolia source transaction](https://sepolia.etherscan.io/tx/0x1a2b0d1b0bfc84f645b2a00ec3e7b46e1895f907b55e3205967e67c5afd2cdbe). Scroll to the `Transfer` event.

**Say:** “Here is the source event on Ethereum Sepolia. My test wallet transferred 150 Wallet Watch Test Tokens. The configured threshold was 100 tokens, so the event qualified.”

## 0:35–0:55 — Reactive execution

**Open:** [Lasna reaction transaction](https://lasna.reactscan.net/tx/0x45200ea9a4af6a324eea94e0176c7e7291d823c6e1b2baec1ecfc14b1919df9c).

**Say:** “Reactive Network detected the transfer and called my `react()` function on Lasna. The contract checked the wallet, token, and amount, then requested a callback. This first deployed MVP handles one qualifying event and unsubscribes.”

## 0:55–1:15 — Callback

**Open:** [Sepolia callback transaction](https://sepolia.etherscan.io/tx/0xeb72216d529ede6bad86c9b33d02bdbb2995cc1e5e4bf33e4448268f3238db65). Scroll to the `LargeTransferAlert` event.

**Say:** “The authenticated Callback Proxy then called my AlertRecorder on Sepolia. This transaction emitted the LargeTransferAlert event. These three transactions show the complete source event, reaction, and destination action.”

## 1:15–1:30 — Verification and close

**Open:** [Project README](https://github.com/mia03ther/reactive-wallet-transfer-watch). Show the test and AI-use sections.

**Say:** “The repository includes the deployed MVP source, the current version with extra safeguards, Foundry tests, and reproduction steps. I used Codex, Claude Code, and Gemini Antigravity in my development workflow, and verified the behavior with tests and on-chain receipts. Thanks for watching.”

The linked run is **MVP v1**. Do not describe its on-chain bytecode as the current v2 source.
