# MapPLZ-Ruby

[MapPLZ](http://mapplz.com) is a framework to make mapping quick and easy in
your favorite language.

## Getting started

Extract, transform, and load geodata into MapPLZ:

```
mapstore = MapPLZ.new

# a point
mapstore << [lat, lng]
mapstore.add( [lat, lng] )

# multiple points
mapstore << [point1, point2]

# a line or shape
mapstore << [[point1, point2, point3]]
mapstore << [[point1, point2, point3, point1]]
mapstore << { path: [point1, point2], label: 'hello world' }

# GeoJSON string or hash
mapstore << { type: "Feature", geometry: { type: "Point", coordinates: [lng, lat] } }
```

Include properties along with the geo data:

```
# an array of attributes
pt1 = mapstore << [lat, lng, color, cost]
pt2 = mapstore << [lat, lng, color2, cost2]
# pt1.properties = [color, cost]

# a hash or JSON string of attributes
mapstore << [lat, lng, { color: 'red', cost: 10 }]

# GeoJSON properties
mapstore << { type: "Feature", geometry: { type: "Point", properties: { name: "Bella" }, coordinates: [lng, lat] } }
```

## Export HTML and GeoJSON

You can output the data anytime as GeoJSON:

```
@mapper = MapPLZ.new
@mapper << mapplz_content
@mapper.to_geojson
```

Each mapped item can be exported as GeoJSON or WKT

```
pt = @mapper << { lat: 40, lng: -70 }
pt.to_wkt
pt.to_geojson
```

You can add interactive, HTML+JavaScript maps which use Leaflet.js

```
require 'mapplz'

@mapper = MapPLZ.new
@mapper << geo_stuff
@mapper.render_html
```

This is based on the Leaflet-Rails plugin. Set Leaflet defaults directly:

```
Leaflet.tile_layer = 'http://{s}.somedomain.com/blabla/{z}/{x}/{y}.png'
@mapper.render_html
```

You can pass options to render_html, including new default styles for lines and shapes:

```
@mapper.render_html(max_zoom: 18, fillColor: '#00f')
```

You can also add styles to your data as it's entered into the map datastore.

```
@mapper << { path: [point1, point2], color: 'red', opacity: 0.8 }
```

All of these would appear as clickable map features with popups:

```
@mapper << [40, -70, 'hello popup']
@mapper << { lat: 40, lng: -80, label: 'hello popup' }
@mapper << { path: [point1, point2], color: 'red', label: 'the red line' }
```

## Queries

All of these are valid ways to query geodata:

```
# return all
mapplz.query

# with a value
mapplz.where('layer = ?', name_of_layer)

# get a count
mapplz.count
mapplz.count('layer = ?', name_of_layer)

# near a point
mapplz.near([lat, lng])
mapplz.near([lat, lng], max: 10)

# in an area
mapplz.inside([point1, point2, point3, point1])
```

Queries are returned as an array of GeoItems, which each can be exported as GeoJSON or WKT

```
my_features = @mapper.where('points > 10')
collection = { type: 'FeatureCollection', features: my_features.map { |feature| JSON.parse(feature.to_geojson) } }
```

## Files

MapPLZ can be passed a CSV or GeoJSON file.

```
@mapstore < File.open('test.csv')
@mapstore < File.open('test.geojson')
```

If you have gdal installed, you can import files in most formats parseable by the ```ogr2ogr``` command line tool.

```
@mapstore < File.open('test.shp')
```

## Databases

You can store geodata in SQLite/Spatialite, Postgres/PostGIS, or MongoDB.

MapPLZ simplifies geodata management and queries.

```
# setting the database
# if a site uses ActiveRecord, the database will be set automatically
mapplz.choose_db('postgis')
```

```
# working with records
pt = mapstore << [lat, lng]
pt.name = "Sears Tower"
pt.save!
pt.delete_item
```

### Database Setup

```
# MongoDB
require 'mongo'
mongo_client = Mongo::MongoClient.new
database = mongo_client['mapplz']
collection = database['geoitems']
mapstore = MapPLZ.new(collection)
mapstore.choose_db('mongodb')

# PostGIS
require 'pg'
conn = PG.connect(dbname: 'your_db')
conn.exec('CREATE TABLE mapplz (id SERIAL PRIMARY KEY, label VARCHAR(30), geom public.geometry)')
mapstore = MapPLZ.new(conn)
mapstore.choose_db('postgis')

# Spatialite
require 'sqlite3'
db = SQLite3::Database.new('data/mapplz.sqlite')
db.execute(".load 'libspatialite.so'")
db.execute('CREATE TABLE mapplz (id INTEGER PRIMARY KEY AUTOINCREMENT, label VARCHAR(30), geom BLOB NOT NULL)')
db.execute("SELECT CreateSpatialIndex('mapplz', 'geom')")
mapstore = MapPLZ.new(db)
mapstore.choose_db('spatialite')
```


## Language
You can make a map super quickly by using the MapPLZ language. A MapPLZ map
can be described using as simply as this:

```
mymap = """map
  marker
    "The Statue of Liberty"
    [40, -70]
  plz
plz"""
@mapper << mymap
```

## License

Free BSD License
