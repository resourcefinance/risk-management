import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { deployProxyAndSave } from "../utils/utils"

const func: DeployFunction = async function (hardhat: HardhatRuntimeEnvironment) {
  let riskOracleAddress = (await hardhat.deployments.getOrNull("RiskOracle"))?.address
  if (!riskOracleAddress) {
    // deploy riskOracle
    const riskOracleAbi = (await hardhat.artifacts.readArtifact("RiskOracle")).abi
    const riskOracleArgs = [(await hardhat.ethers.getSigners())[0].address]
    riskOracleAddress = await deployProxyAndSave(
      "RiskOracle",
      riskOracleArgs,
      hardhat,
      riskOracleAbi
    )
  }
}
export default func
func.tags = ["ORACLE"]
