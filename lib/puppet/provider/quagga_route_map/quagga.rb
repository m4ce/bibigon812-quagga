Puppet::Type.type(:quagga_route_map).provide :quagga do
  @doc = 'Manages redistribution using quagga'

  @resource_map = {
      :match => {
          :default => [],
          :regexp => /\A\smatch\s(.+)\Z/,
          :template => 'match <%= value %>',
          :type => :array,
      },
      :on_match => {
          :default => :absent,
          :regexp => /\A\son-match\s(.+)\Z/,
          :template => 'on-match <%= value %>',
          :type => :string,
      },
      :set => {
          :default => [],
          :regexp => /\A\sset\s(.+)\Z/,
          :template => 'set <%= value %>',
          :type => :array,
      },
  }

  commands :vtysh => 'vtysh'

  def initialize(value)
    super(value)
    @property_flush = {}
  end

  def self.instances
    providers = []
    found_route_map = false
    hash = {}

    config = vtysh('-c', 'show running-config')
    config.split(/\n/).collect do |line|
      next if line =~ /\A!\Z/

      if line =~ /\Aroute-map\s([\w-]+)\s(deny|permit)\s(\d+)\Z/
        name = $1
        action = $2
        sequence = Integer($3)
        found_route_map = true

        unless hash.empty?
          debug 'Instantiated the route-map %{name}' % {
            :name     => hash[:name],
          }

          providers << new(hash)
        end

        hash = {
            :action   => action.to_sym,
            :ensure   => :present,
            :name     => "#{name} #{sequence}",
            :provider => self.name,
        }

        # Added default values
        @resource_map.each do |property, options|
          if [:array, :hash].include?(options[:type])
            hash[property] = options[:default].clone
          else
            hash[property] = options[:default]
          end
        end

      elsif line =~ /\A\s(match|on-match|set)/ and found_route_map
        @resource_map.each do |property, options|
          if line =~ options[:regexp]
            value = $1

            if value.nil?
              hash[property] = :true
            else
              case options[:type]
                when :array
                  hash[property] << value

                else
                  hash[property] = value
              end
            end

            break
          end
        end

      elsif line =~ /\A\w/ && found_route_map
        break
      end
    end

    unless hash.empty?
      debug 'Instantiated the route-map %{name} %{sequence}' % {
        :name     => hash[:name],
        :sequence => hash[:sequence],
      }

      providers << new(hash)
    end

    providers
  end

  def self.prefetch(resources)
    providers = instances
    resources.keys.each do |name|
      if provider = providers.find { |provider| provider.name == name }
        resources[name].provider = provider
      end
    end
  end

  def create
    name, sequence = @resource[:name].split(/\s/)
    action = @resource[:action]

    debug 'Creating the route-map %{name}' % { :name => @resource[:name] }

    resource_map = self.class.instance_variable_get('@resource_map')

    cmds = []
    cmds << 'configure terminal'
    cmds << "route-map #{name} #{action} #{sequence}"

    resource_map.each do |property, options|
      if @resource[property] and @resource[property] != options[:default]
        case options[:type]
          when :array
            @resource[property].each do |value|
              cmds << ERB.new(options[:template]).result(binding)
            end

          else
            value = @resource[property]
            cmds << ERB.new(options[:template]).result(binding)
        end
      end
    end

    cmds << 'end'
    cmds << 'write memory'

    vtysh(cmds.reduce([]){ |cmds, cmd| cmds << '-c' << cmd })
  end

  def destroy
    name, sequence = @property_hash[:name].split(/\s/)
    action = @property_hash[:action]

    debug 'Destroying the route-map #{name}' % { :name => @property_hash[:name] }

    cmds = []
    cmds << 'configure terminal'
    cmds << "route-map #{name} #{action} #{sequence}"
    cmds << "no #{cmds.last}"
    cmds << 'end'
    cmds << 'write memory'

    vtysh(cmds.reduce([]){|cmds, cmd| cmds << '-c' << cmd})
    @property_hash.clear
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def flush
    # Exit if nothing to do
    return if @property_flush.empty?

    name, sequence = @property_hash[:name].split(/\s/)
    action = @property_hash[:action]

    debug 'Flushing the route-map %{name}' % { :name => @property_hash[:name] }

    resource_map = self.class.instance_variable_get('@resource_map')

    cmds = []

    cmds << 'configure terminal'
    cmds << "route-map #{name} #{action} #{sequence}"

    @property_flush.each do |property, v|
      if v == :false or v == :absent
        cmds << "no #{ERB.new(resource_map[property][:template]).result(binding)}"

      elsif resource_map[property][:type] == :array
        (@property_hash[property] - v).each do |value|
          cmds << "no #{ERB.new(resource_map[property][:template]).result(binding)}"
        end

        (v - @property_hash[property]).each do |value|
          cmds << ERB.new(resource_map[property][:template]).result(binding)
        end

      else
        value = v
        cmds << ERB.new(resource_map[property][:template]).result(binding)
      end

      @property_hash[property] = v
    end

    @property_flush.clear

    cmds << 'end'
    cmds << 'write memory'

    vtysh(cmds.reduce([]){|cmds, cmd| cmds << '-c' << cmd})
  end

  def action
    @property_hash[:action] || :absent
  end

  def action=(value)
    @property_hash[:action] = value
  end

  @resource_map.keys.each do |property|
    define_method "#{property}" do
      @property_hash[property] || :absent
    end

    define_method "#{property}=" do |value|
      @property_flush[property] = value
    end
  end
end
