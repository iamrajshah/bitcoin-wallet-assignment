#wallet created by raj21
require 'bitcoin'
require 'json'
require 'csv'
Bitcoin.network =:regtest
include Bitcoin::Builder
require_relative 'bitcoinrpc.rb'

#Global variable used overall file
$bitcoinRpc = BitcoinRPC.new('http://rajesh:jab_raj_meets_satoshi@127.0.0.1:18332')
$BTC = 100000000 #satoshi
$FEE = 1000 #mention in assignment

#to display help to user
def helpFunction
	puts "==========================HELP Section==================================================="
	puts "1. listutxo - will list all the UTXO in the longest chain of blocks.\ncmd:\'ruby wallet.rb listutxo\'"
	puts "2. generatekey - will generate new address & keys.\ncmd:\'ruby wallet.rb generatekey\'"
	puts "3. listkey - will list all the addresses with their keys on console.\ncmd:\'ruby wallet.rb listkey\'"
	puts "4. sendtoaddress - will send the amount(in BTC) to address.\ncmd:\'ruby wallet.rb sendtoaddress _UnspentTXID_ _vout_ _Amount_ _ToAddress_\'"
	puts "5. sendtomultisig - will send the amount(in BTC) to multisig-address.\ncmd:\'ruby wallet.rb sendtomultisig _UnspentTXID_ _vout_ _Amount_ _Address1_..._AddressN_\'"
	puts "6. redemtoaddress - will send the amount(in BTC) to address from multisig-address.\ncmd:\'ruby wallet.rb redemtoaddress _UnspentMultiSigTXID_ _vout_ _Amount_ _ToAddress_\'"
	puts "=========================================================================================="
end	

#to display UTXO which we get from longest block hash
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

#to generate new key-pair add into our wallet (csv)
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

#to display all key-pair present in our wallet (csv)
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

#to send BTC to particular address
def sendtoaddress(previousTxId,voutOfPtx,toAddresss,amount)
	#considering all inputs are valid
	#now check is their enough amount in that UTXO
	previousTxValue=$bitcoinRpc.gettxout(previousTxId,voutOfPtx)
	if previousTxValue == nil
		p "UTXO is spent already, try again with other UTXO"
	else
		previousTxData=$bitcoinRpc.gettransaction(previousTxId)
		previousTxData=previousTxData["hex"].to_s
		previousTx=Bitcoin::P::Tx.new(previousTxData.htb)
		#p previousTx
		amountToBeTransfer=($BTC * amount) + $FEE
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
			amountToBeTransfer-=$FEE
			remainingBalance=previousTxBalance-amountToBeTransfer-$FEE
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
				if (remainingBalance - $FEE) > 0
					t.output do |o|
						o.value remainingBalance
						o.script {|s| s.recipient previousTxValue["scriptPubKey"]["addresses"][0]}
					end
				end
			end	
			
			puts tx_to_transfer_account.to_json
			
			tx_to_account=Bitcoin::Protocol::Tx.new(tx_to_transfer_account.to_payload)
			p tx_to_account.verify_input_signature(0,previousTx)==true
			hex_transaction=tx_to_account.to_payload.unpack("H*")[0]
			p hex_transaction
			transactionId=$bitcoinRpc.sendrawtransaction(hex_transaction)
			#p transactionId
			puts "Transaction Id:#{transactionId}"
			puts "Please execute the command to use the transaction\n\'bitcoin-cli -regtest generate 1\'"
		end
	end	
end

