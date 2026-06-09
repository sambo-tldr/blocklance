import dotenv from 'dotenv';
dotenv.config();

function required(name: string): string {
  const val = process.env[name];
  if (!val) throw new Error(`Missing required env var: ${name}`);
  return val;
}

export const config = {
  // Server
  port: parseInt(process.env.PORT || '8080', 10),
  host: process.env.HOST || '0.0.0.0',

  // Database
  databaseUrl: required('DATABASE_URL'),

  // Stacks Network
  stacksNetwork: process.env.STACKS_NETWORK || 'testnet',
  hiroApiUrl: process.env.HIRO_API_URL || 'https://api.testnet.hiro.so',

  // Contract addresses
  deployerAddress: required('DEPLOYER_ADDRESS'),
  contracts: {
    escrow: required('ESCROW_CONTRACT'),
    dispute: required('DISPUTE_CONTRACT'),
    dao: required('DAO_CONTRACT'),
    membership: required('MEMBERSHIP_CONTRACT'),
    payments: required('PAYMENTS_CONTRACT'),
    reputation: process.env.REPUTATION_CONTRACT || '',
    marketplace: process.env.MARKETPLACE_CONTRACT || '',
  },

  // Bootstrap settings
  bootstrap: {
    batchSize: parseInt(process.env.BOOTSTRAP_BATCH_SIZE || '3', 10),
    batchDelayMs: parseInt(process.env.BOOTSTRAP_BATCH_DELAY_MS || '500', 10),
  },

  // Chainhook
  chainhookAuthToken: process.env.CHAINHOOK_AUTH_TOKEN || 'blocklancer-secret-token',
};

export function parseContractId(contractId: string) {
  const [address, name] = contractId.split('.');
  return { address, name };
}
