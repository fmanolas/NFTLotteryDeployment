require('dotenv').config();
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Interacting with the contracts using account:",await deployer.getAddress());

    // Load the contracts
    const NFTLotteryStorageAddress = "0x5F0654eF982FC5b6745BAD5591a72a80A0E799f3";
    const NFTLotteryAddress = "0x8Bb2fF6f4615e504CAB3168D4d6E3e6897Aa76A5";

    const NFTLotteryStorage = await ethers.getContractAt("NFTLotteryStorage", NFTLotteryStorageAddress);
    const NFTLottery = await ethers.getContractAt("NFTLottery", NFTLotteryAddress);

    // Example interaction: Get contract owner
    const owner = await NFTLotteryStorage.contractOwner();
    console.log("Contract owner:", owner);

    // Example interaction: Inject BIA funds
    const biaTokenAddress = await NFTLotteryStorage.biaTokenContract();
    const BiaToken = await ethers.getContractAt("IERC20", biaTokenAddress);
    console.log("BIA Token address:", biaTokenAddress);

    // Approve BIA token allowance
    const approveTx = await BiaToken.approve(await NFTLottery.getAddress(), 1000);
    await approveTx.wait();
    console.log("BIA token allowance approved.");

    const injectTx = await NFTLottery.injectBIAFunds(1000);
    await injectTx.wait();
    console.log("BIA funds injected.");

    // Check ETH balance
    const balance = await ethers.provider.getBalance(await deployer.getAddress());
    console.log("Current balance:", ethers.formatEther(balance));

    // Example interaction: Inject ETH funds
        const injectEthTx = await NFTLottery.injectETHFunds({ value: ethers.parseEther("0.01") });
        await injectEthTx.wait();
        console.log("ETH funds injected.");
    

    // Example interaction: Initialize a draw
    try {
        const initializeTx = await NFTLottery.initializeDraw();
        await initializeTx.wait();
        console.log("Draw initialized.");
    } catch (error) {
        console.error("Error initializing draw:", error);
    }

    // Wait for the target block to finalize the draw
    try {
        const targetBlock = await NFTLotteryStorage.targetBlock();
        console.log("Target Block:", targetBlock.toString());

        let currentBlock = await ethers.provider.getBlockNumber();
        while (currentBlock < targetBlock) {
            console.log(`Current Block: ${currentBlock}, waiting for Target Block: ${targetBlock.toNumber()}...`);
            await new Promise(resolve => setTimeout(resolve, 10000));
            currentBlock = await ethers.provider.getBlockNumber();
        }

        // Finalize the draw
        const finalizeTx = await NFTLottery.finalizeDraw();
        await finalizeTx.wait();
        console.log("Draw finalized.");
    } catch (error) {
        console.error("Error finalizing draw:", error);
    }

    // Select eligible NFTs
    try {
        const selectEligibleTx = await NFTLottery.selectEligibleNFTs(0, 10); // Process first 10 NFTs
        await selectEligibleTx.wait();
        console.log("Eligible NFTs selected.");
    } catch (error) {
        console.error("Error selecting eligible NFTs:", error);
    }

    // Select winners
    try {
        const selectWinnersTx = await NFTLottery.selectWinners();
        await selectWinnersTx.wait();
        console.log("Winners selected.");
    } catch (error) {
        console.error("Error selecting winners:", error);
    }

    // Example interaction: Get winning NFTs
    try {
        const drawWinnerEventFilter = NFTLottery.filters.DrawWinner();
        const events = await NFTLottery.queryFilter(drawWinnerEventFilter);

        const winningNFTs = events.map(event => event.args.winningNFTs);
        console.log("Winning NFTs:", winningNFTs);
    } catch (error) {
        console.error("Error retrieving or processing winning NFTs:", error);
    }

    // Example interaction: Get total draws
    try {
        const totalDraws = await NFTLotteryStorage.totalDraws();
        console.log("Total Draws:", totalDraws.toString());
    } catch (error) {
        console.error("Error getting total draws:", error);
    }

    // Example interaction: Get current BIA jackpot
    try {
        const currentBiaJackpot = await NFTLotteryStorage.currentBiaJackpot();
        console.log("Current BIA Jackpot:", currentBiaJackpot.toString());
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
        const biaPendingWithdrawals = await NFTLotteryStorage.biaPendingWithdrawals(await deployer.getAddress());
        console.log("BIA Pending Withdrawals:", biaPendingWithdrawals.toString());

        const ethPendingWithdrawals = await NFTLotteryStorage.ethPendingWithdrawals(await deployer.getAddress());
        console.log("ETH Pending Withdrawals:", ethPendingWithdrawals.toString());
    } catch (error) {
        console.error("Error getting pending withdrawals:", error);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
