class Cli
  class RunPublishCI < BookbinderCommand
    def child_run(_)
      check_params
      (
      (0 == Publish.new.run(['github'])) &&
          (0 == PushLocalToStaging.new.run([])) &&
          (0 == BuildAndPushTarball.new.run([]))
      ) ? 0 : 1
    end

    def check_params
      raise BuildAndPushTarball::MissingBuildNumber unless ENV['BUILD_NUMBER']
      config.fetch('book_repo')
    end
  end
end
