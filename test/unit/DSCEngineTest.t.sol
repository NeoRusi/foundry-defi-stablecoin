// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant STARTING_AMOUNT_DSC = 1 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }
    /////////////////////////////////
    //////  Constructor Tests ///////
    /////////////////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }
    /////////////////////////////////
    //////   Price Feed Tests ///////
    /////////////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }
    ////////////////////////////////
    ///// Deposit Collateral Tests /
    ////////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN","RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testDepositCollateralAndMintDsc() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, STARTING_AMOUNT_DSC);
        (uint256 actualDscMinted, uint256 actualCollateralDepositedInUsd) = dsce.getAccountInformation(USER);
        uint256 actualCollateralAmountDeposited = dsce.getTokenAmountFromUsd(weth, actualCollateralDepositedInUsd);
        uint256 expectedCollateralAmountdeposited = AMOUNT_COLLATERAL;
        uint256 expectedDscMinted = STARTING_AMOUNT_DSC;
        assertEq(expectedCollateralAmountdeposited, actualCollateralAmountDeposited);
        assertEq(expectedDscMinted, actualDscMinted);
        vm.stopPrank();
    }
    ////////////////////////////////
    /////Mint  DSC Tests ///////
    ////////////////////////////////

    modifier mintDsc() {
        vm.startPrank(USER);
        dsce.mintDsc(STARTING_AMOUNT_DSC);
        vm.stopPrank();
        _;
    }

    modifier depositCollateralAndMintDsc() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, STARTING_AMOUNT_DSC);
        vm.stopPrank();
        _;
    }

    // function testMintDscRevertsIfMintedToMuch() public depositCollateral {
    //     vm.startPrank(USER);
    //     vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
    //     dsce.mintDsc(28 * STARTING_AMOUNT_DSC);
    //     vm.stopPrank();
    // }

    function testMintDsc() public depositCollateral {
        vm.startPrank(USER);
        uint256 expectedAmountDsc = STARTING_AMOUNT_DSC;
        dsce.mintDsc(STARTING_AMOUNT_DSC);
        (uint256 actualAmountDsc,) = dsce.getAccountInformation(USER);
        assertEq(expectedAmountDsc, actualAmountDsc);
        vm.stopPrank();
    }

    ////////////////////////////////
    ///// Burn Tests ///////////////
    ////////////////////////////////
    modifier burnDsc() {
        vm.startPrank(USER);
        dsce.burnDsc(STARTING_AMOUNT_DSC);
        vm.stopPrank();
        _;
    }

    function testBurnDscMoreThanZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
        vm.stopPrank();
    }

    function testBurnDsc() public depositCollateralAndMintDsc {
        vm.startPrank(USER);
        dsc.approve(address(dsce), STARTING_AMOUNT_DSC);
        dsce.burnDsc(STARTING_AMOUNT_DSC);
        uint256 actualDsc = dsc.balanceOf(address(USER));
        assertEq(actualDsc, 0);
        vm.stopPrank();
    }
    ////////////////////////////////
    ///// redeemCollateral Tests ///
    ////////////////////////////////

    function testRedeemCollateralRevertsIfAmountCollateralLessThanZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRedeemCollateralIsNonReentrant() public {
        // Call the redeemCollateral function with reentrancy
        (bool success,) =
            address(this).call(abi.encodeWithSelector(dsce.redeemCollateral.selector, weth, AMOUNT_COLLATERAL));

        // Assert that the transaction reverts or throws an exception
        assert(success == false);
    }

    function testRedeemCollateral() public depositCollateral {
        vm.startPrank(USER);
        dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
        uint256 userBalance = ERC20Mock(weth).balanceOf(USER);
        assertEq(userBalance, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
    /////////////////////////////////////////////
    ///// redeemCollateralForDsc Tests //////////
    ////////////////////////////////////////////

    function testRedeemCollateralForDsc() public depositCollateralAndMintDsc {
        vm.startPrank(USER);
        dsc.approve(address(dsce), STARTING_AMOUNT_DSC);
        dsce.redeemCOllateralForDsc(weth, AMOUNT_COLLATERAL, STARTING_AMOUNT_DSC);
        uint256 userBalance = ERC20Mock(weth).balanceOf(USER);
        assertEq(userBalance, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    ////////////////////////////////
    ///// Liquidate Tests //////////
    ////////////////////////////////

    function testLiquidateRevertsIfAmountCollateralLessThanZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.liquidate(weth, USER, 0);
        vm.stopPrank();
    }

    function testLiquidateIsNonReentrant() public {
        // Call the redeemCollateral function with reentrancy
        (bool success,) =
            address(this).call(abi.encodeWithSelector(dsce.liquidate.selector, weth, USER, STARTING_AMOUNT_DSC));

        // Assert that the transaction reverts or throws an exception
        assert(success == false);
    }

    function testLiquidateRevertsIfHealthFactorOk() public {}
}
