# Create simple wallet using Ruby

We shall develop a very simple wallet using Ruby language and `bitcoin-ruby`.

## Commands to be implemented

A usage of this wallet is as follows.

``` bash
ruby wallet.rb <command>[ <arg 1> <arg 2> ... <arg n>]
```

### listutxo

* List the all UTXO in the longest blockchain which is pointed in   `getbestblockhash`
* Show the following information of each UTXO
  * Outpoint (Block hash and TXID and output index)
  * Amount
  * Corresponding Address(or Public key)
  
Note:
You must parse the data yourself using `getblock` or `getrawtransaction`. Do not use `listunspent` as it can not get all UTXO.

### generatekey

* Generate new ESDSA secret key and store it to a `keys.csv` file
* Show corresponding Public key and Address when successfully generated  

Note:
Generate using `Bitcoin::Key.generate` instead of `getnewaddress`

### listkey

* List the all generated keys which is stored in `keys.csv`
* Show the following information of each key
  * Private key
  * Public key 
  * Address

### sendtoaddress

* Send indicated value from your own UTXO to other address 
* Arguments of the command are as follows
  * TXID (of the UTXO)
  * Output Index (of the UTXO)
  * Amount
  * Address
* Changes are sent again to the original address

### sendtomultisig

* Send indicated value from your own UTXO to mulisig  
* Arguments of the command are as follows
  * TXID (of the UTXO)
  * Output Index (of the UTXO)
  * Amount
  * Address 1, 2 .. n
* Changes are sent again to the original address

### redeemtoaddress

* Send indicated value from your own UTXO to mulisig  
* Arguments of the command are as follows
  * TXID (of the UTXO)
  * Output Index (of the UTXO)
  * Amount
  * Address
* Changes are sent again to the original multi sig

## Common specification of commands

### sendtoaddress/sendtomultisig/redeemtoaddress

* Inside the command, a new transaction is created and broadcasted using `sendrawtransaction`
* The secret keys necessary to create the `script_sig` of the transaction is obtained from `keys.csv` file 
* Fee is uniformly 1000 satoshi
* Show TXID of the new transaction when the command succeeds
* A new transaction can be used after generating a new block with the `generate` command with bitcoin-cli