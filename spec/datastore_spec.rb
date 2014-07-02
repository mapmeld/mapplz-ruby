# Encoding: utf-8
require 'spec_helper'
require 'mapplz'

describe 'store objects' do
  before(:each) do
    @mapstore = MapPLZ.new
    @mapstore << [1, 2]
    @mapstore << [3, 4]
  end

  it 'should return a count of stored objects' do
    @mapstore.count.should eq(2)
    @mapstore.length.should eq(2)
    @mapstore.size.should eq(2)
  end

  it 'should return a count of matching objects' do
    @mapstore.count('WHERE lat < 2').should eq(1)

    # params pass
    @mapstore.count('WHERE lat < ?', 2).should eq(1)
    @mapstore.size('WHERE lat < ?', 2).should eq(1)
  end

  it 'supports >, <, and =' do
    @mapstore.count('WHERE lat < 2').should eq(1)
    @mapstore.count('WHERE lat > 3').should eq(0)
    @mapstore.count('WHERE lng = 4').should eq(1)
  end
end
