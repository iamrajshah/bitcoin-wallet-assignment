# To validate send to parameter for
def valid_send_to_parameter_list(is_redem, *param_data)
  response = {}
  transaction_info =
  transaction_info_from_utxo(param_data[1], param_data[2].to_i)
  #p transaction_info
  begin
    # to check valid address
    unless valid_address?(param_data[4])
      response['error'] = 'Incorrect bitcoin address'
      return response
    end
    # to check valid transaction provided by user
    if transaction_info.nil?
      response['error'] = 'Transaction is spent already'
      return response
    end
    # to check valid vout index
    if transaction_info['vout_index'] != param_data[2].to_i
      response['error'] = 'vout is invalid for this transaction id'
      return response
    end
    # to check valid amount entered by user
    # p bitcoin_to_satoshi ( transaction_info[:value] )
    # p ( bitcoin_to_satoshi( param_data[3].to_f ) + FEE )
    if bitcoin_to_satoshi(transaction_info['value']) < \
       (bitcoin_to_satoshi(param_data[3].to_f) + FEE)
      response['error'] = 'Insufficient balance in UTXO'
      return response
    end
    # to check whether receiver address is same as sender
    # p transaction_info[:address][0]
    if transaction_info['address'][0] == param_data[4]
      response['error'] = 'You cannot send money to same address.'
      return response
    end
    if is_redem
      if transaction_info['type'] != 'multisig'
        response['error'] = 'To redem input transaction must be mulitsig'
        return response
      end
    end
    # everything seems to be fine so proceed
    response['status'] = true
    return response
  rescue => ex
    puts ex.to_s
    puts ex.message
    puts ex.backtrace.inspect
    # p Exception
    # input might be wrong so it has thrown exception
    response['error'] = 'Invalid Parameter values'
    return response
  end
end

# To validate multisig parameter
def valid_multi_sig_parameter_list(*param_data)
  response = {}
  transaction_info =
  transaction_info_from_utxo(param_data[1], param_data[2].to_i)
  begin
    for i in 4..(ARGV.length - 1) do
      unless valid_address?(ARGV[i])
        response['error'] = 'Incorrect bitcoin address #{ARGV[i]}'
        return response
      end
    end
    if transaction_info.nil?
      response['error'] = 'Transaction is spent already'
      return response
    end
    if transaction_info['vout_index'] != param_data[2].to_i
      response['error'] = 'vout is invalid for this transaction id'
      return response
    end
    if bitcoin_to_satoshi(transaction_info['value']) < \
       (bitcoin_to_satoshi(param_data[3].to_f) + FEE)
      response['error'] = 'Insufficient balance in UTXO'
      return response
    end	
    response['status'] = true
    return response
  rescue => ex
    puts ex.to_s
    puts ex.message
    puts ex.backtrace.inspect
    response['error'] = 'Invalid Parameter values'
    return response
  end
end

# To check address belong to out wallet
def valid_address?(address)
  all_addresses = list_all_addresses_from_wallet
  all_addresses.include? address
end

# Get list of all addresses available in the wallet
def list_all_addresses_from_wallet
  list_of_addresses = []
  CSV.foreach(FILE_NAME) do |row|
    list_of_addresses << row[0]
  end
  list_of_addresses
end

# To fetch private key from CSV
def private_key_for_address(address)
  private_key = nil
  CSV.foreach(FILE_NAME) do |row|
    if address == row[0]
      private_key = row[2]
      break
    end
  end
  private_key
end

# To check the given transaction is belongs to our wallet
def transaction_info_from_utxo(txid, vout)
  list_of_all_transaction = all_utxo
  transaction = nil
  list_of_all_transaction.each { |utxo|
  if(utxo['trans_id'] == txid && utxo['vout_index'] == vout)
    transaction = utxo
  end
  }
  transaction
end
