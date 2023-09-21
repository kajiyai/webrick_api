require 'webrick'
require 'json'
require 'pg'
require 'base64'

# auhorizationヘッダのチェック
def check_authorization_header(encoded_str,conn)
  auth_user_id,auth_password = get_credential(encoded_str)
  result = conn.exec("SELECT password FROM users WHERE id = $1", [auth_user_id]).to_a
  return false if result[0].nil?
  result[0]["password"].rstrip.eql?(auth_password)
end

# authorizationヘッダの処理
def get_credential(encoded_str)
  decoded_str = Base64.decode64(encoded_str)
  decoded_strs = decoded_str.split(":")
  decoded_user_id = decoded_strs[0]
  decoded_password = decoded_strs[1]
  return decoded_user_id, decoded_password
end

# authorizationヘッダのuser_idを取得
def get_auth_user_id(encoded_str)
  Base64.decode64(encoded_str).split(":")[0]
end

server = WEBrick::HTTPServer.new({ 
  :DocumentRoot => './',
  :BindAddress => '127.0.0.1',
  :Port => 8000
})

# DB接続
conn = PG.connect( dbname: 'code_track', user: 'postgres' )

server.mount_proc '/close' do |req, res|
  authorization_header = req.header["authorization"][0]
  return res.status = 401, res.body = { "message":"Authentication Failed" }.to_json if authorization_header.nil? # authorizationヘッダが空白の場合
  return res.status = 401, res.body = { "message":"Authentication Failed" }.to_json if !check_authorization_header(authorization_header,conn) # authorizationヘッダの検証
  auth_user_id = get_auth_user_id(authorization_header)
  result = conn.exec("DELETE FROM users WHERE id = $1", [auth_user_id])
  res.status = 200, res.body = {  "message": "Account and user successfully removed" }.to_json if result.res_status == "PGRES_COMMAND_OK"
end

trap("INT"){ server.shutdown }
server.start
