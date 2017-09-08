module Primalize
  class Many
    def self.attributes attrs={}
      @attributes ||= {}
      add_attributes attrs

      @attributes
    end

    def self.add_attributes attrs
      return if attrs.none?

      attrs.each do |attr, serializer_class|
        if serializer_class.nil?
          raise TypeError, "Serializer for #{self}##{attr} cannot be nil"
        end
      end

      @attributes.merge! attrs
    end

    def self.enumerable serializer_class
      Class.new do
        def initialize enumerable
          @enumerable = enumerable
        end

        define_method :call do
          @enumerable.map { |item| serializer_class.new(item).call }
        end

        define_singleton_method :inspect do
          "enumerable(#{serializer_class.inspect})"
        end
      end
    end

    def self.inspect
      "#{name}(#{attributes.map { |attr, serializer| "#{attr}: #{serializer.inspect}" }.join(', ')})"
    end

    def initialize attributes
      @attributes = attributes
    end

    def call
      self.class.attributes.each_with_object({}) do |(attr, serializer_class), hash|
        hash[attr] = serializer_class.new(@attributes.fetch(attr)).call
      end
    end

    def to_json
      call.to_json
    end
  end
end
