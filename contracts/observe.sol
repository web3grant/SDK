// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

interface IAgentRegistry {
    function setAgentActive(uint256 agentId, bool active) external;
    function logActivity(uint256 agentId, string memory activityType, string memory activityData) external;
}

contract Governance is Initializable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeMathUpgradeable for uint256;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    IAgentRegistry public agentRegistry;

    struct SafeguardParams {
        uint256 maxDailyRequests;
        uint256 maxBudget;
        bool requireHumanApproval;
        uint256 maxTokensPerRequest;
    }

    struct BudgetInfo {
        uint256 totalBudget;
        uint256 spentBudget;
        uint256 lastResetTimestamp;
    }

    struct AgentStats {
        uint256 totalRequests;
        uint256 totalInstances;
        uint256 lastRequestTimestamp;
        uint256 totalTokensRequested;
        uint256 totalTokensResponded;
    }

    mapping(uint256 => SafeguardParams) private _agentSafeguards;
    mapping(uint256 => BudgetInfo) private _agentBudgets;
    mapping(uint256 => AgentStats) private _agentStats;

    event SafeguardSet(uint256 indexed agentId, uint256 maxDailyRequests, uint256 maxBudget, bool requireHumanApproval, uint256 maxTokensPerRequest);
    event ActionApproved(uint256 indexed agentId, string action, address approver);
    event SafeguardTriggered(uint256 indexed agentId, string reason);
    event AgentPaused(uint256 indexed agentId);
    event BudgetSet(uint256 indexed agentId, uint256 totalBudget);
    event BudgetSpent(uint256 indexed agentId, uint256 amount);
    event MetadataLogged(uint256 indexed agentId, string ipfsHash);
    event AgentActionRecorded(uint256 indexed agentId, uint256 tokensRequested, uint256 tokensResponded, bool isNewInstance);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _agentRegistryAddress) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(GOVERNANCE_ROLE, msg.sender);

        agentRegistry = IAgentRegistry(_agentRegistryAddress);
    }

    function setSafeguards(
        uint256 agentId,
        uint256 maxDailyRequests,
        uint256 maxBudget,
        bool requireHumanApproval,
        uint256 maxTokensPerRequest
    ) public onlyRole(GOVERNANCE_ROLE) {
        _agentSafeguards[agentId] = SafeguardParams({
            maxDailyRequests: maxDailyRequests,
            maxBudget: maxBudget,
            requireHumanApproval: requireHumanApproval,
            maxTokensPerRequest: maxTokensPerRequest
        });

        emit SafeguardSet(agentId, maxDailyRequests, maxBudget, requireHumanApproval, maxTokensPerRequest);
    }

    function approveAction(uint256 agentId, string memory action) public onlyRole(GOVERNANCE_ROLE) {
        emit ActionApproved(agentId, action, msg.sender);
    }

    function pauseAgent(uint256 agentId) public onlyRole(GOVERNANCE_ROLE) {
        agentRegistry.setAgentActive(agentId, false);
        emit AgentPaused(agentId);
    }

    function recordAgentAction(
        uint256 agentId,
        uint256 cost,
        uint256 tokensRequested,
        uint256 tokensResponded,
        bool isNewInstance
    ) public onlyRole(GOVERNANCE_ROLE) {
        require(_checkSafeguards(agentId, cost, tokensRequested, tokensResponded), "Safeguard check failed");

        _updateAgentStats(agentId, isNewInstance, tokensRequested, tokensResponded);
        _updateBudget(agentId, cost);

        agentRegistry.logActivity(agentId, "agent_action", "");
        emit AgentActionRecorded(agentId, tokensRequested, tokensResponded, isNewInstance);
    }

    function setBudget(uint256 agentId, uint256 totalBudget) public onlyRole(GOVERNANCE_ROLE) {
        _agentBudgets[agentId].totalBudget = totalBudget;
        _agentBudgets[agentId].spentBudget = 0;
        _agentBudgets[agentId].lastResetTimestamp = block.timestamp;

        emit BudgetSet(agentId, totalBudget);
    }

    function logMetadata(uint256 agentId, string memory ipfsHash) public onlyRole(GOVERNANCE_ROLE) {
        emit MetadataLogged(agentId, ipfsHash);
    }

    function _checkSafeguards(uint256 agentId, uint256 cost, uint256 tokensRequested, uint256 tokensResponded) internal view returns (bool) {
        SafeguardParams storage safeguards = _agentSafeguards[agentId];
        BudgetInfo storage budget = _agentBudgets[agentId];
        AgentStats storage stats = _agentStats[agentId];
        
        if (stats.totalRequests >= safeguards.maxDailyRequests && 
            block.timestamp - stats.lastRequestTimestamp < 1 days) {
            return false;
        }
        
        if (budget.spentBudget.add(cost) > budget.totalBudget) {
            return false;
        }
        
        if (tokensRequested > safeguards.maxTokensPerRequest || tokensResponded > safeguards.maxTokensPerRequest) {
            return false;
        }
        
        if (safeguards.requireHumanApproval) {
            // Implement human approval logic here
            // For now, we'll assume it's always approved
        }
        
        return true;
    }

    function _updateAgentStats(uint256 agentId, bool isNewInstance, uint256 tokensRequested, uint256 tokensResponded) internal {
        AgentStats storage stats = _agentStats[agentId];
        stats.totalRequests++;
        if (isNewInstance) {
            stats.totalInstances++;
        }
        stats.lastRequestTimestamp = block.timestamp;
        stats.totalTokensRequested = stats.totalTokensRequested.add(tokensRequested);
        stats.totalTokensResponded = stats.totalTokensResponded.add(tokensResponded);
    }

    function _updateBudget(uint256 agentId, uint256 cost) internal {
        BudgetInfo storage budget = _agentBudgets[agentId];
        
        if (block.timestamp - budget.lastResetTimestamp >= 30 days) {
            budget.spentBudget = cost;
            budget.lastResetTimestamp = block.timestamp;
        } else {
            budget.spentBudget = budget.spentBudget.add(cost);
        }
        
        emit BudgetSpent(agentId, cost);
    }

    function getSafeguardParams(uint256 agentId) public view returns (
        uint256 maxDailyRequests,
        uint256 maxBudget,
        bool requireHumanApproval,
        uint256 maxTokensPerRequest
    ) {
        SafeguardParams storage params = _agentSafeguards[agentId];
        return (params.maxDailyRequests, params.maxBudget, params.requireHumanApproval, params.maxTokensPerRequest);
    }

    function getBudgetInfo(uint256 agentId) public view returns (
        uint256 totalBudget,
        uint256 spentBudget,
        uint256 lastResetTimestamp
    ) {
        BudgetInfo storage budget = _agentBudgets[agentId];
        return (budget.totalBudget, budget.spentBudget, budget.lastResetTimestamp);
    }

    function getAgentStats(uint256 agentId) public view returns (
        uint256 totalRequests,
        uint256 totalInstances,
        uint256 lastRequestTimestamp,
        uint256 totalTokensRequested,
        uint256 totalTokensResponded
    ) {
        AgentStats storage stats = _agentStats[agentId];
        return (
            stats.totalRequests,
            stats.totalInstances,
            stats.lastRequestTimestamp,
            stats.totalTokensRequested,
            stats.totalTokensResponded
        );
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