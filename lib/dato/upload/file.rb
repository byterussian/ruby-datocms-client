# frozen_string_literal: true

require 'fastimage'
require 'tempfile'
require 'addressable'
require 'net/http'

module Dato
  module Upload
    class File
      IMAGE_FORMATS = %w[png jpg jpeg gif].freeze

      attr_reader :client, :source

      def initialize(client, source)
        @client = client
        @source = source
      end

      def file
        @file ||= if http_source?
                    uri = Addressable::URI.parse(source)
                    ext = ::File.extname(uri.path).downcase
                    tempfile = Tempfile.new(['file', ext])
                    tempfile.binmode
                    tempfile.write(download_file(source))
                    tempfile.rewind
                    tempfile
                  else
                    ::File.new(::File.expand_path(source))
                  end
      end

      def http_source?
        uri = Addressable::URI.parse(source)
        uri.scheme == 'http' || uri.scheme == 'https'
      rescue Addressable::URI::InvalidURIError
        false
      end

      def filename
        if http_source?
          ::File.basename(source)
        else
          ::File.basename(file.path)
        end
      end

      def upload
        upload_request = client.upload_request.create(filename: filename)
        uri = URI.parse(upload_request[:url])

        request = Net::HTTP::Put.new(
          uri,
          'x-amz-acl' => 'public-read'
        )
        request.body = file.read

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        http.request(request)

        uploads = client.uploads.create(
          format_resource(upload_request)
        )

        uploads['id']
      end

      def download_file(url)
        connection = Faraday.new do |c|
          c.response :raise_error
          c.use FaradayMiddleware::FollowRedirects
          c.adapter :net_http
        end
        connection.get(url).body
      rescue Faraday::Error => e
        puts "Error during uploading #{url}"
        raise e
      end

      def format_resource(upload_request)
        extension = FastImage.type(file.path).to_s
        if extension.empty?
          extension = ::File.extname(::File.basename(file.path)).delete('.').downcase
        end

        raise FastImage::UnknownImageType if extension.empty?

        base_format = {
          path: upload_request[:id],
          size: ::File.size(file.path),
          format: extension
        }
        if IMAGE_FORMATS.include?(extension)
          width, height = FastImage.size(file.path)
          base_format = base_format.merge(
            width: width,
            height: height
          )
        end
        base_format
      end
    end
  end
end
