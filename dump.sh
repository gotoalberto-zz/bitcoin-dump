#!/bin/bash

mkdir data
#############################################################################
########################## CONFIG
#############################################################################
JSAWKPATH="/Users/gotoalberto/jsawk/jsawk"
RPCMINNERIP="rpc.blockchain.info"
RPCMINNERPORT="443"
RPCMINNERUSER="c49c5c4d-1b4c-488d-8a7b-065d0a96310a"
RPCMINNERPASSWORD="bitcointest"

#############################################################################
########################## Obtain blocks number on blockchain
#############################################################################
CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"getinfo\", \"params\": [] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT |  sed -E 's|([a-z0-9]{64})|"\1"|g' | $JSAWKPATH 'return this.result.blocks'"
echo "$CMD"
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

while [ $CURRENTBLOCK -gt $1 ]
do
	#Obtain hash of current block to process
	echo "PROCESSING BLOCK $CURRENTBLOCK FROM $BLOCKS"
	CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"getblockhash\", \"params\": [$CURRENTBLOCK] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH 'return this.result'"
	CURRENTHASH=$(eval $CMD)

	#Save all transactions to txtemp.txt
	rm txidtemp.json
	CMD="curl http://blockexplorer.com/rawblock/$CURRENTHASH | $JSAWKPATH 'forEach(this.tx, \"out(item.hash)\").join(\"\\n\")'"
	TXS=$(eval $CMD)
	echo "$TXS" > txidtemp.json

	CMD="cat txidtemp.json | wc -l | tr -d ' '"
	TXID_COUNT=$(eval $CMD)
	TXID_LINE="1"
	while [ "$TXID_LINE" -le "$TXID_COUNT" ]
	do
		rm txfinal.json
		rm txtemp.json
		rm txfromtemp.json
		CMD="sed '$TXID_LINE q;d' txidtemp.json"
		TXHASH=$(eval $CMD)
		CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"gettransaction\", \"params\": [\"$TXHASH\"] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH  'forEach(this.result.details, \"out(item.address + \\\";\\\" + item.blockhash + \\\";\\\" + item.txid + \\\";\\\" + item.time + \\\";\\\" + item.amount + \\\";\\\" + item.label)\").join(\"\\n\")' > txtemp.json"		
		eval $CMD
		CMD="cat txtemp.json"
		TXTEMPJSON=$(eval $CMD)
		while [ "$TXTEMPJSON" == "" ]
		do
			((TXID_LINE++))
			TXHASH=$(eval $CMD)
			CMD="sed '$TXID_LINE q;d' txidtemp.json"
			TXHASH=$(eval $CMD)
			CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"gettransaction\", \"params\": [\"$TXHASH\"] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH  'forEach(this.result.details, \"out(item.address + \\\";\\\" + item.blockhash + \\\";\\\" + item.txid + \\\";\\\" + item.time + \\\";\\\" + item.amount + \\\";\\\" + item.label)\").join(\"\\n\")' > txtemp.json"
			eval $CMD
			CMD="cat txtemp.json"
			TXTEMPJSON=$(eval $CMD)
		done

		CMD="cat txtemp.json | sed '/\-/d' > subtxtemp.json"
		eval $CMD
		CMD="cat txtemp.json | grep -p '-' | cut -f1 -d\";\" > subtxfromtemp.json"
		eval $CMD

		TX_LINE="1"
		CMD="cat subtxtemp.json | wc -l | tr -d ' '"
		TX_COUNT=$(eval $CMD)

		while [ "$TX_LINE" -le "$TX_COUNT" ]
		do

			CMD="sed '$TX_LINE q;d' subtxtemp.json"
			TX=$(eval $CMD)

			TX_FROM_LINE="1"
			CMD="cat subtxfromtemp.json | wc -l | tr -d ' '"
			TX_FROM_COUNT=$(eval $CMD)
			while [ "$TX_FROM_LINE" -le "$TX_COUNT" ]
			do
				CMD="sed '$TX__FROM_LINE q;d' subtxfromtemp.json"
				TX_FROM=$(eval $CMD)
				NEW="$TX_FROM;$TX"
				if [ "$NEW" != "$LAST" ]
				then
					echo "$TX_FROM;$TX" >> txfinal.json
				fi
				LAST="$TX_FROM;$TX"
				((TX_FROM_LINE++))
			done
			((TX_LINE++))
		done

		cat txfinal.json >> data/transactions.json

		((TXID_LINE++))
	done

	#Split file if have more than x lines
	CMD="cat dump.sh | wc -l | tr -d ' '"
	LINESCOUNT=$(eval $CMD)

	if [ "$LINESCOUNT" > "100" ]
	then
		TIMESTAMP=$(date +%y%m%d%H%M%S)
		CMD="mv data/transactions.json data/transactions$TIMESTAMP.tx.json"
		eval $CMD
	fi

	((CURRENTBLOCK--))
	echo "$CURRENTBLOCK" > currentblock.txt
done