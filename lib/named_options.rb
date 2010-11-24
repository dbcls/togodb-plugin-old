class NamedOptions < HashWithIndifferentAccess
  attr_reader :names

  def initialize(runtime_args, *names)
    static_defaults  = names.last.is_a?(Hash) ? names.pop : {}
    dynamic_defaults = runtime_args.last.is_a?(Hash) ? runtime_args.pop : {}

    super( static_defaults.merge(dynamic_defaults) )
    @names = names

    runtime_args.each_with_index do |value, i|
      key = names[i] or
        raise IndexError, "expect %d args but got %s args, that is %s" %
          [names.size, (i+1).ordinalize, runtime_args.inspect]
      self[key] = value
    end
  end

  def named_values
    names.map{|name| self[name]}
  end

  def method_missing(name, *args)
    if name.to_s =~ /(.*)=$/
      self[$1.to_sym] = args.first
    else
      self[name]
    end
  end
end
