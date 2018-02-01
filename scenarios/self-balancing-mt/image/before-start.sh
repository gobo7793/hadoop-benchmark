#!/bin/bash
set -e

echo "Stopping processes before startup..."
source ./start.sh
stop
