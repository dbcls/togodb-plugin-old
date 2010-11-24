#!/usr/bin/env ruby -Ku
#
require 'xmlrpc/client'

query  = ARGV.shift or (puts "usage: #{__FILE__} QUERY_STRING"; exit)
server = XMLRPC::Client.new2('http://localhost:3000/user/api')

p server.call('count',  query)
p server.call('search', query,1,0)

