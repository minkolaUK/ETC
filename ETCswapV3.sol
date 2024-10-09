// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

// IHebeSwapRouter Interface for the ETCswap
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

// IHebeSwapFactory Interface for the ETCswap
interface IHebeSwapFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

// WETC Interface
interface IWETC {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function transfer(address to, uint value) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
}

// ERC20 Token Interface
interface IERC20 {
    function transfer(address recipient, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    function balanceOf(address account) external view returns (uint);
}

contract HebeSwapBot {
    address public owner;
    IHebeSwapRouter public hebeSwapRouter;
    IHebeSwapFactory public hebeSwapFactory;
    IWETC public wetc;
    address public usc; // Address for USC token

    event LiquidityAdded(uint amountA, uint amountB, uint liquidity);
    event TokensSwapped(uint[] amounts);

    constructor() public {
        owner = msg.sender;
        hebeSwapRouter = IHebeSwapRouter(0x9b676E761040D60C6939dcf5f582c2A4B51025F1); // UniversalRouter
        hebeSwapFactory = IHebeSwapFactory(0xE7F43da4Dff1eF4321f6AA3485B825a57A97C772); // ETCswapV3Pool
        wetc = IWETC(0x82A618305706B14e7bcf2592D4B9324A366b6dAd); // WETC
        usc = 0xDE093684c796204224BC081f937aa059D903c52a; // USC (Classic USD)
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // Function to add liquidity for WETC/USC
    function addLiquidity(
        uint amountWETCDesired,
        uint amountUSCDesired,
        uint amountWETCMin,
        uint amountUSCMin,
        uint deadline
    ) external onlyOwner returns (uint amountWETC, uint amountUSC, uint liquidity) {
        // Approve tokens for the router contract
        require(IERC20(address(wetc)).approve(address(hebeSwapRouter), amountWETCDesired), "Approval failed for WETC");
        require(IERC20(usc).approve(address(hebeSwapRouter), amountUSCDesired), "Approval failed for USC");

        // Add liquidity to HebeSwap
        (amountWETC, amountUSC, liquidity) = hebeSwapRouter.addLiquidity(
            address(wetc),
            usc,
            amountWETCDesired,
            amountUSCDesired,
            amountWETCMin,
            amountUSCMin,
            address(this),
            deadline
        );

        emit LiquidityAdded(amountWETC, amountUSC, liquidity);
    }

    // Function to swap WETC for USC
    function swapWETCForUSC(
        uint amountIn,
        uint amountOutMin,
        uint deadline
    ) external onlyOwner {
        address[] memory path = new address[](2);
        path[0] = address(wetc);
        path[1] = usc;

        // Approve the input token
        require(IERC20(address(wetc)).approve(address(hebeSwapRouter), amountIn), "Approval failed for swap");

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
