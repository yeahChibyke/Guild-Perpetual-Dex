// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// ------------------------------------------------------------------
//                             IMPORTS
// ------------------------------------------------------------------
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract GuildToken is ERC20, Ownable {
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
    //                             STORAGE
    // ------------------------------------------------------------------
    address private s_admin;
    address private s_vault;

    // ------------------------------------------------------------------
    //                            MODIFIERS
    // ------------------------------------------------------------------
    modifier onlyAdmin() {
        if (msg.sender != s_admin) {
            revert GTK__NotAdmin();
        }
        _;
    }

    modifier onlyVault() {
        if (msg.sender != address(s_vault)) {
            revert GTK__NotVault();
        }
        _;
    }

    // ------------------------------------------------------------------
    //                            CONTRUCTOR
    // ------------------------------------------------------------------
    constructor(address _admin) ERC20("GuildToken", "GTK") Ownable(_admin) {
        if (_admin == address(0)) {
            revert GTK__ZeroAddress();
        }

        s_admin = _admin;
    }

    // ------------------------------------------------------------------
    //                        EXTERNAL FUNCTIONS
    // ------------------------------------------------------------------

    function setVault(address _vault) external onlyAdmin {
        if (_vault == address(0)) {
            revert GTK__ZeroAddress();
        }

        s_vault = _vault;

        emit VaultSet(s_vault);
    }

    function mint(address _to, uint256 _value) external onlyVault {
        _mint(_to, _value);
    }

    function burn(address _from, uint256 _value) external onlyVault {
        _burn(_from, _value);
    }

    // ------------------------------------------------------------------
    //                         GETTER FUNCTIONS
    // ------------------------------------------------------------------

    function getAdmin() external view returns (address) {
        return s_admin;
    }

    function getVault() external view returns (address) {
        return s_vault;
    }

    function getTotalSupply() external view returns (uint256) {
        return totalSupply();
    }
}
