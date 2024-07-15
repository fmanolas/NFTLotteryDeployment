const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTLottery", function () {
    let NFTLottery, nftLottery, biaToken, nftContract;
    let owner, addr1, addr2;
    const seriesANFTs = [
        { id: 0, rarityScore: 10000, series: "A" },
        { id: 1, rarityScore: 10500, series: "A" },
        // Add more entries if needed...
    ];
    const seriesBNFTs = [
        { id: 3840, rarityScore: 11000, series: "B" },
        { id: 3841, rarityScore: 11500, series: "B" },
        // Add more entries if needed...
    ];

    beforeEach(async function () {
        [owner, addr1, addr2, _] = await ethers.getSigners();
        
        // Mock BIA token contract
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        biaToken = await MockERC20.deploy();
        await biaToken.waitForDeployment();

        // Mock NFT contract
        const MockERC721 = await ethers.getContractFactory("MockERC721");
        nftContract = await MockERC721.deploy();
        await nftContract.waitForDeployment();

        // Deploy NFTLottery contract
        NFTLottery = await ethers.getContractFactory("NFTLottery");
        nftLottery = await NFTLottery.deploy(
            await biaToken.getAddress(),
            await nftContract.getAddress(),
            seriesANFTs,
            seriesBNFTs
        );
        await nftLottery.waitForDeployment();
    });

    describe("Initialization", function () {
        it("Should initialize with correct parameters", async function () {
            expect(await nftLottery.contractOwner()).to.equal(await owner.getAddress());
            expect(await nftLottery.totalDraws()).to.equal(0);
            expect(await nftLottery.currentBiaJackpot()).to.equal(0);
            expect(await nftLottery.currentEthJackpot()).to.equal(0);
        });
    });

    describe("Funds Injection", function () {
        it("Should inject BIA funds correctly", async function () {
            await biaToken.approve(await nftLottery.getAddress(), 1000);
            await nftLottery.injectBIAFunds(1000);
            expect(await nftLottery.totalBiaFunds()).to.equal(1000);
        });

        it("Should inject ETH funds correctly", async function () {
            await nftLottery.injectETHFunds({ value: ethers.parseEther("1.0") });
            expect(await nftLottery.totalEthFunds()).to.equal(ethers.parseEther("1.0"));
        });
    });
});
