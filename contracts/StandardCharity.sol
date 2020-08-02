/* solium-disable no-trailing-whitespace, security/no-block-members */
// SPDX-License-Identifier: MIT
pragma solidity >= 0.6.0 < 0.7.0;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/utils/Pausable.sol";
import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";

contract StandardCharity is Ownable, Pausable {
  using Counters for Counters.Counter;

  mapping (address => mapping (uint256 => UnexpendedDonation)) public unexpendedDonations;
  mapping (address => Counters.Counter) public numUnexpendedDonations;

  MaxDonation public maxDonation;

  struct UnexpendedDonation {
    address donator;
    uint value;
    uint256 timestamp;
    uint valueExpendedETH;
  }

  struct MaxDonation {
    address donator;
    uint value;
    uint256 timestamp;
  }

  event LogNewDonation(address donator, uint value);

  // constructor() public {
    
  // }

  function donate() public payable {
    require(msg.value > 0, 'Donation amount must be greater than 0');

    numUnexpendedDonations[msg.sender].increment();

    UnexpendedDonation memory _donation = UnexpendedDonation({
      donator: msg.sender,
      value: msg.value,
      timestamp: now,
      valueExpendedETH: 0
    });

    unexpendedDonations[msg.sender][numUnexpendedDonations[msg.sender].current()] = _donation;

    emit LogNewDonation(msg.sender, msg.value);

    checkMaxDonation(_donation);
  }

  function checkMaxDonation(UnexpendedDonation memory _donation) private {
    if (_donation.value > maxDonation.value) {
      maxDonation = MaxDonation({
        donator: _donation.donator,
        value: _donation.value,
        timestamp: _donation.timestamp
      });
    }
  }
}