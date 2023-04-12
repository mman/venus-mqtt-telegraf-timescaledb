#!/bin/sh

#
# This list consumes datalist.json produced manually from datalist.py
# and outputs a json mapping file usable by telegraf lookup plugin
# https://github.com/influxdata/telegraf/blob/release-1.26/plugins/processors/lookup/README.md
# to convert MQTT topic to measurement code for storage to TimescaleDB
#

set -x

cat datalist.json |\
jq '(. | to_entries[] | .value[] += {component:.key} | .value | to_entries[] | { key: (.value.component + .key), value: { code: .value.code, whenToLog: .value.whenToLog } } )' |\
jq -s from_entries \
>venus-mqtt-topic-to-code-lut.json

