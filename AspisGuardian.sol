pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract AspisGuardian is AccessControl {

    bytes32 public constant ASPIS_GUARDIAN_ROLE = keccak256("ASPIS_GUARDIAN_ROLE");


    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ASPIS_GUARDIAN_ROLE, msg.sender);
    }

    function execute(address _target, uint256 _ethValue, bytes calldata _data) external {
        
        require(hasRole(ASPIS_GUARDIAN_ROLE, msg.sender), "AspisGuardian: Unauthorized access");

        (bool result, ) = _target.call{value: _ethValue}(_data);

        assembly {
            let ptr := mload(0x40)
            returndatacopy(ptr, 0, returndatasize())

            // revert instead of invalid() bc if the underlying call failed with invalid() it already wasted gas.
            // if the call returned error data, forward it
            switch result
            case 0 {
                revert(ptr, returndatasize())
            }
            default {
                return(ptr, returndatasize())
            }
        }
    }

}