const { ethers } = require("hardhat");
const fs = require("fs");
require("dotenv").config(); // Add this line

async function main() {
    const seriesAData = JSON.parse(fs.readFileSync("seriesA.json"));
    const seriesBData = JSON.parse(fs.readFileSync("seriesB.json"));

    const seriesANFTs = seriesAData.map(nft => ({ id: nft.id, rarityScore: nft.SCRS, series: "A" }));
    const seriesBNFTs = seriesBData.map(nft => ({ id: nft.id, rarityScore: nft.SCRS, series: "B" }));

    const NFTLottery = await ethers.getContractFactory("NFTLottery");


    const nftLottery = await NFTLottery.deploy(
        process.env.BIA_TOKEN_ADDRESS,
        process.env.NFT_CONTRACT_ADDRESS,
        seriesANFTs,
        seriesBNFTs
    );

    await nftLottery.waitForDeployment();

    console.log("NFTLottery deployed to:", await nftLottery.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
