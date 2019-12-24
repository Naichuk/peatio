require 'execjs'

module Peatio
  module Monero
    class Blockchain < Peatio::Blockchain::Abstract

      DEFAULT_FEATURES = {case_sensitive: true, cash_addr_format: false}.freeze
      ONE = 1
      def initialize(custom_features = {})
        # @crypto is used to call the javascript methods.
        @crypto   = ExecJS.compile(File.read("#{File.expand_path('assets', __dir__)}/crypto.js"))
        @features = DEFAULT_FEATURES.merge(custom_features).slice(*SUPPORTED_FEATURES)
        @settings = {}
      end

      def configure(settings = {})
        # Clean client state during configure.
        @client = nil

        @settings.merge!(settings.slice(*SUPPORTED_SETTINGS))
      end

      def fetch_block!(block_number)
        (client.json_rpc('json_rpc', 'get_block',
                         params: {height: block_number}).fetch('tx_hashes', []))
          .each_with_object([]) do |tx, txs_array|
          tx_hash = client.json_rpc('get_transactions', nil,
                                            {txs_hashes: [tx], decode_as_json: true})
          if tx_hash.fetch('missed_tx', nil).nil?
            tx_hash = JSON.parse(tx_hash.fetch('txs_as_json')[0]).merge!(txid: tx)
          end

          binding.pry
          txs = build_transaction(tx_hash.symbolize_keys!).map do |ntx|
            ntx.merge!(block_number: block_number)
            Peatio::Transaction.new(ntx)
          end
          txs_array.append(*txs)
        end.yield_self {|txs_array| Peatio::Block.new(block_number, txs_array)}

      rescue => e
        if e.is_a?(Client::Error)
          raise Peatio::Blockchain::ClientError, e
        elsif e.is_a?(ExecJS::ProgramError)
          raise Peatio::Blockchain::Error, e
        else
          raise Error, e
        end
      end

      def latest_block_number
        # Latest block does not have any data.
        client.json_rpc('json_rpc', 'get_block_count')
              .fetch('count') - ONE
      rescue Client::Error => e
        raise Peatio::Blockchain::ClientError, e
      end

      # Method Not Implemented.
      def load_balance_of_address!(_address, _currency_id)
        # Monero Blockchain(Daemon RPC) does not provide any
        # method for fetching information of any Address.
      end

      private

      def build_transaction(txn)
        unless txn.fetch(:missed_tx, nil).nil?
          # Create failed withdraw.
          return build_invalid_transaction(txn)
        end

        settings_fetch(:currencies).each_with_object([]) do |currency, formatted_txs|
          payment_hash = decode_txn(txn, currency)
          amount, payment_id = payment_hash[0].fetch('amount'), payment_hash[0].fetch('paymentId') if payment_hash.count.positive?
          formatted_txs << {hash:         normalize_txid(txn.fetch(:txid)),
                            amount:       amount || 0,
                            to_address:   build_address(currency.dig(:options, :address),
                                                        payment_id),
                            txout:        0,
                            currency_id:  currency.fetch(:id),
                            status:       transaction_status(txn)}
        end
      end

      def build_invalid_transaction(txn)
        settings_fetch(:currencies).each_with_object([]) do |currency, invalid_txs|
          txn.fetch(:missed_tx).each do |tx|
            invalid_txs << { hash:         normalize_txid(tx),
                             currency_id:  currency.fetch(:id),
                             status:       transaction_status(txn)}
          end
        end
      end

      def transaction_status(txn_hash)
        txn_hash.fetch(:missed_tx, nil).nil? ? 'success' : 'failed'
      end

      def build_address(address, payment_id)
        return nil if payment_id.nil?

        # integrated_address method defined in crypto.js file.
        # required params is address and payment id
        @crypto.call('integrated_address', address, payment_id)
      end

      def decode_txn(txn, currency)
        # It checks transaction belongs to us.
        # checkTx is method is defined in crypto.js file.
        # @crypto.call('method_name', param_1, param_2,..)
        @crypto.call('checkTx', false, {'address':  currency.dig(:options, :address),
                                        'pvKey':    currency.dig(:options, :secret),
                                        'txhash':   {'transaction_data': txn},
                                        'txId':     txn.fetch(:txid)})
      end

      def normalize_txid(txid)
        txid.try(:downcase)
      end

      def client
        @client ||= Client.new(settings_fetch(:server))
      end

      def settings_fetch(key)
        @settings.fetch(key) { raise Peatio::Blockchain::MissingSettingError, key.to_s }
      end
    end
  end
end
