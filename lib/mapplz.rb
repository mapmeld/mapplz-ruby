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

  # alias methods

  # aliases for count
  def size(where_clause = nil, add_on = nil)
    count(where_clause, add_on)
  end

  def length(where_clause = nil, add_on = nil)
    count(where_clause, add_on)
  end

  private

  def standardize_geo(user_geo)
    geo_objects = []

    if user_geo.is_a?(String)
      user_geo = JSON.parse(user_geo)
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
