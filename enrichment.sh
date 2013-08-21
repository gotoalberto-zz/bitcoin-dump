#!/bin/bash

#############################################################################
########################## CONFIG
#############################################################################

JSAWKPATH="/Users/gotoalberto/jsawk/jsawk"
DATAPATH="/Users/gotoalberto/git/bitcoin-dump/data"

#############################################################################
########################## ADD IP AND GEO INFO
#############################################################################

	DATA_PATH_FILES="$DATAPATH/*.tx.json"
	#Add IP and GEO info
	for filename in $DATA_PATH_FILES
	do
		PROCESSED_FILES=($(<$DATAPATH/processed.txt))

		CMD="echo \"$PROCESSED_FILES\" |grep -c \"$filename\""
		PROCESSED_NUMBER=$(eval $CMD)

		if [ "$PROCESSED_NUMBER" == "0" ] 
		then
			CMD="echo $filename >> $DATAPATH/processed.txt"
			eval $CMD

			CMD="cat $filename | wc -l | tr -d ' '"
			COUNT=$(eval $CMD)

			LINE="1"
			rm richtemp.json
			while [ "$LINE" -le "$COUNT" ]
			do
				#Get transaction hash
				CMD="sed '$LINE q;d' $filename | $JSAWKPATH 'return this.hash'"
				TXID=$(eval $CMD)

				#get transaction ip 
				CMD="curl http://blockchain.info/es/tx/$TXID"
				BCPAGE=$(eval $CMD)
				rm blockchainpage.html
				echo "$BCPAGE" > blockchainpage.html
				CMD="cat blockchainpage.html | grep \"ip-address/\" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | uniq"
				IP=$(eval $CMD)

				#if ip is not null, get country
				COUNTRY=""
				if [ "$IP" != "" ]
				then
					CMD="curl ipinfo.io/$IP | $JSAWKPATH 'return this.country'"
					COUNTRY=$(eval $CMD)
				fi

				#Add country and ip as json nodes
				CMD="sed '$LINE q;d' $filename | sed 's/\"ver\"/\"geo\":\"$COUNTRY\",\"ip\":\"$IP\",\"ver\"/g'"
				RICHTX=$(eval $CMD)

				#Save rich transaction on temp file
				echo $RICHTX >> richtemp.json

				#rename original file to *_processed and create new rich_* file
				CMD="mv richtemp.json \"${filename%.tx*}.rich.json\""
				eval $CMD

				((LINE++))
			done
		fi
	done