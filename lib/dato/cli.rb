# frozen_string_literal: true
require 'thor'
require 'dato/dump/runner'
require 'dato/dump/ssg_detector'
require 'dato/migrate_slugs/runner'
require 'dato/watch/site_change_watcher'
require 'listen'
require 'thread'

module Dato
  class Cli < Thor
    package_name 'DatoCMS'

    desc 'dump', 'dumps DatoCMS content into local files'
    option :config, default: 'dato.config.rb'
    option :token, default: ENV['DATO_API_TOKEN'], required: true
    option :watch, default: false, type: :boolean
    def dump
      config_file = File.expand_path(options[:config])
      watch_mode = options[:watch]

      client = Dato::Site::Client.new(
        options[:token],
        extra_headers: {
          'X-Reason' => 'dump',
          'X-SSG' => Dump::SsgDetector.new(Dir.pwd).detect
        }
      )

      if watch_mode
        site_id = client.request(:get, '/site')["data"]["id"]

        semaphore = Mutex.new

        semaphore.synchronize do
          Dump::Runner.new(config_file, client).run
        end

        Dato::Watch::SiteChangeWatcher.new(site_id).connect do
          semaphore.synchronize do
            Dump::Runner.new(config_file, client).run
          end
        end

        Listen.to(File.dirname(config_file), only: /#{Regexp.quote(File.basename(config_file))}/) do
          semaphore.synchronize do
            Dump::Runner.new(config_file, client).run
          end
        end.start

        sleep
      else
        Dump::Runner.new(config_file, client).run
      end
    end

    desc 'check', 'checks the presence of a DatoCMS token'
    def check
      exit 0 if ENV['DATO_API_TOKEN']

      say 'Site token is not specified!'
      token = ask "Please paste your DatoCMS site read-only API token:\n>"

      if !token || token.empty?
        puts 'Missing token'
        exit 1
      end

      File.open('.env', 'a') do |file|
        file.puts "DATO_API_TOKEN=#{token}"
      end

      say 'Token added to .env file.'

      exit 0
    end

    desc 'migrate-slugs', 'migrates a Site so that it uses slug fields'
    option :token, default: ENV['DATO_API_TOKEN'], required: true
    option :skip_id_prefix, type: :boolean
    def migrate_slugs
      client = Dato::Site::Client.new(
        options[:token],
        extra_headers: {
          'X-Reason' => 'migrate-slugs'
        }
      )

      MigrateSlugs::Runner.new(client, options[:skip_id_prefix]).run
    end
  end
end
