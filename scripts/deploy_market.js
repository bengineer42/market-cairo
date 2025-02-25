import {
  RpcProvider,
  Account,
  CallData,
  byteArray,
  CairoCustomEnum,
  Contract,
  hash,
} from "starknet";

import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

import { dirname } from "path";

import { ArgumentParser } from "argparse";

import "toml";

const parser = new ArgumentParser({ description: "Argparse example" });

parser.add_argument("-t", "--target-path", {
  help: "path to the target/ dir",
});

parser.add_argument("--profile", {
  help: "sozo profile",
  default: "dev",
});

parser.add_argument("-s", "--salt", {
  help: "salt for the contract",
  default: 0,
});

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const parsedArgs = parser.parse_args();
const profile = parsedArgs.profile;
const targetPath = path.join(path.resolve(parsedArgs.target_path), profile);

console.log(targetPath);

const getAccount = async (rpc, account1Address, privateKey1) => {
  const provider = new RpcProvider({ nodeUrl: rpc });
  console.log(`Connected to StarkNet node at ${rpc}`);
  const account = new Account(provider, account1Address, privateKey1);
  console.log(`Account address: ${account1Address}`);
  return account;
};

const loadJson = (rpath) => {
  return JSON.parse(fs.readFileSync(path.resolve(__dirname, rpath)));
};

const getContractPaths = (targetPath) => {
  let contracts = {};
  for (const file of fs.readdirSync(targetPath)) {
    const name = path.basename(file).split(".", 1);

    if (file.endsWith(".contract_class.json")) {
      name in contracts || (contracts[name] = {});
      contracts[name].contract = path.join(targetPath, file);
    } else if (file.endsWith(".compiled_contract_class.json")) {
      name in contracts || (contracts[name] = {});
      contracts[name].casm = path.join(targetPath, file);
    }
  }
  return contracts;
};

const declareContract = async (account, name, files) => {
  const contract = loadJson(files.contract);
  const classHash = hash.computeContractClassHash(contract);
  try {
    await account.getClassByHash(classHash);
    console.log(`${name} already declared with class Hash ${classHash}`);
  } catch {
    try {
      const casm = loadJson(files.casm);
      const declareResponse = await account.declare(
        { contract, casm },
        { version: 3 }
      );
      await account.waitForTransaction(declareResponse.transaction_hash);
      console.log(
        `${name} declared with class Hash ${declareResponse.class_hash}`
      );
    } catch (err) {
      console.log(`Failed to declare ${name}`);
      console.log(err);
    }
  }

  return classHash;
};

const declareContracts = async (account, contracts) => {
  let classHashes = {};
  for (const contractName in contracts) {
    classHashes[contractName] = await declareContract(
      account,
      contractName,
      contracts[contractName]
    );
  }
  return classHashes;
};

const deployContract = async (account, classHash, salt, callData) => {
  const deployResponse = await account.deployContract(
    { classHash, salt, unique: false, constructorCalldata: callData },
    { version: 3 }
  );
  await account.waitForTransaction(deployResponse.transaction_hash);
  console.log(
    `Deployed contract with class Hash: ${classHash} and address: ${deployResponse.contract_address}`
  );
  return deployResponse.contract_address;
};

const calculateUDCContractAddressFromHash = (
  salt,
  classHash,
  callData,
  deployerAddress,
  unique
) => {
  if (unique) {
    salt = hash.computePedersenHash(salt, deployerAddress);
    deployerAddress =
      "0x041a78e741e5af2fec34b695679bc6891742439f7afb8484ecd7766661ad02bf";
  } else {
    deployerAddress = "0x0";
  }
  return hash.calculateContractAddressFromHash(
    salt,
    classHash,
    callData,
    deployerAddress
  );
};

const deployZeroContract = async (account, classHash) => {
  const contract_address = calculateUDCContractAddressFromHash(
    0,
    classHash,
    [],
    0,
    false
  );

  if (!(await checkContractAt(account, contract_address))) {
    const deployResponse = await account.deployContract(
      {
        classHash,
        salt: "0x0",
        unique: false,
      },
      { version: 3 }
    );
    await account.waitForTransaction(deployResponse.transaction_hash);
    console.log(
      `Deployed contract with class hash: ${classHash} and address: ${deployResponse.contract_address}`
    );
  } else {
    console.log(
      `Contract already deployed with class hash: ${classHash} at address: ${contract_address}`
    );
  }
  return contract_address;
};
const account = await getAccount(
  process.env.STARKNET_RPC_URL,
  process.env.STARKNET_ACCOUNT_ADDRESS,
  process.env.STARKNET_PRIVATE_KEY
);

const checkContractAt = async (provider, contractAddress) => {
  try {
    await provider.getClassHashAt(contractAddress);
    return true;
  } catch (err) {
    console.log(err);
    return false;
  }
};

const contracts = getContractPaths(targetPath);
let contractHashes = await declareContracts(account, contracts);
for (const contractName in contractHashes) {
  if (contractName.includes("_m_")) {
    await deployZeroContract(account, contractHashes[contractName]);
  }
}

console.log(contractHashes);

const deployArgs = {
  single_class_hash_unguaranteed:
    contractHashes.market_direct_single_unguaranteed,
  multiple_class_hash_unguaranteed:
    contractHashes.market_direct_multiple_unguaranteed,
  one_of_class_hash_unguaranteed:
    contractHashes.market_direct_one_of_unguaranteed,
  single_class_hash_guaranteed: contractHashes.market_direct_single_guaranteed,
  multiple_class_hash_guaranteed:
    contractHashes.market_direct_multiple_guaranteed,
  one_of_class_hash_guaranteed: contractHashes.market_direct_one_of_guaranteed,
  direct_single_model_class_hash: contractHashes.market_m_DirectSingle,
  direct_multiple_model_class_hash: contractHashes.market_m_DirectMultiple,
  direct_one_of_model_class_hash: contractHashes.market_m_DirectOneOf,
  direct_one_of_price_model_class_hash:
    contractHashes.market_m_DirectOneOfPrice,
  tax_ppm: 5000,
  beneficiary: process.env.STARKNET_ACCOUNT_ADDRESS,
};

deployContract(
  account,
  contractHashes.market_direct_manager,
  parsedArgs.salt,
  deployArgs
);
