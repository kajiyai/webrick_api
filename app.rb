require 'webrick'

server = WEBrick::HTTPServer.new({ 
	:DocumentRoot => './',
	:BindAddress => '127.0.0.1',
	:Port => 8000
})
# server.mount('/', WEBrick::HTTPServlet::FileHandler, Dir.pwd, { :FancyIndexing => false })
server.mount_proc '/' do |request, response|
	response.body = request.query['a']
end
trap("INT"){ server.shutdown }
server.start