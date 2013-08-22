#!/bin/bash

mkdir log
exec ./enrichment.sh $* > log/enrichment.log 2> log/enrichment_error.log &
echo "Started!"
echo "See dump.log and error.log for traces."
