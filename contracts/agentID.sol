// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract AgentRegistry is Initializable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    struct Agent {
        address owner;
        string metadataHash;
        bool active;
        uint256 registrationTime;
        uint256 totalStaked;
        uint256 reputationScore;
        uint256 royaltyPercentage;
        string workflowHash;
        string llmDetailsHash;
        string dataSourceHash;
    }

    struct ActivityLog {
        uint256 timestamp;
        string activityType;
        string activityData;
    }

    IERC20Upgradeable public coffeeToken;

    CountersUpgradeable.Counter private _agentIds;
    mapping(uint256 => Agent) private _agents;
    mapping(uint256 => ActivityLog[]) private _activityLogs;
    mapping(uint256 => uint256) private _instanceCount;

    event AgentRegistered(uint256 indexed agentId, address indexed owner, string metadataHash);
    event AgentUpdated(uint256 indexed agentId, string newMetadataHash);
    event AgentDeactivated(uint256 indexed agentId);
    event AgentReactivated(uint256 indexed agentId);
    event ReputationUpdated(uint256 indexed agentId, uint256 newScore);
    event RoyaltyUpdated(uint256 indexed agentId, uint256 newRoyaltyPercentage);
    event RoyaltyDistributed(uint256 indexed agentId, uint256 amount);
    event NewInstanceCreated(uint256 indexed agentId, uint256 instanceCount);
    event ActivityLogged(uint256 indexed agentId, string activityType, string activityData);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _coffeeTokenAddress) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(GOVERNANCE_ROLE, msg.sender);

        coffeeToken = IERC20Upgradeable(_coffeeTokenAddress);
    }

    function registerAgent(
        string memory metadataHash,
        uint256 royaltyPercentage,
        string memory workflowHash,
        string memory llmDetailsHash,
        string memory dataSourceHash
    ) public whenNotPaused nonReentrant returns (uint256) {
        require(royaltyPercentage <= 100, "Royalty percentage must be <= 100");
        
        _agentIds.increment();
        uint256 newAgentId = _agentIds.current();
        
        _agents[newAgentId] = Agent({
            owner: msg.sender,
            metadataHash: metadataHash,
            active: true,
            registrationTime: block.timestamp,
            totalStaked: 0,
            reputationScore: 0,
            royaltyPercentage: royaltyPercentage,
            workflowHash: workflowHash,
            llmDetailsHash: llmDetailsHash,
            dataSourceHash: dataSourceHash
        });
        
        emit AgentRegistered(newAgentId, msg.sender, metadataHash);
        return newAgentId;
    }

    function updateAgentMetadata(
        uint256 agentId,
        string memory newMetadataHash,
        string memory newWorkflowHash,
        string memory newLlmDetailsHash,
        string memory newDataSourceHash
    ) public whenNotPaused nonReentrant {
        require(_agents[agentId].owner == msg.sender, "Not the agent owner");
        require(_agents[agentId].active, "Agent is not active");
        
        _agents[agentId].metadataHash = newMetadataHash;
        _agents[agentId].workflowHash = newWorkflowHash;
        _agents[agentId].llmDetailsHash = newLlmDetailsHash;
        _agents[agentId].dataSourceHash = newDataSourceHash;
        
        emit AgentUpdated(agentId, newMetadataHash);
    }

    function setAgentActive(uint256 agentId, bool active) public whenNotPaused nonReentrant {
        require(_agents[agentId].owner == msg.sender || hasRole(GOVERNANCE_ROLE, msg.sender), "Not authorized");
        _agents[agentId].active = active;
        if (active) {
            emit AgentReactivated(agentId);
        } else {
            emit AgentDeactivated(agentId);
        }
    }

    function createNewInstance(uint256 agentId) public whenNotPaused nonReentrant {
        require(_agents[agentId].active, "Agent is not active");
        _instanceCount[agentId]++;
        emit NewInstanceCreated(agentId, _instanceCount[agentId]);
    }

    function setRoyaltyAmount(uint256 agentId, uint256 newRoyaltyPercentage) public whenNotPaused nonReentrant {
        require(_agents[agentId].owner == msg.sender, "Not the agent owner");
        require(newRoyaltyPercentage <= 100, "Royalty percentage must be <= 100");
        _agents[agentId].royaltyPercentage = newRoyaltyPercentage;
        emit RoyaltyUpdated(agentId, newRoyaltyPercentage);
    }

    function updateReputation(uint256 agentId, uint256 newScore) public onlyRole(GOVERNANCE_ROLE) {
        require(newScore <= 100, "Score must be <= 100");
        _agents[agentId].reputationScore = newScore;
        emit ReputationUpdated(agentId, newScore);
    }

    function distributeRoyalty(uint256 agentId, uint256 amount) public onlyRole(GOVERNANCE_ROLE) {
        require(_agents[agentId].active, "Agent is not active");
        // Implement royalty distribution logic here
        emit RoyaltyDistributed(agentId, amount);
    }

    function logActivity(uint256 agentId, string memory activityType, string memory activityData) public onlyRole(GOVERNANCE_ROLE) {
        _activityLogs[agentId].push(ActivityLog({
            timestamp: block.timestamp,
            activityType: activityType,
            activityData: activityData
        }));
        emit ActivityLogged(agentId, activityType, activityData);
    }

    function getAgentMetadataHash(uint256 agentId) public view returns (string memory) {
        return _agents[agentId].metadataHash;
    }

    function getActivityLog(uint256 agentId, uint256 startIndex, uint256 endIndex) public view returns (ActivityLog[] memory) {
        require(startIndex < endIndex, "Invalid index range");
        require(endIndex <= _activityLogs[agentId].length, "End index out of bounds");
        
        ActivityLog[] memory logs = new ActivityLog[](endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            logs[i - startIndex] = _activityLogs[agentId][i];
        }
        return logs;
    }

    function getAgentDetails(uint256 agentId) public view returns (
        address owner,
        bool active,
        uint256 totalStaked,
        uint256 reputationScore,
        uint256 royaltyPercentage,
        string memory metadataHash,
        string memory workflowHash,
        string memory llmDetailsHash,
        string memory dataSourceHash
    ) {
        Agent storage agent = _agents[agentId];
        return (
            agent.owner,
            agent.active,
            agent.totalStaked,
            agent.reputationScore,
            agent.royaltyPercentage,
            agent.metadataHash,
            agent.workflowHash,
            agent.llmDetailsHash,
            agent.dataSourceHash
        );
    }

    function getInstanceCount(uint256 agentId) public view returns (uint256) {
        return _instanceCount[agentId];
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