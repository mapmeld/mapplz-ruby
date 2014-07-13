# Encoding: utf-8
require 'spec_helper'
require 'mapplz'

describe 'MapPLZ views' do

  # MapPLZ test views
  class TestView < ActionView::Base
  end

  before :each do
    Leaflet.tile_layer = 'http://{s}.somedomain.com/blabla/{z}/{x}/{y}.png'
    Leaflet.attribution = 'Some attribution statement'
    Leaflet.max_zoom = 18

    @mapstore = MapPLZ.new
  end

  it 'should include MapPLZ markers' do
    @mapstore << [40.1, -70.1]

    result = @mapstore.render_html(center: {
                                     latlng: [51.52238797, -0.08366235665],
                                     zoom: 18
                                   })
    result.should include('map.setView([51.52238797, -0.08366235665], 18)')
    result.should include('L.marker([40.1, -70.1]).addTo(map)')
  end

  it 'should include clickable MapPLZ markers' do
    @mapstore << [40.1, -70.1, 'hello world']
    @mapstore << { lat: 40.2, lng: -70.2, label: 'hello world 2' }

    result = @mapstore.render_html
    result.should include('L.marker([40.1, -70.1]).addTo(map)')
    result.should include("marker.bindPopup('hello world')")
    result.should include('L.marker([40.2, -70.2]).addTo(map)')
    result.should include("marker.bindPopup('hello world 2')")
  end

  it 'should include MapPLZ lines and shapes' do
    @mapstore << { path: [[0, 1], [2, 3]] }
    @mapstore << { path: [[0, 1], [2, 3], [4, 5], [0, 1]] }

    result = @mapstore.render_html
    result.should include('L.polyline([[0.0,1.0],[2.0,3.0]], {}).addTo(map)')
    result.should include('L.polygon([[0.0,1.0],[2.0,3.0],[4.0,5.0],[0.0,1.0]], {}).addTo(map)')
  end

  it 'should include styled lines and shapes' do
    @mapstore << { path: [[0, 1], [2, 3]], label: 'hello world' }
    @mapstore << { path: [[[0, 1], [2, 3], [4, 5], [0, 1]]], fillColor: '#f00' }

    result = @mapstore.render_html
    result.should include('L.polyline([[0.0,1.0],[2.0,3.0]], {"clickable":true}).addTo(map)')
    result.should include("line.bindPopup('hello world')")
    result.should include("L.polygon([[0.0,1.0],[2.0,3.0],[4.0,5.0],[0.0,1.0]], {\"fillColor\":\"#f00\"}).addTo(map)")
  end
end
