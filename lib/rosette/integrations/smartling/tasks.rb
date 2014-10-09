# encoding: UTF-8

Dir.glob(File.join(File.expand_path('../tasks', __FILE__), '**/*.rake')).each do |file|
  load(file) if File.file?(file)
end
