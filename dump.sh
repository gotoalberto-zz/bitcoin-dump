#!/bin/bash

#############################################################################
########################## CONFIG
#############################################################################
JSAWKPATH="/Users/gotoalberto/jsawk/jsawk"
RPCMINNERIP="rpc.blockchain.info"
RPCMINNERPORT="443"
RPCMINNERUSER="c49c5c4d-1b4c-488d-8a7b-065d0a96310a"
RPCMINNERPASSWORD="bitcointest"
OUTPUTDIR="/Users/gotoalberto/git/bitcoin-dump/data"

#############################################################################
########################## Obtain blocks number on blockchain
#############################################################################
echo ""
echo "######################################"
echo "Started at $(date)"
echo "######################################"
mkdir temp
CMD="mkdir $OUTPUTDIR"
eval $CMD
PID=$$
CMD="echo $PID > dump.pid"
eval $CMD

CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"getinfo\", \"params\": [] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT |  sed -E 's|([a-z0-9]{64})|"\1"|g' | $JSAWKPATH 'return this.result.blocks'"
BLOCKS=$(eval $CMD)
echo "ACTUALLY THERE ARE $BLOCKS BLOCKS ON BLOCKCHAIN.INFO"
((BLOCKS--))

#Set current processed block
if [ -f 'temp/currentblock.txt' ];
then
   echo "THE EXECUTION CONTINUES ON BLOCK $(<temp/currentblock.txt)"
else
   echo "Starting dump on BLOCK 1"
   echo "$BLOCKS" > temp/currentblock.txt
fi
CURRENTBLOCK=($(<temp/currentblock.txt))

CMD="rm $OUTPUTDIR/transactions.$CURRENTBLOCK.csv"
eval $CMD

#############################################################################
########################## Extract data
#############################################################################
echo ""

while [ $CURRENTBLOCK -gt $1 ]
do
	#Obtain hash of current block to process
	echo ""
	echo "PROCESSING BLOCK $CURRENTBLOCK FROM $BLOCKS ..."
	CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"getblockhash\", \"params\": [$CURRENTBLOCK] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH 'return this.result'"
	CURRENTHASH=$(eval $CMD)

	#Save all transactions to txtemp.txt
	rm txidtemp.json
	CMD="curl http://blockexplorer.com/rawblock/$CURRENTHASH | $JSAWKPATH 'forEach(this.tx, \"out(item.hash)\").join(\"\\n\")' > temp/txidtemp.json"
	eval $CMD

	CMD="cat temp/txidtemp.json | wc -l | tr -d ' '"
	TXID_COUNT=$(eval $CMD)
	TXID_LINE="1"
	while [ "$TXID_LINE" -le "$TXID_COUNT" ]
	do
		rm temp/txfinal.json
		rm temp/txtemp.json
		rm temp/txfromtemp.json
		CMD="sed '$TXID_LINE q;d' temp/txidtemp.json"
		TXHASH=$(eval $CMD)
		CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"gettransaction\", \"params\": [\"$TXHASH\"] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH  'forEach(this.result.details, \"out(item.address + \\\";\\\" + item.blockhash + \\\";\\\" + item.txid + \\\";\\\" + item.time + \\\";\\\" + item.amount + \\\";\\\" + item.label)\").join(\"\\n\")' > temp/txtemp.json"		
		eval $CMD
		CMD="cat temp/txtemp.json"
		TXTEMPJSON=$(eval $CMD)
		while [ "$TXTEMPJSON" == "" ]
		do
			((TXID_LINE++))
			TXHASH=$(eval $CMD)
			CMD="sed '$TXID_LINE q;d' temp/txidtemp.json"
			TXHASH=$(eval $CMD)
			CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"gettransaction\", \"params\": [\"$TXHASH\"] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH  'forEach(this.result.details, \"out(item.address + \\\";\\\" + item.blockhash + \\\";\\\" + item.txid + \\\";\\\" + item.time + \\\";\\\" + item.amount + \\\";\\\" + item.label)\").join(\"\\n\")' > temp/txtemp.json"
			eval $CMD
			CMD="cat temp/txtemp.json"
			TXTEMPJSON=$(eval $CMD)
		done

		CMD="cat temp/txtemp.json | sed '/\-/d' > temp/subtxtemp.json"
		eval $CMD
		CMD="cat temp/txtemp.json | grep -p '-' | cut -f1 -d\";\" > temp/subtxfromtemp.json"
		eval $CMD

		TX_LINE="1"
		CMD="cat temp/subtxtemp.json | wc -l | tr -d ' '"
		TX_COUNT=$(eval $CMD)

		while [ "$TX_LINE" -le "$TX_COUNT" ]
		do

			CMD="sed '$TX_LINE q;d' temp/subtxtemp.json"
			TX=$(eval $CMD)

			TX_FROM_LINE="1"
			CMD="cat temp/subtxfromtemp.json | wc -l | tr -d ' '"
			TX_FROM_COUNT=$(eval $CMD)
			while [ "$TX_FROM_LINE" -le "$TX_COUNT" ]
			do
				CMD="sed '$TX__FROM_LINE q;d' temp/subtxfromtemp.json"
				TX_FROM=$(eval $CMD)
				NEW="$TX_FROM;$TX"
				if [ "$NEW" != "$LAST" ]
				then
					echo "$TX_FROM;$TX" >> temp/txfinal.json
				fi
				LAST="$TX_FROM;$TX"
				((TX_FROM_LINE++))
			done
			((TX_LINE++))
		done

		CMD="cat temp/txfinal.json >> $OUTPUTDIR/transactions.$CURRENTBLOCK.csv"
		eval $CMD

		CMD="find /Users/gotoalberto/git/bitcoin-dump/data -name '*.csv' | xargs wc -l |grep total | sed s/total//g | sed s/\ //g"
		TOTAL_RECORDS=$(eval $CMD)
		echo -ne "\x0d$TOTAL_RECORDS TOTAL RECORDS SAVED AT NOW."

		((TXID_LINE++))
	done

	#Split file if have more than x lines
	CMD="cat $OUTPUTDIR/transactions.$CURRENTBLOCK.csv | wc -l | tr -d ' '"
	LINESCOUNT=$(eval $CMD)

	if [ "$LINESCOUNT" > "9000000" ]
	then
		TIMESTAMP=$(date +%y%m%d%H%M%S)
		CMD="mv $OUTPUTDIR/transactions.$CURRENTBLOCK.csv $OUTPUTDIR/transactions.$TIMESTAMP.tx.csv"
		echo ""
		echo "SPLITTING OUTPUT FILE, $LINESCOUNT LINES ON FILE."
		eval $CMD
	fi

	((CURRENTBLOCK--))
	echo "$CURRENTBLOCK" > temp/currentblock.txt
done