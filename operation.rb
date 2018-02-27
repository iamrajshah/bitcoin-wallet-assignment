# to display help to user
def help
  puts '===================================HELP Section========================'
  puts '1. listutxo - will list all the UTXO in the longest chain of blocks.'
  puts 'cmd:"ruby wallet.rb listutxo"'
  puts '2. generatekey - will generate new address & keys.'
  puts 'cmd:"ruby wallet.rb generatekey"'
  puts '3. listkey - will list all the addresses with their keys on console.'
  puts 'cmd:"ruby wallet.rb listkey"'
  puts '4. sendtoaddress - will send the amount(in BTC) to address.'
  puts 'cmd:"ruby wallet.rb sendtoaddress UTXO vout Amount  ToAddr"'
  puts '5. sendtomultisig - will send the amount(in BTC) to multisig-address.'
  puts 'cmd:"ruby wallet.rb sendtomultisig UTXO vout Amount addr1...addrN"'
  puts '6. redemtoaddress - will send the amount(in BTC) from multisig-address.'
  puts 'cmd:"ruby wallet.rb redemtoaddress _UTXO(multisig) vout amount addr"'
  puts '======================================================================='
end

# to get all UTXO of our wallet
def all_utxo
  best_block_hash = BITCOIN_RPC.getbestblockhash
  block_details = BITCOIN_RPC.getblock(best_block_hash)
  all_addresses_in_wallet = list_all_addresses_from_wallet
  all_transactions = []
  spent_transactions = []
  received_transactions = []
  unspent_transactions = []
  until block_details['previousblockhash'].nil?
    block_details['tx'].each { |trans_id|
    begin
      transaction = BITCOIN_RPC.getrawtransaction(trans_id, true)
      all_transactions << trans_id
      transaction['vin'].each { |vin|
      next if vin['txid'].nil?
      input_transaction = {
        'trans_id' => vin['txid'],
        'vout_index' => vin['vout']
      }
      spent_transactions << input_transaction
      }
        transaction['vout'].each { |vout|
        next if vout['scriptPubKey']['addresses'].nil?
        vout['scriptPubKey']['addresses'].each { |address|
        next unless all_addresses_in_wallet.include? address
        wallet_transaction = {
          'trans_id' => trans_id,
          'block_hash' => block_details['hash'],
          'value' => vout['value'],
          'vout_index' => vout['n'],
          'address' => vout['scriptPubKey']['addresses'],
          'type' => vout['scriptPubKey']['type']
        }
        received_transactions << wallet_transaction
        break
        }
      }
    rescue => ex
      # puts ex.to_s
    end
  }
    block_details = BITCOIN_RPC.getblock block_details['previousblockhash']
  end
  received_transactions.each { |trans|
  next if spent_transactions.any? { |tx|
  tx['trans_id'] == trans['trans_id'] &&
  tx['vout_index'] == trans['vout_index']
  }
  unspent_transactions << trans
  }
  unspent_transactions
end

# to generate new key-pair add into our wallet (csv)
def generate_key()
  key = Bitcoin::Key.generate(compressed: false)
  BITCOIN_RPC.importprivkey(key.to_base58)
  result = nil
  begin
    CSV.open(FILE_NAME, 'a+') do |csv_write|
      if csv_write
        csv_write << [key.addr, key.pub, key.to_base58]
        result = {
          'Address' => key.addr,
          'PublicKey' => key.pub
        }
      end
    end
  rescue
    p 'File creation error'
  end
  puts JSON.pretty_generate(result)
end

# to display all key-pair present in our wallet (csv)
def list_key
  result = nil
  begin
    CSV.foreach(FILE_NAME) do |row|
      if row
        result = { 'Address' => row[0], 'PublicKey' => row[1],
        'PrivateKey' => row[2] }
      end
      puts JSON.pretty_generate(result)
    end
  rescue
    puts 'File not present'
  end
end

