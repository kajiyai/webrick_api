require 'webrick'
require 'json'
require 'pg'
require 'base64'

# auhorizationヘッダのチェック
def check_authorization_header(encoded_str,user_id,password)
  decoded_str = Base64.decode64(encoded_str)
  decoded_str.eql?(user_id+":"+password)
end

server = WEBrick::HTTPServer.new({ 
  :DocumentRoot => './',
  :BindAddress => '127.0.0.1',
  :Port => 8000
})

# DB接続
conn = PG.connect( dbname: 'code_track', user: 'postgres' )

server.mount_proc '/users' do |req, res|
  # TODO: authorizationヘッダーがうんたらを書く
  authorization_header = req.header["authorization"][0]
  user_id = req.path.split('/')[-1]
  result = conn.exec("SELECT * FROM users WHERE id = $1", [user_id])
  user = result.to_a[0].map {|key,val| [key,val.rstrip]}.to_h
  password = user["password"]
  if check_authorization_header(authorization_header, user_id, password)
    puts "ok"
  else
    puts "ng"
  end

  
  # check_authorization_header(authorization_header,user_id,password)
  # TODO: 要求されているuser_idを返す
  
  puts user_id
  # TODO: 何かをする
  
  res.body = user.to_json
end

trap("INT"){ server.shutdown }
server.start
