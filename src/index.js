import "./main.css";
import { Elm } from "./Main.elm";
import * as serviceWorker from "./serviceWorker";
import { ethers } from "ethers";
import algobullABI from "./AlgoBullABI";
import erc20ABI from "./Erc20ABI";
import { config, isSupported, networks } from "./chainConfig";
import * as dotenv from "dotenv";

dotenv.config();

const app = Elm.Main.init({
  node: document.getElementById("root"),
  flags: !!window.ethereum,
});

const refreshOnNetworkChange = () => {
  const provider = new ethers.providers.Web3Provider(window.ethereum, "any");
  provider.on("network", (newNetwork, oldNetwork) => {
    if (oldNetwork) {
      window.location.reload();
    }
  });
};

app.ports.accountRequested.subscribe(async function () {
  try {
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    await provider.send("eth_requestAccounts", []);
    const { chainId } = await provider.getNetwork();

    refreshOnNetworkChange();

    if (!isSupported(chainId)) {
      app.ports.accountFailed.send(
        `This network is not supported by this app. Please switch to a supported network: ${networks()}`
      );
    } else {
      const network = config[chainId].name;

      const networkConfig = config[chainId];
      const signer = await provider.getSigner();
      const address = await signer.getAddress();

      const algobullContract = new ethers.Contract(
        networkConfig.algoBullAddress,
        algobullABI.abi,
        provider
      ).connect(signer);

      const stablecoinContract = new ethers.Contract(
        networkConfig.stablecoinAddress,
        erc20ABI.abi,
        provider
      ).connect(signer);

      const stablecoinSymbol = await stablecoinContract.symbol();
      const stablecoinFeeBig = await algobullContract.mintFee();
      const ethBalanceBig = await provider.getBalance(address);
      const stablecoinBalanceBig = await stablecoinContract.balanceOf(address);
      const algobullBalanceBig = await algobullContract.balanceOf(address);

      const stablecoinFee = ethers.utils.formatEther(stablecoinFeeBig);
      const stablecoinBalance = ethers.utils.formatEther(stablecoinBalanceBig);
      const ethBalance = ethers.utils.formatUnits(ethBalanceBig);

      console.log(ethBalance);

      const wallet = {
        address,
        stablecoinBalance,
        stablecoinSymbol,
        ethBalance,
        network,
        stablecoinFee,
        algobullBalance: algobullBalanceBig.toString(),
      };

      console.log(wallet);

      app.ports.accountSucceeded.send(wallet);
    }
  } catch (e) {
    console.log(e);
    app.ports.accountFailed.send("No account detected for this network.");
  }
});

app.ports.approveRequested.subscribe(async function (quantity) {
  const provider = new ethers.providers.Web3Provider(window.ethereum);
  const { chainId } = await provider.getNetwork();
  if (isSupported(chainId)) {
    const signer = provider.getSigner();
    const networkConfig = config[chainId];

    console.log(networkConfig.stablecoinAddress);

    const stablecoinContract = new ethers.Contract(
      networkConfig.stablecoinAddress,
      erc20ABI.abi,
      provider
    ).connect(signer);

    const algoBullAddress = networkConfig.algoBullAddress;

    approve(
      networkConfig,
      signer,
      stablecoinContract,
      provider,
      algoBullAddress,
      quantity
    );
  } else {
    app.ports.networkError.send(
      `Network with chain id ${chainId} is not supported. Please switch to one of the following supported networks: mumbai, goerli, sepolia.`
    );
  }
});

function approve(
  networkConfig,
  signer,
  contract,
  provider,
  algoBullAddress,
  quantity
) {
  provider.send("eth_requestAccounts", []).then(async () => {
    const allowanceBig = await contract.allowance(
      signer.getAddress(),
      algoBullAddress
    );
    const decimals = await contract.decimals();
    const quantityBig = ethers.utils.parseUnits(quantity + "", decimals);
    if (allowanceBig.gte(quantityBig)) {
      app.ports.approveSucceeded.send("");
    } else {
      contract
        .approve(algoBullAddress, quantity)
        .then(async (res) => {
          const txnUrl = `${networkConfig.scanURL}/tx/${res.hash}`;
          console.log(txnUrl);
          await res.wait();

          app.ports.approveSucceeded.send("");
        })
        .catch((err) => {
          console.log("err");
          app.ports.approveFailed.send("Token approval failed.");
        });
    }
  });
}

app.ports.mintRequested.subscribe(async function (quantity) {
  const provider = new ethers.providers.Web3Provider(window.ethereum);
  const { chainId } = await provider.getNetwork();
  if (isSupported(chainId)) {
    const signer = provider.getSigner();
    const networkConfig = config[chainId];
    const contract = new ethers.Contract(
      networkConfig.algoBullAddress,
      algobullABI.abi,
      provider
    ).connect(signer);

    mint(networkConfig, signer, contract, provider, quantity);
  } else {
    app.ports.networkError.send(
      `Network with chain id ${chainId} is not supported. Please switch to one of the following supported networks: mumbai, goerli, sepolia.`
    );
  }
});

function mint(networkConfig, signer, contract, provider, quantity) {
  provider.send("eth_requestAccounts", []).then(async () => {
    contract
      .mintMultiple(await signer.getAddress(), quantity)
      .then(async (res) => {
        const txnUrl = `${networkConfig.scanURL}/tx/${res.hash}`;
        await res.wait();

        app.ports.mintSucceeded.send(txnUrl);
      })
      .catch((err) => {
        app.ports.mintFailed.send("");
      });
  });
}

// If you want your app to work offline and load faster, you can change
// unregister() to register() below. Note this comes with some pitfalls.
// Learn more about service workers: https://bit.ly/CRA-PWA
serviceWorker.unregister();
