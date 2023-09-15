require 'webrick'
require 'json'

server = WEBrick::HTTPServer.new({ 
	:DocumentRoot => './',
	:BindAddress => '127.0.0.1',
	:Port => 8000
})
# server.mount('/', WEBrick::HTTPServlet::FileHandler, Dir.pwd, { :FancyIndexing => false })
server.mount_proc '/' do |req, res|
	info = "method=#{req.request_method}, uri=#{req.request_uri}, query=#{req.query}, body=#{req.body}"
  server.logger.info(info)
	# TODO: req.bodyの文字列の改行コードを削除して綺麗なhashの形に整形する
	reg = /(\r\n?|\n|\s|"\")/
	req_body = req.body.gsub(reg,"")
	req_body_h = JSON.parse(req_body)
	# puts req_body_h
	
	res.body = {"message": "Account successly created","user": req_body_h}.to_json
end

trap("INT"){ server.shutdown }
server.start

# リクエストの文字列を整形
def cleanup_request_string(str)
end

# user_idのチェック
def check_user_id(user_id)
	check_length(user_id,6,20)
end

# フィールド値のチェック
def check_field
	return false unless check_field?
	return false unless check_require?
end

# 必須項目の存在
def check_require
end

# 値の長さ
def check_length(str, min, max)
	str.length < min || str.length > max
end

# 半角英数字
def single_byte_alp(str)
	# TODO: 正規表現でなんかかけ！
	reg = /^[a-zA-Z0-9]+$/
	reg.match?(str)
end

# user_idの重複
def dup_user_id
	# TODO: user_idをどこに補完するか決めたら書け！賞味初めは同階層にテキストファイル置いておくだけで良いかも！！！
end