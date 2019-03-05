module Bench
  module Injectors
    autoload :Dummy, 'bench/injectors/dummy'

    class << self
      # TODO: Rename.
      def initialize_injector(config)
        "#{self.name}/#{config[:injector]}"
          .camelize
          .constantize
          .new(config)
      end
    end

    class Base
      extend Memoist
      attr_reader :config

      def initialize(config)
        @config = config
        @number = config[:number].to_i
        @markets = ::Market.where(id: config[:markets].split(',').map(&:squish).reject(&:blank?))
      end

      def generate!(members = nil)
        @members = members || Member.all
        @queue = Queue.new
        ActiveRecord::Base.transaction do
          Array.new(@number) do
            create_order.tap { |o| @queue << o }
          end
        end
      end

      def pop
        @queue.empty? ? nil : @queue.pop
      end

      def size
        @queue.size
      end
      
      private

      def create_order
        Order.new(construct_order)
             .tap(&:fix_number_precision)
             .tap { |o| o.locked = o.origin_locked = o.compute_locked }
             .tap { |o| o.hold_account!.lock_funds(o.locked) }
             .tap(&:save)
      end

      def construct_order
        market = @markets.sample
        type = %w[OrderBid OrderAsk].sample
        { type:     type,
          state:    Order::WAIT,
          member:   @members.sample,
          market:   market,
          ask:      market.base_unit,
          bid:      market.quote_unit,
          ord_type: :limit,
          price:    rand(@min_price..@max_price),
          volume:   rand(@min_volume..@max_volume) }
      end
      
      def default_config
        { min_volume: 0.1,
          max_volume: 1,
          min_price:  0.5,
          max_price:  2 }
      end
      memoize :default_config
    end
  end
end

