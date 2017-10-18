require 'primalize/many'
require 'primalize/single'

module Primalize
  RSpec.describe Many do
    let(:user_serializer_class) do
      Class.new(Single) do
        attributes(
          id: integer,
          name: string,
        )

        def self.inspect
          'UserSerializer'
        end
      end
    end

    let(:tweet_serializer_class) do
      Class.new(Single) do
        attributes(
          id: integer,
          body: string,
        )

        def self.inspect
          'TweetSerializer'
        end
      end
    end

    let(:serializer_class) do
      # Within the serializer class, we can't use methods defined on this
      # RSpec context, so we make them local vars here.
      user_serializer_class = self.user_serializer_class
      tweet_serializer_class = self.tweet_serializer_class

      Class.new(Many) do
        attributes(
          user: user_serializer_class,
          tweets: enumerable(tweet_serializer_class),
        )

        def self.name
          'ZOMGSerializer'
        end
      end
    end

    let(:user) { double('User', id: 123, name: 'Jamie') }
    let(:tweets) do
      [
        double('Tweet', id: 1, body: 'hello world!'),
        double('Tweet', id: 2, body: 'serializing for great justice!'),
      ]
    end

    it 'serializes all the things' do
      serializer = serializer_class.new(
        user: user,
        tweets: tweets,
      )

      expected_result = {
        user: { id: 123, name: 'Jamie' },
        tweets: [
          { id: 1, body: 'hello world!' },
          { id: 2, body: 'serializing for great justice!' },
        ],
      }

      expect(serializer.call).to eq(expected_result)
      expect(serializer.to_json).to eq(expected_result.to_json)
    end

    it 'outputs to a pretty format' do
      expect(serializer_class.inspect).to eq 'ZOMGSerializer(user: UserSerializer, tweets: enumerable(TweetSerializer))'
    end

    it 'raises an error if an argument is missing' do
      expect { serializer_class.new(user: double) }
        .to raise_error ArgumentError, /missing.*tweets/
    end

    it 'raises an error if an argument is nil' do
      expect { serializer_class.new(user: nil, tweets: [double]) }
        .to raise_error ArgumentError, /missing.*user/
    end

    it 'does not raise an error if an argument is nil but optional' do
      user_serializer_class = self.user_serializer_class
      serializer_class = Class.new(Many) do
        attributes(user: optional(user_serializer_class))
        self
      end

      expect(serializer_class.new(user: nil).call).to eq(user: nil)
    end

    it 'raises an error if an enumerable argument is not an enumerable' do
      expect {
        serializer_class.new(
          user: double(id: 1, name: 'lol'),
          tweets: Object.new,
        ).call
      }.to raise_error ArgumentError, /must receive an Enumerable object/
    end

    describe 'conversion' do
      let(:serializer) { serializer_class.new(user: user, tweets: tweets) }

      it 'generates JSON' do
        expect(serializer.to_json).to eq('{"user":{"id":123,"name":"Jamie"},"tweets":[{"id":1,"body":"hello world!"},{"id":2,"body":"serializing for great justice!"}]}')
      end

      it 'generates CSV' do
        expect(serializer.to_csv(:user)).to eq <<~CSV
          id,name
          123,Jamie
        CSV

        expect(serializer.to_csv(:tweets)).to eq <<~CSV
          id,body
          1,hello world!
          2,serializing for great justice!
        CSV
      end
    end
  end
end
