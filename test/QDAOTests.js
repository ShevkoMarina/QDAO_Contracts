const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { TASK_COMPILE_REMOVE_OBSOLETE_ARTIFACTS } = require("hardhat/builtin-tasks/task-names");

async function deployFixture() {

    const [admin, proposer, voter1, voter2, voter3, signer1, signer2, signer3] = await ethers.getSigners();

    const QDAOToken = await ethers.getContractFactory("QDAOToken");
    const token = await QDAOToken.connect(admin).deploy(10000, "QDAOToken", "QDAO");
  //  console.log("QDAOToken deployed to address:", token.address);

    const QDAOTimelock = await ethers.getContractFactory("QDAOTimelock");
    const timelock = await QDAOTimelock.connect(admin).deploy(admin.address, 2*24*60*60); // 172800
   // console.log("QDAOTimelock deployed to address:", timelock.address);

    const QDAOGovernor = await ethers.getContractFactory("QDAOGovernor");
    const governor = await QDAOGovernor.connect(admin).deploy();
  //  console.log("QDAOGovernor deployed to address:", governor.address);

    const QDAOMultisig = await ethers.getContractFactory("QDAOMultisig");
    const multisig = await QDAOMultisig.connect(admin).deploy();

    const QDAOGovernorDelegator = await ethers.getContractFactory("QDAOGovernorDelegator");
    const delegator = await QDAOGovernorDelegator.connect(admin)
    .deploy(timelock.address, token.address, multisig.address, governor.address, 6, 5, 0);
  //  console.log("QDAOGovernorDelegator deployed to address:", delegator.address);

    return {token, delegator, governor, timelock, admin,  multisig}
}

async function mineNBlocks(n) {
    for (let index = 0; index < n; index++) {
      await ethers.provider.send('evm_mine');
    }
  }

async function send(sender, to_address, contract, method, params) {

    var result = sender.sendTransaction(
        {
          to: to_address,
          data: contract.interface.encodeFunctionData(method, params)
        });
    
    return result;
}

