#!/bin/bash

mkdir data
#############################################################################
########################## CONFIG
#############################################################################
JSAWKPATH="/users/gotoalberto/jsawk/jsawk"
RPCMINNERIP="rpc.blockchain.info"
RPCMINNERPORT="443"
RPCMINNERUSER="c49c5c4d-1b4c-488d-8a7b-065d0a96310a"
RPCMINNERPASSWORD="bitcointest"

#############################################################################
########################## Obtain blocks number on blockchain
#############################################################################
CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"getinfo\", \"params\": [] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT |  sed -E 's|([a-z0-9]{64})|"\1"|g' | $JSAWKPATH 'return this.result.blocks'"
BLOCKS=$(eval $CMD)
echo "ACTUALLY THERE ARE $BLOCKS BLOCKS ON BLOCKCHAIN.INFO"
((BLOCKS--))
#Set current processed block

if [ -f 'currentblock.txt' ];
then
   echo "The execution continues on BLOCK $(<currentblock.txt)"
else
   echo "Starting dump on BLOCK 1"
   echo "$BLOCKS" > currentblock.txt
fi
CURRENTBLOCK=($(<currentblock.txt))

#############################################################################
########################## Extract data
#############################################################################
echo "$BLOCKS"

while [ $CURRENTBLOCK -gt 1 ]
do
	#Obtain hash of current block to process
	echo "PROCESSING BLOCK $CURRENTBLOCK FROM $BLOCKS"
	CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"getblockhash\", \"params\": [$CURRENTBLOCK] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH 'return this.result'"
	CURRENTHASH=$(eval $CMD)

	#Save all transactions to txtemp.txt
	CMD="curl http://blockexplorer.com/rawblock/$CURRENTHASH | $JSAWKPATH 'forEach(this.tx, \"out(item)\").join(\"\\n\")'"
	TXS=$(eval $CMD)
	echo "$TXS" >> data/transactions.json

	#Split file if have more than x lines
	CMD="cat dump.sh | wc -l | tr -d ' '"
	LINESCOUNT=$(eval $CMD)

	if [ "$LINESCOUNT" -gt 50000 ]
	then
		TIMESTAMP=$(date +%m%d%y%H%M%S)
		CMD="mv data/transactions.json data/transactions$TIMESTAMP.tx.json"
		eval $CMD
	fi

	((CURRENTBLOCK--))
	echo "$CURRENTBLOCK" > currentblock.txt
done