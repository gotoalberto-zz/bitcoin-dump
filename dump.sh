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

CMD="curl --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"bitcoin\", \"method\": \"getinfo\", \"params\": [] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT |  sed -E 's|([a-z0-9]{64})|"\1"|g' | $JSAWKPATH 'return this.result.blocks'"
BLOCKS=$(eval $CMD)

#protection over too many request from same ip
while [ BLOCKS == "" ]
do
	echo "Blockchain.info has blocked this IP. Waiting 70 seconds..."
	sleep 70
	BLOCKS=$(eval $CMD)
done

CURRENTBLOCK=$(eval $CMD)
echo "ACTUALLY THERE ARE $BLOCKS BLOCKS ON MINNER MACHINE"

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
	CMD="curl --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"bitcoin\", \"method\": \"getblockhash\", \"params\": [$CURRENTBLOCK] }'  -H 'content-type: text/plain;' https://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH 'return this.result'"
	CURRENTHASH=$(eval $CMD)

	#Save all transactions to txtemp.txt
	CMD="rm $TEMPDIR/txidtemp.csv"
	eval $CMD
	CMD="curl http://blockexplorer.com/rawblock/$CURRENTHASH | $JSAWKPATH 'forEach(this.tx, \"out(item.hash)\").join(\"\\n\")' > $TEMPDIR/txidtemp.csv"
	eval $CMD

	CMD="cat $TEMPDIR/txidtemp.csv | wc -l | tr -d ' '"
	TXID_COUNT=$(eval $CMD)
	TXID_LINE="1" 

	#Iterate over all transaction ids of this block
	while [ "$TXID_LINE" -le "$TXID_COUNT" ]
	do
		CMD="rm $TEMPDIR/txin.csv $TEMPDIR/txout.csv rm $TEMPDIR/txtemp.csv rm $TEMPDIR/txfinal.csv"
		eval $CMD

		#get one ttransaction id from txidtemp.csv file, which contains all ids of transactions in this block
		CMD="sed '$TXID_LINE q;d' $TEMPDIR/txidtemp.csv"
		TXHASH=$(eval $CMD)

		#save page as html	
		CMD="curl http://blockexplorer.com/tx/$TXHASH > $TEMPDIR/blockexplorer.html"
		eval $CMD

		Obtain number of inputs
		CMD="cat $TEMPDIR/blockexplorer.html | grep \"Number of input\" |sed 's/^.\{230\}//' |sed 's/.\{44\}$//'"
		NUMBER_INPUTS=$(eval $CMD)

		CMD="cat $TEMPDIR/blockexplorer.html | grep \"Number of outputs\" |sed 's/^.\{23\}//' |sed 's/.\{46\}$//'"
		NUMBER_OUTPUTS=$(eval $CMD)

		CMD="cat $TEMPDIR/blockexplorer.html | grep \"Appeared in\" | sed -e ';s/.*(//g' | sed -e ';s/).*//g'"
		TX_TIMESTAMP=$(eval $CMD)

		#Otain all address -> ;line;address
		CMD="cat $TEMPDIR/blockexplorer.html | grep -rne /address/ | grep -rne /address/ | sed '$ d' |sed 's/^.\{35\}//' |sed 's/.\{44\}$//' | sed 's/:/;/g' | sed s/\"\\/\"//g |sed s/\"<td><a href=\"//g | sed s/\"\\\"address\"//g | cut -d \";\" -f2 -f3 | sed s/\\\"//> $TEMPDIR/addresses.csv"
		eval $CMD
		ADDR_LINE="1"
		#read txin
		while [ "$ADDR_LINE" -le "$NUMBER_INPUTS" ] 
		do
			#get amount
			CMD="cat $TEMPDIR/addresses.csv | sed '$ADDR_LINE q;d' | tr ';' '\n' | sed '1 q;d'"
			AMOUNT_HTML_LINE=$(eval $CMD)
			((AMOUNT_HTML_LINE--))
			CMD="cat $TEMPDIR/blockexplorer.html | sed '$AMOUNT_HTML_LINE q;d' |tr -d '</td>'"
			AMOUNT=$(eval $CMD)
			CMD="cat $TEMPDIR/addresses.csv | sed '$ADDR_LINE q;d' | tr ';' '\n' | sed '2 q;d'"
			ADDR=$(eval $CMD)

			CMD="echo \"$ADDR;$CURRENTHASH;$TXHASH;$TX_TIMESTAMP;$AMOUNT\" >> $TEMPDIR/txin.csv"
			eval $CMD
			((ADDR_LINE++))
		done

		#set add_line to number of inputs value
		ADDR_LINE="$NUMBER_INPUTS"
		((ADDR_LINE++))

		CMD="cat $TEMPDIR/addresses.csv| wc -l | tr -d ' '"
		ADDR_IN_FILE=$(eval $CMD)
		
		#read txout
		while [ "$ADDR_LINE" -le "$ADDR_IN_FILE" ] 
		do
			#get amount
			CMD="cat $TEMPDIR/addresses.csv | sed '$ADDR_LINE q;d' | tr ';' '\n' | sed '1 q;d'"
			AMOUNT_HTML_LINE=$(eval $CMD)
			((AMOUNT_HTML_LINE--))
			CMD="cat $TEMPDIR/blockexplorer.html | sed '$AMOUNT_HTML_LINE q;d' |tr -d '</td>'"
			AMOUNT=$(eval $CMD)
			CMD="cat $TEMPDIR/addresses.csv | sed '$ADDR_LINE q;d' | tr ';' '\n' | sed '2 q;d'"
			ADDR=$(eval $CMD)
			CMD="echo \"$ADDR;$CURRENTHASH;$TXHASH;$TX_TIMESTAMP;$AMOUNT\" >> $TEMPDIR/txout.csv"
			eval $CMD
			((ADDR_LINE++))
		done

		TX_IN_LINE="1"
		CMD="cat $TEMPDIR/txin.csv | wc -l | tr -d ' '"
		TX_IN_COUNT=$(eval $CMD)
		
		#if transaction is new money
		TX_OUT_FILE="$TEMPDIR/txout.csv"
		if [ ! -f $TX_OUT_FILE ]
		then
			CMD="sed '1 q;d' $TEMPDIR/txin.csv"
			TX_IN=$(eval $CMD)

			#get data from in sub-transaction
			CMD="echo \"$TX_IN\" | tr ';' '\n' | sed '5 q;d'"
			AMOUNT_IN=$(eval $CMD)
			CMD="echo \"$TX_IN\" | tr ';' '\n' | sed '1 q;d'"
			ADDRESS_IN=$(eval $CMD)
			CMD="echo \"$TX_IN\" | tr ';' '\n' | sed '4 q;d'"
			DATE_TX=$(eval $CMD)

			CMD="echo \";$ADDRESS_IN;;$AMOUNT_IN;$DATE_TX;$CURRENTHASH;$TXHASH;$CURRENTBLOCK\" >> $OUTPUTDIR/wip_dump_$1_$CURRENTBLOCK.csv"
			eval $CMD
		else
			#Iterate over out sub-transactions
			while [ "$TX_IN_LINE" -le "$TX_IN_COUNT" ]
			do
				CMD="sed '$TX_IN_LINE q;d' $TEMPDIR/txin.csv"
				TX_IN=$(eval $CMD)

				TX_OUT_LINE="1"
				CMD="cat $TEMPDIR/txout.csv | wc -l | tr -d ' '"
				TX_OUT_COUNT=$(eval $CMD)

				#iterate over in sub-transactions
				while [ "$TX_OUT_LINE" -le "$TX_OUT_COUNT" ]
				do
					CMD="sed '$TX_OUT_LINE q;d' $TEMPDIR/txout.csv"
					TX_OUT=$(eval $CMD)

					#get data from in sub-transaction
					CMD="echo \"$TX_IN\" | tr ';' '\n' | sed '5 q;d'"
					AMOUNT_IN=$(eval $CMD)
					CMD="echo \"$TX_IN\" | tr ';' '\n' | sed '1 q;d'"
					ADDRESS_IN=$(eval $CMD)
					
					#get data from out sub-transaction
					CMD="echo \"$TX_OUT\" | tr ';' '\n' | sed '5 q;d'"
					AMOUNT_OUT=$(eval $CMD)
					CMD="echo \"$TX_OUT\" | tr ';' '\n' | sed '1 q;d'"
					ADDRESS_OUT=$(eval $CMD)

					CMD="echo \"$TX_OUT\" | tr ';' '\n' | sed '4 q;d'"
					DATE_TX=$(eval $CMD)
					
					CMD="echo \"$ADDRESS_IN;$ADDRESS_OUT;$AMOUNT_IN;$AMOUNT_OUT;$DATE_TX;$CURRENTHASH;$TXHASH;$CURRENTBLOCK\" >> $OUTPUTDIR/wip_dump_$1_$CURRENTBLOCK.csv"
					eval $CMD
					
					((TX_OUT_LINE++))
				done
				((TX_IN_LINE++))
			done
		fi

		((TXID_LINE++))
	done

	#When all transactions are dumped, rename file to final name
	CMD="mv $OUTPUTDIR/wip_dump_$1_$CURRENTBLOCK.csv $OUTPUTDIR/$CURRENTBLOCK.tx.csv"
	eval $CMD

	((CURRENTBLOCK--))
done