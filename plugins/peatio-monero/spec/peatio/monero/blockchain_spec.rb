RSpec.describe Peatio::Monero::Blockchain do
  before(:all) {WebMock.disable_net_connect!}
  after(:all) {WebMock.allow_net_connect!}
  let(:server) { 'http://testnet.node.xmrlab.com:38081' }

  let(:currency) do
    {id: 'xmr',
     base_factor: 1_000_000_000_000,
     options: { address: '56QBugWRa4xMXsWq8NtFQ7DtAQuCvseGHKKuZ4hiHHMCLSK5fkF3ezSVgPjcxyXthDcUmQf7LwhqAGtDcUMhyXxPAurDrjX',
                secret: '9444049984120756fd9b79a3f15cdaa9a778c82dfbb9046b113d60acaa0a390f' }
    }
  end

  context :latest_block_number do

    let(:response) do
      response_file
          .yield_self {|file_path| File.open(file_path)}
          .yield_self {|file| JSON.load(file)}
    end

    let(:response_file) do
      File.join('spec', 'resources', 'get_block_count', 'response.json')
    end

    let(:blockchain) do
      Peatio::Monero::Blockchain.new.tap {|b| b.configure(server: server)}
    end

    before do
      stub_request(:post, server + '/json_rpc')
          .with(body: {"method": "get_block_count"}.to_json)
          .to_return(body: response.to_json)
    end

    it 'returns latest block number' do
      expect(blockchain.latest_block_number).to eq(993162)

    end

    it 'raises error if there is error in response body' do
      stub_request(:post, server + '/json_rpc')
          .with(body: {"method": "get_block_count"}.to_json)
          .to_return(body: {
              "id": "0",
              "jsonrpc": "2.0",
              "error": {
                  "code": -7,
                  "message": ""
              }
          }.to_json)

      expect {blockchain.latest_block_number}.to raise_error(Peatio::Blockchain::ClientError)
    end
  end

  context :build_transaction do

    context 'one xlm coin tx' do
      let(:tx_hash_file) do
        File.join('spec', 'resources', 'get_transactions', 'response.json')
      end

      let(:tx_hash_response) do
        tx_hash_file
            .yield_self {|file_path| File.open(file_path)}
            .yield_self {|file| JSON.load(file)}
      end

      let(:expected_transactions) do
        [
            {
                :hash => "132b6ad5e1aef440ea9fd89b6453f3d5a31f4383ad8ab8994ca1ff59b52398ee",
                :amount => 0.001,
                :to_address => "5G6rvVKvBLUMXsWq8NtFQ7DtAQuCvseGHKKuZ4hiHHMCLSK5fkF3ezSVgPjcxyXthDcUmQf7LwhqAGtDcUMhyXxPFfpGhR1Qz45HVtBbNj",
                :txout => 0,
                :currency_id => "xmr",
                :status => "success"
            }
        ]
      end

      let(:blockchain) do
        Peatio::Monero::Blockchain.new.tap {|b| b.configure(server: server, currencies: [currency])}
      end

      it 'builds formatted transactions for passed transaction' do
        hash = JSON.parse(tx_hash_response.fetch('txs_as_json')[0]).merge!(txid: '132b6ad5e1aef440ea9fd89b6453f3d5a31f4383ad8ab8994ca1ff59b52398ee')
        expect(blockchain.send(:build_transaction, hash.symbolize_keys!)).to contain_exactly(*expected_transactions)
      end
    end
  end

  context :fetch_block! do
    let(:response_file) do
      File.join('spec', 'resources', 'get_block', 'response.json')
    end

    let(:response) do
      response_file
          .yield_self {|file_path| File.open(file_path)}
          .yield_self {|file| JSON.load(file)}
    end

    let(:tx_hash_file) do
      File.join('spec', 'resources', 'get_transactions', 'response.json')
    end

    let(:tx_hash_response) do
      tx_hash_file
          .yield_self {|file_path| File.open(file_path)}
          .yield_self {|file| JSON.load(file)}
    end

    let(:blockchain) do
      Peatio::Monero::Blockchain.new.tap {|b| b.configure(server: server, currencies: [currency])}
    end

    before do
      stub_request(:post, server + '/json_rpc')
          .with(body: {"params": {"height": 380275}, "method": 'get_block'}.to_json)
          .to_return(body: response.to_json)

      stub_request(:post, server + '/get_transactions')
          .with(body: {"txs_hashes": ['f234dfafd8aa759f8b5c8ee8c5bfd6690b3a74cfcc8a9cda267db6a466066ee3'],
                       "decode_as_json": true}.to_json)
          .to_return(body: tx_hash_response.to_json)
    end

    subject {blockchain.fetch_block!(380275)}

    context 'fetch block' do

      it 'builds expected number of transactions' do
        expect(subject.count).to eq(1)
      end

      it 'all transactions are valid' do
        expect(subject.all?(&:valid?)).to be_truthy
      end
    end
  end

  context :load_balance_of_address! do

  end
end
