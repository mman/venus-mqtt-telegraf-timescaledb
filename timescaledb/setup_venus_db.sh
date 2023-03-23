#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL

        CREATE DATABASE venus;
        \connect venus;
	CREATE SCHEMA venus;

	CREATE USER venus WITH PASSWORD 's3cr4t';
	GRANT ALL PRIVILEGES ON SCHEMA venus TO venus;

	CREATE USER grafana WITH PASSWORD 's3cr4t';
        GRANT USAGE ON SCHEMA venus TO grafana;
        GRANT SELECT ON ALL TABLES IN SCHEMA venus TO grafana;
        ALTER ROLE grafana set search_path = venus;

EOSQL
