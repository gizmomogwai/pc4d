sources = Dir.glob("**/*.d")

directory 'out'
directory 'out/docs'

desc 'prepare_index_d'
task :prepare_index_d do
  require 'erb'
  parsers = Dir.glob("source/**/parsers/*.d").map do |f|
    content = File.read(f)
    m = content.match(/class (.*?) : .*?Parser/)
    if m
      parser_name = m[1].gsub("(T)", "")
      [parser_name, f]
    else
      nil
    end
  end.compact
  parsers = parsers.map do |parser|
    name = parser.first
    file_name = File.basename(parser[1]).gsub(".d", ".html")
    "$(LI $(LINK2 #{file_name}, #{name}))"
  end.join("\n")
  puts parsers
  template = ERB.new(File.read("source/pc4d/index.d.erb"))
  File.write("source/pc4d/index.d", template.result(binding()))
  sh "dub build --build=docs"
end

desc 'build out/main.exe'
file 'out/main.exe' => sources + ['out', 'out/docs'] do |t|
  sh "dmd -D -Ddout/docs -X -Xfdocs.json -unittest -odout/obj -of#{t.name} #{sources.join(' ')}"
end

desc 'run out/main.exe'
task :run => 'out/main.exe' do |t|
  sh t.prerequisites[0]
end

desc 'the default task'
task :default => [:run]

desc 'add git to docs'
task :git_docs do
  cd 'docs' do
    sh 'git remote add origin git@github.com:gizmomogwai/pc4d.git'
  end
end
