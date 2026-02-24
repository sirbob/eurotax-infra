#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER mock_user WITH PASSWORD 'mock_dev_pass_2024';
    CREATE USER api_user WITH PASSWORD 'api_dev_pass_2024';

    CREATE DATABASE eurotax_mock OWNER mock_user;
    CREATE DATABASE eurotax_api OWNER api_user;

    GRANT ALL PRIVILEGES ON DATABASE eurotax_mock TO mock_user;
    GRANT ALL PRIVILEGES ON DATABASE eurotax_api TO api_user;
EOSQL
