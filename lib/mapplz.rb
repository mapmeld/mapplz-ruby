# Encoding: utf-8

require 'sql_parser'
require 'json'
require 'csv'
require 'geokdtree'
require 'digest'
include Leaflet::ViewHelpers

# MapPLZ datastore
class MapPLZ
  DATABASES = %w(array postgres postgresql postgis sqlite spatialite mongodb)

  def initialize(db = {})
    @db_type = 'array'
    @db_client = db
    @db = {
      client: @db_client,
      type: @db_type
    }
    @my_array = []

    @parser = SqlParser.new

    choose_db(ActiveRecord::Base.connection.adapter_name) if defined?(ActiveRecord)
  end

  def choose_db(db)
    db.downcase!
    fail 'Database type not supported by MapPLZ' unless DATABASES.include?(db)
    db = 'postgis' if db == 'postgres' || db == 'postgresql'
    db = 'spatialite' if db == 'sqlite'
    db = 'mongodb' if db == 'mongo'
    @db_type = db
    @db[:type] = db
  end

  def add(user_geo, lonlat = false)
    begin
      geo_objects = MapPLZ.standardize_geo(user_geo, lonlat, @db)
    rescue MapPLZException
      geo_objects = code(user_geo)
    end

    if @db_type == 'array'
      @my_array += geo_objects
    elsif @db_type == 'mongodb'
      geo_objects.each do |geo_object|
        save_obj = geo_object.clone
        save_obj.delete(:_id)
        save_obj.delete(:lat)
        save_obj.delete(:lng)
        save_obj.delete(:path)
        save_obj.delete(:centroid)
        save_obj.delete(:type)
        save_obj[:geo] = JSON.parse(geo_object.to_geojson)['geometry']
        reply = @db_client.insert(save_obj)
        geo_object[:_id] = reply.to_s
      end
    elsif @db_type == 'postgis' || @db_type == 'spatialite'
      geo_objects.each do |geo_object|
        geom = geo_object.to_wkt
        if @db_type == 'postgis'
          geojson_props = (JSON.parse(geo_object.to_geojson)['properties'] || {})
          reply = @db_client.exec("INSERT INTO mapplz (properties, geom) VALUES ('#{geojson_props.to_json}', ST_GeomFromText('#{geom}')) RETURNING id")
        elsif @db_type == 'spatialite'
          reply = @db_client.execute("INSERT INTO mapplz (label, geom) VALUES ('#{geo_object[:label] || ''}', AsText('#{geom}')) RETURNING id")
        end
        geo_object[:id] = reply[0]['id']
      end
    end

    if geo_objects.length == 1
      geo_objects[0]
    else
      geo_objects
    end
  end

  def count(where_clause = nil, add_on = nil)
    results = query(where_clause, add_on)
    results.length
  end

  def query(where_clause = nil, add_on = nil)
    geo_results = []

    if where_clause.present?
      if @db_type == 'array'
        geo_results = query_array(where_clause, add_on)
      elsif @db_type == 'mongodb'
        conditions = parse_sql(where_clause, add_on = nil)
        mongo_conditions = {}
        conditions.each do |condition|
          field = condition[:field]
          compare_value = add_on || condition[:value]
          operator = condition[:operator].to_s

          mongo_conditions[field] = compare_value if operator == '='
          mongo_conditions[field] = { '$lt' => compare_value } if operator == '<'
          mongo_conditions[field] = { '$lte' => compare_value } if operator == '<='
          mongo_conditions[field] = { '$gt' => compare_value } if operator == '>'
          mongo_conditions[field] = { '$gte' => compare_value } if operator == '>='
        end

        cursor = @db_client.find(mongo_conditions)
      elsif @db_type == 'postgis'

        conditions = parse_sql(where_clause, add_on = nil)
        conditions.each do |condition|
          where_prop = condition[:field].to_s
          where_clause = where_clause.gsub(where_prop, "json_extract_path_text(properties, '#{where_prop}')")
        end

        cursor = @db_client.exec("SELECT id, ST_AsText(geom) AS geo, properties FROM mapplz WHERE #{where_clause}")
      elsif @db_type == 'spatialite'
        if add_on.is_a?(String)
          where_clause = where_clause.gsub('?', "'#{add_on}'")
        elsif add_on.is_a?(Integer) || add_on.is_a?(Float)
          where_clause = where_clause.gsub('?', "#{add_on}")
        end

        cursor = @db_client.execute("SELECT id, AsText(geom) AS geo, label FROM mapplz WHERE #{where_clause}")
      end
    else
      # query all
      if @db_type == 'array'
        geo_results = @my_array
      elsif @db_type == 'mongodb'
        cursor = @db_client.find
      elsif @db_type == 'postgis'
        cursor = @db_client.exec('SELECT id, ST_AsText(geom) AS geo, properties FROM mapplz')
      elsif @db_type == 'spatialite'
        cursor = @db_client.execute('SELECT id, AsText(geom) AS geo, label FROM mapplz')
      else
        # @my_db.all
      end
    end

    geo_results += read_cursor(cursor)
    geo_results
  end

  def code(mapplz_code)
    @code_lines = mapplz_code.gsub("\r", '').split("\n")
    @code_level = 'toplevel'
    @button_layers = []
    @code_button = 0
    @code_layers = []
    @code_label = ''
    @code_color = nil
    code_line(0)
    @code_layers
  end

  def to_geojson
    geojson = { type: 'FeatureCollection', features: query.map { |feature| JSON.parse(feature.to_geojson) } }
    geojson.to_json
  end

  def render_html(options = {})
    my_embed = embed_html(options)
    my_embed = "<!DOCTYPE html>
