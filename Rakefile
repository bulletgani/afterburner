require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

require 'fileutils'
include FileUtils::Verbose


namespace :db do

  def load_shard_config &block
    env = ::Rails.env.to_s
    db_yml = YAML::load(ERB.new(IO.read("config/database.yml")).result)
    shards_yml = YAML::load(ERB.new(IO.read("config/shards.yml")).result)
    reference = shards_yml['octopus'][env]['shards']
    reference = db_yml.merge reference
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Base.logger.level = Logger::WARN
    ActiveRecord::Base.configurations = reference.dup
    reference.each_key do |name|
      next unless name.include? env
      next if name.include? '_ref_'
      next if (name.include?('slave')) # Replicated databases should not be touched directly
      next unless ENV['SHARDS'].split(',').include? name if ENV['SHARDS']
      ActiveRecord::Base.clear_active_connections!
      ActiveRecord::Base.configurations[name] = reference[name]

      ::Rails.env = name if name != env
      yield name, env
      ::Rails.env = env
    end
  end


  def sync_up_down migration_list, &block
    if @out_of_sync == false or ENV['SHARDS'] or ENV['SHARD']
      step = ENV['STEP'] || 1
      step = step.to_i
      migration_list.each_with_index do |m, i|
        load_shard_config do |name, env|
          #next if name == ENV['RAILS_ENV']
          ap "processing #{name}"
          ActiveRecord::Base.establish_connection name
          ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
          begin
            yield m, step - i, name
          rescue Exception => e
            ap "Migation failed on shard=#{name} with exception #{e}", :color => {:string => :red}
            exit
          end
        end
      end
    else
      ap "Database Migrations are out of SYNC", :color => {:string => :red}
      ap "Synchronize the DB migrations and then run sync_migrate", :color => {:string => :red}
    end
  end

  task :reset do
    Rake::Task['db:shards:drop'].invoke
    Rake::Task['db:shards:create'].invoke
    Rake::Task['db:shards:migrate'].invoke
  end

  namespace :shards do
    namespace :test do
      task :prepare do
        Rake::Task['db:shards:drop'].invoke
        Rake::Task['db:shards:create'].invoke
        Rake::Task['db:shards:migrate'].invoke
      end
    end

    namespace :schema do
      task :load do
        file = ENV['SCHEMA'] || "#{Rails.root}/db/schema.rb"
        if File.exists?(file)
          load_shard_config do |name, env|
            ActiveRecord::Base.establish_connection name
            ap "Loading schema into #{name}"
            Octopus.using(name.to_sym) do
              load(file)
            end
          end
        else
          abort %{#{file} doesn't exist yet. Run "rake db:migrate" to create it then try again. If you do not intend to use a database, you should instead alter #{Rails.root}/config/boot.rb to limit the frameworks that will be loaded}
        end
      end
    end

    task :set_env => :environment do
      # rename ::Rails_env to <env>__ to prevent octopus from picking up the migrations
      #::Rails.env = ENV['RAILS_ENV'] + '__' || 'unknown'
      ap "Setting env to #{ENV['RAILS_ENV']}"
    end

    task :check => :set_env do
      @migrations = {}
      @current_versions = {}
      @pending_migrations = {}
      @existing_migrations = {}

      @out_of_sync = false
      load_shard_config do |name, env|
        ActiveRecord::Base.establish_connection name
        ActiveRecord::Migration.verbose = ENV["VERBOSE"] ? ENV["VERBOSE"] == "true" : true
        @migrations[name] = ActiveRecord::Migrator.new(:up, 'db/migrate')
        @current_versions[name] = @migrations[name].current_version
        @pending_migrations[name] = @migrations[name].pending_migrations
        @existing_migrations[name] = @migrations[name].migrated
        @out_of_sync = true if @current_versions[env] != @current_versions[name]
      end

      ap "Current Version", :color => {:string => :blue}
      ap @current_versions, :color => {:hash=> :blue}

      #ap "Existing Migrations", :color => {:string => :yellowish}
      #ap @existing_migrations, :color => {:hash => :yellowish, :array => :yellowish}
    end


    desc "Checks if all migrations are in sync on all shards"
    task :status => :check do
      @current_versions.each_key do |k|
        ap "Pending Migrations for #{k}", :color => {:string => :cyanish}
        @pending_migrations[k].each do |p|
          ap p.filename, :color => {:hash => :cyanish, :array => :cyanish}
        end
      end
      #@current_versions.each_key do |k|
      #  ap "Existing Migrations for #{k}", :color => {:string => :cyanish}
      #  @existing_migrations[k].each do |e|
      #    ap e, :color => {:hash => :cyanish, :array => :cyanish}
      #  end
      #end
      @current_versions.each_key do |k|
        if @current_versions[ENV['RAILS_ENV']] != @current_versions[k]
          ap "Migrations in #{k} are out of sync with #{ENV['RAILS_ENV']}", :color => {:string => :red}
        else
          ap "Migrations in #{k} are in sync with #{ENV['RAILS_ENV']}", :color => {:string => :green}
        end
      end
    end

    desc "Runs migrations one at a time on all shards before proceeding to the next migration. options: SHARDS=shard1,shard2,..."
    task :migrate => :check do
      sync_up_down(@pending_migrations[ENV['RAILS_ENV']]) do |version, remaining_steps, name|
        ActiveRecord::Migrator.run(:up, "db/migrate/", version.version)
      end
    end

    desc "Rolls back migrations one at a time on all shards before proceeding to the previous migration. Options: SHARDS=shard1,shard2...  STEP=n"
    task :rollback => :check do
      ap rollback_env = ENV['SHARD'] || ENV['RAILS_ENV']
      sync_up_down(@existing_migrations[rollback_env].reverse) do |version, remaining_steps, name|
        ActiveRecord::Migrator.run(:down, "db/migrate/", version) if remaining_steps > 0
      end
    end

    desc "Create databases on all shards"
    task :create => :rails_env do
      load_shard_config do |name, env|
        ap "ENV=#{env} Shard=#{name}"
        config = ActiveRecord::Base.configurations[name]
        begin
          ActiveRecord::Base.establish_connection(config.merge('database' => nil))
          ap config
          ap ActiveRecord::Base.connection_config
          ActiveRecord::Base.connection.create_database(config['database'])
          ActiveRecord::Base.establish_connection name
          ActiveRecord::Base.connection.disconnect!
        rescue Exception => e
          $stderr.puts "Couldn't create #{config['database']} : #{e.inspect}"
        end
      end
    end

    desc "Deletes database on all shards"
    task :drop => :rails_env do
      load_shard_config do |name, env|
        ap "Dropping #{name} : ENV=#{env} Shard=#{name}"
        config = ActiveRecord::Base.configurations[name]
        begin
          ActiveRecord::Base.establish_connection(config.merge('database' => nil))
          ActiveRecord::Base.connection.drop_database(config['database'])
        rescue Exception => e
          $stderr.puts "Couldn't drop #{config['database']} : #{e.inspect}"
        end
      end
    end
  end
end

namespace :db do
  namespace :shards do
    namespace :parallel do
      desc 'parallel db create'
      task :create, :count do |t, args|
        run_in_parallel('rake db:shards:create RAILS_ENV=test', args)
      end


      desc 'parallel db drop'
      task :drop, :count do |t, args|
        run_in_parallel('rake db:shards:drop RAILS_ENV=test', args)
      end


      desc 'parallel db:shards:migrate'
      task :migrate, :count do |t, args|
        run_in_parallel('rake db:shards:migrate RAILS_ENV=test', args)
      end
    end
  end
end
