use aiken/collection/dict
use aiken/primitive/bytearray.{concat,from_string}
use aiken/primitive/int.{from_utf8,to_string}
use aiken/crypto.{ScriptHash}
use cardano/address.{Address}
use cardano/assets.{
  PolicyId, from_asset, from_lovelace, lovelace_of, quantity_of,
}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction
}
use cocktail/vodka_value.{get_all_value_to}
use mocktail/virgin_address.{mock_pub_key_address, mock_script_address}
use mocktail/virgin_key_hash.{
  mock_policy_id, mock_pub_key_hash, mock_script_hash,
}
use mocktail/virgin_output_reference.{mock_utxo_ref}

use mocktail.{
  add_input, add_reference_input, complete, mint, mocktail_tx,
  required_signer_hash, tx_out, tx_out_inline_datum,
}
use types.{TreeschainCampaignDatum}

pub const stable_policy_id: ByteArray =
  #"c3a654d54ddc60c669665a8fc415ba67402c63b58fe65c821d63ba07"

pub const stable_assetname: ByteArray = #"446a65644d6963726f555344"

pub fn extract_number_suffix(b: ByteArray) -> ByteArray {
    expect Some((_, end)) = bytearray.index_of(b, "-x")
    bytearray.slice(b, end + 1, bytearray.length(b) - 1)
}

validator treeschain(v_app_addr: Address, v_campaign_code: ByteArray) {
  mint(redeemer: ByteArray, policy_id: PolicyId, tx: Transaction) {
    let Transaction {reference_inputs, outputs, mint, .. } = tx

    let minted_assets =
      mint
        |> assets.tokens(policy_id) // Extract tokens for the given PolicyId
        |> dict.to_pairs()
    // Verify only one token is minted and retrieve its details
    expect [Pair(asset_name, 1)] = minted_assets

    expect [ref_in] = reference_inputs
        expect InlineDatum(reg_datum) = ref_in.output.datum
        expect TreeschainCampaignDatum {
          app_addr,
      campaign_code,
      registry_script_hash,
      d_rate,
      a_rate,
      state,
        } = reg_datum

        expect and {
        state == "Open",
        v_app_addr == app_addr,
        v_campaign_code == campaign_code
        }


    let quantity_received =
      if redeemer == "DJED" {
        get_all_value_to(outputs, v_app_addr)
          |> quantity_of(stable_policy_id, stable_assetname)
      } else {
        get_all_value_to(outputs, v_app_addr) |> lovelace_of
      }

    let rate =
      if redeemer == "DJED" {
        d_rate
      } else {
        a_rate
      }
      

    //trace @"quantity_received": quantity_received
    //trace @"num_trees": n
    let num_trees = quantity_received / rate
    //expect asset_name = v_campaign_code.concat()
    // trace @"assetname": asset_name
    // trace @"assetname gen": concat(v_campaign_code,"-x") |> concat(from_string(to_string(num_trees))) 
    asset_name == (concat(v_campaign_code,"-x") |> concat(from_string(to_string(num_trees)))) 

  }

  else(_) {
    fail
  }
}

test mint_valid_nft_ada() {
  let app_addr = mock_pub_key_address(0, None)
  let v_campaign_code = "Treeschain-Seeds"
    let registry_address = mock_script_address(0, None)
  let registry_script_hash = mock_script_hash(0)

    let d_rate = 10_000_000
    let a_rate = 15_000_000

  let policy_id = mock_policy_id(0)
  let asset_name = "Treeschain-Seeds-x10"
  let minted_value = from_asset(policy_id, asset_name, 1)
  let received_lovelace = 150_000_000

  let campaign_datum =
    TreeschainCampaignDatum {
      app_addr,
      campaign_code: v_campaign_code,
      registry_script_hash,
      d_rate,
      a_rate,
      state:"Open",
      
    }

    let mock_registry_value = from_lovelace(2_000_000)

  let tx =
    mocktail_tx()
      |> mint(True, 1, policy_id, asset_name)
      |> tx_out(True, app_addr, from_lovelace(received_lovelace))
      |> complete()
      |> add_reference_input(
          True,
          Input {
            output_reference: mock_utxo_ref(0, 0),
            output: Output {
              address: registry_address,
              value: mock_registry_value,
              datum: InlineDatum(campaign_datum),
              reference_script: None,
            },
          },
        )

  treeschain.mint(app_addr, v_campaign_code, "ADA", policy_id, tx)
}


test mint_valid_nft_djed() {
  let app_addr = mock_pub_key_address(0, None)
  let v_campaign_code = "Treeschain-Seeds"
    let registry_address = mock_script_address(0, None)
  let registry_script_hash = mock_script_hash(0)

    let d_rate = 10_000_000
    let a_rate = 15_000_000

  let policy_id = mock_policy_id(0)
  let asset_name = "Treeschain-Seeds-x10"
  let minted_value = from_asset(policy_id, asset_name, 1)
  let received_djed = 100_000_000

  let campaign_datum =
    TreeschainCampaignDatum {
      app_addr,
      campaign_code: v_campaign_code,
      registry_script_hash,
      d_rate,
      a_rate,
      state:"Open",
      
    }

    let mock_registry_value = from_lovelace(2_000_000)

  let tx =
    mocktail_tx()
      |> mint(True, 1, policy_id, asset_name)
      |> tx_out(True, app_addr, from_asset(stable_policy_id,stable_assetname,received_djed))
      |> complete()
      |> add_reference_input(
          True,
          Input {
            output_reference: mock_utxo_ref(0, 0),
            output: Output {
              address: registry_address,
              value: mock_registry_value,
              datum: InlineDatum(campaign_datum),
              reference_script: None,
            },
          },
        )

  treeschain.mint(app_addr, v_campaign_code, "DJED", policy_id, tx)
}

test mint_valid_nft_ada_djed_rate_fail() {
  let app_addr = mock_pub_key_address(0, None)
  let v_campaign_code = "Treeschain-Seeds"
    let registry_address = mock_script_address(0, None)
  let registry_script_hash = mock_script_hash(0)

    let d_rate = 10_000_000
    let a_rate = 15_000_000

  let policy_id = mock_policy_id(0)
  let asset_name = "Treeschain-Seeds-x10"
  let minted_value = from_asset(policy_id, asset_name, 1)
  let received_lovelace = 10 * d_rate

  let campaign_datum =
    TreeschainCampaignDatum {
      app_addr,
      campaign_code: v_campaign_code,
      registry_script_hash,
      d_rate,
      a_rate,
      state:"Open",
      
    }

    let mock_registry_value = from_lovelace(2_000_000)

  let tx =
    mocktail_tx()
      |> mint(True, 1, policy_id, asset_name)
      |> tx_out(True, app_addr, from_lovelace(received_lovelace))
      |> complete()
      |> add_reference_input(
          True,
          Input {
            output_reference: mock_utxo_ref(0, 0),
            output: Output {
              address: registry_address,
              value: mock_registry_value,
              datum: InlineDatum(campaign_datum),
              reference_script: None,
            },
          },
        )

  !treeschain.mint(app_addr, v_campaign_code, "ADA", policy_id, tx)
}