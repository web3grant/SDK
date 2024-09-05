import { ethers } from 'ethers';

export interface ContractConfig {
  address: string;
  abi: any[];
}

export type Signer = ethers.Signer;