module Peatio
  module Monero
    class Wallet < Peatio::Wallet::Abstract

      def initialize(settings = {})
        @settings = settings
      end

      def configure(settings = {})
        # Clean client state during configure.
        @client = nil

        @settings.merge!(settings.slice(*SUPPORTED_SETTINGS))

        @wallet = @settings.fetch(:wallet) do
          raise Peatio::Wallet::MissingSettingError, :wallet
        end.slice(:uri, :address, :secret)

        @currency = @settings.fetch(:currency) do
          raise Peatio::Wallet::MissingSettingError, :currency
        end.slice(:id, :base_factor, :options)
      end

      def create_address!(options = {})
        params = { 'standard_address': @wallet[:address].to_s,
                   'payment_id': generate_payment_id(options) }

        address = client.json_rpc('json_rpc', 'make_integrated_address',
                                  params: params).fetch('integrated_address')
        { address: address }
      rescue Monero::Client::Error => e
        raise Peatio::Wallet::ClientError, e
      end

      def create_transaction!(transaction, options = {})
        params = { 'destinations': [{ 'address': transaction.to_address,
                                       'amount': convert_to_base_unit(transaction.amount)}] }
        params.merge!('payment_id': options[:payment_id]) if options[:payment_id].present?

        transaction.hash = client.json_rpc('json_rpc', 'transfer', params: params)
                                 .fetch('tx_hash')
        transaction
      rescue Monero::Client::Error => e
        raise Peatio::Wallet::ClientError, e
      end

      def load_balance!
        # Load only unlocked balance of wallet.
        convert_from_base_unit(client.json_rpc('json_rpc', 'get_balance',
                                               params: {'account_index': 0}).fetch('unlocked_balance', 0))

      rescue Monero::Client::Error => e
        raise Peatio::Wallet::ClientError, e
      end

      private

      def convert_to_base_unit(value)
        (@currency.fetch(:base_factor).to_d * value.to_d).to_i
      end

      def convert_from_base_unit(value)
        value.to_d / @currency.fetch(:base_factor).to_d
      end

      def generate_payment_id(options)
        Digest::SHA256.hexdigest(options[:uid] + Time.now.to_s)[0...16]
      end

      def client
        uri = @wallet.fetch(:uri) { raise Peatio::Wallet::MissingSettingError, :uri }
        @client ||= Client.new(uri)
      end
    end
  end
end
