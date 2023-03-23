#!/bin/sh

docker run -e VENUS_HOST=${VENUS_HOST:-"127.0.0.1"} \
  -v $PWD/telegraf/telegraf-timescaledb.conf:/etc/telegraf/telegraf.conf:ro telegraf
