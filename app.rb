require "sinatra"
require "sinatra/reloader" if development?
require "pry-byebug"
require "better_errors"
require 'fileutils'
require 'csv'
set :bind, '0.0.0.0'

configure :development do
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end

get '/' do
  erb :index
end

post '/temp' do
  FileUtils.rm_rf(Dir['./temp/*'])

  @filename = params[:file][:filename]
  file = params[:file][:tempfile]

  # parsing the csv
  csv_options = { col_sep: ',', quote_char: '"', headers: :first_row }
  csv_data = CSV.read(file)
  amplitude = csv_data[1][0].include? "Amplitude"
  if amplitude
    headers = csv_data[5]
    csv_data.shift(6)
  else
    headers = csv_data.shift
  end
  cohort_size = 0

  # getting absolute values to percents
  string_data = csv_data.map do |row|

    row.map.with_index do |cell, i|
      if amplitude
        if i == 0 || i == 1 then
          cell.to_s
        elsif i == 2 then
          cell.to_i
          cohort_size = cell.to_i
        else
          (cell.to_f/cohort_size*100).round(2)
        end
      else
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

  end
  # Final hash converted from csv
  print array_of_hashes = string_data.map {|row| Hash[*headers.zip(row).flatten] }
  array_of_hashes = array_of_hashes.reverse if amplitude
  # Getting all the nils as 0
  array_of_hashes.map {|h| h.each{|k,v| h[k] = 0 unless v}}
  # Filling the weighted average hash with the right key/value skeleton
  weighted_average = array_of_hashes[0].clone

  # Computing the weighted average
  if amplitude
    segment_key = "Segment"
    start_date_key="Start Date"
    cohort_size_key="Users"
  else
    start_date_key="start date"
    cohort_size_key="cohort size"
  end

  weighted_average.each do |key, value|
    # setting variables
    week = key
    count_line = 0
    sum = 0
    product = 0
    # counting how much cohorts there is in a week
      array_of_hashes.each {|line| count_line += 1 if line[week] != 0}
    # Filling the two/three firsts columns
    if key == segment_key
      weighted_average[key] = ""
    elsif key == start_date_key
      weighted_average[key] = "All time"
    elsif key == cohort_size_key
      weighted_average[key] = 1
    # gathering the sum.prod and sum of weights
    else
      array_of_hashes.each_with_index do |line, index|
    # do not take last 2 values into account
        if line[week] == 0 or index >= count_line - 2
          puts "#{index}" + week
          sum = sum
          product = product
        elsif line[week] != 0
          sum += line[cohort_size_key]
          product += line[week]*line[cohort_size_key]
        end
      # computing the weighted average
      weighted_average[key] = (product.to_f/sum.to_f).round(2)/100
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
  send_file("./temp/#{new_file_name}", :filename => "#{new_file_name}", :type => 'Application/octet-stream')
end

