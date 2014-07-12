# Encoding: utf-8
require 'spec_helper'
require 'mapplz'
require 'sqlite3'

describe 'test Spatialite' do
  before(:all) do
    # need to load Spatialite functions (even if sqlite file exists)
    @db = SQLite3::Database.new('data/mapplz.sqlite')
    @db.execute("SELECT load_extension('libspatialite.so')")
    @db.execute('CREATE TABLE mapplz (id INTEGER PRIMARY KEY AUTOINCREMENT, label VARCHAR(30), geom BLOB NOT NULL)')
    @db.execute("SELECT CreateSpatialIndex('mapplz', 'geom')")
  end

  before(:each) do
    @mapstore = MapPLZ.new(@db)
    @mapstore.choose_db('spatialite')
    @db.execute('CREATE TABLE ')
  end

  after(:each) do
    @conn.execute('DELETE FROM mapplz WHERE 1 = 1')
  end

  after(:all) do
    @conn.execute('DROP TABLE mapplz')
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
