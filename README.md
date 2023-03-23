# Venus MQTT via Telegraf to TimescaleDB

The aim of this project is to investigate and design ideal database schema to store realtime measurements obtained by polling Victron Venus devices via MQTT for the purposes of later visualization and data analysis via Grafana.

TLDR; The following sections describe testing setup:

1. [Venus to InfluxDB and Grafana using Telegraf](#playground-telegraf---influxdb---grafana).

2. [Venus to TimescaleDB and Grafana using Telegraf](#playground-telegraf---timescaledb---grafana).

## MQTT

Venus devices provide wide variety of realtime metrics via MQTT described here https://github.com/victronenergy/venus/wiki/dbus.

### MQTT Topic Structure

Venus metrics published via MQTT use the followint topic pattern:

```
N/portalId/component/instanceNumber/path
```

where 

- `portalId`: identifies the Venus device (for example: `c0619ab2fcaa`)
- `component`: ??? (for example: `system`, `battery`, `solarcharger`, `vebus`, `vecan`, ...)
- `instanceNumber`: ??? VRM identifier for each component (for example: `276`, `512`, `256`, ...)
- `path`: DBus path representing a concrete measurement (for example `Ac/ActiveIn/P`, `Ac/Out/P`, `Dc/Battery/Power`, ...)

### MQTT Payload Structure


 - `float` value (for example: `{"value": -0.699999988079071}` for topic `N/c0619ab2fcaa/system/0/Dc/Battery/Current`)
 - `string` value (for example: `{"value": "0102"}` for topic `N/c0619ab2fcaa/battery/512/System/MinVoltageCellId`)
 - `object` value (for example: `{"value": [{"temperature": 24.399999618530273, "power": -35, "instance": 512, "current": -0.699999988079071, "voltage": 50.04999923706055, "soc": 76, "name": "Pylontech battery", "state": 2, "active_battery_service": true, "id": "com.victronenergy.battery.socketcan_can1"}]}` for topic `N/c0619ab2fcaa/system/0/Batteries`)

## InfluxDB Storage

### Pushing MQTT to InfluxDB with Venus Grafana Server

When Venus Grafana Server polls Venus device(s) via MQTT, it analyzes the MQTT topic and payload and prepares a following InfluxDB point:

- `timestamp`
- `measurement`: contains `path` (see above) from MQTT topic stripping the `portalId`, and `instanceNumber`, and including back the `component` part (for example `N/c0619ab2fcaa/vebus/276/Ac/Out/L1/P` -> `vebus/Ac/Out/L1/P`).
- `tags`: `portalId`, `instanceNumber`, `name` (installation name).
- `fields`: `value` with value of type `float`, `stringValue` with value of type `string`. Note: `object` typed values are ignored.

This essentially over time populates the InfluxDB with the following series and measurements:

```
# influx
Connected to http://localhost:8086 version 1.8.10
InfluxDB shell version: 1.8.10
> use venus
Using database venus
> show measurements
...
system/Ac/Grid/L1/Current
system/Ac/Grid/L1/Power
system/Ac/Grid/L2/Current
system/Ac/Grid/L2/Power
system/Ac/Grid/L3/Current
system/Ac/Grid/L3/Power
...
> show series
...
system/Ac/Grid/L1/Current,instanceNumber=0,name=c0619ab2fcaa,portalId=c0619ab2fcaa
system/Ac/Grid/L1/Power,instanceNumber=0,name=c0619ab2fcaa,portalId=c0619ab2fcaa
system/Ac/Grid/L2/Current,instanceNumber=0,name=c0619ab2fcaa,portalId=c0619ab2fcaa
system/Ac/Grid/L2/Power,instanceNumber=0,name=c0619ab2fcaa,portalId=c0619ab2fcaa
system/Ac/Grid/L3/Current,instanceNumber=0,name=c0619ab2fcaa,portalId=c0619ab2fcaa
system/Ac/Grid/L3/Power,instanceNumber=0,name=c0619ab2fcaa,portalId=c0619ab2fcaa
...
```

### Visualizing InfluxDB data in Grafana

Given the structure described above, Populating Grafana dashboards from Influx is as easy as using simple queries:

```
FROM system/Dc/Battery/Soc WHERE portalId="c0619ab2fcaa"
```

```
FROM system/Dc/Pv/Power WHERE portalId="c0619ab2fcaa"
```

Where `system/Dc/Pv/Power` identifies the `measurement` and `WHERE` clauses match attached `tags`.

## TimescaleDB Storage

### Pushing MQTT to TimescaleDB with Telegraf

I am using Telegraf from InfluxData to examine how real time `measurement` with `tags` and `fields` can be stored into relational database like TimescaleDB.

#### Approach 1: Mimic InfluxDB

The first approach will leave the measurements intact as in Influx, and will just replace forward slash in path with underscore. That way we will have many small tables, each representing a unique topic and containing only `timestamp`, `portalId`, and `value`, or `stringValue` as appropriate.

```
$ ./psql.sh
venus=> show tables
...
 venus  | battery_Dc_0_Current                                            | table | venus
 venus  | battery_Dc_0_Power                                              | table | venus
 venus  | battery_Dc_0_Temperature                                        | table | venus
 venus  | battery_Dc_0_Voltage                                            | table | venus
 venus  | battery_DeviceInstance                                          | table | venus
 venus  | battery_Info_BatteryLowVoltage                                  | table | venus
 venus  | battery_Info_ChargeRequest                                      | table | venus
 venus  | battery_Info_FullChargeRequest                                  | table | venus
 venus  | battery_Info_MaxChargeCurrent                                   | table | venus
 venus  | battery_Info_MaxChargeVoltage                                   | table | venus
 venus  | battery_Info_MaxDischargeCurrent                                | table | venus
 venus  | battery_InstalledCapacity                                       | table | venus
 venus  | battery_ProductId                                               | table | venus
 venus  | battery_Redetect                                                | table | venus
 venus  | battery_Soc                                                     | table | venus
 ...
```

Visualizing such data via Grafana is rather easy, because instead of selecting Influx measurement by name, we select from table representing that long measurement.

```
$ ./psql.sh
venus=> select * from venus.system_Dc_Pv_Power;
            time            | instanceNumber |     name     |   portalId   |       value        |    valueString     
----------------------------+----------------+--------------+--------------+--------------------+--------------------
 2023-03-23 14:36:15.763974 | 0              | c0619ab2fcaa | c0619ab2fcaa |  558.9960019721984 | 558.9960019721984
 2023-03-23 14:46:18.911915 | 0              | c0619ab2fcaa | c0619ab2fcaa |  634.4320005111695 | 634.4320005111695
 2023-03-23 14:46:21.590247 | 0              | c0619ab2fcaa | c0619ab2fcaa |  624.3640100822449 | 624.3640100822449
 2023-03-23 14:46:22.245781 | 0              | c0619ab2fcaa | c0619ab2fcaa |  634.6919965343477 | 634.6919965343477
 2023-03-23 14:46:24.19169  | 0              | c0619ab2fcaa | c0619ab2fcaa |  624.3640100822449 | 624.3640100822449
 2023-03-23 14:46:26.2398   | 0              | c0619ab2fcaa | c0619ab2fcaa |  619.3300148677827 | 619.3300148677827
 2023-03-23 14:46:28.174759 | 0              | c0619ab2fcaa | c0619ab2fcaa |  644.5550060939786 | 644.5550060939786
```

#### Approach 2: One table for all

This is the approach where one table called for example `measurements` stores all the measurements from all the devices and each unique measurement is identified by a combination of `productId`, `instanceNumber`, and `measurementCode`.

`measurementCode` can essentially be mapped to DBUS Path (MQTT topic) or combined together with `productId` so that less foreign key combinations are possible.

TODO: fill in the details.
TODO: figure out how to obtain `productId` and `measurementCode` from MQTT.

Visualizing such data via Grafana is rather complex, because to identify proper metric we have to essentailly 

```
$ ./psql.sh
venus=> SELECT time, instanceNumber, portalId, productId, measurementCode * from venus.measurements
WHERE portalId='A' AND productId='B' and measurementId='C';

```

#### Approach 3: Mix of both worlds

In this approach we create separate table for each top level `component`. In that table we store `value` of the measurement, and attach a reduced `topic` and `instanceNumber`.

```
$ ./psql.sh
venus=# set search_path to venus;
SET
venus=# \dt
           List of relations
 Schema |     Name      | Type  | Owner 
--------+---------------+-------+-------
 venus  | adc           | table | venus
 venus  | battery       | table | venus
 venus  | fronius       | table | venus
 venus  | hub4          | table | venus
 venus  | logger        | table | venus
 venus  | modbusclient  | table | venus
 venus  | mqtt_consumer | table | venus
 venus  | platform      | table | venus
 venus  | settings      | table | venus
 venus  | solarcharger  | table | venus
 venus  | system        | table | venus
 venus  | vebus         | table | venus
 venus  | vecan         | table | venus
(13 rows)
```

Visualizing such data via Grafana is rather easy, because to identify proper metric we have to essentailly do the following query:

```
$ ./psql.sh
venus=# select time,value from system where topic='Dc/Battery/Soc';
               venus
            time            | value 
----------------------------+-------
 2023-03-23 15:12:12.37409  |    80
 2023-03-23 15:22:34.274252 |    81
(2 rows)

```

List of topics for each category varies, and essentially maps to the `measurementCode` outlined in Approach 2.

```
# select distinct topic from system order by topic;
                       venus
                       topic                       
---------------------------------------------------
 Ac/ActiveIn/L1/Current
 Ac/ActiveIn/L1/Power
 Ac/ActiveIn/L2/Current
 Ac/ActiveIn/L2/Power
 Ac/ActiveIn/L3/Current
 Ac/ActiveIn/L3/Power
 ...
```

Topics and other complex columns can be extracted to separate tables and visualized by creating auto joining views as outlined for example here: https://github.com/influxdata/telegraf/tree/master/plugins/outputs/postgresql#tag-table-with-view.


### Visualizing TimescaleDB data in Grafana

TODO: See above...


## Playground: Telegraf -> InfluxDB -> Grafana

The following demo setup provides easy way to experiment with dumping Venus MQTT payload into InfluxDB by altering it on its way. By default it is configured to be compatible with Venus Grafana Server output via configuration file `telegraf/telegraf-influxdb.conf`.

Please modify the `VENUS_HOST` environment variable below, and specify IP address of your Venus device. By default it will connect to `127.0.0.1`, as if the ingester would run on the Venus itself.

```
$ ./start-grafana-and-dbs.sh
```

This command will start the databases and grafana with preconfigured data sources and dashboards.

```
$ VENUS_HOST=192.168.1.19 ./ingest-to-influxdb.sh
```

The `ingest-to-influxdb.sh` script will print debug info to its stdout, allowing you to quickly examine what `measurememt` with what `tags`, and `fields` is being observed.

Then you can connect to Grafana via `http://localhost:3000`, and use `admin/admin` to sign in and experiment with the dashboards.

## Playground: Telegraf -> TimescaleDB -> Grafana

The following demo setup provides easy way to experiment with dumping Venus MQTT payload into TimescaleDB by altering it on its way. It is configured via file `telegraf/telegraf-timescaledb.conf`.

Please modify the `VENUS_HOST` environment variable below, and specify IP address of your Venus device. By default it will connect to `127.0.0.1`, as if the ingester would run on the Venus itself.

```
$ ./start-grafana-and-dbs.sh
```

This command will start the databases and grafana with preconfigured data sources and dashboards.

```
$ VENUS_HOST=192.168.1.19 ./ingest-to-timescaledb.sh
```

Then you can connect to Grafana via `http://localhost:3000`, and use `admin/admin` to sign in and experiment with the dashboards.

