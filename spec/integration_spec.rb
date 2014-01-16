require 'spec_helper'

describe '$ bookbinder' do
  include_context 'tmp_dirs'
  let(:config_body) do
    {
        'repos' => [
            {'github_repo' => 'foo/dogs-repo', 'directory' => 'temporarily-dogs'},
            {'github_repo' => 'baz/my-docs-repo', 'directory' => 'docs-for-now'},
        ],
        'template_variables' => {'a' => 'b'},
        'public_host' => 'example.com'
    }
  end

  around do |example|
    temp_library = tmp_subdir 'fantastic-library'
    temp_book = FileUtils.mkdir_p(File.join temp_library, 'fantastic-book').pop

    `touch #{temp_book}/config.yml`
    `mkdir #{temp_book}/master_middleman`
    `echo '#{config_body.to_yaml}' > #{temp_book}/config.yml`
    FileUtils.cp_r 'spec/fixtures/markdown_repos/my-docs-repo', temp_library
    FileUtils.cp_r 'spec/fixtures/markdown_repos/dogs-repo', temp_library

    FileUtils.cd(temp_book) { example.run }
  end

  describe 'publish' do
    describe 'local' do
      it 'generates a sinatra app' do
        `#{GEM_ROOT}/bin/bookbinder publish local`

        index_html = File.read File.join('final_app', 'public', 'docs-for-now', 'index.html')
        index_html.should include 'This is a Markdown Page'
      end

      it 'creates a PDF file'
    end

    describe 'github' do
      xit 'generates a sinatra app' do
        `#{GEM_ROOT}/bin/bookbinder publish github`

        index_html = File.read File.join('final_app', 'public', 'docs-for-now', 'index.html')
        index_html.should include 'This is a Markdown Page'
      end

      context 'when no config.yml credentials are provided' do
        it 'generates a sinatra app'
      end
    end
  end

  describe 'run_publish_ci' do
    let(:run_publish_ci) { system("#{GEM_ROOT}/bin/bookbinder run_publish_ci") }

    it 'builds and pushes a tarball'
    it 'pushes local to staging'
    it 'publishes'
  end
end