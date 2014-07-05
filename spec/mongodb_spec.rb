# Encoding: utf-8
require 'spec_helper'
require 'mapplz'
require 'mongo'

describe 'test objects' do
  before(:all) do
    mongo_client = Mongo::MongoClient.new
    db = mongo_client['mapplz']
    @collection = db['geoitems']
    @collection.remove
  end

  before(:each) do
    @mapstore = MapPLZ.new(@collection)
    @mapstore.choose_db('mongodb')
  end

  after(:each) do
    @collection.remove
  end

  it 'stores data in MongoDB' do
    @mapstore << [0, 1]
    @mapstore << [2, 3, 'hello world']
    @mapstore << { lat: 4, lng: 5, label: 'hello world' }
    @mapstore << { path: [[0, 1], [2, 3]], label: 'hello world' }

    @mapstore.count.should eq(4)
  end

  it 'queries data in MongoDB' do
    @mapstore << { lat: 0, lng: 1, label: 'hello' }
    @mapstore << [2, 3, 'world']
    results = @mapstore.where('lat < 2')
    results.count.should eq(1)
    results[0][:label].should eq('hello')
  end

  it 'updates a record in MongoDB' do
    pt = @mapstore << { lat: 0, lng: 1, label: 'hello' }
    pt[:label] = 'world'
    pt.save!
    @mapstore.query[0][:label].should eq('world')
  end

  it 'deletes a record from MongoDB' do
    pt = @mapstore << { lat: 0, lng: 1, label: 'hello' }
    pt.delete_item
    @mapstore.count.should eq(0)
  end
end
