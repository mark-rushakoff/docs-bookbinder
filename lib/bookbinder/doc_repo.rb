class DocRepo < Repository

  attr_reader :subnav_template, :copied_to

  def self.from_remote(repo_hash: {}, github_token: ENV['GITHUB_API_TOKEN'], destination_dir: nil, target_tag: nil)
    repo = self.new(repo_hash, github_token, nil, target_tag)
    repo.copy_from_remote(destination_dir) if destination_dir
    repo
  end

  def self.from_local(repo_hash: {}, local_dir: '', destination_dir: nil)
    repo = self.new(repo_hash, nil, local_dir, nil)
    repo.copy_from_local(destination_dir) if destination_dir
    repo
  end

  def copied?
    !@copied_to.nil?
  end

  def has_tag?(tagname)
    tags.any? { |tag| tag.name == tagname }
  end

  def copy_from_local(destination_dir)
    path_to_local_repo = File.join(@local_repo_dir, short_name)
    if File.exist?(path_to_local_repo)
      log '  copying '.yellow + path_to_local_repo
      FileUtils.cp_r path_to_local_repo, File.join(destination_dir, directory)
      @copied_to = File.join(destination_dir, directory)
    else
      log '  skipping (not found) '.magenta + path_to_local_repo
    end
  end

  def initialize(repo_hash, github_token, local_repo_dir, target_tag)
    @github = GitClient.get_instance(access_token: github_token) unless local_repo_dir

    @ref = target_tag || repo_hash['sha']
    @full_name = repo_hash.fetch('github_repo')
    @directory = repo_hash['directory']
    @local_repo_dir = local_repo_dir
    @subnav_template = repo_hash['subnav_template']
  end
end