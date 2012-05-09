sources = Dir.glob("**/*.d")

directory 'out'
directory 'out/docs'

desc 'build out/main.exe'
file 'out/main.exe' => sources + ['out', 'out/docs'] do |t|
  sh "dmd -D -Ddout/docs -unittest -odout/obj -of#{t.name} #{sources.join(' ')}"
end

desc 'run out/main.exe'
task :run => 'out/main.exe' do |t|
  sh t.prerequisites[0]
end

desc 'the default task'
task :default => [:run]
