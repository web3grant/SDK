import { ethers } from 'ethers';
import PaymentABI from './abis/Payments.json';

export class Payments {
  private contract: ethers.Contract;

  constructor(contractAddress: string, signerOrProvider: ethers.Signer | ethers.Provider) {
    this.contract = new ethers.Contract(contractAddress, PaymentABI, signerOrProvider);
  }

  async processPayment(agentId: number, amount: ethers.BigNumberish): Promise<ethers.ContractTransaction> {
    return this.contract.processPayment(agentId, amount);
  }

  async calculateRoyaltyAmount(amount: ethers.BigNumberish, royaltyPercentage: number): Promise<ethers.BigNumberish> {
    return this.contract.calculateRoyaltyAmount(amount, royaltyPercentage);
  }

  async setUsageCharge(agentId: number, charge: ethers.BigNumberish): Promise<ethers.ContractTransaction> {
    return this.contract.setUsageCharge(agentId, charge);
  }

  async getWalletInfo(user: string): Promise<{ balance: ethers.BigNumberish; totalEarned: ethers.BigNumberish; totalPaid: ethers.BigNumberish }> {
    const info = await this.contract.getWalletInfo(user);
    return {
      balance: info.balance,
      totalEarned: info.totalEarned,
      totalPaid: info.totalPaid
    };
  }

  async getWalletBalance(user: string): Promise<ethers.BigNumberish> {
    return this.contract.getWalletBalance(user);
  }

  async requestPayment(agentId: number): Promise<ethers.BigNumberish> {
    return this.contract.requestPayment(agentId);
  }

  async withdrawFunds(amount: ethers.BigNumberish): Promise<ethers.ContractTransaction> {
    return this.contract.withdrawFunds(amount);
  }

  async updateProtocolFee(newFeePercentage: number): Promise<ethers.ContractTransaction> {
    return this.contract.updateProtocolFee(newFeePercentage);
  }

  async getPaymentDetails(paymentId: number): Promise<{ agentId: number; payer: string; amount: ethers.BigNumberish; timestamp: number }> {
    const details = await this.contract.getPaymentDetails(paymentId);
    return {
      agentId: details.agentId.toNumber(),
      payer: details.payer,
      amount: details.amount,
      timestamp: details.timestamp.toNumber()
    };
  }

  async pause(): Promise<ethers.ContractTransaction> {
    return this.contract.pause();
  }

  async unpause(): Promise<ethers.ContractTransaction> {
    return this.contract.unpause();
  }

  // Utility methods

  static toWei(amount: string): ethers.BigNumberish {
    return ethers.parseEther(amount);
  }

  static fromWei(amount: ethers.BigNumberish): string {
    return ethers.formatEther(amount);
  }

  static toBasisPoints(percentage: number): number {
    return Math.floor(percentage * 100);
  }

  static fromBasisPoints(basisPoints: number): number {
    return basisPoints / 100;
  }

  // Getter methods for contract constants
  async getMaxFeePercentage(): Promise<number> {
    const maxFee = await this.contract.MAX_FEE_PERCENTAGE();
    return Payments.fromBasisPoints(maxFee.toNumber());
  }

  async getBasisPoints(): Promise<number> {
    return (await this.contract.BASIS_POINTS()).toNumber();
  }

  async getProtocolFeePercentage(): Promise<number> {
    const feePercentage = await this.contract.protocolFeePercentage();
    return Payments.fromBasisPoints(feePercentage.toNumber());
  }

  async getCoffeeTokenAddress(): Promise<string> {
    return this.contract.coffeeToken();
  }

  async getAgentRegistryAddress(): Promise<string> {
    return this.contract.agentRegistry();
  }

  // Role checking methods
  async hasUpgraderRole(address: string): Promise<boolean> {
    const UPGRADER_ROLE = await this.contract.UPGRADER_ROLE();
    return this.contract.hasRole(UPGRADER_ROLE, address);
  }

  async hasFeeManagerRole(address: string): Promise<boolean> {
    const FEE_MANAGER_ROLE = await this.contract.FEE_MANAGER_ROLE();
    return this.contract.hasRole(FEE_MANAGER_ROLE, address);
  }

  async hasDefaultAdminRole(address: string): Promise<boolean> {
    const DEFAULT_ADMIN_ROLE = await this.contract.DEFAULT_ADMIN_ROLE();
    return this.contract.hasRole(DEFAULT_ADMIN_ROLE, address);
  }
}

export default Payments;