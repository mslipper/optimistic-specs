import { expect } from 'chai'
import { ethers } from 'hardhat'
import { Signer, BigNumber } from 'ethers'
import { applyL1ToL2Alias } from '@eth-optimism/core-utils'
import { GasMeasurement, erc20DepositData } from '../utils'

import { DepositFeed__factory, DepositFeed } from '../../typechain'

const ZERO_ADDRESS = '0x' + '00'.repeat(20)
const ZERO_BIGNUMBER = BigNumber.from(0)
const NON_ZERO_ADDRESS = '0x' + '11'.repeat(20)
const NON_ZERO_GASLIMIT = BigNumber.from(50_000)
const NON_ZERO_VALUE = BigNumber.from(100)
const NON_ZERO_DATA = '0x' + '11'.repeat(42)

describe('DepositFeed Gas Costs', () => {
  let signer: Signer
  let depositFeed: DepositFeed
  let gm: GasMeasurement
  before(async () => {
    ;[signer] = await ethers.getSigners()
    depositFeed = await new DepositFeed__factory(signer).deploy()
    await depositFeed.deployed()
    gm = new GasMeasurement()
    await gm.init(signer)
  })

  it('Simulated ERC20 deposit data', async () => {
    const cost = await gm.getGasCost(
      depositFeed,
      ZERO_BIGNUMBER,
      'depositTransaction(address,uint256,uint256,bool,bytes)',
      [
        NON_ZERO_ADDRESS,
        ZERO_BIGNUMBER,
        NON_ZERO_GASLIMIT,
        false,
        erc20DepositData,
      ]
    )
    console.log('gasUsed:', cost.toString())
  })

  describe('Lowest cost scenarios', () => {
    it('Depositing a transaction with zero value and no data', async () => {
      const cost = await gm.getGasCost(
        depositFeed,
        ZERO_BIGNUMBER,
        'depositTransaction(address,uint256,uint256,bool,bytes)',
        [NON_ZERO_ADDRESS, NON_ZERO_VALUE, NON_ZERO_GASLIMIT, false, '0x']
      )
      console.log('gasUsed:', cost.toString())
    })

    it('Depositing a creation with 0 value.', async () => {
      const cost = await gm.getGasCost(
        depositFeed,
        ZERO_BIGNUMBER,
        'depositTransaction(address,uint256,uint256,bool,bytes)',
        [ZERO_ADDRESS, NON_ZERO_VALUE, NON_ZERO_GASLIMIT, true, NON_ZERO_DATA]
      )
      console.log('gasUsed:', cost.toString())
    })
  })
})
