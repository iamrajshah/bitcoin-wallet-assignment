#wallet created by raj21
require 'bitcoin'
require 'json'
require 'csv'
Bitcoin.network =:regtest
include Bitcoin::Builder
require_relative 'bitcoinrpc.rb'

$bitcoinRpc = BitcoinRPC.new('http://rajesh:jab_raj_meets_satoshi@127.0.0.1:18332')
$BTC = 100000000 #satoshi

def helpFunction
	puts "==========================HELP Section==================================================="
	puts "1. listutxo - will list all the UTXO in the longest chain of blocks.\ncmd:\'ruby wallet.rb listutxo\'"
	puts "2. generatekey - will generate new address & keys.\ncmd:\'ruby wallet.rb generatekey\'"
	puts "3. listkey - will list all the addresses with their keys on console.\ncmd:\'ruby wallet.rb listkey\'"
	puts "4. sendtoaddress - will send the amount(in BTC) to address.\ncmd:\'ruby wallet.rb sendtoaddress _UnspentTXID_ _vout_ _Amount_ _ToAddress_\'"
	puts "5. sendtomultisig - will send the amount(in BTC) to multisig-address.\ncmd:\'ruby wallet.rb sendtomultisig _UnspentTXID_ _vout_ _Amount_ _Address1_..._AddressN_\'"
	puts "6. redemtoaddress - will send the amount(in BTC) to address from multisig-address.\ncmd:\'ruby wallet.rb redemtoaddress _UnspentTXID_ _vout_ _Amount_ _ToAddress_\'"
	puts "=========================================================================================="
end	

def listUnspentFunction
	#For getting the longest blockchain info
	bestBlockHash=$bitcoinRpc.getbestblockhash
	#For getting the best block
	blockHash=$bitcoinRpc.getblock(bestBlockHash)				
	#We want to get all the transaction id present in the block
	listOfTransaction=blockHash["tx"]
	#Traverse through each transaction
	counter=0
	balanceOfUTXO=0
	listOfTransaction.each do |i|
		counter+=1
		puts counter
		
		getTransactionInfo=$bitcoinRpc.getrawtransaction(i,true)
		res=
		{
		 "txid":" #{getTransactionInfo["txid"]}",
		 "hash": "#{getTransactionInfo["hash"]}"
		}
		#puts "txid: #{getTransactionInfo["txid"]}"
		#puts "hash: #{getTransactionInfo["hash"]}"
		vout=getTransactionInfo["vout"]					
		#traverse through vout of every transaction
		vout.each do |j|
			if j["scriptPubKey"]["type"] != "nulldata"
				#puts j
				res["vout"]="#{j["n"]}"
				res["amount"]="#{j["value"]}"
				balanceOfUTXO+=j["value"]
				res["addresses"]="#{j["scriptPubKey"]["addresses"]}"
				#puts  "amount: #{j["value"]}"
				#puts  "vout: #{j["n"]}"
				#puts  "addresses:#{j["scriptPubKey"]["addresses"]}"
				puts JSON.pretty_generate(res)
				
			end #if	
		end #loop traverse through vout					
	puts "\n"
	  
				
	end #loop traverse through transaction
   puts "Balance: #{balanceOfUTXO}"
end	

def generatekeyFunction
	key=Bitcoin::Key.generate(opts={compressed:false})
	$bitcoinRpc.importprivkey(key.to_base58)
	CSV.open("keys.csv", "a") do |csvWrite|
		csvWrite<<[key.addr,key.priv,key.pub] 
	res=
		{
			"Address":key.addr,"PublicKey":key.pub
		}
		puts JSON.pretty_generate(res)
	end #file write loop
end

def listkeyFunction
	CSV.foreach('keys.csv') do |row|
	res=
	{
		"Address":row[0],
		"PrivateKey":row[1],
		"PublicKey":row[2]
	}
	puts JSON.pretty_generate(res)
	
	end #loop end
end

