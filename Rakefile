# frozen_string_literal: true

require 'rake'
require 'rake/testtask'

task(default: [:test])

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.pattern = FileList['test/**/test*.rb']
  t.warning = false
end

task :rubocop do
  if RUBY_ENGINE == 'ruby'
    require 'rubocop/rake_task'
    RuboCop::RakeTask.new
  end
end
