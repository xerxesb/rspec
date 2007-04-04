# We have to make sure the rspec lib above gets loaded rather than the gem one (in case it's installed)
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/../../../rspec/lib'))
require 'spec/rake/spectask'

pre_commit_tasks = ["rspec:ensure_db_config", "rspec:clobber_sqlite_data", "db:migrate", "rspec:generate_rspec", "spec", "rspec:destroy_purchase"]
pre_commit_tasks.unshift "rspec:create_purchase" unless ENV['RSPEC_RAILS_VERSION'] == '1.1.6'

namespace :rspec do
  task :pre_commit do
    begin
      rm_rf 'vendor/plugins/rspec_on_rails'
      `svn export ../rspec_on_rails vendor/plugins/rspec_on_rails`
      pre_commit_tasks.each do |t|
        output = nil
        IO.popen("rake #{t}") do |io|
          io.each_line do |line|
            puts line unless line =~ /^running against rails/ || line =~ /^\(in /
          end
          output = io.read
        end
        raise "ERROR while running rake: #{output}" if output =~ /ERROR/n || $? != 0
      end
    ensure
      rm_rf 'vendor/plugins/rspec_on_rails'
    end
  end
  
  task :install_plugin do
    rm_rf 'vendor/plugins/rspec_on_rails'
    puts "installing rspec_on_rails ..."
    result = `svn export ../rspec_on_rails vendor/plugins/rspec_on_rails`
    raise "Failed to install plugin:\n#{result}" if $? != 0
  end
  
  task :uninstall_plugin do
    rm_rf 'vendor/plugins/rspec_on_rails'
  end

  task :generate_rspec do
    result = `ruby script/generate rspec --force`
    raise "Failed to generate rspec environment:\n#{result}" if $? != 0 || result =~ /^Missing/
  end

  task :ensure_db_config do
    config_path = 'config/database.yml'
    unless File.exists?(config_path)
      message = <<EOF
#####################################################
Could not find #{config_path}

You can get rake to generate this file for you using either of:
  rake rspec:generate_mysql_config
  rake rspec:generate_sqlite3_config

If you use mysql, you'll need to create dev and test
databases and users for each. To do this, standing
in rspec_on_rails, log into mysql as root and then...
  mysql> source db/mysql_setup.sql;

There is also a teardown script that will remove
the databases and users:
  mysql> source db/mysql_teardown.sql;
#####################################################
EOF
      raise message
    end
  end

  desc "configures config/database.yml for mysql"
  task :generate_mysql_config do
    copy 'config/database.mysql.yml', 'config/database.yml'
  end

  desc "configures config/database.yml for sqlite3"
  task :generate_sqlite3_config do
    copy 'config/database.sqlite3.yml', 'config/database.yml'
  end

  desc "deletes config/database.yml"
  task :clobber_db_config do
    rm 'config/database.yml'
  end

  desc "deletes sqlite databases"
  task :clobber_sqlite_data do
    rm_rf 'db/*.db'
  end
    
  task :create_purchase => ['rspec:generate_purchase', 'rspec:migrate_up']

  desc "Generates temporary purchase files with rspec_resource"
  task :generate_purchase do
    generator = "ruby script/generate rspec_resource purchase order_id:integer created_at:datetime amount:decimal keyword:string description:text --force"
    puts <<EOF
#####################################################
#{generator}
#####################################################
EOF
    result = `#{generator}`
    raise "rspec_resource failed" if $? != 0 || result =~ /not/
  end

  task :migrate_up do
    ENV['VERSION'] = '5'
    Rake::Task["db:migrate"].invoke
  end

  desc "Destroys temporary purchase files (generated by rspec_resource)"
  task :destroy_purchase => ['rspec:migrate_down', 'rspec:rm_generated_purchase_files']

  task :migrate_down do
    puts <<EOF
#####################################################
Migrating down and reverting config/routes.rb
#####################################################
EOF
    ENV['VERSION'] = '4'
    Rake::Task["db:migrate"].invoke
    `svn revert config/routes.rb`
    raise "svn revert failed" if $? != 0
  end
  
  task :rm_generated_purchase_files do
    puts "#####################################################"
    puts "Removing generated files:"
    generated_files = %W{
      app/helpers/purchases_helper.rb
      app/models/purchase.rb
      app/controllers/purchases_controller.rb
      app/views/purchases
      db/migrate/005_create_purchases.rb
      spec/models/purchase_spec.rb
      spec/controllers/purchases_controller_spec.rb
      spec/fixtures/purchases.yml
      spec/views/purchases
    }
    generated_files.each do |file|
      rm_rf file
    end
    puts "#####################################################"
  end
end