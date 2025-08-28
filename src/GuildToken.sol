// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract GuildToken is ERC20, Ownable {
    error GTK__ZeroAddress();
    error GTK__NotAdmin();
    error GTK__NotVault();
    // error GTK__VaultNotSet();

    event VaultSet(address indexed vault);

    address public admin;
    address public vault;

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert GTK__NotAdmin();
        }
        _;
    }

    modifier onlyVault() {
        if (msg.sender != address(vault)) {
            revert GTK__NotVault();
        }
        _;
    }

    constructor(address _admin) ERC20("GuildToken", "GTK") Ownable(_admin) {
        if (_admin == address(0)) {
            revert GTK__ZeroAddress();
        }

        admin = _admin;
    }

    function setVault(address _vault) external onlyAdmin {
        if (_vault == address(0)) {
            revert GTK__ZeroAddress();
        }

        vault = _vault;

        emit VaultSet(vault);
    }

    function mint(address _to, uint256 _value) external onlyVault {
        _mint(_to, _value);
    }

    function burn(address _from, uint256 _value) external onlyVault {
        _burn(_from, _value);
    }
}
