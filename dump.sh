#!/bin/bash

#############################################################################
########################## CONFIG
#############################################################################
JSAWKPATH="/users/gotoalberto/jsawk/jsawk"
RPCMINNERIP="127.0.0.1"
RPCMINNERPORT="8332"
RPCMINNERUSER="bitcoin"
RPCMINNERPASSWORD="password"

#############################################################################
########################## Obtain downloaded blocks number
#############################################################################
CMD="curl --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"getinfo\", \"params\": [] }'  -H 'content-type: text/plain;' http://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH 'return this.result.blocks'"
BLOCKS=$()
rm blocksnumber.txt
echo "$BLOCKS" > blocksnumber.txt

BLOCKS=($(<blocksnumber.txt))

#Set current processed block

if [ -f 'currentblock.txt' ];
then
   echo "The execution continues on BLOCK $(<currentblock.txt)"
else
   echo "Starting dump on BLOCK 1"
   echo 1 >> currentblock.txt
fi
CURRENTBLOCK=($(<currentblock.txt))

#############################################################################
########################## Extract data
#############################################################################

while [ $CURRENTBLOCK -le $BLOCKS ]
do
	echo "PROCESSING BLOCK $CURRENTBLOCK FROM $BLOCKS"
	CMD="curl --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"bitcoin\", \"method\": \"getblockhash\", \"params\": [$CURRENTBLOCK] }'  -H 'content-type: text/plain;' http://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH 'return this.result'"
    CURRENTHASH=$(eval $CMD)

	CMD="curl --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"bitcoin\", \"method\": \"getblock\", \"params\": [\"$CURRENTHASH\"] }'  -H 'content-type: text/plain;' http://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH 'return this.join(\"\\n\")' 'return this.result.tx.join(\"\\n\")' "
	TX=$(eval $CMD)
	rm txtemp.txt
	echo "$TX" > txtemp.txt

	for txid in $(cat txtemp.txt)
	do
		#obtain transaction ip 
		CMD="curl http://blockchain.info/es/tx/$txid)"
		BCPAGE=$(eval $CMD)
		rm blockchainpage.txt
		echo "$BCPAGE" > blockchainpage.txt

		CMD="cat blockchainpage.txt | grep \"ip-address/\" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | uniq"
		IP=$(eval $CMD)
		echo "$IP"

		#obtain country from ip
		CMD="curl ipinfo.io/$IP | /users/gotoalberto/jsawk/jsawk 'return this.country'"
		COUNTRY=$(eval $CMD)

		#obtain tx data
		CMD="curl --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"bitcoin\", \"method\": \"getrawtransaction\", \"params\": [\"$txid\"] }'  -H 'content-type: text/plain;' http://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH 'return this.result'"
		RAWTX=$(eval $CMD)

		if [ "$RAWTX" == "" ]
		then
			echo "$RAWTX" >> txfails.txt
		else
			CMD="curl --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"bitcoin\", \"method\": \"decoderawtransaction\", \"params\": [\"$RAWTX\"] }'  -H 'content-type: text/plain;' http://$RPCMINNERUSER:$RPCMINNERPASSWORD@$RPCMINNERIP:$RPCMINNERPORT | $JSAWKPATH 'return this.result'"
			DECODEDTX=$(eval $CMD)
			echo "$DECODEDTX" >> transactions.tx
		fi		
	done
done