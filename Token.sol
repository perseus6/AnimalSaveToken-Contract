// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract SAT is Ownable, ERC20 {

    using SafeMath for uint256;

    address public pancakeV2Pair;
    IPancakeRouter02 public router;

    uint256 buybackFee;
    uint256 marketingFee;
    uint256 liquidityFee;

    address public buybackAddress;
    address public marketingAddress;
    address public liquidityAddress;

    uint256 constant FEE_PRECISION = 1000;

    uint256 public constant MAX_SUPPLY = 1e10 * 10 ** 9;

    mapping (address => bool) private _isExcludedFromFee;

    bool private swapping;

    bool public tradingEnabled = false;

    uint256 public swapAmountThreshold = 100 * 10 ** 9;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    modifier Swapping {
      swapping = true;
      _;
      swapping = false;
    }

    constructor(address _router) ERC20("Save Animals Token", "SAT") {

      router = IPancakeRouter02(_router);

      pancakeV2Pair = IPancakeFactory(router.factory())
        .createPair(address(this), router.WETH());

      _isExcludedFromFee[msg.sender] = true;
      _isExcludedFromFee[address(this)] = true;

      _approve(address(this), address(router), uint256(int(-1)));
    }

    receive() payable external {}

    function updatePair(address _new) external onlyOwner {
      require(_new != address(0), "Null address");

      pancakeV2Pair = _new;
    }

    function updateReceiver(
      address _buyback,
      address _marketing,
      address _liquidity
    ) external onlyOwner {
      require(_buyback != address(0), "Null address");
      require(_marketing != address(0), "Null address");
      require(_liquidity != address(0), "Null address");

      buybackAddress = _buyback;
      marketingAddress = _marketing;
      liquidityAddress = _liquidity;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (
          !_isExcludedFromFee[from] && !_isExcludedFromFee[to]
        ) {  

          if (from == pancakeV2Pair || to == pancakeV2Pair) { // Buying or selling
            require(tradingEnabled, "Trading Not available");

            uint256 _feeAmount;

            if(from == pancakeV2Pair) { // Buying
                _feeAmount = amount.mul(60).div(FEE_PRECISION);

                buybackFee += _feeAmount.mul(20).div(60);
                marketingFee += _feeAmount.mul(20).div(60);
                liquidityFee += _feeAmount.mul(20).div(60);
            }
            else {
                _feeAmount = amount.mul(80).div(FEE_PRECISION);
                
                buybackFee += _feeAmount.mul(30).div(80);
                marketingFee += _feeAmount.mul(20).div(80);
                liquidityFee += _feeAmount.mul(30).div(80);
            }

            super._transfer(from, address(this), _feeAmount);

            amount = amount.sub(_feeAmount);
          } 
        //   else {
        //     uint256 contractTokenBalance = balanceOf(address(this));

        //     bool swapAmountOk = contractTokenBalance >= swapAmountThreshold;

        //     if (swapAmountOk && !swapping) {
        //         distributeFee();
        //     }
        //   }
        }

        super._transfer(from, to, amount);
    }

    function distributeFee() private Swapping {

        uint256 tokenBalance = balanceOf(address(this));
        uint256 initialBalance = address(this).balance;
        swapTokensForBNB(tokenBalance);
        uint256 newBalance = address(this).balance.sub(initialBalance);
        uint256 feeTotal = buybackFee.add(marketingFee).add(liquidityFee);
      uint256 bnbForbuyback = newBalance.mul(buybackFee).div(feeTotal);
      uint256 bnbForMarketing = newBalance.mul(marketingFee).div(feeTotal);
      Address.sendValue(payable(buybackAddress), bnbForbuyback);
      Address.sendValue(payable(marketingAddress), bnbForMarketing);
      Address.sendValue(payable(liquidityAddress), newBalance.sub(bnbForbuyback).sub(bnbForMarketing));


    }

    function swapTokensForBNB(uint256 tokenAmount) private {

        if (tokenAmount == 0) return;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
      // approve token transfer to cover all possible scenarios
        _approve(address(this), address(router), tokenAmount);

        // add the liquidity
        router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {

        require(totalSupply() <= MAX_SUPPLY, "Exceed max supply");

        _mint(_to, _amount);
    }

    function burn(address _from ,uint256 _amount) public onlyOwner {
        _burn(_from, _amount);
    }

    function setExcludedFromFee(address _addr, bool _bExcluded) public onlyOwner {
        require(_isExcludedFromFee[_addr] != _bExcluded, "Already set");

        _isExcludedFromFee[_addr] = _bExcluded;
    }

    function openTrading() public onlyOwner {
        require(!tradingEnabled, "Already enabled");
        tradingEnabled = true;
    }

    function isExcludedFromFee(address _addr) public view returns (bool) {
        return _isExcludedFromFee[_addr];
    }

    function decimals() public pure override returns (uint8) {
        return 9;
    }
}

interface IPancakeRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IPancakeRouter02 is IPancakeRouter01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IPancakeFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;

    function INIT_CODE_PAIR_HASH() external view returns (bytes32);
}