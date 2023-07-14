// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract OracleTest is Test {
    uint256 arbitrumFork;
    string ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");

    address internal constant poolAddress = 0xc31e54c7a869b9fcbecc14363cf510d1c41fa443;
    address internal constant userAddress = 0x112f3DB1687E0fC4Deea7637521A55A25dB2D133;

    uint256 internal constant ORACLE_PERIOD = 30 minutes;

    /**
     * @dev Callback for Uniswap V3 pool.
     */
    function uniswapV3MintCallback(uint256 amount0, uint256 amount1, bytes calldata) external {
        if (amount0 > 0) {
            TransferHelper.safeTransfer(IUniswapV3Pool(msg.sender).token0(), msg.sender, amount0);
        }
        if (amount1 > 0) {
            TransferHelper.safeTransfer(IUniswapV3Pool(msg.sender).token1(), msg.sender, amount1);
        }
    }

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

    function getSqrtTWAP(address _uniswapPool) internal view returns (uint160 sqrtTwapX96) {
        (sqrtTwapX96,) = callUniswapObserve(IUniswapV3Pool(_uniswapPool), ORACLE_PERIOD);
    }

    function callUniswapObserve(IUniswapV3Pool uniswapPool, uint256 ago) internal view returns (uint160, uint256) {
        uint32[] memory secondsAgos = new uint32[](2);

        secondsAgos[0] = uint32(ago);
        secondsAgos[1] = 0;

        (bool success, bytes memory data) =
            address(uniswapPool).staticcall(abi.encodeWithSelector(IUniswapV3PoolOracle.observe.selector, secondsAgos));

        if (!success) {
            if (keccak256(data) != keccak256(abi.encodeWithSignature("Error(string)", "OLD"))) {
                revertBytes(data);
            }

            (,, uint16 index, uint16 cardinality,,,) = uniswapPool.slot0();

            (uint32 oldestAvailableAge,,, bool initialized) = uniswapPool.observations((index + 1) % cardinality);

            if (!initialized) {
                (oldestAvailableAge,,,) = uniswapPool.observations(0);
            }

            ago = block.timestamp - oldestAvailableAge;
            secondsAgos[0] = uint32(ago);

            (success, data) = address(uniswapPool).staticcall(
                abi.encodeWithSelector(IUniswapV3PoolOracle.observe.selector, secondsAgos)
            );
            if (!success) {
                revertBytes(data);
            }
        }

        int56[] memory tickCumulatives = abi.decode(data, (int56[]));

        int24 tick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(int256(ago)));

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);

        return (sqrtPriceX96, ago);
    }

    function setUp() public {
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
    }

    function testReallocate2() public {
        vm.selectFork(arbitrumFork);
        vm.rollFork(108795004);

        vm.startPrank(0x822C0E3aFbCfbD166833F44AD82f28354a57cf28);
        usdc.transfer(userAddress, 5000 * 1e6);
        usdc.transfer(address(this), 5000 * 1e6);
        vm.stopPrank();

        vm.startPrank(0xb65edBa80A3D81903eCD499C8EB9Cf0E19096Bd0);
        weth.transfer(userAddress, 5000 * 1e18);
        weth.transfer(address(this), 5000 * 1e18);
        vm.stopPrank();

        uniswapPool = IUniswapV3Pool(poolAddress);

        uint256 preSqrtPrice = getSqrtTWAP(poolAddress);

        vm.startPrank(userAddress);

        vm.warp(block.timestamp + 1 minutes);

        uniswapPool.swap(address(this), false, 5 * 1e6, TickMath.MAX_SQRT_RATIO - 1, "");

        vm.stopPrank();

        vm.warp(block.timestamp + 1 minutes);

        uint256 postSqrtPrice = getSqrtTWAP(poolAddress);


        assertEq(preSqrtPrice, 0);
        assertEq(postSqrtPrice, 0);
    }
}
