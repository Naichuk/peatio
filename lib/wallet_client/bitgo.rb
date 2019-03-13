# encoding: UTF-8
# frozen_string_literal: true

module WalletClient
  class Bitgo < Base

    def initialize(*)
      super
      currency_code_prefix = wallet.bitgo_test_net ? 't' : ''
      @endpoint            = wallet.bitgo_rest_api_root.gsub(/\/+\z/, '') + '/' + currency_code_prefix + wallet.currency.code
      @access_token        = wallet.bitgo_rest_api_access_token
    end

    def create_address!(options = {})
      if options[:address_id].present?
        path = '/wallet/' + urlsafe_wallet_id + '/address/' + escape_path_component(options[:address_id])
        rest_api(:get, path).slice('address').symbolize_keys
      else
        response = rest_api(:post, '/wallet/' + urlsafe_wallet_id + '/address', options.slice(:label))
        address  = response['address']
        { address: address.present? ? normalize_address(address) : nil, bitgo_address_id: response['id'] }
      end
    end

    def create_withdrawal!(issuer, recipient, amount, options = {})
      fee = options.key?(:fee) ? convert_to_base_unit!(options[:fee]) : nil
      rest_api(:post, '/wallet/' + urlsafe_wallet_id + '/sendcoins', {
          address:          normalize_address(recipient.fetch(:address)),
          amount:           convert_to_base_unit!(amount).to_s,
          feeRate:          fee,
          walletPassphrase: bitgo_wallet_passphrase
      }.compact).fetch('txid').yield_self(&method(:normalize_txid))
    end

    def build_raw_transaction(recipient, amount)
      rest_api(:post, '/wallet/' + urlsafe_wallet_id + '/tx/build', {
          recipients: [{address: normalize_address(recipient.fetch(:address)), amount: convert_to_base_unit!(amount).to_s }]
      }.compact, false).fetch('feeInfo').fetch('fee').yield_self(&method(:convert_from_base_unit))
    end

    def inspect_address!(address)
      { address: normalize_address(address), is_valid: :unsupported }
    end

    # Note: bitgo doesn't accept cash address format
    def normalize_address(address)
      wallet.blockchain_api&.supports_cash_addr_format? ? CashAddr::Converter.to_legacy_address(super) : super
    end

    def load_balance!(_address, _currency)
      convert_from_base_unit(wallet_details(true).fetch('balanceString'))
    end

    def each_deposit!(options = {})
      each_batch_of_deposits do |deposits|
        deposits.each { |deposit| yield deposit }
      end
    end

    def each_deposit(options = {})
      each_batch_of_deposits false do |deposits|
        deposits.each { |deposit| yield deposit }
      end
    end

    def build_deposit(tx)
      entries = build_deposit_entries(tx)
      return if entries.blank?
      binding.pry
      { txid:          normalize_txid(tx.fetch('txid')),
        address:       entries.fetch(:address),
        block_number:  tx.fetch('height').to_i,
        amount:        entries.fetch(:amount),
        member:        entries.fetch(:member),
        currency:      entries.fetch(:currency),
        received_at:   Time.parse(tx.fetch('date')) }
    end

    def build_deposit_entries(tx)
      tx.fetch('entries').each do |entry|
        payment_addresses_where(address: entry['address']) do |payment_address|
          binding.pry
          next unless entry['wallet'] == wallet_id
          next unless entry['valueString'].to_d > 0
          next unless tx.fetch('type') != 'recieve'
          next if entry.key?('outputs') && entry['outputs'] != 1
          return { amount:  convert_from_base_unit(entry.fetch('valueString')),
          currency: wallet.currency,
          member:  payment_address.account.member,
          address: normalize_address(entry.fetch('address')) }.compact
        end
      end
    end

    def each_batch_of_deposits(raise = true)
      next_batch_ref = nil
      collected      = []
      loop do
        begin
          batch_deposits = nil
          query          = { limit: 100, prevId: next_batch_ref }
          response       = rest_api(:get, '/wallet/' + urlsafe_wallet_id + '/transfer', query)
          next_batch_ref = response['nextBatchPrevId']
          batch_deposits = response.fetch('transfers')
                                   .map { |tx| build_deposit(tx) }
                                   .compact
        rescue => e
          report_exception(e)
          raise e if raise
        end
        yield batch_deposits if batch_deposits
        collected += batch_deposits
        break if next_batch_ref.blank?
      end
      collected
    end

    def rest_api(verb, path, data = nil, raise_error = true)
      args = [@endpoint + path]

      if data
        if verb.in?(%i[ post put patch ])
          args << data.compact.to_json
          args << { 'Content-Type' => 'application/json' }
        else
          args << data.compact
          args << {}
        end
      else
        args << nil
        args << {}
      end

      args.last['Accept']        = 'application/json'
      args.last['Authorization'] = 'Bearer ' + @access_token

      response = Faraday.send(verb, *args)
      Rails.logger.debug { response.describe }
      response.assert_success! if raise_error
      JSON.parse(response.body)
    end

    def wallet_details(_state)
      rest_api(:get, '/wallet/' + urlsafe_wallet_id)
    end

    def urlsafe_wallet_address
      CGI.escape(normalize_address(wallet.address))
    end

    def wallet_id
      wallet.bitgo_wallet_id
    end

    def bitgo_wallet_passphrase
      wallet.bitgo_wallet_passphrase
    end

    def urlsafe_wallet_id
      escape_path_component(wallet_id)
    end

    def escape_path_component(id)
      CGI.escape(id)
    end

  end
end
