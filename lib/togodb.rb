require 'fileutils'

module Togodb
  mattr_accessor :plugin_dir
  self.plugin_dir = File.dirname(__FILE__) + "/.."

  class ExpectedError < RuntimeError; end
  class ServiceUnavailable < ExpectedError; end
  class Forbidden < ExpectedError; end

  ######################################################################
  ### Migration

  def self.migrate
    # actual models
    migrate_for Togodb::Table
    migrate_for Togodb::Through
    migrate_for Togodb::Column
    migrate_for Togodb::Setting
    migrate_for Togodb::Syslog
    migrate_for Togodb::User
    migrate_for Togodb::Role

    # for migration purpose
    migrate_for Togodb::Migrations::OpenIdAuthenticationAssociation
    migrate_for Togodb::Migrations::OpenIdAuthenticationNonce

    # metadata
    migrate_for Togodb::Metadata
    migrate_for Togodb::Organization
    migrate_for Togodb::DatabaseClass
    migrate_for Togodb::MetadataDbclass
    migrate_for Togodb::Taxonomy
    migrate_for Togodb::Licence
    migrate_for Togodb::Literature
    migrate_for Togodb::NcbiTaxonomy
  end

  def self.migrate_for(klass)
    klass.migrate :strict
  rescue
    raise "could not create '%s' table in your database. check config/database.yml" % klass.table_name
  end

  ######################################################################
  ### Mirror

  def self.mirror(dir)
    source_dir = File.join(File.dirname(__FILE__), '..', 'mirror', dir)
    target_dir = File.join(RAILS_ROOT, dir)
    FileUtils.mkdir_p(target_dir) unless File.exist?(target_dir)

    Dir[source_dir + "/*"].each do |src|
      time = File.mtime(src)
      file = File.basename(src)
      dst  = File.join(target_dir, file)

      next if File.directory?(src)
      next if File.exist?(dst) and File.mtime(dst) >= time
      FileUtils.copy(src, dst)
      File.utime(time, time, dst)
      command = File.exist?(dst) ? "update" : "install"
      logger.debug "#{command}: #{dir}/#{file}"
    end
  end

  ######################################################################
  ### Logger and Syslog

  def self.logger
    ActiveRecord::Base.logger
  end

  def self.syslog(*args)
    Togodb::Syslog.write(*args)
  end

  def self.syslog!(*args)
    Togodb::Syslog.write!(*args)
  end

  def self.cleanpath(path)
    regexp = /^\s*(\#\{RAILS_ROOT\}|#{Regexp.escape RAILS_ROOT}|#{Regexp.escape Pathname(RAILS_ROOT).cleanpath})\/?/m
    path.to_s.gsub(regexp, '').gsub(/^\s*$/m, '')
  end

  def self.pretty_error_message(error)
    where = cleanpath(error.backtrace.join("\n")).split(/\n/).select{|line| not %r{^vendor/rails} === line.to_s}.first rescue '???'
    "%s\n%s" % [error.message, where]
  end

  def self.action_error(error, params)
    message  = pretty_error_message(error)
    priority = 10
    group    = "%s#%s" % [params[:controller], params[:action]]

    syslog(message, priority, group)
    logger.debug error.message.to_s
    logger.debug error.backtrace.join("\n")
  end
end

