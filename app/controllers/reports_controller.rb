class ReportsController < ApplicationController
  def index
    @report = Report.new('report')
    render json: @report.data
  end
end
