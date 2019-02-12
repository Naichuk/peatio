# encoding: UTF-8
# frozen_string_literal: true

require_relative '../validations'

module API
  module V2
    module Account
      class Deposits < Grape::API
        helpers API::V2::NamedParams

        before { deposits_must_be_permitted! }

        desc 'Get your deposits history.',
          is_array: true,
          success: API::V2::Entities::Deposit

        params do
          optional :currency,
                   type: { value: String, message: 'account.deposit.non_string_currency' },
                   values: { value: -> { Currency.enabled.codes(bothcase: true) }, message: 'account.deposit.invalid_currency' },
                   desc: -> { "Currency value contains #{Currency.enabled.codes(bothcase: true).join(',')}" }
          optional :state,
                   type: { value: String, message: 'account.deposit.non_string_state' },
                   values: { value: -> { Deposit::STATES.map(&:to_s) }, message: 'account.deposit.invalid_state' }
          optional :limit,
                   type: { value: Integer, message: 'account.deposit.non_integer_limit' },
                   default: 100,
                   values: { value: 1..100, message: 'account.deposit.invalid_limit' },
                   desc: "Number of deposits per page (defaults to 100, maximum is 100)."
          optional :page,
                   type: { value: Integer, message: 'account.deposit.non_integer_page' },
                   default: 1,
                   values: { value: -> (p){ p.try(:positive?) }, message: 'account.deposit.negative_page'},
                   desc: 'Page number (defaults to 1).'
        end
        get "/deposits" do
          currency = Currency.find(params[:currency]) if params[:currency].present?

          current_user.deposits.order(id: :desc)
                      .tap { |q| q.where!(currency: currency) if currency }
                      .tap { |q| q.where!(aasm_state: params[:state]) if params[:state] }
                      .tap { |q| present paginate(q), with: API::V2::Entities::Deposit }
        end

        desc 'Get details of specific deposit.' do
          success API::V2::Entities::Deposit
        end
        params do
          requires :txid,
                   type: { value: String, message: 'account.deposit.non_string_txid' },
                   desc: "Deposit transaction id"
        end
        get "/deposits/:txid" do
          deposit = current_user.deposits.find_by(txid: params[:txid])
          raise DepositByTxidNotFoundError, params[:txid] unless deposit

          present deposit, with: API::V2::Entities::Deposit
        end

        desc 'Returns deposit address for account you want to deposit to by currency. ' \
          'The address may be blank because address generation process is still in progress. ' \
          'If this case you should try again later.',
          success: API::V2::Entities::Deposit
        params do
          requires :currency,
                   type: { value: String, message: 'account.deposit_address.non_string_currency' },
                   values: { value: -> { Currency.coins.enabled.codes(bothcase: true) }, message: 'account.deposit_address.invalid_currency'},
                   desc: 'The account you want to deposit to.'
          given :currency do
            optional :address_format,
                     type: { value: String, message: 'account.deposit_address.non_string_address_format' },
                     values: { value: -> { %w[legacy cash] }, message: 'account.deposit_address.invalid_address_format' },
                     validate_currency_address_format: true,
                     desc: 'Address format legacy/cash'
          end
        end
        get '/deposit_address/:currency' do
          current_user.ac(params[:currency]).payment_address.yield_self do |pa|
            { currency: params[:currency], address: params[:address_format] ? pa.format_address(params[:address_format]) : pa.address }
          end
        end
      end
    end
  end
end