def chechkSuitableTransaction(amountWishedByUser)
	#For getting the longest blockchain info
	bestBlockHash=$bitcoinRpc.getbestblockhash
	#For getting the best block
	blockHash=$bitcoinRpc.getblock(bestBlockHash)				
	#We want to get all the transaction id present in the block
	listOfTransaction=blockHash["tx"]
	#Traverse through each transaction
	
	balanceOfUTXO=0
	listOfTransaction.each do |i|
		
		getTransactionInfo=$bitcoinRpc.getrawtransaction(i,true)
		
		vout=getTransactionInfo["vout"]					
		#traverse through vout of every transaction
		vout.each do |j|
			if j["scriptPubKey"]["type"] != "nulldata"
				balanceOfUTXO+=j["value"]
			
				if Float(balanceOfUTXO) >= amountWishedByUser
					return  getTransactionInfo["txid"],j["n"],j["value"],j["scriptPubKey"]["addresses"] 	
				
				end #if	
			end #loop traverse through vout					
				
		end #loop traverse through transaction
	end 
end	

def sendtoaddress(previousTxId,voutOfPtx,toAddresss,amount)
	#considering all inputs are valid
	#now check is their enough amount in that UTXO
	previousTxValue=$bitcoinRpc.gettxout(previousTxId,voutOfPtx)
	previousTxData=$bitcoinRpc.gettransaction(previousTxId)
	previousTxData=previousTxData["hex"].to_s
	previousTx=Bitcoin::P::Tx.new(previousTxData.htb)
	#p previousTx
	amountToBeTransfer=($BTC * amount) + 50000
	previousTxBalance=($BTC * previousTxValue["value"])
	#p amountToBeTransfer
	#p previousTxBalance
	#p previousTx["scriptPubKey"]["addresses"][0]
	#p previousTxBalance/$BTC
	#p amountToBeTransfer/$BTC
	if previousTxBalance < amountToBeTransfer #insufficient fund
		puts "In-sufficient fund in UTXO"
	else #yes we can transfer
		
		keyOfPreviousAddress=Bitcoin::Key.from_base58($bitcoinRpc.dumpprivkey(previousTxValue["scriptPubKey"]["addresses"][0]))
		amountToBeTransfer-=50000
		remainingBalance=previousTxBalance-amountToBeTransfer-50000
		#p remainingBalance
		tx_to_transfer_account=build_tx do |t|
			t.input do |i|
				i.prev_out previousTx
				i.prev_out_index voutOfPtx
				i.signature_key keyOfPreviousAddress
			end
			t.output do |o|
				o.value amountToBeTransfer
				o.script {|s| s.recipient toAddresss}
			end
			t.output do |o|
				o.value remainingBalance
				o.script {|s| s.recipient previousTxValue["scriptPubKey"]["addresses"][0]}
			end
		end	
		
		puts tx_to_transfer_account.to_json
		
		tx_to_account=Bitcoin::Protocol::Tx.new(tx_to_transfer_account.to_payload)
		p tx_to_account.verify_input_signature(0,previousTx)==true
		hex_transaction=tx_to_account.to_payload.unpack("H*")[0]
		p hex_transaction
		transactionId=$bitcoinRpc.sendrawtransaction(hex_transaction)
		p transactionId
		
	end
end

def is_number? string
	true if Float(string) rescue false
end



