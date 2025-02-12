// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockERC721", "MERC721") {}

    function mint(uint256 tokenId, address to) public {
        _mint(to, tokenId);
    }
}
