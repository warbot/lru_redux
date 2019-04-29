module LruRedux
  module TTL
    class Cache
      attr_reader :max_size, :ttl

      def initialize(*args)
        max_size, ttl = args

        ttl ||= :none

        raise ArgumentError.new(:max_size) if
        max_size < 1
        raise ArgumentError.new(:ttl) unless
        ttl == :none || ((ttl.is_a? Numeric) && ttl >= 0)

        @max_size = max_size
        @ttl = ttl
        @data_ttl = {}
        @cache = ::LruRedux::Cache.new(max_size)
      end

      def max_size=(max_size)
        @cache.max_size = max_size
      end

      def ttl=(ttl)
        ttl ||= @ttl

        raise ArgumentError.new(:ttl) unless
        ttl == :none || ((ttl.is_a? Numeric) && ttl >= 0)

        @ttl = ttl

        ttl_evict
      end

      def getset(key, &block)
        ttl_evict

        result = @cache.getset(key, &block)
        @data_ttl[key] = Time.now.to_f

        if @cache.count > @max_size
          key, _ = @cache.first

          @data_ttl.delete(key)
        end

        result
      end

      def fetch(key)
        ttl_evict

        @cache.fetch(key)
      end

      def [](key)
        ttl_evict

        @cache[key]
      end

      def []=(key, val)
        ttl_evict

        @cache[key] = val
        @data_ttl.delete(key)
        @data_ttl[key] = Time.now.to_f

        if @cache.count > @max_size
          key, _ = @cache.first

          @data_ttl.delete(key)
        end

        val
      end

      def each(&block)
        ttl_evict

        @cache.each &block
      end

      # used further up the chain, non thread safe each
      alias_method :each_unsafe, :each

      def to_a
        ttl_evict

        @cache.to_a
      end

      def values
        ttl_evict

        @cache.values
      end

      def delete(key)
        ttl_evict

        @data_ttl.delete(key)
        @cache.delete(key)
      end

      alias_method :evict, :delete

      def key?(key)
        ttl_evict

        @cache.key?(key)
      end

      alias_method :has_key?, :key?

      def clear
        @cache.clear
        @data_ttl.clear
      end

      def expire
        ttl_evict
      end

      def count
        @cache.count
      end

      protected

      # for cache validation only, ensures all is sound
      def valid?
        @cache.count == @data_ttl.size
      end

      def ttl_evict
        return if @ttl == :none

        ttl_horizon = Time.now.to_f - @ttl
        key, time = @data_ttl.first

        until time.nil? || time > ttl_horizon
          @data_ttl.delete(key)
          @cache.delete(key)

          key, time = @data_ttl.first
        end
      end

      def resize
        ttl_evict

        @cache.resize

        while @cache.count > @max_size
          key, _ = @cache.first

          @data_ttl.delete(key)
        end
      end
    end
  end
end
