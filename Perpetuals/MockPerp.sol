// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockPerp {
    enum PositionType { None, Long, Short }

    struct Position {
        PositionType positionType;
        uint256 size;
        uint256 entryPrice;
        bool isOpen;
    }

    address public admin;
    mapping(address => Position) public positions;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function long(uint256 size, uint256 price) external {
        require(!positions[msg.sender].isOpen, "Position already open");
        positions[msg.sender] = Position(PositionType.Long, size, price, true);
    }

    function short(uint256 size, uint256 price) external {
        require(!positions[msg.sender].isOpen, "Position already open");
        positions[msg.sender] = Position(PositionType.Short, size, price, true);
    }

    function close() external {
        require(positions[msg.sender].isOpen, "No open position");
        positions[msg.sender].isOpen = false;
    }

    function liquidate(address user) external onlyAdmin {
        require(positions[user].isOpen, "No open position");
        positions[user].isOpen = false;
    }
}
