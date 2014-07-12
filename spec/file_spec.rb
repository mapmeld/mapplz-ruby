# Encoding: utf-8
require 'spec_helper'
require 'mapplz'

describe 'parse CSV files' do
  before(:each) do
    @mapstore = MapPLZ.new
  end

  it 'loads a point from a CSV string' do
    csv_file = File.open('spec/data/point.csv')
    pt = @mapstore << csv_file.read
    pt[:lat].should eq(40)
    pt[:lng].should eq(-70)
    pt[:label].should eq('hello world')
  end

  it 'loads a point from a CSV file' do
    csv_file = File.open('spec/data/point.csv')
    pt = @mapstore << csv_file
    pt[:lat].should eq(40)
    pt[:lng].should eq(-70)
    pt[:label].should eq('hello world')
  end

  it 'loads GeoJSON from a CSV column' do
    csv_file = File.open('spec/data/geojson.csv')
    pt = @mapstore << csv_file
    pt[:lat].should eq(40)
    pt[:lng].should eq(-70)
    pt[:label].should eq('hello world')
  end

  it 'loads WKT from a CSV column' do
    csv_file = File.open('spec/data/wkt.csv')
    pt = @mapstore << csv_file
    pt[:lat].should eq(40)
    pt[:lng].should eq(-70)
    pt[:label].should eq('hello world')
  end
end

describe 'parse GeoJSON' do
  before(:each) do
    @mapstore = MapPLZ.new
  end

  it 'loads GeoJSON from a file' do
    gj_file = File.open('spec/data/data.geojson')
    pt = @mapstore << gj_file
    pt[:lat].should eq(40)
    pt[:lng].should eq(-70)
    pt[:label].should eq('hello world')
  end
end

# describe 'parse a shapefile' do
#   before(:each) do
#     @mapstore = MapPLZ.new
#   end
#
#   it 'loads points from a shapefile using gdal' do
#   end
# end
