# MapPLZ-Ruby

[MapPLZ](http://mapplz.com) is a framework to make mapping quick and easy in
your favorite language.

## MapPLZ and Scripting
You can make a map super quickly by using the MapPLZ language. A MapPLZ map
can be described using as simply as this:

```
map
  marker
    "The Statue of Liberty"
    @ "Statue of Liberty, NYC"
  plz
plz
```

You can then output an interactive, HTML + JavaScript map:

```
require 'mapplz'
mapplz.render_html(mapplz_code)
```

You can use it in Rails + HAML, too:

```
div#map
  = mapplz.render_html(@mapplz_code)
```

## MapPLZ and Databases

You can store geodata in SQLite/Spatialite databases, or in Postgres/PostGIS
databases, using a simplified MapPLZ API.

All of these are valid ways to store geodata:

```
mapstore = MapPLZ.new

# a point
mapstore << [lat, lng]

# a line
mapstore << [[point1, point2, point3]]

# GeoJSON string or object
mapstore << { type: "Feature", geometry: { type: "Point", coordinates: [lng, lat] } }
```

Different ways to add properties to geo data:

```
# an array of attributes
pt1 = mapstore << [lat, lng, color, cost]
pt2 = mapstore << [lat, lng, color2, cost2]
# pt1.properties = [color, cost]

# a hash or JSON string of attributes
mapstore << [lat, lng, { color: 'red', cost: 10 }]

# working with records
pt = mapstore << [lat, lng]
pt.name = "Sears Tower"
pt.save!
```

All of these are valid ways to query geodata:

```
# with a value
mapplz.where('layer = ?', name_of_layer)

# get a count
mapplz.count
mapplz.count('layer = ?', name_of_layer)

### COMING SOON

# near a point
mapplz.near([lat, lng])

# in an area
mapplz.inside([point1, point2, point3, point1])
```

## License

Free BSD License
