module Bench
  class ActiveRecord
    def initialize(config)
      @config = config
    end

    def benchmark!
      @start = Time.now
      @config[:number].times do |_|
        ::Order.where("id > 20", 10).load
      end

      @finish = Time.now
      return execution_time = @finish - @start
    end
  end
end