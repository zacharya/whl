require 'octokit'
require 'open3'
require_relative 'logger'

include Logging

class GHWrapper
  def initialize(token)
    @client=Octokit::Client.new(
      :access_token => token
    )
    @org = "zachs-org"
    @repo = "#{@org}/test_repo"
    @repo_base = "/tmp/github/test_repo"
    @giturl = "git@github.com:#{@org}/#{@repo.split('/')[1]}.git"
  end

  def list_prs
    @client.pull_requests(@repo).each do | pr |
      puts "PR: #{pr.number}"
      puts "Author: #{pr.user.login}"
      puts "Comments:"
      @client.issue_comments(@repo, pr.number).each do | comment |
        puts "Comment at #{comment.created_at}: #{comment.body}"
      end
    end
  end

  def pr_comment(pr_num, comment)
    @client.add_comment(@repo, pr_num, comment)
  end

  def delete_pr_comments(pr_num)
    @client.issue_comments(@repo, pr_num).each do | comment |
      @client.delete_comment(@repo, comment.id)
    end
  end

  def clone_repo()
    logger.info("GH CLONE!!!")
    stdout, stderr, status = Open3.capture3("git", "clone", @giturl, @repo_base)
    puts stdout, stderr, status
  end
end
