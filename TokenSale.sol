// SPDX-License-Identifier: MIT

/**
 *                                                                                @
 *                                                                               @@@
 *                          @@@@@@@                     @@@@@@@@                @ @ @
 *                   @@@@@@@@@@@@@@@@@@@@         @@@@@@@@@@@@@@@@@@@@           @@@
 *                @@@@@@@@@@@@@@@@@@@@@@@@@@@  @@@@@@@@@@@@@@@@@@@@@@@@@@         @
 *
 *    @@@@@@@@     @@@@@@@@@    @@@@@@@@@@    @@@@@@@       @@@      @@@@@  @@     @@@@@@@@@@
 *    @@@@@@@@@@   @@@@@@@@@@   @@@@@@@@@@   @@@@@@@@@      @@@       @@@   @@@    @@@@@@@@@@
 *    @@@     @@@  @@@     @@@  @@@     @@  @@@     @@@    @@@@@      @@@   @@@@   @@@     @@
 *    @@@     @@@  @@@     @@@  @@@         @@@            @@@@@      @@@   @@@@   @@@
 *    @@@@@@@@@@   @@@@@@@@@@   @@@    @@    @@@@@@@      @@@ @@@     @@@   @@@@   @@@    @@
 *    @@@@@@@@     @@@@@@@@     @@@@@@@@@     @@@@@@@     @@@ @@@     @@@   @@@@   @@@@@@@@@
 *    @@@          @@@   @@@    @@@    @@          @@@   @@@   @@@    @@@   @@@@   @@@    @@
 *    @@@  @@@@    @@@   @@@    @@@                 @@@  @@@   @@@    @@@   @@@@   @@@
 *    @@@   @@@    @@@    @@@   @@@     @@  @@@     @@@  @@@@@@@@@    @@@   @@     @@@     @@
 *    @@@    @@    @@@    @@@   @@@@@@@@@@   @@@@@@@@    @@@   @@@    @@@      @@  @@@@@@@@@@
 *   @@@@@     @  @@@@@   @@@@  @@@@@@@@@@    @@@@@@    @@@@@ @@@@@  @@@@@@@@@@@@  @@@@@@@@@@
 *
 *                @@@@@@@@@@@@@@@@@@@@@@@@@@  @@@@@@@@@@@@@@@@@@@@@@@@@@@@
 *                   @@@@@@@@@@@@@@@@@@@@        @@@@@@@@@@@@@@@@@@@@@
 *                        @@@@@@@@@@                 @@@@@@@@@@@@Z
 *
 */


pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenSale is Ownable{
    using SafeMath for uint256;

    enum Status{ SEED, PRIVATE, PUBLIC}

    bool public isActive = false;
    bool public end = false;

    uint public constant  DECIMALS = 9;
    uint256[3] public MAX_SUPPLY = [300000000 * 10 ** 9, 1630000000 * 10 ** 9, 2500000000 * 10 ** 9];
    uint256 public MIN_BUY = 0.2 ether;
    uint256[3] public MAX_BUY = [2 ether, 2 ether, 3 ether];

    uint256[3] public price = [0.00007 ether, 0.00008 ether, 0.000095 ether];

    Status public status = Status.SEED;

    mapping(address => uint256)[3] public TokenBalance;
    uint256[3] public totalSoldTokens;

    modifier saleActive() {
        require(isActive, "TokenSale must be active");
        _;
    }

    modifier saleNotActive() {
        require(!isActive, "TokenSale should not be active");
        _;
    }

    function setPrice(Status _status, uint256 _price) public onlyOwner {
        price[uint(_status)] = _price;
    }

    function getStatus() public view returns(Status) {
        return status;
    }

    function startSeedSale() public onlyOwner saleNotActive{
        require(!end, "TokenSale is ended");
        status = Status.SEED;
        isActive = true;
    }

    function startPrivateSale() public onlyOwner saleActive{
        require(status == Status.SEED, "Should be Seed round period");
        status = Status.PRIVATE;
    }

    function startPublicSale() public onlyOwner saleActive{
        require(status == Status.PRIVATE, "Should be Private Sale period");
        status = Status.PUBLIC;
    }

    function endSale() public onlyOwner saleActive {
        require(status == Status.PUBLIC, "Should be Public Sale Period");
        end = true;
        isActive = false;
    }

    function buyToken() public payable saleActive{
        uint currentStatus = uint(status);
        uint256 buyAmount = msg.value + TokenBalance[currentStatus][msg.sender].mul(price[currentStatus]).div(10 ** DECIMALS);

        if(status == Status.PUBLIC)
            require(buyAmount >= MIN_BUY && buyAmount <= MAX_BUY[currentStatus], "Have to buy more than 0.2bnb, less than 3bnb");
        else
            require(buyAmount >= MIN_BUY && buyAmount <= MAX_BUY[currentStatus], "Have to buy more than 0.2bnb, less than 2bnb");

        uint256 tokenCount = _getTokenAmount(msg.value);
        require(totalSoldTokens[currentStatus] + tokenCount.mul(10 ** DECIMALS) <= MAX_SUPPLY[currentStatus], "Insufficient token amount.");

        TokenBalance[currentStatus][msg.sender] += tokenCount.mul(10 ** DECIMALS);
        totalSoldTokens[currentStatus] += tokenCount.mul(10 ** DECIMALS);
    }

    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        uint currentStatus = uint(status);
        return weiAmount.div(price[currentStatus]);
    }

    function getBoughtBalance(Status _status) public view returns (uint256) {
        return TokenBalance[uint(_status)][msg.sender];
    }

    function getAvailableTokensCount() public view returns (uint256) {
        uint currentStatus = uint(status);
        return MAX_SUPPLY[currentStatus] - totalSoldTokens[currentStatus];
    }

    function withdrawETH() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}