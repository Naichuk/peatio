module Bench
  class Mysql
    def initialize(config)
      @config = config
      @client = ::Mysql2::Client.new(
          :host => ENV.fetch('DATABASE_HOST', '127.0.0.1'),
          :username => ENV.fetch('DATABASE_USER', 'root'),
          :port => 3306,
          :password => ENV['DATABASE_PASS'],
          :database => ENV.fetch('DATABASE_NAME', 'peatio_development')
      )
    end

    def benchmark!
      p 'Start!'
      @start = Time.now
      @config[:number].times do |i|
        @client.query("SELECT * FROM `orders`")
      end

      @finish = Time.now
      @execution_time = @finish - @start
    end
  end
end