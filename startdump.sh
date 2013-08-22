#!/bin/bash

mkdir log
exec ./dump.sh $* > log/dump.log 2> log/error.log &
echo "Started!"
echo "See dump.log and error.log for traces."
