#!/bin/bash

PATTERN="*.$1.mem"
find -name $PATTERN -exec rm -i {} \;