def sendtomultisig(previousTxId,voutOfPtx,amount,*mulSigAddresss)
	#considering all inputs are valid
	#now check is their enough amount in that UTXO
	p mulSigAddresss
	previousTxValue=$bitcoinRpc.gettxout(previousTxId,voutOfPtx)
	previousTxData=$bitcoinRpc.gettransaction(previousTxId)
	previousTxData=previousTxData["hex"].to_s
	previousTx=Bitcoin::P::Tx.new(previousTxData.htb)
	#p previousTx
	amountToBeTransfer=($BTC * amount) + 50000
	previousTxBalance=($BTC * previousTxValue["value"])
	#p amountToBeTransfer
	#p previousTxBalance
	if previousTxBalance < amountToBeTransfer #insufficient fund
		puts "In-sufficient fund in UTXO"
	else #yes we can transfer
		#create a transaction to send to multisig address
		#create a array of private keys
		listOfPrivateKeys={}
		listOfPublicKeys=[]
		counter=0
		mulSigAddresss.each do |addr|
			counter+=1
			listOfPrivateKeys["#{counter}"]=Bitcoin::Key.from_base58($bitcoinRpc.dumpprivkey(addr))
			listOfPublicKeys.push((listOfPrivateKeys["#{counter}"].pub))
		end
		#p listOfPrivateKeys["1"].pub
		#p listOfPublicKeys
		#listOfPrivateKeys=listOfPrivateKeys.to_json	
		#p listOfPrivateKeys
		#p listOfPrivateKeys["1"].pub
		#script_pubkey = Bitcoin::Script.to_multisig_script(2, listOfPrivateKeys["1"].pub, listOfPrivateKeys["2"].pub)
		script_pubkey = Bitcoin::Script.to_multisig_script(1, *listOfPublicKeys)
		#p ({ script_pubkey: script_pubkey })
		#p ({ dump_script_pubkey: Bitcoin::Script.new(script_pubkey).to_string })

		keyOfPreviousAddress=Bitcoin::Key.from_base58($bitcoinRpc.dumpprivkey(previousTxValue["scriptPubKey"]["addresses"][0]))
		amountToBeTransfer-=50000
		remainingBalance=previousTxBalance-amountToBeTransfer-50000

		tx = Bitcoin::Protocol::Tx.new

		tx_in = Bitcoin::Protocol::TxIn.from_hex_hash(previousTxId, voutOfPtx)
		tx.add_in(tx_in)

		
		tx_out = Bitcoin::Protocol::TxOut.new(amountToBeTransfer, script_pubkey)
		tx.add_out(tx_out)
		tx_out_remaining = Bitcoin::Protocol::TxOut.new(remainingBalance, previousTxValue["scriptPubKey"]["addresses"][0])
		tx.add_out(tx_out_remaining)

		sig_hash = tx.signature_hash_for_input(0, previousTx, Bitcoin::Script::SIGHASH_TYPE[:all])
		signature = keyOfPreviousAddress.sign(sig_hash)
		script_sig = Bitcoin::Script.to_signature_pubkey_script(signature, keyOfPreviousAddress.pub.htb, Bitcoin::Script::SIGHASH_TYPE[:all])
		tx.in[0].script_sig = script_sig
		#p ({ dump_tx: tx.to_payload.bth })

		verify_tx = Bitcoin::Protocol::Tx.new(tx.to_payload)
		p ({ verify: verify_tx.verify_input_signature(0, previousTx) })

		hex_transaction=verify_tx.to_payload.unpack("H*")[0]
		p hex_transaction
		transactionId=$bitcoinRpc.sendrawtransaction(hex_transaction)
		p transactionId

		
	end
end

def redemtoaddress(previousTxId,voutOfPtx,amount,toAddresss)
	previousTxValue=$bitcoinRpc.gettxout(previousTxId,voutOfPtx)
	previousTxData=$bitcoinRpc.gettransaction(previousTxId)
	previousTxData=previousTxData["hex"].to_s
	previousTx=Bitcoin::P::Tx.new(previousTxData.htb)
	#script_pubkey=previousTxValue["scriptPubKey"]["asm"]
	
	listOfAllAddress=previousTxValue["scriptPubKey"]["addresses"]
	
	listOfPrivateKeys={}
	listOfPublicKeys=[]
	counter=0
	listOfAllAddress.each do |addr|
		counter+=1
		listOfPrivateKeys["#{counter}"]=Bitcoin::Key.from_base58($bitcoinRpc.dumpprivkey(addr))
		listOfPublicKeys.push((listOfPrivateKeys["#{counter}"].pub))
	end
	script_pubkey = Bitcoin::Script.to_multisig_script(1, *listOfPublicKeys)
	amountToBeTransfer=($BTC * amount) + 50000
	previousTxBalance=($BTC * previousTxValue["value"])
	if previousTxBalance < amountToBeTransfer #insufficient fund
		puts "In-sufficient fund in UTXO"
	else #yes we can transfer
		amountToBeTransfer-=50000
		remainingBalance=previousTxBalance-amountToBeTransfer-50000
		tx=Bitcoin::Protocol::Tx.new

		tx_in=Bitcoin::Protocol::TxIn.from_hex_hash(previousTxId,voutOfPtx)
		tx.add_in(tx_in)

		tx_out=Bitcoin::Protocol::TxOut.value_to_address(amountToBeTransfer,toAddresss)
		tx.add_out(tx_out)
		tx_out_remaining=Bitcoin::Protocol::TxOut.new(remainingBalance,script_pubkey)
		tx.add_out(tx_out_remaining)
		sig_hash = tx.signature_hash_for_input(0, previousTx, Bitcoin::Script::SIGHASH_TYPE[:all])
		#p sig_hash
		script_sig = Bitcoin::Script.to_multisig_script_sig(listOfPrivateKeys["2"].sign(sig_hash))
		tx.in[0].script_sig = script_sig
		#p tx.to_json
		verify_tx = Bitcoin::Protocol::Tx.new(tx.to_payload)
		p verify: verify_tx.verify_input_signature(0, previousTx)

		hex_transaction=verify_tx.to_payload.unpack("H*")[0]
		p hex_transaction
		transactionId=$bitcoinRpc.sendrawtransaction(hex_transaction)
		p transactionId

	end	
