require 'puppet'

module Proxy::Puppet::Support

  # scans a given directory and its sub directory for puppet classes
  # returns an array of PuppetClass objects.
  def scan_directory directory
    # Get a Puppet Parser to parse the manifest source
    parser = Puppet::Parser::Parser.new Puppet::Node::Environment.new
    Dir.glob("#{directory}/*/manifests/**/*.pp").map do |filename|
      scan_manifest File.read(filename), filename, parser
    end.compact.flatten
  end

  private
  def ast_to_value value
    unless value.class.name.start_with? "Puppet::Parser::AST::"
      # Native Ruby types
      case value
        # Supported with exact JSON equivalent
      when NilClass, String, Numeric, Array, Hash, FalseClass, TrueClass
        value
      when Struct
        value.hash
      when Enumerable
        value.to_a
        # Stringified
      when Regexp # /(?:stringified)/
        "/#{value.to_s}/"
      when Symbol # stringified
        value.to_s
      else
        raise TypeError
      end
    else
      # Parser types
      case value
        # Supported with exact JSON equivalent
      when Puppet::Parser::AST::Boolean, Puppet::Parser::AST::String
        value.evaluate nil
        # Supported with stringification
      when Puppet::Parser::AST::Concat
        # This is the case when two params are concatenated together ,e.g. "param_${key}_something"
        # Note1: only simple content are supported, plus variables whose raw name is taken
        # Note2: The variable substitution WON'T be done by Puppet from the ENC YAML output
        value.value.map do |v|
          case v
          when Puppet::Parser::AST::String
            v.evaluate nil
          when Puppet::Parser::AST::Variable
            "${#{v.value}}"
          else
            raise TypeError
          end
        end.join rescue nil
      when Puppet::Parser::AST::Variable
        "${#{value}}"
      when Puppet::Parser::AST::Type
        value.value
      when Puppet::Parser::AST::Name
        (Puppet::Parser::Scope.number?(value.value) or value.value)
      when Puppet::Parser::AST::Undef # equivalent of nil
        nil
        # Depends on content
      when Puppet::Parser::AST::ASTArray
        value.inject([]) { |arr, v| (arr << ast_to_value(v)) rescue arr }
      when Puppet::Parser::AST::ASTHash
        Hash[value.value.each.inject([]) { |arr, (k,v)| (arr << [ast_to_value(k), ast_to_value(v)]) rescue arr }]
      when Puppet::Parser::AST::Function
        value.to_s
        # Let's see if a raw evaluation works with no scope for any other type
      else
        if value.respond_to? :evaluate
          # Can probably work for: (depending on the actual content)
          # - Puppet::Parser::AST::ArithmeticOperator
          # - Puppet::Parser::AST::ComparisonOperator
          # - Puppet::Parser::AST::BooleanOperator
          # - Puppet::Parser::AST::Minus
          # - Puppet::Parser::AST::Not
          # May work for:
          # - Puppet::Parser::AST::InOperator
          # - Puppet::Parser::AST::MatchOperator
          # - Puppet::Parser::AST::Selector
          # Probably won't work for
          # - Puppet::Parser::AST::Variable
          # - Puppet::Parser::AST::HashOrArrayAccess
          # - Puppet::Parser::AST::ResourceReference
          value.evaluate nil
        else
          raise TypeError
        end
      end
    end
  end

end
