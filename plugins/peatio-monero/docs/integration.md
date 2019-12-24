# Integration.

For Peatio Monero plugin integration you need to do the following steps:

## Image Build.

1. Add peatio-monero gem into your Gemfile.plugin
```ruby
gem 'peatio-monero', '~> 0.1.0'
```

2. Run `bundle install` for updating Gemfile.lock

3. Build custom Peatio [docker image with Monero plugin](https://github.com/rubykube/peatio/blob/master/docs/plugins.md#build)

4. Push your image using `docker push`

5. Update your deployment to use image with peatio-monero gem

## Peatio Configuration.

1. Create Monero Blockchain [config example](../config/blockchains.yml).
    * No additional steps are needed

2. Create Monero Currency [config example](../config/currencies.yml).
    * No additional steps are needed

3. Create Monero Wallets [config example](../config/wallets.yml)(deposit, hot and warm Wallets are required).

4. Increase address limit in `payment_addresses` and `deposits` to `125`.