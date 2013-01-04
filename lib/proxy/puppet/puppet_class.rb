require 'puppet'
require 'proxy/puppet/support'

module Proxy::Puppet

  class PuppetClass

    class << self
      include Proxy::Puppet::Support

      def scan_manifest manifest, filename = '', parser = nil
        klasses = []
        # Get a Puppet Parser to parse the manifest source
        parser ||= Puppet::Parser::Parser.new(Puppet::Node::Environment.new)
        already_seen = Set.new parser.known_resource_types.hostclasses.keys
        already_seen << '' # Prevent the toplevel "main" class from matching
        ast = parser.parse manifest
        # Get the parsed representation of the top most objects
        hostclasses = ast.respond_to?(:instantiate) ? ast.instantiate('') : ast.hostclasses.values
        hostclasses.each do |klass|
          # Only look at classes
          if klass.type == :hostclass and not already_seen.include? klass.namespace
            params = {}
            # Get parameters and eventual default values
            klass.arguments.each do |name, value|
              params[name] = ast_to_value(value) rescue nil
            end
            klasses << new(klass.namespace, params)
          end
        end
        klasses
      rescue => e
        puts "Error while parsing #{filename}: #{e}"
        klasses
      end

    end

    def initialize name, params = {}
      @klass  = name || raise("Must provide puppet class name")
      @params = params
    end

    def to_s
      self.module.nil? ? name : "#{self.module}::#{name}"
    end

    # returns module name (excluding of the class name)
    def module
      klass[0..(klass.index("::")-1)] if has_module?(klass)
    end

    # returns class name (excluding of the module name)
    def name
      has_module?(klass) ? klass[(klass.index("::")+2)..-1] : klass
    end

    attr_reader :params

    private
    attr_reader :klass

    def has_module?(klass)
      !!klass.index("::")
    end

  end
end

