#!/bin/bash
set -e

[[ "$1" != 'controller' ]] && exit 0

# start self-balancing approach
java -cp .:JKalman.jar controller/Controller &

