# Venus MQTT via Telegraf to InfluxDB and TimescaleDB

The aim of this project is to investigate and design ideal database schema to store realtime measurements obtained by polling Victron Venus devices via MQTT for the purposes of later visualization and data analysis via Grafana.

## TLDR; Quick start:

1. `$ ./start-grafana-and-dbs.sh`
  
2. `$ VENUS_HOST=192.168.1.19 ./ingest-to-influxdb.sh`

3. `$ VENUS_HOST=192.168.1.19 ./ingest-to-timescaledb.sh`

Note: Replace `VENUS_HOST` in the example above with IP address of your Venus device.

Navigate to http://localhost:3000, sign into Grafana using `admin`, `admin`, and poke around.

Grafana will start up preconfigured with sample dashboards visualizing the same data from both InfluxDB and TimescaleDB.

You can explore the dashboards and their underlying queries to see how the panels are created.

## Summary

Grafana provides excellent support for visualizing data from InfluxDB datasource.

1. It automatically identifies `timestamp` and orders all data points appropriately.
2. It automatically visualizes the first field of each measurement.
3. It provides autocomplete to identify `measurement`.
4. It provides autocomplete for all tags used when filtering queries (`WHERE` constraints).

Grafana provides support for visualizing data stored in TimescaleDB via PostgreSQL datasource.

1. It provides autocomplete to choose `table`.
2. It provides autocomplete to choose `column`.
3. You have to manually tell Grafana which field is `timestamp`.
4. You have to manually tell Grafana to sort values by `timestamp`.
5. You have to tell grafana what column should be visualized.
6. Grafana will not help you autocomplete query constraints in `WHERE`.
7. Grafana will automatically only fetch 50 records, you have to manually remove that. TODO: figure out how to properly query selected time range without putting strain on DB.

So creating SQL queries against TimescaleDB is much more time consuming and non-intuitive.

I had to many times consult the `psql.sh` with manually entered SQL like `select distinct instance from measurememnt where code = 'PVP'` to identify all available solar chargers.

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

Storing data to InfluxDB using the `ingest-to-influxdb.sh` sample script produces the following data points:

Each line identifies one datapoint with `measurement`, `tags`, and `fields`, terminated by `timestamp`.

```
$ VENUS_HOST=192.168.1.19 ./ingest-to-influxdb.sh
...
system/Timers/TimeOnGrid,instanceNumber=0,name=c0619ab2fcaa,portalId=c0619ab2fcaa value=3639393 1681486791414904507
hub4/MaxDischargePower,instanceNumber=0,name=c0619ab2fcaa,portalId=c0619ab2fcaa value=6639.731794662953 1681486791417308798
vebus/Dc/0/Voltage,instanceNumber=276,name=c0619ab2fcaa,portalId=c0619ab2fcaa value=48.599998474121094 1681486791421747215
vebus/Dc/0/Current,instanceNumber=276,name=c0619ab2fcaa,portalId=c0619ab2fcaa value=-81.9000015258789 1681486791424226548
vebus/Dc/0/Power,instanceNumber=276,name=c0619ab2fcaa,portalId=c0619ab2fcaa value=-3546 1681486791426660715
...
```

You can examine series and measurements recorded using the `influx.sh` script as follows:

```
$ ./influx.sh
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

## TimescaleDB Storage

### Alternative 1: Store all measurements in one big SQL table

Storing data to InfluxDB using the `ingest-to-timescaledb.sh` sample script produces the following data points:

Each line identifies one row in a table called `measurement`, storing `timestamp`, `tags`, and `fields` as columns.

```
$ VENUS_HOST=192.168.1.19 ./ingest-to-timescaledb.sh`
...
measurement,code=PVP,instance=279,portal_id=c0619ab2fcaa,topic=solarcharger/Yield/Power valueFloat=118 1681487017577883167
measurement,code=PVV,instance=279,portal_id=c0619ab2fcaa,topic=solarcharger/Pv/V valueFloat=136.64999389648438 1681487017580085667
measurement,code=ScI,instance=279,portal_id=c0619ab2fcaa,topic=solarcharger/Dc/0/Current valueFloat=2.4000000953674316 1681487017582518792
measurement,code=I,instance=512,portal_id=c0619ab2fcaa,topic=battery/Dc/0/Current valueFloat=-76.4000015258789 1681487017584531875
measurement,code=g1,instance=0,portal_id=c0619ab2fcaa,topic=system/Ac/Grid/L1/Power valueFloat=5 1681487017586999209
measurement,code=g2,instance=0,portal_id=c0619ab2fcaa,topic=system/Ac/Grid/L2/Power valueFloat=46 1681487017589478584
measurement,code=g3,instance=0,portal_id=c0619ab2fcaa,topic=system/Ac/Grid/L3/Power valueFloat=6 1681487017592242959
measurement,code=o1,instance=0,portal_id=c0619ab2fcaa,topic=system/Ac/ConsumptionOnOutput/L1/Power valueFloat=1052 1681487017599566542
measurement,code=o2,instance=0,portal_id=c0619ab2fcaa,topic=system/Ac/ConsumptionOnOutput/L2/Power valueFloat=1455 1681487017601862417
measurement,code=o3,instance=0,portal_id=c0619ab2fcaa,topic=system/Ac/ConsumptionOnOutput/L3/Power valueFloat=1181 1681487017604240542
...
```

