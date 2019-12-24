require "active_support/core_ext/object/blank"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/string/inquiry"
require "active_support/core_ext/object/try"
require "peatio"

module Peatio
  module Monero
    require "bigdecimal"
    require "bigdecimal/util"

    require "peatio/monero/blockchain"
    require "peatio/monero/client"
    require "peatio/monero/wallet"
    require "peatio/monero/hooks"
    require "peatio/monero/version"
  end
end
