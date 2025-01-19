// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.10;

import '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import '@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol';
import 'forge-std/Test.sol';
import 'forge-std/console.sol';
import 'solmate/utils/FixedPointMathLib.sol';

import 'contracts/GIVpower.sol';
import 'contracts/GardenUnipoolTokenDistributor.sol';
import './interfaces/IERC20Bridged.sol';

contract GIVpowerTest is Test {
    uint256 public constant MAX_GIV_BALANCE = 10 ** 28; // 10 Billion, Total minted giv is 1B at the moment

    ProxyAdmin gardenUnipoolProxyAdmin;
    TransparentUpgradeableProxy gardenUnipoolProxy;
    GIVpower implementation;
    GIVpower givPower;
    ITokenManager tokenManager;
    IERC20Bridged givToken;
    IERC20 gGivToken;
    address givethMultisig;

    // accounts
    address sender = address(1);
    address senderWithNoBalance = address(2);
    address omniBridge = 0xf6A78083ca3e2a662D6dd1703c939c8aCE2e268d;
    address[] testUsers = [0xB8306b6d3BA7BaB841C02f0F92b8880a4760199A, 0x975f6807E8406191D1C951331eEa4B26199b37ff];

    struct StorageData {
        address tokenManager;
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

    constructor() {
        uint256 forkId = vm.createFork('https://rpc.ankr.com/gnosis', 22501098); //https://xdai-archive.blockscout.com/
        vm.selectFork(forkId);
        gardenUnipoolProxyAdmin = ProxyAdmin(address(0x076C250700D210e6cf8A27D1EB1Fd754FB487986));
        gardenUnipoolProxy = TransparentUpgradeableProxy(payable(0xD93d3bDBa18ebcB3317a57119ea44ed2Cf41C2F2));

        // wrap in ABI to support easier calls
        givPower = GIVpower(address(gardenUnipoolProxy));

        tokenManager = ITokenManager(givPower.getTokenManager());

        givToken = IERC20Bridged(address(tokenManager.wrappableToken()));

        gGivToken = IERC20(address(tokenManager.token()));

        givethMultisig = gardenUnipoolProxyAdmin.owner();
    }

    function setUp() public virtual {
        // new implementation
        implementation = new GIVpower();

        // upgrade to new implementation
        vm.prank(givethMultisig);
        gardenUnipoolProxyAdmin.upgrade(gardenUnipoolProxy, address(implementation));

        // mint
        vm.prank(omniBridge);
        givToken.mint(sender, 100 ether);

        // labels
        vm.label(sender, 'sender');
        vm.label(senderWithNoBalance, 'senderWithNoBalance');
        vm.label(givethMultisig, 'givethMultisig');
        vm.label(address(gardenUnipoolProxyAdmin), 'ProxyAdmin');
        vm.label(address(gardenUnipoolProxy), 'Proxy');
        vm.label(address(givPower), 'GIVpower');
        vm.label(address(tokenManager), 'TokenManager');
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
            tokenManager: givPower.getTokenManager(),
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
