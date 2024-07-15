// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./NFTLotteryStorage.sol";

contract NFTLottery is ReentrancyGuard {
    NFTLotteryStorage public storageContract;

    event DrawInitialized(uint256 mode, uint256 numberOfWinners, uint256 jackpotSize, uint256 series, uint256 rarityMode, uint256 threshold);
    event DrawWinner(uint256[] winningNFTs, uint256 prizeAmount, string currency);
    event FundsInjected(uint256 biaAmount, uint256 ethAmount);
    event FundsClaimed(address indexed claimer, uint256 amount, string currency);
    event NFTAdded(uint256 id, uint256 rarityScore, string series);

    constructor(address storageContractAddress) {
        storageContract = NFTLotteryStorage(storageContractAddress);
    }

    modifier onlyContractOwner() {
        require(msg.sender == storageContract.contractOwner(), "Not the contract owner");
        _;
    }

    modifier onlyNFTOwner(uint256 nftId) {
        require(storageContract.nftContract().ownerOf(nftId) == msg.sender, "Not the owner of the specified NFT");
        _;
    }

    function initialize(NFTLotteryStorage.NFT[] memory batch, string memory series) public onlyContractOwner {
        _addNFTs(batch, series);
    }

    function _addNFTs(NFTLotteryStorage.NFT[] memory batch, string memory series) internal {
        for (uint256 i = 0; i < batch.length; i++) {
            _addNFT(batch[i], series);
        }
    }

    function _addNFT(NFTLotteryStorage.NFT memory newNFT, string memory series) internal {
        uint256 id = newNFT.id;
        require(!storageContract.nftActiveStatus(id), "NFT already active");
        storageContract.setNFTDetails(id, newNFT.rarityScore, series);
    }

    function addNFTs(NFTLotteryStorage.NFT[] memory batch, string memory series) public onlyContractOwner {
        _addNFTs(batch, series);
    }

    function injectBIAFunds(uint256 amount) public onlyContractOwner {
        require(amount > 0, "Amount must be greater than zero");

        storageContract.setTotalBiaFunds(storageContract.totalBiaFunds() + amount);
        require(storageContract.biaTokenContract().transferFrom(msg.sender, address(storageContract), amount), "BIA transfer failed");

        _updateCurrentBiaJackpot();

        emit FundsInjected(amount, 0);
    }

    function injectETHFunds() public payable onlyContractOwner {
        require(msg.value > 0, "Amount must be greater than zero");
        storageContract.setTotalEthFunds(storageContract.totalEthFunds() + msg.value);

        _updateCurrentEthJackpot();

        emit FundsInjected(0, msg.value);
    }

    function _updateCurrentBiaJackpot() internal {
        uint256 W = storageContract.gameMode() == 0 ? 1 : 2;
        uint256 randomFactor = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 15000 + 5000;
        storageContract.setCurrentBiaJackpot((randomFactor * storageContract.totalBiaFunds() * W) / 30000);
    }

    function _updateCurrentEthJackpot() internal {
        uint256 W = storageContract.gameMode() == 0 ? 1 : 2;
        uint256 randomFactor = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 15000 + 5000;
        storageContract.setCurrentEthJackpot((randomFactor * storageContract.totalEthFunds() * W) / 30000);
    }

    function _combinedRandomNumber() internal returns (uint256) {
        uint256 rand1 = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)));
        uint256 rand2 = uint256(keccak256(abi.encodePacked(msg.sender, storageContract.randomNonce())));
        uint256 rand3 = uint256(keccak256(abi.encodePacked(block.prevrandao, gasleft())));
        bytes32 lastRandomHash = keccak256(abi.encodePacked(rand1, rand2, rand3));
        storageContract.setLastRandomHash(lastRandomHash);
        storageContract.incrementRandomNonce();
        return uint256(lastRandomHash);
    }

    function _calculateJackpot() internal view returns (uint256, string memory) {
        uint256 amount;
        string memory currency;

        uint256 scaleFactor = 1e18;

        if (storageContract.totalDraws() < 6 || storageContract.totalDraws() % 2 == 0) {
            currency = "$BIA";
            amount = ((uint256(storageContract.lastRandomHash()) % 16 + 5) * storageContract.currentBiaJackpot() * scaleFactor) / 100;
        } else {
            currency = "$ETH";
            amount = ((uint256(storageContract.lastRandomHash()) % 16 + 5) * storageContract.currentEthJackpot() * scaleFactor) / 100;
        }

        return (amount / scaleFactor, currency);
    }

    function initializeDraw() public onlyContractOwner {
        require(storageContract.targetBlock() == 0 && storageContract.finalizeBlock() == 0, "A draw is already in progress");

        uint256 initialRandom = _combinedRandomNumber();

        storageContract.setGameMode(uint8(initialRandom % 2));
        storageContract.setWinnersCount(uint8((initialRandom / 2 % 10) + 1));
        storageContract.setJackpotPercentage(uint8((initialRandom / 12 % 20) + 1));
        storageContract.setSelectedSeries(uint8((initialRandom / 32 % 2) + 1));
        storageContract.setRarityMode(uint8((initialRandom / 64 % 3)));
        storageContract.setRarityThreshold((initialRandom / 128 % (storageContract.maxRarityScore() - storageContract.minRarityScore() + 1)) + storageContract.minRarityScore());

        storageContract.setTargetBlock(block.number + (initialRandom / 256 % 20) + 5);

        emit DrawInitialized(storageContract.gameMode(), storageContract.winnersCount(), storageContract.jackpotPercentage(), storageContract.selectedSeries(), storageContract.rarityMode(), storageContract.rarityThreshold());
    }

    function finalizeDraw() public onlyContractOwner {
        require(storageContract.targetBlock() > 0 && block.number >= storageContract.targetBlock(), "Cannot finalize draw yet");
        require(storageContract.finalizeBlock() == 0, "Winner selection already in progress");

        storageContract.setFinalizeBlock(block.number + (_combinedRandomNumber() % 20) + 5);
    }

    function selectWinners() public onlyContractOwner {
        require(storageContract.finalizeBlock() > 0 && block.number >= storageContract.finalizeBlock(), "Cannot select winners yet");

        uint256 finalRandom = _combinedRandomNumber();
        uint256[] memory selectedSeriesNFTIds = storageContract.selectedSeries() == 1 ? storageContract.getSeriesANFTIds() : storageContract.getSeriesBNFTIds();

        uint256[] memory eligibleNFTs = new uint256[](selectedSeriesNFTIds.length);
        uint256 eligibleCount = 0;

        for (uint256 i = 0; i < selectedSeriesNFTIds.length; i++) {
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
                eligibleNFTs[eligibleCount++] = id;
            }
        }

        require(eligibleCount > 0, "No eligible NFTs found");

        (uint256 jackpotAmount, string memory currency) = _calculateJackpot();
        jackpotAmount = jackpotAmount * storageContract.jackpotPercentage() / 100;

        uint256[] memory winners = new uint256[](storageContract.gameMode() == 0 ? 1 : (eligibleCount > storageContract.winnersCount() ? storageContract.winnersCount() : eligibleCount));
        uint256 totalJackpotAmount = jackpotAmount * 1e18;
        uint256 prizePerWinner = totalJackpotAmount / winners.length;

        for (uint256 i = 0; i < winners.length; i++) {
            winners[i] = eligibleNFTs[finalRandom % eligibleCount];
            finalRandom = uint256(keccak256(abi.encodePacked(finalRandom, i)));
        }

        if (keccak256(bytes(currency)) == keccak256(bytes("$BIA"))) {
            require(storageContract.currentBiaJackpot() >= jackpotAmount, "Insufficient BIA in jackpot");
            storageContract.setCurrentBiaJackpot(storageContract.currentBiaJackpot() - jackpotAmount);
            storageContract.setTotalBiaFunds(storageContract.totalBiaFunds() - jackpotAmount);
            for (uint256 i = 0; i < winners.length; i++) {
                storageContract.setBiaPendingWithdrawals(storageContract.nftContract().ownerOf(winners[i]), storageContract.biaPendingWithdrawals(storageContract.nftContract().ownerOf(winners[i])) + prizePerWinner / 1e18);
            }
        } else {
            require(storageContract.currentEthJackpot() >= jackpotAmount, "Insufficient ETH in jackpot");
            storageContract.setCurrentEthJackpot(storageContract.currentEthJackpot() - jackpotAmount);
            storageContract.setTotalEthFunds(storageContract.totalEthFunds() - jackpotAmount);
            for (uint256 i = 0; i < winners.length; i++) {
                storageContract.setEthPendingWithdrawals(storageContract.nftContract().ownerOf(winners[i]), storageContract.ethPendingWithdrawals(storageContract.nftContract().ownerOf(winners[i])) + prizePerWinner / 1e18);
            }
        }

        emit DrawWinner(winners, jackpotAmount, currency);

        storageContract.setTargetBlock(0);
        storageContract.setFinalizeBlock(0);
    }

    function claimFunds(uint256 nftId) public nonReentrant onlyNFTOwner(nftId) {
        require(storageContract.nftActiveStatus(nftId), "NFT is not active");

        uint256 biaAmount = storageContract.biaPendingWithdrawals(msg.sender);
        uint256 ethAmount = storageContract.ethPendingWithdrawals(msg.sender);

        require(biaAmount > 0 || ethAmount > 0, "No funds to claim");

        if (biaAmount > 0) {
            storageContract.setBiaPendingWithdrawals(msg.sender, 0);
            require(storageContract.biaTokenContract().transfer(msg.sender, biaAmount), "BIA transfer failed");
            emit FundsClaimed(msg.sender, biaAmount, "$BIA");
        }

        if (ethAmount > 0) {
            storageContract.setEthPendingWithdrawals(msg.sender, 0);
            (bool success, ) = msg.sender.call{value: ethAmount}("");
            require(success, "ETH transfer failed");
            emit FundsClaimed(msg.sender, ethAmount, "$ETH");
        }
    }
}
