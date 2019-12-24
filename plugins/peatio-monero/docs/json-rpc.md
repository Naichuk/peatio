# JSON RPC

The next list of JSON RPC calls where used for plugin development.
For response examples see spec/resources:

  * Create Address
  
    `curl -X POST http://127.0.0.1:18082/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"make_integrated_address","params":{"standard_address":"55LTR8KniP4LQGJSPtbYDacR7dz8RBFnsfAKMaMuwUNYX6aQbBcovzDPyrQF9KXF9tVU6Xk3K8no1BywnJX6GvZX8yJsXvt", "payment_id": "420fa29b2d9a49f5"}}' -H 'Content-Type: application/json'` 
  * Fetch Balance
   
    ` curl -X POST http://127.0.0.1:18082/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_balance","params":{"account_index":0}}' -H 'Content-Type: application/json'`
    
  * Fetch latest block
  
    `curl -X POST http://127.0.0.1:18081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_block_count"}' -H 'Content-Type: application/json'`
    
  * Get block
  
    ` curl -X POST http://127.0.0.1:18081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_block","params":{"height":912345}}' -H 'Content-Type: application/json'`

  *  Transaction from Transaction Hash
  
     `curl -X POST http://127.0.0.1:18081/get_transactions -d '{"txs_hashes":["f234dfafd8aa759f8b5c8ee8c5bfd6690b3a74cfcc8a9cda267db6a466066e113"], "decode_as_json":true}' -H 'Content-Type: application/json'`
  
  * Transfer XMR
    
    `curl -X POST http://127.0.0.1:18082/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"transfer","params":{"destinations":[{"amount":100000000000,"address":"7BnERTpvL5MbCLtj5n9No7J5oE5hHiB3tVCK5cjSvCsYWD2WRJLFuWeKTLiXo5QJqt2ZwUaLy2Vh1Ad51K7FNgqcHgjW85o"}]}}' -H 'Content-Type: application/json'`
