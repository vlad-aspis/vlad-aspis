pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./IAspisConfiguration.sol";
import "../registry/IAspisRegistry.sol";

contract AspisConfiguration is Initializable, IAspisConfiguration {
    using EnumerableSet for EnumerableSet.AddressSet;

    address private pool;
    IAspisRegistry private registry;

    EnumerableSet.AddressSet private depositTokensSet;
    EnumerableSet.AddressSet private whitelistUsersSet;
    EnumerableSet.AddressSet private tradingTokensSet;
    EnumerableSet.AddressSet private trustedProtocolsSet;

    function setConfiguration(
        address _aspisPool,
        address _registry,
        uint256[16] memory _poolconfig,
        address[] calldata _whitelistUsers,
        address[] calldata _trustedProtocols,
        address[] calldata _depositTokens,
        address[] calldata _tradingTokens
    ) external override initializer {
        pool = _aspisPool;
        registry = IAspisRegistry(_registry);

        maxCap = _poolconfig[0];
        minDeposit = _poolconfig[1];
        maxDeposit = _poolconfig[2];

        startTime = _poolconfig[3];
        finishTime = _poolconfig[4];

        withdrawlWindow = _poolconfig[5];
        freezePeriod = _poolconfig[6];

        //no check on locklimit (it could be zero as well)
        lockLimit = _poolconfig[7];
        spendingLimit = _poolconfig[8];
        initialPrice = _poolconfig[9];
        canChangeManager = _poolconfig[10] > 0;

        _setEntranceFee(_poolconfig[11]);
        _setFundManagementFee(_poolconfig[12]);
        _setPerformanceFee(_poolconfig[13]);
        _setRageQuitFee(_poolconfig[14]);
        _setRageQuitFee(_poolconfig[14]);

        canPerformDirectTransfer = _poolconfig[15] > 0;

        _addTradingTokens(_tradingTokens);
        _addDepositTokens(_depositTokens);
        
        if(_whitelistUsers.length > 0) {
            _addToWhitelist(_whitelistUsers);
        }

        _addToTrustedProtocols(_trustedProtocols);
    }

    function getConfiguration() public view returns(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,bool,bool,bool) {
        return (maxCap, minDeposit, maxDeposit, startTime, finishTime, 
        withdrawlWindow, freezePeriod, lockLimit,
        spendingLimit, initialPrice, canChangeManager, isPublicFund(), canPerformDirectTransfer);
    }

    function getDepositLimit() public override view returns(uint256, uint256) {
        return (minDeposit, maxDeposit);
    }

    function getWhiteListUsers() public override view returns (address[] memory) {
        return whitelistUsersSet.values();
    }

    function getDepositTokens() public override view returns (address[] memory) {
        return depositTokensSet.values();
    }

    function getTradingTokens() public override view returns (address[] memory) {
        return tradingTokensSet.values();
    }

    function getTrustedProtocols() public override view returns (address[] memory) {
        return trustedProtocolsSet.values();
    }
    
    function supportsProtocol(address protocol) public override view returns (bool) {
        return trustedProtocolsSet.contains(protocol);
    }
    
    function supportsDepositToken(address token) public override view returns (bool) {
        return depositTokensSet.contains(token);
    }
    
    function supportsTradingToken(address token) public override view returns (bool) {
        return tradingTokensSet.contains(token);
    }

    function userWhitelisted(address user) public override view returns (bool) {
        return whitelistUsersSet.contains(user);
    }

    function isPublicFund() public override view returns(bool) {
        if(whitelistUsersSet.length() > 0) {
            return false;
        } else {
            return true;
        }
    }

    function setEntranceFee(uint256 _newEntranceFee) external {
        _aspisAuth();
       _setEntranceFee(_newEntranceFee);
    }

    function _setEntranceFee(uint256 _newEntranceFee) internal {
        require(_newEntranceFee <= maxFeePercentage, "Max Entrance Fee Exceeded");
        entranceFee = _newEntranceFee;
    }

    function setPerformanceFee(uint256 _performanceFee) external {
        _aspisAuth();
       _setPerformanceFee(_performanceFee);
    }

    function _setPerformanceFee(uint256 _performanceFee) internal {
        require(_performanceFee <= maxFeePercentage, "Max Performance Fee Exceeded");
        performanceFee = _performanceFee;
    }

    function setFundManagementFee(uint256 _fundManagementFee) external {
        _aspisAuth();
        _setFundManagementFee(_fundManagementFee);
    }

    function _setFundManagementFee(uint256 _fundManagementFee) internal {
        require(_fundManagementFee <= maxFeePercentage, "Max Fundmanagement Fee Exceeded");
        fundManagementFee = _fundManagementFee;
    }

    function setRageQuitFee(uint256 _newRageQuitFee) external override {
        _aspisAuth();
        _setRageQuitFee(_newRageQuitFee);
    }

     function _setRageQuitFee(uint256 _newRageQuitFee) internal {
        require(_newRageQuitFee <= maxFeePercentage, "Max Rage Quit Fee Exceeded");
        rageQuitFee = _newRageQuitFee;
    }

    function addDepositTokens(address[] memory _tokenAddresses) external {
        _aspisAuth();
        _addDepositTokens(_tokenAddresses);
    }

    function _addDepositTokens(address[] memory _tokenAddresses) internal {
        for (uint8 i = 0; i < _tokenAddresses.length; i++) {
            //check against not needed because deposit tokens will be checked against the trading tokens of the pools
            require(tradingTokensSet.contains(_tokenAddresses[i]), "Unsupported deposit token");
            depositTokensSet.add(_tokenAddresses[i]);
        }
    }

    function removeDepositTokens(address[] memory _tokenAddresses) external {
        _aspisAuth();
        for (uint8 i = 0; i < _tokenAddresses.length; i++) {
            depositTokensSet.remove(_tokenAddresses[i]);
        }
    }

    function addToWhitelist(address[] memory _voters) external {
        _aspisAuth();
        _addToWhitelist(_voters);
    }

    function _addToWhitelist(address[] memory _voters) internal {
        for (uint64 i = 0; i < _voters.length; i++) {
            whitelistUsersSet.add(_voters[i]);
        }
    }

    function removeFromWhitelist(address[] memory _users) external {
        _aspisAuth();

        require(whitelistUsersSet.length() >= _users.length, "Array length error");

        for (uint8 i = 0; i < _users.length; i++) {
            whitelistUsersSet.remove(_users[i]);
        }
    }

    function addToTrustedProtocols(address[] memory _trustedProtocols) external {
        _aspisAuth();
        _addToTrustedProtocols(_trustedProtocols);
    }

    function _addToTrustedProtocols(address[] memory _trustedProtocols) internal {
        for (uint64 i = 0; i < _trustedProtocols.length; i++) {
            require(registry.isAspisSupportedTradingProtocol(_trustedProtocols[i]), "Unsupported protocol found");
            trustedProtocolsSet.add(_trustedProtocols[i]);
        }
    }

    function addTradingTokens(address[] memory _tradingTokens) external {
        _aspisAuth();
        _addTradingTokens(_tradingTokens);
    }

    function _addTradingTokens(address[] memory _tradingTokens) internal {
        for (uint64 i = 0; i < _tradingTokens.length; i++) {
            require(registry.isAspisSupportedTradingToken(_tradingTokens[i]), "Unsupported token found");
            tradingTokensSet.add(_tradingTokens[i]);
        }
    }

     function removeFromTradingTokens(address[] memory _tradingTokens) external {
         _aspisAuth();
        for (uint8 i = 0; i < _tradingTokens.length; i++) {
            tradingTokensSet.remove(_tradingTokens[i]);
        }
    }


    function removeFromTrustedProtocols(address[] memory _trustedProtocols) external {
         _aspisAuth();
        for (uint8 i = 0; i < _trustedProtocols.length; i++) {
            trustedProtocolsSet.remove(_trustedProtocols[i]);
        }
    }

    function setFundraisingTarget(uint256 _newTarget) external {
        _aspisAuth();
        maxCap = _newTarget;
    }

    function setFundraisingStartTimeAndFinishTime(uint256 _newStartTime, uint256 _newFinishTime) external {
        _aspisAuth();
        require(block.timestamp < _newStartTime && _newStartTime > finishTime , "Fundraising ongoing");
        require(_newFinishTime > _newStartTime && _newFinishTime > block.timestamp, "Invalid finish time");

        startTime = _newStartTime;
        finishTime = _newFinishTime;

    }

    function setInitialTokenPrice(uint256 _newPrice) external {
         _aspisAuth();
        initialPrice = _newPrice;
    }

    function setDepositLimits(uint256 _newMinLimit, uint256 _newMaxLimit) external {
         _aspisAuth();
        maxDeposit = _newMaxLimit;
        minDeposit = _newMinLimit;
    }

    function setSpendingLimit(uint256 _newSpendingLimit) external {
         _aspisAuth();
        // require(_newSpendingLimit > 0, "Zero spending limit error");
        spendingLimit = _newSpendingLimit;
    }

    function setWithdrawlWindows(uint256 _newFreezePeriod, uint256 _newWithdrawlWindow) external {
         _aspisAuth();
        withdrawlWindow = _newWithdrawlWindow;
        freezePeriod = _newFreezePeriod;
    }

    function setLockLimit(uint256 _newLockLimit) external {
         _aspisAuth();
        lockLimit = _newLockLimit;
    }

    function updateCanChangeManager(bool _status) external {
        _aspisAuth();
        canChangeManager = _status;
    }

    function _aspisAuth() internal view {
        require(msg.sender == pool, "Unauthorized access");
    }

}