require 'puppet/parameter/name'
require 'puppet/property/availability'
require 'puppet/property/description'
require 'puppet/property/monitor'

Puppet::Type.newtype(:f5_pool) do
  @doc = 'Manage pool objects'

  apply_to_device
  ensurable

  newparam(:name, :parent => Puppet::Parameter::F5Name, :namevar => true)
  newproperty(:description, :parent => Puppet::Property::F5Description)
  newproperty(:availability, :parent => Puppet::Property::F5Availability)
  newproperty(:monitor, :array_matching => :all, :parent => Puppet::Property::F5Monitor)

  newproperty(:allow_snat) do
    desc "Allow SNAT?
    Valid options: <true|false>"

    newvalues(:true, :false)
  end

  newproperty(:allow_nat) do
    desc "Allow NAT?
    Valid options: <true|false>"

    newvalues(:true, :false)
  end

  newproperty(:service_down) do
    desc "Action to take when the service is down.
    Valid options: <none|reject|drop|reselect>"

    newvalues('none', 'reject', 'drop', 'reselect')
  end

  newproperty(:slow_ramp_time) do
    options = '<Integer>'
    desc "The slow ramp time for the pool.
    Valid options: #{options}"

    validate do |value|
      fail ArgumentError, "Valid options: #{options}" unless value =~ /^\d+$/
    end
  end

  newproperty(:ip_tos_to_client) do
    options = '<pass-through|mimic|0-255>'
    desc "The IP TOS to the client.
    Valid options: #{options}"

    validate do |value|
      unless value =~ /^(pass-through|mimic)$/ || (value =~ /^\d+$/ && value.to_i.between?(0,255))
        fail ArgumentError, "Valid options: #{options}"
      end
    end
  end

  newproperty(:ip_tos_to_server) do
    options = '<pass-through|mimic|0-255>'
    desc "The IP TOS to the server.
    Valid options: #{options}"

    validate do |value|
      unless value =~ /^(pass-through|mimic)$/ || (value =~ /^\d+$/ && value.to_i.between?(0,255))
        fail ArgumentError, "Valid options: #{options}"
      end
    end
  end

  newproperty(:link_qos_to_client) do
    options = '<pass-through|0-7>'
    desc "The Link TOS to the client.
    Valid options: #{options}"

    validate do |value|
      unless value =~ /^pass-through$/ || (value =~ /^\d+$/ && value.to_i.between?(0,7))
        fail ArgumentError, "Valid options: #{options}"
      end
    end
  end

  newproperty(:link_qos_to_server) do
    options = '<pass-through|0-7>'
    desc "The Link TOS to the server.
    Valid options: #{options}"

    validate do |value|
      unless value =~ /^pass-through$/ || (value =~ /^\d+$/ && value.to_i.between?(0,7))
        fail ArgumentError, "Valid options: #{options}"
      end
    end
  end

  newproperty(:reselect_tries) do
    options = '<Integer>'
    desc "The number of reselect tries to attempt.
    Valid options: #{options}"

    validate do |value|
      fail ArgumentError, "Valid options: #{options}" unless value =~ /^\d+$/ && value.to_i.between?(0,65535)
    end
  end

  newproperty(:request_queuing) do
    desc "Request Queuing?
    Valid options: <true|false>"

    newvalues(:true, :false)
  end

  newproperty(:request_queue_depth) do
    options = '<Integer>'
    desc "The request queue depth.
    Valid options: #{options}"

    validate do |value|
      fail ArgumentError, "Valid options: #{options}" unless value =~ /^\d+$/
    end
  end

  newproperty(:request_queue_timeout) do
    options = '<Integer>'
    desc "The request queue timeout.
    Valid options: #{options}"

    validate do |value|
      fail ArgumentError, "Valid options: #{options}" unless value =~ /^\d+$/
    end
  end

  newproperty(:ip_encapsulation) do
    encapsulations = %w(gre nvgre dslite ip4ip4 ip4ip6 ip6ip4 ip6ip6 ipip)
    encaps_with_partition = encapsulations.map { |e| "/Partition/#{e}|" }
    desc "The request queue timeout.
    Valid options: <#{encaps_with_partition}]"

    validate do |value|
      # We need to check that the value conforms to /Partition/Name, as well
      # as ensuring the Name part is from the above list of encapsulations.
      unless encapsulations.include?(File.basename(value)) && value =~ /^\/\w+\/\w+$/
        fail ArgumentError, "Valid options: <[#{encaps_with_partition}]>"
      end
    end
  end

  newproperty(:load_balancing_method) do
    methods = %w(round-robin ratio-member least-connections-member
    observed-member predictive-member ratio-node least-connection-node
    fastest-node observed-node predictive-node dynamic-ratio-member
    weighted-least-connection-member weighted-least-connection-node
    ratio-session ratio-least-connections-member ratio-least-connection-node)

    desc "The request queue timeout.
    Valid options: <#{methods.join('|')}>"

    validate do |value|
      fail ArgumentError, "Valid options: <#{methods.join('|')}>" unless methods.include?(value)
    end
  end

  newproperty(:ignore_persisted_weight) do
    desc "Ignore persisted weight?
    Valid options: <true|false>"

    newvalues(:true, :false)
  end

  newproperty(:priority_group_activation) do
    options = '<disabled|Integer>'
    desc "The priority group activation (number of nodes) for the pool.
    Valid options: #{options}"

    validate do |value|
      fail ArgumentError, "Valid options: #{options}" unless value =~ /^(disabled|\d+)$/
    end
  end

  newproperty(:members, :array_matching => :all) do
    options = "[{ name => '/Partition/name', port => '1-65535', enable => <true|false> , ratio => <Integer>, connection_limit => <Integer> } ]"
    desc "An array of hashes containing pool members.
    Valid options: #{options}"

    validate do |value|
      # First we check that all required keys exist in the hash.
      [:name, :port, :enable].each do |k|
        fail ArgumentError, "Key #{k} is missing.  Valid options: #{options}" unless value.key?(k)
      end

      # Next we ensure unwanted keys don't exist.
      value.each do |k, v|
        unless [:name, :port, :enable, :ratio, :connection_limit].include?(k)
          fail ArgumentError "Key #{k} is invalid.  Valid options: #{options}"
        end

        # Then we check each value in turn.
        case k.to_sym
        when :name
          fail ArgumentError, "#{v} must be a String" unless v.is_a?(String)
          fail ArgumentError, "#{v} must match the pattern /Partition/name" unless v =~ /^\/\w+\/(\w|\.)+$/
        when :port
          unless v.to_s =~ /^\d+$/ && v.to_i.between?(1,65535)
            fail ArgumentError, "Valid options: #{options}"
          end
        when :enable
          unless v.to_s =~ /^(enabled|disabled|true|false)+$/
            fail ArgumentError, "Valid options: #{options}"
          end
        when :ratio
          unless v.to_s =~ /^\d+$/
            raise ArgumentError, "#{name} must be an Integer"
          end
        when :connection_limit
          unless v.to_s =~ /^\d+$/
            raise ArgumentError, "#{name} must be an Integer"
          end
        end
      end
    end
  end

  validate do
    if ! self[:monitor] && self[:availability]
      fail ArgumentError, 'ERROR:  Availability cannot be set when no monitor is assigned.'
    end

    # You can't have a minimum of more than the total number of monitors.
    if self[:availability] =~ /\d+/
      if Array(self[:monitor]).count < self[:availability].to_i
        fail ArgumentError, 'ERROR:  Availability count cannot be more than the total number of monitors.'
      end
    end

    if self[:monitor].is_a?(Array) && ! self[:availability]
      fail ArgumentError, 'ERROR:  Availability must be set when monitors are assigned.'
    end
  end

end