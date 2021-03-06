class Middleman::Cli::BuildAction
  def handle_error(file_name, response, e=Thor::Error.new(response))
    our_errors = [GitClient::TokenException, CodeRepo::InvalidSnippet]
    raise e if our_errors.include?(e.class)

    original_handle_error(e, file_name, response)
  end

  private

  def original_handle_error(e, file_name, response)
    base.had_errors = true

    base.say_status :error, file_name, :red
    if base.debugging
      raise e
      exit(1)
    elsif base.options["verbose"]
      base.shell.say response, :red
    end
  end
end

class MiddlemanRunner

  include BookbinderLogger
  include ShellOut

  def run(middleman_dir, template_variables, verbose = false, repos = [])
    log "\nRunning middleman...\n\n"

    # awful hacks to eliminate the impact of global state in middleman. when will it end?
    Middleman::Cli::Build.instance_variable_set(:@_shared_instance, nil)
    ENV['MM_ROOT'] = middleman_dir
    Dir.chdir(middleman_dir) do
      build_command = Middleman::Cli::Build.new [], {:quiet => !verbose}, {}
      Middleman::Cli::Build.shared_instance(verbose).config[:template_variables] = template_variables
      Middleman::Cli::Build.shared_instance(verbose).config[:relative_links] = false
      Middleman::Cli::Build.shared_instance(verbose).config[:subnav_templates] = subnavs_by_dir_name(repos)
      build_command.invoke :build, [], {:verbose => verbose}
    end
  end

  private

  def subnavs_by_dir_name(repos)
    repos.reduce({}) do |final_map, repository|
      namespace = repository.directory.gsub('/', '_')
      template = repository.subnav_template || 'default'

      final_map.merge(namespace => template)
    end
  end
end