You can examine data recorded using the `psql.sh` script as follows:

```
$ ./psql.sh 
psql (15.2)
Type "help" for help.

venus=# set search_path = venus;
SET
venus=# select * from measurement ;
            time            |   code   | instance |  portal_id   |                          topic                          |     valueFloat      |          valueString          
----------------------------+----------+----------+--------------+---------------------------------------------------------+---------------------+-------------------------------
 2023-04-14 15:21:39.856895 | si1      | 0        | c0619ab2fcaa | settings/Settings/SystemSetup/AcInput1                  |                   1 | 
 2023-04-14 15:21:39.856899 | si2      | 0        | c0619ab2fcaa | settings/Settings/SystemSetup/AcInput2                  |                   0 | 
 2023-04-14 15:21:39.857061 | sb       | 0        | c0619ab2fcaa | settings/Settings/SystemSetup/BatteryService            |                     | com.victronenergy.battery/512
 2023-04-14 15:21:39.857066 | shao     | 0        | c0619ab2fcaa | settings/Settings/SystemSetup/HasAcOutSystem            |                   1 | 
 2023-04-14 15:21:39.857085 | shd      | 0        | c0619ab2fcaa | settings/Settings/SystemSetup/HasDcSystem               |                   0 | 
 2023-04-14 15:21:39.857087 | umc      | 0        | c0619ab2fcaa | settings/Settings/SystemSetup/MaxChargeCurrent          |                  -1 | 
 2023-04-14 15:21:39.857089 | umv      | 0        | c0619ab2fcaa | settings/Settings/SystemSetup/MaxChargeVoltage          |                   0 | 
 2023-04-14 15:21:39.85711  | svs      | 0        | c0619ab2fcaa | settings/Settings/SystemSetup/SharedVoltageSense        |                   2 | 
 2023-04-14 15:21:39.857218 | H4ms     | 0        | c0619ab2fcaa | settings/Settings/CGwacs/BatteryLife/MinimumSocLimit    |                  10 | 
 2023-04-14 15:21:39.85748  | H4as     | 0        | c0619ab2fcaa | settings/Settings/CGwacs/BatteryLife/SocLimit           |                  10 | 
 2023-04-14 15:21:39.857482 | H4bs     | 0        | c0619ab2fcaa | settings/Settings/CGwacs/BatteryLife/State              |                  10 | 
 2023-04-14 15:21:39.857484 | H4M      | 0        | c0619ab2fcaa | settings/Settings/CGwacs/Hub4Mode                       |                   2 | 
... 
```

Querying such measurements using SQL requires the following logic:

```
$ ./psql.sh 
psql (15.2)
Type "help" for help.

venus=# set search_path = venus;
SET
venus=# select time, "valueFloat" from measurement where (code = 'PVP' and instance = '278');
            time            |     valueFloat     
----------------------------+--------------------
 2023-04-14 15:21:39.880893 |                166
 2023-04-14 15:21:39.956164 | 168.99000549316406
 2023-04-14 15:21:42.01627  |  167.4499969482422
 2023-04-14 15:21:44.02025  | 167.02999877929688
 2023-04-14 15:21:45.958863 | 149.61000061035156
 2023-04-14 15:21:48.055989 | 157.22999572753906
 2023-04-14 15:21:50.001553 | 163.02999877929688
 2023-04-14 15:21:52.047923 |                164
 2023-04-14 15:21:53.993387 |  150.3000030517578
...
```

Querying is possible by filtering on `code`, `topic`, `portal_id`, and `instance`.

#### Alternative 2: Make Timescale DB Mimic InfluxDB

This approach tries to simplify SQL queries by mimicking data storage to be similar to Influx. That way we will have many small tables, each representing a unique MQTT topic and containing only `timestamp`, `portalId`, `instanceNumber`, and `value`, or `stringValue` as appropriate.

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

#### Alternative 3: Mix of both worlds

In this approach we create separate table for each top level MQTT `component`. In that table we store `value` of the measurement, and attach a reduced `topic`, `portalId`, and `instanceNumber`.

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

List of topics for each category varies.

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

