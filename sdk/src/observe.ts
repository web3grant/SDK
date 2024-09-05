import { ethers } from 'ethers';
import ObserveABI from './abis/Observe.json';

export class Observe {
  private contract: ethers.Contract;

  constructor(contractAddress: string, signerOrProvider: ethers.Signer | ethers.Provider) {
    this.contract = new ethers.Contract(contractAddress, ObserveABI, signerOrProvider);
  }

  async setSafeguards(
    agentId: number,
    maxDailyRequests: number,
    maxBudget: ethers.BigNumberish,
    requireHumanApproval: boolean,
    maxTokensPerRequest: number
  ): Promise<ethers.ContractTransaction> {
    return this.contract.setSafeguards(
      agentId,
      maxDailyRequests,
      maxBudget,
      requireHumanApproval,
      maxTokensPerRequest
    );
  }

  async approveAction(agentId: number, action: string): Promise<ethers.ContractTransaction> {
    return this.contract.approveAction(agentId, action);
  }

  async pauseAgent(agentId: number): Promise<ethers.ContractTransaction> {
    return this.contract.pauseAgent(agentId);
  }

  async recordAgentAction(
    agentId: number,
    cost: ethers.BigNumberish,
    tokensRequested: number,
    tokensResponded: number,
    isNewInstance: boolean
  ): Promise<ethers.ContractTransaction> {
    return this.contract.recordAgentAction(agentId, cost, tokensRequested, tokensResponded, isNewInstance);
  }

  async setBudget(agentId: number, totalBudget: ethers.BigNumberish): Promise<ethers.ContractTransaction> {
    return this.contract.setBudget(agentId, totalBudget);
  }

  async logMetadata(agentId: number, ipfsHash: string): Promise<ethers.ContractTransaction> {
    return this.contract.logMetadata(agentId, ipfsHash);
  }

  async getAgentStats(agentId: number): Promise<{
    totalRequests: number;
    totalInstances: number;
    lastRequestTimestamp: number;
    totalTokensRequested: number;
    totalTokensResponded: number;
  }> {
    const stats = await this.contract.getAgentStats(agentId);
    return {
      totalRequests: stats.totalRequests.toNumber(),
      totalInstances: stats.totalInstances.toNumber(),
      lastRequestTimestamp: stats.lastRequestTimestamp.toNumber(),
      totalTokensRequested: stats.totalTokensRequested.toNumber(),
      totalTokensResponded: stats.totalTokensResponded.toNumber(),
    };
  }
  async getBudgetInfo(agentId: number): Promise<{
    totalBudget: ethers.BigNumberish;
    spentBudget: ethers.BigNumberish;
    lastResetTimestamp: number;
  }> {
    const info = await this.contract.getBudgetInfo(agentId);
    return {
      totalBudget: info.totalBudget,
      spentBudget: info.spentBudget,
      lastResetTimestamp: info.lastResetTimestamp.toNumber(),
    };
  }

  async getSafeguardParams(agentId: number): Promise<{
    maxDailyRequests: number;
    maxBudget: ethers.BigNumberish;
    requireHumanApproval: boolean;
    maxTokensPerRequest: number;
  }> {
    const params = await this.contract.getSafeguardParams(agentId);
    return {
      maxDailyRequests: params.maxDailyRequests.toNumber(),
      maxBudget: params.maxBudget,
      requireHumanApproval: params.requireHumanApproval,
      maxTokensPerRequest: params.maxTokensPerRequest.toNumber(),
    };
  }

  async pause(): Promise<ethers.ContractTransaction> {
    return this.contract.pause();
  }

  async unpause(): Promise<ethers.ContractTransaction> {
    return this.contract.unpause();
  }

  // Utility function to convert ether to wei
  static toWei(value: string): ethers.BigNumberish {
    return ethers.parseEther(value);
  }

  // Utility function to convert wei to ether
  static fromWei(value: ethers.BigNumberish): string {
    return ethers.formatEther(value);
  }
}

export default Observe;