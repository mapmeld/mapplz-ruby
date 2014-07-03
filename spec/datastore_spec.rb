# Encoding: utf-8
require 'spec_helper'
require 'mapplz'

describe 'store objects' do
  before(:each) do
    @mapstore = MapPLZ.new
  end

  it 'stores a [x, y] point' do
    pt = @mapstore << [1, 2]
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
  end

  it 'stores additional values as an array of properties' do
    pt = @mapstore << [1, 2, 3, 4]
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
    pt[:properties].should == [3, 4]
  end

  it 'accepts a hash of properties' do
    pt = @mapstore << [1, 2, { a: 1, b: 2 }]
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
    pt[:a].should eq(1)
    pt[:b].should eq(2)
  end

  it 'accepts a hash of properties with symbols' do
    pt = @mapstore << [1, 2, { :a => 1, :b => 2 }]
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
    pt[:a].should eq(1)
    pt[:b].should eq(2)
  end

  it 'stores a hash' do
    pt = @mapstore << { lat: 1, lng: 2, a: 3, b: 4 }
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
    pt[:a].should eq(3)
    pt[:b].should eq(4)
  end

  it 'stores a hash with symbols' do
    pt = @mapstore << { :lat => 1, :lng => 2, :a => 3, :b => 4 }
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
    pt[:a].should eq(3)
    pt[:b].should eq(4)
  end
end

describe 'count and filter objects' do
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
    @mapstore.count('lat < 2').should eq(1)

    # params pass
    @mapstore.count('lat < ?', 2).should eq(1)
    @mapstore.size('lat < ?', 2).should eq(1)
  end

  it 'filters with >, <, and =' do
    @mapstore.count('lat < 2').should eq(1)
    @mapstore.count('lat > 3').should eq(0)
    @mapstore.count('lng = 4').should eq(1)
  end
end
