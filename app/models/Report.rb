module ReportHelpers

  # #test_points:
  # creates array of data and slices to appropriate size
  def test_points(batch_size, num_test_points)
    test_points = (1..num_test_points).map do |num|
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
    end
    test_points.each_slice(batch_size)
  end

  # #format_results:
  # properly formats the results of testing
  def format_results(args)
    {
      "total_time_ms" => (args[:write_duration] * 1000).round(3),
      "time_per_point_µm" => (args[:per_point_write] * 1000000).round(3),
    }
  end

  # #parse_json:
  # strips wrapping and parses json from database
  def parse_json(pr)
    pr.map do |result_hash|
      JSON.parse(result_hash["json_results"].gsub(/\\/,''))
    end
  end

  # #sort_past_results:
  # sorts past results into desired structure
  def sort_past_results(pr)
    sorted = {
      "1" => [],
      "10" => [],
      "100" => [],
      "1000" => [],
    }
    parse_json(pr).each do |result_hash|
      result_hash.each do |chunk, data|
        sorted[chunk].push(data["total_time_ms"])
      end
    end
    sorted
  end

  # #average_sorted:
  # takes the sorted data and averages it
  def average_sorted(sorted)
    sorted.each do |chunk,total_times|
      num_reports = total_times.length
      sorted[chunk] = (total_times.reduce(:+)/num_reports).round(3)
    end
  end

  # #parse_past_results:
  # takes past results from database and averages them
  def parse_past_results(pr)
    past_results = pr[0]["values"]
    if past_results.length > 1
      sorted = sort_past_results(past_results)
      average_sorted(sorted)
    else
      nil
    end
  end

end

class Report

  # ReportHelpers:
  # contains methods that don't involve database operations
  include ReportHelpers

  def initialize(args)
    # @bm: name of testing database. Wiped with every run
    @bm = "benchmark"
    # @rp: name of report storage
    @rp = "reports"
    # @client: InfluxDB client
    @client = set_client
    # number of points to test with
    @num_test_points = args[:points]
    # different batch sizes to test
    @batch_sizes = args[:batch_sizes]
  end

  # #to_json:
  # runs all other methods and outputs a JSON friendly result array
  def to_json
    # #result_data runs all tests
    results = Hash[@batch_sizes.zip(result_data)]
    # delete testing database
    @client.delete_database(@bm)
    # reset @client database to persist results
    @client.config.database = @rp
    # saves results to database
    persist_results(results)
    # adds past averages to return object
    add_past_averages(results)
  end

  private

  # #set_client:
  # ensures local database has proper setup for testing and storage
  def set_client
    client = InfluxDB::Client.new
    dbs = client.list_databases.to_json
    if dbs.include?(@bm) && dbs.include?(@rp)
      client.config.database = @bm
    elsif dbs.include?(@bm) && !dbs.include?(@rp)
      client.create_database(@rp)
      client.config.database = @bm
    elsif dbs.include?(@rp) && !dbs.include?(@bm)
      client.create_database(@bm)
      client.config.database = @bm
    else
      client.create_database(@rp)
      client.create_database(@bm)
      client.config.database = @bm
    end
    client
  end

  # #write_chunks:
  # iterates over dummy data and writes it to database
  def write_chunks(batch_size)
    test_points(batch_size, @num_test_points).each do |points|
      @client.write_points(points)
    end
  end

  # #batch_result:
  # takes one batch size and writes points to database
  def batch_result(batch_size)
    start_time = Time.now
    write_chunks(batch_size)
    write_duration = Time.now - start_time
    format_results({
      batch_size: batch_size,
      write_duration: write_duration,
      per_point_write: write_duration/@num_test_points,
    })
  end

  # #result_data:
  # maps @batch_sizes with #batch_result
  def result_data
    @batch_sizes.map do |batch_size|
      batch_result(batch_size)
    end
  end

  # #persist_results:
  # saves results of test to database
  def persist_results(results)
    @client.write_point("reports", {
      values: {
        json_results: results.to_json
      },
      timestamp: Time.now.to_i,
    })
  end

  # #add_past_averages:
  # retrieves past results, averages, and appends to results
  def add_past_averages(results)
    past_results = @client.query 'SELECT * FROM "reports"'
    results[:past_averages_total_time_ms] = parse_past_results(past_results)
    results[:test_details] = {
      num_test_points: @num_test_points,
      batch_sizes: @batch_sizes,
      test_database_name: @bm,
      report_database_name: @rp
    }
    results
  end

end