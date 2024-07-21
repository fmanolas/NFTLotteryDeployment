// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NFTLotteryStorage.sol";

contract NFTLottery is ReentrancyGuard {
    NFTLotteryStorage public storageContract;

    // Event emitted when a draw is initialized
    event DrawInitialized(uint256 mode, uint256 numberOfWinners, uint256 jackpotSize, uint256 series, uint256 rarityMode, uint256 threshold);
    // Event emitted when a draw winner is selected
    event DrawWinner(uint256[] winningNFTs, uint256 prizeAmount, string currency);
    // Event emitted when funds are injected
    event FundsInjected(uint256 biaAmount, uint256 ethAmount);
    // Event emitted when funds are claimed
    event FundsClaimed(address indexed claimer, uint256 amount, string currency);
    // Event emitted when a new NFT is added
    event NFTAdded(uint256 id, uint256 rarityScore, string series);
    // Event emitted when an eligible NFT is selected
    event EligibleNFTSelected(uint256 id);

    uint256[] public eligibleNFTs;
    uint256 public eligibleCount;

    // Constructor to initialize the contract with the storage contract address
    constructor(address storageContractAddress) {
        storageContract = NFTLotteryStorage(storageContractAddress);
    }

    // Modifier to allow only the contract owner to call certain functions
    modifier onlyContractOwner() {
        require(msg.sender == storageContract.contractOwner(), "Not the contract owner");
        _;
    }

    // Modifier to allow only the NFT owner to call certain functions
    modifier onlyNFTOwner(uint256 nftId) {
        require(storageContract.nftContract().ownerOf(nftId) == msg.sender, "Not the owner of the specified NFT");
        _;
    }

    // Function to initialize the lottery with a batch of NFTs and series
    function initialize(NFTLotteryStorage.NFT[] memory batch, string memory series) public onlyContractOwner {
        _addNFTs(batch, series);
    }

    // Internal function to add multiple NFTs to the lottery
    function _addNFTs(NFTLotteryStorage.NFT[] memory batch, string memory series) internal {
        for (uint256 i = 0; i < batch.length; i++) {
            _addNFT(batch[i], series);
        }
    }

    // Internal function to add a single NFT to the lottery
    function _addNFT(NFTLotteryStorage.NFT memory newNFT, string memory series) internal {
        uint256 id = newNFT.id;
        require(!storageContract.nftActiveStatus(id), "NFT already active");
        storageContract.setNFTDetails(id, newNFT.rarityScore, series);
    }

    // Function to add multiple NFTs to the lottery (public)
    function addNFTs(NFTLotteryStorage.NFT[] memory batch, string memory series) public onlyContractOwner {
        _addNFTs(batch, series);
    }

    // Function to inject BIA funds into the lottery
    function injectBIAFunds(uint256 amount) public onlyContractOwner {
        require(amount > 0, "Amount must be greater than zero");

        storageContract.setTotalBiaFunds(storageContract.totalBiaFunds() + amount);
        require(storageContract.biaTokenContract().transferFrom(msg.sender, address(storageContract), amount), "BIA transfer failed");

        emit FundsInjected(amount, 0);
    }

    // Function to inject ETH funds into the lottery
    function injectETHFunds() public payable onlyContractOwner {
        require(msg.value > 0, "Amount must be greater than zero");
        storageContract.setTotalEthFunds(storageContract.totalEthFunds() + msg.value);

        emit FundsInjected(0, msg.value);
    }

    // Internal function to generate a combined random number
    function _combinedRandomNumber() internal returns (uint256) {
        uint256 rand1 = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)));
        uint256 rand2 = uint256(keccak256(abi.encodePacked(msg.sender, storageContract.randomNonce())));
        uint256 rand3 = uint256(keccak256(abi.encodePacked(block.prevrandao, gasleft())));
        bytes32 lastRandomHash = keccak256(abi.encodePacked(rand1, rand2, rand3));
        storageContract.setLastRandomHash(lastRandomHash);
        storageContract.incrementRandomNonce();
        return uint256(lastRandomHash);
    }

    // Internal function to calculate the jackpot amount and currency
    function _calculateJackpot() internal view returns (uint256, string memory) {
        uint256 amount;
        string memory currency;

        uint256 scaleFactor = 1e18;
        uint256 randomPercentage = (uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 16 + 5); // Random percentage between 5% and 20%

        if (storageContract.totalDraws() < 6 || storageContract.totalDraws() % 2 == 0) {
            currency = "$BIA";
            amount = (randomPercentage * storageContract.totalBiaFunds()) / 100;
        } else {
            currency = "$ETH";
            amount = (randomPercentage * storageContract.totalEthFunds()) / 100;
        }

        return (amount, currency);
    }

    // Function to initialize a draw
    function initializeDraw() public onlyContractOwner {
        require(storageContract.targetBlock() == 0 && storageContract.finalizeBlock() == 0, "A draw is already in progress");

        uint256 initialRandom = _combinedRandomNumber();

        storageContract.setGameMode(uint8(initialRandom % 2));
        storageContract.setWinnersCount(uint8((initialRandom / 2 % 10) + 1));
        storageContract.setJackpotPercentage(uint8((initialRandom / 12 % 20) + 1));
        storageContract.setSelectedSeries(uint8((initialRandom / 32 % 2) + 1));
        storageContract.setRarityMode(uint8((initialRandom / 64 % 3)));
        storageContract.setRarityThreshold((initialRandom / 128 % (storageContract.maxRarityScore() - storageContract.minRarityScore() + 1)) + storageContract.minRarityScore());

        (uint256 jackpotAmount, string memory currency) = _calculateJackpot();
        if (keccak256(bytes(currency)) == keccak256(bytes("$BIA"))) {
            storageContract.setCurrentBiaJackpot(jackpotAmount);
        } else {
            storageContract.setCurrentEthJackpot(jackpotAmount);
        }

        storageContract.setTargetBlock(block.number + (initialRandom / 256 % 20) + 5);

        emit DrawInitialized(storageContract.gameMode(), storageContract.winnersCount(), jackpotAmount, storageContract.selectedSeries(), storageContract.rarityMode(), storageContract.rarityThreshold());
    }

    // Function to finalize a draw
    function finalizeDraw() public onlyContractOwner {
        if (storageContract.targetBlock() == 0 || block.number < storageContract.targetBlock()) {
            storageContract.setTargetBlock(0);
            storageContract.setFinalizeBlock(0);
            revert("Cannot finalize draw yet");
        }
        if (storageContract.finalizeBlock() != 0) {
            storageContract.setTargetBlock(0);
            storageContract.setFinalizeBlock(0);
            revert("Winner selection already in progress");
        }

        uint256 newFinalizeBlock = block.number + (_combinedRandomNumber() % 20) + 5;
        storageContract.setFinalizeBlock(newFinalizeBlock);
    }

    // Function to select eligible NFTs for the draw
    function selectEligibleNFTs(uint256 startIndex, uint256 endIndex) public onlyContractOwner {
        require(storageContract.finalizeBlock() > 0 && block.number >= storageContract.finalizeBlock(), "Cannot select winners yet");

        uint256[] memory selectedSeriesNFTIds = storageContract.selectedSeries() == 1 ? storageContract.getSeriesANFTIds() : storageContract.getSeriesBNFTIds();

        for (uint256 i = startIndex; i < endIndex && i < selectedSeriesNFTIds.length; i++) {
            uint256 id = selectedSeriesNFTIds[i];
            uint256 rarity = storageContract.nftRarityScores(id);

            bool isEligible = false;
            if (storageContract.rarityMode() == 0 && rarity > storageContract.rarityThreshold()) {
                isEligible = true;
            } else if (storageContract.rarityMode() == 1 && rarity < storageContract.rarityThreshold()) {
                isEligible = true;
            } else if (storageContract.rarityMode() == 2 && rarity >= storageContract.rarityThreshold() / 2 && rarity <= (storageContract.maxRarityScore() * 3) / 2) {
                isEligible = true;
            }

            if (isEligible && storageContract.nftActiveStatus(id)) {
                eligibleNFTs.push(id);
                eligibleCount++;
                emit EligibleNFTSelected(id);
            }
        }
    }

    // Function to select winners from eligible NFTs
