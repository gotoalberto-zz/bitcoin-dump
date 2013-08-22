#!/bin/bash

kill -9 $(cat dump.pid)
echo "Stopped!"