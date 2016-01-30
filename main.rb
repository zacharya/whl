require_relative './whl/gh'
require_relative './whl/httpd'
require_relative './whl/logger'

include Logging

logger.info("Program start")
gh = GHWrapper.new('xxx')
gh.delete_pr_comments(1)
gh.pr_comment(1, "Test from modular ruby!")
gh.pr_comment(1, "Stuff for comment testing.")

s = HTTPD.new(gh)
logger.info("Starting httpd")
s.start()