function selectWinners() public onlyContractOwner {
    if (eligibleCount == 0) {
        storageContract.setTargetBlock(0);
        storageContract.setFinalizeBlock(0);
        revert("No eligible NFTs found");
    }

    uint256 finalRandom = _combinedRandomNumber();
    (uint256 jackpotAmount, string memory currency) = _calculateJackpot();
    jackpotAmount = jackpotAmount * storageContract.jackpotPercentage() / 100;

    uint256 numWinners = storageContract.gameMode() == 0 ? 1 : (eligibleCount > storageContract.winnersCount() ? storageContract.winnersCount() : eligibleCount);

    uint256[] memory winners = new uint256[](numWinners);
    uint256 totalJackpotAmount = jackpotAmount * 1e18;
    uint256 prizePerWinner = totalJackpotAmount / winners.length;

    uint256[] memory currentEligibleNFTs = new uint256[](eligibleCount);
    for (uint256 i = 0; i < eligibleCount; i++) {
        currentEligibleNFTs[i] = eligibleNFTs[i];
    }

    // Clear previous eligible NFTs list
    delete eligibleNFTs;
    eligibleCount = 0;

    bool[] memory selected = new bool[](currentEligibleNFTs.length);
    uint256 selectedCount = 0;

    while (selectedCount < numWinners) {
        uint256 winnerIndex = finalRandom % currentEligibleNFTs.length;
        uint256 winnerId = currentEligibleNFTs[winnerIndex];

        if (!selected[winnerIndex]) {
            selected[winnerIndex] = true;
            winners[selectedCount] = winnerId;
            eligibleNFTs.push(winnerId);
            eligibleCount++;
            selectedCount++;
        }
        finalRandom = uint256(keccak256(abi.encodePacked(finalRandom, selectedCount)));
    }

    if (keccak256(bytes(currency)) == keccak256(bytes("$BIA"))) {
        require(storageContract.totalBiaFunds() >= jackpotAmount, "Insufficient BIA in total funds");
        storageContract.setTotalBiaFunds(storageContract.totalBiaFunds() - jackpotAmount);
        for (uint256 i = 0; i < winners.length; i++) {
            storageContract.setBiaPendingWithdrawals(storageContract.nftContract().ownerOf(winners[i]), storageContract.biaPendingWithdrawals(storageContract.nftContract().ownerOf(winners[i])) + prizePerWinner / 1e18);
        }
    } else {
        require(storageContract.totalEthFunds() >= jackpotAmount, "Insufficient ETH in total funds");
        storageContract.setTotalEthFunds(storageContract.totalEthFunds() - jackpotAmount);
        for (uint256 i = 0; i < winners.length; i++) {
            storageContract.setEthPendingWithdrawals(storageContract.nftContract().ownerOf(winners[i]), storageContract.ethPendingWithdrawals(storageContract.nftContract().ownerOf(winners[i])) + prizePerWinner / 1e18);
        }
    }

    emit DrawWinner(winners, jackpotAmount, currency);

    storageContract.setTargetBlock(0);
    storageContract.setFinalizeBlock(0);
}




    // Function to claim funds by NFT owner
    function claimFunds(uint256 nftId) public nonReentrant onlyNFTOwner(nftId) {
    require(storageContract.nftActiveStatus(nftId), "NFT is not active");

    uint256 biaAmount = storageContract.biaPendingWithdrawals(msg.sender);
    uint256 ethAmount = storageContract.ethPendingWithdrawals(msg.sender);

    require(biaAmount > 0 || ethAmount > 0, "No funds to claim");

    if (biaAmount > 0) {
        storageContract.setBiaPendingWithdrawals(msg.sender, 0);

        // Ensure NFTLottery contract has enough allowance to transfer BIA tokens
        require(storageContract.biaTokenContract().allowance(address(storageContract), address(this)) >= biaAmount, "Insufficient BIA allowance");
        require(storageContract.biaTokenContract().transferFrom(address(storageContract), msg.sender, biaAmount), "BIA transfer failed");
        emit FundsClaimed(msg.sender, biaAmount, "$BIA");
    }

    if (ethAmount > 0) {
        storageContract.setEthPendingWithdrawals(msg.sender, 0);
        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");
        emit FundsClaimed(msg.sender, ethAmount, "$ETH");
    }
}

function approveBiaTransferFromStorage(uint256 amount) external onlyContractOwner {
    storageContract.approveBiaTransfer(address(this), amount);
}
}
