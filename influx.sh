#!/bin/sh

docker exec -it venus-mqtt-telegraf-timescaledb-influxdb-1 influx -username venus -password s3cr4t -database venus
