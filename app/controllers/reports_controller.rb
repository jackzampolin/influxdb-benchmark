class ReportsController < ApplicationController
  def index
    @report = Report.new({
      database: 'benchmark',
      points: 1000,
      batch_sizes: [1,10,100,1000],
    })
    render json: @report.run
  end
end
