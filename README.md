

## Overview

This project introduces a comprehensive system for creating ERC20 tokens and managing liquidity pools on the Ethereum blockchain. Utilizing the `TokenFactory` contract, users can deploy their own tokens with ease, and the `LiquidityPool` contract facilitates the addition of liquidity and token swapping, enhancing the token's usability and integration into the decentralized finance ecosystem.

### Features

- **TokenFactory Contract**: Enables the creation of `MEOWChild` tokens, each with its own unique name, symbol, and initial supply. The factory also automatically sets up a corresponding liquidity pool for the newly created token.
- **LiquidityPool Contract**: Manages liquidity for token pairs, supports liquidity provision and removal, and enables token swaps with built-in pricing mechanisms based on reserve weights and slopes.

### How It Works

1. **Initialization**: The `TokenFactory` is initialized with a default reserve token, which will be used across all liquidity pools created by the factory.
2. **Token Creation**: Users call the `createToken` function, specifying the token's parameters. A new `MEOWChild` token is minted, and a liquidity pool is set up for it.
3. **Liquidity Management**: Token holders can add to or remove liquidity from the pool, receiving liquidity pool shares in return.
4. **Token Swapping**: Users can swap between the newly created token and the reserve token, with the swap rate determined by the liquidity pool's current state.

### Example: Alice and Bob

Imagine Alice wants to create a new token named "AliceToken" (`ALC`) with an initial supply of 1,000,000 ALC. She uses the `TokenFactory` to deploy her token and automatically sets up a liquidity pool for ALC paired with the default reserve token (e.g., `MEOW`).

Bob, interested in Alice's project, decides to provide liquidity to the ALC-ETH pool. He deposits equal values of ALC and ETH into the pool and receives liquidity pool shares in return. These shares represent his stake in the pool and can be redeemed for a proportional amount of the underlying assets at any time.

Later, Carol discovers Alice's token and decides to acquire some ALC using ETH. She interacts with the liquidity pool, swapping her ETH for ALC at the current rate determined by the pool's reserves. This swap process is seamless, thanks to the `LiquidityPool` contract's integration with the factory-created token.

