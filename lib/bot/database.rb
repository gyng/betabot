class Bot::Database
  require 'fileutils'
  require 'sequel'
  require 'sqlite3'

  attr_reader :db, :path

  def initialize(path)
    @path = path
    FileUtils.mkdir_p(File.dirname(path)) unless File.directory?(File.dirname(path))
    @db = Sequel.sqlite(path)
  end

  def method_missing(m, *args, &block)
    @db.send(m, *args, &block)
  rescue => e
    Bot.log.error "Bot::Database - #{@path}: #{e}\n#{e.backtrace.join("\n")}"
  end
end