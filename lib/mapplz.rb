# Encoding: utf-8

require 'sql_parser'

# MapPLZ datastore
class MapPLZ
  def initialize
    @db_type = 'array'
    @parser = SqlParser.new
    @my_array = []
  end

  def <<(user_geo)
    geo_object = standardize_geo(user_geo)
    @my_array << geo_object
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

  def standardize_geo(user_geo)
    if user_geo.is_a?(Array)
      {
        lat: user_geo[0].to_f,
        lng: user_geo[1].to_f,
        properties: user_geo.drop(2)
      }
    elsif user_geo.is_a?(Hash)

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
