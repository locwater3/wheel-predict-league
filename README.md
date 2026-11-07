# Wheel Predict League

A wallet-signed prediction league for Squeekchain's hamster wheel (Squeektoshi).

Players connect an EVM wallet on Ethereum Sepolia, predict the next wheel round — will Squeektoshi **run** or **nap**, and how much work / how many blocks — and lock that prediction with a free `personal_sign` signature (no transaction, no gas). Scoring is verified from real Squeekchain settlements published by the public Squeekchain API, with on-chain transaction hashes for every settled round.

## Live site

https://locwater3.github.io/wheel-predict-league/

## Features

- **Connect Wallet** — real EIP-1193 connect/disconnect, Sepolia network badge (chainId 11155111) with switch-network action, silent reconnect
- **Signed predictions** — each prediction for the next round is locked by a free `personal_sign` over a canonical message (wallet, round, call, work, blocks, timestamp), verified client-side with ethers.js when available
- **Live Squeekchain data** — live status and recent settlements from `https://api.squeekchain.com/v1/` with a 3-second capped refresh and a baked snapshot fallback, so the page still renders if the API is slow
- **Verifiable scoring** — max 100 points per round, scored from real settlements; every settled round links to its Sepolia Etherscan transaction
- **SqueekBot baseline** — an AI baseline prediction (median of the last 10 rounds) to beat
- **Follow & Copy** — follow top predictors and copy their call into your prediction form in one tap
- **Season leaderboard** — with streaks; your own row updates live from your signed predictions

## Honest limits

- Signed predictions are kept on-device for the browser session in this public static build — there is no shared cross-player database yet. The other leaderboard rivals besides you and SqueekBot are clearly labeled demo samples.
- This is a Squeekchain (Sepolia testnet) project. Predictions are signed messages only — no real-money transactions.

## How to play

1. Open the live site in a browser with an EVM wallet (e.g. MetaMask).
2. Click **Connect Wallet** and switch to **Ethereum Sepolia** if prompted.
3. Pick Run or Nap for the next round, enter work + blocks, then **Sign & Lock**.
4. Sign the message in your wallet — it's free, no gas.
5. When the round settles, your score is checked against the real settlement.

## Tech

Single self-contained `index.html` — vanilla HTML/CSS/JS plus ethers.js from CDN when available, and the public Squeekchain API. No build step, no backend, no API keys.

Built for the Squeekchain Genesis / Code program: https://squeekchain.com/genesis/code