end	

if ARGV.length>0
	

	command=ARGV[0]	
	case command
		when "help"
			helpFunction
		
		when "listutxo"
			if ARGV.length>1
				puts "No argument with \'listutxo\' command please try running\n\'ruby wallet.rb listutxo\'"
			else
				listUnspentFunction
			end #if end
		
		when "generatekey"
			if ARGV.length>1
				puts "No argument with \'generatekey\' command please try running\n\'ruby wallet.rb listutxo\'"
			else
				generatekeyFunction
			end	#if end

		when "listkey"
			if ARGV.length>1
				puts "No argument with \'listkey\' command please try running\n\'ruby wallet.rb listutxo\'"
			else
				listkeyFunction
			end #if end

		when "sendtoaddress2p"
			if ARGV.length<2
				puts "Invalid argument-list with \'sendtoaddress\' command please try running\n\'ruby wallet.rb sendtoaddress _ToAddress_ _Amount_\'"
			else
				if Bitcoin.valid_address? ARGV[1]
					txId,vout,amount,address=chechkSuitableTransaction(ARGV[2].to_f)
					p txId
					p vout
					p amount
					p address
					remainingBalanceNeedTotransferBack=amount-ARGV[2].to_f
					puts "remaining amount #{remainingBalanceNeedTotransferBack}"
				#we need to check from our UTXO balance
				#transfer money to address send in parameter
				#remaining amount transfer back to original account
				else
					p "Invalid bitcoin address"
				end	
			end	#if end
		when "sendtoaddress"
			if ARGV.length<4
				puts "Invalid argument-list with \'sendtoaddress\' command please try running\n\'ruby wallet.rb sendtoaddress _UnspentTXID_ _vout_ _Amount_ _ToAddress_ \'"
			else
				if !Bitcoin.valid_address? ARGV[4]  
					puts "Invalid bitcoin address"
				elsif !is_number? ARGV[3]
					puts "Invalid amount"
				elsif !is_number? ARGV[2] 
					puts "Invalid vout"
				else
					sendtoaddress(ARGV[1],ARGV[2].to_i,ARGV[4],ARGV[3].to_f)
					
					
				end	
			end	
		when "sendtomultisig"
			#p ARGV.length
			#p ARGV
			if ARGV.length<4
				puts "Invalid argument-list with \'sendtomultisig\' command please try running\n\'ruby wallet.rb sendtomultisig _UnspentTXID_ _vout_ _Amount_ _Address1_..._AddressN \'"
			else 
				listofaddresses=[]
				for i in 4..(ARGV.length-1) do
					listofaddresses << ARGV[i]
				end
				puts listofaddresses
				sendtomultisig(ARGV[1],ARGV[2].to_i,ARGV[3].to_f,*listofaddresses)	
			end	
		when "redemtoaddress"
			if ARGV.length<4
				puts "Invalid argument-list with \'redeemtoaddress\' command please try running\n\'ruby wallet.rb redeemtoaddress _UnspentTXID_ _vout_ _Amount_ _Address_ \'"
			else
				redemtoaddress(ARGV[1],ARGV[2].to_i,ARGV[3].to_f,ARGV[4])
				#p ARGV	
			end	
		else puts"Sorry !!! You mis-spelled command, if you need any help try running\n\'ruby wallet.rb help\'"
	end #case end
else 
	puts"Sorry !!! You forgot to send command, if you need any help try running\n\'ruby wallet.rb help\'"
end #if end


