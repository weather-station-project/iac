set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- USERS
    CREATE USER admin WITH SUPERUSER PASSWORD '$DATABASE_ADMIN_USER_PASSWORD';
    CREATE USER read_write WITH PASSWORD '$DATABASE_READ_WRITE_USER_PASSWORD';
    CREATE USER read_only WITH PASSWORD '$DATABASE_READ_ONLY_USER_PASSWORD';

    -- Create database
    CREATE DATABASE weather_station;
    GRANT CONNECT ON DATABASE weather_station TO read_write;
    GRANT CONNECT ON DATABASE weather_station TO read_only;

    \c weather_station

    -- Create schema and point to it to store the objects as the default public is not recommended
    CREATE SCHEMA weather_station;
    GRANT USAGE ON SCHEMA weather_station TO read_write;
    GRANT USAGE ON SCHEMA weather_station TO read_only;
    SET search_path TO weather_station;

    -- Table ambient_temperatures
    CREATE TABLE ambient_temperatures (
        id BIGINT GENERATED ALWAYS AS IDENTITY,
        temperature SMALLINT NOT NULL,
        date_time TIMESTAMPTZ(0) NOT NULL,

        CONSTRAINT ambient_temperatures_pkey PRIMARY KEY (id)
    );

    GRANT SELECT, INSERT ON ambient_temperatures TO read_write;
    GRANT SELECT ON ambient_temperatures TO read_only;
    GRANT USAGE, SELECT ON SEQUENCE ambient_temperatures_id_seq TO read_write;

    -- Table ground_temperatures
    CREATE TABLE ground_temperatures (
        id BIGINT GENERATED ALWAYS AS IDENTITY,
        temperature SMALLINT NOT NULL,
        date_time TIMESTAMPTZ(0) NOT NULL,

        CONSTRAINT ground_temperatures_pkey PRIMARY KEY (id)
    );

    GRANT SELECT, INSERT ON ground_temperatures TO read_write;
    GRANT SELECT ON ground_temperatures TO read_only;
    GRANT USAGE, SELECT ON SEQUENCE ground_temperatures_id_seq TO read_write;

    -- Table air_measurements
    CREATE TABLE air_measurements (
        id BIGINT GENERATED ALWAYS AS IDENTITY,
        pressure SMALLINT NOT NULL,
        humidity SMALLINT NOT NULL,
        date_time TIMESTAMPTZ(0) NOT NULL,

        CONSTRAINT air_measurements_pkey PRIMARY KEY (id)
    );

    GRANT SELECT, INSERT ON air_measurements TO read_write;
    GRANT SELECT ON air_measurements TO read_only;
    GRANT USAGE, SELECT ON SEQUENCE air_measurements_id_seq TO read_write;

    -- Table wind_measurements
    CREATE TABLE wind_measurements (
        id BIGINT GENERATED ALWAYS AS IDENTITY,
        direction VARCHAR(4) NOT NULL,
        speed SMALLINT NOT NULL,
        date_time TIMESTAMPTZ(0) NOT NULL,

        CONSTRAINT wind_measurements_pkey PRIMARY KEY (id)
    );

    GRANT SELECT, INSERT ON wind_measurements TO read_write;
    GRANT SELECT ON wind_measurements TO read_only;
    GRANT USAGE, SELECT ON SEQUENCE wind_measurements_id_seq TO read_write;

    -- Table rainfall
    CREATE TABLE rainfall (
        id BIGINT GENERATED ALWAYS AS IDENTITY,
        amount SMALLINT NOT NULL,
        date_time TIMESTAMPTZ(0) NOT NULL,

        CONSTRAINT rainfall_pkey PRIMARY KEY (id)
    );

    GRANT SELECT, INSERT ON rainfall TO read_write;
    GRANT SELECT ON rainfall TO read_only;
    GRANT USAGE, SELECT ON SEQUENCE rainfall_id_seq TO read_write;

    -- Table users
    CREATE TABLE users (
        login VARCHAR(20) NOT NULL,
        password VARCHAR(200) NOT NULL,
        role VARCHAR(5) NOT NULL,

        CONSTRAINT users_pkey PRIMARY KEY (login)
    );

    GRANT SELECT ON users TO read_write;
    GRANT SELECT ON users TO read_only;

    -- Indexes
    CREATE INDEX ambient_temperatures_date_time_idx ON ambient_temperatures(date_time);
    CREATE INDEX ground_temperatures_date_time_idx ON ground_temperatures(date_time);
    CREATE INDEX air_measurements_date_time_idx ON air_measurements(date_time);
    CREATE INDEX wind_measurements_date_time_idx ON wind_measurements(date_time);
    CREATE INDEX rainfall_date_time_idx ON rainfall(date_time);

    -- Extension to enable crypto
    CREATE EXTENSION IF NOT EXISTS pgcrypto;

    -- Insert users
    INSERT INTO users (login, password, role) VALUES ('sensors', crypt('$DATABASE_READ_WRITE_USER_PASSWORD', gen_salt('bf', 10)), 'write');
    INSERT INTO users (login, password, role) VALUES ('dashboard', crypt('$DATABASE_READ_ONLY_USER_PASSWORD', gen_salt('bf', 10)), 'read');
EOSQL

cat > /var/lib/postgresql/data/pg_hba.conf <<- EOF
# You may want to improve this configuration by using this link https://www.postgresql.org/docs/current/auth-pg-hba-conf.html

# From local, no connections available
local all all reject

# Default user is not allowed
host all "$POSTGRES_USER" all reject

# Users allowed to log from anywhere
host all admin 0.0.0.0/0 scram-sha-256
host all read_write 0.0.0.0/0 scram-sha-256
host all read_only 0.0.0.0/0 scram-sha-256
EOF