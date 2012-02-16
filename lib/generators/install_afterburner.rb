module Afterburner
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('../../config', __FILE__)
      desc "Copies example database.yml, shards.yml to config and test_shards_yml to config/environments/"

      def copy_config_files
        copy_file "../../config/database.yml", "config/database.yml"
        copy_file "../../config/shards.yml", "config/shards.yml"
        copy_file "../../config/analytics.yml", "config/analytics.yml"
        copy_file "../../config/environments/test_shards.yml", "config/environments/test_shards.yml"
      end
    end
  end
end