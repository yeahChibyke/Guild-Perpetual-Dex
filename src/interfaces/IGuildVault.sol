// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IGuildVault {
    // ------------------------------------------------------------------
    //                              ERRORS
    // ------------------------------------------------------------------
    error GV__ZeroAddress();
    error GV__ZeroAmount();
    error GV__InvalidShares();
    error GV__InsufficientLiquidity();

    // ------------------------------------------------------------------
    //                              EVENTS
    // ------------------------------------------------------------------
    event GV__PerpSet(address indexed perp);
    event GV__Deposited(address indexed depositor, uint256 indexed deposit);
    event GV__Withdrew(address indexed withdrawer, uint256 indexed withdrawal);

    // ------------------------------------------------------------------
    //                              VIEW FUNCTIONS
    // ------------------------------------------------------------------
    function iAsset() external view returns (address);
    function iToken() external view returns (address);
    function perp() external view returns (address);
    function admin() external view returns (address);
    function totalAssets() external view returns (uint256);

    function convertToShares(uint256 _assetAmount) external view returns (uint256);
    function convertToAssets(uint256 _sharesAmount) external view returns (uint256);

    // ------------------------------------------------------------------
    //                        EXTERNAL FUNCTIONS
    // ------------------------------------------------------------------
    function setPerp(address _perp) external;

    function deposit(uint256 _assetAmount) external;

    function withdraw(uint256 _sharesAmount) external;
}
