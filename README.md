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

# GeoJSON string or object
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

Currently you can output the data as GeoJSON:

```
@mapper = MapPLZ.new
@mapper << mapplz_content
@mapper.to_geojson
```

You will be able to output an interactive, HTML+JavaScript map with Leaflet.js

```
require 'mapplz'

@mapper = MapPLZ.new
@mapper << mapplz_code
@mapper.render_html
```

You would be able to use it in Rails + HAML templates, too:

```
div#map
  = @mapper.embed_html
```

## Queries

All of these are valid ways to query geodata:

```
# with a value
mapplz.where('layer = ?', name_of_layer)

# get a count
mapplz.count
mapplz.count('layer = ?', name_of_layer)
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
```

### COMING SOON

```
# near a point
mapplz.near([lat, lng])

# in an area
mapplz.inside([point1, point2, point3, point1])
```

## Language
You can make a map super quickly by using the MapPLZ language. A MapPLZ map
can be described using as simply as this:

```
map
  marker
    "The Statue of Liberty"
    [40, -70]
  plz
plz
```

## License

Free BSD License
