require('dotenv').config();
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Interacting with the contracts using account:", await deployer.getAddress());

    // Load the contracts
    const NFTLotteryStorageAddress = "0x5F0654eF982FC5b6745BAD5591a72a80A0E799f3";
    const NFTLotteryAddress = "0x631437F1d7699A39588D89E4B062Af1cAE5acCF0";
    const NFTContractAddress = "0xE63198b621EC3628d9a320944355D74E0De81E63";  // Replace with your NFT contract address

    const NFTLotteryStorage = await ethers.getContractAt("NFTLotteryStorage", NFTLotteryStorageAddress);
    const NFTLottery = await ethers.getContractAt("NFTLottery", NFTLotteryAddress);
    const NFTContract = await ethers.getContractAt("IERC721", NFTContractAddress);  // Assuming the NFT contract follows the ERC721 standard
    await NFTLotteryStorage.setAuthorizedCaller(await NFTLottery.getAddress());
    const BiaToken = await ethers.getContractAt("IERC20", process.env.BIA_TOKEN_ADDRESS);  // Assuming the BIA token follows the ERC20 standard

    // Check BIA token balance of the contract
    const biaTokenBalance = await BiaToken.balanceOf(NFTLotteryStorageAddress);
    console.log("BIA Token Balance in contract:", ethers.formatUnits(biaTokenBalance, 18));

    // Example interaction: Get contract owner
    const owner = await NFTLotteryStorage.contractOwner();
    console.log("Contract owner:", owner);

    // Example interaction: Get current BIA jackpot
    // Check if a draw is already in progress
    // const targetBlock = await NFTLotteryStorage.targetBlock();
    // const finalizeBlock = await NFTLotteryStorage.finalizeBlock();

    // console.log("Target Block:", targetBlock.toString());
    // console.log("Finalize Block:", finalizeBlock.toString());

    // if (targetBlock.toString()=="0" && finalizeBlock.toString()=="0") {
    //     // Example interaction: Initialize a draw
    //     try {
    //         const initializeTx = await NFTLottery.initializeDraw();
    //         await initializeTx.wait();
    //         console.log("Draw initialized.");
    //     } catch (error) {
    //         console.error("Error initializing draw:", error);
    //     }
    // } else {
    //     console.log("A draw is already in progress.");
    // }

    // // Wait for the target block to finalize the draw
    // try {
    //     let currentBlock = await ethers.provider.getBlockNumber();
    //     while (currentBlock.toString() < targetBlock.toString()) {
    //         console.log(`Current Block: ${currentBlock}, waiting for Target Block: ${targetBlock}...`);
    //         await new Promise(resolve => setTimeout(resolve, 10000));
    //         currentBlock = await ethers.provider.getBlockNumber();
    //     }

    //     // Finalize the draw
    //     const finalizeTx = await NFTLottery.finalizeDraw();
    //     await finalizeTx.wait();
    //     console.log("Draw finalized.");
    // } catch (error) {
    //     console.error("Error finalizing draw:", error);
    // }

    // // Wait for the finalize block to select eligible NFTs
    // try {
    //     console.log(finalizeBlock);
    //     let currentBlock = await ethers.provider.getBlockNumber();
    //     while (currentBlock.toString() < finalizeBlock.toString()) {
    //         console.log(`Current Block: ${currentBlock}, waiting for Finalize Block: ${finalizeBlock}...`);
    //         await new Promise(resolve => setTimeout(resolve, 10000));
    //         currentBlock = await ethers.provider.getBlockNumber();
    //     }

    //     // Select eligible NFTs
    //     const selectEligibleTx = await NFTLottery.selectEligibleNFTs(0, 10); // Process first 10 NFTs
    //     await selectEligibleTx.wait();
    //     console.log("Eligible NFTs selected.");
    // } catch (error) {
    //     console.error("Error selecting eligible NFTs:", error);
    // }

    // // Log the eligible NFTs count
    // try {
    //     const eligibleNFTCount = await NFTLottery.eligibleCount();
    //     console.log("Eligible NFTs count:", eligibleNFTCount.toString());
    // } catch (error) {
    //     console.error("Error retrieving eligible NFTs:", error);
    // }

    // // Select winners
    // try {
    //     const selectWinnersTx = await NFTLottery.selectWinners();
    //     await selectWinnersTx.wait();
    //     console.log("Winners selected.");
    // } catch (error) {
    //     console.error("Error selecting winners:", error);
    // }

    // // Example interaction: Get winning NFTs
    // try {
    //     const drawWinnerEventFilter = NFTLottery.filters.DrawWinner();
    //     const events = await NFTLottery.queryFilter(drawWinnerEventFilter);

    //     const winningNFTs = events.map(event => event.args.winningNFTs);
    //     console.log("Winning NFTs:", winningNFTs);
    // } catch (error) {
    //     console.error("Error retrieving or processing winning NFTs:", error);
    // }

    // // Example interaction: Get total draws
    // try {
    //     const totalDraws = await NFTLotteryStorage.totalDraws();
    //     console.log("Total Draws:", totalDraws.toString());
    // } catch (error) {
    //     console.error("Error getting total draws:", error);
    // }

    // const amountToInject = ethers.parseUnits("1000000", 18); // Adjust the amount based on your needs

    // // Approve the NFTLottery contract to spend the BIA tokens
    // const approveTx = await BiaToken.approve(NFTLotteryAddress, amountToInject);
    // await approveTx.wait();
    // console.log("BIA token allowance approved.");

    // // Inject BIA funds into the NFTLottery contract
    // const injectTx = await NFTLottery.injectBIAFunds(amountToInject);
    // await injectTx.wait();

    try {
        const currentBiaJackpot = await NFTLotteryStorage.currentBiaJackpot();
        console.log("Current BIA Jackpot:", ethers.parseUnits(currentBiaJackpot.toString(), 18));
    } catch (error) {
        console.error("Error getting current BIA jackpot:", error);
    }

    // Example interaction: Get current ETH jackpot
    try {
        const currentEthJackpot = await NFTLotteryStorage.currentEthJackpot();
        console.log("Current ETH Jackpot:", currentEthJackpot.toString());
    } catch (error) {
        console.error("Error getting current ETH jackpot:", error);
    }

    // Example interaction: Get pending withdrawals
    try {
        const biaPendingWithdrawals = await NFTLotteryStorage.biaPendingWithdrawals("0x49A1c5562FBe1E6cA689Af75d429Bc2dCacbb223");
        console.log("BIA Pending Withdrawals for deployer:", ethers.formatUnits(biaPendingWithdrawals, 18));

        const ethPendingWithdrawals = await NFTLotteryStorage.ethPendingWithdrawals("0x49A1c5562FBe1E6cA689Af75d429Bc2dCacbb223");
        console.log("ETH Pending Withdrawals for deployer:", ethers.formatUnits(ethPendingWithdrawals, 18));

        // Check if the contract has enough balance to cover the pending withdrawals
        if (biaTokenBalance<biaPendingWithdrawals) {
            console.error("Contract does not have enough BIA tokens to cover the pending withdrawals.");
            return;
        }
    } catch (error) {
        console.error("Error getting pending withdrawals:", error);
    }

    // Interact with the claimFunds function on behalf of the NFT owner
    try {
        const nftId = 2; // Replace with a specific NFT ID you want to claim funds for

        // Get the owner of the specified NFT
        const nftOwner = await NFTContract.ownerOf(nftId);
        console.log(`Owner of NFT ID ${nftId}:`, nftOwner);

        // Connect to the contract as the NFT owner
        const nftOwnerSigner = await ethers.provider.getSigner(nftOwner);
        const NFTLotteryAsOwner = NFTLottery.connect(nftOwnerSigner);

        // Claim funds for the NFT
        const claimFundsTx = await NFTLotteryAsOwner.claimFunds(nftId);
        await claimFundsTx.wait();
        console.log(`Funds claimed for NFT ID: ${nftId}`);
    } catch (error) {
        console.error("Error claiming funds:", error);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
