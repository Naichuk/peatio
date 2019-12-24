require 'httparty'
require 'pry-byebug'

class Part 
    include HTTParty
    base_uri 'http://51.77.42.233:38081'
    basic_auth 'deploy', 'changeme'
end

resp = Part.get('/json_rpc')

binding.pry
pp resp
