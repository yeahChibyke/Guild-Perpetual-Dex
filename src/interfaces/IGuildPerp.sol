// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IGuildPerp {
    // ------------------------------------------------------------------
    //                              ERRORS
    // ------------------------------------------------------------------
    error GP__ZeroAddress();
    error GP__ZeroAmount();
    error GP__NotAllowed();
    error GP__SizeError();
    error GP__TradesNotAllowed();
    error GP__TradesCurrentlyActive();
    error GP__InsufficientLiquidity();

    // ------------------------------------------------------------------
    //                              EVENTS
    // ------------------------------------------------------------------
    event GP__PositionOpened(
        address indexed trader, uint256 collateralAmount, uint256 indexed size, bool indexed status, uint256 positionId
    );

    event GP__PositionClosed(address indexed trader);

    event GP__BTCPriceUpdated(uint256 indexed newRate);

    // ------------------------------------------------------------------
    //                              TYPES
    // ------------------------------------------------------------------
    struct Position {
        uint256 collateralAmount;
        uint256 size;
        uint256 entryPrice;
        uint256 leverage;
        bool status; // true for long, false for short
    }

    // ------------------------------------------------------------------
    //                   ONLYADMIN EXTERNAL FUNCTIONS
    // ------------------------------------------------------------------
    function updateBTCRate(uint256 _newRate) external;

    // ------------------------------------------------------------------
    //                   ONLYVAULT EXTERNAL FUNCTIONS
    // ------------------------------------------------------------------
    function supplyLiquidity(uint256 _amount) external;

    function exitLiquidity(uint256 _amount) external;

    // ------------------------------------------------------------------
    //                        EXTERNAL FUNCTIONS
    // ------------------------------------------------------------------
    function openPosition(uint256 _collateralAmount, uint256 _size, bool _status) external;

    // ------------------------------------------------------------------
    //                      PUBLIC VIEW FUNCTIONS
    // ------------------------------------------------------------------
    function getBTCPrice() external view returns (uint256);

    function calculatePnL(address _trader) external view returns (int256);

    function getPositionById(uint256 _id) external view returns (Position memory);

    function getOwnerOfPosition(uint256 _id) external view returns (address);
}
