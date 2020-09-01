pragma solidity ^0.6.7;

import "./FarmerToken.sol";

interface IMasterChef {
    function poolInfo(uint256 _pid) external view returns (address, uint256, uint256, uint256);
    function userInfo(uint256 _pid, address user) external view returns (uint256, uint256);
    // Deposit LP tokens to MasterChef for SUSHI allocation.
    function deposit(uint256 _pid, uint256 _amount) external;
    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external;
    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external;
}

interface IUniswapRouter {
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
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IUniswapFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

contract SushiFisher is FishermanERC20 {
    uint256 pid;
    IERC20 token;
    IERC20 univ2;
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 sushi = IERC20(0x6B3595068778DD592e39A122f4f5a5cF09C90fE2);
    IMasterChef chef = IMasterChef(0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd);
    IUniswapRouter router = IUniswapRouter(0xf164fC0Ec4E93095b804a4795bBe1e041497b92a);
    IUniswapFactory factory = IUniswapFactory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    constructor(address _token, uint256 _pid) public {
        (address _lpt,,,) = chef.poolInfo(_pid);
        require(_lpt == _token, "tokens don't match");
        pid = _pid;
        token = IERC20(token);
        univ2 = IERC20(factory.getPair(_token, address(weth)));
        univ2.approve(address(chef), uint(-1));
        sushi.approve(address(router), uint(-1));
    }

    // Add TOKEN/ETH UniV2 liquidity tokens
    function join(uint256 amount) public {
        require(univ2.transferFrom(msg.sender, address(this), amount), "transfer from failed");
        (uint256 currentlyStaked,) = chef.userInfo(pid, address(this));
        uint256 liquidity = 0;
        if (currentlyStaked == 0) {
            liquidity = amount;
        } else {
            liquidity = amount.mul(totalSupply) / currentlyStaked;
        }
        require(liquidity > 0, 'no tokens minted');
        _mint(msg.sender, liquidity);

        chef.deposit(pid, amount);

        // Only do this when over 100 sushi tokens
        if (sushi.balanceOf(address(this)) > 100000000000000000000) {
            sellSushiJoinUni();
        }
    }

    function join() public {
        join(univ2.balanceOf(msg.sender));
    }

    function exit(uint256 amount) public {
        _burn(msg.sender, amount);
        (uint256 currentlyStaked,) = chef.userInfo(pid, address(this));
        require(currentlyStaked > 0, "uh oh this is bad");
        uint256 underlying = 0;
        underlying = amount.mul(currentlyStaked) / totalSupply;
        require(underlying > 0, 'no tokens staked');

        chef.withdraw(pid, underlying);
        univ2.transfer(msg.sender, underlying);

        // Only do this when over 100 sushi tokens
        if (sushi.balanceOf(address(this)) > 100000000000000000000) {
            sellSushiJoinUni();
        }
    }

    function exit() public {
        exit(balanceOf[msg.sender]);
    }

    function sellSushiJoinUni() internal {
        address[] memory path1; 
        path1[0] = address(sushi);
        path1[1] = address(weth);
        path1[2] = address(token);
        address[] memory path2;
        path2[0] = address(sushi);
        path2[1] = address(weth);

        // Sell half the sushi for weth and half for yfi
        // Slippage should be negligable so we do not care about amountOutMin
        router.swapExactTokensForTokens(sushi.balanceOf(address(this)) / 2, 0, path1, address(this), block.timestamp);
        router.swapExactTokensForTokens(sushi.balanceOf(address(this)) / 2, 0, path2, address(this), block.timestamp);
        // We do not care about mins again
        router.addLiquidity(address(weth), address(token), weth.balanceOf(address(this)), token.balanceOf(address(this)), 0, 0, address(this), block.timestamp);
        chef.deposit(pid, univ2.balanceOf(address(this)));
    }

    function finish() public {
        require(totalSupply == 0, "there are tokens");
        (uint256 currentlyStaked,) = chef.userInfo(pid, address(this));
        chef.withdraw(pid, currentlyStaked);
        sushi.transfer(msg.sender, sushi.balanceOf(address(this)));
        token.transfer(msg.sender, token.balanceOf(address(this)));
        weth.transfer(msg.sender, weth.balanceOf(address(this)));
        univ2.transfer(msg.sender, univ2.balanceOf(address(this)));
    }

}
