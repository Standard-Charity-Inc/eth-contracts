/* solium-disable no-trailing-whitespace, security/no-block-members */
// SPDX-License-Identifier: MIT
pragma solidity >= 0.6.0 < 0.7.0;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/utils/Pausable.sol";
import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";

contract StandardCharity is Ownable, Pausable {
  using Counters for Counters.Counter;
  
  mapping (address => mapping (uint256 => Donation)) public donations;
  mapping (address => Counters.Counter) public numDonations;

  struct Donation {
    uint value;
    uint256 timestamp;
    uint valueExpendedETH;
    uint valueExpendedUSD;
  }

  constructor() public {
    
  }

  function donate() public payable {
    require(msg.value > 0, 'Donation amount must be greater than 0');

    numDonations[msg.sender].increment();

    donations[msg.sender][numDonations[msg.sender].current()] = Donation({
      value: msg.value,
      timestamp: now,
      valueExpendedETH: 0,
      valueExpendedUSD: 0
    });
  }
}