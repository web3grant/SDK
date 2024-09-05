import CoffeeSDK from '../sdk/src/CoffeeSDK';

async function testSDK() {
  const sdk = new CoffeeSDK('your_private_key', 'base_testnet');

  try {
    const agentDetails = await sdk.getAgentDetails(1);
    console.log('Agent details:', agentDetails);
  } catch (error) {
    console.error('Error:', error);
  }
}

testSDK();