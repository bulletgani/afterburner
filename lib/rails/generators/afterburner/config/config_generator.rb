require 'rails/generators/named_base'


module Afterburner
  module Generators
    class ConfigGenerator < Rails::Generators::NamedBase
      desc "Copies example database.yml, shards.yml to config and test_shards_yml to config/environments/"

      def self.source_root
        File.expand_path('../../../../../../config_example/',  __FILE__)
      end

      def create_config_files
        copy_file "database.yml", "config/database.yml"
        copy_file "shards.yml", "config/shards.yml"
        copy_file "analytics.yml", "config/analytics.yml"
        ['development', 'test', 'production'].each do |environ|
          copy_file "environments/test_shards.yml", "config/environments/#{environ}_shards.yml"
        end
      end
    end
  end
end
