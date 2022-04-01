#!/bin/bash

mkdir -p $2
PATTERN="*.$1.mem"
find -name $PATTERN -exec mv {} $2/ \;