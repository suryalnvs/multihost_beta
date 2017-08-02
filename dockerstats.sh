#!/bin/bash
for (( i=0 ; i<432 ; i++ ))
do
      echo `date` >> stats.log 2>&1
      docker stats --no-stream --all >> stats.log 2>&1
      sleep 300
done
