module Sorcery
  module Controller
    module Submodules
      # This submodule helps you login users from external auth providers such as Twitter.
      # This is the controller part which handles the http requests and tokens passed between the app and the provider.
      module External
        def self.included(base)
          base.send(:include, InstanceMethods)
          Config.module_eval do
            class << self
              attr_reader :external_providers                           # external providers like twitter.
                                          
              def merge_external_defaults!
                @defaults.merge!(:@external_providers => [])
              end
              
              def external_providers=(providers)
                providers.each do |provider|
                  include Providers.const_get(provider.to_s.split("_").map {|p| p.capitalize}.join(""))
                end
              end
            end
            merge_external_defaults!
          end
        end

        module InstanceMethods
          protected
          
          # sends user to authenticate at the provider's website.
          # after authentication the user is redirected to the callback defined in the provider config
          def login_at(provider, args = {})
            @provider = Config.send(provider)
            if @provider.has_callback?
              redirect_to @provider.login_url(params,session)
            else
              #@provider.login(args)
            end
          end
          
          # tries to login the user from provider's callback
          def login_from(provider)
            @provider = Config.send(provider)
            @provider.process_callback(params,session)
            @user_hash = @provider.get_user_hash
            if user = Config.user_class.load_from_provider(provider,@user_hash[:uid])
              reset_session
              login_user(user)
              user
            end
          end
          
          # this method automatically creates a new user from the data in the external user hash.
          # The mappings from user hash fields to user db fields are set at controller config.
          # If the hash field you would like to map is nested, use slashes. For example, Given a hash like:
          #
          #   "user" => {"name"=>"moishe"}
          #
          # You will set the mapping:
          #
          #   {:username => "user/name"}
          #
          # And this will cause 'moishe' to be set as the value of :username field.
          def create_from(provider)
            provider = provider.to_sym
            @provider = Config.send(provider)
            @user_hash = @provider.get_user_hash
            config = Config.user_class.sorcery_config
            attrs = {}
            @provider.user_info_mapping.each do |k,v|
              (varr = v.split("/")).size > 1 ? attrs.merge!(k => varr.inject(@user_hash[:user_info]) {|hsh,v| hsh[v] }) : attrs.merge!(k => @user_hash[:user_info][v])
            end
            Config.user_class.transaction do
              @user = Config.user_class.create!(attrs)
              Config.user_class.sorcery_config.authentications_class.create!({config.authentications_user_id_attribute_name => @user.id, config.provider_attribute_name => provider, config.provider_uid_attribute_name => @user_hash[:uid]})
            end
            @user
          end
        end
      end
    end
  end
end
