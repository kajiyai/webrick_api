require 'webrick'
require 'json'
require 'pg'
require 'base64'
require 'bcrypt'

# ヘルパーメソッドや共通の関数

# パスワードがの判定
def password_matches?(hashed_password_from_database, plain_password)
  BCrypt::Password.new(hashed_password_from_database) == plain_password
end

# auhorizationヘッダのチェック
def check_authorization_header(encoded_str,conn)
  auth_user_id,auth_password = get_credential(encoded_str)
  result = conn.exec("SELECT password FROM users WHERE id = $1", [auth_user_id]).to_a
  return false if result[0].nil?
  password_matches?(result[0]["password"].rstrip, auth_password)
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


# user_idのチェック
def check_user_id(user_id)
  return "require user_id" unless check_require(user_id)
  return "more than 6 and less than 20" unless check_length(user_id, 6, 20)
  return "use half-width alphanumeric character " unless reg_single_byte_alp(user_id)
  true
end

# passwordのチェック
def check_password(password)
  return "require password" unless check_require(password)
  return "more than 8 and less than 20" unless check_length(password, 8, 20)
  return "use half-width alphanumeric character and some codes " unless reg_single_byte_alp_code(password)
  true
end


# nicknameのチェック
def check_nickname(nickname)
  return "less than 30" unless check_length(nickname,0,30)
  return "use ascii character" unless is_valid_ascii(nickname)
  true
end

# commentのチェック
def check_comment(comment)
  return "less than 100" unless check_length(comment,0,100)
  return "use ascii character" unless is_valid_ascii(comment)
  true
end

# 必須項目の存在
def check_require(str)
  str && !str.empty?
end

# 値の長さ
def check_length(str, min, max)
  str.length >= min && str.length <= max
end

# ASCII文字か
def is_valid_ascii(str)
  reg = /^[ -~]+$/
  reg.match?(str)
end

# user_idの重複
def dup_user_id(conn, user_id)
  result = conn.exec("SELECT * FROM users WHERE id = $1", [user_id])
  result.cmd_tuples > 0
end

### 正規表現 ###

# 半角英数字
def reg_single_byte_alp(str)
  reg = /^[a-zA-Z0-9]+$/
  reg.match?(str)
end

# 半角英数字記号
def reg_single_byte_alp_code(str)
  reg = /^[!-~]+$/
  reg.match?(str)
end

### 正規表現 ###


# DB接続
conn = PG.connect(dbname: 'code_track', user: 'postgres')

# WEBrickサーバーの設定
server = WEBrick::HTTPServer.new({
  :DocumentRoot => './',
  :BindAddress => '127.0.0.1',
  :Port => 8000
})

# Signup エンドポイント
# TODO: passwordをbcryptを使ってハッシュ化する
server.mount_proc '/signup' do |req, res|
  req_body = req.body
  req_body_h = JSON.parse(req_body)
  user_id, password = req_body_h["user_id"], req_body_h["password"]
  check_user_id_result = check_user_id(user_id)
  check_password_result = check_password(password)
  if dup_user_id(conn, user_id)
    res.status = 400
    res.body = {"message": "Account creation failed", "cause": "user_id already exists"}.to_json
  elsif check_user_id_result != true
    res.status = 400
    res.body = {"message": "Account creation failed", "cause": check_user_id_result}.to_json
  elsif check_password_result != true
    res.status = 400
    res.body = {"message": "Account creation failed", "cause": check_password_result}.to_json
  else
    insert_user_sql = "insert into users (id,password,nickname,comment) values ($1, $2, $3, '')"
    hashed_password = BCrypt::Password.create(password) # パスワードをハッシュ化
    conn.exec_params(insert_user_sql, [user_id, hashed_password, user_id])
    res_body_h = {"user_id": user_id, "nickname": user_id} # nicknameの初期値はuser_idと同値
    res.body = {"message": "Account successfully created","user": res_body_h}.to_json
  end
end

# Close エンドポイント
# TODO: 一度削除したのちにもう一度削除しようとすると500エラーが起こる(authヘッダの検証で引っかかるはずが・・)
server.mount_proc '/close' do |req, res|
  authorization_header = req.header["authorization"][0]
  return res.status = 401, res.body = { "message":"Authentication Failed" }.to_json if authorization_header.nil? # authorizationヘッダが空白の場合
  return res.status = 401, res.body = { "message":"Authentication Failed" }.to_json if !check_authorization_header(authorization_header,conn) # authorizationヘッダの検証
  auth_user_id = get_auth_user_id(authorization_header)
  conn.exec("DELETE FROM users WHERE id = $1", [auth_user_id])
  res.status = 200
  res.body = {"message": "Account and user successfully removed" }.to_json
end

# Users エンドポイント
class UsersServlet < WEBrick::HTTPServlet::AbstractServlet
  def initialize(server, conn)
    super(server)
    @conn = conn
  end

  # GETメソッド用の処理
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

  # PATCHメソッド用の処理
  # TODO: nicknameにvalid,commentに何も指定せずに送るとnot valid asciiが返る(200が返されるはず・)
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

# Users エンドポイントをマウント
server.mount '/users', UsersServlet, conn

# サーバーのシャットダウン処理
trap("INT") { server.shutdown }

# サーバーの開始
server.start
