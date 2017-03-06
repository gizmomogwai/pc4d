desc 'docs'
task :docs do
  sh "dub build --build=docs"
end

desc 'test'
task :test do
  sh "dub test"
end

desc 'the default task'
task :default => [:test, :docs]

desc 'add git to docs'
task :git_docs do
  cd 'docs' do
    sh 'git remote add origin git@github.com:gizmomogwai/pc4d.git'
  end
end