describe("Initial tests", function () {
    
  
    it("Deploy contracts", async function () {

        const {token, delegator, governor, timelock, admin} = await deployFixture();

        console.log("Admin address: ", await delegator.admin())
        expect(await delegator.admin()).to.equal(admin.address)
        expect(await delegator.implementation()).to.equal(governor.address);
    })

    it("Governor initialize only once", async function () {

        var {token, delegator, governor, timelock, admin,  multisig} = await deployFixture();
        var [admin, proposer, voter1, voter2, voter3, signer1, signer2, signer3] = await ethers.getSigners();

        var result = send(admin , delegator.address, governor, "initialize", 
        [timelock.address, token.address, multisig.address, 5, 6, 0]);
        
        await expect(result).to.be.revertedWith('QDAOGovernor::initialize: can be only be initialized once');

    })
    
    it("Create proposal with valid params", async function ()  {

        var {token, delegator, governor, timelock, admin, multisig} = await deployFixture();
        var [admin, proposer, voter1, voter2, voter3, signer1, signer2, signer3] = await ethers.getSigners();

        var targets = [governor.address]
        var values = [0]
        var calldata = governor.interface.encodeFunctionData('updateVotingPeriod', [7])
        var calldatas = [calldata]

        var currentBlock = await ethers.provider.getBlockNumber();

        var result = await send(admin, multisig.address, multisig, 'addPrincipal', [signer1.address, 1]);
        var result = await send(admin, multisig.address, multisig, 'addPrincipal', [signer2.address, 2]);

        var result = await send(proposer , delegator.address, governor, "createProposal", [targets, values, calldatas]);

        await expect(result).to.emit(delegator, "ProposalCreated")
        .withArgs(1, proposer.address, targets, values, calldatas,
            currentBlock + 3, 
            currentBlock + 9)
    })


    
    it("Distribute tokens between voters", async function ()  {

        var {token, delegator, governor, timelock, admin} = await deployFixture();
        var [admin, proposer, voter1, voter2, voter3] = await ethers.getSigners();
        
        await token.connect(admin).transfer(voter1.address, 20);
        await token.connect(admin).transfer(voter2.address, 31);

        expect(await token.balanceOf(voter1.address)).to.equal(20);
        expect(await token.balanceOf(voter2.address)).to.equal(31);
        expect(await token.balanceOf(admin.address)).to.equal((await token.totalSupply())-51);
    })

    it("Token: numcheckpoints returns the number of a delegate", async function ()  {

      var {token, delegator, governor, timelock, admin} = await deployFixture();
      var [admin, proposer, voter1, voter2, voter3] = await ethers.getSigners();
      
      var result = await token.connect(admin).transfer(voter1.address, 100);

      // voter1 delegates his votes to voter2
      const t1 = await token.connect(voter1).delegate(voter2.address);
      expect(await token.numCheckpoints(voter2.address)).to.equal(1)

      // voter 2 now have 20 votes
      expect(await token.getCurrentVotes(voter2.address)).to.equal(100)
      expect(await token.balanceOf(voter2.address)).to.equal(0)

      // voter 1 have no votes
      expect(await token.getCurrentVotes(voter1.address)).to.equal(0)
      expect(await token.balanceOf(voter1.address)).to.equal(100)

      // voter 1 transfer 10 tokens to voter 3
      const t2 = await token.connect(voter1).transfer(voter3.address, 10);
      expect(await token.numCheckpoints(voter2.address)).to.equal(2)
      expect(await token.balanceOf(voter1.address)).to.equal(90)
      expect(await token.getCurrentVotes(voter2.address)).to.equal(90)

      // voter 1 transfer more 10 tokens to voter 3
      const t3 = await token.connect(voter1).transfer(voter3.address, 10);
      expect(await token.numCheckpoints(voter2.address)).to.equal(3)

      // admin transfer 20 tokens to voter 1
      const t4 = await token.connect(admin).transfer(voter1.address, 20);
      expect(await token.numCheckpoints(voter2.address)).to.equal(4)

      var result = await token.checkpoints(voter2.address, 0)
      expect(result.fromBlock).to.equal(t1.blockNumber)
      expect(result.votes).to.equal(100)

      var result = await token.checkpoints(voter2.address, 1)
      expect(result.fromBlock).to.equal(t2.blockNumber)
      expect(result.votes).to.equal(90)

      console.log(await token.getPastVotes(voter2.address, t2.blockNumber))
    })


    it("Token: distribute tokens", async function ()  {

      var {token, delegator, governor, timelock, admin} = await deployFixture();
      var [admin, proposer, voter1, voter2, voter3] = await ethers.getSigners();
      
      await token.connect(admin).transfer(voter1.address, 20);
      await token.connect(admin).transfer(voter2.address, 30);
      await token.connect(admin).transfer(voter3.address, 1);
      
      await token.connect(voter1).delegate(voter1.address);
      expect(await token.getCurrentVotes(voter1.address)).to.equal(20)

      await token.connect(voter2).delegate(voter3.address);
      await token.connect(voter3).delegate(voter3.address);
      expect(await token.getCurrentVotes(voter2.address)).to.equal(0)
      expect(await token.getCurrentVotes(voter3.address)).to.equal(31)
    })
   
    
    it ("Delagator: Vote for proposal succeed state", async function () {

        var {token, delegator, governor, timelock, admin, multisig} = await deployFixture();
        var [admin, proposer, voter1, voter2, voter3, signer1, signer2, signer3] = await ethers.getSigners();

        await token.connect(admin).transfer(voter1.address, 200);
        await token.connect(voter1).delegate(voter1.address);
        await token.connect(admin).transfer(voter2.address, 310);
        await token.connect(voter2).delegate(voter2.address);

        var targets = [governor.address]
        var values = [0]
        var calldata = governor.interface.encodeFunctionData('updateVotingPeriod', [7])
        var calldatas = [calldata]

        var result = await send(admin, multisig.address, multisig, 'addPrincipal', [signer1.address, 1]);
        var result = await send(admin, multisig.address, multisig, 'addPrincipal', [signer2.address, 2]);

        var startBlock = await ethers.provider.getBlockNumber();
        await send(proposer , delegator.address, governor, "createProposal", [targets, values, calldatas])

        await send(voter1, delegator.address, governor, 'vote', [1, true])
        await send(voter2, delegator.address, governor, 'vote', [1, true])

        await mineNBlocks(6);
        await expect(startBlock + 6, await ethers.provider.getBlockNumber())

        await timelock.connect(admin).setDelegator(delegator.address);

        var result = send(admin, delegator.address, governor, 'queueProposal', [1])
        await expect(result).to.emit(timelock, "QueueTransaction")
        await expect(result).to.emit(delegator, 'ProposalQueued');
    })

    it ("Delagator: Vote for proposal to no quorum state with signers approve", async function () {

        var {token, delegator, governor, timelock, admin, multisig} = await deployFixture();
        await timelock.connect(admin).setDelegator(delegator.address);
        var [admin, proposer, voter1, voter2, voter3, signer1, signer2, signer3] = await ethers.getSigners();

        var result = await send(admin, multisig.address, multisig, 'addPrincipal', [signer1.address, 1]);
        var result = await send(admin, multisig.address, multisig, 'addPrincipal', [signer2.address, 2]);
        var result = await send(admin, multisig.address, multisig, 'addPrincipal', [signer3.address, 2]);

        var targets = [governor.address]
        var values = [0]
        var calldata = governor.interface.encodeFunctionData('updateVotingPeriod', [7])
        var calldatas = [calldata]

        var startBlock = await ethers.provider.getBlockNumber();

        await token.connect(admin).transfer(voter1.address, 1);
        await token.connect(voter1).delegate(voter1.address);
        await token.connect(admin).transfer(voter2.address, 1);
        await token.connect(voter2).delegate(voter2.address);

        await send(proposer , delegator.address, governor, "createProposal", [targets, values, calldatas])

        await send(voter1, delegator.address, governor, 'vote', [1, true])
        await send(voter2, delegator.address, governor, 'vote', [1, true])

        await mineNBlocks(6);
        expect(startBlock + 6, await ethers.provider.getBlockNumber())

        var result = send(admin, delegator.address, governor, 'queueProposal', [1])
        await expect(result).to.be.revertedWith('QDAOGovernor::queue: proposal must have Succeded state');

        var result = send(signer1, delegator.address, governor, 'approve', [1]); 
        await expect(result).to.emit(delegator, 'ProposalApproved').withArgs(signer1.address, 1)

        var result = send(admin, delegator.address, governor, 'queueProposal', [1])
        await expect(result).to.be.revertedWith('QDAOGovernor::queue: proposal must have Succeded state');
    
        var result = await send(signer2, delegator.address, governor, 'approve', [1]); 
        await expect(result).to.emit(delegator, 'ProposalApproved').withArgs(signer2.address, 1)

        var result = await send(admin, delegator.address, governor, 'queueProposal', [1])
        await expect(result).to.emit(delegator, 'ProposalQueued');
    })

    it ("Delagator: Execute queued proposal", async function () {

        var {token, delegator, governor, timelock, admin, multisig} = await deployFixture();
        await timelock.connect(admin).setDelegator(delegator.address);
        var [admin, proposer, voter1, voter2, voter3, signer1, signer2, signer3] = await ethers.getSigners();

        var targets = [delegator.address]
        var values = [0]
        var calldata = governor.interface.encodeFunctionData('updateVotingPeriod', [7])
        var calldatas = [calldata]

        var result = await send(admin, multisig.address, multisig, 'addPrincipal', [signer1.address, 1]);
        var result = await send(admin, multisig.address, multisig, 'addPrincipal', [signer2.address, 2]);
        var result = await send(admin, multisig.address, multisig, 'addPrincipal', [signer3.address, 2]);

        await token.connect(admin).transfer(voter1.address, 300);
        await token.connect(voter1).delegate(voter1.address);
        await token.connect(admin).transfer(voter2.address, 400);
        await token.connect(voter2).delegate(voter2.address);

        var startBlock = await ethers.provider.getBlockNumber();
        await send(proposer , delegator.address, governor, "createProposal", [targets, values, calldatas])
        await send(voter1, delegator.address, governor, 'vote', [1, true])
        await send(voter2, delegator.address, governor, 'vote', [1, true])

        await mineNBlocks(6);
        expect(startBlock + 6, await ethers.provider.getBlockNumber())

        var result = send(admin, delegator.address, governor, 'queueProposal', [1])
        await expect(result).to.emit(delegator, 'ProposalQueued')

        var result = send(admin, delegator.address, governor, 'executeProposal', [1])
        await expect(result).to.be.revertedWith("QDAOTimelock::executeTransaction: Transaction hasn't surpassed time lock.");
        
        await ethers.provider.send("evm_increaseTime", [2*24*60*60])

        var result = send(admin, delegator.address, governor, 'executeProposal', [1])
        await expect(result).to.emit(delegator, 'ProposalExecuted')
        .withArgs(1);
    })
    
})