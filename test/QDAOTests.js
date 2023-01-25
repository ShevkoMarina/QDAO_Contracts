const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("Governor", function () {
    
    async function deployTokensFixture() {
        const [owner, proposer, voter1, voter2, voter3] = await ethers.getSigners();

        const QDAOToken = await ethers.getContractFactory("QDAOToken");
        const token = await QDAOToken.deploy();
        console.log("QDAOToken deployed to address:", token.address);

        const QDAOTimelock = await ethers.getContractFactory("QDAOTimelock");
        const timelock = await QDAOTimelock.deploy(0, [owner.address], [owner.address], owner.address);
        console.log("QDAOTimelock deployed to address:", timelock.address);

        const QDAOGovernor = await ethers.getContractFactory("QDAOGovernor");
        const governor = await QDAOGovernor.deploy(token.address, timelock.address);
        console.log("QDAOGovernor deployed to address:", governor.address);

        return {token, governor, owner, proposer, voter1, voter2, voter3}
    }

    async function mineBlocksFixture() {
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");
    }

    it("Getting votes for account", async function () {

        
        //const {token, governor, owner, proposer, voter1, voter2, voter3} = 
        await loadFixture(deployTokensFixture);

        // Распределяем токены
       // await token.connect(owner).transfer(voter1.address, 20);
        
        //expect(await token.getCurrentVotes(voter1.address)).to.equal(20);
        //expect(await token.getCurrentVotes(owner.address)).to.equal(80);

        //await expect(token.connect(voter1).transferFrom(voter1.address, voter2.address, 10))
        //.to.be.revertedWith('ERC20: insufficient allowance');
    })
})