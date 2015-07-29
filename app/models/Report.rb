module ReportHelpers
  def test_points(batch_size)
    test_points = (1..@num_test_points).map do |num|
      {
        series: batch_size.to_s,
        values: {
          temp: Random.rand(37...82),
          wspd: Random.rand(0...31).to_f,
          status: 'working',
        },
        tags: {
          sensor: "sensor_#{num}",
        }
      }
    end
    test_points.each_slice(batch_size)
  end
  def log(args)
    message = "Chunks of #{args[:batch_size]}:\n  write time:\n    total: #{args[:write_duration]}\n    per point: #{args[:per_point_write]}\n  drop time:\n    total: #{args[:drop_duration]}\n    per point: #{args[:per_point_drop]}\n--------------------------"
    puts message
  end
  def format_results(args)
    log(args)
    {
      write: {
        total_time: args[:write_duration],
        per_point: args[:per_point_write],
      },
      drop: {
        total_time: args[:drop_duration],
        per_point: args[:per_point_drop],
      },
    }
  end
end
class Report
  include ReportHelpers
  def initialize(args)
    @client = InfluxDB::Client.new args[:database]
    @num_test_points = args[:points]
    @batch_sizes = args[:batch_sizes]
    puts "--------------------------\nRunning benchmark test...\n--------------------------"
  end
  def run
    results = @batch_sizes.map do |batch_size|
      batch_data(batch_size)
    end
    Hash[@batch_sizes.zip(results)]
  end
  private
  def drop_chunk(batch_size)
    @client.query 'drop measurement "' + batch_size.to_s + '"'
  end
  def write_chunk(batch_size)
    test_points(batch_size).each do |points|
      @client.write_points(points)
    end
  end
  def batch_data(batch_size)
    start_time = Time.now
    write_chunk(batch_size)
    write_duration = Time.now - start_time
    drop_chunk(batch_size)
    drop_duration = Time.now - write_duration - start_time
    format_results({
      batch_size: batch_size,
      write_duration: "#{(write_duration * 1000).round(3)} ms",
      drop_duration: "#{(drop_duration * 1000).round(3)} ms",
      per_point_write: "#{(write_duration/@num_test_points * 1000000).round(3)} µm",
      per_point_drop: "#{(drop_duration/@num_test_points * 1000000).round(3)} µm",
    })
  end
end