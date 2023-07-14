// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Helper.sol";


contract OracleTest is Test, Helper {
    uint256 arbitrumFork;
    string ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");

    address internal constant wethUsdcPoolAddress = 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443;
    address internal constant wbtcUsdcPoolAddress = 0xA62aD78825E3a55A77823F00Fe0050F567c1e4EE;
    address internal constant arbUsdcPoolAddress = 0x81c48D31365e6B526f6BBadC5c9aaFd822134863;

    ERC20 internal usdc = ERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    ERC20 internal weth = ERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    ERC20 internal arb = ERC20(0x912CE59144191C1204E64559FE8253a0e49E6548);
    ERC20 internal wbtc = ERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);

    address internal userAddress = vm.addr(uint256(1));

    /**
     * @dev Callback for Uniswap V3 pool.
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        if (amount0Delta > 0) {
            TransferHelper.safeTransfer(IUniswapV3Pool(msg.sender).token0(), msg.sender, uint256(amount0Delta));
        }
        if (amount1Delta > 0) {
            TransferHelper.safeTransfer(IUniswapV3Pool(msg.sender).token1(), msg.sender, uint256(amount1Delta));
        }
    }

    function setUp() public {
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);

        vm.selectFork(arbitrumFork);
        vm.rollFork(108795004);

        deal(address(usdc), address(this), 50000000 * 1e6);
    }

    function testTWAPWith_ETHUSDCPool() public {
        IUniswapV3Pool uniswapPool = IUniswapV3Pool(wethUsdcPoolAddress);

        uint256 preSqrtPrice = getSqrtTWAP(wethUsdcPoolAddress);

        uniswapPool.swap(address(this), false, 12000000 * 1e6, TickMath.MAX_SQRT_RATIO - 1, "");

        vm.warp(block.timestamp + 1 minutes);

        uniswapPool.swap(address(this), false, 12000000 * 1e6, TickMath.MAX_SQRT_RATIO - 1, "");

        vm.warp(block.timestamp + 1 minutes);

        uint256 postSqrtPrice = getSqrtTWAP(wethUsdcPoolAddress);

        // 0.77%
        assertEq(postSqrtPrice * 1e6 / preSqrtPrice, 1003857);
    }

    function testTWAPWith_ARBUSDCPool() public {
        IUniswapV3Pool uniswapPool = IUniswapV3Pool(arbUsdcPoolAddress);

        uint256 preSqrtPrice = getSqrtTWAP(arbUsdcPoolAddress);

        uniswapPool.swap(address(this), false, 3300000 * 1e6, TickMath.MAX_SQRT_RATIO - 1, "");

        vm.warp(block.timestamp + 1 minutes);

        uniswapPool.swap(address(this), false, 3300000 * 1e6, TickMath.MAX_SQRT_RATIO - 1, "");

        vm.warp(block.timestamp + 1 minutes);

        uint256 postSqrtPrice = getSqrtTWAP(arbUsdcPoolAddress);

        // 21%
        assertEq(postSqrtPrice * 1e6 / preSqrtPrice, 1107876);
    }

    function testTWAPWith_WBTCUSDCPool() public {
        IUniswapV3Pool uniswapPool = IUniswapV3Pool(wbtcUsdcPoolAddress);

        uint256 preSqrtPrice = getSqrtTWAP(wbtcUsdcPoolAddress);

        uniswapPool.swap(address(this), false, 100000 * 1e6, TickMath.MAX_SQRT_RATIO - 1, "");

        vm.warp(block.timestamp + 1 minutes);

        uniswapPool.swap(address(this), false, 100000 * 1e6, TickMath.MAX_SQRT_RATIO - 1, "");

        vm.warp(block.timestamp + 1 minutes);

        uint256 postSqrtPrice = getSqrtTWAP(wbtcUsdcPoolAddress);

        // 21%
        assertEq(postSqrtPrice * 1e6 / preSqrtPrice, 1100038);
    }

}
