# encoding: utf-8
module RailsBestPractices
  module Core
    # A Check class that takes charge of checking the sexp.
    class Check

      CONTROLLER_FILES = /controllers\/.*\.rb$/
      MIGRATION_FILES = /db\/migrate\/.*\.rb$/
      MODEL_FILES = /models\/.*\.rb$/
      MAILER_FILES = /models\/.*mailer\.rb$|mailers\/.*mailer\.rb/
      VIEW_FILES = /views\/.*\.(erb|haml)$/
      PARTIAL_VIEW_FILES = /views\/.*\/_.*\.(erb|haml)$/
      ROUTE_FILES = /config\/routes(.*)?\.rb/
      SCHEMA_FILE = /db\/schema\.rb/
      HELPER_FILES = /helpers.*\.rb$/

      attr_reader :errors

      def initialize
        @errors = []
      end

      # default interesting nodes.
      def interesting_nodes
        []
      end

      # default interesting files.
      def interesting_files
        /.*/
      end

      # delegate to start_### according to the sexp_type, like
      #
      #     start_call
      #     start_def
      #
      # @param [Sexp] node
      def node_start(node)
        @node = node
        Array(self.class.callbacks["start_#{node.sexp_type}"]).each do |callback|
          self.instance_exec node, &callback
        end
        self.send("start_#{node.sexp_type}", node)
      end

      # delegate to end_### according to the sexp_type, like
      #
      #     end_call
      #     end_def
      #
      # @param [Sexp] node
      def node_end(node)
        @node = node
        Array(self.class.callbacks["end_#{node.sexp_type}"]).each do |callback|
          self.instance_exec node, &callback
        end
        self.send("end_#{node.sexp_type}", node)
      end

      # add error if source code violates rails best practice.
      #   error is the string message for violation of the rails best practice
      #   file is the filename of source code
      #   line is the line number of the source code which is reviewing
      def add_error(error, file = @node.file, line = @node.line)
        @errors << RailsBestPractices::Core::Error.new("#{file}", "#{line}", error, url)
      end

      # default url is empty.
      #
      # @return [String] the url of rails best practice
      def url
        ""
      end

      # method_missing to catch all start and end process for each node type, like
      #
      #     start_def
      #     end_def
      #     start_call
      #     end_call
      #
      # if there is a "debug" method defined in check, each node will be output.
      def method_missing(method_name, *args)
        if method_name.to_s =~ /^start_/
          p args if respond_to?(:debug)
        elsif method_name.to_s =~ /^end_/
          # nothing to do
        else
          super
        end
      end

      class <<self
        def callbacks
          @callbacks ||= {}
        end

        def add_callback(name, &block)
          callbacks[name] ||= []
          callbacks[name] << block
        end
      end

      module Classable
        def self.included(base)
          base.class_eval do
            # remember module name
            add_callback "start_module" do |node|
              modules << node.module_name
            end

            # end of the module.
            add_callback "end_module" do
              modules.pop
            end
          end
        end

        # get the class name with module name.
        def class_name(node)
          class_name = node.class_name.to_s
          if modules.empty?
            class_name
          else
            modules.map { |modu| "#{modu}::" }.join("") + class_name
          end
        end

        def modules
          @moduels ||= []
        end
      end

      module AccessControl
        def self.included(base)
          base.class_eval do
            # remember the current access control for methods.
            add_callback "start_var_ref" do |node|
              case node.to_s
              when "public" then @access_control = "public"
              when "protected" then @access_control = "protected"
              when "private" then @access_control = "private"
              else
              end
            end
          end

          def access_control
            @access_control ||= "public"
          end
        end
      end
    end
  end
end
