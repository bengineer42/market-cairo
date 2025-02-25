import { RpcProvider, Account, CairoCustomEnum, Contract } from "starknet";

const managerAddress =
  "0x7188ec796ab7aae9fdbc131c5f2f46a3d21d26377ff02c7473ef7ada56d8231";

const getContract = async (provider, contractAddress) => {
  console.log(contractAddress);
  const { abi } = await provider.getClassAt(contractAddress);
  return new Contract(abi, contractAddress, provider);
};

const getAccount = async (rpc, account1Address, privateKey1) => {
  const provider = new RpcProvider({ nodeUrl: rpc });
  console.log(`Connected to StarkNet node at ${rpc}`);
  const account = new Account(
    provider,
    account1Address,
    privateKey1,
    undefined,
    "0x3"
  );
  console.log(`Account address: ${account1Address}`);
  return account;
};

const account = await getAccount(
  process.env.STARKNET_RPC_URL,
  process.env.STARKNET_ACCOUNT_ADDRESS,
  process.env.STARKNET_PRIVATE_KEY
);

const CallData = {
  offer: [
    new CairoCustomEnum({
      ERC20: {
        contract_address:
          "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
        amount: 2000000,
      },
    }),
    new CairoCustomEnum({
      ERC721: {
        contract_address:
          "0x032cb9f30629268612ffb6060e40dfc669849c7d72539dd23c80fe6578d0549d",
        token_id: 50,
      },
    }),
  ],
  erc20_address:
    "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
  price: 1000000,
  expiry: 1840514683,
  tax_ppm: 5000,
  guaranteed: true,
};

const contract = await getContract(account, managerAddress);
contract.connect(account);
const response = await contract.new_single(
  contract.populate("new_single", CallData).calldata
);
await account.waitForTransaction(response.transaction_hash);
