const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { TASK_COMPILE_REMOVE_OBSOLETE_ARTIFACTS } = require("hardhat/builtin-tasks/task-names");

async function deployFixture() {

    const [admin, proposer, voter1, voter2, voter3, signer1, signer2, signer3] = await ethers.getSigners();

    const QDAOToken = await ethers.getContractFactory("QDAOTokenV0");
    const token = await QDAOToken.connect(admin).deploy(admin.address);
  //  console.log("QDAOToken deployed to address:", token.address);

    const QDAOTimelock = await ethers.getContractFactory("QDAOTimelock");
    const timelock = await QDAOTimelock.connect(admin).deploy(admin.address, 2*24*60*60);
   // console.log("QDAOTimelock deployed to address:", timelock.address);

    const QDAOGovernor = await ethers.getContractFactory("QDAOGovernor");
    const governor = await QDAOGovernor.connect(admin).deploy();
  //  console.log("QDAOGovernor deployed to address:", governor.address);

    const QDAOGovernorDelegator = await ethers.getContractFactory("QDAOGovernorDelegator");
    const delegator = await QDAOGovernorDelegator.connect(admin)
    .deploy(timelock.address, token.address, admin.address, governor.address, 6, 5, [signer1.address, signer2.address, signer3.address], 2);
  //  console.log("QDAOGovernorDelegator deployed to address:", delegator.address);

    return {token, delegator, governor, timelock, admin}
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

        var {token, delegator, governor, timelock, admin} = await deployFixture();
        var [admin, proposer, voter1, voter2, voter3, signer1, signer2, signer3] = await ethers.getSigners();

        var result = send(admin , delegator.address, governor, "initialize", 
        [timelock.address, token.address, 5, 6, [signer1.address, signer2.address, signer3.address], 2]);
        
        await expect(result).to.be.revertedWith('QDAOGovernor::initialize: can be only be initialized once');

    })
    
    it("Create proposal with valid params", async function ()  {

        var {token, delegator, governor, timelock, admin} = await deployFixture();
        var [admin, proposer] = await ethers.getSigners();

        var targets = [governor.address]
        var values = [0]
        var calldata = governor.interface.encodeFunctionData('updateVotingPeriod', [7])
        var calldatas = [calldata]

        var currentBlock = await ethers.provider.getBlockNumber();

        var result = send(proposer , delegator.address, governor, "createProposal", [targets, values, calldatas]);

        await expect(result).to.emit(delegator, "ProposalCreated")
        .withArgs(1, proposer.address, targets, values, calldatas,
            currentBlock + 1, // понять как исправить эту фигню с блоками
            currentBlock + 7)
    })


    it("Distribute tokens between voters", async function ()  {

        var {token, delegator, governor, timelock, admin} = await deployFixture();
        var [admin, proposer, voter1, voter2, voter3] = await ethers.getSigners();
        
        await token.connect(admin).transfer(voter1.address, 20);
        await token.connect(admin).transfer(voter2.address, 31);

        expect(await token.getCurrentVotes(voter1.address)).to.equal(20);
        expect(await token.getCurrentVotes(voter2.address)).to.equal(31);
        expect(await token.getCurrentVotes(admin.address)).to.equal((await token.totalSupply())-51);
    })

    it ("Delagator: Vote for proposal succeed state", async function () {

        var {token, delegator, governor, timelock, admin} = await deployFixture();
        var [admin, proposer, voter1, voter2, voter3] = await ethers.getSigners();

        var targets = [governor.address]
        var values = [0]
        var calldata = governor.interface.encodeFunctionData('updateVotingPeriod', [7])
        var calldatas = [calldata]

        var startBlock = await ethers.provider.getBlockNumber();
        await send(proposer , delegator.address, governor, "createProposal", [targets, values, calldatas])

        await token.connect(admin).transfer(voter1.address, 200);
        await token.connect(admin).transfer(voter2.address, 310);

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

        var {token, delegator, governor, timelock, admin} = await deployFixture();
        await timelock.connect(admin).setDelegator(delegator.address);
        var [admin, proposer, voter1, voter2, voter3, signer1, signer2, signer3] = await ethers.getSigners();

        var targets = [governor.address]
        var values = [0]
        var calldata = governor.interface.encodeFunctionData('updateVotingPeriod', [7])
        var calldatas = [calldata]

        var startBlock = await ethers.provider.getBlockNumber();
        await send(proposer , delegator.address, governor, "createProposal", [targets, values, calldatas])

        await token.connect(admin).transfer(voter1.address, 1);
        await token.connect(admin).transfer(voter2.address, 1);

        await send(voter1, delegator.address, governor, 'vote', [1, true])
        await send(voter2, delegator.address, governor, 'vote', [1, true])

        await mineNBlocks(6);
        expect(startBlock + 6, await ethers.provider.getBlockNumber())

        var result = send(admin, delegator.address, governor, 'queueProposal', [1])
        await expect(result).to.be.revertedWith('QDAOGovernor::queue: proposal must have Succeded state');

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

        var {token, delegator, governor, timelock, admin} = await deployFixture();
        await timelock.connect(admin).setDelegator(delegator.address);
        var [admin, proposer, voter1, voter2, voter3, signer1, signer2, signer3] = await ethers.getSigners();

        var targets = [delegator.address]
        var values = [0]
        var calldata = governor.interface.encodeFunctionData('updateVotingPeriod', [7])
        var calldatas = [calldata]

        var startBlock = await ethers.provider.getBlockNumber();
        await send(proposer , delegator.address, governor, "createProposal", [targets, values, calldatas])

        await token.connect(admin).transfer(voter1.address, 300);
        await token.connect(admin).transfer(voter2.address, 400);

        await send(voter1, delegator.address, governor, 'vote', [1, true])
        await send(voter2, delegator.address, governor, 'vote', [1, true])

        await mineNBlocks(6);
        expect(startBlock + 6, await ethers.provider.getBlockNumber())

        var result = send(admin, delegator.address, governor, 'queueProposal', [1])
        await expect(result).to.emit(delegator, 'ProposalQueued')

        var result = send(admin, delegator.address, governor, 'executeProposal', [1])
        await expect(result).to.be.revertedWith("QDAOTimelock::executeTransaction: Transaction hasn't surpassed time lock.");
        
        await ethers.provider.send("evm_increaseTime", [2*24*60*60])

        console.log("bryre", await timelock.contractAddress())

        var result = send(admin, delegator.address, governor, 'executeProposal', [1])
        await expect(result).to.emit(delegator, 'ProposalExecuted')
        .withArgs(1);
    })
})