use cardano/address.{Address}
use cardano/assets.{PolicyId, from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, find_script_outputs,
}
use cocktail/vodka_address.{address_pub_key}
use cocktail/vodka_extra_signatories.{key_signed}
use cocktail/vodka_mints.{only_minted_token}
use mocktail.{
  add_input, complete, mocktail_tx, required_signer_hash, tx_out,
  tx_out_inline_datum,
}
use mocktail/virgin_address.{mock_pub_key_address, mock_script_address}
use mocktail/virgin_key_hash.{mock_pub_key_hash, mock_script_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}
use mocktail/virgin_outputs.{mock_script_output}
use types.{TreeschainCampaignDatum}

pub type Action {
  Initiate
  Update
}

validator treeschain_registry(v_app_addr: Address, v_campaign_code: ByteArray) {
  mint(
    redeemer: Action,
    policy_id: PolicyId,
    tx: Transaction,
  ) {
    let Transaction { outputs, mint, .. } = tx

    when redeemer is {
      Initiate ->
        only_minted_token(mint, policy_id, v_campaign_code, 1)
      _ -> False
    }
  }

  spend(
    datum_opt: Option<TreeschainCampaignDatum>,
    redeemer: Action,
    utxo: OutputReference,
    tx: Transaction,
  ) {
    // Deconstruct the transaction to extract inputs and outputs
    let Transaction { inputs, outputs, extra_signatories, .. } = tx

    // Find the UTXO being spent in the transaction inputs
    expect Some(datum) = datum_opt
    expect TreeschainCampaignDatum {
      app_addr,
      campaign_code,
      registry_script_hash,
      state,
      ..
    } = datum

    expect Some(app_pub_key) = address_pub_key(v_app_addr)
    let is_app_signed = key_signed(tx.extra_signatories, app_pub_key)

    // Handle the different redeemer cases
    when redeemer is {
      Update -> {
        expect [script_out] = find_script_outputs(outputs, registry_script_hash)

        expect InlineDatum(raw_new_datum) = script_out.datum
        expect new_datum: TreeschainCampaignDatum = raw_new_datum

        let datum_matches = and {
            new_datum.app_addr == app_addr,
            new_datum.campaign_code == campaign_code,
            new_datum.registry_script_hash == registry_script_hash,
          }
        trace @"datum_matches": datum_matches

        let is_state_change_valid = or {
            state == "Open",
            state == "Closed",
          }
        trace @"is_state_change_valid": is_state_change_valid

        datum_matches && is_state_change_valid && is_app_signed
      }

      //Valcampaign_codeate that old datum creator, new datum creator and signatory of this tx are same
      _ -> False
    }
  }

  else(_) {
    fail
  }
}

test success_update_project_datum_close() {
  let redeemer = Update
  let campaign_code = "Sprouts"
  let app_addr_address = mock_pub_key_address(1, None)
  let app_pkh = mock_pub_key_hash(1)
  let script_address = mock_script_address(0, None)
  let script_value = from_lovelace(2_000_000)

  let registry_script_hash = mock_script_hash(0)

  let new_datum =
    TreeschainCampaignDatum {
      app_addr: app_addr_address,
      campaign_code,
      registry_script_hash,
      d_rate: 10_000_000,
      a_rate: 15_000_000,
      state: "Closed",
    }

  let old_datum =
    TreeschainCampaignDatum {
      app_addr: app_addr_address,
      campaign_code,
      registry_script_hash,
      d_rate: 10_000_000,
      a_rate: 15_000_000,
      state: "Open",
    }

  let utxo_ref = mock_utxo_ref(1, 0)

  let tx =
    mocktail_tx()
      |> tx_out(True, script_address, script_value)
      |> tx_out_inline_datum(True, new_datum)
      |> required_signer_hash(True, app_pkh)
      |> complete()
      |> add_input(
          True,
          Input {
            output_reference: utxo_ref,
            output: mock_script_output(
              script_address,
              script_value,
              InlineDatum(old_datum),
            ),
          },
        )

  treeschain_registry.spend(
    app_addr_address,
    campaign_code,
    Some(old_datum),
    redeemer,
    utxo_ref,
    tx,
  )
}
