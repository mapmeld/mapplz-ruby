# Encoding: utf-8

require 'sql_parser'
require 'json'

# MapPLZ datastore
class MapPLZ
  def initialize
    @db_type = 'array'
    @parser = SqlParser.new
    @my_array = []
  end

  def <<(user_geo)
    geo_objects = standardize_geo(user_geo)
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

  def query(where_clause, add_on)
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
    @code_lines = mapplz_code.gsub("\r", "").split("\n")
    @code_level = 'toplevel'
    @buttonLayers = []
    @code_button = 0
    @code_layers = []
    @code_label = ''
    @code_color = nil
    code_line(0)
    return @code_layers
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

  # alias methods

  # aliases for count
  def size(where_clause = nil, add_on = nil)
    count(where_clause, add_on)
  end

  def length(where_clause = nil, add_on = nil)
    count(where_clause, add_on)
  end

  private

  def code_line(index)
    return if index >= @code_lines.length
    line = @code_lines[index].strip
    codeline = line.downcase.split(' ')

    if @code_level == 'toplevel'
      if line.index('map')
        @code_level = 'map'
      end
      return code_line(index + 1)

    elsif @code_level == 'map' || @code_level == 'button'
      if codeline.index('button') || codeline.index('btn')
        @code_level = 'button'
        @buttonLayers << { layers: [] }
        @code_button = @buttonLayers.length
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
          @code_layers << {
            lat: @code_latlngs[0][0],
            lng: @code_latlngs[0][1],
            label: @code_label || ''
          }
        elsif @code_level == 'line'
          @code_layers << {
            path: @code_latlngs,
            strokeColor: (@code_color || ''),
            label: @code_label || ''
          }
        elsif @code_level == 'shape'
          @code_layers << {
            paths: @code_latlngs,
            strokeColor: (@code_color || ''),
            fillColor: (@code_color || ''),
            label: @code_label || ''
          }
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
        @code_color = @code_color.gsub('#','')
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
      @code_label = @code_label[0..(@code_label.index('"')-1)]
    end

    # reading a latlng coordinate
    if line.index('[') && line.index(',') && line.index(']')
      sign = 1.0
      latlng = [ ]
      latlng_line = line.gsub('[','').gsub(']','').split(',').map! { |num| num.to_f }

      if latlng_line.length != 2
        return codeline(index + 1)
      end

      @code_latlngs << latlng_line

      return code_line(index + 1)
    end

    return code_line(index + 1)

  end

  def standardize_geo(user_geo)
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
        geo_object = {
          lat: user_geo[0].to_f,
          lng: user_geo[1].to_f
        }
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
        geo_object = {
          lat: user_geo[validate_lat].to_f,
          lng: user_geo[validate_lng].to_f
        }
        user_geo.keys.each do |key|
          next if key == validate_lat || key == validate_lng
          geo_object[key.to_sym] = user_geo[key]
        end
        geo_objects << geo_object
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
            geo_object = {}
            coordinates = user_geo['geometry']['coordinates']
            if user_geo.key?('properties')
              user_geo['properties'].keys.each do |key|
                geo_object[key.to_sym] = user_geo['properties'][key]
              end
            end

            if user_geo['geometry']['type'] == 'Point'
              geo_object[:lat] = coordinates[1].to_f
              geo_object[:lng] = coordinates[0].to_f
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
            geo_object = {}
            coordinates = user_geo[:geometry][:coordinates]
            if user_geo.key?(:properties)
              user_geo[:properties].keys.each do |key|
                geo_object[key.to_sym] = user_geo[:properties][key]
              end
            end

            if user_geo[:geometry][:type] == 'Point'
              geo_object[:lat] = coordinates[1].to_f
              geo_object[:lng] = coordinates[0].to_f
            end

            geo_objects << geo_object
          end
        end
      end
    end

    geo_objects
  end

  def as_geojson(geo_object)
    property_list = geo_object.clone
    property_list.delete(:lat)
    property_list.delete(:lng)
    if geo_object.key?(:properties)
      property_list = geo_object[:properties]
    end
    if geo_object.key?(:lat) && geo_object.key?(:lng)
      # point
      {
        type: 'Feature',
        geometry: {
          type: 'Point',
          coordinates: [geo_object[:lng], geo_object[:lat]]
        },
        properties: property_list
      }
    else
      # other geometry
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
