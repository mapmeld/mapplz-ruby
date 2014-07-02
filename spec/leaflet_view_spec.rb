# Encoding: utf-8
require 'spec_helper'

describe Leaflet::ViewHelpers do

  # Leaflet test views
  class TestView < ActionView::Base
  end

  before :all do
    Leaflet.tile_layer = 'http://{s}.somedomain.com/blabla/{z}/{x}/{y}.png'
    Leaflet.attribution = 'Some attribution statement'
    Leaflet.max_zoom = 18

    @view = TestView.new
  end

  it 'should mix in view helpers on initialization' do
    @view.should respond_to(:map)
  end

  it 'should generate a basic map with latitude, longitude and zoom' do
    result = @view.map(center: {
                         latlng: [51.52238797, -0.08366235665],
                         zoom: 18
                       })
    result.should match(/map\.setView\(\[51.52238797, -0.08366235665\], 18\)/)
  end
end
