# frozen_string_literal: true
#
# Install or update the dsh-go share-code card theme component and attach it to the default theme. Re-runnable.
#   rails runner /shared/dshgo/install_theme.rb /shared/dshgo/theme-dshgo.tar.gz

require "shellwords"

archive = ARGV[0]
abort "usage: rails runner install_theme.rb <theme-dshgo.tar.gz>" if archive.blank? || !File.exist?(archive)

info = JSON.parse(`tar -xzOf #{Shellwords.escape(archive)} theme-dshgo/about.json`)
name = info.fetch("name")

existing = Theme.find_by(name: name, component: true)
theme =
  RemoteTheme.update_zipped_theme(archive, File.basename(archive), theme_id: existing&.id)
puts "#{existing ? "updated" : "installed"} theme component \"#{theme.name}\" (id #{theme.id})"

default = Theme.find_default
if default.nil?
  puts "  ! no default theme: add the component to the theme in use under Admin → Appearance → Themes"
elsif default.child_themes.exists?(id: theme.id)
  puts "  = already on default theme \"#{default.name}\""
else
  default.add_relative_theme!(:child, theme)
  puts "  ✓ attached to default theme \"#{default.name}\""
end
