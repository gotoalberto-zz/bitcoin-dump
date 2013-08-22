#!/bin/bash

mkdir log

if [ "$1" == "" ]
then
	exec ./dump.sh 1 > log/dump.log 2> log/dump_error.log &
else
	exec ./dump.sh $* > log/dump.log 2> log/dump_.log &
fi
echo "Started!"
echo "See dump.log and error.log for traces."
