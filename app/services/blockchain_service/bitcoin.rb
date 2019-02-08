class BlockchainService::Bitcoin < Peatio::BlockchainService::Abstract
  BlockGreaterThanLatestError = Class.new(StandardError)
  FetchBlockError = Class.new(StandardError)
  FetchBlockHashError = Class.new(StandardError)
  EmptyCurrentBlockError = Class.new(StandardError)

  include Peatio::BlockchainService::Helpers

  def fetch_block!(block_number)
    raise BlockGreaterThanLatestError if block_number > latest_block_number

    block_hash = client.get_block_hash(block_id)
    if block_hash.blank?
      raise FetchBlockHashError
    end

    @block_json = client.get_block(block_number)
    if block_json.blank? || block_json['tx'].blank?
      raise FetchBlockError
    end
  end

  def current_block_number
    require_current_block!
    @block_json['height'].to_i(16)
  end

  def latest_block_number
    @cache.fetch(cache_key(:latest_block), expires_in: 5.seconds) do
      client.latest_block_number
    end
  end

  def client
    @client ||= BlockchainClient::Bitcoin.new(@blockchain)
  end

  def filtered_deposits(payment_addresses, &block)
    require_current_block!
    @block_json
      .fetch('tx')
      .each_with_object([]) do |block_txn, deposits|

      payment_addresses
        .where(address: client.to_address(block_txn))
        .each do |payment_address|
        deposit_txs = client.build_transaction(txn, @block_json,
                                               payment_address.address,
                                               payment_address.currency)
        deposit_txs.fetch(:entries).each do |entry|
          deposit = { txid:           deposit_txs[:id],
                      address:        entry[:address],
                      amount:         entry[:amount],
                      member:         payment_address.account.member,
                      currency:       payment_address.currency,
                      txout:          entry[:txout],
                      block_number:   deposit_txs[:block_number] }

          block.call(deposit) if block_given?
          deposits << deposit
        end
      end
    end
  end

  def fetch_unconfirmed_deposits(block_json = {})
    Rails.logger.info { "Processing unconfirmed deposits." }
    txns = client.get_unconfirmed_txns

    # Read processed mempool tx ids because we can skip them.
    processed = Rails.cache.read("processed_#{self.class.name.underscore}_mempool_txids") || []

    # Skip processed txs.
    block_json.merge!('tx' => txns - processed)
    deposits = build_deposits(block_json, nil)
    update_or_create_deposits!(deposits)

    # Store processed tx ids from mempool.
    Rails.cache.write("processed_#{self.class.name.underscore}_mempool_txids", txns)
  end

  private
  def require_current_block!
    raise EmptyCurrentBlockError if @block_json.blank?
  end
end