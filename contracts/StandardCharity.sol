/* solium-disable no-trailing-whitespace, security/no-block-members */
// SPDX-License-Identifier: MIT
pragma solidity >= 0.6.0 < 0.7.0;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/utils/Pausable.sol";
import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";
import "../node_modules/@openzeppelin/contracts/utils/Strings.sol";
import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

contract StandardCharity is Ownable, Pausable {
  using Counters for Counters.Counter;
  using Strings for *;
  using SafeMath for uint256;

  mapping (address => mapping (uint256 => Donation)) public donations;
  mapping (address => Counters.Counter) public numDonationsByUser;
  /**
   * @notice The donationTracker mapping format is as follows:
   * {total donation number}-{donator address without leading 0x}
   *
   * So, for example, if the first donation that this contract receives
   * is from address 0xA7a5F8EA98C9b345075dDa7442A833189Ce3717e, the 
   * donationTracker mapping entry will look like this:
   * 1 => 1-a7a5f8ea98c9b345075dda7442a833189ce3717e
   */
  mapping (uint256 => string) public donationTracker;
  
  mapping (uint256 => Expenditure) public expenditures;
  mapping (address => ExpendedDonation) public expendedDonations;

  Counters.Counter public totalNumDonations;
  Counters.Counter public nextDonationToExpend;
  Counters.Counter public totalNumExpenditures;

  uint256 public totalDonationsETH;
  uint256 public totalExpendedETH;
  uint256 public totalExpendedUSD;

  MaxDonation public maxDonation;
  LatestDonation public latestDonation;

  /// @param donationNumber The donation number for this particular address
  struct Donation {
    address donator;
    uint256 value;
    uint256 timestamp;
    uint256 valueExpendedETH;
    uint256 donationNumber;
  }

  struct MaxDonation {
    address donator;
    uint256 value;
    uint256 timestamp;
  }

  struct LatestDonation {
    address donator;
    uint256 value;
    uint256 timestamp;
  }

  /// @param donationNumber The donation number for this particular address
  struct ExpendedDonation {
    address donator;
    uint256 valueExpendedETH;
    uint256 valueExpendedUSD;
    uint256 timestamp;
    uint256 donationNumber;
    // mapping (uint => Expenditure) expenditures;
  }

  /// @param videoHash The hash of the video file associated with this donation. The
  /// XXHash algorithm is used to produce a 32 bit hash with a seed of 0xCAFEBABE
  /// @param valueExpendedUSD Value in cents
  struct Expenditure {
    uint256 valueExpendedETH;
    uint256 valueExpendedUSD;
    string videoHash;
    uint256 timestamp;
  }

  event LogNewDonation(address donator, uint256 value);

  constructor() public {
    nextDonationToExpend.increment();
  }

  function donate() public payable {
    require(msg.value > 0, 'Donation amount must be greater than 0');

    numDonationsByUser[msg.sender].increment();

    uint256 donationNumber = numDonationsByUser[msg.sender].current();

    Donation memory _donation = Donation({
      donator: msg.sender,
      value: msg.value,
      timestamp: now,
      valueExpendedETH: 0,
      donationNumber: donationNumber
    });

    donations[msg.sender][donationNumber] = _donation;

    emit LogNewDonation(msg.sender, msg.value);

    updateStoredDonations(_donation);

    totalNumDonations.increment();

    string memory donationNumWithDash = concat(
      donationNumber.toString(),
      '-'
    );

    donationTracker[totalNumDonations.current()] = concat(
      donationNumWithDash,
      toAsciiString(msg.sender)
    );

    totalDonationsETH = totalDonationsETH.add(msg.value);
  }

  function createExpenditure(
    string memory _videoHash,
    uint256 _valueUSD,
    uint256 _valueETH
  ) public onlyOwner() {
    require(
      address(this).balance >= _valueETH,
      'The expenditure must be less than or equal to the balance of the contract.'
    );

    totalNumExpenditures.increment();

    expenditures[totalNumExpenditures.current()] = Expenditure({
      valueExpendedETH: _valueETH,
      valueExpendedUSD: _valueUSD,
      videoHash: _videoHash,
      timestamp: now
    });

    totalExpendedETH = totalExpendedETH.add(_valueETH);

    totalExpendedUSD = totalExpendedUSD.add(_valueUSD);

    payable(owner()).transfer(_valueETH);
  }

  // TO DO: Create function to create expended donation. Link expended
  // donation to original donation.

  function addressToString(address x) private pure returns (string memory) {
    bytes memory b = new bytes(20);

    for (uint i = 0; i < 20; i++)
        b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));

    return string(b);
  }

  function toAsciiString(address x) internal pure returns (string memory) {
    bytes memory s = new bytes(40);

    for (uint i = 0; i < 20; i++) {
        byte b = byte(uint8(uint(x) / (2**(8*(19 - i)))));
        byte hi = byte(uint8(b) / 16);
        byte lo = byte(uint8(b) - 16 * uint8(hi));
        s[2*i] = char(hi);
        s[2*i+1] = char(lo);            
    }

    return string(s);
  }

  function char(byte b) internal pure returns (byte c) {
      if (uint8(b) < 10) return byte(uint8(b) + 0x30);
      else return byte(uint8(b) + 0x57);
  }

  function concat(string memory _base, string memory _value) internal pure returns (string memory) {
    bytes memory _baseBytes = bytes(_base);
    bytes memory _valueBytes = bytes(_value);

    string memory _tmpValue = new string(_baseBytes.length + _valueBytes.length);
    bytes memory _newValue = bytes(_tmpValue);

    uint i;
    uint j;

    for(i = 0; i < _baseBytes.length; i++) {
      _newValue[j++] = _baseBytes[i];
    }

    for(i = 0; i < _valueBytes.length; i++) {
      _newValue[j++] = _valueBytes[i];
    }

    return string(_newValue);
  }

  function updateStoredDonations(Donation memory _donation) internal {
    if (_donation.value > maxDonation.value) {
      maxDonation = MaxDonation({
        donator: _donation.donator,
        value: _donation.value,
        timestamp: _donation.timestamp
      });
    }

    latestDonation = LatestDonation({
      donator: _donation.donator,
      value: _donation.value,
      timestamp: _donation.timestamp
    });
  }

  receive() external payable {
    if (msg.value > 0) {
      payable(owner()).transfer(msg.value);
    }
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }
}
