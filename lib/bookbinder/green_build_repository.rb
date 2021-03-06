class GreenBuildRepository

  class FileDoesNotExist < StandardError; end
  class NoNamespaceGiven < StandardError; end

  include BookbinderLogger

  def initialize(key: '', secret: '')
    @aws_key = key
    @aws_secret_key = secret
  end

  def create(build_number: nil, app_dir: 'final_app', bucket: '', namespace: nil)
    raise 'You must provide a build_number to push an identifiable build.' unless build_number
    raise 'You must provide a namespace to push an identifiable build.' unless namespace

    directory = connection.directories.create key: bucket

    tarball_filename = "#{namespace}-#{build_number}.tgz"
    tarball_path = File.join(Dir.mktmpdir, tarball_filename)

    Dir.chdir(app_dir) { `tar czf #{tarball_path} *` }

    directory.files.create :key => tarball_filename,
                           :body => File.read(tarball_path),
                           :public => true
    log "Green build ##{build_number.to_s.green} has been uploaded to S3 for #{namespace.cyan}"
  end

  def download(download_dir: nil, bucket: nil, build_number: nil, namespace: nil)
    raise NoNamespaceGiven, 'One must specify a namespace to find files in this bucket' unless namespace

    directory = connection.directories.get bucket
    build_number ||= highest_build_number_for_namespace(directory, namespace)
    filename = "#{namespace}-#{build_number}.tgz"

    s3_file = directory.files.get(filename)
    raise FileDoesNotExist, "Unable to find tarball on AWS for book '#{namespace}', build number: #{build_number}" unless s3_file

    downloaded_file = File.join(Dir.mktmpdir, 'downloaded.tgz')
    File.open(downloaded_file, 'wb') { |f| f.write(s3_file.body) }
    Dir.chdir(download_dir) { `tar xzf #{downloaded_file}` }

    log "Green build ##{build_number.to_s.green} has been downloaded from S3 and untarred into #{download_dir.cyan}"
  end

  private

  def highest_build_number_for_namespace(directory, namespace)
    directory.files.map(&:key).map do |key|
      matches = /^#{namespace}-([\d]+)\.tgz/.match(key)
      matches[1] if matches
    end.map(&:to_i).max
  end

  def connection
    @connection ||= Fog::Storage.new :provider => 'AWS',
                                     :aws_access_key_id => @aws_key,
                                     :aws_secret_access_key => @aws_secret_key
  end
end