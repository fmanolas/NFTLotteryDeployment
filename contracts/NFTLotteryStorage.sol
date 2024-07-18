// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTLotteryStorage is ReentrancyGuard {
    struct NFT {
        uint256 id;
        uint256 rarityScore;
        string series;
    }

    // State variables
    address public contractOwner;
    address public authorizedCaller;
    IERC20 public biaTokenContract;
    IERC721 public nftContract;
    uint256 public currentBiaJackpot;
    uint256 public currentEthJackpot;
    uint256 public totalDraws;
    uint256 public totalBiaFunds;
    uint256 public totalEthFunds;
    uint256 public constant minRarityScore = 10000;
    uint256 public constant maxRarityScore = 100000;
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

    uint8 public gameMode;
    uint8 public winnersCount;
    uint8 public jackpotPercentage;
    uint8 public selectedSeries;
    uint8 public rarityMode;
    uint256 public rarityThreshold;

    event DrawInitialized(uint256 mode, uint256 numberOfWinners, uint256 jackpotSize, uint256 series, uint256 rarityMode, uint256 threshold);
    event DrawWinner(uint256[] winningNFTs, uint256 prizeAmount, string currency);
    event FundsInjected(uint256 biaAmount, uint256 ethAmount);
    event FundsClaimed(address indexed claimer, uint256 amount, string currency);
    event NFTAdded(uint256 id, uint256 rarityScore, string series);

    bytes32 public lastRandomHash;

    // Constructor to initialize the contract with BIA token and NFT contract addresses
    constructor(
        address biaTokenAddress,
        address nftContractAddress
    ) {
        contractOwner = msg.sender;
        biaTokenContract = IERC20(biaTokenAddress);
        nftContract = IERC721(nftContractAddress);
    }

    // Modifier to allow only the contract owner to call certain functions
    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "Not the contract owner");
        _;
    }

    // Modifier to allow only the authorized caller to call certain functions
    modifier onlyAuthorized() {
        require(msg.sender == authorizedCaller, "Not authorized");
        _;
    }

    // Modifier to allow only the NFT owner to call certain functions
    modifier onlyNFTOwner(uint256 nftId) {
        require(nftContract.ownerOf(nftId) == msg.sender, "Not the owner of the specified NFT");
        _;
    }

    // Function to set the authorized caller
    function setAuthorizedCaller(address _authorizedCaller) external onlyContractOwner {
        authorizedCaller = _authorizedCaller;
    }

    // Function to set NFT details
    function setNFTDetails(uint256 id, uint256 rarityScore, string memory series) external onlyAuthorized {
        NFT memory newNFT = NFT({id: id, rarityScore: rarityScore, series: series});
        nftDetails[id] = newNFT;
        nftRarityScores[id] = rarityScore;
        nftActiveStatus[id] = true;

        if (keccak256(bytes(series)) == keccak256("A")) {
            seriesANFTIds.push(id);
        } else {
            seriesBNFTIds.push(id);
        }

        emit NFTAdded(id, rarityScore, series);
    }

    // Function to increment the random nonce
    function incrementRandomNonce() external onlyAuthorized {
        randomNonce++;
    }

    // Function to set the current BIA jackpot value
    function setCurrentBiaJackpot(uint256 value) external onlyAuthorized {
        currentBiaJackpot = value;
    }

    // Function to set the current ETH jackpot value
    function setCurrentEthJackpot(uint256 value) external onlyAuthorized {
        currentEthJackpot = value;
    }

    // Function to set the last random hash value
    function setLastRandomHash(bytes32 value) external onlyAuthorized {
        lastRandomHash = value;
    }

    // Function to set the game mode
    function setGameMode(uint8 value) external onlyAuthorized {
        gameMode = value;
    }

    // Function to set the number of winners
    function setWinnersCount(uint8 value) external onlyAuthorized {
        winnersCount = value;
    }

    // Function to set the jackpot percentage
    function setJackpotPercentage(uint8 value) external onlyAuthorized {
        jackpotPercentage = value;
    }

    // Function to set the selected series
    function setSelectedSeries(uint8 value) external onlyAuthorized {
        selectedSeries = value;
    }

    // Function to set the rarity mode
    function setRarityMode(uint8 value) external onlyAuthorized {
        rarityMode = value;
    }

    // Function to set the rarity threshold
    function setRarityThreshold(uint256 value) external onlyAuthorized {
        rarityThreshold = value;
    }

    // Function to set the target block number
    function setTargetBlock(uint256 value) external onlyAuthorized {
        targetBlock = value;
    }

    // Function to set the finalize block number
    function setFinalizeBlock(uint256 value) external onlyAuthorized {
        finalizeBlock = value;
    }

    // Function to set the total BIA funds
    function setTotalBiaFunds(uint256 value) external onlyAuthorized {
        totalBiaFunds = value;
    }

    // Function to set the total ETH funds
    function setTotalEthFunds(uint256 value) external onlyAuthorized {
        totalEthFunds = value;
    }

    // Function to set the BIA pending withdrawals for a user
    function setBiaPendingWithdrawals(address user, uint256 value) external onlyAuthorized {
        biaPendingWithdrawals[user] = value;
    }

    // Function to set the ETH pending withdrawals for a user
    function setEthPendingWithdrawals(address user, uint256 value) external onlyAuthorized {
        ethPendingWithdrawals[user] = value;
    }

    // Function to get the NFT IDs for series A
    function getSeriesANFTIds() external view returns (uint256[] memory) {
        return seriesANFTIds;
    }

    // Function to get the NFT IDs for series B
    function getSeriesBNFTIds() external view returns (uint256[] memory) {
        return seriesBNFTIds;
    }
}
