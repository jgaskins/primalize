require 'primalize/single'
require 'time'

module Primalize
  RSpec.describe Single do
    order_serializer_class = Class.new(Single) do
      attributes(
        price_cents: integer,
        payment_method: string,
      )
    end

    serializer_class = Class.new(Single) do
      attributes(
        id: integer,
        name: string,
        nicknames: array(string),
        active: boolean,
        options: object(
          color: string,
          count: integer,
        ),
        rating: float,
        address: optional(string),
        state: enum(1, 2, 3, 4),
        order: primalize(order_serializer_class),
        value: number,
        loosely_defined: any(string, integer),
        created_at: timestamp,
      )
    end

    let(:default_attrs) do
      {
        id: 123,
        name: 'Foo',
        nicknames: %w(Bar Baz),
        active: true,
        options: {
          color: 'red',
          count: 12,
        },
        rating: 3.5,
        address: '123 Main St',
        state: 1,
        order: double(
          price_cents: 123_45,
          payment_method: 'card_123456',
        ),
        value: 21.3,
        loosely_defined: 'wat',
        created_at: Time.new(1999, 12, 31, 23, 59, 59),
      }
    end

    it 'serializes to a hash' do
      serializer = serializer_class.new(double(default_attrs))

      actually_serialized_things = {
        order: { # converted to a hash from a proper object
          price_cents: 12345,
          payment_method: 'card_123456',
        },
      }

      expect(serializer.call).to eq(default_attrs.merge(actually_serialized_things))
    end

    it 'allows nils for optional types' do
      serializer = serializer_class.new(double(default_attrs.merge(address: nil)))

      expect(serializer.call.fetch(:address)).to be_nil
    end

    [
      { id: 'abc' },
      { id: nil },
      { name: 123 },
      { name: nil },
      { nicknames: 'single string instead of an array' },
      { nicknames: nil },
      { active: nil },
      { active: 1 },
      { active: 'true' },
      { options: {} }, # The right type, but without required keys
      { options: [] },
      { options: 12 },
      { rating: nil },
      { rating: 'abc' },
      { address: 123 },
      { created_at: nil },
      { order: nil },
      { loosely_defined: nil },
    ].each do |attrs|
      attr, value = attrs.first
      type = serializer_class.attributes[attr].inspect

      it "raises an error if an expected #{type} is actually a #{value.class}" do
        serializer = serializer_class.new(double(default_attrs.merge(attr => value)))

        expect { serializer.call }.to raise_error TypeError
      end
    end

    it 'checks the return type of a method defined by the primalizer' do
      my_serializer = Class.new(Single) do
        attributes(foo: string)

        def foo
          object.bar
        end
      end

      expect { my_serializer.new(double(bar: 'baz')).call }.not_to raise_error
      expect { my_serializer.new(double(bar: nil)).call }
        .to raise_error TypeError
    end

    it 'allows a handler to be set on a type mismatch' do
      serializer_class.type_mismatch_handler = proc do |klass, attr, type, value|
        expect(klass).to be serializer_class
        expect(attr).to eq :name
        expect(value).to eq 12
        expect(type).to be_a Single::String
      end

      serializer = serializer_class.new(double(default_attrs.merge(name: 12)))

      serializer.call
    end

    it 'allows overriding the method from the object to coerce values' do
      my_serializer = Class.new(Single) do
        attributes(
          name: string,
        )

        def name
          object.name.capitalize
        end
      end
      object = double(name: 'jamie')

      serializer = my_serializer.new(object)

      expect(serializer.call).to eq(name: 'Jamie')
    end

    it 'allows blocks to coerce values' do
      my_serializer = Class.new(Single) do
        attributes(
          id: integer { |value| value.abs },
          name: string { |value| value.to_s.capitalize },
          nicknames: array(string) { |value| value.map(&:downcase) },
          active: boolean { |value| value == 'true' },
          options: object(
            color: string,
            count: integer,
          ) { |value|
            {
              color: 'black',
              count: 0,
            }.merge(value.to_h)
          },
          rating: float { |value| value.to_f.abs },
          address: optional(string) { |value| 'omg' },
          state: enum(1, 2, 3, 4) { |value, allowed_values|
            if allowed_values.include?(value)
              value
            else
              allowed_values.first
            end
          },
          value: number { |value| value.to_i },
          loosely_defined: any(string, integer) { |lol| lol.to_s },
          created_at: timestamp { |created_at|
            Time.parse(created_at)
          },
        )
      end

      created_at = Time.new(2017, 9, 16, 12, 57, 0, '-04:00')
      object = double(
        id: -123,
        name: 'jamie',
        nicknames: %w(Foo Bar Baz),
        active: 'true',
        options: {},
        rating: -5.0,
        address: 'this string is ignored',
        state: 12,
        value: nil,
        loosely_defined: nil,
        created_at: created_at.iso8601,
      )

      expect(my_serializer.new(object).call).to eq(
        id: 123,
        name: 'Jamie',
        nicknames: ['foo', 'bar', 'baz'],
        active: true,
        options: {
          color: 'black',
          count: 0,
        },
        rating: 5.0,
        address: 'omg',
        state: 1,
        value: 0,
        loosely_defined: '',
        created_at: created_at,
      )
    end

    describe 'pretty inspect' do
      it 'outputs a pretty inspect' do
        def serializer_class.name
          'StuffSerializer'
        end

        def order_serializer_class.inspect
          'OrderSerializer'
        end

        # Wacky transformations to make the expected output easier to read
        expected = <<~EOF.strip.gsub(/\s+/, ' ').gsub(/(\() | (\))/) { |match| match.strip }
        StuffSerializer(
          id: integer,
          name: string,
          nicknames: array(string),
          active: enum(true, false),
          options: object(
            color: string,
            count: integer
          ),
          rating: float,
          address: optional(string),
          state: enum(1, 2, 3, 4),
          order: primalize(OrderSerializer),
          value: number,
          loosely_defined: any(string, integer),
          created_at: timestamp
        )
        EOF

        expect(serializer_class.inspect).to eq expected
      end

      {
        serializer_class.integer => 'integer',
        serializer_class.string => 'string',
        serializer_class.array(serializer_class.string) => 'array(string)',
        serializer_class.array(serializer_class.integer) => 'array(integer)',
        serializer_class.boolean => 'enum(true, false)',
        serializer_class.enum(1, 2, 3) => 'enum(1, 2, 3)',
        serializer_class.any(
          serializer_class.string,
          serializer_class.integer,
        ) => 'any(string, integer)',
        serializer_class.number => 'number',
        serializer_class.float => 'float',
        serializer_class.optional(serializer_class.number) => 'optional(number)',
        serializer_class.primalize(order_serializer_class) => 'primalize(OrderSerializer)',
        serializer_class.object(key: serializer_class.string) => 'object(key: string)',
        serializer_class.timestamp => 'timestamp',
      }.each do |type, expected_output|
        it "pretty-prints #{type} as #{expected_output}" do
          expect(type.inspect).to eq expected_output
        end
      end
    end

    describe 'conversion' do
      let(:obj) { double(hello: 'world') }
      let(:my_serializer) do
        Class.new(Single) do
          attributes(hello: string)
        end
      end
      let(:serializer) { my_serializer.new(obj) }

      it 'converts to JSON' do
        expect(serializer.to_json).to eq '{"hello":"world"}'
      end

      it 'converts to CSV' do
        expect(serializer.csv_headers).to eq ['hello']
        expect(serializer.to_csv).to eq <<~CSV
          world
        CSV
      end
    end
  end
end
