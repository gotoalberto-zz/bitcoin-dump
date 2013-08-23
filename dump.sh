#!/bin/bash

#############################################################################
########################## CONFIG
#############################################################################

JSAWKPATH="/Users/gotoalberto/jsawk/jsawk"
OUTPUTDIR="/Users/gotoalberto/git/bitcoin-dump/data"
RPCMINNERUSER="c49c5c4d-1b4c-488d-8a7b-065d0a96310a"
RPCMINNERPASSWORD="bitcointest"

#############################################################################
#############################################################################

#############################################################################
########################## Obtain blocks number on blockchain
#############################################################################

#Init values

TEMPDIR="temp_dump_$1"
LOGDIR="log_dump_$1"
RPCMINNERIP="rpc.blockchain.info"
RPCMINNERPORT="443"

echo ""
echo "######################################"
echo "Started at $(date)"
echo "######################################"


CMD="mkdir $OUTPUTDIR"
eval $CMD
CMD="mkdir $TEMPDIR"
eval $CMD

PID=$$
CMD="echo $PID > pid/dump$1.pid"
eval $CMD

CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"getinfo\", \"params\": [] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT |  sed -E 's|([a-z0-9]{64})|"\1"|g' | $JSAWKPATH 'return this.result.blocks'"
BLOCKS=$(eval $CMD)
CURRENTBLOCK=$(eval $CMD)
echo "ACTUALLY THERE ARE $BLOCKS BLOCKS ON BLOCKCHAIN.INFO"
((BLOCKS--))



#############################################################################
########################## Extract data
#############################################################################

while [ $CURRENTBLOCK -gt "1" ]
do

	CMD="find $OUTPUTDIR -type f -maxdepth 1 | grep $CURRENTBLOCK"
	echo "$CMD"
	EXISTING=$(eval $CMD)

	while [ "$EXISTING" != "" ]
	do
		((CURRENTBLOCK--))
		CMD="find $OUTPUTDIR -type f -maxdepth 1 | grep $CURRENTBLOCK" 
		EXISTING=$(eval $CMD)
	done	
	echo "" > $OUTPUTDIR/workinprogress_$1_$CURRENTBLOCK.csv
	#Obtain hash of current block to process
	echo ""
	echo "PROCESSING BLOCK $CURRENTBLOCK FROM $BLOCKS ..."
	CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"getblockhash\", \"params\": [$CURRENTBLOCK] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH 'return this.result'"
	CURRENTHASH=$(eval $CMD)

	#Save all transactions to txtemp.txt
	CMD="rm $TEMPDIR/txidtemp.csv"
	eval $CMD
	CMD="curl http://blockexplorer.com/rawblock/$CURRENTHASH | $JSAWKPATH 'forEach(this.tx, \"out(item.hash)\").join(\"\\n\")' > $TEMPDIR/txidtemp.csv"
	eval $CMD

	CMD="cat $TEMPDIR/txidtemp.csv | wc -l | tr -d ' '"
	TXID_COUNT=$(eval $CMD)
	TXID_LINE="1"
	while [ "$TXID_LINE" -le "$TXID_COUNT" ]
	do
		CMD="rm $TEMPDIR/txfinal.csv"
		eval $CMD
		CMD="rm $TEMPDIR/txtemp.csv"
		eval $CMD
		CMD="rm $TEMPDIR/txfromtemp.csv"
		eval $CMD

		CMD="sed '$TXID_LINE q;d' $TEMPDIR/txidtemp.csv"
		TXHASH=$(eval $CMD)
		CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"gettransaction\", \"params\": [\"$TXHASH\"] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH  'forEach(this.result.details, \"out(item.address + \\\";\\\" + item.blockhash + \\\";\\\" + item.txid + \\\";\\\" + item.time + \\\";\\\" + item.amount + \\\";\\\" + item.label)\").join(\"\\n\")' > $TEMPDIR/txtemp.csv"		
		eval $CMD
		CMD="cat $TEMPDIR/txtemp.csv"
		TXTEMPCSV=$(eval $CMD)
		while [ "$TXTEMPCSV" == "" ]
		do
			((TXID_LINE++))
			TXHASH=$(eval $CMD)
			CMD="sed '$TXID_LINE q;d' $TEMPDIR/txidtemp.csv"
			TXHASH=$(eval $CMD)
			CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"gettransaction\", \"params\": [\"$TXHASH\"] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH  'forEach(this.result.details, \"out(item.address + \\\";\\\" + item.blockhash + \\\";\\\" + item.txid + \\\";\\\" + item.time + \\\";\\\" + item.amount + \\\";\\\" + item.label)\").join(\"\\n\")' > $TEMPDIR/txtemp.csv"
			eval $CMD
			CMD="cat $TEMPDIR/txtemp.csv"
			TXTEMPCSV=$(eval $CMD)
		done

		CMD="cat $TEMPDIR/txtemp.csv | sed '/\-/d' > $TEMPDIR/subtxtemp.csv"
		eval $CMD
		CMD="cat $TEMPDIR/txtemp.csv | grep -p '-' | cut -f1 -d\";\" > $TEMPDIR/subtxfromtemp.csv"
		eval $CMD

		TX_LINE="1"
		CMD="cat $TEMPDIR/subtxtemp.csv | wc -l | tr -d ' '"
		TX_COUNT=$(eval $CMD)

		while [ "$TX_LINE" -le "$TX_COUNT" ]
		do

			CMD="sed '$TX_LINE q;d' $TEMPDIR/subtxtemp.csv"
			TX=$(eval $CMD)

			TX_FROM_LINE="1"
			CMD="cat $TEMPDIR/subtxfromtemp.csv | wc -l | tr -d ' '"
			TX_FROM_COUNT=$(eval $CMD)
			while [ "$TX_FROM_LINE" -le "$TX_COUNT" ]
			do
				CMD="sed '$TX__FROM_LINE q;d' $TEMPDIR/subtxfromtemp.csv"
				TX_FROM=$(eval $CMD)
				NEW="$TX_FROM;$TX"
				if [ "$NEW" != "$LAST" ]
				then
					CMD="echo \"$TX_FROM;$TX\" >> $OUTPUTDIR/workinprogress_$1_$CURRENTBLOCK.csv"
					eval $CMD
				fi
				LAST="$TX_FROM;$TX"
				((TX_FROM_LINE++))
			done
			((TX_LINE++))
		done

		CMD="find $OUTPUTDIR -name '*.csv' | xargs wc -l |grep total | sed s/total//g | sed s/\ //g"
		TOTAL_RECORDS=$(eval $CMD)
		echo -ne "\x0d$TOTAL_RECORDS TOTAL RECORDS SAVED AT NOW."

		((TXID_LINE++))
	done

	CMD="mv $OUTPUTDIR/workinprogress_$1_$CURRENTBLOCK.csv $OUTPUTDIR/$CURRENTBLOCK.tx.csv"
	eval $CMD

	((CURRENTBLOCK--))
done