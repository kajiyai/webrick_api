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
  result = conn.exec("SELECT password FROM users WHERE id = $1", [auth_user_id])
  result["password"].eql?(auth_password)
end

# authorizationヘッダの処理
def get_credential(encoded_str)
  decoded_str = Base64.decode64(encoded_str)
  decoded_strs = decoded_str.split(":")
  decoded_user_id = decoded_strs[0]
  decoded_password = decoded_strs[1]
  return decoded_user_id, decoded_password
end

class UsersServlet < WEBrick::HTTPServlet::AbstractServlet
  def initialize(server, conn)
    super(server)
    @conn = conn
  end

  def do_GET(req, res)
    authorization_header = req.header["authorization"][0]
    return res.status = 401, res.body = { "message":"Authentication Failed" }.to_json if authorization_header.nil?
    user_id = req.path.split('/')[-1]
    result = @conn.exec("SELECT * FROM users WHERE id = $1", [user_id])
    if result.cmd_tuples == 0
      res.status = 404
      res.body = {"message": "No User found"}.to_json
    else
      user = result.to_a[0].map {|key,val| [key,val.rstrip]}.to_h
      password = user["password"]
      nickname = user["user_id"] if user["nickname"].empty?
      if check_authorization_header(authorization_header, user_id, password)
        res.body = user.to_json
      else
        res.status = 401
        res.body = { "message":"Authentication Failed" }.to_json
      end
    end
  end

  def do_PATCH(req, res)
    authorization_header = req.header["authorization"][0]
    return res.status = 401, res.body = { "message":"Authentication Failed" }.to_json if authorization_header.nil?
    user_id = req.path.split('/')[-1]
    result = @conn.exec("SELECT * FROM users WHERE id = $1", [user_id])
    if result.cmd_tuples == 0
      res.status = 404
      res.body = {"message": "No User found"}.to_json
    else
      user = result.to_a[0].map {|key,val| [key,val.rstrip]}.to_h
      password = user["password"]
      nickname = user["user_id"] if user["nickname"].empty?
      if check_authorization_header(authorization_header, user_id, password)
        req_body = req.body
        req_body_h = JSON.parse(req_body)
        nickname, comment = req_body_h["nickname"], req_body_h["comment"]
        if req_body_h.keys.include?(["user_id","password"])
          res.status = 400
          res.body = {
            "message": "User updation failed",
            "cause": "not updatable user_id and password"
          }.to_json
        elsif nickname.nil? && comment.nil?
          res.status = 400
          res.body = {
            "message": "User updation failed",
            "cause": "required nickname or comment"
          }.to_json
        else
          check_nickname_res = check_nickname(nickname)
          check_comment_res = check_comment(comment)
          if check_nickname_res != true
            res.status = 400
            res.body = {"message": "User updation failed", "cause": check_nickname_res}.to_json
          elsif check_comment_res != true
            res.status = 400
            res.body = {"message": "User updation failed", "cause": check_comment_res}.to_json
          else
            update_user_sql = "UPDATE users SET nickname = $1, comment = $2 WHERE id = $3"
            @conn.exec(update_user_sql, [nickname, comment, user_id])
            res_body_h = {"nickname": nickname, "comment": comment}
            res.body = {
              "message": "User successfully updated",
              "recipe": [
                res_body_h
              ]
            }.to_json
          end
        end
      else
        res.status = 401
        res.body = { "message":"Authentication Failed" }.to_json
      end
    end
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
