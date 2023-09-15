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
	puts req.body
	
	# res.body = {"message": "Account successly created","user": req.body.gsub(/(\r\n?|\n|\s|\\")/,"").to_h}.to_json
end
# server.mount_proc '/' do_POST(req,res)

trap("INT"){ server.shutdown }
server.start

# リクエストの文字列を整形
def cleanup_request_string(str)
	
end

# フィールド値のチェック
def check_field
	return false unless check_field?
	return false unless check_?
end

# 必須項目の存在
def check_require
end

# 値の長さ
def check_length
end

# 文字種類
def check_pattern
	# TODO: 正規表現でなんかかけ！
end

# user_idの重複
def dup_user_id
	# TODO: user_idをどこに補完するか決めたら書け！賞味初めは同階層にテキストファイル置いておくだけで良いかも！！！
end