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

// An example of the data submitted for a token deposit
export const erc20DepositData =
  '0xCBD4ECE9000000000000000000000000420000000000000000000000000000000000001000000000000000000000000099C9FC46F92E8A1C0DEC1B1747D010903E884BE10000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000A32A00000000000000000000000000000000000000000000000000000000000000E4662A633A0000000000000000000000002260FAC5E5542A773AA44FBCFEDF7C193BC2C59900000000000000000000000068F180FCCE6836688E9084F035309E29BF0A2095000000000000000000000000A2490947B30258B522B7D6FD8FABEC2D21C42D57000000000000000000000000A2490947B30258B522B7D6FD8FABEC2D21C42D570000000000000000000000000000000000000000000000000000000003E344EF00000000000000000000000000000000000000000000000000000000000000C0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'

export class GasMeasurement {
  GasMeasurementContract: Contract

  public async init(wallet: Signer) {
    this.GasMeasurementContract = await (
      await (await ethers.getContractFactory('HelperGasMeasurer')).deploy()
    ).connect(wallet)
  }

  public async getGasCost(
    targetContract: Contract,
    value: BigNumber,
    methodName: string,
    methodArgs: Array<any> = []
  ): Promise<number> {
    const gasCost: number =
      await this.GasMeasurementContract.callStatic.measureCallGas(
        targetContract.address,
        targetContract.interface.encodeFunctionData(methodName, methodArgs),
        {
          value,
        }
      )

    return gasCost
  }
}
