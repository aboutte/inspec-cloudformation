require 'aws-sdk-cloudformation'










# See https://github.com/inspec/inspec/blob/master/docs/dev/plugins.md#implementing-input-plugins

module InspecPlugins::Vault
  class Input < Inspec.plugin(2, :input)

    VALID_PATTERNS = [
      Regexp.new("^databag://[^/]+/[^/]+/.+$"),
      Regexp.new("^node://[^/]*/attributes/.+$"),
    ].freeze

    attr_reader :plugin_conf
    # attr_reader :mount_point
    # attr_reader :path_prefix
    # attr_reader :vault
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

      # @vault = Vault::Client.new(
      #   address: fetch_vault_setting("vault_addr"),
      #   token: fetch_vault_setting("vault_token")
      # )
    end

    # What priority should an input value recieve from us?
    # This plgin does not currently allow setting this on a per-input basis,
    # so they all recieve the same "default" value.
    # Implements https://github.com/inspec/inspec/blob/master/dev-docs/plugins.md#default_priority
    def default_priority
      priority
    end

    # returns Array of input names as strings
    # def list_inputs(profile_name)
    #   vault.with_retries(Vault::HTTPConnectionError) do
    #     path = logical_path_for_profile(profile_name)
    #     doc = vault.logical.read(path)
    #     return [] unless doc

    #     return doc.data[:data].keys.map(&:to_s)
    #   end
    # end

    # Fetch a value of a single input from Vault
    
    def fetch(profile_name, input_name)
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
      
      # stacks.each do |stack|
      #     next if input(stack).nil? # If HRA addon was skipped we expect the input to be skipped also
          
      # end



      # @input_name = input_name

      # path = logical_path_for_profile(profile_name)
      # item = input_name

      # if absolute_path?
      #   _empty, *path, item = input_name.split("/")
      #   path = logical_path path.join("/")
      # end

      # logger.info format("Reading Vault secret from %s", path)
      # vault.with_retries(Vault::HTTPConnectionError) do
      #   doc = vault.logical.read(path)
      #   # Keys from vault are always symbolized
      #   return doc.data[:data][item.to_sym] if doc
      # end
    end

    private

    # # Assumption for profile based lookups: inputs have been stored on documents named
    # # for their profiles, and each input has a key-value pair in the document.
    # def logical_path_for_profile(profile_name)
    #   logical_path(profile_name)
    # end

    # def logical_path(relative_path)
    #   # When you actually read a value, on the KV2 backend you must
    #   # read secret/data/path, not secret/path (as on the CLI)
    #   # https://www.vaultproject.io/api/secret/kv/kv-v2.html#read-secret-version
    #   # Is this true for all backends?
    #   "#{mount_point}/data/#{prefix}#{relative_path}"
    # end

    # def prefix
    #   return "#{path_prefix}/" unless absolute_path?

    #   ""
    # end

    # def absolute_path?
    #   input_name.start_with?("/")
    # end

    def valid_plugin_input?(input)
      VALID_PATTERNS.any? { |regex| regex.match? input }
    end

    def fetch_plugin_setting(setting_name, default = nil)
      env_var_name = "INSPEC_CLOUDFORMATION_#{setting_name.upcase}"
      ENV[env_var_name] || plugin_conf[setting_name] || default
    end

    # def fetch_vault_setting(setting_name)
    #   ENV[setting_name.upcase] || plugin_conf[setting_name]
    # end
  end
end
