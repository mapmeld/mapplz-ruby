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

  it 'stores multiple points' do
    pts = @mapstore << [[1, 2], [2, 3], [4, 5]]
    pts[0][:lat].should eq(1)
    pts[1][:lat].should eq(2)
    pts[2][:lat].should eq(4)
  end

  it 'stores a GeoJSON string point' do
    pt = @mapstore << '{ "type": "Feature", "geometry": { "type": "Point", "coordinates": [2, 1] } }'
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
  end

  it 'stores a GeoJSON hash point' do
    pt = @mapstore << { type: "Feature", geometry: { type: "Point", coordinates: [2, 1] } }
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
  end

  it 'stores a GeoJSON hash point' do
    pt = @mapstore << { :type => "Feature", :geometry => { :type => "Point", :coordinates => [2, 1] } }
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
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

describe 'custom MapPLZ language' do
  before(:each) do
    @mapstore = MapPLZ.new
  end

  it 'stores a lat lng point' do
    lang = '''map
      marker
        "The Statue of Liberty"
        [40, -70]
      plz
    plz'''
    pt = @mapstore << lang

    pt[:lat].should eq(40)
    pt[:lng].should eq(-70)
    pt[:label].should eq('The Statue of Liberty')
  end
end
