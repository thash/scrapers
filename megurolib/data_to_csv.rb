#!/usr/bin/env ruby

require 'digest'
require 'json'
require 'open3'
require 'pry'

f = open('result.csv', 'w')
f.write(['"title"','"author"','"reserve"','"borrow"','"return"'].join(','))
f.write("\n")

# $ aws dynamodb scan --table-name books --query 'Items[.[title.S, author.S]' --output text | tr "\t" ',' > ta.txt]
open('ta.txt').each_line{|l|
  title, author = l.strip.split(',')
  puts "#{title} -- #{author}"
  ht = Digest::SHA1.hexdigest(title)

  cmd =<<EOL
aws dynamodb query \
    --table-name events \
    --index-name hashed_title \
    --query 'Items[].{"date":date.S,"type":type.S}' \
    --key-condition-expression "hashed_title = :vval" \
    --expression-attribute-values '{":vval": {"S": "#{ht}"}}'
EOL

  output = Open3.capture3(cmd).first # get STDOUT
  json   = JSON.load(output)
  puts json

  res = json.find{|j| j['type'] == 'reserve' }['date'] rescue ""
  bor = json.find{|j| j['type'] == 'borrow' }['date']  rescue ""
  ret = json.find{|j| j['type'] == 'return' }['date']  rescue ""

  f.write('"')
  f.write([ title, author, res, bor, ret ].join('","'))
  f.write('"')
  f.write("\n")
}
