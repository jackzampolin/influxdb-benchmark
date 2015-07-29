class ReportsController < ApplicationController
  def index
    @report = Report.new({
      points: 1000,
      batch_sizes: [1,10,100,1000],
    })
    render json: @report.to_json
  end
end
