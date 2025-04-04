// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "./Roles.sol";
import "../utils/Context.sol";

// Define a contract 'ConsumerAccessRole' to manage this role - add, remove, check
contract ConsumerAccessRole is Context {
    using Roles for Roles.Role;
    // Define 2 events, one for Adding, and other for Removing
    event ConsumerAdded(address indexed account);
    event ConsumerRemoved(address indexed account);

    // Define a struct 'consumers' by inheriting from 'Roles' library, struct Role
    Roles.Role private consumers;

    // In the constructor make the address that deploys this contract the 1st consumer
    constructor() {
        //_addConstructor(_msgSender());
        _addConsumer(_msgSender());
    }

    // Define a modifier that checks to see if _msgSender() has the appropriate role
    modifier onlyConsumer() {
        require(isConsumer(_msgSender()));
        _;
    }

    // Define a function 'isConsumer' to check this role
    function isConsumer(address account) public view returns (bool) {
        return consumers.has(account);
    }

    // Define a function 'addConsumer' that adds this role
    function addConsumer(address account) public onlyConsumer {
        _addConsumer(account);
    }

    // Define a function 'renounceConsumer' to renounce this role
    function renounceConsumer(address account) public {
        _removeConsumer(account);
    }

    // Define an internal function '_addConsumer' to add this role, called by 'addConsumer'
    function _addConsumer(address account) internal {
        consumers.add(account);
        emit ConsumerAdded(account);
    }

    // Define an internal function '_removeConsumer' to remove this role, called by 'removeConsumer'
    function _removeConsumer(address account) internal {
        consumers.remove(account);
        emit ConsumerRemoved(account);
    }
}