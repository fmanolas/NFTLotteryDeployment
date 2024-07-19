require('dotenv').config();
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Interacting with the contracts using account:", await deployer.getAddress());

    const NFTLotteryStorageAddress = "0x2221f857119caaaCA524Dd1f45AC9C7562744d23";
    const NFTLotteryAddress = "0xb47194E220c121e8FE79ABAffC0C06c7f4333706";
    const NFTContractAddress = "0xE63198b621EC3628d9a320944355D74E0De81E63";

    const NFTLotteryStorage = await ethers.getContractAt("NFTLotteryStorage", NFTLotteryStorageAddress);
    const NFTLottery = await ethers.getContractAt("NFTLottery", NFTLotteryAddress);
    const NFTContract = await ethers.getContractAt("IERC721", NFTContractAddress);
    const BiaToken = await ethers.getContractAt("IERC20", process.env.BIA_TOKEN_ADDRESS);

    await NFTLotteryStorage.setAuthorizedCaller(await NFTLottery.getAddress());

    const biaTokenBalance = await BiaToken.balanceOf(NFTLotteryStorageAddress);
    console.log("BIA Token Balance in contract:", ethers.formatUnits(biaTokenBalance, 18));

    const owner = await NFTLotteryStorage.contractOwner();
    console.log("Contract owner:", owner);

    const totalBiaFunds = await NFTLotteryStorage.totalBiaFunds();
    console.log("Total BIA Funds:", ethers.formatUnits(totalBiaFunds, 18));

    const targetBlock = await NFTLotteryStorage.targetBlock();
    const finalizeBlock = await NFTLotteryStorage.finalizeBlock();

    console.log("Target Block:", targetBlock.toString());
    console.log("Finalize Block:", finalizeBlock.toString());

    if (targetBlock.toString() === "0" && finalizeBlock.toString() === "0") {
        try {
            const initializeTx = await NFTLottery.initializeDraw();
            await initializeTx.wait();
            console.log("Draw initialized.");
        } catch (error) {
            console.error("Error initializing draw:", error);
        }
    } else {
        console.log("A draw is already in progress.");
    }

    try {
        let currentBlock = await ethers.provider.getBlockNumber();
        while (currentBlock.toString() < targetBlock.toString()) {
            console.log(`Current Block: ${currentBlock}, waiting for Target Block: ${targetBlock}...`);
            await new Promise(resolve => setTimeout(resolve, 10000));
            currentBlock = await ethers.provider.getBlockNumber();
        }

        const finalizeTx = await NFTLottery.finalizeDraw();
        await finalizeTx.wait();
        console.log("Draw finalized.");
    } catch (error) {
        console.error("Error finalizing draw:", error);
    }

    try {
        console.log(finalizeBlock);
        let currentBlock = await ethers.provider.getBlockNumber();
        while (currentBlock.toString() < finalizeBlock.toString()) {
            console.log(`Current Block: ${currentBlock}, waiting for Finalize Block: ${finalizeBlock}...`);
            await new Promise(resolve => setTimeout(resolve, 10000));
            currentBlock = await ethers.provider.getBlockNumber();
        }

        const selectEligibleTx = await NFTLottery.selectEligibleNFTs(0, 10);
        await selectEligibleTx.wait();
        console.log("Eligible NFTs selected.");
    } catch (error) {
        console.error("Error selecting eligible NFTs:", error);
    }

    try {
        const eligibleNFTCount = await NFTLottery.eligibleCount();
        console.log("Eligible NFTs count:", eligibleNFTCount.toString());
    } catch (error) {
        console.error("Error retrieving eligible NFTs:", error);
    }

    try {
        const selectWinnersTx = await NFTLottery.selectWinners();
        await selectWinnersTx.wait();
        console.log("Winners selected.");
    } catch (error) {
        console.error("Error selecting winners:", error);
    }

    try {
        const drawWinnerEventFilter = NFTLottery.filters.DrawWinner();
        const events = await NFTLottery.queryFilter(drawWinnerEventFilter);

        const winningNFTs = events.flatMap(event => event.args.winningNFTs);
        console.log("Winning NFTs:", winningNFTs.map(nftId => nftId.toString()));
    } catch (error) {
        console.error("Error retrieving or processing winning NFTs:", error);
    }

    try {
        const totalDraws = await NFTLotteryStorage.totalDraws();
        console.log("Total Draws:", totalDraws.toString());
    } catch (error) {
        console.error("Error getting total draws:", error);
    }

    const amountToInject = ethers.parseUnits("1000000", 18);

    const approveTx = await BiaToken.approve(NFTLotteryAddress, amountToInject);
    await approveTx.wait();
    console.log("BIA token allowance approved.");

    const injectTx = await NFTLottery.injectBIAFunds(amountToInject);
    await injectTx.wait();
    console.log("BIA funds injected.");

    try {
        const currentBiaJackpot = await NFTLotteryStorage.currentBiaJackpot();
        console.log("Current BIA Jackpot:", ethers.formatUnits(currentBiaJackpot, 18));
    } catch (error) {
        console.error("Error getting current BIA jackpot:", error);
    }

    try {
        const currentEthJackpot = await NFTLotteryStorage.currentEthJackpot();
        console.log("Current ETH Jackpot:", currentEthJackpot.toString());
    } catch (error) {
        console.error("Error getting current ETH jackpot:", error);
    }

    try {
        const biaPendingWithdrawals = await NFTLotteryStorage.biaPendingWithdrawals("0x49A1c5562FBe1E6cA689Af75d429Bc2dCacbb223");
        console.log("BIA Pending Withdrawals for deployer:", ethers.formatUnits(biaPendingWithdrawals, 18));

        const ethPendingWithdrawals = await NFTLotteryStorage.ethPendingWithdrawals("0x49A1c5562FBe1E6cA689Af75d429Bc2dCacbb223");
        console.log("ETH Pending Withdrawals for deployer:", ethers.formatUnits(ethPendingWithdrawals, 18));

        if (biaTokenBalance < biaPendingWithdrawals) {
            console.error("Contract does not have enough BIA tokens to cover the pending withdrawals.");
            return;
        }
    } catch (error) {
        console.error("Error getting pending withdrawals:", error);
    }

    try {
        const drawWinnerEventFilter = NFTLottery.filters.DrawWinner();
        const events = await NFTLottery.queryFilter(drawWinnerEventFilter);
        const winningNFTs = events.flatMap(event => event.args.winningNFTs);

        for (const nftId of winningNFTs) {
            const nftOwner = await NFTContract.ownerOf(nftId);
            console.log(`Owner of NFT ID ${nftId}:`, nftOwner);

            const nftOwnerSigner = await ethers.provider.getSigner(nftOwner);
            const NFTLotteryAsOwner = NFTLottery.connect(nftOwnerSigner);

            const biaBalanceBefore = await BiaToken.balanceOf(nftOwner);
            console.log(`BIA Balance of owner before claim for NFT ID ${nftId}:`, ethers.formatUnits(biaBalanceBefore, 18));

            const pendingWithdrawals = await NFTLotteryStorage.biaPendingWithdrawals(nftOwner);
            console.log(`Pending Withdrawals for NFT ID ${nftId}:`, ethers.formatUnits(pendingWithdrawals, 18));

            const contractBiaBalance = await BiaToken.balanceOf(NFTLotteryStorageAddress);
            console.log(`Contract BIA Balance before claim for NFT ID ${nftId}:`, ethers.formatUnits(contractBiaBalance, 18));

            const contractAllowance = await BiaToken.allowance(NFTLotteryStorageAddress, NFTLotteryAddress);
            console.log(`Contract BIA Allowance for NFTLottery contract:`, ethers.formatUnits(contractAllowance, 18));

                const approveTx = await BiaToken.connect(deployer).approve(NFTLotteryAddress, pendingWithdrawals);
                await approveTx.wait();
                console.log(`Allowance set for NFTLottery contract to spend from storage contract for NFT ID ${nftId}`);
            

            const claimFundsTx = await NFTLotteryAsOwner.claimFunds(nftId);
            await claimFundsTx.wait();
            console.log(`Funds claimed for NFT ID: ${nftId}`);

            const biaBalanceAfter = await BiaToken.balanceOf(nftOwner);
            console.log(`BIA Balance of owner after claim for NFT ID ${nftId}:`, ethers.formatUnits(biaBalanceAfter, 18));

            const contractBiaBalanceAfter = await BiaToken.balanceOf(NFTLotteryStorageAddress);
            console.log(`Contract BIA Balance after claim for NFT ID ${nftId}:`, ethers.formatUnits(contractBiaBalanceAfter, 18));
        }
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
