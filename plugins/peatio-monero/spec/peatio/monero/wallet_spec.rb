RSpec.describe Peatio::Monero::Wallet do
  let(:wallet) {Peatio::Monero::Wallet.new}
  let(:uri) {'http://127.0.0.1:28085'}

  let(:settings) do
    {
        wallet: {address: '56QBugWRa4xMXsWq8NtFQ7DtAQuCvseGHKKuZ4hiHHMCLSK5fkF3ezSVgPjcxyXthDcUmQf7LwhqAGtDcUMhyXxPAurDrjX',
                 uri: uri,
                 secret: '9444049984120756fd9b79a3f15cdaa9a778c82dfbb9046b113d60acaa0a390f'}
    }
  end

  let(:currency) do
    {id: 'xmr',
     base_factor: 1_000_000_000_000,
     options: { address: '56QBugWRa4xMXsWq8NtFQ7DtAQuCvseGHKKuZ4hiHHMCLSK5fkF3ezSVgPjcxyXthDcUmQf7LwhqAGtDcUMhyXxPAurDrjX',
                secret: '9444049984120756fd9b79a3f15cdaa9a778c82dfbb9046b113d60acaa0a390f' }
    }
  end

  context :configure do

    before do
      settings[:currency] = currency
      wallet.configure(settings)
    end

    let(:unconfigured_wallet) {Peatio::Monero::Wallet.new}

    it 'requires wallet' do
      expect {unconfigured_wallet.configure(settings.except(:wallet))}.to raise_error(Peatio::Wallet::MissingSettingError)

      expect {unconfigured_wallet.configure(settings)}.to_not raise_error
    end

    it 'requires currency' do
      expect {unconfigured_wallet.configure(settings.except(:currency))}.to raise_error(Peatio::Wallet::MissingSettingError)

      expect {unconfigured_wallet.configure(settings)}.to_not raise_error
    end

    it 'sets settings attribute' do
      unconfigured_wallet.configure(settings)
      expect(unconfigured_wallet.settings).to eq(settings.slice(*Peatio::Monero::Wallet::SUPPORTED_SETTINGS))
    end
  end

  context :create_address! do
    before do
      settings[:currency] = currency
      wallet.configure(settings)
    end

    before(:all) {WebMock.disable_net_connect!}
    after(:all) {WebMock.allow_net_connect!}

    let(:response) do
      response_file
          .yield_self {|file_path| File.open(file_path)}
          .yield_self {|file| JSON.load(file)}
    end

    let(:response_file) do
      File.join('spec', 'resources', 'make_integrated_address', 'response.json')
    end

    before do
      stub_request(:post, uri + '/json_rpc')
          .with(body: { 'params': {'standard_address': '56QBugWRa4xMXsWq8NtFQ7DtAQuCvseGHKKuZ4hiHHMCLSK5fkF3ezSVgPjcxyXthDcUmQf7LwhqAGtDcUMhyXxPAurDrjX',
                                   'payment_id': "#{Digest::SHA256.hexdigest('UID123' + Time.now.to_s)[0...16]}"},
                        'method': 'make_integrated_address'}.to_json)
          .to_return(body: response.to_json)
    end

    it 'request rpc and creates new address' do
      result = wallet.create_address!(uid: 'UID123')
      expect(result.symbolize_keys)
          .to eq({:address=>"5G6rvVKvBLUMXsWq8NtFQ7DtAQuCvseGHKKuZ4hiHHMCLSK5fkF3ezSVgPjcxyXthDcUmQf7LwhqAGtDcUMhyXxPFbMLcVhAfJtStsYNVg"})
    end
  end

  context :create_transaction! do
    before(:all) {WebMock.disable_net_connect!}
    after(:all) {WebMock.allow_net_connect!}

    before do
      settings[:currency] = currency
      wallet.configure(settings)
    end

    let(:response) do
      response_file
          .yield_self {|file_path| File.open(file_path)}
          .yield_self {|file| JSON.load(file)}
    end

    let(:response_file) do
      File.join('spec', 'resources', 'transfer', 'response.json')
    end

    before do
      stub_request(:post, uri + '/json_rpc')
          .with(body: {
                  "params": {"destinations": [
                  "address": '56QBugWRa4xMXsWq8NtFQ7DtAQuCvseGHKKuZ4hiHHMCLSK5fkF3ezSVgPjcxyXthDcUmQf7LwhqAGtDcUMhyXxPAurDrjX',
                  "amount": 2000000000000
              ]}, "method": "transfer"
          }.to_json)
          .to_return(body: response.to_json)
    end

    let(:transaction) do
      Peatio::Transaction.new(amount: 2, to_address: '56QBugWRa4xMXsWq8NtFQ7DtAQuCvseGHKKuZ4hiHHMCLSK5fkF3ezSVgPjcxyXthDcUmQf7LwhqAGtDcUMhyXxPAurDrjX')
    end

    it 'requests rpc and sends transaction' do
      result = wallet.create_transaction!(transaction)
      expect(result.amount).to eq(2.to_d)
      expect(result.to_address).to eq('56QBugWRa4xMXsWq8NtFQ7DtAQuCvseGHKKuZ4hiHHMCLSK5fkF3ezSVgPjcxyXthDcUmQf7LwhqAGtDcUMhyXxPAurDrjX')
      expect(result.hash).to eq('7663438de4f72b25a0e395b770ea9ecf7108cd2f0c4b75be0b14a103d3362be9')
    end

  end

  context :load_balance! do

    before(:all) {WebMock.disable_net_connect!}
    after(:all) {WebMock.allow_net_connect!}

    let(:get_balance_response) do
      get_balance_file
          .yield_self {|file_path| File.open(file_path)}
          .yield_self {|file| JSON.load(file)}
    end

    let(:get_balance_file) do
      File.join('spec', 'resources', 'get_balance', 'response.json')
    end

    before do
      stub_request(:post, uri + "/json_rpc")
          .with(body: { "params": {"account_index":0}, "method": 'get_balance'}.to_json)
          .to_return(body: get_balance_response.to_json)
    end

    context 'address with balance is defined' do
      it 'requests rpc accounts and return currency balance' do
        settings[:currency] = currency
        wallet.configure(settings)

        result = wallet.load_balance!
        expect(result).to be_a(BigDecimal)
        expect(result).to eq('0.799928391e1'.to_d)
      end
    end
  end
end
