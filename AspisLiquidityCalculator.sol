/*
 * SPDX-License-Identifier:    MIT
 */

pragma solidity 0.8.10;

import "./ITokenValueCalculator.sol";
import "./IAggregator.sol";

struct DataFeed {
    address erc20ContractAddress;
    address oracleAddress;
    uint256 decimals;
}

contract AspisLiquidityCalculator is ITokenValueCalculator {
    
    mapping(address => bytes32) public dataFeeds;

    uint256 public constant SUPPORTED_USD_DECIMALS = 4;

    address immutable private aspisGuardian; 

    constructor(address _aspisGuardian) {
        require(_aspisGuardian != address(0), "zero address error");
        aspisGuardian = _aspisGuardian;
    }

    function addPriceFeed(DataFeed[] calldata _dataFeeds) external {
        require(msg.sender == aspisGuardian, "Unauthorized access");

        for(uint64 i = 0; i < _dataFeeds.length; i++) {
            dataFeeds[_dataFeeds[i].erc20ContractAddress] = bytes32(bytes20(_dataFeeds[i].oracleAddress)) | bytes32(uint256(_dataFeeds[i].decimals));
        }
    }

    function getDerivedPrice(address _base, address _quote, uint8 _decimals)
        public
        view
        returns (int256, uint8)
    {
        require(_decimals > uint8(0) && _decimals <= uint8(18), "Invalid _decimals");
        
        int256 decimals = int256(10 ** uint256(_decimals));
        
        (uint80 roundId, int256 basePrice, ,uint256 timestamp,uint80 answerdInRound) = IAggregator(_base).latestRoundData();

        require(basePrice > 0, "Chainlink: price <=0");
        require(answerdInRound >= roundId, "Chainlink: Stale Price");
        require(timestamp > 0, "Chainlink: Round not complete");
        
        uint8 baseDecimals = IAggregator(_base).decimals();
        
        basePrice = scalePrice(basePrice, baseDecimals, _decimals);

        ( , int256 quotePrice, , , ) = IAggregator(_quote).latestRoundData();
        uint8 quoteDecimals = IAggregator(_quote).decimals();
        
        quotePrice = scalePrice(quotePrice, quoteDecimals, _decimals);

        return (basePrice * decimals / quotePrice, _decimals);
    }

    function getPrice(address _base, uint8 _decimals)
        public
        view
        returns (int256, uint8)
    {
        require(_decimals > uint8(0) && _decimals <= uint8(18), "Invalid _decimals");
                
        ( , int256 basePrice, , , ) = IAggregator(_base).latestRoundData();
        uint8 baseDecimals = IAggregator(_base).decimals();
        
        // basePrice = scalePrice(basePrice, baseDecimals, _decimals);

        return (basePrice, baseDecimals);
    }

    function scalePrice(int256 _price, uint8 _priceDecimals, uint8 _decimals)
        internal
        pure
        returns (int256)
    {
        if (_priceDecimals < _decimals) {
            return _price * int256(10 ** uint256(_decimals - _priceDecimals));
        } else if (_priceDecimals > _decimals) {
            return _price / int256(10 ** uint256(_priceDecimals - _decimals));
        }
        return _price;
    }


    //add decimal places for the tokens (usdc and usdt have 6 decimal places)
    function convert(address _token, uint256 _amount) public view returns (uint256) {
        (address _oracleAddress,  uint8 _decimals) = getOracleAndDecimals(_token);

        require(_oracleAddress != address(0), "This token is not supported"); 

        (int256 _price, uint8 decimals) =  getPrice(_oracleAddress, _decimals);

        return (_amount * uint256(_price)) /(10 ** (decimals + _decimals - SUPPORTED_USD_DECIMALS));
    }

    function getOracleAndDecimals(address _token) public view returns(address, uint8) {
        address _oracleAddress = address(bytes20(dataFeeds[_token]));
        uint8 _decimals = uint8(uint96(uint256(dataFeeds[_token])));

        return (_oracleAddress, _decimals);
    }

}
