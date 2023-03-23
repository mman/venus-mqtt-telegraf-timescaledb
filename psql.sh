#!/bin/sh

docker exec -it -e PGPASSWORD=s3cret \
  venus-mqtt-telegraf-timescaledb-timescaledb-1 psql -U postgres venus
