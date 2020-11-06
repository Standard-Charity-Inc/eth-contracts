# Standard Charity ETH contracts

> Ethereum smart contracts for Standard Charity written in Solidity

## Development

This project utilizes contracts developed by [Open Zeppelin](https://docs.openzeppelin.com/openzeppelin/). To import the required npm modules, run the following from the root of the project:

`npm install`

You'll need [Truffle](https://www.trufflesuite.com/truffle) installed:

`npm install truffle -g`

To compile contracts, run:

`truffle compile`

To migrate the contracts (i.e. deploy the contracts to a testnet), you'll need an instance of a testnet running locally. Ganache CLI is a useful tool for getting a local blockchain up and running.

First, install Ganache CLI:

`npm install -g ganache-cli`

Then, run the CLI:

`ganache-cli`

You can now migrate the contracts to the local blockchain:

`truffle migrate`

## Testing

To test the contracts, follow the steps above in **Development** to start a development blockchain with Gananche CLI, then run the following:

`truffle test`
