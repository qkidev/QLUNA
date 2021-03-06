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

    // TODO ????????????????????????
    address public usdtAddress = 0xDF0e293CC3c7bA051763FF6b026DA0853D446E38; //?????? USDT ????????????
    address public tokenAddress = 0x8e9D8dBcAAe1F9BE5F11905b74c372aB6d033B73; //?????? qluna ????????????
    address public uniswapFactory = 0x4cB5B19e8316743519072170886355B0e2C717cF; //swap??????????????????
    address public uniswapRouter = 0x3c91FD5247B050A1536F24D012a17a618EEFbfCA; //swap????????????

    IUniswapV2Router public immutable uniswapV2Router;
    address public tokenPairAddress;

    address public owner;
    uint256 public feeRate = 30; //??????????????? feeRate / 10000
    uint256 public feeMax = 1e6; // ??????????????? ??????1QU
    uint256 public actionUserDuration = 300; //???????????????????????????
    mapping(address => uint256) public actionAt; //??????????????????

    mapping(address => bool) public whiteFrom; // ???????????????
    mapping(address => bool) public whiteTo; // ???????????????

    // staking pool
    uint256 public bonusRate = 20; // ?????????????????? ??????20
    uint256 public bonusReward; //???????????????
    uint256 public totalStaked; //?????????
    uint256 public totalMaxSupply; //usd ??????
    uint256 public lastBonusAt; // ????????????????????????
    uint256 public lastBonusEpoch = 0;
    uint256 public accRewardPerShare; //??????????????????
    uint256 public totalReward; //?????????
    uint256 public unstakeDuration = 86400 * 1; // ????????????????????? 1???

    // stake user
    // mapping(address => uint256) public rewardAt; // ????????????????????????
    mapping(address => uint256) public stakedOf; // ????????????
    mapping(address => uint256) public stakedAt; // ????????????
    mapping(address => uint256) public rewardOf; // ?????????????????????(??????????????????)
    mapping(address => uint256) public rewardRealOf; // ?????????????????????(????????????????????????)
    mapping(address => address) public rewardTo; // ????????????????????????token
    bool public rewardSwap = true; // ????????????????????????????????????
    address[] public rewardTokens; // ?????????????????? token ?????????
    uint256 public rewardTokenLength; // ?????????????????? token ???????????????
    uint256 perHourMintLimit = 1000 * 1e6;
    uint256 perHourBurnLimit = 1000 * 1e6;
    uint256 perDayMintLimit = 10000 * 1e6;
    uint256 perDayBurnLimit = 10000 * 1e6;
    mapping(uint256 => uint256) public HourMintLimit; // epoch=>????????????
    mapping(uint256 => uint256) public HourBurnLimit; // epoch=>????????????

    mapping(uint256 => uint256) public DayMintLimit; // epoch=>????????????
    mapping(uint256 => uint256) public DayBurnLimit; // epoch=>????????????

    event DailyBonus(uint256 reward, uint256 totalStaked);
    // ????????????
    event Staked(address indexed from, uint256 amount);
    // ??????????????????
    event Unstaked(address indexed from, uint256 amount);
    // ??????????????????
    event Reward(address indexed to, uint256 amount);
    // ????????????
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

        //swap????????????
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

    // ?????? rewardTokens
    function setRewardTokens(address[] memory _rewardTokens)
        public
        virtual
        onlyOwner
    {
        require(_rewardTokens.length > 0, "rewardTokens must be not empty");
        rewardTokens = _rewardTokens;
        rewardTokenLength = _rewardTokens.length;
    }

    // ?????? rewardSwap
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
        require(msg.sender != recipient); //????????????????????????

        uint256 fee = transfer_fee(msg.sender, recipient, amount);
        uint256 add_value = amount.sub(fee); //??????????????????????????????

        require(balanceOf[msg.sender] >= amount, "sender balanceOf overflows"); //???????????????????????????????????????
        require(
            balanceOf[recipient].add(add_value) >= balanceOf[recipient],
            "recipient balanceOf overflows"
        ); //Check for overflows

        //???????????????
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
        require(sender != recipient); //????????????????????????

        uint256 fee = transfer_fee(sender, recipient, amount);
        uint256 add_value = amount.sub(fee);

        require(balanceOf[sender] >= amount, "sender balanceOf overflows"); //???????????????????????????????????????
        require(
            balanceOf[recipient].add(amount) >= balanceOf[recipient],
            "recipient balanceOf overflows"
        ); //Check for overflows
        require(
            allowance[sender][msg.sender] >= amount,
            "ERC20: transfer amount exceeds allowance"
        );

        //???????????????
        distribute_fee(fee);

        balanceOf[sender] = balanceOf[sender].sub(amount); // Subtract from the sender
        balanceOf[recipient] = balanceOf[recipient].add(add_value); // Add the same to the recipient
        allowance[sender][msg.sender] = allowance[sender][msg.sender].sub(
            amount
        );

        emit Transfer(sender, recipient, add_value);
        return true;
    }

    //???????????????
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
     * ????????????usd?????????staking?????????
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
        //???????????????????????????????????????1%
        uint256 tokenLP = IERC20(tokenAddress).balanceOf(tokenPairAddress);
        uint256 maxAmount = tokenLP.div(100);
        require(tokenAmount <= maxAmount, "amount max limit error");

        uint256 beforeBalance = IERC20(tokenAddress).balanceOf(address(this));
        //????????????
        TransferHelper.safeTransferFrom(
            tokenAddress,
            msg.sender,
            address(this),
            tokenAmount
        );
        uint256 afterBalance = IERC20(tokenAddress).balanceOf(address(this));

        //?????????????????????(?????????fee???Token)
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

        //???????????????????????????????????????1%
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

    //????????????token?????????usdt??????
    function getTokenPrice(uint256 amount) public view returns (uint256) {
        return getTokenAmount(tokenAddress, amount, usdtAddress);
    }

    //????????????usdt?????????token??????
    function getUsdPrice(uint256 amount) public view returns (uint256) {
        return getTokenAmount(usdtAddress, amount, tokenAddress);
    }

    // ????????????token??????
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
        path[1] = usdtAddress; // ??????????????? usdt
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

    // ??????
    function stake(uint256 amount) public returns (bool) {
        // ???????????????1 USD????????????
        require(amount > 0, "stake must be integer multiple of 1 USD.");

        require(balanceOf[msg.sender] >= amount, "out of balance");

        _stake(msg.sender, amount);

        return true;
    }

    function _stake(address _user, uint256 _amount) internal {
        // ?????????????????????
        if (stakedOf[_user] > 0) {
            receiveReward();
        }

        balanceOf[_user] = balanceOf[_user].sub(_amount);
        // ???????????????????????????
        stakedOf[_user] = stakedOf[_user].add(_amount);
        // ????????????
        stakedAt[_user] = block.timestamp;
        // ???????????????????????????
        rewardOf[_user] = stakedOf[_user].mul(accRewardPerShare).div(1e12);
        // ?????????????????????
        totalStaked = totalStaked.add(_amount);

        // emit event
        emit Staked(_user, _amount);
        emit Transfer(_user, address(this), _amount);
    }

    //???????????????
    function distribute_fee(uint256 fee) private {
        if (fee > 0) {
            uint256 bonus = fee.mul(1).div(10).mul(9); // 90%???????????????
            bonusReward = bonusReward.add(bonus); // ?????????????????????

            balanceOf[owner] = balanceOf[owner].add(fee.sub(bonus)); // ????????????

            notifyBonusAmount(); //????????????
        }
    }

    //??????????????????
    function notifyBonusAmount() public returns (bool) {
        if (block.timestamp / 86400 > lastBonusEpoch && totalStaked > 0) {
            //???????????????????????????????????????????????????n???????????????????????????
            uint256 amount = bonusReward.div(bonusRate);
            bonusReward = bonusReward - amount;
            totalReward += amount; //???????????????
            balanceOf[address(this)] = balanceOf[address(this)].add(amount); //????????????

            accRewardPerShare = accRewardPerShare.add(
                amount.mul(1e12).div(totalStaked)
            );
            emit DailyBonus(amount, totalStaked);
            lastBonusAt = block.timestamp;
        }

        return true;
    }

    /**
     * ???????????????
     */
    function withdraw(uint256 _amount) public virtual returns (bool) {
        require(stakedOf[msg.sender] >= _amount, "Staking: out of staked");
        require(
            stakedAt[msg.sender] + unstakeDuration < block.timestamp,
            "Staking: unstakeDuration"
        );
        require(_amount > 0, "votes must be gt 0.");

        // ????????????
        receiveReward();

        totalStaked = totalStaked.sub(_amount);
        stakedOf[msg.sender] = stakedOf[msg.sender].sub(_amount);
        balanceOf[msg.sender] = balanceOf[msg.sender].add(_amount);
        // ???????????????????????????
        rewardOf[msg.sender] = stakedOf[msg.sender].mul(accRewardPerShare).div(
            1e12
        );

        emit Unstaked(msg.sender, _amount);
        emit Transfer(address(this), msg.sender, _amount);
        return true;
    }

    // ??????????????????token
    function setRewardTo(address token) public {
        require(checkInRewardTokens(token), "token not in reward tokens");
        rewardTo[msg.sender] = token;
    }

    //??????
    function receiveReward() public returns (bool) {
        // ?????????????????????????????????
        uint256 pending = rewardAmount(msg.sender);
        if (pending == 0) {
            return true;
        }

        // ???????????????????????????
        rewardOf[msg.sender] = stakedOf[msg.sender].mul(accRewardPerShare).div(
            1e12
        );
        // ??????????????????????????????
        rewardRealOf[msg.sender] = rewardRealOf[msg.sender].add(pending);
        _safeRewardTransfer(msg.sender, pending);

        emit Reward(msg.sender, pending);
        return true;
    }

    // ???????????????????????????
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

    //?????????????????????????????????
    function rewardAmount(address _user) public view returns (uint256) {
        return
            stakedOf[_user].mul(accRewardPerShare).div(1e12).sub(
                rewardOf[_user]
            );
    }

    //?????????????????????????????????(?????????oken)
    function rewardTokenAmount(address _user) public view returns (uint256) {
        uint256 amount = rewardAmount(_user);
        if (amount == 0) {
            return 0;
        }

        uint256 usdtAmount = getTokenAmount(address(this), amount, usdtAddress);
        return getTokenAmount(usdtAddress, usdtAmount, rewardTo[_user]);
    }

    //????????????
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
            // ????????????????????????
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
