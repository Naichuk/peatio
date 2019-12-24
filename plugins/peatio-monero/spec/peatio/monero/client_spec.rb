RSpec.describe Peatio::Monero::Client do
  let(:uri) {"http://127.0.0.1:6876"}
  before(:all) {WebMock.disable_net_connect!}
  after(:all) {WebMock.allow_net_connect!}
  subject {Peatio::Monero::Client.new(uri)}

  context :initialize do
    it {expect {subject}.not_to raise_error}
  end

  context :json_rpc do
    let(:response) do
      response_file
          .yield_self {|file_path| File.open(file_path)}
          .yield_self {|file| JSON.load(file)}
    end

    context :get_block_count do
      let(:response_file) do
        File.join('spec', 'resources', 'get_block_count', 'response.json')
      end

      before do
        stub_request(:post, uri + '/json_rpc')
            .with(body: {method: 'get_block_count'}.to_json)
            .to_return(body: response.to_json)
      end
      it {expect {subject.json_rpc('json_rpc', 'get_block_count')}.not_to raise_error}
      it {expect(subject.json_rpc('json_rpc', 'get_block_count')).to eq({'count'=>993163, 'status'=>'OK'})}
    end

    context :methodnotfound do
      before do
        stub_request(:post, uri + '/json_rpc')
            .with(body: {method: 'methodnotfound'}.to_json)
            .to_return(body: {
                "error": {
                    "code": -32601,
                    "message": "Method not found"
                },
                "id": "0",
                "jsonrpc": "2.0"
            }.to_json)
      end

      it do
        expect {subject.json_rpc('json_rpc', 'methodnotfound')}.to \
          raise_error(Peatio::Monero::Client::ResponseError)
      end
    end

    context :notfound do
      before do
        stub_request(:post, uri + '/notfound')
            .with(body: {method: 'notfound'}.to_json)
            .to_return(body: '')
      end

      it do
        expect {subject.json_rpc('notfound','notfound')}.to \
          raise_error(Peatio::Monero::Client::Error)
      end
    end

    context :connectionerror do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::Error)
      end

      it do
        expect {subject.json_rpc(:connectionerror, nil)}.to \
          raise_error(Peatio::Monero::Client::ConnectionError)
      end
    end
  end
end