<html>
  <head>
    <style type=\"text/css\">
    html, body, #map {
      width: 100%;
      height: 100%;
      margin: 0;
      padding: 0;
    }
    </style>
    <script type=\"text/javascript\" src=\"http://cdn.leafletjs.com/leaflet-0.7.3/leaflet.js\"></script>
    <link href=\"http://cdn.leafletjs.com/leaflet-0.7.3/leaflet.css\" rel=\"stylesheet\" type=\"text/css\"/>
  </head>
  <body>
    #{my_embed}
  </body>
</html>"
    my_embed
  end

  def embed_html(options = {})
    # Leaflet options
    options[:tile_layer] ||= Leaflet.tile_layer
    options[:attribution] ||= Leaflet.attribution
    options[:max_zoom] ||= Leaflet.max_zoom
    options[:container_id] ||= 'map'

    geojson_features = JSON.parse(to_geojson)['features']

    # use Leaflet to add clickable markers
    options[:markers] = []
    geojson_features.each do |feature|
      next if feature['geometry']['type'] != 'Point'

      if feature.key?('properties')
        if feature['properties'].is_a?(Hash) && feature['properties'].key?('label')
          label = feature['properties']['label']
        elsif feature['properties'].key?('properties') && feature['properties']['properties'].is_a?(Array) && feature['properties']['properties'].length == 1
          label = feature['properties']['properties'][0]
        end
      else
        label = nil
      end
      options[:markers] << { latlng: feature['geometry']['coordinates'].reverse, popup: label }
    end

    render_text = map(options).gsub('</script>', '')

    # add clickable lines and polygons after
    # Leaflet-Rails does not support clickable lines or any polygons
    geojson_features.each do |feature|
      next if feature['geometry']['type'] == 'Point'

      label = nil
      path_options = {}
      path_options[:color] = options[:color] if options.key?(:color)
      path_options[:opacity] = options[:opacity] if options.key?(:opacity)
      path_options[:fillColor] = options[:fillColor] if options.key?(:fillColor)
      path_options[:fillOpacity] = options[:fillOpacity] if options.key?(:fillOpacity)
      path_options[:weight] = options[:weight] if options.key?(:weight)
      path_options[:stroke] = options[:stroke] if options.key?(:stroke)

      if feature.key?('properties')
        if feature['properties'].key?('label')
          label = feature['properties']['label']
        elsif feature['properties'].key?('properties') && feature['properties']['properties'].is_a?(Array) && feature['properties']['properties'].length == 1
          label = feature['properties']['properties'][0]
        end

        path_options[:color] = feature['properties']['color'] if feature['properties'].key?('color')
        path_options[:opacity] = feature['properties']['opacity'].to_f if feature['properties'].key?('opacity')
        path_options[:fillColor] = feature['properties']['fillColor'] if feature['properties'].key?('fillColor')
        path_options[:fillOpacity] = feature['properties']['fillOpacity'].to_f if feature['properties'].key?('fillOpacity')
        path_options[:weight] = feature['properties']['weight'].to_i if feature['properties'].key?('weight')
        path_options[:stroke] = feature['properties']['stroke'] if feature['properties'].key?('stroke')
        path_options[:clickable] = true unless label.nil?
      end

      flip_coordinates = feature['geometry']['coordinates']
      if flip_coordinates[0][0].is_a?(Array)
        flip_coordinates.each do |segment|
          segment.map! { |coord| coord.reverse }
        end
      else
        flip_coordinates.map! { |coord| coord.reverse }
      end

      if feature['geometry']['type'] == 'LineString'
        render_text += ('line = L.polyline(' + flip_coordinates.to_json + ", #{path_options.to_json}).addTo(map);\n").html_safe
        render_text += "line.bindPopup('#{label}');\n".html_safe unless label.nil?
      elsif feature['geometry']['type'] == 'Polygon'
        render_text += ('polygon = L.polygon(' + flip_coordinates[0].to_json + ", #{path_options.to_json}).addTo(map);\n").html_safe
        render_text += "polygon.bindPopup('#{label}');\n".html_safe unless label.nil?
      end
    end

    render_text + '</script>'
  end

  def near(user_geo, limit = 10, max = 40_010_000, lon_lat = false)
    max = max.to_f # send max in meters
    limit = limit.to_i

    if user_geo.is_a?(Hash)
      lat = user_geo[:lat] || user_geo['lat'] || user_geo[:latitude] || user_geo['latitude']
      lng = user_geo[:lng] || user_geo['lng'] || user_geo[:longitude] || user_geo['longitude']
      user_geo = [lat.to_f, lng.to_f]
    elsif user_geo.is_a?(Array)
      user_geo.reverse! if lon_lat
    else
      fail 'must query near a point'
    end

    lat = user_geo[0].to_f
    lng = user_geo[1].to_f
    wkt = "POINT(#{lng} #{lat})"
    geo_results = []

    if @db_type == 'array'
      @my_array.sort! do |a, b|
        a_distance = a.distance_from([lat, lng])
        b_distance = b.distance_from([lat, lng])
        a_distance <=> b_distance
      end
      geo_results = @my_array.slice(0, limit)
    elsif @db_type == 'mongodb'
      cursor = @db_client.find(geo: { '$nearSphere' => { '$geometry' => { type: 'Point', coordinates: [lng, lat] }, '$maxDistance' => max } })
    elsif @db_type == 'postgis'
      cursor = @db_client.exec("SELECT id, ST_AsText(geom) AS geo, properties, ST_Distance(start.geom::geography, ST_GeomFromText('#{wkt}')::geography) AS distance FROM mapplz AS start WHERE ST_Distance(start.geom::geography, ST_GeomFromText('#{wkt}')::geography) <= #{max} ORDER BY distance LIMIT #{limit}")
    elsif @db_type == 'spatialite'
      cursor = @db_client.execute("SELECT id, AsText(geom) AS geo, label, Distance(start.geom, AsText('#{wkt}')) AS distance FROM mapplz AS start WHERE Distance(start.geom, AsText('#{wkt}')) <= #{max} ORDER BY distance LIMIT #{limit}")
    end

    geo_results += read_cursor(cursor)
    geo_results
  end

  def inside(user_geo)
    geo_results = []

    # accept [point1, point2, point3, point1] as a polygon search area
    if user_geo.is_a?(Array) && user_geo[0].is_a?(Array) && !user_geo[0][0].is_a?(Array)
      user_geo = [user_geo]
    end

    search_areas = MapPLZ.standardize_geo(user_geo)

    search_areas.each do |search_area|
      next unless search_area.key?(:path)
      wkt = search_area.to_wkt

      if @db_type == 'array'
        # in-Ruby point-in-polygon
        @my_array.each do |geo_item|
          GeoItem.centroid(geo_item)
          geo_results << geo_item if geo_item.inside?(search_area)
        end
      elsif @db_type == 'mongodb'
        polygon_gj = JSON.parse(search_area.to_geojson)['geometry']
        cursor = @db_client.find(geo: { '$geoWithin' => { '$geometry' => polygon_gj } })
      elsif @db_type == 'postgis'
        cursor = @db_client.exec("SELECT id, ST_AsText(geom) AS geo, properties FROM mapplz AS start WHERE ST_Contains(ST_GeomFromText('#{wkt}'), start.geom)")
      elsif @db_type == 'spatialite'
        cursor = @db_client.exec("SELECT id, AsText(geom) AS geo, label FROM mapplz WHERE MBRContains(FromText('#{wkt}'), FromText(geom))")
      end

      geo_results += read_cursor(cursor)
    end
    geo_results
  end

  def self.flip_path(path)
    path.map! do |pt|
      [pt[1].to_f, pt[0].to_f]
    end
  end

  def self.parse_wkt(geo_item, geom_string)
    if geom_string.index('POINT')
      coordinates = geom_string.gsub('POINT', '').gsub('(', '').gsub(')', '').split(' ')
      geo_item[:lat] = coordinates[1].to_f
      geo_item[:lng] = coordinates[0].to_f
    elsif geom_string.index('LINESTRING')
      line_nodes = geom_string.gsub('LINESTRING', '').gsub('(', '').gsub(')', '').split(',')
      geo_item[:path] = line_nodes.map do |pt|
        pt = pt.split(' ')
        [pt[1].to_f, pt[0].to_f]
      end
    elsif geom_string.index('POLYGON')
      line_nodes = geom_string.gsub('POLYGON', '').gsub('(', '').gsub(')', '').split(', ')
      geo_item[:path] = line_nodes.map do |pt|
        pt = pt.split(' ')
        [pt[1].to_f, pt[0].to_f]
      end
    end
    geo_item
  end

  def self.standardize_geo(user_geo, lonlat = false, db = nil)
    return [user_geo] if user_geo.is_a?(GeoItem)
    geo_objects = []

    if user_geo.is_a?(File)
      file_type = File.extname(user_geo)
      if ['.csv', '.tsv', '.tdv', '.txt', '.geojson', '.json'].include?(file_type)
        # parse this as if it were sent as a string
        user_geo = user_geo.read
      else
        # convert this with ogr2ogr and parse as a string
        begin
          `ogr2ogr -f "GeoJSON" tmp.geojson #{File.path(user_geo)} -t_srs EPSG:4326`
          user_geo = File.open('tmp.geojson').read
        rescue
          raise 'gdal was not installed, or format was not accepted by ogr2ogr'
        end
      end
    end

    if user_geo.is_a?(String)
      begin
        user_geo = JSON.parse(user_geo)
      rescue
        # not JSON - attempt CSV
        begin
          CSV.parse(user_geo.gsub('\"', '""'), headers: true) do |row|
            geo_objects += standardize_geo(row, lonlat, db)
          end
          return geo_objects
        rescue
          # not JSON or CSV - attempt mapplz parse
          raise MapPLZException, 'call code() to parse mapplz language'
        end
      end
    end

    if user_geo.is_a?(Array) && user_geo.length > 0
      if user_geo[0].is_a?(Array) && user_geo[0].length > 0
        if user_geo[0][0].is_a?(Array) || (user_geo[0][0].is_a?(Hash) && user_geo[0][0].key?(:lat) && user_geo[0][0].key?(:lng))
          # lines and shapes
          user_geo.map! do |path|
            path_pts = []
            path.each do |path_pt|
              if lonlat
                lat = path_pt[1] || path_pt[:lat]
                lng = path_pt[0] || path_pt[:lng]
              else
                lat = path_pt[0] || path_pt[:lat]
                lng = path_pt[1] || path_pt[:lng]
              end
              path_pts << [lat, lng]
            end

            # polygon border repeats first point
            if path_pts[0] == path_pts.last
              geo_type = 'polygon'
              path_pts = [path_pts]
            else
              geo_type = 'polyline'
            end

            geoitem = GeoItem.new(db)
            geoitem[:path] = path_pts
            geoitem[:type] = geo_type
            geoitem
          end
          return user_geo
        end
      end

      # multiple objects being added? iterate through
      if user_geo[0].is_a?(Hash) || user_geo[0].is_a?(Array)
        user_geo.each do |geo_piece|
          geo_objects += standardize_geo(geo_piece, lonlat, db)
        end
        return geo_objects
      end

      # first two spots are a coordinate
      validate_lat = user_geo[0].to_f != 0 || user_geo[0].to_s == '0'
      validate_lng = user_geo[1].to_f != 0 || user_geo[1].to_s == '0'

      if validate_lat && validate_lng
        geo_object = GeoItem.new(db)
        geo_object[:type] = 'point'

        if lonlat
          geo_object[:lat] = user_geo[1].to_f
          geo_object[:lng] = user_geo[0].to_f
        else
          geo_object[:lat] = user_geo[0].to_f
          geo_object[:lng] = user_geo[1].to_f
        end
      else
        fail 'no latitude or longitude found'
      end

      # assume user properties are an ordered array of values known to the user
      user_properties = user_geo.drop(2)

      # only one property and it's a string? check for JSON hash
      if user_properties.length == 1 && user_properties[0].is_a?(String)
        begin
          user_properties[0] = JSON.parse(user_properties[0])
        rescue
        end
      end

      # only one property and it's a hash? it's a hash of properties
      if user_properties.length == 1 && user_properties[0].is_a?(Hash)
        user_properties[0].keys.each do |key|
          geo_object[key.to_sym] = user_properties[0][key]
        end
      else
        geo_object[:properties] = user_properties
      end

      geo_objects << geo_object

    elsif user_geo.is_a?(Hash) || user_geo.is_a?(CSV::Row)
      if user_geo.is_a?(CSV::Row)
        # convert CSV::Row to geo hash
        geo_hash = {}
        user_geo.headers.each do |header|
          geo_hash[header] = user_geo[header]
        end
        user_geo = geo_hash
      end

      # check for lat and lng
      validate_lat = false
      validate_lat = 'lat' if user_geo.key?('lat') || user_geo.key?(:lat)
      validate_lat ||= 'latitude' if user_geo.key?('latitude') || user_geo.key?(:latitude)

      validate_lng = false
      validate_lng = 'lng' if user_geo.key?('lng') || user_geo.key?(:lng)
      validate_lng ||= 'lon' if user_geo.key?('lon') || user_geo.key?(:lon)
      validate_lng ||= 'long' if user_geo.key?('long') || user_geo.key?(:long)
      validate_lng ||= 'longitude' if user_geo.key?('longitude') || user_geo.key?(:longitude)

      if validate_lat && validate_lng
        # single hash
        geo_object = GeoItem.new(db)
        geo_object[:lat] = user_geo[validate_lat].to_f
        geo_object[:lng] = user_geo[validate_lng].to_f
        geo_object[:type] = 'point'

        user_geo.keys.each do |key|
          next if key == validate_lat || key == validate_lng
          geo_object[key.to_sym] = user_geo[key]
        end
        geo_objects << geo_object
      elsif user_geo.key?('path') || user_geo.key?(:path)
        # try line or polygon
        path_pts = []
        path = user_geo['path'] if user_geo.key?('path')
        path = user_geo[:path] if user_geo.key?(:path)

        if path_pts[0].is_a?(Array) && path_pts[0][0].is_a?(Array)
          # ring polygon
          path.each do |ring|
            ring.map! do |path_pt|
              if lonlat
                lat = path_pt[1] || path_pt[:lat]
                lng = path_pt[0] || path_pt[:lng]
              else
                lat = path_pt[0] || path_pt[:lat]
                lng = path_pt[1] || path_pt[:lng]
              end
              [lat, lng]
            end
          end
          path_pts = path
        else
          path.each do |path_pt|
            if lonlat
              lat = path_pt[1] || path_pt[:lat]
              lng = path_pt[0] || path_pt[:lng]
            else
              lat = path_pt[0] || path_pt[:lat]
              lng = path_pt[1] || path_pt[:lng]
            end
            path_pts << [lat, lng]
          end

          # polygon border repeats first point
          if path_pts[0] == path_pts.last
            geo_type = 'polygon'
            path_pts = [path_pts]
          else
            geo_type = 'polyline'
          end
        end

        geoitem = GeoItem.new(db)
        geoitem[:path] = path_pts
        geoitem[:type] = geo_type

        property_list = user_geo.clone
        property_list = property_list[:properties] if property_list.key?(:properties)
        property_list = property_list['properties'] if property_list.key?('properties')
        property_list.delete(:path)
        property_list.keys.each do |prop|
          geoitem[prop.to_sym] = property_list[prop]
        end

        geo_objects << geoitem
      elsif user_geo.key?('geo') || user_geo.key?(:geo)
        # this key is GeoJSON or WKT
        geotext = (user_geo['geo'] || user_geo[:geo])
        if geotext.upcase.index('POINT(') || geotext.upcase.index('LINESTRING(') || geotext.upcase.index('POLYGON(')
          # try WKT
          geoitem = GeoItem.new(db)
          geoitem = MapPLZ.parse_wkt(geoitem, geotext)
        else
          # GeoJSON
          begin
            geoitem = standardize_geo(JSON.parse(geotext), lonlat, db)[0]
          rescue
            # did not recognize format
            raise 'did not recognize format in CSV geo column'
          end
        end
        user_geo.keys.each do |key|
          next if ['lat', 'lng', 'geo', 'geom', 'geojson', 'wkt', :lat, :lng, :geo, :geom, :geojson, :wkt].include?(key)
          geoitem[key.to_sym] = user_geo[key]
        end
        geo_objects << geoitem
      else
        # try GeoJSON
        if user_geo.key?(:type)
          user_geo['type'] = user_geo[:type] || ''
          user_geo['features'] = user_geo[:features] if user_geo.key?(:features)
          user_geo['properties'] = user_geo[:properties] || {}
          if user_geo.key?(:geometry)
            user_geo['geometry'] = user_geo[:geometry]
            user_geo['geometry']['type'] = user_geo[:geometry][:type]
            user_geo['geometry']['coordinates'] = user_geo[:geometry][:coordinates]
          end
        end
        if user_geo.key?('type')
          if user_geo['type'] == 'FeatureCollection' && user_geo.key?('features')
            # recursive onto features
            user_geo['features'].each do |feature|
              geo_objects += standardize_geo(feature, lonlat, db)
            end
          elsif user_geo.key?('geometry') && user_geo['geometry'].key?('coordinates')
            # each feature
            coordinates = user_geo['geometry']['coordinates']

            if user_geo['geometry']['type'] == 'Point'
              geo_object = GeoItem.new(db)
              geo_object[:lat] = coordinates[1].to_f
              geo_object[:lng] = coordinates[0].to_f
              geo_object[:type] = 'point'
              geo_objects << geo_object
            elsif user_geo['geometry']['type'] == 'LineString'
              geo_object = GeoItem.new(db)
              MapPLZ.flip_path(coordinates)
              geo_object[:path] = coordinates
              geo_object[:type] = 'polyline'
              geo_objects << geo_object
            elsif user_geo['geometry']['type'] == 'Polygon'
              geo_object = GeoItem.new(db)
              coordinates.map! do |ring|
                MapPLZ.flip_path(ring)
              end
              geo_object[:path] = coordinates
              geo_object[:type] = 'polygon'
              geo_objects << geo_object
            elsif user_geo['geometry']['type'] == 'MultiPoint'
              coordinates.each do |point|
                geo_object = GeoItem.new(db)
                geo_object[:lat] = point[1].to_f
                geo_object[:lng] = point[0].to_f
                geo_object[:type] = 'point'
                geo_objects << geo_object
              end
            elsif user_geo['geometry']['type'] == 'MultiLineString'
              coordinates.each do |line|
                geo_object = GeoItem.new(db)
                geo_object[:path] = MapPLZ.flip_path(line)
                geo_object[:type] = 'polyline'
                geo_objects << geo_object
              end
            elsif user_geo['geometry']['type'] == 'MultiPolygon'
              coordinates.each do |poly|
                geo_object = GeoItem.new(db)
                poly.map! do |ring|
                  MapPLZ.flip_path(ring)
                end
                geo_object[:path] = poly
                geo_object[:type] = 'polygon'
                geo_objects << geo_object
              end
            end

            # store properties on all generated geometries
            prop_keys = {}
            if user_geo.key?('properties')
              user_geo['properties'].keys.each do |key|
                prop_keys[key.to_sym] = user_geo['properties'][key]
              end
            end
            geo_objects.each do |geo|
              prop_keys.keys.each do |key|
                geo[key] = prop_keys[key]
              end
            end
          end
        end
      end
    end

    geo_objects
  end

  # alias methods

  # aliases for add
  def <<(user_geo)
    add(user_geo)
  end

  def push(user_geo)
    add(user_geo)
  end

  # aliases for query
  def where(where_clause = nil, add_on = nil)
    query(where_clause, add_on)
  end

  # aliases for count
  def size(where_clause = nil, add_on = nil)
    count(where_clause, add_on)
  end

  def length(where_clause = nil, add_on = nil)
    count(where_clause, add_on)
  end

  private

  # internal error record
  class MapPLZException < Exception
  end

  # internal map object record
  class GeoItem < Hash
    def initialize(db = nil)
      db = { type: 'array', client: nil } if db.nil?
      @db = db
      @db_type = db[:type]
      @db_client = db[:client]
    end

    def save!
      # update record in database
      if @db_type == 'mongodb'
        save_obj = clone
        save_obj.delete(:_id)
        save_obj.delete(:lat)
        save_obj.delete(:lng)
        save_obj.delete(:path)
        save_obj.delete(:centroid)
        save_obj.delete(:type)
        save_obj[:geo] = JSON.parse(to_geojson)['geometry']
        @db[:client].update({ _id: BSON::ObjectId(self[:_id]) }, save_obj)
      elsif @db_type == 'postgis'
        geojson_props = (JSON.parse(to_geojson)['properties'] || {})
        @db_client.exec("UPDATE mapplz SET geom = ST_GeomFromText('#{to_wkt}'), properties = '#{geojson_props.to_json}' WHERE id = #{self[:id]}") if @db_type == 'postgis'
      elsif @db_type == 'spatialite'
        updaters = []
        keys.each do |key|
          next if [:id, :lat, :lng, :path, :type, :centroid].include?(key)
          updaters << "#{key} = '#{self[key]}'" if self[key].is_a?(String)
          updaters << "#{key} = #{self[key]}" if self[key].is_a?(Integer) || self[key].is_a?(Float)
        end
        updaters << "geom = AsText('#{to_wkt}')"
        if updaters.length > 0
          @db_client.execute("UPDATE mapplz SET #{updaters.join(', ')} WHERE id = #{self[:id]}")
        end
      end
    end

    def delete_item
      if @db_type == 'array'
        keys.each do |key|
          delete(key)
        end
      elsif @db_type == 'mongodb'
        # update record in database
        @db[:client].remove(_id: BSON::ObjectId(self[:_id]))
      elsif @db_type == 'postgis'
        @db_client.exec("DELETE FROM mapplz WHERE id = #{self[:id]}")
      elsif @db_type == 'spatialite'
        @db_client.execute("DELETE FROM mapplz WHERE id = #{self[:id]}")
      end
    end

    def to_wkt
      if self[:type] == 'point'
        geom = "POINT(#{self[:lng]} #{self[:lat]})"
      elsif self[:type] == 'polyline'
        linestring = self[:path].map do |path_pt|
          "#{path_pt[1]} #{path_pt[0]}"
        end
        geom = "LINESTRING(#{linestring.join(', ')})"
      elsif self[:type] == 'polygon'
        linestring = self[:path][0].map do |path_pt|
          "#{path_pt[1]} #{path_pt[0]}"
        end
        geom = "POLYGON((#{linestring.join(', ')}))"
      end
      geom
    end

    def to_geojson
      if key?(:properties)
        property_list = { properties: self[:properties] }
      else
        property_list = clone
        property_list.delete(:lat)
        property_list.delete(:lng)
        property_list.delete(:path)
        property_list.delete(:type)
        property_list.delete(:centroid)
      end

      output_geo = {
        type: 'Feature',
        properties: property_list
      }

      if self[:type] == 'point'
        # point
        output_geo[:geometry] = {
          type: 'Point',
          coordinates: [self[:lng], self[:lat]]
        }
      elsif self[:type] == 'polyline'
        # line
        output_geo[:geometry] = {
          type: 'LineString',
          coordinates: MapPLZ.flip_path(self[:path])
        }
      elsif self[:type] == 'polygon'
        # polygon
        rings = self[:path].clone
        rings.map! do |ring|
          MapPLZ.flip_path(ring)
        end
        output_geo[:geometry] = {
          type: 'Polygon',
          coordinates: rings
        }
      end
      output_geo.to_json
    end

    def centroid
      # verify up-to-date centroid exists
      path_hash = Digest::SHA256.digest(self[:path].to_s)
      (key?(:path) && key?(:centroid) && self[:centroid] == path_hash)
    end

    def distance_from(user_geo)
      GeoItem.centroid(self)
      user_geo = MapPLZ.standardize_geo(user_geo)[0]
      GeoItem.centroid(user_geo)

      Geokdtree::Tree.distance([user_geo[:lat], user_geo[:lng]], [self[:lat], self[:lng]])
    end

    def inside?(user_geo)
      GeoItem.centroid(self)

      # accept [point1, point2, point3, point1] as a polygon search area
      if user_geo.is_a?(Array) && user_geo[0].is_a?(Array) && !user_geo[0][0].is_a?(Array)
        user_geo = [user_geo]
      end

      user_geo = MapPLZ.standardize_geo(user_geo)[0]
      path_pts = user_geo[:path]
      path_pts = path_pts[0] if user_geo[:type] == 'polygon'

      # point in polygon from http://jakescruggs.blogspot.com/2009/07/point-inside-polygon-in-ruby.html
      c = false
      i = -1
      j = path_pts.size - 1
      while (i += 1) < path_pts.size
        if (path_pts[i][0] <= self[:lat] && self[:lat] < path_pts[j][0]) || (path_pts[j][0] <= self[:lat] && self[:lat] < path_pts[i][0])
          if self[:lng] < (path_pts[j][1] - path_pts[i][1]) * (self[:lat] - path_pts[i][0]) / (path_pts[j][0] - path_pts[i][0]) + path_pts[i][1]
            c = !c
          end
        end
        j = i
      end
      c
    end

    def self.centroid(geo_item)
      # generate centroid if possible and not already existing
      if geo_item.key?(:path) && !geo_item.centroid
        coordinates = geo_item[:path].clone

        # centroid calculation from https://code.google.com/p/tokland/source/browse/trunk/centroid
        consecutive_pairs = (coordinates + [coordinates.first]).each_cons(2)
        area = 0.5 * consecutive_pairs.map do |(x0, y0), (x1, y1)|
          (x0 * y1) - (x1 * y0)
        end
        area.inject(:+)

        consecutive_pairs.map! do |(x0, y0), (x1, y1)|
          cross = (x0 * y1 - x1 * y0)
          [(x0 + x1) * cross, (y0 + y1) * cross]
        end
        (center_lat, center_lng) = consecutive_pairs.transpose.map do |cs|
          cs.inject(:+) / (6 * area)
        end

        geo_item[:centroid] = Digest::SHA256.digest(geo_item[:path].to_s)
        geo_item[:lat] = center_lat
        geo_item[:lng] = center_lng
      end
    end
  end

  def read_cursor(cursor)
    if cursor.nil?
      []
    else
      geo_results = []
      cursor.each do |geo_result|
        if @db_type == 'postgis'
          geo_item = GeoItem.new(@db)
          geom = (geo_result['geo'] || geo_result[:geo]).upcase
          geo_item = MapPLZ.parse_wkt(geo_item, geom)
          geo_result = JSON.parse(geo_result['properties'])
        elsif @db_type == 'spatialite'
          geo_item = GeoItem.new(@db)
          geom = (geo_result['geo'] || geo_result[:geo]).upcase
          geo_item = MapPLZ.parse_wkt(geo_item, geom)
        elsif @db_type == 'mongodb'
          geom = { 'type' => 'Feature', 'geometry' => geo_result['geo'] }
          geo_item = MapPLZ.standardize_geo(geom, true, @db)[0]
        end

        if geo_result.is_a?(Array)
          geo_item[:properties] = geo_result
        else
          geo_result.keys.each do |key|
            next if [:geo].include?(key.to_sym)
            geo_item[key.to_sym] = geo_result[key]
          end
        end

        geo_results << geo_item
      end
      geo_results
    end
  end

  def code_line(index)
    return if index >= @code_lines.length
    line = @code_lines[index].strip
    codeline = line.downcase.split(' ')

    if @code_level == 'toplevel'
      @code_level = 'map' if line.index('map')
      return code_line(index + 1)

    elsif @code_level == 'map' || @code_level == 'button'
      if codeline.index('button') || codeline.index('btn')
        @code_level = 'button'
        @button_layers << { layers: [] }
        @code_button = @button_layers.length
      end

      if codeline.index('marker')
        @code_level = 'marker'
        @code_latlngs = []
        return code_line(index + 1)
      elsif codeline.index('line')
        @code_level = 'line'
        @code_latlngs = []
        return code_line(index + 1)
      elsif codeline.index('shape')
        @code_level = 'shape'
        @code_latlngs = []
        return code_line(index + 1)
      end

      if codeline.index('plz') || codeline.index('please')
        if @code_level == 'map'
          @code_level = 'toplevel'
          return
        elsif @code_level == 'button'
          # add button
          @code_level = 'map'
          @code_button = nil
          return code_line(index + 1)
        end
      end

    elsif @code_level == 'marker' || @code_level == 'line' || @code_level == 'shape'
      if codeline.index('plz') || codeline.index('please')

        if @code_level == 'marker'
          geoitem = GeoItem.new(@db)
          geoitem[:lat] = @code_latlngs[0][0]
          geoitem[:lng] = @code_latlngs[0][1]
          geoitem[:label] = @code_label || ''

          @code_layers << geoitem
        elsif @code_level == 'line'
          geoitem = GeoItem.new(@db)
          geoitem[:path] = @code_latlngs
          geoitem[:stroke_color] = (@code_color || '')
          geoitem[:label] = @code_label || ''

          @code_layers << geoitem
        elsif @code_level == 'shape'
          geoitem = GeoItem.new(@db)
          geoitem[:paths] = @code_latlngs
          geoitem[:stroke_color] = (@code_color || '')
          geoitem[:fill_color] = (@code_color || '')
          geoitem[:label] = @code_label || ''

          @code_layers << geoitem
        end

        if @code_button
          @code_level = 'button'
        else
          @code_level = 'map'
        end

        @code_latlngs = []
        return code_line(index + 1)
      end

    end

    # geocoding starts with @

    # reading a color
    if codeline[0].index('#') == 0
      @code_color = codeline[0]
      if @code_color.length != 4 && @code_color.length != 7
        # named color
        @code_color = @code_color.gsub('#', '')
      end

      if @code_level == 'button'
        # button color
      end

      return codeline(index + 1)
    end

    # reading a raw string (probably text for a popup)
    if codeline[0].index('"') == 0
      # check button
      @code_label = line[(line.index('"') + 1)..line.length]
      @code_label = @code_label[0..(@code_label.index('"') - 1)]
    end

    # reading a latlng coordinate
    if line.index('[') && line.index(',') && line.index(']')
      latlng_line = line.gsub('[', '').gsub(']', '').split(',').map! { |num| num.to_f }

      # must be a 2D coordinate
      return codeline(index + 1) if latlng_line.length != 2

      @code_latlngs << latlng_line

      return code_line(index + 1)
    end

    code_line(index + 1)
  end

  def parse_sql(where_clause, add_on = nil)
    where_clause.downcase! unless where_clause.blank?
    where_clause = where_clause.gsub('?', '\'?\'') if add_on.present?
    where_clause = 'select * from bogus_table where ' + where_clause

    # parse where conditions
    @parser.parse(where_clause).tree[:conditions]
  end

  def query_array(where_clause, add_on = nil)
    # prepare where clause for parse
    conditions = parse_sql(where_clause, add_on)

    # filter array
    @my_array.select do |geo_obj|
      return false if geo_obj.nil?
      is_valid = true
      conditions.each do |condition|
        field = condition[:field]
        compare_value = add_on || condition[:value]
        operator = condition[:operator].to_s

        # check that key exists
        is_valid = geo_obj.key?(field)
        break unless is_valid

        # compare to value
        if operator == '<'
          is_valid = geo_obj[field] < compare_value
        elsif operator == '<='
          is_valid = geo_obj[field] <= compare_value
        elsif operator == '>'
          is_valid = geo_obj[field] > compare_value
        elsif operator == '>='
          is_valid = geo_obj[field] >= compare_value
        elsif operator == '='
          is_valid = geo_obj[field] == compare_value
        else
          fail "#{operator} comparison not supported by MapPLZ on arrays"
        end
        break unless is_valid
      end
      is_valid
    end
  end
end
