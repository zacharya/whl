require 'octokit'
require 'open3'
require 'inifile'
require 'fileutils'
require_relative 'logger'
require_relative 'utils'

include Utils
include Logging

class GHWrapper
  def initialize(token, api_url, org, repo)
    # @client=Octokit::Client.new(
    #   :access_token => token,
    #   :api_endpoint => api_url
    # )
    @token = token
    @host = api_url.match('https?://([^/]+).*')[1]
    @org = org
    @repo = repo
    @orgrepo = "#{@org}/#{@repo}"
    @client=Octokit::Client.new(
       :access_token => token,
       :api_endpoint => api_url
    )
  end

  def client()
    return @client
  end

  def orgrepo()
    return @orgrepo
  end

  def construct_ssh_url(repo_url=nil)
    if ! repo_url
      return "git@#{@host}:#{@orgrepo}.git"
    end
    _, url = repo_url.split("://")
    gh_path = url.split('/')
    host, org, repo = gh_path
    return "git@#{host}:#{org}/#{repo}"
  end

  def clone(path)
    url = construct_ssh_url()
    logger.debug("Using SSH url: #{url}")
    pwd = Dir.pwd()

    begin
      git_config_file = IniFile.load("#{path}/.git/config")
      git_config_origin_url = git_config_file['remote "origin"']['url']
    rescue
      logger.warn("Issue parsing git config file")
      config_origin_url = ""
    end

    if url == git_config_origin_url
      logger.info("#{path} exists and is a git repo.")
      Dir.chdir(path)

      log_msg = "Switching to master branch"
      logger.info("#{log_msg} -start")
      cmd_list = ["git",  "checkout", "master"]
      shell_cmd(cmd_list, "#{log_msg} - failed")
      logger.info("#{log_msg} -complete")

      log_msg = "Synching with origin"
      logger.info("#{log_msg} -start")
      cmd_list = ["git",  "pull", "origin", "master"]
      shell_cmd(cmd_list, "#{log_msg} - failed")
      logger.info("#{log_msg} -complete")
    else
      parent_dir = path.split("/")[-2]
      if ! File.directory?(parent_dir)
        logger.info("Parent dir #{parent_dir} does not exist.  Creating.")
        FileUtils.mkdir_p(parent_dir)
      else
        if Dir.exists?(path)
          logger.info("#{path} exists, but is not a valid git repo.  Removing.")
          FileUtils.rm_rf(path)
        end
      end

      log_msg = "Cloning #{url} to #{path}"
      logger.info("#{log_msg} -start")
      cmd_list = ["git",  "clone", url, path]
      shell_cmd(cmd_list, "#{log_msg} - failed")
      logger.info("#{log_msg} -complete")
    end

    Dir.chdir(pwd)

  end

  def checkout_pull_request(pr, path)
    remote_label = pr.head.label.gsub(':', '-')
    clone(path)
    pwd = Dir.pwd()
    Dir.chdir(path)

    log_msg = "Creating branch #{remote_label} for PR #{pr.number}"
    logger.info("#{log_msg} -start")
    cmd_list = ["git",  "checkout", "-b", remote_label]
    shell_cmd(cmd_list, "#{log_msg} - failed")
    logger.info("#{log_msg} -complete")

    puts pr.head.repo.clone_url
    url = construct_ssh_url(pr.head.repo.clone_url)
    puts url
    puts pr.head.ref

    log_msg = "Pulling  branch #{remote_label} for PR #{pr.number}"
    logger.info("#{log_msg} -start")
    cmd_list = ["git",  "pull", url, pr.head.ref]
    shell_cmd(cmd_list, "#{log_msg} - failed")
    logger.info("#{log_msg} -complete")

    Dir.chdir(pwd)

  end

  def cleanup_branches(path)
    pwd = Dir.pwd()
    Dir.chdir(path)

    log_msg = "Cleaning up local branches"
    logger.info("#{log_msg} - start")

    log_msg = "Switching back to master branch"
    logger.info("#{log_msg} -start")
    cmd_list = ["git",  "checkout", "master"]
    shell_cmd(cmd_list, "#{log_msg} - failed")
    logger.info("#{log_msg} -complete")

    log_msg = "Listing branches"
    logger.info("#{log_msg} -start")
    cmd_list = ["git",  "branch"]
    raw_branches = shell_cmd(cmd_list, "#{log_msg} - failed")
    branches = raw_branches.gsub(/(\n|\*)/,'').split
    logger.info("#{log_msg} -complete")

    branches.each do | branch |
      if branch != "master"
        log_msg = "Deleting branch #{branch}"
        logger.info("#{log_msg} -start")
        cmd_list = ["git",  "branch", "-D", branch]
        shell_cmd(cmd_list, "#{log_msg} - failed")
        logger.info("#{log_msg} -complete")
      end
    end
  end

  def get_pull_requests
    return @client.pull_requests(@orgrepo)
  end

  def get_hooks
    return client.hooks(@orgrepo)
  end

  def pr_comment(pr_num, comment)
    @client.add_comment(@orgrepo, pr_num, comment)
  end

  def delete_pr_comments(pr_num)
    @client.issue_comments(@orgrepo, pr_num).each do | comment |
      @client.delete_comment(@orgrepo, comment.id)
    end
  end
end
