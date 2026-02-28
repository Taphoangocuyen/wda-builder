require 'xcodeproj'

project_path = 'WebDriverAgent/WebDriverAgent.xcodeproj'
project = Xcodeproj::Project.open(project_path)

lib_target = project.targets.find { |t| t.name == 'WebDriverAgentLib' }
if lib_target.nil?
  puts "ERROR: WebDriverAgentLib target not found!"
  puts "Available targets: #{project.targets.map(&:name).join(', ')}"
  exit 1
end
puts "Found target: #{lib_target.name}"

wda_lib_group = project.main_group.find_subpath('WebDriverAgentLib', false)
if wda_lib_group.nil?
  wda_lib_group = project.main_group.find_subpath('WebDriverAgentLib/WebDriverAgentLib', false)
end

routing_group = nil
if wda_lib_group
  routing_group = wda_lib_group.find_subpath('Routing', false)
end

target_group = routing_group || wda_lib_group || project.main_group
puts "Adding to group: #{target_group.display_name}"

file_ref = target_group.new_file('IPCAuthGuard.m')
puts "Added file reference: #{file_ref.path}"

lib_target.source_build_phase.add_file_reference(file_ref)
puts "Added to compile sources of #{lib_target.name}"

project.save
puts "Xcode project updated successfully"
