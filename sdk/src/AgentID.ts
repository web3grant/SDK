import { ethers } from 'ethers';
import AgentIDABI from './abis/AgentID.json';

export class AgentID {
  private contract: ethers.Contract;

  constructor(contractAddress: string, signer: ethers.Signer) {
    this.contract = new ethers.Contract(contractAddress, AgentIDABI, signer);
  }

  async registerAgent(
    metadataHash: string,
    royaltyPercentage: number,
    workflowHash: string,
    llmDetailsHash: string,
    dataSourceHash: string
  ): Promise<number> {
    const tx = await this.contract.registerAgent(
      metadataHash,
      royaltyPercentage,
      workflowHash,
      llmDetailsHash,
      dataSourceHash
    );
    const receipt = await tx.wait();
    const event = receipt.events?.find((e: { event: string }) => e.event === 'AgentRegistered');
    return event?.args?.agentId.toNumber();
  }

  async updateAgentMetadata(
    agentId: number,
    newMetadataHash: string,
    newWorkflowHash: string,
    newLlmDetailsHash: string,
    newDataSourceHash: string
  ): Promise<void> {
    const tx = await this.contract.updateAgentMetadata(
      agentId,
      newMetadataHash,
      newWorkflowHash,
      newLlmDetailsHash,
      newDataSourceHash
    );
    await tx.wait();
  }

  async setAgentActive(agentId: number, active: boolean): Promise<void> {
    const tx = await this.contract.setAgentActive(agentId, active);
    await tx.wait();
  }

  async createNewInstance(agentId: number): Promise<void> {
    const tx = await this.contract.createNewInstance(agentId);
    await tx.wait();
  }

  async setRoyaltyAmount(agentId: number, newRoyaltyPercentage: number): Promise<void> {
    const tx = await this.contract.setRoyaltyAmount(agentId, newRoyaltyPercentage);
    await tx.wait();
  }

  async updateReputation(agentId: number, newScore: number): Promise<void> {
    const tx = await this.contract.updateReputation(agentId, newScore);
    await tx.wait();
  }

  async distributeRoyalty(agentId: number, amount: ethers.BigNumberish): Promise<void> {
    const tx = await this.contract.distributeRoyalty(agentId, amount);
    await tx.wait();
  }

  async logActivity(agentId: number, activityType: string, activityData: string): Promise<void> {
    const tx = await this.contract.logActivity(agentId, activityType, activityData);
    await tx.wait();
  }

  async getAgentMetadataHash(agentId: number): Promise<string> {
    return await this.contract.getAgentMetadataHash(agentId);
  }

  async getActivityLog(agentId: number, startIndex: number, endIndex: number): Promise<any[]> {
    return await this.contract.getActivityLog(agentId, startIndex, endIndex);
  }

  async getAgentDetails(agentId: number): Promise<any> {
    return await this.contract.getAgentDetails(agentId);
  }

  async getInstanceCount(agentId: number): Promise<number> {
    const count = await this.contract.getInstanceCount(agentId);
    return count.toNumber();
  }
}