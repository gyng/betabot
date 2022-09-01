class Bot::Plugin::Image < Bot::Plugin
  # rubocop:disable Metrics/MethodLength
  def initialize(bot)
    @s = {
      trigger: {
        image: [:random_image_link, 0, 'Image scraper plugin. Call this for a random image.'],
        images: [:images_link, 0, 'Gets the images listing webpage.']
      },
      subscribe: true,
      content_type_regex: 'image/.*',
      filters: [
        '(http.*png(\/?\?.*)?$)',
        '(http.*gif(\/?\?.*)?$)',
        '(http.*jpg(\/?\?.*)?$)',
        '(http.*jpeg(\/?\?.*)?$)',
        '(http.*bmp(\/?\?.*)?$)',
        '(http.*webp(\/?\?.*)?$)',
        '(http.*webm(\/?\?.*)?$)',
        '(http.*mp4(\/?\?.*)?$)',
        'http.*format=(jpg|jpeg|png|bmp|gif).*'
      ],
      check_content_type_filter: '^http.*',
      relative_database_path: ['lib', 'databases', 'images.sqlite3'],
      image_directory: ['lib', 'public', 'i'],
      get_google_guess: false
    }
    super(bot)

    @db = Bot::Database.new(File.join(@s[:relative_database_path]))

    if !@db.table_exists?(:images)
      @db.create_table :images do
        primary_key :id
        String      :sha256, size: 64
        String      :md5
        String      :path
        String      :google_description
        Integer     :bytesize
      end
    end

    if !@db.table_exists?(:sources)
      @db.create_table :sources do
        primary_key :id
        foreign_key :image_id, :images, key: :id
        DateTime    :timestamp
        String      :url
        String      :source_name
        String      :context
        String      :filename
      end
    end

    random_proc = lambda do |n|
      @db[:images].order(Sequel.lit('RANDOM()')).limit(n)
    end

    sources_proc = lambda do |image|
      @db[:sources].where(image_id: image[:id]).order(:timestamp)
    end

    return if !defined?(Web)

    Web.get '/i/random' do
      image = random_proc.call(1).to_a.first
      sources = sources_proc.call(image).to_a
      op = sources.first
      path = Web.url + image[:path].gsub('lib/public', '')
      "<!DOCTYPE html>
      <html>
      <body>
        <video autoplay loop poster='#{path}'>
          <source src='#{path}' type='video/webm' />
        </video>
        <ul>
          <li>First posted by: #{op[:source_name]}</li>
          <li>First posted on: #{op[:timestamp]}</li>
          <li>Times seen: #{sources.size}
        </ul>
        <a href='../i'>Image listing</a>
      </body>
      </html>"
    end

    image_directory = @s[:image_directory]
    Web.get '/i' do
      @dir = File.join(image_directory)
      @paths = Dir.entries(@dir).reject { |p| ['.gitignore', '.', '..', 'temp'].include? p }
      erb '
        <!DOCTYPE html>
        <html>
        <body>
          <h2>Image list</h2>
          <a href="../i/random">Random image</a>
          <table>
            <tr>
              <th>Filename</th>
              <th>Last modified</th>
            </tr>
            <% @paths.each do |path| %>
              <tr>
                <td><a href="/i/<%=path%>"><%=path%></a></td>
                <td><%= File.mtime "#{@dir}/#{path}" %></td>
              </tr>
            <% end %>
          </table>
          <p><%= @paths.length %> entries.</p>
        </body>
        </html>'
    end
  end
  # rubocop:enable Metrics/MethodLength

  def random_images(n)
    @db[:images].order(Sequel.lit('RANDOM()')).limit(n).to_a
  end

  def random_image_link(m = nil)
    if defined?(Web)
      image = random_images(1).first
      m.reply Web.url + image[:path].gsub('lib/public', '')
    else
      m.reply 'The web server is disabled.'
    end
  end

  def images_link(m)
    if defined?(Web)
      path = @s[:image_directory].join('/').gsub('lib/public', '')
      m.reply "#{Web.url}#{path}"
    else
      m.reply 'The web server is disabled.'
    end
  end

  def record_if_match_filter(url, m)
    @s[:filters].each do |regex_s|
      regex = Regexp.new(regex_s)
      next if regex.match(url).nil?

      Bot.log.info "#{self.class.name} - Image detected (filter): #{url}"
      record(url, m)
      return true
    end

    false
  end

  def record_if_match_content_type(url, m)
    Thread.new do
      if valid_content_type?(url)
        Bot.log.info "#{self.class.name} - Image detected (content-type): #{url}"
        record(url, m)
      end
    end
  end

  def valid_content_type?(url)
    res = RestClient.head(url)
    res.headers[:content_type] =~ Regexp.new(@s[:content_type_regex])
  rescue StandardError => e
    Bot.log.info "#{self.class.name} - failed to get HEAD for #{url}: #{e}"
    false
  end

  def receive(m)
    return if m.text.nil?

    # Record each URL found in m.text
    tokens = String.new(m.text).split(' ').uniq
    tokens.each do |t|
      next if t !~ URI::DEFAULT_PARSER.make_regexp

      # If it matches our filters we record regardless
      # Else if it matches content types we will record it,
      # even if it doesn't match the filter
      record_if_match_filter(t, m) || record_if_match_content_type(t, m)
    end
  end

  def record(url, m)
    # rubocop:disable Metrics/BlockLength
    Thread.new do
      Bot.log.info("#{self.class.name} - Saving image #{url}...")
      temp_dir = File.join(*@s[:image_directory], 'temp')
      if !File.directory?(temp_dir)
        FileUtils.mkdir_p(temp_dir)
        File.write(File.join(temp_dir, '.gitignore'), "*\n!.gitignore")
        File.write(File.join(*@s[:image_directory], '.gitignore'), "*\n!.gitignore")
      end
      temp_path = File.join(temp_dir, "temp_#{Time.now.to_f}")

      # Grab file. TODO: setup a timeout
      begin
        File.open(temp_path, 'wb') do |f|
          data = RestClient::Request.execute(method: :get, url:, timeout: 300)
          f.write(data)
        end
      rescue StandardError => e
        Bot.log.info("Failed to open image #{url} #{e}")
        File.delete(temp_path)
      end

      # Discard bad file
      File.delete(temp_path) if File.size?(temp_path).nil?

      # Record image if new
      sha256 = Digest::SHA256.file(temp_path).to_s

      if (matched_image = @db[:images].where(sha256:)).to_a.empty?
        # New image
        filetype = File.extname(URI.parse(url).path)
        image_path = File.join(*@s[:image_directory], "#{sha256}#{filetype}")
        FileUtils.mv(temp_path, image_path) if !File.file?(image_path)
        @db.from(:images).insert(
          sha256:,
          md5: Digest::MD5.file(image_path).to_s,
          path: image_path,
          google_description: '',
          bytesize: File.size(image_path)
        )
      else
        # Duplicate
        Bot.log.info "#{self.class.name} - This image is a duplicate."
        File.delete(temp_path)
      end

      # Record source
      @db.from(:sources).insert(
        image_id: matched_image.to_a.first[:id],
        timestamp: Time.now,
        url:,
        source_name: m.sender,
        context: m.text,
        filename: File.basename(URI.parse(url).path)
      )

      Bot.log.info "#{self.class.name} - #{url} saved."
    end
    # rubocop:enable Metrics/BlockLength
  end
end
