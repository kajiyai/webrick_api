require 'webrick'

server = WEBrick::HTTPServer.new({ 
	:DocumentRoot => './',
	:BindAddress => '127.0.0.1',
	:Port => 8000
})
# server.mount('/', WEBrick::HTTPServlet::FileHandler, Dir.pwd, { :FancyIndexing => false })
server.mount_proc '/' do |request, response|
	response.body = "user_id:" + request.query['a'] +","+"password:"+request.query['b']
end
trap("INT"){ server.shutdown }
server.start