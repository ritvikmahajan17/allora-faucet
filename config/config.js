import { stringToPath } from "@cosmjs/crypto";
import fs from "fs";
import * as dotenv from "dotenv";

// Load environment variables
dotenv.config();

// Load mnemonic from environment variable
if (!process.env.MNEMONIC) {
  console.error("==================================================================");
  console.error("ERROR: MNEMONIC environment variable is required!");
  console.error("Set MNEMONIC environment variable with your wallet mnemonic phrase");
  console.error("==================================================================");
  process.exit(1);
}

const mnemonics = [process.env.MNEMONIC.trim()];
console.log("==================================================================");
console.log(`faucet mnemonic from ENV: ${mnemonics[0].substring(0, 15)} ...`);

export default {
  port: 8000, // http port
  db: {
    path: `./faucet.db`, // db for frequency checker(WIP)
  },
  project: {
    name: "Faucet", // What ever you want, recommend: chain-id,
    logo: "",
    deployer: "",
  },
  blockchains: [
    {
      name: "allora-testnet-1",
      endpoint: {
        // Ethereum JSON-RPC endpoint for blockchain communication
        evm_endpoint: process.env.EVM_ENDPOINT,
      },
      sender: {
        mnemonic: mnemonics[0], // Single mnemonic for Ethereum
        mnemonics,
        option: {
          hdPaths: [stringToPath("m/44'/60'/0'/0/0")],
          prefix: "", // Ethereum addresses don't use prefix
        },
      },
      tx: {
        amount: { amount: "1000000000000000000" }, // 1 ETH in Wei (for Ethereum)
        fee: {
          amount: [{ denom: "uallo", amount: "500" }],
          gasPrice: "11uallo",
        },
      },
      limit: {
        // how many times each wallet address is allowed in a window(24h)
        address: 100,
        // how many times each ip is allowed in a window(24h),
        // if you use proxy, double check if the req.ip is return client's ip.
        ip: 200,
        cooldownInSec: 1,
        processableAddresses: 100,
      },
    },
  ],
  reCaptcha: {
    siteKey: process.env.RECAPTCHA_SITE_KEY,
    secretKey: process.env.RECAPTCHA_SECRET_KEY,
  },
  reCaptchaEnabled: false,
};
