module Peatio
  module Monero
    module Hooks
      class << self
        def check_compatibility
          if Peatio::Blockchain::VERSION >= '2.0'
            [
                "Monero plugin was designed for work with 1.x. Blockchain.",
                "You use #{Peatio::Blockchain::VERSION}."
            ].join('\n').tap { |s| Kernel.abort s }
          end

          if Peatio::Wallet::VERSION >= '2.0'
            [
                "Monero plugin was designed for work with 1.x. Wallet.",
                "You use #{Peatio::Wallet::VERSION}."
            ].join('\n').tap { |s| Kernel.abort s }
          end
        end

        def register
          Peatio::Blockchain.registry[:monero] = Monero::Blockchain.new
          Peatio::Wallet.registry[:monerod] = Monero::Wallet.new
        end
      end

      if defined?(Rails::Railtie)
        require "peatio/monero/railtie"
      else
        check_compatibility
        register
      end
    end
  end
end
