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
      "total_time_s" => args[:write_duration].round(3),
      "time_per_point_ms" => (args[:per_point_write] * 1000).round(3),
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
        sorted[chunk].push(data["total_time_s"])
      end
    end
    average_sorted(sorted)
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
      total = 0
      sorted = sort_past_results(past_results)
      sorted.each do |batch_number, batch_time|
        total += batch_time
      end
      sorted[:total_in_s] = total.round(3)
      sorted
    else
      nil
    end
  end

  # #divider:
  # Helps format console results
  def divider
    puts "-------------------------------------"
  end

  # #get_test_time:
  # takes final report and gives total test time
  def get_test_time(report, batch_sizes)
    batch_times = batch_sizes.map do |batch_size|
      report[batch_size]["total_time_s"]
    end
    batch_times.reduce(:+).round(3)
  end

  # #generate_progress:
  # Makes array of 10% progress markers
  def generate_progress(array_length)
    Array.new(100) { |index| index * (array_length / 100) }
  end

  # #check_progress:
  # Checks progress of the writing
  def check_progress(index, array_length, init_time)
    now = Time.now
    progress = generate_progress(array_length)
    if progress.include?(index + 1)
      puts "  -- #{(((index + 1).to_f/array_length.to_f) * 100).to_i}% of batch complete. Total time elapsed #{(now - init_time).round(2)} s"
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
    # For server progress logs
    @init_time = Time.now
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
    finalize_results(results)
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
  def write_chunks(points)
    points.each_with_index do |point_group, index|
      check_progress(index, points.length, @init_time)
      @client.write_points(point_group)
    end
  end

  # #write_ones:
  # deals specifically with writing individual points
  def write_ones(points)
    points.flatten.each_with_index do |point, index|
      check_progress(index, @num_test_points, @init_time)
      @client.write_point("1", {
        values: point[:values],
        tags: point[:tags]
      })
    end
  end

  # #batch_result:
  # takes one batch size and writes points to database
  def batch_result(batch_size)
    puts "Starting Batch #{batch_size}"
    divider
    points = test_points(batch_size, @num_test_points).to_a
    start_time = Time.now
    if batch_size == 1
      write_ones(points)
    else
      write_chunks(points)
    end
    write_duration = Time.now - start_time
    divider
    puts "Finsished Batch #{batch_size} in #{write_duration.round(3)} seconds"
    divider
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

  # #finalize_results:
  # retrieves past results, averages, and appends to results
  def finalize_results(results)
    puts "compiling results..."
    past_results = @client.query 'SELECT * FROM "reports"'
    results[:past_averages_total_time_s] = parse_past_results(past_results)
    results[:total_test_time] = get_test_time(results, @batch_sizes)
    results[:test_details] = {
      num_test_points: @num_test_points,
      batch_sizes: @batch_sizes,
      test_database_name: @bm,
      report_database_name: @rp
    }
    results
  end

end