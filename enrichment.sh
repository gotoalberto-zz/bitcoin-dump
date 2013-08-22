#!/bin/bash

#############################################################################
########################## CONFIG
#############################################################################

JSAWKPATH="/Users/gotoalberto/jsawk/jsawk"
DATAPATH="/Users/gotoalberto/git/bitcoin-dump/data"

#############################################################################
########################## ADD IP AND GEO INFO
#############################################################################
	CMD="mkdir temp"
	eval $CMD

	PID=$$
	CMD="echo $PID > enrichment.pid"
	eval $CMD

	DATA_PATH_FILES="$DATAPATH/*.tx.csv"
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
			rm temp/richtemp.csv
			rm temp/cache.csv
			while [ "$LINE" -le "$COUNT" ]
			do
				#Get transaction hash
				CMD="sed '$LINE q;d' $filename | tr ';' '\n' | sed '4 q;d'"
				TXID=$(eval $CMD)

				CMD="cat temp/cache.csv | grep $TXID | uniq"
				CACHETX=$(eval $CMD)
				if [ "$CACHETX" != "" ] 
				then
					CMD="cat temp/cache.csv | grep $TXID | uniq | tr ';' '\n' | sed '2 q;d'"
					IP=$(eval $CMD)
					CMD="cat temp/cache.csv | grep $TXID | uniq | tr ';' '\n' | sed '3 q;d'"
					COUNTRY=$(eval $CMD)
				else
					#get transaction ip 
					CMD="curl http://blockchain.info/es/tx/$TXID"
					BCPAGE=$(eval $CMD)
					rm temp/blockchainpage.html
					echo "$BCPAGE" > temp/blockchainpage.html
					CMD="cat temp/blockchainpage.html | grep \"ip-address/\" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | uniq"
					IP=$(eval $CMD)

					if [ "$IP" == "0.0.0.0" ]
					then
						$IP=""
					fi

					#If ip is not null, get country
					COUNTRY=""
					if [ "$IP" != "" ]
					then
						CMD="curl ipinfo.io/$IP | $JSAWKPATH 'return this.country'"
						COUNTRY=$(eval $CMD)
					fi
				fi
				
				#Add country and ip as json nodes
				CMD="sed '$LINE q;d' $filename"
				ORIGINALTX=$(eval $CMD)
				RICHTX="$ORIGINALTX;$IP;$COUNTRY"

				#Save rich transaction on temp file
				echo $RICHTX >> temp/richtemp.csv

				CACHETX="$TXID;$IP;$COUNTRY"
				echo $CACHETX >> temp/cache.csv

				((LINE++))
			done
			#rename original file to *_processed and create new rich_* file
			CMD="mv temp/richtemp.csv \"${filename%.tx*}.rich.csv\""
			eval $CMD
		fi
	done