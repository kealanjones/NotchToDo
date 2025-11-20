#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'NotchToDo/NotchToDo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Get the NotchToDo group
notch_group = project.main_group.find_subpath('NotchToDo/NotchToDo', true)

# Create ML group if it doesn't exist
ml_group = notch_group.find_subpath('ML', true) || notch_group.new_group('ML')
ml_group.set_source_tree('<group>')
ml_group.set_path('ML')

# Add ML files
ml_files = [
  'TaskClassifier.swift',
  'EmbeddingGenerator.swift',
  'OrbTrainingData.swift',
  'OrbManager+MLIntegration.swift',
  'TaskClassifierTests.swift'
]

ml_files.each do |filename|
  file_path = "NotchToDo/NotchToDo/ML/#{filename}"
  unless ml_group.files.any? { |f| f.path == filename }
    file_ref = ml_group.new_file(file_path)
    unless filename.include?('Tests')
      target.add_file_references([file_ref])
    end
  end
end

# Create NaturalLanguage group
nl_group = notch_group.find_subpath('NaturalLanguage', true) || notch_group.new_group('NaturalLanguage')
nl_group.set_source_tree('<group>')
nl_group.set_path('NaturalLanguage')

# Add NaturalLanguage files
nl_files = [
  'AdvancedIntentParser.swift',
  'NaturalLanguageDateParser.swift',
  'FuzzyOrbMatcher.swift',
  'AdvancedIntentParserTests.swift'
]

nl_files.each do |filename|
  file_path = "NotchToDo/NotchToDo/NaturalLanguage/#{filename}"
  unless nl_group.files.any? { |f| f.path == filename }
    file_ref = nl_group.new_file(file_path)
    unless filename.include?('Tests')
      target.add_file_references([file_ref])
    end
  end
end

# Create Voice group
voice_group = notch_group.find_subpath('Voice', true) || notch_group.new_group('Voice')
voice_group.set_source_tree('<group>')
voice_group.set_path('Voice')

# Add Voice files
voice_files = ['VoiceFeedback.swift']

voice_files.each do |filename|
  file_path = "NotchToDo/NotchToDo/Voice/#{filename}"
  unless voice_group.files.any? { |f| f.path == filename }
    file_ref = voice_group.new_file(file_path)
    target.add_file_references([file_ref])
  end
end

project.save

puts "✅ Successfully added all files to Xcode project!"
puts ""
puts "Files added:"
puts "  ML/ (#{ml_files.count} files)"
puts "  NaturalLanguage/ (#{nl_files.count} files)"
puts "  Voice/ (#{voice_files.count} files)"
puts ""
puts "Please close and reopen Xcode, then clean and rebuild the project."
