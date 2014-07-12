# Encoding: utf-8
require 'spec_helper'
require 'mapplz'

describe 'store objects' do
  before(:each) do
    @mapstore = MapPLZ.new
  end

  it 'stores a [lat, lng] point' do
    pt = @mapstore << [1, 2]
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
    pt[:type].should eq('point')
  end

  it 'stores a [lng, lat] point' do
    pt = @mapstore.add([1, 2], lonlat: true)
    pt[:lat].should eq(2)
    pt[:lng].should eq(1)
  end

  it 'stores additional values as an array of properties' do
    pt = @mapstore << [1, 2, 3, 4]
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
    pt[:properties].should eq([3, 4])
  end

  it 'accepts a hash of properties' do
    pt = @mapstore << [1, 2, { a: 1, b: 2 }]
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
    pt = @mapstore << { type: 'Feature', geometry: { type: 'Point', coordinates: [2, 1] } }
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
  end

  it 'stores a GeoJSON linestring' do
    pt1 = [-70, 40]
    pt2 = [-110, 65]
    line = @mapstore << { type: 'Feature', geometry: { type: 'LineString', coordinates: [pt1, pt2] } }
    line[:path].should eq([[40, -70], [65, -110]])
  end

  it 'stores a GeoJSON polygon' do
    pt1 = [-70, 40]
    pt2 = [-110, 65]
    pt3 = [-90, 80]
    poly = @mapstore << { type: 'Feature', geometry: { type: 'Polygon', coordinates: [[pt1, pt2, pt3, pt1]] } }
    poly[:path].should eq([[[40, -70], [65, -110], [80, -90], [40, -70]]])
  end

  it 'stores a GeoJSON FeatureCollection' do
    store_point = { type: 'Feature', geometry: { type: 'Point', coordinates: [2, 1] } }
    pt = @mapstore << { type: 'FeatureCollection', features: [store_point] }
    pt[:lat].should eq(1)
    pt[:lng].should eq(2)
  end

  # Rarer GeoJSONs
  it 'stores a GeoJSON MultiPoint' do
    pt1 = [-70, 40]
    pt2 = [-110, 65]
    pts = @mapstore << { type: 'Feature', geometry: { type: 'MultiPoint', coordinates: [pt1, pt2] } }
    pts.length.should eq(2)
    pts[0][:lat].should eq(40)
    pts[1][:lat].should eq(65)
  end

  it 'stores a GeoJSON MultiLineString' do
    pt1 = [-70, 40]
    pt2 = [-110, 65]

    lines = @mapstore << { type: 'Feature', geometry: { type: 'MultiLineString', coordinates: [[pt1, pt2], [pt2, pt1]] } }
    lines[0][:path].should eq(lines[1][:path].reverse)
  end

  it 'stores a GeoJSON MultiPolygon' do
    pt1 = [-70, 40]
    pt2 = [-110, 65]
    pt3 = [-90, 80]
    poly_path = [[pt1, pt2, pt3, pt1]]
    polys = @mapstore << { type: 'Feature', geometry: { type: 'MultiPolygon', coordinates: [poly_path, poly_path] } }
    polys[0][:path].should eq(polys[1][:path])
  end

  it 'stores a line of hash points' do
    point1 = { lat: 1, lng: 2 }
    point2 = { lat: 3, lng: 4 }
    point3 = { lat: 5, lng: 6 }
    line = @mapstore << [[point1, point2, point3]]
    line[:path].should eq([[1, 2], [3, 4], [5, 6]])
    line[:type].should eq('polyline')
  end

  it 'stores a line' do
    point1 = [1, 2]
    point2 = [3, 4]
    point3 = [5, 6]
    line = @mapstore << [[point1, point2, point3]]
    line[:path].should eq([[1, 2], [3, 4], [5, 6]])
    line[:type].should eq('polyline')
  end

  it 'stores a line with a label' do
    point1 = [1, 2]
    point2 = [3, 4]
    point3 = [5, 6]
    line = @mapstore << { path: [point1, point2, point3], label: 'hello world' }
    line[:path].should eq([[1, 2], [3, 4], [5, 6]])
    line[:type].should eq('polyline')
    line[:label].should eq('hello world')
  end

  it 'stores a polygon' do
    point1 = [1, 2]
    point2 = [3, 4]
    point3 = [5, 6]
    line = @mapstore << [[point1, point2, point3, point1]]
    line[:path].should eq([[1, 2], [3, 4], [5, 6], [1, 2]])
    line[:type].should eq('polygon')
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

  it 'searches for nearest point' do
    @mapstore << { lat: 40, lng: -70 }
    @mapstore << { lat: 35, lng: 110 }

    response = @mapstore.near([30, -60])[0]
    response[:lat].should eq(40)
    response[:lng].should eq(-70)
  end
end

describe 'save and delete objects' do
  before(:each) do
    @mapstore = MapPLZ.new
    @mapstore << [1, 2]
    @mapstore << [3, 4]
  end

  it 'should delete a record from array' do
    @mapstore.count('lat < 2').should eq(1)

    pt = @mapstore.where('lat < 2')
    pt[0].delete_item
    @mapstore.count('lat < 2').should eq(0)
  end
end

describe 'export GeoJSON' do
  before(:each) do
    @mapstore = MapPLZ.new
    @mapstore << [1, 2]
    @mapstore << [3, 4]
  end

  it 'outputs as a FeatureCollection' do
    gj = JSON.parse(@mapstore.to_geojson)
    gj['type'].should eq('FeatureCollection')
    gj['features'].length.should eq(2)
    first_pt = gj['features'][0]
    # lng, lat order
    first_pt['geometry']['coordinates'].should eq([2, 1])
  end

  it 'includes properties in GeoJSON' do
    @mapstore << [1, 2, { data: 'byte', number: 1 }]
    gj = JSON.parse(@mapstore.to_geojson)

    gj['features'].length.should eq(3)
    data_pt = gj['features'][2]
    data_pt['properties']['data'].should eq('byte')
    data_pt['properties']['number'].should eq(1)
    data_pt['properties'].key?('lat').should eq(false)
  end

  it 'outputs a line in lng,lat order' do
    @mapstore << [[[1, 2], [3, 4]]]
    gj = JSON.parse(@mapstore.to_geojson)
    gj['type'].should eq('FeatureCollection')
    gj['features'].length.should eq(3)

    line = gj['features'][2]
    line['geometry']['type'].should eq('LineString')
    line['geometry']['coordinates'].should eq([[2, 1], [4, 3]])
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
