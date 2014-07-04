# Encoding: utf-8

require 'sql_parser'
require 'json'
include Leaflet::ViewHelpers

# MapPLZ datastore
class MapPLZ
  DATABASES = %w(array postgres postgresql postgis sqlite spatialite mongodb)

  def initialize
    @db_type = 'array'
    @parser = SqlParser.new
    @my_array = []

    choose_db(ActiveRecord::Base.connection.adapter_name) if defined?(ActiveRecord)
  end

  def choose_db(db)
    db.downcase!
    fail 'Database type not supported by MapPLZ' unless DATABASES.include?(db)
    db = 'postgis' if db == 'postgres' || db == 'postgresql'
    db = 'spatialite' if db == 'sqlite'
    @db_type = db
  end

  def add(user_geo, lonlat = false)
    geo_objects = standardize_geo(user_geo, lonlat)
    @my_array += geo_objects

    if geo_objects.length == 1
      geo_objects[0]
    else
      geo_objects
    end
  end

  def count(where_clause = nil, add_on = nil)
    results = query(where_clause, add_on)
    if @db_type == 'array'
      results.length
    else
      results.count
    end
  end

  def query(where_clause, add_on = nil)
    if where_clause.present?
      if @db_type == 'array'
        query_array(where_clause, add_on)
      else
        # @my_db.where(where_clause, add_on)
      end
    else
      # count all
      if @db_type == 'array'
        @my_array
      else
        # @my_db.all
      end
    end
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
    feature_list = []
    if @db_type == 'array'
      @my_array.each do |feature|
        feature_list << as_geojson(feature)
      end
    end
    geojson = { type: 'FeatureCollection', features: feature_list }
    geojson.to_json
  end

  def render_html(options = {})
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

    render_text = map(options)

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

      if feature['geometry']['type'] == 'Polyline'
        render_text += ('line = L.polyline(' + flip_coordinates.to_json + ", #{path_options.to_json}).addTo(map);\n").html_safe
        render_text += "line.bindPopup('#{label}');\n".html_safe unless label.nil?
      elsif feature['geometry']['type'] == 'Polygon'
        render_text += ('polygon = L.polygon(' + flip_coordinates[0].to_json + ", #{path_options.to_json}).addTo(map);\n").html_safe
        render_text += "polygon.bindPopup('#{label}');\n".html_safe unless label.nil?
      end

      render_text
    end

    render_text
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
  def where(where_clause, add_on = nil)
    query(where_clause, add_on)
  end

  # aliases for count
  def size(where_clause = nil, add_on = nil)
    count(where_clause, add_on)
  end

  def length(where_clause = nil, add_on = nil)
    count(where_clause, add_on)
  end

  # aliases for render_html
  def embed_html(options = {})
    render_html(options)
  end

  private

  # internal map object record
  class GeoItem < Hash
    def initialize(db)
      @db_type = db
    end

    def save!
      # update record in database
      unless @db_type == 'array'
      end
    end

    def delete_item
      if @db_type == 'array'
        keys.each do |key|
          delete(key)
        end
      else
        # update record in database
      end
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
          geoitem = GeoItem.new(@db_type)
          geoitem[:lat] = @code_latlngs[0][0]
          geoitem[:lng] = @code_latlngs[0][1]
          geoitem[:label] = @code_label || ''

          @code_layers << geoitem
        elsif @code_level == 'line'
          geoitem = GeoItem.new(@db_type)
          geoitem[:path] = @code_latlngs
          geoitem[:stroke_color] = (@code_color || '')
          geoitem[:label] = @code_label || ''

          @code_layers << geoitem
        elsif @code_level == 'shape'
          geoitem = GeoItem.new(@db_type)
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

  def standardize_geo(user_geo, lonlat = false)
    geo_objects = []

    if user_geo.is_a?(String)
      begin
        user_geo = JSON.parse(user_geo)
      rescue
        # not JSON string - attempt mapplz parse
        return code(user_geo)
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
            else
              geo_type = 'polyline'
            end

            geoitem = GeoItem.new(@db_type)
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
          geo_objects += standardize_geo(geo_piece)
        end
        return geo_objects
      end

      # first two spots are a coordinate
      validate_lat = user_geo[0].to_f != 0 || user_geo[0].to_s == '0'
      validate_lng = user_geo[1].to_f != 0 || user_geo[1].to_s == '0'

      if validate_lat && validate_lng
        geo_object = GeoItem.new(@db_type)
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

      # only one property and it's a hash? it's a hash of properties
      if user_properties.length == 1 && user_properties[0].is_a?(Hash)
        user_properties[0].keys.each do |key|
          geo_object[key.to_sym] = user_properties[0][key]
        end
      else
        geo_object[:properties] = user_properties
      end

      geo_objects << geo_object

    elsif user_geo.is_a?(Hash)
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
        geo_object = GeoItem.new(@db_type)
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
        else
          geo_type = 'polyline'
        end

        geoitem = GeoItem.new(@db_type)
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
      else
        # try GeoJSON
        if user_geo.key?('type')
          if user_geo['type'] == 'FeatureCollection' && user_geo.key?('features')
            # recursive onto features
            user_geo['features'].each do |feature|
              geo_objects += standardize_geo(feature)
            end
          elsif user_geo.key?('geometry') && user_geo['geometry'].key?('coordinates')
            # individual feature
            geo_object = GeoItem.new(@db_type)
            coordinates = user_geo['geometry']['coordinates']
            if user_geo.key?('properties')
              user_geo['properties'].keys.each do |key|
                geo_object[key.to_sym] = user_geo['properties'][key]
              end
            end

            if user_geo['geometry']['type'] == 'Point'
              geo_object[:lat] = coordinates[1].to_f
              geo_object[:lng] = coordinates[0].to_f
              geo_object[:type] = 'point'
            end

            geo_objects << geo_object
          end
        elsif user_geo.key?(:type)
          if user_geo[:type] == 'FeatureCollection' && user_geo.key?(:features)
            # recursive onto features
            user_geo[:features].each do |feature|
              geo_objects += standardize_geo(feature)
            end
          elsif user_geo.key?(:geometry) && user_geo[:geometry].key?(:coordinates)
            # individual feature
            geo_object = GeoItem.new(@db_type)
            coordinates = user_geo[:geometry][:coordinates]
            if user_geo.key?(:properties)
              user_geo[:properties].keys.each do |key|
                geo_object[key.to_sym] = user_geo[:properties][key]
              end
            end

            if user_geo[:geometry][:type] == 'Point'
              geo_object[:lat] = coordinates[1].to_f
              geo_object[:lng] = coordinates[0].to_f
              geo_object[:type] = 'point'
            end

            geo_objects << geo_object
          end
        end
      end
    end

    geo_objects
  end

  def as_geojson(geo_object)
    if geo_object.key?(:properties)
      property_list = { properties: geo_object[:properties] }
    else
      property_list = geo_object.clone
      property_list.delete(:lat)
      property_list.delete(:lng)
      property_list.delete(:path)
    end

    output_geo = {
      type: 'Feature',
      properties: property_list
    }

    if geo_object[:type] == 'point'
      # point
      output_geo[:geometry] = {
        type: 'Point',
        coordinates: [geo_object[:lng], geo_object[:lat]]
      }
    elsif geo_object[:type] == 'polyline'
      # line
      output_geo[:geometry] = {
        type: 'Polyline',
        coordinates: flip_path(geo_object[:path])
      }
    elsif geo_object[:type] == 'polygon'
      # polygon
      output_geo[:geometry] = {
        type: 'Polygon',
        coordinates: [flip_path(geo_object[:path])]
      }
    end
    output_geo
  end

  def flip_path(path)
    path.map! do |pt|
      pt.reverse
    end
  end

  def query_array(where_clause, add_on = nil)
    # prepare where clause for parse
    where_clause.downcase! unless where_clause.blank?
    where_clause = where_clause.gsub('?', '\'?\'') if add_on.present?
    where_clause = 'select * from bogus_table where ' + where_clause

    # parse where conditions
    conditions = @parser.parse(where_clause).tree[:conditions]

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
