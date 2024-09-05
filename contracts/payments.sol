// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

interface IAgentRegistry {
    function getAgentDetails(uint256 agentId) external view returns (
        address owner,
        bool active,
        uint256 totalStaked,
        uint256 reputationScore,
        uint256 royaltyPercentage,
        string memory metadataHash,
        string memory workflowHash,
        string memory llmDetailsHash,
        string memory dataSourceHash
    );
    function distributeRoyalty(uint256 agentId, uint256 amount) external;
    function logActivity(uint256 agentId, string memory activityType, string memory activityData) external;
}

contract Payment is Initializable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    IERC20Upgradeable public coffeeToken;
    IAgentRegistry public agentRegistry;

    uint256 public protocolFeePercentage;
    uint256 public constant MAX_FEE_PERCENTAGE = 2000; // 20% in basis points
    uint256 public constant BASIS_POINTS = 10000;

    struct PaymentInfo {
        uint256 agentId;
        address payer;
        uint256 amount;
        uint256 timestamp;
    }

    struct WalletInfo {
        uint256 balance;
        uint256 totalEarned;
        uint256 totalPaid;
    }

    mapping(uint256 => PaymentInfo) public payments;
    mapping(uint256 => uint256) public agentUsageCharges;
    mapping(address => WalletInfo) public wallets;
    uint256 public paymentCount;

    event PaymentProcessed(uint256 indexed paymentId, uint256 indexed agentId, address indexed payer, uint256 amount);
    event RoyaltyDistributed(uint256 indexed paymentId, uint256 indexed agentId, uint256 amount);
    event ProtocolFeeUpdated(uint256 newFeePercentage);
    event UsageChargeSet(uint256 indexed agentId, uint256 charge);
    event FundsWithdrawn(address indexed recipient, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _coffeeTokenAddress, address _agentRegistryAddress) public initializer {
    __AccessControl_init();
    __Pausable_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(UPGRADER_ROLE, msg.sender);
    _grantRole(FEE_MANAGER_ROLE, msg.sender);

    coffeeToken = IERC20Upgradeable(_coffeeTokenAddress);
    agentRegistry = IAgentRegistry(_agentRegistryAddress);
    protocolFeePercentage = 500; // 5% initial fee
}
    function processPayment(uint256 agentId, uint256 amount) public whenNotPaused nonReentrant {
        require(amount > 0, "Payment amount must be greater than 0");

        (address agentOwner, bool active, , , uint256 royaltyPercentage, , , , ) = agentRegistry.getAgentDetails(agentId);
        require(active, "Agent is not active");

        coffeeToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 protocolFee = amount.mul(protocolFeePercentage).div(BASIS_POINTS);
        uint256 remainingAmount = amount.sub(protocolFee);
        uint256 royaltyAmount = calculateRoyaltyAmount(remainingAmount, royaltyPercentage);

        wallets[agentOwner].balance = wallets[agentOwner].balance.add(royaltyAmount);
        wallets[agentOwner].totalEarned = wallets[agentOwner].totalEarned.add(royaltyAmount);
        wallets[msg.sender].totalPaid = wallets[msg.sender].totalPaid.add(amount);

        paymentCount++;
        payments[paymentCount] = PaymentInfo({
            agentId: agentId,
            payer: msg.sender,
            amount: amount,
            timestamp: block.timestamp
        });

        emit PaymentProcessed(paymentCount, agentId, msg.sender, amount);
        distributeRoyalty(agentId, royaltyAmount);

        agentRegistry.logActivity(agentId, "payment_received", string(abi.encodePacked("Payment ID: ", uintToString(paymentCount))));
    }

    function calculateRoyaltyAmount(uint256 amount, uint256 royaltyPercentage) public pure returns (uint256) {
        return amount.mul(royaltyPercentage).div(BASIS_POINTS);
    }

    function distributeRoyalty(uint256 agentId, uint256 royaltyAmount) internal {
        agentRegistry.distributeRoyalty(agentId, royaltyAmount);
        emit RoyaltyDistributed(paymentCount, agentId, royaltyAmount);
    }

    function setUsageCharge(uint256 agentId, uint256 charge) public whenNotPaused {
        (address agentOwner, bool active, , , , , , , ) = agentRegistry.getAgentDetails(agentId);
        require(msg.sender == agentOwner || hasRole(FEE_MANAGER_ROLE, msg.sender), "Not authorized");
        require(active, "Agent is not active");

        agentUsageCharges[agentId] = charge;
        emit UsageChargeSet(agentId, charge);
    }

    function getWalletInfo(address user) public view returns (WalletInfo memory) {
        return wallets[user];
    }

    function getWalletBalance(address user) public view returns (uint256) {
        return wallets[user].balance;
    }

    function requestPayment(uint256 agentId) public view returns (uint256) {
        return agentUsageCharges[agentId];
    }

    function withdrawFunds(uint256 amount) public whenNotPaused nonReentrant {
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(wallets[msg.sender].balance >= amount, "Insufficient balance");

        wallets[msg.sender].balance = wallets[msg.sender].balance.sub(amount);
        coffeeToken.safeTransfer(msg.sender, amount);

        emit FundsWithdrawn(msg.sender, amount);
    }

    function updateProtocolFee(uint256 newFeePercentage) public onlyRole(FEE_MANAGER_ROLE) {
        require(newFeePercentage <= MAX_FEE_PERCENTAGE, "Fee percentage too high");
        protocolFeePercentage = newFeePercentage;
        emit ProtocolFeeUpdated(newFeePercentage);
    }

    function getPaymentDetails(uint256 paymentId) public view returns (uint256 agentId, address payer, uint256 amount, uint256 timestamp) {
        PaymentInfo storage payment = payments[paymentId];
        return (payment.agentId, payment.payer, payment.amount, payment.timestamp);
    }

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}
}