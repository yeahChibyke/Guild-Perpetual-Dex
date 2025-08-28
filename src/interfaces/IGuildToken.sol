// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IGuildToken {
    // ------------------------------------------------------------------
    //                              ERRORS
    // ------------------------------------------------------------------
    error GTK__ZeroAddress();
    error GTK__NotAdmin();
    error GTK__NotVault();
    error GTK__VaultNotSet();

    // ------------------------------------------------------------------
    //                              EVENTS
    // ------------------------------------------------------------------
    event VaultSet(address indexed vault);

    // ------------------------------------------------------------------
    //                          VIEW FUNCTIONS
    // ------------------------------------------------------------------
    function admin() external view returns (address);
    function vault() external view returns (address);

    // ------------------------------------------------------------------
    //                         ERC20 FUNCTIONS
    // ------------------------------------------------------------------
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    // ------------------------------------------------------------------
    //                        OWNABLE FUNCTIONS
    // ------------------------------------------------------------------
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;

    // ------------------------------------------------------------------
    //                         CUSTOM FUNCTIONS
    // ------------------------------------------------------------------
    function setVault(address _vault) external;
    function mint(address _to, uint256 _value) external;
    function burn(address _from, uint256 _value) external;
}
