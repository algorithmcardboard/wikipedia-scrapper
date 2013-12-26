set :application, 'wikipedia_scrapper'
set :repo_url, 'git@github.com:rajegannathan/wikipedia-scrapper.git'

# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

set :deploy_to, '/var/webapps/wikipedia-scrapper'
set :scm, :git

set :ssh_options, {
  forward_agent: true
}

# set :format, :pretty
# set :log_level, :debug
# set :pty, true

set :linked_files, %w{config/database.yml .env}
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

set :unicorn_pid_file, 'tmp/pids/unicorn.pid'
set :sidekiq_pid, 'tmp/pids/sidekiq.pid'

# set :default_env, { path: "/opt/ruby/bin:$PATH" }
set :keep_releases, 5

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, release_path.join('tmp/restart.txt')

      if test "[ -f #{current_path}/#{fetch(:unicorn_pid_file)} ]" then
        old_unicorn_pid = capture "cat #{current_path}/#{fetch(:unicorn_pid_file)}"
        if test "kill -0 #{old_unicorn_pid} > /dev/null 2>&1 " then
          execute "kill -USR2 #{old_unicorn_pid}"
        else
          execute "unicorn -c #{current_path}/config/unicorn.rb -E #{fetch(:stage)} -D"
        end
      else
        execute "unicorn -c #{current_path}/config/unicorn.rb -E #{fetch(:stage)} -D"
      end

    end
  end

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

  after :finishing, 'deploy:cleanup'

end
