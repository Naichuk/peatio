# encoding: UTF-8
# frozen_string_literal: true

require_dependency 'admin/withdraws/base_controller'

module Admin
  module Withdraws
    class FiatsController < BaseController
      before_action :find_withdraw, only: [:show, :update, :destroy]

      def index
        @latest_withdraws  = ::Withdraws::Fiat.where(currency: currency)
                                              .where('created_at <= ?', 1.day.ago)
                                              .order(id: :desc)
                                              .includes(:member, :currency)
        @all_withdraws     = ::Withdraws::Fiat.where(currency: currency)
                                              .where('created_at > ?', 1.day.ago)
                                              .order(id: :desc)
                                              .includes(:member, :currency)
      end

      def show

      end

      def update
        @withdraw.transaction do
          @withdraw.accept!
          @withdraw.process!
          @withdraw.dispatch!
          @withdraw.success!
        end
        redirect_to admin_withdraw_path(currency.id, @withdraw.id)
      end

      def destroy
        @withdraw.reject!
        redirect_to admin_withdraw_path(currency.id, @withdraw.id)
      end
    end
  end
end
