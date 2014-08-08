# MapPLZ-Ruby

[MapPLZ](http://mapplz.com) is a framework to make mapping quick and easy in
your favorite language.

<img src="https://raw.githubusercontent.com/mapmeld/mapplz-ruby/master/logo.jpg" width="140"/>

## Getting started

MapPLZ consumes many many types of geodata. It can process data for a script or dump
it into a database.

Here's how you can add some data:

```
mapstore = MapPLZ.new

# a point
mapstore << [lat, lng]
mapstore << { lat: 40, lng: -70 }
mapstore.add( [lng, lat], lonlat: true )

# multiple points
mapstore << [point1, point2]

# a line or polygon
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

MapPLZ can read GeoJSON files and some CSVs.

```
@mapstore < File.open('test.csv')
@mapstore < File.open('test.geojson')
```

If you have gdal installed, you can import files in formats parseable by the ```ogr2ogr``` command line tool.

```
@mapstore < File.open('test.shp')
```

## Export HTML and GeoJSON

You can output the entire dataset anytime as GeoJSON:

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
@mapper.embed_html # a map embed snippet
@mapper.render_html # a full HTML page
```

This extends the Leaflet-Rails plugin. Set Leaflet defaults directly:

```
Leaflet.tile_layer = 'http://{s}.somedomain.com/blabla/{z}/{x}/{y}.png'
@mapper.render_html
```

You can pass options to render_html, including new default styles for lines and shapes:

```
@mapper.render_html(max_zoom: 18, fillColor: '#00f')
```

You can also add styles as you enter data into MapPLZ.

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

## Databases

If you want to store geodata in a database, you can use Postgres/PostGIS or MongoDB.
SQLite/Spatialite support is written but untested.

MapPLZ simplifies geodata management and queries.

```
# setting the database
mapplz.choose_db('postgis')
```

```
# updating records
pt = mapstore << [lat, lng]
pt[:name] = "Sears Tower"
pt[:lat] += 1
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
collection.create_index(geo: Mongo::GEO2DSPHERE)
mapstore = MapPLZ.new(collection)
mapstore.choose_db('mongodb')

# PostGIS
# before you start, install PostGIS and create a table
# here's my schema:
# CREATE TABLE mapplz (id SERIAL PRIMARY KEY, properties JSON, geom public.geometry)

require 'pg'
conn = PG.connect(dbname: 'your_db')
mapstore = MapPLZ.new(conn)
mapstore.choose_db('postgis')
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
