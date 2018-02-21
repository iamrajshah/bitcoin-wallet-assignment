require 'pp'
require 'bitcoin'

Bitcoin.network = :regtest

BTC = 100000000 #satoshi

privkeys = {
  a: "cR4x5UE6go4sjTC8QDUM7KCoywkuvkgQTqe3GMfJZjJTYu52oCAv", # mjFokZ6Pw3G3ooXkW5vjSfYJGFTqbTsRiQ
  b: "cPN9MBnaQbtmYeLtxEVLShGSf2wtTRSn5HheGSzjrWfa3dxk6tqT", # mxitqdGcT6X7kMEhDoqgkFoHdEVtXLGcfq
  c: "cTByZy1QcomJDAgDQgfhQCzwTNdHMemkYco5UkRCr8hWhFGYGDdz" # n3w6s4KAEzQs1xqdBQdSPqKRFPhwupwW4r
}

keys = privkeys.inject({}) { |memo, item| 
  memo[item.first] = Bitcoin::Key.from_base58(item.last)
  memo
}

keys[:x] = Bitcoin::Key.generate # multisig key

prev_tx_hash = "5e0f4bfb46159327b7550d7f4245cd87b9f9272ae66f492677a6dd831b5c5268"
prev_tx_data = "010000000125e78270e1d74e066968a40ddc0e70469335c91241b23c34b66baa122c395f08000000006b483045022100d596f05063133c3406ff135deeed508e7a953069e1d80f11f37bfc22b482c63b02200adce74341b0233969b6eb7933eb312d5a3b17b0497241ceb94d87ce98e06a6e012102271ed5ba3640f1e8f9377af651759d533949fb1d0f5eb278b350b273cef1172fffffffff01b0069a3b000000006952210346a947963ecfd2d512a812fc1062e13a6d3e40dd3255affc1a57377361bb5fa22102dd2de9765da991aba0144dd2de22deb768c4f23b0c841e98344b909e7beffe60210343c92b08019ea70cf8ae74347f417eb1bfc588f4355cc185c781f0b2cf1c7f0153ae00000000"
prev_ouput_index = 0

def create_script_sig(sig_hash, *keys)
  signatures = keys.map {|key| key.sign(sig_hash) }
  first_sig = Bitcoin::Script.to_multisig_script_sig(signatures.shift)
  signatures.inject(first_sig) { |memo, sig|
    Bitcoin::Script.add_sig_to_multisig_script_sig(sig, memo)
  }
end

tests = [
  [:a],
  [:a, :x],
  [:a, :b],
  [:b, :c],
  [:b, :a],
  [:c, :a],
  [:c, :b],
  [:c, :b, :a],
  [:c, :b, :x],
  [:c, :a, :b],
]

tests.each do |key_ids|
  tx = Bitcoin::Protocol::Tx.new

  tx_in = Bitcoin::Protocol::TxIn.from_hex_hash(prev_tx_hash, prev_ouput_index)
  tx.add_in(tx_in)

  value = 5 * BTC - 50000
  payee_address = "mtsgWs9ySM2caQwCRKhdWyqb6bz3czdZYQ"
  tx_out = Bitcoin::Protocol::TxOut.value_to_address(value, payee_address)
  tx.add_out(tx_out)

  prev_tx = Bitcoin::Protocol::Tx.new(prev_tx_data.htb)

  sig_hash = tx.signature_hash_for_input(0, prev_tx, Bitcoin::Script::SIGHASH_TYPE[:all])
  sig_keys = keys.values_at(*key_ids)
  script_sig = create_script_sig(sig_hash, *sig_keys)
  tx.in[0].script_sig = script_sig

  verify_tx = Bitcoin::Protocol::Tx.new(tx.to_payload)
  pp ({ 
    key_ids: key_ids,
    dump_tx: tx.to_payload.bth,
    verify: verify_tx.verify_input_signature(0, prev_tx)
  })
end
