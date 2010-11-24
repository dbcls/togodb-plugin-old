require File.dirname(__FILE__) + '/../../spec_helper'

include LuxurySearch

describe LuxurySearch do
  before(:each) do
    @tokens = QueryTokenizer.new(description).execute
    @token  = @tokens.first
  end

  ######################################################################
  ### a simple query

  it "foo" do
    @tokens.should == [Like.new("foo")]
  end

  it " foo " do
    @tokens.should == [Like.new("foo")]
  end

  it "foo" do
    @token.condition_for("name").should == ["name LIKE ?", '%foo%']
  end

  ######################################################################
  ### a token with negation

  it "-foo" do
    @tokens.should == [Like.new("foo").not]
  end

  it " -foo " do
    @tokens.should == [Like.new("foo").not]
  end

  it " - foo " do
    @tokens.should == [Like.new("foo").not]
  end

  it "-foo" do
    @token.condition_for("name").should == ["NOT (name LIKE ?)", '%foo%']
  end

  ######################################################################
  ### two tokens

  it "foo bar" do
    @tokens.should == [Like.new("foo"), Like.new("bar")]
  end

  it " foo  bar " do
    @tokens.should == [Like.new("foo"), Like.new("bar")]
  end

  it "-foo bar" do
    @tokens.should == [Like.new("foo").not, Like.new("bar")]
  end

  it "foo -bar" do
    @tokens.should == [Like.new("foo"), Like.new("bar").not]
  end

  it "-foo -bar" do
    @tokens.should == [Like.new("foo").not, Like.new("bar").not]
  end

  ######################################################################
  ### a numeric operation

  it "<10" do
    @tokens.should == [Lt.new("10")]
  end

  it " < 10 " do
    @tokens.should == [Lt.new("10")]
  end

  it "<=10" do
    @tokens.should == [Ltoe.new("10")]
  end

  it " <= 10 " do
    @tokens.should == [Ltoe.new("10")]
  end

  it ">50" do
    @tokens.should == [Gt.new("50")]
  end

  it " > 50 " do
    @tokens.should == [Gt.new("50")]
  end

  it ">=50" do
    @tokens.should == [Gtoe.new("50")]
  end

  it " >= 50 " do
    @tokens.should == [Gtoe.new("50")]
  end

  ######################################################################
  ### a range query

  it "11..13" do
    @tokens.should == [Between.new("11","13")]
  end

  it "11 .. 13" do
    @tokens.should == [Between.new("11","13")]
  end

  it "-11..13" do
    @tokens.should == [Between.new("11","13").not]
  end

  it " - 11 .. 13 " do
    @tokens.should == [Between.new("11","13").not]
  end

  it "foo..bar" do
    @tokens.should == [Between.new("foo","bar")]
  end

end
