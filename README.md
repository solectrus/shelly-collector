[![Continuous integration](https://github.com/solectrus/shelly-collector/actions/workflows/push.yml/badge.svg)](https://github.com/solectrus/shelly-collector/actions/workflows/push.yml)
[![Maintainability](https://api.codeclimate.com/v1/badges/2004a93d6d9dbeb908c5/maintainability)](https://codeclimate.com/github/solectrus/shelly-collector/maintainability)
[![wakatime](https://wakatime.com/badge/user/697af4f5-617a-446d-ba58-407e7f3e0243/project/018dc198-44e2-4b00-bb01-a7b07d445b01.svg)](https://wakatime.com/badge/user/697af4f5-617a-446d-ba58-407e7f3e0243/project/018dc198-44e2-4b00-bb01-a7b07d445b01)
[![Test Coverage](https://api.codeclimate.com/v1/badges/2004a93d6d9dbeb908c5/test_coverage)](https://codeclimate.com/github/solectrus/shelly-collector/test_coverage)

# Shelly Collector

Collects electricity consumption data from Shelly energy meters and transfers it to InfluxDB 2

Tested with Shelly devices generation 2:

- Shelly Pro 3EM
- Shelly Plus Plug S

**Untested** with Shelly devices generation 1, like this:

- Shelly EM
- Shelly 3EM
- Shelly Plug S

## Requirements

Linux machine with Docker installed, InfluxDB 2 database

## Getting started

1. Prepare a Linux box (Raspberry Pi, Synology NAS, ...) with Docker installed

2. Make sure your InfluxDB2 database is ready (not subject of this README)

3. Prepare an `.env` file (see `.env.example`)

4. Run the Docker container on your Linux box:

   ```bash
   docker compose up
   ```

The Docker image support multiple platforms: `linux/amd64`, `linux/arm64`, `linux/arm/v7`

## Output

The Shelly Collector sends the following data to InfluxDB (stored as fields in the given measurement):

- `power_a` (in W, if available)
- `power_b` (in W, if available)
- `power_c` (in W, if available)
- `power` (in W, stores `power_a + power_b + power_c` if not available)
- `response_duration` (in milliseconds)
- `temp` (in °C, if available)

## License

Copyright (c) 2024 Georg Ledermann, released under the MIT License