# to send BTC to particular address
def send_to_address(prev_tx_id, vout_prev_tx, to_address, amount)
  previous_transaction_id = prev_tx_id
  previous_transaction_vout = vout_prev_tx
  payee_address = to_address
  begin
    transfer_amount = bitcoin_to_satoshi(amount)
    previous_transaction_hex =
    BITCOIN_RPC.getrawtransaction(previous_transaction_id)
    previous_transaction =
    Bitcoin::Protocol::Tx.new(previous_transaction_hex.htb)
    previous_transaction_balance =
    previous_transaction.out[previous_transaction_vout].value
    previous_transaction_address =
    previous_transaction.out[previous_transaction_vout].parsed_script.get_address
    key = key_object_for_address(previous_transaction_address)
    change_amount = (previous_transaction_balance - transfer_amount - FEE)
    change_address = previous_transaction_address
    new_transaction = Bitcoin::Protocol::Tx.new
    transaction_input =
    Bitcoin::Protocol::TxIn.from_hex_hash(previous_transaction_id, previous_transaction_vout)
    new_transaction.add_in(transaction_input)
    transaction_output_payee =
    Bitcoin::Protocol::TxOut.value_to_address(transfer_amount, payee_address)
    transaction_output_remaining =
    Bitcoin::Protocol::TxOut.value_to_address(change_amount, change_address)
    new_transaction.add_out(transaction_output_payee)
    new_transaction.add_out(transaction_output_remaining)
    signature_hash =
    new_transaction.signature_hash_for_input(0, previous_transaction)
    signature = key.sign(signature_hash)
    script_sig =
    Bitcoin::Script.to_signature_pubkey_script(signature, key.pub.htb)
    new_transaction.in[0].script_sig = script_sig
    # puts new_transaction.to_payload.bth
    # Code to verify input signature
    # verify_transaction = Bitcoin::Protocol::Tx.new(new_transaction.to_payload)
    #	p ({verify: verify_transaction.verify_input_signature(0, previous_transaction)})
    transaction_id = BITCOIN_RPC.sendrawtransaction new_transaction.to_payload.bth
    transaction_id
  rescue => ex
    p ex.to_s
  end
end

# to send BTC from multisig to other address
def redem_to_address(previous_tx_id, vout_prev_tx, amount,to_address)
  previous_transaction_id = previous_tx_id
  previous_transaction_vout = vout_prev_tx
  begin
    transfer_amount = bitcoin_to_satoshi(amount)
    previous_transaction_hex =
    BITCOIN_RPC.getrawtransaction(previous_transaction_id)
    previous_transaction =
    Bitcoin::Protocol::Tx.new(previous_transaction_hex.htb)
    puts JSON.pretty_generate( previous_transaction )
    previous_transaction_addresses =
    previous_transaction.out[previous_transaction_vout].parsed_script.get_addresses
    # p previous_transaction.out[previous_transaction_vout]
    p previous_transaction_addresses
    previous_transaction_balance =
    previous_transaction.out[previous_transaction_vout].value
    min_signatures_required =
    previous_transaction.out[previous_transaction_vout].parsed_script.get_signatures_required
    previous_pubkeys = []
    previous_keys = []
    previous_transaction_addresses.each { |address|
    previous_key = key_object_for_address(address)
    previous_pubkeys << previous_key.pub
    previous_keys << previous_key
    }
    p *previous_pubkeys
    multisig_script =
    Bitcoin::Script.to_multisig_script(min_signatures_required, *previous_pubkeys)
    change_amount =
    (previous_transaction_balance - transfer_amount - FEE)
    new_transaction = Bitcoin::Protocol::Tx.new
    transaction_input =
    Bitcoin::Protocol::TxIn.from_hex_hash(previous_transaction_id, previous_transaction_vout)
    new_transaction.add_in(transaction_input)
    transaction_output_payee =
    Bitcoin::Protocol::TxOut.value_to_address(transfer_amount, to_address)
    transaction_output_remaining =
    Bitcoin::Protocol::TxOut.new(change_amount, multisig_script)
    new_transaction.add_out(transaction_output_payee)
    new_transaction.add_out(transaction_output_remaining)
    signature_hash =
    new_transaction.signature_hash_for_input(0, previous_transaction, Bitcoin::Script::SIGHASH_TYPE[:all])
    # p signature_hash
    previous_keys = previous_keys.reverse()
    key = previous_keys.shift()
    # p key
    signature = key.sign(signature_hash)
    # p signature.to_s
    partially_signed = Bitcoin::Script.to_multisig_script_sig(signature)
    signed_by_signature = 1
    # p signed_by_signature
    # loop to sign the transaction by required number key
    while signed_by_signature < min_signatures_required
      # p signed_by_signature
      key = previous_keys.shift()
      signature = key.sign(signature_hash)
      partially_signed =
      Bitcoin::Script.add_sig_to_multisig_script_sig(signature, partially_signed)
      signed_by_signature += 1
    end
    # p partially_signed
    script_sig = partially_signed
    new_transaction.in[0].script_sig = script_sig
    # p new_transaction.to_payload.bth
    # Uncomment following code to verify the signature
    # verify_transaction=Bitcoin::Protocol::Tx.new(new_transaction.to_payload)
    # p ({verify:verify_transaction.verify_input_signature(0,previous_transaction)})
    transaction_id =
    BITCOIN_RPC.sendrawtransaction(new_transaction.to_payload.bth)
    return transaction_id
  rescue => ex
    puts ex.to_s
    return ex.to_s
  end
