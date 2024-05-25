// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LiquidityPool.sol";

contract DEX {
    LiquidityPool public liquidityPool;
    IERC20 public token;

    constructor(address tokenAddress, address liquidityPoolAddress) {
        token = IERC20(tokenAddress);
        liquidityPool = LiquidityPool(liquidityPoolAddress);
    }

    function addLiquidity(uint256 tokenAmount) public payable {
        liquidityPool.addLiquidity{value: msg.value}(tokenAmount);
    }

    function removeLiquidity(uint256 liquidityAmount) public {
        liquidityPool.removeLiquidity(liquidityAmount);
    }

    function ethToTokenSwap(uint256 minTokens) public payable {
        liquidityPool.ethToTokenSwap{value: msg.value}(minTokens);
    }

    function tokenToEthSwap(uint256 tokenAmount, uint256 minEth) public {
        liquidityPool.tokenToEthSwap(tokenAmount, minEth);
    }

    function getReserves() public view returns (uint256, uint256) {
        return liquidityPool.getReserves();
    }
}
