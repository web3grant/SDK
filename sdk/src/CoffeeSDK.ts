import { ethers } from 'ethers';

// Import ABIs
import ObserveABI from '../src/abis/Observe.json';
import PaymentsABI from '../src/abis/Payments.json';
import AgentIDABI from '../src/abis/AgentID.json';

interface NetworkConfig {
  rpcUrl: string;
  observeAddress: string;
  paymentsAddress: string;
  agentIDAddress: string;
}

const NETWORKS: { [key: string]: NetworkConfig } = {
  base_mainnet: {
    rpcUrl: 'https://mainnet.base.org',
    observeAddress: '0x1234567890123456789012345678901234567890',
    paymentsAddress: '0x2345678901234567890123456789012345678901',
    agentIDAddress: '0x3456789012345678901234567890123456789012',
  },
  base_testnet: {
    rpcUrl: 'https://sepolia.base.org',
    observeAddress: '0x9876543210987654321098765432109876543210',
    paymentsAddress: '0x8765432109876543210987654321098765432109',
    agentIDAddress: '0x7654321098765432109876543210987654321098',
  },
};

class CoffeeSDK {
  private provider: ethers.JsonRpcProvider;
  private signer: ethers.Wallet;
  private observeContract: ethers.Contract;
  private paymentsContract: ethers.Contract;
  private agentIDContract: ethers.Contract;

  constructor(
    privateKey: string,
    network: 'base_mainnet' | 'base_testnet' = 'base_mainnet',
    providerUrl?: string
  ) {
    const networkConfig = NETWORKS[network];
    this.provider = new ethers.JsonRpcProvider(providerUrl || networkConfig.rpcUrl);
    this.signer = new ethers.Wallet(privateKey, this.provider);

    this.observeContract = new ethers.Contract(networkConfig.observeAddress, ObserveABI, this.signer);
    this.paymentsContract = new ethers.Contract(networkConfig.paymentsAddress, PaymentsABI, this.signer);
    this.agentIDContract = new ethers.Contract(networkConfig.agentIDAddress, AgentIDABI, this.signer);
  }

  // Observe (Governance) Methods
  async setSafeguards(
    agentId: number,
    maxDailyRequests: number,
    maxBudget: bigint,
    requireHumanApproval: boolean,
    maxTokensPerRequest: number
  ): Promise<ethers.ContractTransaction> {
    return this.observeContract.setSafeguards(agentId, maxDailyRequests, maxBudget, requireHumanApproval, maxTokensPerRequest);
  }

  async approveAction(agentId: number, action: string): Promise<ethers.ContractTransaction> {
    return this.observeContract.approveAction(agentId, action);
  }

  async pauseAgent(agentId: number): Promise<ethers.ContractTransaction> {
    return this.observeContract.pauseAgent(agentId);
  }

  async recordAgentAction(
    agentId: number,
    cost: bigint,
    tokensRequested: number,
    tokensResponded: number,
    isNewInstance: boolean
  ): Promise<ethers.ContractTransaction> {
    return this.observeContract.recordAgentAction(agentId, cost, tokensRequested, tokensResponded, isNewInstance);
  }

  async setBudget(agentId: number, totalBudget: bigint): Promise<ethers.ContractTransaction> {
    return this.observeContract.setBudget(agentId, totalBudget);
  }

  async getSafeguardParams(agentId: number): Promise<any> {
    return this.observeContract.getSafeguardParams(agentId);
  }

  async getBudgetInfo(agentId: number): Promise<any> {
    return this.observeContract.getBudgetInfo(agentId);
  }

  async getAgentStats(agentId: number): Promise<any> {
    return this.observeContract.getAgentStats(agentId);
  }

  // Payments Methods
  async processPayment(agentId: number, amount: bigint): Promise<ethers.ContractTransaction> {
    return this.paymentsContract.processPayment(agentId, amount);
  }

  async setUsageCharge(agentId: number, charge: bigint): Promise<ethers.ContractTransaction> {
    return this.paymentsContract.setUsageCharge(agentId, charge);
  }

  async getWalletInfo(user: string): Promise<any> {
    return this.paymentsContract.getWalletInfo(user);
  }

  async withdrawFunds(amount: bigint): Promise<ethers.ContractTransaction> {
    return this.paymentsContract.withdrawFunds(amount);
  }

  async getPaymentDetails(paymentId: number): Promise<any> {
    return this.paymentsContract.getPaymentDetails(paymentId);
  }

  // AgentID (AgentRegistry) Methods
  async registerAgent(
    metadataHash: string,
    royaltyPercentage: number,
    workflowHash: string,
    llmDetailsHash: string,
    dataSourceHash: string
  ): Promise<ethers.ContractTransaction> {
    return this.agentIDContract.registerAgent(metadataHash, royaltyPercentage, workflowHash, llmDetailsHash, dataSourceHash);
  }

  async updateAgentMetadata(
    agentId: number,
    newMetadataHash: string,
    newWorkflowHash: string,
    newLlmDetailsHash: string,
    newDataSourceHash: string
  ): Promise<ethers.ContractTransaction> {
    return this.agentIDContract.updateAgentMetadata(agentId, newMetadataHash, newWorkflowHash, newLlmDetailsHash, newDataSourceHash);
  }

  async setAgentActive(agentId: number, active: boolean): Promise<ethers.ContractTransaction> {
    return this.agentIDContract.setAgentActive(agentId, active);
  }

  async getAgentDetails(agentId: number): Promise<any> {
    return this.agentIDContract.getAgentDetails(agentId);
  }

  async getActivityLog(agentId: number, startIndex: number, endIndex: number): Promise<any> {
    return this.agentIDContract.getActivityLog(agentId, startIndex, endIndex);
  }

  // Utility Methods
  async getGasPrice(): Promise<bigint> {
    return this.provider.getFeeData().then(feeData => feeData.gasPrice ?? BigInt(0));
  }

  async estimateGas(transaction: ethers.TransactionRequest): Promise<bigint> {
    return this.provider.estimateGas(transaction);
  }

  static toWei(amount: string): bigint {
    return ethers.parseEther(amount);
  }

  static fromWei(amount: bigint): string {
    return ethers.formatEther(amount);
  }
}

export default CoffeeSDK;