require 'webrick'
require 'json'
require 'pg'

server = WEBrick::HTTPServer.new({ 
  :DocumentRoot => './',
  :BindAddress => '127.0.0.1',
  :Port => 8000
})

# DB接続
conn = PG.connect( dbname: 'code_track', user: 'postgres' )

server.mount_proc '/users' do |req, res|
  # TODO: authorizationヘッダーがうんたらを書く
  # TODO: 要求されているuser_idを返す
  # TODO: 何かをする
  req_head = req.header
  puts req_head
  req_body = req.body
  req_body_h = JSON.parse(req_body)
end

trap("INT"){ server.shutdown }
server.start
