{-# LANGUAGE DataKinds #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module GADA.Contracts.Trace where

import Control.Monad (void)
import Data.Default (def)
import Data.Monoid (Last (..))
import Ledger qualified
import Ledger.Address (unPaymentPubKeyHash)
import Ledger.Time (POSIXTime (POSIXTime))
import Ledger.TimeSlot (scSlotZeroTime)
import Ledger.Value qualified as Value
import Plutus.Contract (Contract, ContractError, Endpoint, Promise, awaitTxConfirmed)
import Plutus.Contract.Test
import Plutus.Trace (EmulatorTrace, activateContractWallet, callEndpoint, runEmulatorTraceIO, waitNSlots)
import PlutusTx.AssocMap qualified as PtMap

import GADA.Contracts.Common
import GADA.Contracts.OffChain
import GADA.Contracts.OnChain
import GADA.Contracts.Token
import GADA.Contracts.Types
import GADA.Contracts.Utils

import Prelude

anEpochInSec :: Integer
anEpochInSec = 2

anEpochInMs :: Integer
anEpochInMs = anEpochInSec * 1_000

-- | The wallet of the operator.
operatorWallet :: Wallet
operatorWallet = knownWallet 1

-- | The wallet of the client person.
clientWallet :: Wallet
clientWallet = knownWallet 2

authTokenParams :: SeedSaleAuthTokenParams
authTokenParams = SeedSaleAuthTokenParams (unPaymentPubKeyHash (mockWalletPaymentPubKeyHash operatorWallet))

authToken :: Value.AssetClass
authToken = Value.assetClass (seedSaleAuthTokenCurrencySymbol authTokenParams) "seed_sale_auth_token"

seedSaleParams :: SeedSaleParams
seedSaleParams = SeedSaleParams gadaAsset authToken (unPaymentPubKeyHash (mockWalletPaymentPubKeyHash operatorWallet))

endpoints :: Promise () SeedSaleSchema ContractError ()
endpoints = seedSaleEndpoints seedSaleParams

startTimeAfterGenesis :: POSIXTime
startTimeAfterGenesis = scSlotZeroTime def + POSIXTime (anEpochInMs * 2)

createSeedSaleParams :: CreateSeedSaleParams
createSeedSaleParams =
  CreateSeedSaleParams
    (unPaymentPubKeyHash (mockWalletPaymentPubKeyHash operatorWallet))
    1_000
    seedSaleDatum1

seedSaleDatum1 :: SeedSaleDatum
seedSaleDatum1 =
  SeedSaleDatum
    { dListSale = PtMap.fromList [(unPaymentPubKeyHash (mockWalletPaymentPubKeyHash clientWallet), (0, 0))]
    , dRate = 10
    , dAmountPerMonth = 10
    , dMaxAmount = 1_000
    , dNumContract = 1
    , dStart = startTimeAfterGenesis
    }

buySeedSaleParams :: BuySeedSaleParams
buySeedSaleParams =
  BuySeedSaleParams
    { bpNewAmount = 10
    , bpSubmitTime = Nothing
    }

withdrawSeedSaleParams :: WithdrawSeedSaleParams
withdrawSeedSaleParams =
  WithdrawSeedSaleParams
    { wpWithdrawAmount = 10
    , wpSubmitTime = Nothing
    }

seedSaleTrace :: EmulatorTrace ()
seedSaleTrace = do
  void $ activateContractWallet operatorWallet (initGADA @SeedSaleSchema 1000000)
  void $ waitNSlots 2

  hdl <- activateContractWallet operatorWallet endpoints
  callEndpoint @"CreateSeedSale" hdl createSeedSaleParams
  void $ waitNSlots 2

  hdl2 <- activateContractWallet clientWallet endpoints
  callEndpoint @"BuySeedSale" hdl2 buySeedSaleParams
  void $ waitNSlots 2

  hdl2 <- activateContractWallet clientWallet endpoints
  callEndpoint @"WithdrawSeedSale" hdl2 withdrawSeedSaleParams
  void $ waitNSlots 2

runTest :: IO ()
runTest = runEmulatorTraceIO seedSaleTrace
