// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import 'solmate/utils/FixedPointMathLib.sol';
import '../../contracts/UnipoolGIVpower.sol';
import '../../contracts/UnipoolTokenDistributor.sol';
import '../interfaces/IL2StandardERC20.sol';

contract UnipoolGIVpowerTest is Test {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public constant MAX_GIV_BALANCE = 10 ** 28; // 10 Billion, Total minted giv is 1B at the moment

    UnipoolGIVpower implementation;
    UnipoolGIVpower givPower;
    ProxyAdmin unipoolGIVpowerProxyAdmin;
    TransparentUpgradeableProxy unipoolGIVpowerProxy;
    IERC20Upgradeable givToken;
    IL2StandardERC20 bridgedGivToken;
    IERC20 gGivToken;
    address givethMultisig = 0x4D9339dd97db55e3B9bCBE65dE39fF9c04d1C2cd;
    IDistro iDistro = IDistro(0xE3Ac7b3e6B4065f4765d76fDC215606483BF3bD1);
    ProxyAdmin masterProxyAdmin = ProxyAdmin(0x2f2c819210191750F2E11F7CfC5664a0eB4fd5e6);
    address rewardDistributor = address(uint160(1));

    // token
    address givTokenAddressOptimism = 0x528CDc92eAB044E1E39FE43B9514bfdAB4412B98;

    // bridge
    address optimismL2Bridge = 0x4200000000000000000000000000000000000010;

    // accounts
    address sender = address(1);
    address senderWithNoBalance = address(2);
    address proxyAdminAddress = address(3);
    address[] testUsers = [0xB8306b6d3BA7BaB841C02f0F92b8880a4760199A, 0x975f6807E8406191D1C951331eEa4B26199b37ff];

    struct StorageData {
        address tokenDistro;
        uint256 duration;
        address rewardDistribution;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        uint256 totalSupply;
        uint256[] usersBalances;
        uint256[] usersRewardsPerTokenPaid;
        uint256[] usersRewards;
    }

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event TokenLocked(address indexed account, uint256 amount, uint256 rounds, uint256 untilRound);
    event TokenUnlocked(address indexed account, uint256 amount, uint256 round);
    event DepositTokenDeposited(address indexed account, uint256 amount);
    event DepositTokenWithdrawn(address indexed account, uint256 amount);

    constructor() {
        uint256 forkId = vm.createFork('https://mainnet.optimism.io');
        vm.selectFork(forkId);
        // wrap in ABI to support easier calls
    }

    function setUp() public virtual {
        givToken = IERC20Upgradeable(givTokenAddressOptimism);
        bridgedGivToken = IL2StandardERC20(givTokenAddressOptimism);
        // new implementation
        implementation = new UnipoolGIVpower();
        unipoolGIVpowerProxy = new TransparentUpgradeableProxy(
            payable(address(implementation)),
            address(masterProxyAdmin),
            abi.encodeWithSelector(UnipoolGIVpower(givPower).initialize.selector, iDistro, givToken, 14 days)
        );
        givPower = UnipoolGIVpower(address(unipoolGIVpowerProxy));
        givPower.setRewardDistribution(rewardDistributor);

        // mint
        vm.prank(optimismL2Bridge);
        bridgedGivToken.mint(sender, 100 ether);

        // labels
        vm.label(sender, 'sender');
        vm.label(senderWithNoBalance, 'senderWithNoBalance');
        vm.label(givethMultisig, 'givethMultisig');
        vm.label(address(unipoolGIVpowerProxyAdmin), 'ProxyAdmin');
        vm.label(address(unipoolGIVpowerProxy), 'Proxy');
        vm.label(address(givPower), 'GIVpower');
        vm.label(address(givToken), 'GivethToken');
        vm.label(address(gGivToken), 'gGivToken');
    }

    function getImplementationStorageData(address[] memory _users) public view returns (StorageData memory) {
        uint256[] memory usersBalances = new uint256[](_users.length);
        uint256[] memory usersRewardsPerTokenPaid = new uint256[](_users.length);
        uint256[] memory usersRewards = new uint256[](_users.length);

        for (uint256 i = 0; i < _users.length; i++) {
            usersBalances[i] = givPower.balanceOf(_users[i]);
            usersRewardsPerTokenPaid[i] = givPower.userRewardPerTokenPaid(_users[i]);
            usersRewards[i] = givPower.rewards(_users[i]);
        }

        return StorageData({
            tokenDistro: address(givPower.tokenDistro()),
            duration: givPower.duration(),
            rewardDistribution: givPower.rewardDistribution(),
            periodFinish: givPower.periodFinish(),
            rewardRate: givPower.rewardRate(),
            lastUpdateTime: givPower.lastUpdateTime(),
            rewardPerTokenStored: givPower.rewardPerTokenStored(),
            totalSupply: givPower.totalSupply(),
            usersBalances: usersBalances,
            usersRewardsPerTokenPaid: usersRewardsPerTokenPaid,
            usersRewards: usersRewards
        });
    }

    function roundHasStartedInSeconds() public view returns (uint256) {
        return (block.timestamp - givPower.INITIAL_DATE()) % 14 days;
    }
}
