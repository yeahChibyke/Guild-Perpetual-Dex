// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWBTC is ERC20 {
    uint8 dec;

    constructor(uint8 _dec) ERC20("MockWBTC", "wbtc") {
        dec = _dec;
    }

    function mint(address _to, uint256 _value) external {
        uint256 to_mint = _value * dec;
        _mint(_to, to_mint);
    }

    function transfer(address _to, uint256 _value) public override returns (bool) {
        uint256 to_transfer = _value * dec;
        _transfer(msg.sender, _to, to_transfer);

        return true;
    }

    function decimals() public view override returns (uint8) {
        return dec;
    }
}
