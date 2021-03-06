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
  Counters.Counter public totalNumDonations;
  /**
   * @notice The donationTracker mapping format is as follows:
   * {total donation number for the user}-{donator address without leading 0x}
   *
   * So, for example, if the first donation that this contract receives
   * is from address 0xA7a5F8EA98C9b345075dDa7442A833189Ce3717e, the 
   * donationTracker mapping entry will look like this:
   * 1 => 1-a7a5f8ea98c9b345075dda7442a833189ce3717e
   *
   * Note how the address is converted to lower case.
   */
  mapping (uint256 => string) public donationTracker;
  
  mapping (uint256 => Expenditure) public expenditures;
  Counters.Counter public totalNumExpenditures;

  mapping (uint256 => ExpendedDonation) public expendedDonations;
  Counters.Counter totalNumExpendedDonations;

  uint256 public nextDonationToExpend;

  uint256 public totalDonationsETH;
  uint256 public totalExpendedETH;
  uint256 public totalExpendedUSD;
  // Denoninated as *10, i.e. 50 = 5.0
  uint256 public totalPlatesDeployed;

  SpotlightDonation public maxDonation;
  SpotlightDonation public latestDonation;

  /// @param donationNumber The donation number for this particular address
  struct Donation {
    address donator;
    uint256 value;
    uint256 timestamp;
    uint256 valueExpendedETH;
    uint256 valueExpendedUSD;
    uint256 valueRefundedETH;
    uint256 donationNumber;
    mapping (uint256 => uint256) expendedDonationIDs;
    uint256 numExpenditures;
  }

  struct SpotlightDonation {
    address donator;
    uint256 value;
    uint256 timestamp;
  }

  /// @param donationNumber The donation number for this particular address
  /// @param platedDeployed Denoninated as *10, i.e. 50 = 5.0
  struct ExpendedDonation {
    address donator;
    uint256 valueExpendedETH;
    uint256 valueExpendedUSD;
    uint256 expenditureNumber;
    uint256 donationNumber;
    uint256 platesDeployed;
  }

  /// @param videoHash The hash of the video file associated with this donation. The
  /// XXHash algorithm is used to produce a 32 bit hash with a seed of 0xCAFEBABE
  /// @param valueExpendedUSD Value in cents
  /// @param platedDeployed Denoninated as *10, i.e. 50 = 5.0
  struct Expenditure {
    uint256 valueExpendedETH;
    uint256 valueExpendedUSD;
    string videoHash;
    string receiptHash;
    uint256 timestamp;
    mapping (uint256 => uint256) expendedDonationIDs;
    uint256 numExpendedDonations;
    uint256 valueExpendedByDonations;
    uint256 platesDeployed;
  }

  event LogNewDonation(address donator, uint256 donationNumber, uint256 value, uint256 overallDonationNumber);
  event LogNewExpenditure(uint256 expenditureNumber, uint256 valueETH);
  event LogNewExpendedDonation(address donator, uint256 donationNumber, uint256 expeditureNumber, uint256 expendedDonationNumber);
  event LogNewRefund(address donator, uint256 donationNumber, uint256 valueETH);
  event LogNewNextDonationToExpend(uint256 nextDonationToExpend);

  constructor() public {
    nextDonationToExpend = 1;
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
      valueExpendedUSD: 0,
      donationNumber: donationNumber,
      numExpenditures: 0,
      valueRefundedETH: 0
    });

    donations[msg.sender][donationNumber] = _donation;

    totalNumDonations.increment();

    emit LogNewDonation(msg.sender, donationNumber, msg.value, totalNumDonations.current());

    updateStoredDonations(_donation);

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

  /// @param _valueUSD Denominated in cents
  /// @param _platesDeployed Denoninated as *10, i.e. 50 = 5.0
  function createExpenditure(
    string memory _videoHash,
    string memory _receiptHash,
    uint256 _valueUSD,
    uint256 _valueETH,
    uint256 _platesDeployed
  ) public onlyOwner() {
    require(
      _valueETH > 0,
      'The expenditure value in ETH must be greater than 0'
    );

    require(
      _valueUSD > 0,
      'The expenditure value in USD must be greater than 0'
    );

    require(
      isTextEmpty(_videoHash) == false,
      'A video hash must be supplied'
    );

    require(
      isTextEmpty(_receiptHash) == false,
      'A receipt hash must be supplied'
    );

    require(
      address(this).balance >= _valueETH,
      'The expenditure must be less than or equal to the balance of the contract.'
    );

    totalNumExpenditures.increment();

    expenditures[totalNumExpenditures.current()] = Expenditure({
      valueExpendedETH: _valueETH,
      valueExpendedUSD: _valueUSD,
      videoHash: _videoHash,
      receiptHash: _receiptHash,
      timestamp: now,
      numExpendedDonations: 0,
      valueExpendedByDonations: 0,
      platesDeployed: _platesDeployed
    });

    totalExpendedETH = totalExpendedETH.add(_valueETH);

    totalExpendedUSD = totalExpendedUSD.add(_valueUSD);

    totalPlatesDeployed = totalPlatesDeployed.add(_platesDeployed);

    payable(owner()).transfer(_valueETH);

    emit LogNewExpenditure(totalNumExpenditures.current(), _valueETH);
  }

  function setNextDonationToExpend(uint256 _nextDonationToExpend) public onlyOwner() {
    require(
      _nextDonationToExpend > nextDonationToExpend,
      'You must provide a value greater than the current next donation to expend'
    );
    
    string memory lastDonation = donationTracker[_nextDonationToExpend.sub(1)];

    string memory thisDonation = donationTracker[_nextDonationToExpend];

    if (isTextEmpty(lastDonation) == true && isTextEmpty(thisDonation) == true) {
      revert('The ID of the next donation to expend is invalid');
    }

    nextDonationToExpend = _nextDonationToExpend;

    emit LogNewNextDonationToExpend(_nextDonationToExpend);
  }

  /// @param _platesDeployed Denoninated as *10, i.e. 50 = 5.0
  function createExpendedDonation(
    address _donator,
    uint256 _valueExpendedETH,
    uint256 _valueExpendedUSD,
    uint256 _donationNumber,
    uint256 _expeditureNumber,
    uint256 _platesDeployed
  ) public onlyOwner() {
    Donation memory donation = donations[_donator][_donationNumber];

    Expenditure memory expenditure = expenditures[_expeditureNumber];

    totalNumExpendedDonations.increment();

    ExpendedDonation memory expendedDonation = ExpendedDonation({
      donator: _donator,
      donationNumber: _donationNumber,
      valueExpendedETH: _valueExpendedETH,
      valueExpendedUSD: _valueExpendedUSD,
      expenditureNumber: _expeditureNumber,
      platesDeployed: _platesDeployed
    });

    uint256 currentExpendedDonation = totalNumExpendedDonations.current();

    emit LogNewExpendedDonation(_donator, _donationNumber, _expeditureNumber, currentExpendedDonation);

    expendedDonations[currentExpendedDonation] = expendedDonation;

    // Add the donation expenditure to the donation if the donation exists

    if (donation.value > 0) {
      uint256 numDonationExpenditures = donation.numExpenditures.add(1);

      donations[_donator][_donationNumber].valueExpendedETH =
        donations[_donator][_donationNumber].valueExpendedETH.add(_valueExpendedETH);

      donations[_donator][_donationNumber].valueExpendedUSD =
        donations[_donator][_donationNumber].valueExpendedUSD.add(_valueExpendedUSD);

      donations[_donator][_donationNumber].numExpenditures = numDonationExpenditures;

      donations[_donator][_donationNumber].expendedDonationIDs[numDonationExpenditures] = currentExpendedDonation;
    }

    // Add the donation expenditure to the expenditure if the expenditure exists

    if (expenditure.valueExpendedETH > 0) {
      uint256 numExpendedDonations = expenditure.numExpendedDonations.add(1);

      expenditures[_expeditureNumber].numExpendedDonations = numExpendedDonations;

      expenditures[_expeditureNumber].valueExpendedByDonations =
        expenditures[_expeditureNumber].valueExpendedByDonations.add(_valueExpendedETH);

      expenditures[_expeditureNumber].expendedDonationIDs[numExpendedDonations] = currentExpendedDonation;
    }
  }

  /// @dev Returns an ID (uint256) to be used to get a value from the expendedDonations mapping
  function getExpendedDonationIDForDonation(
    address _address,
    uint256 _donationNumber,
    uint256 _expenditureNumber
  ) public view returns (uint256) {
    return donations[_address][_donationNumber].expendedDonationIDs[_expenditureNumber];
  }

  /// @dev Returns an ID (uint256) to be used to get a value from the expendedDonations mapping
  function getExpendedDonationIDForExpenditure(
    uint256 _expenditureNumber,
    uint256 _expendedDonationNumber
  ) public view returns (uint256) {
    return expenditures[_expenditureNumber].expendedDonationIDs[_expendedDonationNumber];
  }

  function refundDonation(
    address _address,
    uint256 _donationNumber,
    uint256 _valueETHToRefund
  ) public onlyOwner() {
    Donation memory donation = donations[_address][_donationNumber];

    require(
      donation.value > 0,
      'A donation with the provided address and/or donation number could not be found'
    );

    require(
      donation.value.sub(donation.valueExpendedETH) >= _valueETHToRefund,
      'You may not refund more than the value of the donation less any expendeditures'
    );

    // This should never happen, but it's placed here as a check just in case.
    require(
      _valueETHToRefund <= address(this).balance,
      'The contract does not have enough balance to make a refund of the requested size'
    );

    payable(donation.donator).transfer(_valueETHToRefund);

    donations[_address][_donationNumber].valueRefundedETH =
      donations[_address][_donationNumber].valueRefundedETH.add(_valueETHToRefund);

    totalDonationsETH = totalDonationsETH.sub(_valueETHToRefund);

    emit LogNewRefund(_address, _donationNumber, _valueETHToRefund);
  }

  function toAsciiString(address x) public pure returns (string memory) {
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

  function concat(
    string memory _base,
    string memory _value
  ) public pure returns (string memory) {
    bytes memory _baseBytes = bytes(_base);
    bytes memory _valueBytes = bytes(_value);

    string memory _tmpValue = new string(
      _baseBytes.length +
      _valueBytes.length
    );
    
    bytes memory _newValue = bytes(_tmpValue);

    uint i;
    uint j;

    for (i = 0; i < _baseBytes.length; i++) {
      _newValue[j++] = _baseBytes[i];
    }

    for (i = 0; i < _valueBytes.length; i++) {
      _newValue[j++] = _valueBytes[i];
    }

    return string(_newValue);
  }

  function updateStoredDonations(Donation memory _donation) internal {
    if (_donation.value > maxDonation.value) {
      maxDonation = SpotlightDonation({
        donator: _donation.donator,
        value: _donation.value,
        timestamp: _donation.timestamp
      });
    }

    latestDonation = SpotlightDonation({
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

  function getTotalNumDonations() public view returns (uint256) {
    return totalNumDonations.current();
  }

  function getTotalNumExpenditures() public view returns (uint256) {
    return totalNumExpenditures.current();
  }

  function getTotalNumExpendedDonations() public view returns (uint256) {
    return totalNumExpendedDonations.current();
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  /// @notice Check to see if a string is empty
  /// @param _string A string for which to check whether it is empty
  /// @return a boolean value that expresses whether the string is empty
  function isTextEmpty(string memory _string) public pure returns(bool) {
    return bytes(_string).length == 0;
  }
}
