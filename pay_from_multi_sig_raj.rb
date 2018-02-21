require 'bitcoin'
require 'open-uri'
require 'net/http'
require 'json'
require 'pp'

def binary_to_hex(str)
  str.unpack("H*").first
end

Bitcoin.network =:regtest

include Bitcoin::Builder

require_relative 'bitcoinrpc.rb'

BTC = 100000000 #satoshi

bitcoinRpc = BitcoinRPC.new('http://rajesh:jab_raj_meets_satoshi@127.0.0.1:18332')


address1="mofitUdewLitMX8qW5hrz5VdJzcXZ4Th1B"
address2="mpS4e8JBeLxczxjbVkGLHCeGaTzdMfF7gy"
address3="n3EdzaomHHQpGyNZLGy5vSQQHD7Lmmbm5q"
#we need to transfer to address4 from multisig (payee address)
address4="n1tPAxp7YWMuy3bVBNpqzfkTyjiMiPfX8a"

##To generate pair of key for each addresses
key1=Bitcoin::Key.from_base58(bitcoinRpc.dumpprivkey(address1))
key2=Bitcoin::Key.from_base58(bitcoinRpc.dumpprivkey(address2))
key3=Bitcoin::Key.from_base58(bitcoinRpc.dumpprivkey(address3))
key4=Bitcoin::Key.from_base58(bitcoinRpc.dumpprivkey(address4))

privkeys = {
 a: bitcoinRpc.dumpprivkey(address1),
 b: bitcoinRpc.dumpprivkey(address2),
 c: bitcoinRpc.dumpprivkey(address3)}
#puts privkeys
keys = privkeys.inject({}) { |memo, item| 
  memo[item.first] = Bitcoin::Key.from_base58(item.last)
  memo
}

keys[:x] = Bitcoin::Key.generate # multisig key

#puts keys

from_multisig_hash = "9bea8f2f427c60b6707ac202e7cc0c6782a7e97a7739c64a2df7d2b3530dcd71"
from_multisig_tx_data = "01000000010d1a99682ae62dbf9e4df6495813952d1ce6a826769b2e23ff79715e25d2594d000000006b48304502210080828db2812ccdbdd79aec7d1a469ff2b80ca94ce99295f8c0839df921e89e5e02202e0ed76c123981b2c98fa00e8c2c6ef6bb436c8c947295be781a350057b46a5401210344c1a8fac17e57664b41b6734417193aa2291ac66a4310deeeacc33f9d6fc9aaffffffff014010212901000000695221029803c607fadf8e5e8e79abe8a26539c3ec68442106d35f3fd0fbf0dbf5ab221421039af217c55b6aacf092d7417ed2525baed05f70ad0f90dad3720821484b116d092103803edc3241c1251ff120b1818b4972b9f9c5c14da9f16705e93dcd276654bdde53ae00000000"
prev_ouput_index = 0

def create_script_sig(sig_hash, *keys)
  signatures = keys.map {|key| key.sign(sig_hash) }
	puts signatures
  first_sig = Bitcoin::Script.to_multisig_script_sig(signatures.shift)
	#puts first_sig  
	signatures.inject(first_sig) { |memo, sig|
    Bitcoin::Script.add_sig_to_multisig_script_sig(sig, memo)
  }
end
=begin
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
  [:b, :a, :c],
  [:a, :b, :c],
]
=end

tests=[ 
[:c, :b, :a],
]


#tests.each do |key_ids|
#  p key_ids
	tx=Bitcoin::Protocol::Tx.new

	tx_in=Bitcoin::Protocol::TxIn.from_hex_hash(from_multisig_hash,prev_ouput_index)
	tx.add_in(tx_in)

	value = 49.85 * BTC - 50000
	tx_out=Bitcoin::Protocol::TxOut.new(value,address4)
	tx.add_out(tx_out)


	prev_tx = Bitcoin::Protocol::Tx.new(from_multisig_tx_data.htb)
	sig_hash = tx.signature_hash_for_input(0, prev_tx, Bitcoin::Script::SIGHASH_TYPE[:all])
	#sig_keys = keys.values_at(*key_ids)
	#script_sig = create_script_sig(sig_hash, *sig_keys)
	script_sig = Bitcoin::Script.to_multisig_script_sig(key1.sign(sig_hash),key2.sign(sig_hash))
	tx.in[0].script_sig = script_sig

	verify_tx = Bitcoin::Protocol::Tx.new(tx.to_payload)
  pp verify: verify_tx.verify_input_signature(0, prev_tx)
#	pp ({ 
#	    key_ids: key_ids,
#	    dump_tx: tx.to_payload.bth,
#	    verify: verify_tx.verify_input_signature(0, prev_tx)
#	  })	
=begin	
	pp ({ 
	   key_ids: [:c,:b,:a],
	   dump_tx: tx.to_payload.bth,
	   verify: verify_tx.verify_input_signature(0, prev_tx)
	 })
=end
#end
 
