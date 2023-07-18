// Chain ID to network and contract config.
// (see https://chainlist.org/)
export const config = {
  11155111: {
    name: "sepolia",
    algoBullAddress: "0xF3c144FC829f6351241568b7200E622fb0fb0421",
    stablecoinAddress: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
    scanURL: "https://sepolia.etherscan.io",
  },
  97: {
    name: "BinanceSmartChainTestnet",
    algoBullAddress: "0x1E67DB7b119aDdCBAfEe67978183819788B413D8",
    stablecoinAddress: "0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee",
    scanURL: "https://testnet.bscscan.com/",
  },
};

export const networks = () => {
  const names = [];
  for (const prop in config) {
    names.push(config[prop].name);
  }
  console.log(names);
  return names;
};

export const isSupported = (chainId) =>
  Object.keys(config).includes(chainId.toString());
