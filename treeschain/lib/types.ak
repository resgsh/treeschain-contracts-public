use aiken/crypto.{ScriptHash}
use cardano/address.{Address}
use cardano/assets.{PolicyId}

pub type TreeschainCampaignDatum {
  app_addr: Address,
  campaign_code: ByteArray,
  registry_script_hash: ScriptHash,
  d_rate: Int,
  a_rate: Int,
  state: ByteArray,
}
