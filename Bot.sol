// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

// HebeSwap Router Interface
interface IHebeSwapRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

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
}

// HebeSwap Factory Interface
interface IHebeSwapFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

// WETC (Wrapped Ethereum Classic) Interface
interface IWETC {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function transfer(address to, uint value) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
}

contract HebeSwapBot {
    address public owner;
    IHebeSwapRouter public hebeSwapRouter;
    IHebeSwapFactory public hebeSwapFactory;
    IWETC public wetc;

    event LiquidityAdded(uint amountA, uint amountB, uint liquidity);
    event TokensSwapped(uint[] amounts);

    constructor(
        address _hebeSwapRouter,
        address _hebeSwapFactory,
        address _wetc
    ) public {
        owner = msg.sender;
        hebeSwapRouter = IHebeSwapRouter(_hebeSwapRouter);
        hebeSwapFactory = IHebeSwapFactory(_hebeSwapFactory);
        wetc = IWETC(_wetc);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // Function to add liquidity
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        uint deadline
    ) external onlyOwner returns (uint amountA, uint amountB, uint liquidity) {
        // Approve tokens for the router contract
        require(IERC20(tokenA).approve(address(hebeSwapRouter), amountADesired), "Approval failed for token A");
        require(IERC20(tokenB).approve(address(hebeSwapRouter), amountBDesired), "Approval failed for token B");

        // Add liquidity to HebeSwap
        (amountA, amountB, liquidity) = hebeSwapRouter.addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            address(this),
            deadline
        );
        
        emit LiquidityAdded(amountA, amountB, liquidity);
    }

    // Function to swap tokens
    function swapTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        uint deadline
    ) external onlyOwner {
        // Approve the input token
        require(IERC20(path[0]).approve(address(hebeSwapRouter), amountIn), "Approval failed for swap");

        // Perform the swap
        uint[] memory amounts = hebeSwapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            deadline
        );
        
        emit TokensSwapped(amounts);
    }

    // Function to withdraw WETC
    function withdrawWETC(uint wad) external onlyOwner {
        wetc.withdraw(wad);
    }

    // Fallback function to handle ETH/WETC deposits
    receive() external payable {
        wetc.deposit{value: msg.value}();
    }

    // Function to check balance of WETC
    function getWETCBalance() external view returns (uint) {
        return wetc.balanceOf(address(this));
    }

    // Function to create a new pair on HebeSwap
    function createPair(address tokenA, address tokenB) external onlyOwner returns (address pair) {
        pair = hebeSwapFactory.createPair(tokenA, tokenB);
    }

    // Function to get pair address from HebeSwap Factory
    function getPair(address tokenA, address tokenB) external view returns (address pair) {
        pair = hebeSwapFactory.getPair(tokenA, tokenB);
    }

    // Withdraw any tokens that might have been sent to the contract by mistake
    function withdrawTokens(address token, uint amount) external onlyOwner {
        require(IERC20(token).transfer(owner, amount), "Token withdrawal failed");
    }
}

// IERC20 Token Interface
interface IERC20 {
    function transfer(address recipient, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function balanceOf(address account) external view returns (uint);
}
