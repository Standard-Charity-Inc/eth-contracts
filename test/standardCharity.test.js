const StandardCharity = artifacts.require('StandardCharity');
const catchRevert = require('./exceptionsHelpers').catchRevert;
const BN = web3.utils.BN;

contract('StandardCharity', accounts => {
  const firstAccount = accounts[0];
  const secondAccount = accounts[1];

  let instance;

  beforeEach(async () => {
    instance = await StandardCharity.new();
  });

  describe('setup', () => {
    it('should the deploying address to be the owner of the contract', async () => {
      const owner = await instance.owner();

      assert.equal(owner, firstAccount, 'The deploying address should be the contract owner');
    });

    it('should set the nextDonationToExpend to 1', async () => {
      const nextDonationToExpend = await instance.nextDonationToExpend();

      assert.equal(nextDonationToExpend, 1, 'Initial nextDonationToExpend should be set to 1');
    });
  })
})