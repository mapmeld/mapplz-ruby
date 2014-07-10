If you can help, contact me @mapmeld or https://github.com/mapmeld/mapplz-ruby/issues

# Roadmap

* What databases should be supported?
* What languages should be next?
* What is the real purpose of a MapPLZ API?

# Spatialite

* Do you use Spatialite? Does it have a following?
* How can I get Spatialite working with Ruby and without Rgeo+Rails? Got nowhere on Mac. Linux errors on ```SELECT load_extension('data/libspatialite');``` because I'm missing libgeos-3.1.1.so
* How can I get Spatialite working on Travis CI? This helped me write PostGIS but I get permissions errors on Travis.

# Rails and ActiveRecord

* Is there a way to seamlessly support ActiveRecord while keeping everything else for plain Ruby?
* How does Leaflet-Rails offer its views, and should MapPLZ be more like that?

# PostGIS

* Load GeoItem results from any PostGIS geometry
* Geospatial index and queries

# MongoDB

* Store geodata as geodata in MongoDB - but MultiPolygons cannot
* Geospatial index and queries

# Visualizations

* Instead of a generic HTML/JS, offer color_by(property) ?