import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { deployProxyAndSave } from "../utils/utils"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  let reserveRegistryAddress = (await hardhat.deployments.getOrNull("ReserveRegistry"))?.address
  if (!reserveRegistryAddress) {
    // deploy reserveRegistry
    const reserveRegistryAbi = (await hardhat.artifacts.readArtifact("ReserveRegistry")).abi
    const reserveRegistryArgs = []
    reserveRegistryAddress = await deployProxyAndSave(
      "ReserveRegistry",
      reserveRegistryArgs,
      hardhat,
      reserveRegistryAbi
    )
  }
}
export default func
func.tags = ["REGISTRY"]
