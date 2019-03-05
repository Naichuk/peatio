require_relative '../injectors'

module Bench
  module Injectors
    class Bitfinex < Base
      extend Memoist

      def initialize(config)
        super
        config.reverse_merge!(default_config)
        if config[:data_load_path].present?
          @data = YAML.load_file(Rails.root.join(config[:data_load_path]))
        end
      end

      def generate!(members = nil)
        @members = members || Member.all
        @queue = Queue.new
        ActiveRecord::Base.transaction do
          @index = 0
          Array.new(@number) do
            create_order.tap { |o| @queue << o }
            @index += 1
          end
        end
      end

      private

      def construct_order
        @index = 0 if @data[@index].blank?
        order_data = @data[@index]
        price = order_data[1]
        amount = order_data[2]
        market = @markets.sample
        type = amount > 0 ? 'OrderBid' : 'OrderAsk'
        { type:       type,
          state:      Order::WAIT,
          member:     @members.sample,
          market:     market,
          ask:        market.base_unit,
          bid:        market.quote_unit,
          ord_type:   :limit,
          price:      price,
          volume:     amount.abs }
      end
    end
  end
end
