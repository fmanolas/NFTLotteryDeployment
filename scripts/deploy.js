require('dotenv').config();
const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
    // Load seriesA and seriesB data from JSON files
    const seriesAData = JSON.parse(fs.readFileSync("seriesA.json"));
    const seriesBData = JSON.parse(fs.readFileSync("seriesB.json"));

    const seriesANFTs = seriesAData.map(nft => ({ id: nft.ID, rarityScore: nft.SCRS, series: "A" }));
    const seriesBNFTs = seriesBData.map(nft => ({ id: nft.ID, rarityScore: nft.SCRS, series: "B" }));

    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Deploy NFTLotteryStorage contract
    const NFTLotteryStorage = await ethers.getContractFactory("NFTLotteryStorage");
    const nftLotteryStorage = await NFTLotteryStorage.deploy(process.env.BIA_TOKEN_ADDRESS, process.env.NFT_CONTRACT_ADDRESS);
    await nftLotteryStorage.waitForDeployment();
    console.log("NFTLotteryStorage deployed to:", await nftLotteryStorage.getAddress());

    // Deploy NFTLottery contract
    const NFTLottery = await ethers.getContractFactory("NFTLottery");
    const nftLottery = await NFTLottery.deploy(await nftLotteryStorage.getAddress());
    await nftLottery.waitForDeployment();
    console.log("NFTLottery deployed to:", await nftLottery.getAddress());

    // Set the authorized caller for the storage contract
    await nftLotteryStorage.setAuthorizedCaller(await nftLottery.getAddress());

    // Function to initialize NFTs in batches
    async function initializeNFTs(nfts, series) {
        const batchSize = 50; // Adjust this value as needed
        for (let i = 0; i < nfts.length; i += batchSize) {
            const batch = nfts.slice(i, i + batchSize);
            await nftLottery.initialize(batch, series);
        }
    }

    // Initialize NFTs from series A and B in batches
    await initializeNFTs(seriesANFTs, "A");
    await initializeNFTs(seriesBNFTs, "B");

    console.log("NFTLottery initialized with NFTs from series A and B");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
