require 'webrick'
require 'json'
require_relative 'logger'

include Logging

class HTTPD

  def initialize(gh)
    log_file = File.open("/tmp/github/log.log",'a+')
    log = WEBrick::Log.new log_file
    @server = WEBrick::HTTPServer.new(
      :Port => 8000,
      :Logger => log
    )
    @gh = gh
    @registered_events = ['pull_request', 'push']
    @merged_commits = []
  end

  def start()
    @server.mount_proc '/webhook' do | req, res |
      data_length = req.content_length

      begin
        payload = JSON.parse(req.body)
        logger.info("successfully processed payload")
      rescue
        logger.critical("Can't process payload")
      end
      if payload['pull_request']
        puts "Got new PR"
        process_open_pr
      elsif payload['pusher'] && payload['repository']
        puts "Got merged PR"
        process_merged_pr(payload["after"])
      else
        puts "unknown payload sent to listener"
      end
      res.status = 200
      logger.info("Webhook listener processing POST request")
      payload = JSON.parse(req.body)
      logger.info("Connection from: #{req.attributes}")
      res.body = "cloning repo!"
    end
    trap 'INT' do @server.shutdown end
    @server.start
  end

  def process_open_pr
    @gh.get_pull_requests.each do | pr |
      logger.info("Processing PR #{pr.number}")
      pwd = Dir.pwd()
      @gh.checkout_pull_request(pr, "/tmp/github/test_repo")
      Dir.chdir(pwd)
      @gh.cleanup_branches("/tmp/github/test_repo")
    end
  end

  def process_merged_pr(commit)
    # if @merged_commits[commit]
    #   logger.warn("Commit {0} previously merged. Skipping.")
    #   return
    # end

    log_msg = "Processing merge webhook"
    logger.info("#{log_msg} - start")
    @gh.clone("/tmp/github/test_repo")
    # @merged_commits.push(commit)
  end

  def is_registered()
    listener_url = ("/webhook")
    @gh.get_hooks.each do | hook |
      if hook.config.url == listener_url
        if hook.events == @registered_events
          return true
        end
      else
        logger.debug("hook.events: #{hook.events} registered_events: #{@registered_events}")
      end
    end
    return false
  end

  def register()
    if is_registered()
      logger.info("Webhooks already registered.")
      return
    end
    logger.debug("Registering webhooks!")
    listener_url = ("/webhook")
    hook_config = {
      :url => listener_url,
      :content_type => 'json'
    }
    hook_options = {
        :events => @registered_events,
        :active => true
    }
    puts "creating hook"
    @gh.client.create_hook(@gh.orgrepo, "web", hook_config, hook_options)
  end

end
