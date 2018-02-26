# To convert BTC to satoshi
def bitcoin_to_satoshi(param_data)
  (param_data * BTC)
end

# To convert sathoshi to BTC
def satoshi_to_bitcoin(param_data)
  (param_data / BTC)
end

# To get Key object for given address
def key_object_for_address(address)
  privkey = private_key_for_address(address)
  key = Bitcoin::Key.from_base58(privkey)
  key
end
