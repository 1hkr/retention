require "sinatra"
require "sinatra/reloader" if development?
require "pry-byebug"
require "better_errors"
require 'fileutils'
require 'csv'
configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end

get '/' do
  erb :index
end

post '/temp' do

  @filename = params[:file][:filename]
  file = params[:file][:tempfile]

  # parsing the csv
  csv_options = { col_sep: ',', quote_char: '"', headers: :first_row }
  csv_data = CSV.read(file)
  headers = csv_data.shift
  cohort_size = 0

  # getting absolute values to percents
  string_data = csv_data.map do |row|

    row.map.with_index do |cell, i|
      if i == 0 then
        cell.to_s
      elsif i == 1 then
        cell.to_i
        cohort_size = cell.to_i
      else
        (cell.to_f/cohort_size*100).round(2)
      end
    end

  end
  # Final hash converted from csv
  print array_of_hashes = string_data.map {|row| Hash[*headers.zip(row).flatten] }

  # Filling the weighted average hash with the right key/value skeleton
  weighted_average = array_of_hashes[0].clone

  # Computing the weighted average
  weighted_average.each do |key, value|
    # setting variables
    week = key
    sum = 0
    product = 0
    # Filling the two firsts columns
    if key == "start date"
      weighted_average[key] = "All time"
    elsif key == "cohort size"
      weighted_average[key] = 100
    # gathering the sum.prod and sum of weights
    else
      array_of_hashes.each do |line|
        if line[week] == 0 or sum > 0 and line[week] < (product/sum - (product/sum*0.5))
          sum = sum
          product = product
        elsif line[week] != 0
          sum += line["cohort size"]
          product += line[week]*line["cohort size"]
        end
      # computing the weighted average
      weighted_average[key] = (product.to_f/sum.to_f).round(2)
      end
    end
  end

  # Adding the weighted average line to the top of the array
  array_of_hashes.unshift(weighted_average)
  @csv = array_of_hashes

  # Creating a csv with the results
  new_file_name = @filename.slice(0.. @filename.length-4)+"transformed.csv"
  # File.delete(new_file_name) if File.exist?(new_file_name)
  File.new("./temp/"+new_file_name, "w")

  # Populating the csv
  CSV.open("./temp/"+new_file_name, 'wb', headers: array_of_hashes.first.keys) do |csv|
    csv << headers
    array_of_hashes.each do |h|
      csv << h.values
    end
  end

  # download file
  begin
  send_file("./temp/#{new_file_name}", :filename => "#{new_file_name}", :type => 'Application/octet-stream')
  ensure
  File.delete("./temp/#{new_file_name}")
  redirect '/transformed'
  end
end

  # delete file
get '/transformed' do
  erb :csv
end