#to send BTC to multisig address (in old way)
def sendtomultisig(previousTxId,voutOfPtx,amount,*mulSigAddresss)
	#considering all inputs are valid
	#now check is their enough amount in that UTXO
	p mulSigAddresss
	previousTxValue=$bitcoinRpc.gettxout(previousTxId,voutOfPtx)
	if previousTxValue == nil
		p "UTXO is spent already, try again with other UTXO"
	else	
		previousTxData=$bitcoinRpc.gettransaction(previousTxId)
		previousTxData=previousTxData["hex"].to_s
		previousTx=Bitcoin::P::Tx.new(previousTxData.htb)
		#p previousTx
		amountToBeTransfer=($BTC * amount) 
		previousTxBalance=($BTC * previousTxValue["value"])
		#p amountToBeTransfer
		#p previousTxBalance
		if previousTxBalance < (amountToBeTransfer + $FEE) #insufficient fund
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
			script_pubkey = Bitcoin::Script.to_multisig_script(2, *listOfPublicKeys)
			#p ({ script_pubkey: script_pubkey })
			#p ({ dump_script_pubkey: Bitcoin::Script.new(script_pubkey).to_string })

			keyOfPreviousAddress=Bitcoin::Key.from_base58($bitcoinRpc.dumpprivkey(previousTxValue["scriptPubKey"]["addresses"][0]))
			#amountToBeTransfer-=$FEE
			remainingBalance=previousTxBalance-amountToBeTransfer-$FEE

			tx = Bitcoin::Protocol::Tx.new

			tx_in = Bitcoin::Protocol::TxIn.from_hex_hash(previousTxId, voutOfPtx)
			tx.add_in(tx_in)

			
			tx_out = Bitcoin::Protocol::TxOut.new(amountToBeTransfer, script_pubkey)
			tx.add_out(tx_out)
			if (remainingBalance - $FEE) > 0
				tx_out_remaining = Bitcoin::Protocol::TxOut.value_to_address(remainingBalance, previousTxValue["scriptPubKey"]["addresses"][0])
				tx.add_out(tx_out_remaining)
			end	
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
			puts "Transaction Id:#{transactionId}"
			puts "Please execute the command to use the transaction\n\'bitcoin-cli -regtest generate 1\'"
			
		end
	end	
end

#to send BTC from multisig to other address
def redemtoaddress(previousTxId,voutOfPtx,amount,toAddresss)
	previousTxValue=$bitcoinRpc.gettxout(previousTxId,voutOfPtx)
	if previousTxValue == nil
		p "UTXO is spent already, try again with other UTXO"
	else	
		previousTxData=$bitcoinRpc.gettransaction(previousTxId)
		previousTxData=previousTxData["hex"].to_s
		previousTx=Bitcoin::P::Tx.new(previousTxData.htb)
		#script_pubkey=previousTxValue["scriptPubKey"]["asm"]
		previousTxType=previousTxValue["scriptPubKey"]["type"]
		listOfAllAddress=previousTxValue["scriptPubKey"]["addresses"]
		
		listOfPrivateKeys={}
		listOfPublicKeys=[]
		counter=0
		listOfAllAddress.each do |addr|
			counter+=1
			listOfPrivateKeys["#{counter}"]=Bitcoin::Key.from_base58($bitcoinRpc.dumpprivkey(addr))
			listOfPublicKeys.push((listOfPrivateKeys["#{counter}"].pub))
		end
		script_pubkey = Bitcoin::Script.to_multisig_script(2, *listOfPublicKeys)
		amountToBeTransfer=($BTC * amount) 
		previousTxBalance=($BTC * previousTxValue["value"])
		if previousTxBalance < (amountToBeTransfer + $FEE) #insufficient fund
			puts "In-sufficient fund in UTXO"
		elsif previousTxType!="multisig" #previous transaction is not multisig
			p "Previous transaction must be multi-sig transaction to redem, please try again with to multisig address"
		else #yes we can transfer
			#amountToBeTransfer-=$FEE
			remainingBalance=previousTxBalance-amountToBeTransfer-$FEE
			tx=Bitcoin::Protocol::Tx.new

			tx_in=Bitcoin::Protocol::TxIn.from_hex_hash(previousTxId,voutOfPtx)
			tx.add_in(tx_in)

			tx_out=Bitcoin::Protocol::TxOut.value_to_address(amountToBeTransfer,toAddresss)
			tx.add_out(tx_out)
			if (remainingBalance - $FEE) > 0
				tx_out_remaining=Bitcoin::Protocol::TxOut.new(remainingBalance,script_pubkey)
				tx.add_out(tx_out_remaining)
			end
			sig_hash = tx.signature_hash_for_input(0, previousTx, Bitcoin::Script::SIGHASH_TYPE[:all])
			#p sig_hash
			script_sig = Bitcoin::Script.to_multisig_script_sig(listOfPrivateKeys["1"].sign(sig_hash),listOfPrivateKeys["2"].sign(sig_hash))
			tx.in[0].script_sig = script_sig
			#p tx.to_json
			verify_tx = Bitcoin::Protocol::Tx.new(tx.to_payload)
			p verify: verify_tx.verify_input_signature(0, previousTx)

			hex_transaction=verify_tx.to_payload.unpack("H*")[0]
			p hex_transaction
			transactionId=$bitcoinRpc.sendrawtransaction(hex_transaction)
			#p transactionId
			puts "Transaction Id:#{transactionId}"
			puts "Please execute the command to use the transaction\n\'bitcoin-cli -regtest generate 1\'"

		end
	end		
