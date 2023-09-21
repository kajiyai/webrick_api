require 'webrick'
require 'json'
require 'pg'
require 'base64'

# nicknameのチェック
def check_nickname(nickname)
  return "less than 30" unless check_length(nickname,30)
  return "use ascii character" unless is_valid_ascii(nickname)
  true
end

# commentのチェック
def check_comment(comment)
  return "less than 100" unless check_length(comment,100)
  return "use ascii character" unless is_valid_ascii(comment)
  true
end

# 値の長さ
def check_length(str, max)
  str.length <= max
end

def is_valid_ascii(str)
  reg = /^[ -~]+$/
  reg.match?(str)
end

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

class UsersServlet < WEBrick::HTTPServlet::AbstractServlet
  def initialize(server, conn)
    super(server)
    @conn = conn
  end

  def do_GET(req, res)
    authorization_header = req.header["authorization"][0]
    return res.status = 401, res.body = { "message":"Authentication Failed" }.to_json if authorization_header.nil? # authorizationヘッダが空白の場合
    return res.status = 401, res.body = { "message":"Authentication Failed" }.to_json if !check_authorization_header(authorization_header,@conn) # authorizationヘッダの検証
    user_id = req.path.split('/')[-1]
    result = @conn.exec("SELECT * FROM users WHERE id = $1", [user_id])
    return res.status = 404, res.body = {"message": "No User found"}.to_json if result.cmd_tuples == 0 # 登録されていないuser_idを指定した場合
    user = result.to_a[0].map {|key,val| [key,val.rstrip]}.to_h
    user.delete("password") # passwordの削除
    user.delete("comment") if user["comment"].empty? # commentが空の場合コメントは返さない
    nickname = user["user_id"] if user["nickname"].empty? # nicknameが空の場合user_idをnicknameに設定する
    res.body = user.to_json
  end

  def do_PATCH(req, res)
    authorization_header = req.header["authorization"][0]
    return res.status = 401, res.body = { "message":"Authentication Failed" }.to_json if authorization_header.nil? # authorizationヘッダが空白の場合
    return res.status = 401, res.body = { "message":"Authentication Failed" }.to_json if !check_authorization_header(authorization_header,@conn) # authorizationヘッダの検証

    user_id = req.path.split('/')[-1]
    return res.status = 403, res.body = { "message":"No Permission for Update"}.to_json if user_id != get_auth_user_id(authorization_header) # アクセスしたpathのuser_idと認証で使用したuser_idが異なる場合

    result = @conn.exec("SELECT * FROM users WHERE id = $1", [user_id])
    return res.status = 404, res.body = {"message": "No User found"}.to_json if result.cmd_tuples == 0 # 登録されていないuser_idを指定した場合

    user = result.to_a[0].map {|key,val| [key,val.rstrip]}.to_h
    password = user["password"]
    nickname = user["user_id"] if user["nickname"].empty?
    req_body = req.body
    req_body_h = JSON.parse(req_body)
    nickname, comment = req_body_h["nickname"], req_body_h["comment"]
    return res.status = 400, res.body = {"message": "User updation failed","cause": "not updatable user_id and password"}.to_json if req_body_h.keys.any?(/user_id|password/) # user_id,passwordを変更しようとした場合
    return res.status = 400, res.body = {"message": "User updation failed","cause": "required nickname or comment"}.to_json if nickname.empty? && comment.empty? # nickname,commentが共に空白の場合

    check_nickname_res = check_nickname(nickname)
    check_comment_res = check_comment(comment)
    return res.status = 400, res.body = {"message": "User updation failed", "cause": check_nickname_res}.to_json if check_nickname_res != true # nicknameのバリデーション
    return res.status = 400, res.body = {"message": "User updation failed", "cause": check_comment_res}.to_json if check_comment_res != true # commentのバリデーション

    update_user_sql = "UPDATE users SET nickname = $1, comment = $2 WHERE id = $3"
    @conn.exec(update_user_sql, [nickname, comment, user_id])
    res_body_h = {"nickname": nickname, "comment": comment}
    res.body = {"message": "User successfully updated","recipe": [res_body_h]}.to_json
  end
end

server = WEBrick::HTTPServer.new({
  :DocumentRoot => './',
  :BindAddress => '127.0.0.1',
  :Port => 8000
})

conn = PG.connect(dbname: 'code_track', user: 'postgres')

server.mount '/users', UsersServlet, conn

trap("INT"){ server.shutdown }
server.start
