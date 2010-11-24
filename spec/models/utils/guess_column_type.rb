require 'rubygems'
require 'spec'

# mock for Test
unless defined?(Togodb)
  module Togodb; end
  module Togodb::Utils; end
end

require File.dirname(__FILE__) + '/../../../lib/togodb/utils/guess_column_type'
include Togodb::Utils

describe GuessColumnType do
  ######################################################################
  ### Helper Methods

  def data(string, options = {})
    @guess = GuessColumnType.new(string, options)
    @columns = @guess.execute
  end

  def data_with_header(string)
    data(string, :header=>true)
  end

  def guessed(index = 0)
    @columns[index]
  end

  ######################################################################
  ### Exceptions

  ### only data

  it "nil" do
    proc {
      data(nil)
    }.should raise_error(GuessColumnType::DataIsEmpty)
  end

  it "empty" do
    proc {
      data("")
    }.should raise_error(GuessColumnType::DataIsEmpty)
  end

  it "empty line" do
    proc {
      data("\n")
    }.should_not raise_error(GuessColumnType::DataIsEmpty)
  end

  ### with header

  it "nil with header" do
    proc {
      data_with_header(nil)
    }.should raise_error(GuessColumnType::DataIsEmpty)
  end

  it "empty" do
    proc {
      data_with_header("")
    }.should raise_error(GuessColumnType::DataIsEmpty)
  end

  it "empty line" do
    proc {
      data_with_header("\n")
    }.should raise_error(GuessColumnType::DataIsEmpty)
  end

  it "double empty line" do
    proc {
      data_with_header("\n\n")
    }.should_not raise_error(GuessColumnType::DataIsEmpty)
  end

  ######################################################################
  ### Column size

  it "body column count" do
    data("1,2,3\n4,5,6")
    @guess.send(:column_size).should == 3
  end

  it "header column count" do
    data_with_header("a,b,c\n1,2,3,4")
    @guess.send(:column_size).should == 3
  end

  ######################################################################
  ### Boolean

  it "detect boolean" do
    data("1\n0\n1\n")
    guessed.should == "boolean"
  end

  ######################################################################
  ### Integer

  it "detect integer" do
    data("1\n2\n3\n")
    guessed.should == "integer"
  end

  it "detect integer with minus" do
    data("1\n-1\n5\n-2\n")
    guessed.should == "integer"
  end

  it "detect integer with minus but only 0,1,-1" do
    data("1\n-1\n0\n")
    guessed.should == "integer"
  end

  ######################################################################
  ### Float

  it "detect float" do
    data("1.0\n0\n1\n")
    guessed.should == "float"
  end

  ######################################################################
  ### Date

  it "detect date" do
    data("1993-08-03\n1994-02-05")
    guessed.should == "date"
  end

  ######################################################################
  ### String

  it "detect string" do
    data("1\n0\na\n")
    guessed.should == "string"
  end

  ######################################################################
  ### Text

  it "detect text with over 256 length" do
    data("1"*1024)
    guessed.should == "text"
  end

  it "detect text with line break" do
    data(%Q["1\n2"\n3])
    guessed.should == "text"
  end

end
