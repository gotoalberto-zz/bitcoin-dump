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

#protection over too many request from same ip
while [ BLOCKS == "" ]
do
	echo "Blockchain.info has blocked this IP. Waiting 70 seconds..."
	sleep 70
	BLOCKS=$(eval $CMD)
done

CURRENTBLOCK=$(eval $CMD)
echo "ACTUALLY THERE ARE $BLOCKS BLOCKS ON BLOCKCHAIN.INFO"

#############################################################################
########################## Extract data
#############################################################################

while [ $CURRENTBLOCK -gt "1" ]
do

	CMD="find $OUTPUTDIR -type f -maxdepth 1 | grep $CURRENTBLOCK"
	EXISTING=$(eval $CMD)

	#test if other thread 
	while [ "$EXISTING" != "" ]
	do
		((CURRENTBLOCK--))
		CMD="find $OUTPUTDIR -type f -maxdepth 1 | grep $CURRENTBLOCK" 
		EXISTING=$(eval $CMD)
	done	
	echo "" > $OUTPUTDIR/wip_dump_$1_$CURRENTBLOCK.csv
	#Obtain hash of current block to process
	echo ""
	echo "PROCESSING BLOCK $CURRENTBLOCK FROM $BLOCKS ..."
	CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"getblockhash\", \"params\": [$CURRENTBLOCK] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH 'return this.result'"
	CURRENTHASH=$(eval $CMD)

	#protection over too many request from same ip
	while [ "$CURRENTHASH" == "" ]
	do
		echo ""
		echo "Blockchain.info has blocked this IP at $(date). Waiting 70 seconds..."
		sleep 70
		CURRENTHASH=$(eval $CMD)
	done

	#Save all transactions to txtemp.txt
	CMD="rm $TEMPDIR/txidtemp.csv"
	eval $CMD
	CMD="curl http://blockexplorer.com/rawblock/$CURRENTHASH | $JSAWKPATH 'forEach(this.tx, \"out(item.hash)\").join(\"\\n\")' > $TEMPDIR/txidtemp.csv"
	eval $CMD

	CMD="cat $TEMPDIR/txidtemp.csv | wc -l | tr -d ' '"
	TXID_COUNT=$(eval $CMD)
	TXID_LINE="2" #because line 1 is ""

	#Iterate over all transaction ids of this block
	while [ "$TXID_LINE" -le "$TXID_COUNT" ]
	do
		CMD="rm $TEMPDIR/txin.csv $TEMPDIR/txout.csv rm $TEMPDIR/txtemp.csv rm $TEMPDIR/txfinal.csv"
		eval $CMD

		#get one ttransaction id from txidtemp.csv file, which contains all ids of transactions in this block
		CMD="sed '$TXID_LINE q;d' $TEMPDIR/txidtemp.csv"
		TXHASH=$(eval $CMD)

		#Save all sub-transactions of this transaction
		CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"gettransaction\", \"params\": [\"$TXHASH\"] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH  'forEach(this.result.details, \"out(item.address + \\\";\\\" + item.blockhash + \\\";\\\" + item.txid + \\\";\\\" + item.time + \\\";\\\" + item.amount + \\\";\\\" + item.label)\").join(\"\\n\")' > $TEMPDIR/txtemp.csv"		
		eval $CMD

		#protection over too many request from same ip
		CMD="curl blockchain.info"
		RESPONSE=$(eval $CMD)
		while [ "$RESPONSE" == "IP temporarily blocked due to too many requests" ]
		do
			echo ""
			echo "Blockchain.info has blocked this IP at $(date). Waiting 70 seconds..."
			sleep 70
			CMD="curl --data-binary '{\"jsonrpc\": \"2.0\", \"id\":\"bitcoin\", \"method\": \"gettransaction\", \"params\": [\"$TXHASH\"] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH  'forEach(this.result.details, \"out(item.address + \\\";\\\" + item.blockhash + \\\";\\\" + item.txid + \\\";\\\" + item.time + \\\";\\\" + item.amount + \\\";\\\" + item.label)\").join(\"\\n\")' > $TEMPDIR/txtemp.csv"		
			eval $CMD
			CMD="curl blockchain.info"
			RESPONSE=$(eval $CMD)
		done


		#get all sub-transactions of this transaction
		CMD="cat $TEMPDIR/txtemp.csv"
		TXTEMPCSV=$(eval $CMD)

		#Save sub-transactions out addresses, this sub-transactions don't contain "-" character
		CMD="cat $TEMPDIR/txtemp.csv | sed '/\-/d' > $TEMPDIR/txout.csv"
		eval $CMD
		#Save sub-transactions in addresses, this sub-transactions cointain "-" minus sign in amount field
		CMD="cat $TEMPDIR/txtemp.csv | grep -p '-' | sed -e 's/-//g' > $TEMPDIR/txin.csv"
		eval $CMD

		TX_OUT_LINE="1"
		CMD="cat $TEMPDIR/txout.csv | wc -l | tr -d ' '"
		TX_OUT_COUNT=$(eval $CMD)

		#Iterate over out sub-transactions
		while [ "$TX_OUT_LINE" -le "$TX_OUT_COUNT" ]
		do
			CMD="sed '$TX_OUT_LINE q;d' $TEMPDIR/txout.csv"
			TX=$(eval $CMD)

			TX_IN_LINE="1"
			CMD="cat $TEMPDIR/txin.csv | wc -l | tr -d ' '"
			TX_IN_COUNT=$(eval $CMD)

			#iterate over in sub-transactions
			while [ "$TX_IN_LINE" -le "$TX_IN_COUNT" ]
			do
				#get amount from in sub-transaction
				CMD="sed '$TX_IN_LINE q;d' $TEMPDIR/txin.csv | tr ';' '\n' | sed '5 q;d'"
				AMOUNT_IN=$(eval $CMD)

				#get address from in sub-transaction
				CMD="sed '$TX_IN_LINE q;d' $TEMPDIR/txin.csv | tr ';' '\n' | sed '1 q;d'"
				ADDRESS_IN=$(eval $CMD)

				NEW="$TX_IN;$TX"
				if [ "$NEW" != "$LAST" ]
				then
					CMD="echo \"$ADDRESS_IN;$AMOUNT_IN;$TX\" >> $OUTPUTDIR/wip_dump_$1_$CURRENTBLOCK.csv"
					eval $CMD
				fi
				LAST="$TX_IN;$TX"
				((TX_IN_LINE++))
			done
			((TX_OUT_LINE++))
		done

		#Show lines number contained in all OUTPUTDATA files
		CMD="find $OUTPUTDIR -name '*.csv' | xargs wc -l |grep total | sed s/total//g | sed s/\ //g"
		TOTAL_RECORDS=$(eval $CMD)
		echo -ne "\x0d$TOTAL_RECORDS TOTAL RECORDS SAVED AT NOW."

		((TXID_LINE++))
	done

	#When all transactions are dumped, rename file to final name
	CMD="mv $OUTPUTDIR/wip_dump_$1_$CURRENTBLOCK.csv $OUTPUTDIR/$CURRENTBLOCK.tx.csv"
	eval $CMD

	((CURRENTBLOCK--))
done