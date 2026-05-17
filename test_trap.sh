#!/bin/bash
trap 'echo "Trap triggered!"; exit 0' SIGTERM
sleep 100 &
wait $!
