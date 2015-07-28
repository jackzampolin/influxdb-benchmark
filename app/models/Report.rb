class Report
  def initialize(database)
    @database = database
    @influxdb = InfluxDB::Client.new udp: { host: '127.0.0.1', port: 8000 }
  end
  def data
    @influxdb.create_database(@database)
    byebug
    @influxdb.list_databases
  end
end