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

    ERC20 public SATToken;

    bool public isActive = false;
    bool public isTokenSaleEnded = false;
    bool public setTeamAdvisor = false; 
    bool public isVestingStarted = false;

    uint public constant  DECIMALS = 9;
    uint256 constant MAX = (300000000 + 1630000000 + 2500000000 + 500000000 + 500000000) * 10 ** 9;

    uint256[5] public MAX_SUPPLY = [300000000 * 10 ** 9, 1630000000 * 10 ** 9, 2500000000 * 10 ** 9, 500000000 * 10 **9, 500000000 * 10 ** 9];
    uint256 public MIN_BUY = 0.2 ether;
    uint256[3] public MAX_BUY = [2 ether, 2 ether, 3 ether];

    uint256[3] public price = [0.00007 ether, 0.00008 ether, 0.000095 ether];

    Status public status = Status.SEED;

    mapping(address => uint256)[5] public tokenBalance;
    mapping(address => uint256)[5] public vestedTokenBalance;
    uint256[3] public totalSoldTokens;

    uint256 public startTime;

    modifier saleActive() {
        require(isActive, "TokenSale must be active");
        _;
    }

    modifier saleNotActive() {
        require(!isActive, "TokenSale should not be active");
        _;
    }

    modifier vestingActive() {
        require(isVestingStarted, "Vesting should be active");
        _;
    }

    modifier vestingNotActive() {
        require(isVestingStarted, "Vesting should not be active");
        _;
    }

    constructor(address _tokenAddress) {
        SATToken = ERC20(_tokenAddress);
    }

    function deposit(uint256 amount) public onlyOwner {
        SATToken.transferFrom(msg.sender, address(this), amount);
    }

    function setPrice(Status _status, uint256 _price) public onlyOwner {
        price[uint(_status)] = _price;
    }

    function getStatus() public view returns(Status) {
        return status;
    }

    function startSeedSale() public onlyOwner saleNotActive{
        require(!isTokenSaleEnded, "TokenSale is ended");
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
        isTokenSaleEnded = true;
        isActive = false;
    }

    function buyToken() public payable saleActive{
        uint currentStatus = uint(status);
        uint256 buyAmount = msg.value + tokenBalance[currentStatus][msg.sender].mul(price[currentStatus]).div(10 ** DECIMALS);

        if(status == Status.PUBLIC)
            require(buyAmount >= MIN_BUY && buyAmount <= MAX_BUY[currentStatus], "Have to buy more than 0.2bnb, less than 3bnb");
        else
            require(buyAmount >= MIN_BUY && buyAmount <= MAX_BUY[currentStatus], "Have to buy more than 0.2bnb, less than 2bnb");

        uint256 tokenCount = _getTokenAmount(msg.value);
        require(totalSoldTokens[currentStatus] + tokenCount.mul(10 ** DECIMALS) <= MAX_SUPPLY[currentStatus], "Insufficient token amount.");

        tokenBalance[currentStatus][msg.sender] += tokenCount.mul(10 ** DECIMALS);
        totalSoldTokens[currentStatus] += tokenCount.mul(10 ** DECIMALS);
    }

    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        uint currentStatus = uint(status);
        return weiAmount.div(price[currentStatus]);
    }

    function getBoughtBalance(Status _status) public view returns (uint256) {
        return tokenBalance[uint(_status)][msg.sender];
    }

    function getAvailableTokensCount() public view returns (uint256) {
        uint currentStatus = uint(status);
        return MAX_SUPPLY[currentStatus] - totalSoldTokens[currentStatus];
    }

    function withdrawETH() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function startVesting() public onlyOwner vestingNotActive{
        require(isTokenSaleEnded, "TokenSale should isTokenSaleEnded");
        require(SATToken.balanceOf(address(this)) >= MAX, "Not enough Tokens");
        require(setTeamAdvisor, "Please set the team wallet");

        startTime = block.timestamp;
        isVestingStarted = true;
    }

    function setMembersWallet(address[] memory teamAddresses, address[] memory advisorAddresses) external onlyOwner {
        require(!setTeamAdvisor, "You have already set Team members.");

        uint teamMembers = teamAddresses.length;
        uint advisors = advisorAddresses.length;
        for(uint i = 0; i < teamMembers; i++){
            tokenBalance[3][teamAddresses[i]] = MAX_SUPPLY[3].div(teamMembers);
        }
        for(uint i = 0; i < advisors; i++){
            tokenBalance[4][advisorAddresses[i]] = MAX_SUPPLY[4].div(advisors);
        }

        setTeamAdvisor = true;
    }

    function getAvailabeTokens(address _addr, uint kind) public view vestingActive returns(uint256) {

        require(kind >=0 && kind < 5, "Invalid value");

        uint256 availableBalance;
        uint256 currentTime = block.timestamp;
        uint256 months = (currentTime - startTime).div(30 days);

        if(kind == 0) {
            months = months > 36 ? 36 : months;
            availableBalance = tokenBalance[0][_addr].mul(10).div(100) + tokenBalance[0][_addr].mul(10).div(100).mul(months.div(4));
        }
        if(kind == 1) {
            months = months > 32 ? 32 : months;
            availableBalance = tokenBalance[1][_addr].mul(15).div(100) + tokenBalance[1][_addr].mul(85).div(100).mul(months.div(4)).div(8);
        }
        if(kind == 2) {
            months = months > 28 ? 28 : months;
            availableBalance = tokenBalance[2][_addr].mul(20).div(100) + tokenBalance[2][_addr].mul(80).div(100).mul(months.div(4)).div(7);
        }
        if(kind == 3) {
            months = months > 36 ? 36 : months;
            availableBalance = tokenBalance[3][_addr].mul(months.div(6)).div(6);
        }
        if(kind == 4) {
            months = months > 60 ? 60 : months;
            availableBalance = tokenBalance[4][_addr].mul(months.div(3)).div(20);
        }

        availableBalance -= vestedTokenBalance[kind][_addr];
        return availableBalance;       
    }

    function confirm(address _addr, uint kind) public vestingActive {
        
        require(kind >=0 && kind < 5, "Invalid value");
        
        uint256 availableBalance = getAvailabeTokens(_addr, kind);
        require(availableBalance > 0, "No token available");

        SATToken.transferFrom(address(this), _addr, availableBalance);
        
        vestedTokenBalance[kind][_addr] += availableBalance;
    }
}

interface ERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
    function allowance(address _owner, address spender)
        external
        view
        returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}