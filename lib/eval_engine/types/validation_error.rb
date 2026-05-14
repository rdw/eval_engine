module EvalEngine
  module Types
    class ValidationError < StandardError
      attr_reader :tree

      def initialize(tree)
        @tree = tree
        super(self.class.format_tree(tree))
      end

      def self.format_tree(tree, path = [])
        return "" unless tree.is_a?(Hash)

        lines = []
        Array(tree["errors"]).each do |msg|
          prefix = path.empty? ? "" : "#{path.join(".")}: "
          lines << "#{prefix}#{msg}"
        end

        case tree["children"]
        when Hash
          tree["children"].each do |key, child|
            sub = format_tree(child, path + [key.to_s])
            lines << sub unless sub.empty?
          end
        when Array
          tree["children"].each_with_index do |child, i|
            next unless child

            sub = format_tree(child, path + ["[#{i}]"])
            lines << sub unless sub.empty?
          end
        end

        lines.join("\n")
      end
    end

    class DuplicateKeyError < StandardError
    end
  end

  class ConfigurationError < StandardError
  end
end
