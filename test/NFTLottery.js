const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTLottery", function () {
    let NFTLottery, nftLottery, NFTLotteryStorage, nftLotteryStorage, biaToken, nftContract;
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

        // Deploy NFTLotteryStorage contract
        NFTLotteryStorage = await ethers.getContractFactory("NFTLotteryStorage");
        nftLotteryStorage = await NFTLotteryStorage.deploy(await biaToken.getAddress(), await nftContract.getAddress());
        await nftLotteryStorage.waitForDeployment();

        // Deploy NFTLottery contract
        NFTLottery = await ethers.getContractFactory("NFTLottery");
        nftLottery = await NFTLottery.deploy(await nftLotteryStorage.getAddress());
        await nftLottery.waitForDeployment();

        // Set authorized caller
        await nftLotteryStorage.setAuthorizedCaller(await nftLottery.getAddress());

        // Initialize NFTLottery with series A and B NFTs
        await initializeNFTs(seriesANFTs, "A");
        await initializeNFTs(seriesBNFTs, "B");
    });

    async function initializeNFTs(nfts, series) {
        const batchSize = 50; // Adjust this value as needed
        for (let i = 0; i < nfts.length; i += batchSize) {
            const batch = nfts.slice(i, i + batchSize);
            await nftLottery.initialize(batch, series);
        }
    }

    describe("Initialization", function () {
        it("Should initialize with correct parameters", async function () {
            expect(await nftLotteryStorage.contractOwner()).to.equal(await owner.getAddress());
            expect(await nftLotteryStorage.totalDraws()).to.equal(0);
            expect(await nftLotteryStorage.currentBiaJackpot()).to.equal(0);
            expect(await nftLotteryStorage.currentEthJackpot()).to.equal(0);
        });
    });

    describe("Funds Injection", function () {
        it("Should inject BIA funds correctly", async function () {
            await biaToken.approve(await nftLottery.getAddress(), 1000);
            await nftLottery.injectBIAFunds(1000);
            expect(await nftLotteryStorage.totalBiaFunds()).to.equal(1000);
        });

        it("Should inject ETH funds correctly", async function () {
            await nftLottery.injectETHFunds({ value: ethers.parseEther("1.0") });
            expect(await nftLotteryStorage.totalEthFunds()).to.equal(ethers.parseEther("1.0"));
        });
    });
});
