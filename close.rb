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

server.mount_proc '/close' do |req, res|
  authorization_header = req.header["authorization"][0]
  # TODO: user_id, passwordはどのように取得するべきか検討する
  if check_authorization_header(authorization_header, user_id, password)
    # いくつかの処理
    delete_sql = "delete users where id = $1"
    conn.exec(delete_sql,[user_id])
    res.body = {  "message": "Account and user successfully removed" }.to_json
  else
    res.status = 401
    res.body = { "message": "Authentication Failed" }.to_json
  end
end