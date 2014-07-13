# Encoding: utf-8
require 'spec_helper'
require 'mapplz'
require 'mongo'

describe 'test MongoDB' do
  before(:all) do
    mongo_client = Mongo::MongoClient.new
    db = mongo_client['mapplz']
    @collection = db['geoitems']
    @collection.create_index(geo: Mongo::GEO2DSPHERE)
    @collection.remove
  end

  before(:each) do
    @mapstore = MapPLZ.new(@collection)
    @mapstore.choose_db('mongodb')
  end

  after(:each) do
    @collection.remove
  end

  it 'stores data' do
    @mapstore << [0, 1]
    @mapstore << [2, 3, 'hello world']
    @mapstore << { lat: 4, lng: 5, label: 'hello world' }
    @mapstore << { path: [[0, 1], [2, 3]], label: 'hello world' }

    @mapstore.count.should eq(4)
  end

  it 'queries data' do
    @mapstore << { lat: 0, lng: 1, label: 'hello' }
    @mapstore << [2, 3, 'world']
    results = @mapstore.where("label = 'hello'")
    results.count.should eq(1)
    results[0][:lat].should eq(0)
    results[0][:lng].should eq(1)
  end

  it 'searches for nearest point' do
    @mapstore << { lat: 40, lng: -70 }
    @mapstore << { lat: 35, lng: 110 }

    response = @mapstore.near([30, -60])[0]
    response[:lat].should eq(40)
    response[:lng].should eq(-70)
  end

  it 'searches for point in polygon' do
    pt = @mapstore << { lat: 40, lng: -70 }
    @mapstore << { lat: 35, lng: 110 }

    responses = @mapstore.inside([[38, -72], [38, -68], [42, -68], [42, -72], [38, -72]])
    responses.length.should eq(1)
    responses[0][:lat].should eq(40)
    responses[0][:lng].should eq(-70)

    pt.inside?([[38, -72], [38, -68], [42, -68], [42, -72], [38, -72]]).should eq(true)
  end

  it 'updates a record' do
    pt = @mapstore << { lat: 0, lng: 1, label: 'hello' }
    pt[:label] = 'world'
    pt.save!
    @mapstore.query[0][:label].should eq('world')
  end

  it 'deletes a record' do
    pt = @mapstore << { lat: 0, lng: 1, label: 'hello' }
    pt.delete_item
    @mapstore.count.should eq(0)
  end
end
