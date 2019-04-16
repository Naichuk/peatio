module Ethereum1
  class Blockchain < Peatio::Blockchain::Abstract

    class MissingSettingError < StandardError
      def initialize(key = '')
        super "#{key.capitalize} setting is missing"
      end
    end

    DEFAULT_FEATURES = { case_sensitive: false, supports_cash_addr_format: false }.freeze

    def initialize(custom_features = {})
      @features = DEFAULT_FEATURES.merge(custom_features).slice(*SUPPORTED_FEATURES)
      @settings = {}
    end

    def configure(settings = {})
      @settings.merge!(settings.slice(*SUPPORTED_SETTINGS))
    end

    def fetch_block!(block_number)
      block_json = client.json_rpc(:eth_getBlockByNumber, ["0x#{block_number.to_s(16)}", true])

      if block_json.blank? || block_json['transactions'].blank?
        Rails.logger.info { "Skipped processing #{block_number}" }
        return
      end

      block_json.fetch('transactions').each_with_object([]) do |tx, block|
        binding.pry
        if tx.fetch('input').hex <= 0
          next if client.invalid_eth_transaction?(tx)
        else
          # tx = client.get_txn_receipt(tx.fetch('hash'))
          tx = client.json_rpc(:eth_getTransactionReceipt, [normalize_txid(tx.fetch('hash'))])
          next if tx.nil? || client.invalid_erc20_transaction?(tx)
        end
        normalized_tx = build_transaction(tx).megre(block_number: block_number)
        block << Peatio::Transaction.new(normalized_tx)
      end.yield_self { |block_arr| Peatio::Block.new(block_number, block_arr) }
    end

    def latest_block_number
      client.json_rpc(:eth_blockNumber)
    end

    # @deprecated
    def supports_cash_addr_format?
      @features[:supports_cash_addr_format]
    end

    private

    def client
      @client ||= Ethereum1::Client.new(settings_fetch(:server))
    end

    def settings_fetch(key)
      @settings.fetch(key) { raise MissingSettingError(key.to_s) }
    end

    def normalize_txid(txid)
      txid.try(:downcase)
    end

    def build_transaction(tx_hash)
      if tx_hash.has_key?('logs')
        build_erc20_transaction(txn)
      else
        build_eth_transaction(txn)
      end
    end
  end
end
