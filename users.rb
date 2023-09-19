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
  authorization_header = req.header["authorization"][0]
  user_id = req.path.split('/')[-1]
  result = conn.exec("SELECT * FROM users WHERE id = $1", [user_id])
  # user_idが存在しない場合
  if result.cmd_tuples == 0
    res.status = 404
    res.body = {"message": "No User found"}.to_json
  else
    user = result.to_a[0].map {|key,val| [key,val.rstrip]}.to_h
    password = user["password"]
    nickname = user["user_id"] if user["nickname"].empty?
    if check_authorization_header(authorization_header, user_id, password)
      # GET methodの場合
      if req.request_method == 'GET'
        res.body = user.to_json
      # PATCH methodの場合
      elsif req.request_method == 'PATCH'
        req_body = req.body
        req_body_h = JSON.parse(req_body)
        # TODO: user_id, passwordを変えようしている場合、エラーを返す
        nickname, comment = req_body_h["nickname"], req_body_h["comment"]
        # TODO: 認証と異なるuser_idを指定している場合、エラーを返す
        # TODO: nickname, commentのバリデーション
      end
    else
      res.status = 401
      res.body = { "message":"Authentication Failed" }.to_json
    end
  end
end

trap("INT"){ server.shutdown }
server.start
