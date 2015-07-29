# InfluxDB Benchmarking Test

Requires a running install of [InfluxDB 0.9.2](https://influxdb.com/docs/v0.9/introduction/installation.html).

To run just:

```bash
$ git clone https://github.com/jackzampolin/influxdb-benchmark.git
or
$ git clone git@github.com:jackzampolin/influxdb-benchmark.git

$ bundle install
$ bin/rails server
```

Then, in another terminal window:

```bash
$ curl localhost:3000 | python -m json.tool
```

The route will output testing data in a JSON format.  Below is a sample output that also includes average times for 10 test runs and full data for one.

```json
{
    "1": {
        "time_per_point_ms": 2.661,
        "total_time_s": 266.109
    },
    "10": {
        "time_per_point_ms": 0.338,
        "total_time_s": 33.831
    },
    "100": {
        "time_per_point_ms": 0.093,
        "total_time_s": 9.255
    },
    "1000": {
        "time_per_point_ms": 0.06,
        "total_time_s": 5.989
    },
    "past_averages_total_time_s": {
        "1": 260.953,
        "10": 36.893,
        "100": 9.204,
        "1000": 5.718,
        "total_in_s": 312.768
    },
    "test_details": {
        "batch_sizes": [
             1,
            10,
            100,
            1000
        ],
        "num_test_points": 100000,
        "report_database_name": "reports",
        "test_database_name": "benchmark"
    },
    "total_test_time": 315.184
}
```

The sample data points have a structure as follows:

```ruby
{
  series: "#{batch_size}",
  values: {
    temp: Random.rand(37...82),
    wspd: Random.rand(0...31).to_f,
    status: 'working',
  },
  tags: {
    sensor: "sensor_#{num}",
  }
}
```

## Configuration

To change either the number of points to test or the different batch sizes to test you can set them in ./app/controllers/reports_controller.rb

```ruby
Examples:

@report = Report.new({
  points: 100000,
  batch_sizes: [1,10,100,1000],
})

@report = Report.new({
  points: 100000,
  batch_sizes: [100 ,1000, 10000],
})
```

### Potential Features
- Add reports/:n route to run route n times with one request
- Add additional report delivery methods
- Track additional information with every report
- Refactor to eliminate special case for writing individual points.  Should be no performance difference between client.write_point and client.write_points because of implementation in gem.
- Run report n times a day and persist all results automatically.  Then only deliver results when asked greatly reducing latency.

### Notes
- App does timeout occasionally.  Timeout coming from InfulxDB Ruby client.  Larger numbers timeout more frequently
- Batch numbers other than [1,10,100,1000] don't log correctly on server.
- If changing either batch size or test size please reset results databse.