require 'aws-sdk-cloudformation'

# See https://github.com/inspec/inspec/blob/master/docs/dev/plugins.md#implementing-input-plugins

module InspecPlugins::CloudFormation
  class Input < Inspec.plugin(2, :input)

    VALID_PATTERNS = [
      Regexp.new("^databag://[^/]+/[^/]+/.+$"),
      Regexp.new("^node://[^/]*/attributes/.+$"),
    ].freeze

    attr_reader :plugin_conf
    attr_reader :priority
    attr_reader :input_name
    attr_reader :logger

    def initialize
      @plugin_conf = Inspec::Config.cached.fetch_plugin_config("inspec-cloudformation")

      @logger = Inspec::Log
      logger.debug format("inspec-cloudformation plugin version %s", VERSION)

      # @mount_point = fetch_plugin_setting("mount_point", "secret")
      # @path_prefix = fetch_plugin_setting("path_prefix", "inspec")

      # We need priority to be numeric; even though env vars or JSON may present it as string - hence the to_i
      @priority = fetch_plugin_setting("priority", 60).to_i


    end

    # What priority should an input value recieve from us?
    # This plgin does not currently allow setting this on a per-input basis,
    # so they all recieve the same "default" value.
    # Implements https://github.com/inspec/inspec/blob/master/dev-docs/plugins.md#default_priority
    def default_priority
      priority
    end
    
    def fetch(profile_name, input_name)
      # skip any input name that is an invalid cloudformation stack name to keep things quick...no need to make the AWS API call.
      return nil if input_name.include?('_')

      cf = Aws::CloudFormation::Client.new

      # input format will be "cloudformation stack name / output name"
      stack_name = input_name.split('/').first
      output_name = input_name.split('/').last

      logger.info format("The stack name is  %s", stack_name)
      logger.info format("The output name is  %s", output_name)

      name = { stack_name: stack_name }
      resp = cf.describe_stacks(name)
      return nil if resp.stacks.nil? || resp.stacks.empty?
      stack = resp.stacks.first
      stack.outputs.each do |output|
          next unless output['output_key'] == output_name
          return output['output_value']
      end
    end

    private

    def valid_plugin_input?(input)
      VALID_PATTERNS.any? { |regex| regex.match? input }
    end

    def fetch_plugin_setting(setting_name, default = nil)
      env_var_name = "INSPEC_CLOUDFORMATION_#{setting_name.upcase}"
      ENV[env_var_name] || plugin_conf[setting_name] || default
    end

  end
end
