class Togodb::Controller < ApplicationController
  def index
    redirect_to :controller=>:togodb_table
  end
end

