# Encoding: utf-8
require 'spec_helper'
require 'mapplz'
require 'pg'

describe 'test PostGIS' do
  before(:all) do
    @conn = PG.connect(dbname: 'travis_postgis')
    @conn.exec('CREATE TABLE mapplz (id SERIAL PRIMARY KEY, label VARCHAR(30), geom public.geometry)')
  end

  before(:each) do
    @mapstore = MapPLZ.new(@conn)
    @mapstore.choose_db('postgis')
  end

  after(:each) do
    @conn.exec('DELETE FROM mapplz WHERE 1 = 1')
  end

  after(:all) do
    @conn.exec('DROP TABLE mapplz')
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
    results[0][:label].should eq('hello')
  end

  it 'queries line data' do
    ll_path = [[0, 1], [2, 3]]
    @mapstore << { path: ll_path }
    result = @mapstore.query
    result[:path].should eq(ll_path)
  end

  it 'updates geometry data' do
    pt = @mapstore << { lat: 10, lng: 5 }
    pt[:lat] = 7
    pt.save!
    result = @mapstore.query
    result[:lat].should eq(7)
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
