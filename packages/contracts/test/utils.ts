import { ethers } from 'hardhat'
import { Contract, Signer, BigNumber } from 'ethers'
import { DepositFeed__factory, DepositFeed } from '../typechain'

export const decodeDepositEvent = async (
  depositFeed: DepositFeed
): Promise<{
  from: string
  to: string
  mint: BigNumber
  value: BigNumber
  gasLimit: BigNumber
  isCreation: boolean
  data: string
}> => {
  const events = await depositFeed.queryFilter(
    depositFeed.filters.TransactionDeposited()
  )

  const eventArgs = events[events.length - 1].args

  return {
    from: eventArgs.from,
    to: eventArgs.to,
    mint: eventArgs.mint,
    value: eventArgs.value,
    gasLimit: eventArgs.gasLimit,
    isCreation: eventArgs.isCreation,
    data: eventArgs.data,
  }
}

export class GasMeasurement {
  GasMeasurementContract: Contract

  public async init(wallet: Signer) {
    this.GasMeasurementContract = await (
      await (await ethers.getContractFactory('HelperGasMeasurer')).deploy()
    ).connect(wallet)
  }

  public async getGasCost(
    targetContract: Contract,
    methodName: string,
    methodArgs: Array<any> = []
  ): Promise<number> {
    const gasCost: number =
      await this.GasMeasurementContract.callStatic.measureCallGas(
        targetContract.address,
        targetContract.interface.encodeFunctionData(methodName, methodArgs)
      )

    return gasCost
  }
}
