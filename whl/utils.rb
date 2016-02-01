module Utils
  #include Logger
  def shell_cmd(cmd_list, err_message)
    stdout, stderr, status = Open3.capture3(*cmd_list)
    if status.success?
      #logger.info(stdout)
      return stdout
    else
      #logger.error(stderr)
      return false
    end
  end
end