end	

#validations methods
def validateInput(txid, vout, amnt, *addr)	

	if !is_number? amnt
		return ({"Runtime-Error" => "Invalid amount #{amnt}"})
	end
	if !is_integer? vout	
		return ({"Runtime-Error" => "Invalid vout index #{vout}"})
	end
	addr.each do |elementOfAddress|
		if !Bitcoin.valid_address? elementOfAddress	
			return ({"Runtime-Error" => "Invalid bitcoin address #{elementOfAddress}"})
		end
	end	
	return {}
end

#validations methods
def is_integer? string
	true if (Integer(string) && string.to_i >=0) rescue false
end

#validations methods
def is_number? string
	true if Float(string) rescue false
end

#entry point 
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
					#p txId
					#p vout
					#p amount
					#p address
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
				checkValidation=validateInput(ARGV[1],ARGV[2].to_i,ARGV[3].to_f,ARGV[4])
				if checkValidation=={}
					sendtoaddress(ARGV[1],ARGV[2].to_i,ARGV[4],ARGV[3].to_f)
				else
					p checkValidation
				end	
			end	
		when "sendtomultisig"
			
			if ARGV.length<4
				puts "Invalid argument-list with \'sendtomultisig\' command please try running\n\'ruby wallet.rb sendtomultisig _UnspentTXID_ _vout_ _Amount_ _Address1_..._AddressN \'"
			else 
				listofaddresses=[]
				for i in 4..(ARGV.length-1) do
					listofaddresses << ARGV[i]
				end
				checkValidation=validateInput(ARGV[1],ARGV[2].to_i,ARGV[3].to_f,*listofaddresses)
				p checkValidation
				if checkValidation=={}
					sendtomultisig(ARGV[1],ARGV[2].to_i,ARGV[3].to_f,*listofaddresses)
				else
					p checkValidation
				end	
					
			end	
		when "redemtoaddress"
			if ARGV.length<4
				puts "Invalid argument-list with \'redeemtoaddress\' command please try running\n\'ruby wallet.rb redeemtoaddress _UnspentMultisigTXID_ _vout_ _Amount_ _Address_ \'"
			else
				checkValidation=validateInput(ARGV[1],ARGV[2].to_i,ARGV[3].to_f,ARGV[4])
				if checkValidation=={}
					redemtoaddress(ARGV[1],ARGV[2].to_i,ARGV[3].to_f,ARGV[4])	
				else
					p checkValidation
				end	
			end	
		else puts"Sorry !!! You mis-spelled command, if you need any help try running\n\'ruby wallet.rb help\'"
	end #case end
else 
	puts"Sorry !!! You forgot to send command, if you need any help try running\n\'ruby wallet.rb help\'"
end #if end