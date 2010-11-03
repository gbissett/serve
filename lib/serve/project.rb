require 'pathname'
require 'serve/out'

module Serve #:nodoc:
  #
  # Serve::Project.new(options).create
  # Serve::Project.new(options).convert
  #
  class Project #:nodoc:
    attr_reader :name, :location, :framework
    
    def initialize(options)
      @name       = options[:name]
      @location   = normalize_location(options[:directory], @name)
      @full_name  = git_config('user.name') || 'Your Full Name'
      @framework  = options[:framework]
    end
    
    # Create a new Serve project
    def create
      setup_base
      %w(
        public/images
        public/javascripts
        public/stylesheets
        sass
      ).each { |path| make_path path } 
      install_javascript_framework
    end
    
    # Convert an existing Compass project to a Serve project
    def convert
      setup_base
      move_file 'images', 'public/'
      move_file 'stylesheets', 'public/'
      move_file 'javascripts', 'public/'
      move_file 'src', 'sass'
      install_javascript_framework
      note_old_compass_config
    end
    
    private
      
      include Serve::Out
      
      # Files required for both a new server project and for an existing compass project.
      def setup_base
        %w(
          .
          public
          tmp
          views
        ).each { |path| make_path path }
        create_file 'config.ru',       config_ru
        create_file 'LICENSE',         license
        create_file '.gitignore',      gitignore
        create_file 'compass.config',  compass_config
        create_file 'README.markdown', readme
        create_empty_file 'tmp/restart.txt'
      end
      
      # Install a JavaScript framework if one was specified
      def install_javascript_framework
        if @framework
          log_action 'installing', @framework
          Serve::JavaScript.new(@location).install(@framework)
        end
      end
      
      # Display note about old compass config if it exists
      def note_old_compass_config
        old_config = normalize_path(@location, 'config.rb')
        if File.exists? old_config
          puts ""
          puts "============================================================================"
          puts " Please Note: You still need to copy your unique settings from config.rb to "
          puts " compass.config. Remove config.rb when you are finished."
          puts "============================================================================"
          puts ""
        end
      end
      
      # Read template for compass.config
      def compass_config
        read_template 'compass_config'
      end
      
      # Read template for config.ru
      def config_ru
        read_template 'config_ru'
      end
      
      # Read template for .gitignore file
      def gitignore
        read_template 'gitignore'
      end
      
      # Read template for project license
      def license
        read_template 'license'
      end
      
      # Read template for project README
      def readme
        read_template 'readme'
      end
      
      # Read and eval a template by name
      def read_template(name)
        contents = IO.read(normalize_path(File.dirname(__FILE__), "templates", name))
        instance_eval "%{#{contents}}"
      end
      
      # Create a file with contents
      def create_file(file, contents)
        path = normalize_path(@location, file)
        unless File.exists? path
          log_action "create", path
          File.open(path, 'w+') { |f| f.puts contents }
        else
          log_action "exists", path
        end
      end
      
      # Create an empty file
      def create_empty_file(file)
        path = normalize_path(@location, file)
        FileUtils.touch(path)
      end
      
      
      # Make every directory in a given path
      def make_path(path)
        path = normalize_path(@location, path)
        unless File.exists? path
          log_action "create", path
          FileUtils.mkdir_p(path)
        else
          log_action "exists", path
        end
      end
      
      # Move a file from => to (relative to the project location)
      def move_file(from, to)
        from_path = normalize_path(@location, from)
        to_path = normalize_path(@location, to)
        if File.exists? from_path
          to = to + from if to[-1..-1] == "/"
          log_action "move", "#{@location}/{#{from} => #{to}}"
          FileUtils.mv from_path, to_path
        end
      end
      
      # Convert dashes and spaces to underscores
      def underscore(string)
        string.gsub(/-|\s+/, '_')
      end
            
      # Grab data by key from the git config file if it exists
      def git_config(key)
        value = `git config #{key}`.chomp
        value.empty? ? nil : value
      end
      
      # Normalize the path of the target directory
      def normalize_location(path, name = nil)
        path = File.join(path, underscore(name)) if name
        path = normalize_path(path)
        path
      end
      
      # Normalize a path relative to the current working directory
      def normalize_path(*paths)
        path = File.join(*paths)
        Pathname.new(File.expand_path(path)).relative_path_from(Pathname.new(Dir.pwd)).to_s
      end
      
  end
end