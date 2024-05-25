// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract LiquidityPool {
    IERC20 public token;
    AggregatorV3Interface internal priceFeedEthUsd;
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    event LiquidityAdded(
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 tokenAmount,
        uint256 ethAmount
    );
    event TokenPurchase(
        address indexed buyer,
        uint256 ethSold,
        uint256 tokensBought
    );
    event EthPurchase(
        address indexed buyer,
        uint256 tokensSold,
        uint256 ethBought
    );

    constructor(address tokenAddress, address _priceFeedEthUsd) {
        token = IERC20(tokenAddress);
        priceFeedEthUsd = AggregatorV3Interface(_priceFeedEthUsd);
    }

    function getLatestEthPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeedEthUsd.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price);
    }

    function addLiquidity(
        uint256 tokenAmount
    ) public payable returns (uint256) {
        require(tokenAmount > 0 && msg.value > 0, "Invalid amounts");

        uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 liquidityMinted;

        if (totalLiquidity == 0) {
            liquidityMinted = address(this).balance;
        } else {
            liquidityMinted = (msg.value * totalLiquidity) / ethReserve;
        }

        totalLiquidity += liquidityMinted;
        liquidity[msg.sender] += liquidityMinted;

        require(
            token.transferFrom(msg.sender, address(this), tokenAmount),
            "Token transfer failed"
        );

        emit LiquidityAdded(msg.sender, tokenAmount, msg.value);

        return liquidityMinted;
    }

    function removeLiquidity(
        uint256 liquidityAmount
    ) public returns (uint256, uint256) {
        require(
            liquidity[msg.sender] >= liquidityAmount,
            "Insufficient liquidity"
        );

        uint256 ethAmount = (liquidityAmount * address(this).balance) /
            totalLiquidity;
        uint256 tokenAmount = (liquidityAmount *
            token.balanceOf(address(this))) / totalLiquidity;

        totalLiquidity -= liquidityAmount;
        liquidity[msg.sender] -= liquidityAmount;

        require(
            token.transfer(msg.sender, tokenAmount),
            "Token transfer failed"
        );
        payable(msg.sender).transfer(ethAmount);

        emit LiquidityRemoved(msg.sender, tokenAmount, ethAmount);

        return (tokenAmount, ethAmount);
    }

    function ethToTokenSwap(uint256 minTokens) public payable {
        require(msg.value > 0, "ETH amount must be greater than 0");

        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokensBought = getOutputAmount(
            msg.value,
            ethReserve,
            tokenReserve
        );

        require(tokensBought >= minTokens, "Insufficient output amount");
        require(
            token.transfer(msg.sender, tokensBought),
            "Token transfer failed"
        );

        emit TokenPurchase(msg.sender, msg.value, tokensBought);
    }

    function tokenToEthSwap(uint256 tokenAmount, uint256 minEth) public {
        require(tokenAmount > 0, "Token amount must be greater than 0");

        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance;
        uint256 ethBought = getOutputAmount(
            tokenAmount,
            tokenReserve,
            ethReserve
        );

        require(ethBought >= minEth, "Insufficient output amount");
        require(
            token.transferFrom(msg.sender, address(this), tokenAmount),
            "Token transfer failed"
        );
        payable(msg.sender).transfer(ethBought);

        emit EthPurchase(msg.sender, tokenAmount, ethBought);
    }

    function getOutputAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) internal pure returns (uint256) {
        uint256 inputAmountWithFee = inputAmount * 997; // 0.3% fee
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 1000) + inputAmountWithFee;
        return numerator / denominator;
    }

    function getReserves() public view returns (uint256, uint256) {
        return (address(this).balance, token.balanceOf(address(this)));
    }
}
