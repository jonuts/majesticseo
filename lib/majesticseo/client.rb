module Majesticseo
=begin rdoc
  Please refer to the Majesticseo developer documentation for information regarding API methods: http://developer-support.Majesticseo.com/

  =Example
    maj = Majesticseo::Client.new(:app_api_key => "BLAH")
    maj.get_subscription_info
    if maj.success?
      puts maj.global_vars.max_bulk_backlinks_check
      => 120
      puts maj.data_tables.first.rows.first.index_item_info_res_units
      => 99992
    else
      puts maj.response
      puts maj.error_message
    end
=end
  class Client
    BASE_URI = "http://%s.majesticseo.com/api_command" unless
      self.const_defined?(:BASE_URI)

    attr_reader   :app_api_key, :env, :uri, :response
    attr_accessor :code, :error_message, :full_error, :data_tables, :global_vars
=begin rdoc
  Initialize a Majestic SEO aPI client passing the following options:
  app_api_key: You Majesticseo API key, found at: https://www.Majesticseo.com/account/api
  environment (optional): Default to RAILS_ENV, RACK_ENV or default. Determines whether the client uses the sandbox or production API server
=end
    def initialize(opts = {})
      @app_api_key = opts.delete(:app_api_key)
      @debug = opts.fetch(:debug, true)

      if !@app_api_key || @app_api_key.empty?
        msg = "API key needs to be a valid Majestic SEO API key. See: "\
              "https://www.Majesticseo.com/account/api"

        raise Majesticseo::InvalidAPIKey.new(msg)
      end

      if opts[:environment]
        @env = opts.delete(:environment)
      elsif defined?(RAILS_ENV)
        @env = RAILS_ENV
      elsif defined?(RACK_ENV)
        @env = RACK_ENV
      else
        @env = "development"
      end
      @response = nil
      @data_tables = []
      @global_vars = nil
      @uri = URI.parse(build_url)

      puts "Started Majesticseo::Client in #{env} mode"
    end

    def call method, params
      params = {} unless params.is_a? Hash
      request_uri = uri.clone
      request_uri.query = params.merge({
        :app_api_key => app_api_key,
        :cmd => method
      }).to_param

      @response = Nokogiri::XML(open(request_uri))

      # Set response and global variable attributes
      if response.at("Result")
        response.at("Result").keys.each do |a|
          send("#{a.underscore}=".to_sym, response.at("Result").attr(a))
        end
      end

      @global_vars = GlobalVars.new
      if response.at("GlobalVars")
        response.at("GlobalVars").keys.each do |a|
          @global_vars.send("#{a.underscore}=".to_sym, response.at("GlobalVars").attr(a)) 
        end
      end

      parse_data if success?
    end

    def method_missing(m, *args)
      call(m.to_s.camelize, args[0])
    end

    def parse_data
      @data_tables = @response.search("DataTable").map do |table|
        DataTable.create_from_xml(table)
      end
    end

    def success?
      code == "OK" and error_message == ""
    end

    def build_url
      subdomain = Hash.new("developer")
      subdomain[:production] = "enterprise"
      subdomain['production'] = "enterprise"

      BASE_URI % subdomain[env]
    end

    def puts(msg)
      Kernel.puts(msg) if debug?
    end

    def debug?
      @debug
    end
  end
end
