require 'webrick'
require 'json'

class HTTPD

  def initialize(gh)
    @server = WEBrick::HTTPServer.new(
      :Port => 8000
    )
    @gh = gh
    @gh.list_prs
  end

  def start()
    @server.mount_proc '/webhook' do | req, res |
      res.status = 200
      res.body = "cloning repo!"
      @gh.clone_repo()
    end
    @server.start
  end

  # class MyListener < WEBrick::HTTPServlet::AbstractServlet
  #   def do_GET(request, response)
  #     status, content_type, body = request
  #     # puts "REQUEST: #{request}"
  #     # puts "BODY: #{request.body}"
  #     response.status = 200
  #     response['Content-Type'] = 'text/json'
  #     payload = JSON.parse(request.body)
  #     # puts "PAYLOAD:"
  #     # puts payload['title']
  #     response.body = "cloning repo!"
  #     @gh.list_prs
  #     #@gh.clone_repo()
  #   end
  #   def do_stuff_with(request)
  #     return 200, 'text/json', 'you got a page'
  #   end
  #   alias :do_POST :do_GET
  # end
end
