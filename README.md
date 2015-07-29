# InfluxDB Benchmarking Test

Requires a running install of [InfluxDB](https://influxdb.com/docs/v0.9/introduction/installation.html).

To run just:

```bash
$ bundle install
$ bin/rails server
```

Then, in another terminal window,

```bash
$ curl localhost:3000

or (if you have python 2.6+ installed)

$ curl localhost:3000 | python -m json.tool
```

The route will output testing data in a JSON format.

Below is a sample output that also includes average times for 10 test runs and full data for one.

```json
{
    "1": {
        "time_per_point_µm": 6781.274,
        "total_time_ms": 6781.274
    },
    "10": {
        "time_per_point_µm": 970.569,
        "total_time_ms": 970.569
    },
    "100": {
        "time_per_point_µm": 466.668,
        "total_time_ms": 466.668
    },
    "1000": {
        "time_per_point_µm": 411.478,
        "total_time_ms": 411.478
    },
    "past_averages_total_time_ms": {
        "1": 6653.352,
        "10": 979.123,
        "100": 467.042,
        "1000": 398.311
    },
    "test_details": {
        "batch_sizes": [
            1,
            10,
            100,
            1000
        ],
        "num_test_points": 1000,
        "report_database_name": "reports",
        "test_database_name": "benchmark"
    }
}
```