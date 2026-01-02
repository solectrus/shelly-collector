[![Continuous integration](https://github.com/solectrus/shelly-collector/actions/workflows/push.yml/badge.svg)](https://github.com/solectrus/shelly-collector/actions/workflows/push.yml)
[![Maintainability](https://qlty.sh/gh/solectrus/projects/shelly-collector/maintainability.svg)](https://qlty.sh/gh/solectrus/projects/shelly-collector)
[![wakatime](https://wakatime.com/badge/user/697af4f5-617a-446d-ba58-407e7f3e0243/project/018dc198-44e2-4b00-bb01-a7b07d445b01.svg)](https://wakatime.com/badge/user/697af4f5-617a-446d-ba58-407e7f3e0243/project/018dc198-44e2-4b00-bb01-a7b07d445b01)
[![Code Coverage](https://qlty.sh/gh/solectrus/projects/shelly-collector/coverage.svg)](https://qlty.sh/gh/solectrus/projects/shelly-collector)

# Shelly Collector

Collects electricity consumption data from Shelly energy meters and transfers it to InfluxDB 2

Tested with these Shelly devices:

- Shelly Pro 3EM
- Shelly Pro EM-50
- Shelly Pro 1PM
- Shelly Pro 4PM
- Shelly 3EM
- Shelly Plus Plug S
- Shelly PM Mini Gen3
- Shelly Plug S (Gen3)
- Shelly Plug 2
- Shelly EM

There are two ways to get the data from the Shelly devices: Via local access (HTTP) or via the Shelly Cloud API.

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

By default, all numeric values are stored as floating-point numbers in InfluxDB. If you need integer values for power measurements instead (e.g., when migrating from Home Assistant), you can set the power data type to integer using the `INFLUX_POWER_DATA_TYPE` environment variable:

```bash
INFLUX_POWER_DATA_TYPE=Integer
```

This will affect all power-related fields (`power`, `power_a`, `power_b`, `power_c`) while keeping other fields like `temp` and `response_duration` as floats. This is useful when you previously stored power values as integers and want to avoid InfluxDB type conflicts.

## License

Copyright (c) 2024-2026 Georg Ledermann, released under the MIT License
