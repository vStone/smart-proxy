require 'puppet'
require 'proxy/puppet/support'

module Proxy::Puppet

  class PuppetDefinition

    class << self
      include Proxy::Puppet::Support

      def scan_manifest manifest, filename = '', parser = nil
        definitions = []
        # Get a Puppet Parser to parse the manifest source
        parser ||= Puppet::Parser::Parser.new(Puppet::Node::Environment.new)
        already_seen = Set.new parser.known_resource_types.hostclasses.keys
        already_seen << '' # Prevent the toplevel "main" class from matching
        ast = parser.parse manifest
        # Get the parsed representation of the top most objects
        hostclasses = ast.respond_to?(:instantiate) ? ast.instantiate('') : ast.hostclasses.values
        hostclasses.each do |klass|
          # Only look at classes
          if klass.type == :definition and not already_seen.include? klass.namespace
            params = {}
            # Get parameters and eventual default values
            klass.arguments.each do |name, value|
              params[name] = ast_to_value(value) rescue nil
            end
            definitions << new(klass.name, params)
          end
        end
        definitions
      rescue => e
        puts "Error while parsing #{filename}: #{e}"
        definitions
      end

    end

    def initialize name, params = {}
      @definition = name || raise("Must provide puppet class name")
      @params = params
    end

    def to_s
      self.module.nil? ? name : "#{self.module}::#{name}"
    end

    # returns module name (excluding of the class name)
    def module
      definition[0..(definition.index("::")-1)] if has_module?(definition)
    end

    # returns class name (excluding of the module name)
    def name
      has_module?(definition) ? definition[(definition.index("::")+2)..-1] : definition
    end

    attr_reader :params

    private
    attr_reader :definition

    def has_module?(definition)
      !!definition.index("::")
    end

  end
end

