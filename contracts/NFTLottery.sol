// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTLottery is ReentrancyGuard {
    struct NFT {
        uint256 id;
        uint256 rarityScore;
        string series;
    }

    address public contractOwner;
    IERC20 public biaTokenContract;
    IERC721 public nftContract;
    uint256 public currentBiaJackpot;
    uint256 public currentEthJackpot;
    uint256 public totalDraws;
    uint256 public totalBiaFunds;
    uint256 public totalEthFunds;
    uint256 public minRarityScore = 10000;
    uint256 public maxRarityScore = 100000;
    uint256 public randomNonce;
    uint256 public targetBlock;
    uint256 public finalizeBlock;

    uint256[] public seriesANFTIds;
    uint256[] public seriesBNFTIds;
    mapping(uint256 => NFT) public nftDetails;
    mapping(uint256 => uint256) public nftRarityScores;
    mapping(uint256 => bool) public nftActiveStatus;
    mapping(address => uint256) public biaPendingWithdrawals;
    mapping(address => uint256) public ethPendingWithdrawals;

    uint256 public gameMode;
    uint256 public winnersCount;
    uint256 public jackpotPercentage;
    uint256 public selectedSeries;
    uint256 public rarityMode;
    uint256 public rarityThreshold;

    event DrawInitialized(uint256 mode, uint256 numberOfWinners, uint256 jackpotSize, uint256 series, uint256 rarityMode, uint256 threshold);
    event DrawWinner(uint256[] winningNFTs, uint256 prizeAmount, string currency);
    event FundsInjected(uint256 biaAmount, uint256 ethAmount);
    event FundsClaimed(address indexed claimer, uint256 amount, string currency);
    event NFTAdded(uint256 id, uint256 rarityScore, string series);

    bytes32 public lastRandomHash;

    constructor(
        address biaTokenAddress,
        address nftContractAddress,
        NFT[] memory seriesANFTs,
        NFT[] memory seriesBNFTs
    ) {
        contractOwner = msg.sender;
        biaTokenContract = IERC20(biaTokenAddress);
        nftContract = IERC721(nftContractAddress);
        totalDraws = 0;
        currentBiaJackpot = 0;
        currentEthJackpot = 0;
        randomNonce = 0;
        targetBlock = 0;
        finalizeBlock = 0;

        addNFTs(seriesANFTs, seriesBNFTs);
    }

    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "Not the contract owner");
        _;
    }

    modifier onlyNFTOwner(uint256 nftId) {
        require(nftContract.ownerOf(nftId) == msg.sender, "Not the owner of the specified NFT");
        _;
    }

    function addNFTs(
        NFT[] memory seriesANFTs,
        NFT[] memory seriesBNFTs
    ) public onlyContractOwner {
        for (uint256 i = 0; i < seriesANFTs.length; i++) {
            require(seriesANFTs[i].id >= 0 && seriesANFTs[i].id <= 3839, "Series A ID out of range");
            require(!nftActiveStatus[seriesANFTs[i].id], "Series A NFT already active");

            NFT memory newANFT = NFT({
                id: seriesANFTs[i].id,
                rarityScore: seriesANFTs[i].rarityScore,
                series: "A"
            });

            nftDetails[seriesANFTs[i].id] = newANFT;
            nftRarityScores[seriesANFTs[i].id] = seriesANFTs[i].rarityScore;
            nftActiveStatus[seriesANFTs[i].id] = true;

            seriesANFTIds.push(seriesANFTs[i].id);

            emit NFTAdded(seriesANFTs[i].id, seriesANFTs[i].rarityScore, "A");
        }

        for (uint256 i = 0; i < seriesBNFTs.length; i++) {
            require(seriesBNFTs[i].id >= 3840 && seriesBNFTs[i].id <= 7679, "Series B ID out of range");
            require(!nftActiveStatus[seriesBNFTs[i].id], "Series B NFT already active");

            NFT memory newBNFT = NFT({
                id: seriesBNFTs[i].id,
                rarityScore: seriesBNFTs[i].rarityScore,
                series: "B"
            });

            nftDetails[seriesBNFTs[i].id] = newBNFT;
            nftRarityScores[seriesBNFTs[i].id] = seriesBNFTs[i].rarityScore;
            nftActiveStatus[seriesBNFTs[i].id] = true;

            seriesBNFTIds.push(seriesBNFTs[i].id);

            emit NFTAdded(seriesBNFTs[i].id, seriesBNFTs[i].rarityScore, "B");
        }
    }

    function injectBIAFunds(uint256 amount) public onlyContractOwner {
        require(amount > 0, "Amount must be greater than zero");

        // Update state before external call
        totalBiaFunds += amount;
        require(biaTokenContract.transferFrom(msg.sender, address(this), amount), "BIA transfer failed");

        updateCurrentBiaJackpot();

        emit FundsInjected(amount, 0);
    }

    function injectETHFunds() public payable onlyContractOwner {
        require(msg.value > 0, "Amount must be greater than zero");
        totalEthFunds += msg.value;

        updateCurrentEthJackpot();

        emit FundsInjected(0, msg.value);
    }

    function updateCurrentBiaJackpot() internal {
        uint256 W = gameMode == 0 ? 1 : 2; // 1 for single winner, 2 for multiple winners
        uint256 randomFactor = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 15000 + 5000; // Random factor between 5000 and 20000
        currentBiaJackpot = (randomFactor * totalBiaFunds * W) / 30000; // Adjust to match the scale
    }

    function updateCurrentEthJackpot() internal {
        uint256 W = gameMode == 0 ? 1 : 2; // 1 for single winner, 2 for multiple winners
        uint256 randomFactor = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 15000 + 5000; // Random factor between 5000 and 20000
        currentEthJackpot = (randomFactor * totalEthFunds * W) / 30000; // Adjust to match the scale
    }

    function randomFunction1() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)));
    }

    function randomFunction2() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(msg.sender, randomNonce)));
    }

    function randomFunction3() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.prevrandao, gasleft())));
    }

    function combinedRandomNumber() internal returns (uint256) {
        uint256 rand1 = randomFunction1();
        uint256 rand2 = randomFunction2();
        uint256 rand3 = randomFunction3();
        lastRandomHash = keccak256(abi.encodePacked(rand1, rand2, rand3));
        randomNonce++;
        return uint256(lastRandomHash);
    }

    function calculateJackpot() internal view returns (uint256, string memory) {
        uint256 amount;
        string memory currency;

        // Scale factor to handle precise division
        uint256 scaleFactor = 1e18;

        if (totalDraws < 6 || totalDraws % 2 == 0) {
            currency = "$BIA";
            amount = ((uint256(lastRandomHash) % 16 + 5) * currentBiaJackpot * scaleFactor) / 100;
        } else {
            currency = "$ETH";
            amount = ((uint256(lastRandomHash) % 16 + 5) * currentEthJackpot * scaleFactor) / 100;
        }

        return (amount / scaleFactor, currency);
    }

    function initializeDraw() public onlyContractOwner {
        require(targetBlock == 0 && finalizeBlock == 0, "A draw is already in progress");

        uint256 initialRandom = combinedRandomNumber();

        // Determine the mode of the game
        gameMode = initialRandom % 2; // 0 for single winner, 1 for multiple winners
        // Determine the number of winners
        winnersCount = (initialRandom / 2 % 10) + 1; // 1 to 10 winners
        // Determine the size of the jackpot
        jackpotPercentage = (initialRandom / 12 % 20) + 1; // 1% to 20% of the current jackpot

        selectedSeries = (initialRandom / 32 % 2) + 1; // 1 for Series A, 2 for Series B
        rarityMode = (initialRandom / 64 % 3); // 0: Higher, 1: Lower, 2: In-Between
        rarityThreshold = (initialRandom / 128 % (maxRarityScore - minRarityScore + 1)) + minRarityScore;

        targetBlock = block.number + (initialRandom / 256 % 20) + 5; // Random delay of 5 to 25 blocks

        emit DrawInitialized(gameMode, winnersCount, jackpotPercentage, selectedSeries, rarityMode, rarityThreshold);
    }

    function finalizeDraw() public onlyContractOwner {
        require(targetBlock > 0 && block.number >= targetBlock, "Cannot finalize draw yet");
        require(finalizeBlock == 0, "Winner selection already in progress");

        finalizeBlock = block.number + (combinedRandomNumber() % 20) + 5; // Random delay of 5 to 25 blocks
    }

    function selectWinners() public onlyContractOwner {
        require(finalizeBlock > 0 && block.number >= finalizeBlock, "Cannot select winners yet");

        uint256 finalRandom = combinedRandomNumber();

        uint256[] storage selectedSeriesNFTIds = selectedSeries == 1 ? seriesANFTIds : seriesBNFTIds;

        uint256[] memory eligibleNFTs = new uint256[](selectedSeriesNFTIds.length);
        uint256 eligibleCount = 0;

        for (uint256 i = 0; i < selectedSeriesNFTIds.length; i++) {
            uint256 id = selectedSeriesNFTIds[i];
            uint256 rarity = nftRarityScores[id];

            bool isEligible = false;
            if (rarityMode == 0 && rarity > rarityThreshold) { // Higher
                isEligible = true;
            } else if (rarityMode == 1 && rarity < rarityThreshold) { // Lower
                isEligible = true;
            } else if (rarityMode == 2 && rarity >= rarityThreshold / 2 && rarity <= (maxRarityScore * 3) / 2) { // In-Between
                isEligible = true;
            }

            if (isEligible && nftActiveStatus[id]) {
                eligibleNFTs[eligibleCount++] = id;
            }
        }

        require(eligibleCount > 0, "No eligible NFTs found");

        (uint256 jackpotAmount, string memory currency) = calculateJackpot();
        jackpotAmount = jackpotAmount * jackpotPercentage / 100; // Adjust jackpot size

        uint256[] memory winners = new uint256[](gameMode == 0 ? 1 : (eligibleCount > winnersCount ? winnersCount : eligibleCount));

        // Scale factor to handle integer division
        uint256 scaleFactor = 1e18;
        uint256 totalJackpotAmount = jackpotAmount * scaleFactor;
        uint256 prizePerWinner = totalJackpotAmount / winners.length;

        for (uint256 i = 0; i < winners.length; i++) {
            winners[i] = eligibleNFTs[finalRandom % eligibleCount];
            finalRandom = uint256(keccak256(abi.encodePacked(finalRandom, i))); // Update finalRandom for next selection
        }

        if (keccak256(bytes(currency)) == keccak256(bytes("$BIA"))) {
            require(currentBiaJackpot >= jackpotAmount, "Insufficient BIA in jackpot");
            currentBiaJackpot -= jackpotAmount;
            totalBiaFunds -= jackpotAmount;
            for (uint256 i = 0; i < winners.length; i++) {
                biaPendingWithdrawals[nftContract.ownerOf(winners[i])] += prizePerWinner / scaleFactor;
            }
        } else {
            require(currentEthJackpot >= jackpotAmount, "Insufficient ETH in jackpot");
            currentEthJackpot -= jackpotAmount;
            totalEthFunds -= jackpotAmount;
            for (uint256 i = 0; i < winners.length; i++) {
                ethPendingWithdrawals[nftContract.ownerOf(winners[i])] += prizePerWinner / scaleFactor;
            }
        }

        emit DrawWinner(winners, jackpotAmount, currency);

        // Reset targetBlock and finalizeBlock for next draw
        targetBlock = 0;
        finalizeBlock = 0;
    }

    function claimFunds(uint256 nftId) public nonReentrant onlyNFTOwner(nftId) {
        require(nftActiveStatus[nftId], "NFT is not active");

        uint256 biaAmount = biaPendingWithdrawals[msg.sender];
        uint256 ethAmount = ethPendingWithdrawals[msg.sender];

        require(biaAmount > 0 || ethAmount > 0, "No funds to claim");

        // Update state before external calls
        if (biaAmount > 0) {
            biaPendingWithdrawals[msg.sender] = 0;
            require(biaTokenContract.transfer(msg.sender, biaAmount), "BIA transfer failed");
            emit FundsClaimed(msg.sender, biaAmount, "$BIA");
        }

        if (ethAmount > 0) {
            ethPendingWithdrawals[msg.sender] = 0;
            (bool success, ) = msg.sender.call{value: ethAmount}("");
            require(success, "ETH transfer failed");
            emit FundsClaimed(msg.sender, ethAmount, "$ETH");
        }
    }
}
