// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function owner() external view returns (address);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address holder, address spender)
        external
        view
        returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed holder,
        address indexed spender,
        uint256 value
    );
}

interface IUniswapV2Router {
    function factory() external pure returns (address);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

// pragma solidity >=0.5.0;
interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
    
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

library TransferHelper {
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: TRANSFER_FAILED"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: TRANSFER_FROM_FAILED"
        );
    }

    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper: APPROVE_FAILED"
        );
    }
}

contract UST {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    uint8 public decimals = 6;
    uint256 public totalSupply = 0;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // TODO 正式环境修改配置
    address public usdtAddress = 0xDF0e293CC3c7bA051763FF6b026DA0853D446E38; //本链 USDT 合约地址
    address public tokenAddress = 0x8e9D8dBcAAe1F9BE5F11905b74c372aB6d033B73; //本链 qluna 合约地址
    address public uniswapFactory = 0x4cB5B19e8316743519072170886355B0e2C717cF; //swap工厂合约地址
    address public uniswapRouter = 0x3c91FD5247B050A1536F24D012a17a618EEFbfCA; //swap路由地址

    IUniswapV2Router public immutable uniswapV2Router;
    address public tokenPairAddress;

    address public owner;
    uint256 public feeRate = 30; //转账手续费 feeRate / 10000
    uint256 public feeMax = 1e6; // 最高手续费 默认1QU
    uint256 public actionUserDuration = 300; //单地址活动间隔时间
    mapping(address => uint256) public actionAt; //上次活动时间

    mapping(address => bool) public whiteFrom; // 转出白名单
    mapping(address => bool) public whiteTo; // 转入白名单

    // staking pool
    uint256 public bonusRate = 20; // 分红比例分母 默认20
    uint256 public bonusReward; //待分红奖励
    uint256 public totalStaked; //总质押
    uint256 public totalMaxSupply; //usd 上限
    uint256 public lastBonusAt; // 上次分红奖励时间
    uint256 public lastBonusEpoch = 0;
    uint256 public accRewardPerShare; //全局每股分红
    uint256 public totalReward; //总分红
    uint256 public unstakeDuration = 86400 * 1; // 质押物解锁周期 1天

    // stake user
    // mapping(address => uint256) public rewardAt; // 上次领取奖励时间
    mapping(address => uint256) public stakedOf; // 质押数量
    mapping(address => uint256) public stakedAt; // 质押时间
    mapping(address => uint256) public rewardOf; // 已领取奖励数量(随股份初始化)
    mapping(address => uint256) public rewardRealOf; // 已领取奖励数量(实际已经领取数量)
    mapping(address => address) public rewardTo; // 用户领取奖励默认token
    bool public rewardSwap = true; // 用户领取奖励是否自动转换
    address[] public rewardTokens; // 领取奖励换算 token 白名单
    uint256 public rewardTokenLength; // 领取奖励换算 token 白名单长度
    uint256 perHourMintLimit = 1000 * 1e6;
    uint256 perHourBurnLimit = 1000 * 1e6;
    uint256 perDayMintLimit = 10000 * 1e6;
    uint256 perDayBurnLimit = 10000 * 1e6;
    mapping(uint256 => uint256) public HourMintLimit; // epoch=>已用额度
    mapping(uint256 => uint256) public HourBurnLimit; // epoch=>已用额度

    mapping(uint256 => uint256) public DayMintLimit; // epoch=>已用额度
    mapping(uint256 => uint256) public DayBurnLimit; // epoch=>已用额度

    event DailyBonus(uint256 reward, uint256 totalStaked);
    // 质押事件
    event Staked(address indexed from, uint256 amount);
    // 取消质押事件
    event Unstaked(address indexed from, uint256 amount);
    // 领取奖励事件
    event Reward(address indexed to, uint256 amount);
    // 提现事件
    event Withdraw(address indexed to, uint256 amount);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
        owner = msg.sender;

        //swap路由地址
        IUniswapV2Router _uniswapV2Router = IUniswapV2Router(uniswapRouter);

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        tokenPairAddress = IUniswapV2Factory(uniswapFactory).getPair(
            tokenAddress,
            usdtAddress
        );

        setWhiteFrom(address(this), true);
        setWhiteTo(address(this), true);
        setWhiteFrom(owner, true);
        setWhiteTo(owner, true);

        allowance[address(this)][uniswapRouter] = ~uint256(0);
        TransferHelper.safeApprove(usdtAddress, uniswapRouter, ~uint256(0));
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "caller is not the owner");
        _;
    }

    function setOwner(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "new owner is the zero address");
        owner = newOwner;
    }

    function setTotalMaxSupply(uint256 amount) public virtual onlyOwner {
        totalMaxSupply = amount;
    }

    function setperHourMintLimit(uint256 amount) public virtual onlyOwner {
        perHourMintLimit = amount;
    }

    function setperDayMintLimit(uint256 amount) public virtual onlyOwner {
        perDayMintLimit = amount;
    }

    function setperHourBurnLimit(uint256 amount) public virtual onlyOwner {
        perHourBurnLimit = amount;
    }

    function setperDayBurnLimit(uint256 amount) public virtual onlyOwner {
        perDayBurnLimit = amount;
    }

    function setWhiteFrom(address _address, bool state)
        public
        virtual
        onlyOwner
    {
        whiteFrom[_address] = state;
    }

    function setWhiteTo(address _address, bool state) public virtual onlyOwner {
        whiteTo[_address] = state;
    }

    function setBonusRate(uint256 rate) public virtual onlyOwner {
        require(rate > 0, "bonus rate must big than 0");
        bonusRate = rate;
    }

    function setFeeRate(uint256 amount) public virtual onlyOwner {
        require(amount <= 100);
        feeRate = amount;
    }

    function setFeeMax(uint256 amount) public virtual onlyOwner {
        feeMax = amount;
    }

    // 设置 rewardTokens
    function setRewardTokens(address[] memory _rewardTokens)
        public
        virtual
        onlyOwner
    {
        require(_rewardTokens.length > 0, "rewardTokens must be not empty");
        rewardTokens = _rewardTokens;
        rewardTokenLength = _rewardTokens.length;
    }

    // 设置 rewardSwap
    function setRewardSwap(bool _rewardSwap)
        public
        virtual
        onlyOwner
    {
        rewardSwap = _rewardSwap;
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        returns (bool)
    {
        require(recipient != address(0)); // Prevent transfer to 0x0 address. Use burn() instead
        require(amount > 0, "amount error");
        require(msg.sender != recipient); //自己不能转给自己

        uint256 fee = transfer_fee(msg.sender, recipient, amount);
        uint256 add_value = amount.sub(fee); //扣除手续费后实际到账

        require(balanceOf[msg.sender] >= amount, "sender balanceOf overflows"); //需要计算加上手续费后是否够
        require(
            balanceOf[recipient].add(add_value) >= balanceOf[recipient],
            "recipient balanceOf overflows"
        ); //Check for overflows

        //分配手续费
        distribute_fee(fee);

        balanceOf[msg.sender] = balanceOf[msg.sender].sub(amount);
        balanceOf[recipient] = balanceOf[recipient].add(add_value);

        emit Transfer(msg.sender, recipient, add_value);
        return true;
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual returns (bool) {
        require(recipient != address(0)); // Prevent transfer to 0x0 address. Use burn() instead
        require(amount > 0, "amount error");
        require(sender != recipient); //自己不能转给自己

        uint256 fee = transfer_fee(sender, recipient, amount);
        uint256 add_value = amount.sub(fee);

        require(balanceOf[sender] >= amount, "sender balanceOf overflows"); //需要计算加上手续费后是否够
        require(
            balanceOf[recipient].add(amount) >= balanceOf[recipient],
            "recipient balanceOf overflows"
        ); //Check for overflows
        require(
            allowance[sender][msg.sender] >= amount,
            "ERC20: transfer amount exceeds allowance"
        );

        //分配手续费
        distribute_fee(fee);

        balanceOf[sender] = balanceOf[sender].sub(amount); // Subtract from the sender
        balanceOf[recipient] = balanceOf[recipient].add(add_value); // Add the same to the recipient
        allowance[sender][msg.sender] = allowance[sender][msg.sender].sub(
            amount
        );

        emit Transfer(sender, recipient, add_value);
        return true;
    }

    //计算手续费
    function transfer_fee(
        address _from,
        address _to,
        uint256 _value
    ) public view returns (uint256) {
        if (whiteFrom[_from]) {
            return 0;
        }

        if (whiteTo[_to]) {
            return 0;
        }

        uint256 _fee = _value.mul(feeRate).div(10000);
        if (_fee > feeMax) _fee = feeMax;
        return _fee;
    }

    /**
     * 把一定的usd空投给staking的用户
     */
    function airdrop(uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "sender balanceOf overflows");

        balanceOf[msg.sender] -= amount;
        bonusReward = bonusReward.add(amount);
        emit Transfer(msg.sender, address(this), amount);
        return true;
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = balanceOf[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        balanceOf[account] = accountBalance - amount;
        totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function mintUsd(uint256 tokenAmount) public {
        //单次铸币数量不超过流动池的1%
        uint256 tokenLP = IERC20(tokenAddress).balanceOf(tokenPairAddress);
        uint256 maxAmount = tokenLP.div(100);
        require(tokenAmount <= maxAmount, "amount max limit error");

        uint256 beforeBalance = IERC20(tokenAddress).balanceOf(address(this));
        //转入资产
        TransferHelper.safeTransferFrom(
            tokenAddress,
            msg.sender,
            address(this),
            tokenAmount
        );
        uint256 afterBalance = IERC20(tokenAddress).balanceOf(address(this));

        //确切的转入金额(防止有fee的Token)
        uint256 amount = afterBalance.sub(beforeBalance);
        require(amount > 0, "amount error");
        uint256 usdtAmount = getTokenPrice(amount);
        require(usdtAmount > 0, "usdt amount error");
        require(
            usdtAmount + totalSupply <= totalMaxSupply,
            "out totalMaxSupply"
        );
        uint256 epoch_day = block.timestamp / 86400;
        uint256 epoch_hour = block.timestamp / 3600;
        require(
            usdtAmount + HourMintLimit[epoch_hour] <= perHourMintLimit,
            "out perHourMintLimit"
        );
        require(
            usdtAmount + DayMintLimit[epoch_day] <= perDayMintLimit,
            "out perDayMintLimit"
        );
        HourMintLimit[epoch_hour] += usdtAmount;
        DayMintLimit[epoch_day] += usdtAmount;

        _mint(msg.sender, usdtAmount);
    }

    // usd=>token
    function burnUsd(uint256 usdAmount) public {
        uint256 tokenAmount = getUsdPrice(usdAmount);
        require(tokenAmount <= IERC20(usdtAddress).balanceOf(address(this)));
        require(tokenAmount > 0, "token amount error");

        //单次铸币数量不超过流动池的1%
        uint256 tokenLP = IERC20(usdtAddress).balanceOf(tokenPairAddress);
        uint256 maxAmount = tokenLP.div(100);
        require(usdAmount <= maxAmount, "amount max limit error");

        uint256 epoch_day = block.timestamp / 86400;
        uint256 epoch_hour = block.timestamp / 3600;
        require(
            usdAmount + HourBurnLimit[epoch_hour] <= perHourBurnLimit,
            "out perHourMintLimit"
        );
        require(
            usdAmount + DayBurnLimit[epoch_day] <= perDayBurnLimit,
            "out perDayMintLimit"
        );
        HourBurnLimit[epoch_hour] += usdAmount;
        DayBurnLimit[epoch_day] += usdAmount;

        _burn(msg.sender, usdAmount);
        TransferHelper.safeTransfer(tokenAddress, msg.sender, tokenAmount);
    }

    //计算输入token兑换的usdt数量
    function getTokenPrice(uint256 amount) public view returns (uint256) {
        return getTokenAmount(tokenAddress, amount, usdtAddress);
    }

    //计算输入usdt兑换的token数量
    function getUsdPrice(uint256 amount) public view returns (uint256) {
        return getTokenAmount(usdtAddress, amount, tokenAddress);
    }

    // 计算兑换token数量
    function getTokenAmount(
        address inToken,
        uint256 inAmount,
        address outToken
    ) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = inToken;
        path[1] = outToken;
        uint256[] memory amounts = uniswapV2Router.getAmountsOut(
            inAmount,
            path
        );
        return amounts[1];
    }

    function swapToken(
        address inToken,
        uint256 inAmount,
        address outToken,
        address to
    ) private {
        address[] memory path = new address[](3);
        path[0] = inToken;
        path[1] = usdtAddress; // 固定跳一层 usdt
        path[2] = outToken;

        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            inAmount,
            0, // accept any amount of ETH
            path,
            to,
            block.timestamp
        );
    }

    // 质押
    function stake(uint256 amount) public returns (bool) {
        // 数量必须是1 USD的整数倍
        require(amount > 0, "stake must be integer multiple of 1 USD.");

        require(balanceOf[msg.sender] >= amount, "out of balance");

        _stake(msg.sender, amount);

        return true;
    }

    function _stake(address _user, uint256 _amount) internal {
        // 领取之前的奖励
        if (stakedOf[_user] > 0) {
            receiveReward();
        }

        balanceOf[_user] = balanceOf[_user].sub(_amount);
        // 更新用户质押的数量
        stakedOf[_user] = stakedOf[_user].add(_amount);
        // 质押时间
        stakedAt[_user] = block.timestamp;
        // 更新已经领取的奖励
        rewardOf[_user] = stakedOf[_user].mul(accRewardPerShare).div(1e12);
        // 更新池子总票数
        totalStaked = totalStaked.add(_amount);

        // emit event
        emit Staked(_user, _amount);
        emit Transfer(_user, address(this), _amount);
    }

    //分配手续费
    function distribute_fee(uint256 fee) private {
        if (fee > 0) {
            uint256 bonus = fee.mul(1).div(10).mul(9); // 90%奖励费用户
            bonusReward = bonusReward.add(bonus); // 累计待分红奖励

            balanceOf[owner] = balanceOf[owner].add(fee.sub(bonus)); // 团队奖励

            notifyBonusAmount(); //更新分红
        }
    }

    //更新质押奖励
    function notifyBonusAmount() public returns (bool) {
        if (block.timestamp / 86400 > lastBonusEpoch && totalStaked > 0) {
            //将待分红奖励划入分红余额，分红池按n天分红，分红更线性
            uint256 amount = bonusReward.div(bonusRate);
            bonusReward = bonusReward - amount;
            totalReward += amount; //记录总分红
            balanceOf[address(this)] = balanceOf[address(this)].add(amount); //分红地址

            accRewardPerShare = accRewardPerShare.add(
                amount.mul(1e12).div(totalStaked)
            );
            emit DailyBonus(amount, totalStaked);
            lastBonusAt = block.timestamp;
        }

        return true;
    }

    /**
     * 提取质押物
     */
    function withdraw(uint256 _amount) public virtual returns (bool) {
        require(stakedOf[msg.sender] >= _amount, "Staking: out of staked");
        require(
            stakedAt[msg.sender] + unstakeDuration < block.timestamp,
            "Staking: unstakeDuration"
        );
        require(_amount > 0, "votes must be gt 0.");

        // 领取奖励
        receiveReward();

        totalStaked = totalStaked.sub(_amount);
        stakedOf[msg.sender] = stakedOf[msg.sender].sub(_amount);
        balanceOf[msg.sender] = balanceOf[msg.sender].add(_amount);
        // 更新已经领取的奖励
        rewardOf[msg.sender] = stakedOf[msg.sender].mul(accRewardPerShare).div(
            1e12
        );

        emit Unstaked(msg.sender, _amount);
        emit Transfer(address(this), msg.sender, _amount);
        return true;
    }

    // 用户设置奖励token
    function setRewardTo(address token) public {
        require(checkInRewardTokens(token), "token not in reward tokens");
        rewardTo[msg.sender] = token;
    }

    //领奖
    function receiveReward() public returns (bool) {
        // 计算并将奖励发送给用户
        uint256 pending = rewardAmount(msg.sender);
        if (pending == 0) {
            return true;
        }

        // 更新已经领取的奖励
        rewardOf[msg.sender] = stakedOf[msg.sender].mul(accRewardPerShare).div(
            1e12
        );
        // 累计真实已经领取数量
        rewardRealOf[msg.sender] = rewardRealOf[msg.sender].add(pending);
        _safeRewardTransfer(msg.sender, pending);

        emit Reward(msg.sender, pending);
        return true;
    }

    // 检查是否在白名单中
    function checkInRewardTokens(address token) public view returns (bool) {
        bool result = false;
        for (uint256 index = 0; index < rewardTokens.length; index++) {
            if (rewardTokens[index] == token) {
                result = true;
                break;
            }
        }

        return result;
    }

    //查询是否有可领取的奖励
    function rewardAmount(address _user) public view returns (uint256) {
        return
            stakedOf[_user].mul(accRewardPerShare).div(1e12).sub(
                rewardOf[_user]
            );
    }

    //查询是否有可领取的奖励(转换成oken)
    function rewardTokenAmount(address _user) public view returns (uint256) {
        uint256 amount = rewardAmount(_user);
        if (amount == 0) {
            return 0;
        }

        uint256 usdtAmount = getTokenAmount(address(this), amount, usdtAddress);
        return getTokenAmount(usdtAddress, usdtAmount, rewardTo[_user]);
    }

    //发放奖励
    function _safeRewardTransfer(address _user, uint256 _reward) internal {
        uint256 amount = _reward;
        uint256 totalBonus = balanceOf[address(this)];

        if (_reward > totalBonus) {
            amount = totalBonus;
        }

        if (rewardSwap) {
            require(checkInRewardTokens(rewardTo[_user]), "out of reward tokens");
            balanceOf[address(this)] -= amount;
            balanceOf[_user] += amount;
            emit Transfer(address(this), _user, amount);
        } else {
            uint256 before = IERC20(rewardTo[_user]).balanceOf(_user);
            // 交易所兑换给用户
            swapToken(address(this), amount, rewardTo[_user], _user);
            uint256 diff = IERC20(rewardTo[_user]).balanceOf(_user).sub(before);

            require(diff > 0, "reward transfer failed");
        }
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 amount
    ) internal virtual {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        allowance[_owner][_spender] = amount;
        emit Approval(_owner, _spender, amount);
    }
}
