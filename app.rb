require 'webrick'
require 'json'
require 'pg'

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

# 必須項目の存在
def check_require(str)
  str && !str.empty?
end

# 値の長さ
def check_length(str, min, max)
  str.length >= min && str.length <= max
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

# user_idの重複
def dup_user_id
  # TODO: user_idをどこに補完するか決めたら書け！賞味初めは同階層にテキストファイル置いておくだけで良いかも！！！
end


# DB接続
conn = PG.connect( dbname: 'code_track', user: 'postgres' )

server = WEBrick::HTTPServer.new({ 
  :DocumentRoot => './',
  :BindAddress => '127.0.0.1',
  :Port => 8000
})

server.mount_proc '/' do |req, res|
  req_body = req.body
  req_body_h = JSON.parse(req_body)
  user_id, password = req_body_h["user_id"], req_body_h["password"]
  check_user_id_result = check_user_id(user_id)
  check_password_result = check_password(password)
  if check_user_id_result != true
		res.status = 400
    res.body = {"message": "Account creation failed", "cause": check_user_id_result}.to_json
  elsif check_password_result != true
		res.status = 400
    res.body = {"message": "Account creation failed", "cause": check_password_result}.to_json
  else
    insert_user_sql = "insert into users (id,password,nickname,comment) values ('#{user_id}','#{password}','#{user_id}','')"
    conn.exec(insert_user_sql)
    res_body_h = {"user_id": user_id, "nickname": user_id} # nicknameの初期値はuser_idと同値
    res.body = {"message": "Account successfully created","user": res_body_h}.to_json
  end
end

trap("INT"){ server.shutdown }
server.start
