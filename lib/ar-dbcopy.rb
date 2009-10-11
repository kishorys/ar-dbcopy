#!/usr/bin/env ruby
#
# Simple script to copy data from one database to another.
# This script can be used to migrate from one Database system
# to another one, e.q. when the SQL dumps are not compatible.
# Database agnosticism is achieved by using ActiveRecord.
#
# The script just defines 2 connections, looks at the tables,
# creates ActiveRecord model classes on-the-fly and copies over
# the data.
#
# Configure the databases using the database.yml.example as a
# template (the format is the same as Rails's database.yml)
#
# Then, run the script. The script only copies data, not structure,
# so make sure that you created the schema  and all tables in
# the destination database already (use rake db:schema:load)
#
require "rubygems"
require 'active_record'

class ARDBcopy
  class SourceDB < ActiveRecord::Base; end
  class TargetDB < ActiveRecord::Base; end

  def initialize(config_file)
    config = YAML.load_file(config_file)

    ActiveRecord::Base.logger ||= Logger.new(nil)

    SourceDB.establish_connection(config["source"])
    TargetDB.establish_connection(config["target"])

    @tables = SourceDB.connection.tables.reject { |m| m == "schema_migrations" }
  end

  def run
    @tables.each do |table_name|
      source_model = Class.new(SourceDB) do
        set_inheritance_column(:not_sti)
        set_table_name table_name
      end

      dest_model = Class.new(TargetDB) do
        set_inheritance_column(:not_sti)
        set_table_name table_name
      end

      dest_model.delete_all

      puts "Copying #{table_name} (#{source_model.count} instances)..."

      i = 0
      source_model.find_in_batches(:batch_size => 10_000) do |src_batch|
        dest_model.transaction do
          src_batch.each do |src_inst|
            dst_inst = dest_model.new(src_inst.attributes)
            dst_inst.id = src_inst.id
            dst_inst.save!
            i += 1
          end

          puts i
        end
      end
    end
  end
end

if __FILE__ == $0

  ARDBcopy.new(ARGV[0]).run
end
