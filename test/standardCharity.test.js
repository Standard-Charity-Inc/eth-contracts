const StandardCharity = artifacts.require("StandardCharity");
const catchRevert = require("./exceptionsHelpers").catchRevert;
const BN = web3.utils.BN;

contract("StandardCharity", (accounts) => {
  const firstAccount = accounts[0];
  const secondAccount = accounts[1];

  let instance;

  beforeEach(async () => {
    instance = await StandardCharity.new();
  });

  describe("setup", () => {
    it("sets the deploying address to be the owner of the contract", async () => {
      const owner = await instance.owner();

      assert.equal(
        owner,
        firstAccount,
        "The deploying address should be the contract owner"
      );
    });

    it("sets the nextDonationToExpend to 1", async () => {
      const nextDonationToExpend = await instance.nextDonationToExpend();

      assert.equal(
        nextDonationToExpend,
        1,
        "Initial nextDonationToExpend should be set to 1"
      );
    });
  });

  describe("donate()", () => {
    it("reverts if the transaction amount is 0", async () => {
      await catchRevert(instance.donate(), {
        from: secondAccount,
        value: 0,
      });
    });

    it("increases the number of donations by the user by 1", async () => {
      await instance.donate({
        from: secondAccount,
        value: 10000,
      });

      const numDonationsByUser = await instance.numDonationsByUser.call(
        secondAccount
      );

      assert.equal(
        numDonationsByUser,
        1,
        "The number of donations by the user should increase by 1 when a donation is made"
      );

      const numDoationsByFirstUser = await instance.numDonationsByUser.call(
        firstAccount
      );

      assert.equal(
        numDoationsByFirstUser,
        0,
        "The number of donations stored for a particular user should not be affected by donations made by a different user"
      );

      await instance.donate({
        from: secondAccount,
        value: 10000,
      });

      const numDonationsByUser2 = await instance.numDonationsByUser.call(
        secondAccount
      );

      assert.equal(
        numDonationsByUser2,
        2,
        "The number of donations by the user should increase by 1 when a donation is made"
      );
    });

    it("increments the total number of donations by 1", async () => {
      await instance.donate({
        from: secondAccount,
        value: 10000,
      });

      const totalNumDonations = await instance.totalNumDonations();

      assert(
        totalNumDonations,
        1,
        "The total number of donations should be increased by 1 when a donation is made"
      );

      await instance.donate({
        from: secondAccount,
        value: 10000,
      });

      const totalNumDonations2 = await instance.totalNumDonations();

      assert(
        totalNumDonations2,
        2,
        "The total number of donations should be increased by 1 when a donation is made"
      );
    });

    it("correctly adds an item to the donation tracker mapping", async () => {
      const error =
        "When a donation is made, the donationTracker mapping should be updated with a format as follows: {total donation number for the user}-{donator address without leading 0x}";

      await instance.donate({
        from: firstAccount,
        value: 10000,
      });

      const firstDonationTrackerItem = await instance.donationTracker.call(1, {
        from: firstAccount,
        value: 0,
      });

      assert.equal(
        firstDonationTrackerItem,
        `1-${firstAccount.replace("0x", "").toLowerCase()}`,
        error
      );

      await instance.donate({
        from: firstAccount,
        value: 10000,
      });

      const secondDonationTrackerItem = await instance.donationTracker.call(2, {
        from: firstAccount,
        value: 0,
      });

      assert.equal(
        secondDonationTrackerItem,
        `2-${firstAccount.replace("0x", "").toLowerCase()}`,
        error
      );

      await instance.donate({
        from: secondAccount,
        value: 10000,
      });

      const thirdDonationTrackerItem = await instance.donationTracker.call(3, {
        from: secondAccount,
        value: 0,
      });

      assert.equal(
        thirdDonationTrackerItem,
        `1-${secondAccount.replace("0x", "").toLowerCase()}`,
        error
      );
    });

    it("increases the total ETH donations by the value of the donation", async () => {
      const error =
        "A donation should increase the total ETH donations by the value of the donation";

      await instance.donate({
        from: firstAccount,
        value: 10000,
      });

      const totalDonationsETH = await instance.totalDonationsETH();

      assert.equal(totalDonationsETH, 10000, error);

      await instance.donate({
        from: secondAccount,
        value: 20000,
      });

      const totalDonationsETH2 = await instance.totalDonationsETH();

      assert.equal(totalDonationsETH2, 30000, error);

      await instance.donate({
        from: firstAccount,
        value: 10000,
      });

      const totalDonationsETH3 = await instance.totalDonationsETH();

      assert.equal(totalDonationsETH3, 40000, error);
    });
  });

  describe("setNextDonationToExpend()", () => {
    it("successfully sets the next donation to expend if the account is the contract owner", async () => {
      await instance.donate({
        from: firstAccount,
        value: 10000,
      });

      await instance.setNextDonationToExpend(2, {
        from: firstAccount,
        value: 0,
      });

      const nextDonationToExpend = await instance.nextDonationToExpend();

      assert.equal(
        nextDonationToExpend,
        2,
        "The next donation to expend should be set by calling setNextDonationToExpend() from the address of the contract owner"
      );
    });

    it("reverts if the account is not the contract owner", async () => {
      await catchRevert(
        instance.setNextDonationToExpend(2, {
          from: secondAccount,
          value: 0,
        })
      );
    });

    it("reverts if the next donation to expend is less than the current", async () => {
      await instance.donate({
        from: firstAccount,
        value: 10000,
      });

      await instance.setNextDonationToExpend(2, {
        from: firstAccount,
        value: 0,
      });

      await catchRevert(
        instance.setNextDonationToExpend(1, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("reverts if the contract owner tries to set the next donation to expend to a value that could never be associated with a donation -- i.e. is out of bounds given previous donations (or lack thereof)", async () => {
      /**
       * This will revert because there was never a first
       * donation, so setting the next donation to expend to
       * the second donation would not make sense -- i.e. it
       * would be out of bounds.
       */
      await catchRevert(
        instance.setNextDonationToExpend(2, {
          from: firstAccount,
          value: 0,
        })
      );
    });
  });

  describe("createExpenditure()", () => {
    it("reverts if address does not belong to the contract owner", async () => {
      await catchRevert(
        instance.createExpenditure("abcd", "abcde", 10000, 10050, {
          from: secondAccount,
          value: 0,
        })
      );
    });

    it("reverts if a video hash is not provided", async () => {
      await catchRevert(
        instance.createExpenditure("", "abcde", 10000, 10050, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("reverts if the ETH value is 0", async () => {
      await catchRevert(
        instance.createExpenditure("abcd", "abcde", 0, 10050, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("reverts if the USD value is 0", async () => {
      await catchRevert(
        instance.createExpenditure("abcd", "abcde", 10000, 0, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("reverts if the contract balance is less than the ETH to expend", async () => {
      await catchRevert(
        instance.createExpenditure("abcd", "abcde", 10000, 10050, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("increases the total number of expenditures by 1 when an expenditure is made", async () => {
      await instance.donate({
        from: firstAccount,
        value: 10000,
      });

      await instance.createExpenditure("abcd", "abcde", 10050, 10000, {
        from: firstAccount,
        value: 0,
      });

      const totalNumExpenditures = await instance.totalNumExpenditures();

      assert.equal(
        totalNumExpenditures,
        1,
        "The total number of expenditures should increase by one when an expenditure is created"
      );
    });

    it("increases the total expended in ETH by the ETH value of the expenditure", async () => {
      const error =
        "The total expended in ETH should be increased by the amount of an expenditure when an expenditure is created";

      await instance.donate({
        from: firstAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 10050, 10000, {
        from: firstAccount,
        value: 0,
      });

      const totalExpendedETH = await instance.totalExpendedETH();

      assert.equal(totalExpendedETH, 10000, error);

      await instance.createExpenditure("abcd", "abcde", 10050, 20000, {
        from: firstAccount,
        value: 0,
      });

      const totalExpendedETH2 = await instance.totalExpendedETH();

      assert.equal(totalExpendedETH2, 30000, error);
    });

    it("increases the total expended in USD by the USD value of the expenditure", async () => {
      const error =
        "The total expended in USD should be increased by the amount of an expenditure when an expenditure is created";

      await instance.donate({
        from: firstAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 10000, 10000, {
        from: firstAccount,
        value: 0,
      });

      const totalExpendedUSD = await instance.totalExpendedUSD();

      assert.equal(totalExpendedUSD, 10000, error);

      await instance.createExpenditure("abcd", "abcde", 20000, 20000, {
        from: firstAccount,
        value: 0,
      });

      const totalExpendedUSD2 = await instance.totalExpendedUSD();

      assert.equal(totalExpendedUSD2, 30000, error);
    });

    it("increases the balance of the owner of the contract by the amount of the expenditure", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      const expenditureValueETH = 20000;

      const preExpenditureBalance = await web3.eth.getBalance(firstAccount);

      const createExpenditureReceipt = await instance.createExpenditure(
        "abcd",
        "abcde",
        20000,
        expenditureValueETH,
        {
          from: firstAccount,
          value: 0,
        }
      );

      const createExpenditureTx = await web3.eth.getTransaction(
        createExpenditureReceipt.tx
      );

      const createExpenditureTxCost =
        Number(createExpenditureTx.gasPrice) *
        createExpenditureReceipt.receipt.gasUsed;

      const postExpenditureBalance = await web3.eth.getBalance(firstAccount);

      assert.equal(
        postExpenditureBalance,
        new BN(preExpenditureBalance)
          .add(new BN(expenditureValueETH))
          .sub(new BN(createExpenditureTxCost))
          .toString(),
        "Contract owner should receive the ETH value of an expenditure"
      );
    });
  });

  describe("createExpendedDonation()", () => {
    it("reverts if the caller is not the contract owner", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 10000, 10000, {
        from: firstAccount,
        value: 0,
      });

      await catchRevert(
        instance.createExpendedDonation(secondAccount, 10000, 10050, 1, 1, {
          from: secondAccount,
          value: 0,
        })
      );
    });

    it("successfully creates an expended donation", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 10000, 10000, {
        from: firstAccount,
        value: 0,
      });

      await instance.createExpendedDonation(secondAccount, 10000, 10050, 1, 1, {
        from: firstAccount,
        value: 0,
      });
    });

    it("reverts if a donation with the provided donator address and donation number does not exist", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 10000, 10000, {
        from: firstAccount,
        value: 0,
      });

      await catchRevert(
        instance.createExpendedDonation(secondAccount, 10000, 10050, 2, 1, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("reverts if an expenditure with the provided expenditure number does not exist", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 10000, 10000, {
        from: firstAccount,
        value: 0,
      });

      await catchRevert(
        instance.createExpendedDonation(secondAccount, 10000, 10050, 1, 2, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("reverts if the value expended in ETH is not greater than 0", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 10000, 10000, {
        from: firstAccount,
        value: 0,
      });

      await catchRevert(
        instance.createExpendedDonation(secondAccount, 0, 10050, 1, 1, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("reverts if the value expended in USD is not greater than 0", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 10000, 10000, {
        from: firstAccount,
        value: 0,
      });

      await catchRevert(
        instance.createExpendedDonation(secondAccount, 10000, 0, 1, 1, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("reverts if the value of ETH to expend is greater than the initial donation -- if this is the first expended donation for the donation", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 30000, 10000, {
        from: firstAccount,
        value: 0,
      });

      await catchRevert(
        instance.createExpendedDonation(secondAccount, 40000, 100, 1, 1, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("reverts if the value of ETH to expend is greater than the initial expenditure -- if this is the first expended donation for the donation", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 20000, 10000, {
        from: firstAccount,
        value: 0,
      });

      await catchRevert(
        instance.createExpendedDonation(secondAccount, 30000, 100, 1, 1, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("reverts if the value of ETH to expend is greater than the initial value of the donation less any previous donation(s)", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 30000, 10000, {
        from: firstAccount,
        value: 0,
      });

      await instance.createExpendedDonation(secondAccount, 10000, 100, 1, 1, {
        from: firstAccount,
        value: 0,
      });

      await catchRevert(
        instance.createExpendedDonation(secondAccount, 30000, 100, 1, 1, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("reverts if the donation was fully refunded", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 30000, 10000, {
        from: firstAccount,
        value: 0,
      });

      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.refundDonation(secondAccount, 1, 30000, {
        from: firstAccount,
        value: 0,
      });

      await catchRevert(
        instance.createExpendedDonation(secondAccount, 30000, 100, 1, 1, {
          from: firstAccount,
          value: 0,
        })
      );
    });

    it("creates an expended donation that can be related to the donations mapping item", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 30000, 30000, {
        from: firstAccount,
        value: 0,
      });

      await instance.createExpendedDonation(secondAccount, 30000, 100, 1, 1, {
        from: firstAccount,
        value: 0,
      });

      const expdendedDonationIDForDonation = await instance.getExpendedDonationIDForDonation(
        secondAccount,
        1,
        1
      );

      assert.equal(
        expdendedDonationIDForDonation,
        1,
        "The ID of the expended donation should be added to the related item in the donations mapping when an expended donation is created"
      );
    });

    it("creates an expenditure that can be related to the donations mapping item", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 30000, 30000, {
        from: firstAccount,
        value: 0,
      });

      await instance.createExpendedDonation(secondAccount, 30000, 100, 1, 1, {
        from: firstAccount,
        value: 0,
      });

      const expdendedDonationIDForExpenditure = await instance.getExpendedDonationIDForExpenditure(
        1,
        1
      );

      assert.equal(
        expdendedDonationIDForExpenditure,
        1,
        "The ID of the expenditure should be added to the related item in the donations mapping when an expenditure is created"
      );
    });
  });

  describe("utility functions", () => {
    it("toAsciiString() converts an address to a string", async () => {
      const asciiString = await instance.toAsciiString(secondAccount, {
        from: firstAccount,
        value: 0,
      });

      assert.equal(
        asciiString,
        secondAccount.replace("0x", "").toLowerCase(),
        "An address should be converted into a string"
      );
    });

    it("concat() concatenates strings", async () => {
      const donationNumber = 1;

      const donationNumWithDash = await instance.concat(
        donationNumber.toString(),
        "-"
      );

      const donationTrackerString = await instance.concat(
        donationNumWithDash,
        firstAccount.toString()
      );

      assert.equal(
        donationTrackerString,
        `${donationNumber}-${firstAccount}`,
        "The concat() function should concatenate two strings"
      );
    });

    it("getTotalNumDonations() returns the total number of donations", async () => {
      const totalNumDonations = await instance.getTotalNumDonations();

      assert.equal(
        totalNumDonations,
        0,
        "The total number of donations should be 0 before any donations are made"
      );

      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      const totalNumDonations2 = await instance.getTotalNumDonations();

      assert.equal(
        totalNumDonations2,
        1,
        "The total number of donations should increase by 1 when a donation is made"
      );
    });

    it("getTotalNumExpenditures() returns the total number of expenditures", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      totalNumExpenditures = await instance.getTotalNumExpenditures();

      assert.equal(
        totalNumExpenditures,
        0,
        "The total number of donations should be 0 before any donations are made"
      );

      await instance.createExpenditure("abcd", "abcde", 30000, 30000, {
        from: firstAccount,
        value: 0,
      });

      const totalNumExpenditures2 = await instance.getTotalNumExpenditures();

      assert.equal(
        totalNumExpenditures2,
        1,
        "The total number of expenditures should increase by 1 when an expenditure is created"
      );
    });

    it("getTotalNumExpendedDonations() returns the total number of expended donations", async () => {
      await instance.donate({
        from: secondAccount,
        value: 30000,
      });

      await instance.createExpenditure("abcd", "abcde", 30000, 30000, {
        from: firstAccount,
        value: 0,
      });

      const totalNumExpendedDonations = await instance.getTotalNumExpendedDonations();

      assert.equal(
        totalNumExpendedDonations,
        0,
        "The total number of expended donations should be 0 before any expended donations are created"
      );

      await instance.createExpendedDonation(secondAccount, 30000, 10050, 1, 1, {
        from: firstAccount,
        value: 0,
      });

      const totalNumExpendedDonations2 = await instance.getTotalNumExpendedDonations();

      assert.equal(
        totalNumExpendedDonations2,
        1,
        "The total number of expended donations should increase by 1 when an expended donation is created"
      );
    });

    it("getContractBalance() returns the contract balance", async () => {
      const contractBalance = await instance.getContractBalance();

      assert.equal(
        contractBalance,
        0,
        "The contract balance should be 0 before any donations are made"
      );

      const donationAmount = 30000;

      await instance.donate({
        from: secondAccount,
        value: donationAmount,
      });

      const contractBalance2 = await instance.getContractBalance();

      assert.equal(
        contractBalance2,
        donationAmount,
        "The contract balance should be returned properly after a donation is made"
      );
    });

    it("isTextEmpty() returns a boolean value expressing whether a string is empty", async () => {
      const isTextEmpty = await instance.isTextEmpty("");

      assert.equal(
        isTextEmpty,
        true,
        "isTextEmpty() should return true for an empty string"
      );

      const isTextEmpty2 = await instance.isTextEmpty("abcd");

      assert.equal(
        isTextEmpty2,
        false,
        "isTextEmpty() should return false for a non-empty string"
      );
    });
  });
});
