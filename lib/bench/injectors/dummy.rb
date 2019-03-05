require_relative '../injectors'

module Bench
  module Injectors
    class Dummy < Base

      def initialize(config)
        super
        config.reverse_merge!(default_config)
        %i[min_volume max_volume min_price max_price].each do |var|
          instance_variable_set(:"@#{var}", config[var])
        end
      end
    end
  end
end
