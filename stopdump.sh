#!/bin/bash
###########################################
##################### CONFIG
###########################################

OUTPUTDIR="/Users/gotoalberto/git/bitcoin-dump/data"

###########################################
###########################################

if [ ! -f "pid/dump_threads.dat" ]
then
	echo "Already stopped!"
	exit
fi

CMD="cat pid/dump_threads.dat"
THREADS=$(eval $CMD)

THREAD="1"

while [ "$THREAD" -le "$THREADS" ]
do
	 CMD="kill -9 $(cat pid/dump$THREAD.pid)"
	 eval $CMD
	 CMD="rm -rf log_dump_$THREAD temp_dump_$THREAD $OUTPUTDIR/workinprogress_$THREAD*"
	 eval $CMD

	 ((THREAD++))
done

rm -rf pid

echo "Stopped!"