end

# to send BTC to multisig address (in old way)
def send_to_multisig(previous_tx_id, vout_ptx, amount, *multi_sig_address)
  # p multi_sig_address
  previous_transaction_id = previous_tx_id
  previous_transaction_vout = vout_ptx
  begin
    transfer_amount = bitcoin_to_satoshi(amount)
    payee_address_list = *multi_sig_address
    payee_pubkeys = []
    payee_address_list.each { |address|
    payee_key = key_object_for_address(address)
    payee_pubkeys << payee_key.pub
    }
    # p payee_pubkeys
    multisig_script = Bitcoin::Script.to_multisig_script(2, *payee_pubkeys)
    previous_transaction_hex =
    BITCOIN_RPC.getrawtransaction(previous_transaction_id)
    previous_transaction =
    Bitcoin::Protocol::Tx.new(previous_transaction_hex.htb)
    previous_transaction_balance =
    previous_transaction.out[previous_transaction_vout].value
    previous_transaction_address =
    previous_transaction.out[previous_transaction_vout].parsed_script.get_address
    key = key_object_for_address(previous_transaction_address)
    change_amount = (previous_transaction_balance - transfer_amount - FEE)
    new_transaction = Bitcoin::Protocol::Tx.new
    input_transaction =
    Bitcoin::Protocol::TxIn.from_hex_hash(previous_tx_id, previous_transaction_vout)
    new_transaction.add_in(input_transaction)
    output_to_multisig =
    Bitcoin::Protocol::TxOut.new(transfer_amount, multisig_script)
    output_to_remaining =
    Bitcoin::Protocol::TxOut.value_to_address(change_amount, previous_transaction_address)
    new_transaction.add_out(output_to_multisig)
    new_transaction.add_out(output_to_remaining)
    signature_hash =
    new_transaction.signature_hash_for_input(0, previous_transaction, Bitcoin::Script::SIGHASH_TYPE[:all])
    signature = key.sign(signature_hash)
    script_sig =
    Bitcoin::Script.to_signature_pubkey_script(signature,key.pub.htb, Bitcoin::Script::SIGHASH_TYPE[:all])
    new_transaction.in[0].script_sig = script_sig
    # Uncomment following code to verify the signature
    # verify_transaction=Bitcoin::Protocol::Tx.new(new_transaction.to_payload)
    # p ({verify:verify_transaction.verify_input_signature(0,previous_transaction)})
    # p new_transaction.to_payload.bth
    new_transaction_id =
    BITCOIN_RPC.sendrawtransaction(new_transaction.to_payload.bth)
    new_transaction_id
  rescue => ex
    puts ex.to_s
    puts ex.backtrace.inspect
  end
end
