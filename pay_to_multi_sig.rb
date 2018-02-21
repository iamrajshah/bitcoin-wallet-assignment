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

script_pubkey = Bitcoin::Script.to_multisig_script(2, keys[:a].pub, keys[:b].pub, keys[:c].pub)

p ({ script_pubkey: script_pubkey })

p ({ dump_script_pubkey: Bitcoin::Script.new(script_pubkey).to_string })

prev_tx_hash = "085f392c12aa6bb6343cb24112c9359346700edc0da46869064ed7e17082e725"
prev_tx_data = "0100000001612fa1406152fd29d889dc79d8d00dea319a6805d2d0936ed7fa86ed3c8baf710000000049483045022100e9b3fd00a760931f890f343ca94bf3c7c0a6d6716d86e5059fa6d23ae7e5ccd102202fdf0973e4230d145b4c3d91069122cb6baeb0221d8f6e9bf3d85f6f249a297501ffffffff01b02e052a010000001976a914f4e9a9818ec928e5dd95b0e9670f8e4a2d9c64cd88ac00000000"
prev_ouput_index = 0

tx = Bitcoin::Protocol::Tx.new

tx_in = Bitcoin::Protocol::TxIn.from_hex_hash(prev_tx_hash, prev_ouput_index)
tx.add_in(tx_in)

value = 10 * BTC - 50000
tx_out = Bitcoin::Protocol::TxOut.new(value, script_pubkey)
tx.add_out(tx_out)

prev_tx = Bitcoin::Protocol::Tx.new(prev_tx_data.htb)
privkey = "cPCn2XsoveFhnaShALsEG6FkyEzC1GS8cWL2j2BHXn4WrDZfkuLr"
key = Bitcoin::Key.from_base58(privkey)
sig_hash = tx.signature_hash_for_input(0, prev_tx, Bitcoin::Script::SIGHASH_TYPE[:all])
signature = key.sign(sig_hash)
script_sig = Bitcoin::Script.to_signature_pubkey_script(signature, key.pub.htb, Bitcoin::Script::SIGHASH_TYPE[:all])
tx.in[0].script_sig = script_sig
p ({ dump_tx: tx.to_payload.bth })

verify_tx = Bitcoin::Protocol::Tx.new(tx.to_payload)
p ({ verify: verify_tx.verify_input_signature(0, prev_tx) })
