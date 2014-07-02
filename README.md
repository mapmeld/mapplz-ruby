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
require mapplz
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
# a point
mapplz.data << [lat, lng]
# a line
mapplz.data << [[point1, point2, point3]]

# a point with some data
pt = mapplz.data << [lat, lng]
pt.name = "Sears Tower"
pt.save!

# GeoJSON string or object
mapplz.data << geojson_data
```

All of these are valid ways to query geodata:

```
# with a value
mapplz.where('layer = ?', name_of_layer)

# near a point
mapplz.near([lat, lng])

# in an area
mapplz.inside([point1, point2, point3, point1])
```

## License

Free BSD License
