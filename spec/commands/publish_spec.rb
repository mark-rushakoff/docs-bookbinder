require 'spec_helper'

describe Cli::Publish do
  include_context 'tmp_dirs'
  around do |spec|
    temp_library = tmp_subdir 'markdown_repos'
    book_dir = File.join temp_library, 'book'
    FileUtils.cp_r 'spec/fixtures/markdown_repos/.', temp_library
    FileUtils.cd(book_dir) { spec.run }
  end

  context 'local' do
    it 'creates some static HTML' do
      Cli::Publish.new.run ['local']

      index_html = File.read File.join('final_app', 'public', 'dogs', 'index.html')
      index_html.should include 'Woof'
    end
  end

  context 'github' do
    before do
      GitClient.any_instance.stub(:archive_link)
      stub_github_for 'fantastic/dogs-repo', 'dog-sha'
      stub_github_for 'fantastic/my-docs-repo', 'my-docs-sha'
      stub_github_for 'fantastic/my-other-docs-repo', 'my-other-sha'
    end

    it 'creates some static HTML' do
      Cli::Publish.new.run ['github']

      index_html = File.read File.join('final_app', 'public', 'foods', 'sweet', 'index.html')
      index_html.should include 'This is a Markdown Page'
    end

    context 'when a tag is provided' do
      let(:desired_tag) { 'foo-1.7.12' }
      let(:cli_args) { [desired_tag] }

      it 'gets the book at that tag' do
        stub_github_for 'fantastic/dogs-repo', desired_tag
        stub_github_for 'fantastic/my-docs-repo', desired_tag
        stub_github_for 'fantastic/my-other-docs-repo', desired_tag

        zipped_repo_url = "https://github.com/#{'fantastic/fixture-book-title'}/archive/#{desired_tag}.tar.gz"
        GitClient.any_instance.stub(:archive_link).with('fantastic/fixture-book-title', ref: desired_tag).and_return zipped_repo_url

        zipped_repo = MarkdownRepoFixture.tarball 'fantastic/book'.split('/').last, desired_tag
        stub_request(:get, zipped_repo_url).to_return(
            :body => zipped_repo, :headers => {'Content-Type' => 'application/x-gzip'}
        )

        Cli::Publish.new.run cli_args
      end

      context 'when a constituent repository does not have the tag'
      context 'when a book does not have the tag'
    end
  end
end