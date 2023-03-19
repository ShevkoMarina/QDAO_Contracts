const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { TASK_COMPILE_REMOVE_OBSOLETE_ARTIFACTS } = require("hardhat/builtin-tasks/task-names");

describe("Initial tests", function () {
    
    async function deployFixture() {

        const [owner, proposer, voter1, voter2, voter3] = await ethers.getSigners();
    
        const QDAOToken = await ethers.getContractFactory("QDAOToken");
        const token = await QDAOToken.deploy(owner.address);
        console.log("QDAOToken deployed to address:", token.address);

        const QDAOTimelock = await ethers.getContractFactory("QDAOTimelock");
        const timelock = await QDAOTimelock.deploy(owner.address, 2*24*60*60);
        console.log("QDAOTimelock deployed to address:", timelock.address);

        const QDAOGovernor = await ethers.getContractFactory("QDAOGovernor");
        const governor = await QDAOGovernor.deploy();
        console.log("QDAOGovernor deployed to address:", governor.address);

        const QDAOGovernorDelegator = await ethers.getContractFactory("QDAOGovernorDelegator");
        const delegator = await QDAOGovernorDelegator.deploy(timelock.address, token.address, owner.address, governor.address, 5);
        console.log("QDAOGovernorDelegator deployed to address:", delegator.address);

        return {token, delegator, governor, timelock, owner, proposer, voter1, voter2, voter3}
    }

    async function mineBlocksFixture() {
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");
    }

    it("Deploy contracts", async function () {

        await loadFixture(deployFixture);
    })
})


describe("Token tests", function () {

    async function deployFixture() {
        const [owner, voter1, voter2, voter3] = await ethers.getSigners();

        const QDAOToken = await ethers.getContractFactory("QDAOTokenV0");
        const token = await QDAOToken.deploy(owner.address);
        console.log("QDAOTokenV0 deployed to address:", token.address);


        return {token, owner, voter1, voter2, voter3};
    }

    it("Get total supply", async function () {

        const {token, owner, voter1, voter2, voter3} =
        await loadFixture(deployFixture);

        expect(await token.totalSupply()).to.equal(10000);
    });

    it("Distibute tokens", async function () {

        // Почему то возвращает 0 с чекпоинтами
        const {token, owner, voter1, voter2, voter3} =
        await loadFixture(deployFixture);

        await token.connect(owner).transfer(voter1.address, 20);
        await token.connect(owner).transfer(voter2.address, 31);

        expect(await token.getCurrentVotes(voter1.address)).to.equal(20);
        expect(await token.getCurrentVotes(voter2.address)).to.equal(31);
        expect(await token.getCurrentVotes(owner.address)).to.equal((await token.totalSupply())-51);
    });
})

describe("Governor:Proposal tests", function () {

    async function deployFixture() {
        // Надо еще либу задеплоить
        const [owner, proposer, voter1, voter2, voter3] = await ethers.getSigners();

        const QDAOToken = await ethers.getContractFactory("QDAOToken");
        const token = await QDAOToken.deploy(owner.address);
        console.log("QDAOToken deployed to address:", token.address);

        const QDAOTimelock = await ethers.getContractFactory("QDAOTimelock");
        const timelock = await QDAOTimelock.deploy(owner.address, 2*24*60*60);
        console.log("QDAOTimelock deployed to address:", timelock.address);

        const QDAOGovernor = await ethers.getContractFactory("QDAOGovernor");
        const governor = await QDAOGovernor.deploy();
        console.log("QDAOGovernor deployed to address:", governor.address);

        const QDAOGovernorDelegator = await ethers.getContractFactory("QDAOGovernorDelegator");
        const delegator = await QDAOGovernorDelegator.deploy(timelock.address, token.address, owner.address, governor.address, 5);
        console.log("QDAOGovernorDelegator deployed to address:", delegator.address);

        return {token, delegator, governor, timelock, owner, proposer, voter1, voter2, voter3}
    }

    it("Init governor", async function () {

        const {token, delegator, governor, timelock, owner, proposer, voter1, voter2, voter3} =
        await loadFixture(deployFixture);

        expect(await governor.votingPeriod()).to.equal(0);

        await governor.connect(owner).initialize(
            timelock.address,
            token.address,
            5);

        expect(await governor.votingPeriod()).to.equal(5);
    });

    it("Create proposal with valid params", async function () {
        const {token, delegator, governor, timelock, owner, proposer, voter1, voter2, voter3} =
        await loadFixture(deployFixture);

        await governor.connect(owner).initialize(
            timelock.address,
            token.address,
            5);

        // Распределяем токены
        await token.connect(owner).transfer(voter1.address, 20);
        await token.connect(owner).transfer(voter2.address, 31);
        await token.connect(owner).transfer(voter3.address, 8);
        await token.connect(owner).transfer(proposer.address, 1);

        // Создаем предложение
        const proposalCallData = governor.interface.encodeFunctionData("updateVotingPeriod", [2]);
        const targets = [governor.address];
        const values = [0];
        const proposalDesc = "Change voting period to 2";

        createdProposal = await governor.connect(proposer).createProposal(targets, values, [proposalCallData], proposalDesc);
        var createdProposalId =  await governor.proposalCount();

        expect(createdProposalId).to.equal(1);
        var proposal = await governor.proposals(createdProposalId);
        expect(proposal.id).to.equal(1);
       // expect(proposal.description).to.equal(proposalDesc);

        expect(await governor.getState(createdProposalId)).to.equal(ProposalState.Active);
        console.log(proposal)
        
       // expect(createdProposal).to.emit(governor, "ProposalCreated")
       //  .withArgs(1, proposer.address, targets, values, proposalCallData, await ethers.provider.getBlockNumber(), await ethers.provider.getBlockNumber() + await governor.getVotingPeriod(), proposalDesc)
    });

    async function mineBlocksFixture() {
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");
    }

    it("Crisis management no quorum", async function () {
        const {token, delegator, governor, timelock, owner, proposer, voter1, voter2, voter3} =
        await loadFixture(deployFixture);

        await governor.connect(owner).initialize(
            timelock.address,
            token.address,
            5);

         // Распределяем токены
         await token.connect(owner).transfer(voter1.address, 1);
         await token.connect(owner).transfer(voter2.address, 2);
         await token.connect(owner).transfer(voter3.address, 3);

         // Создаем предложение
         const proposalCallData = governor.interface.encodeFunctionData("updateVotingPeriod", [2]);
         const targets = [governor.address];
         const values = [0];
         const proposalDesc = "Change voting period to 2";
 
         createdProposal = await governor.connect(proposer).createProposal(targets, values, [proposalCallData], proposalDesc);
         var createdProposalId =  await governor.proposalCount();
         expect(createdProposalId).to.equal(1);

         // Создаем принципалов
         await governor.createMultisig([voter1.address, voter2.address], 2);

         await loadFixture(mineBlocksFixture);

         expect(await governor.getState(createdProposalId)).to.equal(ProposalState.NoQuorum);

         await governor.connect(voter1).approve(1);
         await governor.connect(voter2).approve(1);


         var admin = await timelock.admin();
         console.log(admin);
         console.log(owner.address);

         // Пытаемся поставить в очередь
         await governor.connect(owner).queue(1);

         expect(await governor.getState(1)).to.equal(ProposalState.Queued);

    });
});

const ProposalState  = {
    Active: 0,
    Canceled: 1,
    Defeated: 2,
    NoQuorum: 3,
    Succeeded: 4,
    Queued: 5,
    Expired: 6,
    Executed: 7
};
