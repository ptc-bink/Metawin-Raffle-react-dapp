import { ethers } from "hardhat";

async function main() {
  // const vrfConsumerAddress = "0x9E24F6e2a161C1dfADb2D9e5331336ad836C2F4F";

  const MetawinRaffle = await ethers.getContractFactory("MetawinRaffle");
  const metawinRaffle = await MetawinRaffle.deploy();

  await metawinRaffle.deployed();

  console.log("Main Contract deployed to address: ", metawinRaffle.address);

  // const subscriptionId = 9759;

  // const VRFv2Consumer = await ethers.getContractFactory("VRFv2Consumer");
  // const vrfV2Consumer = await VRFv2Consumer.deploy(subscriptionId);

  // await vrfV2Consumer.deployed();

  // console.log("VRFv2Consumer contract is deployed to address: ", vrfV2Consumer.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
