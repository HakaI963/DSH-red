# frozen_string_literal: true
#
# dsh-go forum initialization: site settings, login methods, categories, tags, UI text.
# Run inside the container with rails runner (scripts/apply.sh calls it for you):
#
#   rails runner /shared/dshgo/apply_settings.rb /shared/dshgo
#
# Re-runnable: settings whose values did not change are not rewritten; existing categories are
# matched by slug and only their permissions, color and "accepted answers" toggle are synced.
# A failure in any item only prints a warning and does not affect the rest.

require "yaml"

dir = ARGV[0].presence || "/shared/dshgo"
PLACEHOLDER = "<<FILL"

def load_yaml(path)
  return {} unless File.exist?(path)
  YAML.safe_load(File.read(path), permitted_classes: [], aliases: false) || {}
end

def say(msg) = puts(msg)
def warn_line(msg) = puts("  ! #{msg}")

def placeholder?(value)
  case value
  when String
    value.include?(PLACEHOLDER)
  when Array
    value.any? { |v| placeholder?(v) }
  when Hash
    value.values.any? { |v| placeholder?(v) }
  else
    false
  end
end

def apply_setting(name, value)
  sym = name.to_sym
  unless SiteSetting.has_setting?(sym)
    warn_line "#{name}: this Discourse version has no such setting, skipped"
    return
  end
  if SiteSetting.shadowed_settings.include?(sym)
    say "  = #{name} (already set by an app.yml environment variable)"
    return
  end
  if placeholder?(value)
    warn_line "#{name}: still a placeholder; fill it in the file first"
    return
  end

  if value.is_a?(Hash) && value.key?("add")
    current = SiteSetting.get(sym).to_s.split("|").map(&:strip).reject(&:empty?)
    value = (current + Array(value["add"]).map(&:to_s)).uniq.join("|")
  end

  before = SiteSetting.get(sym)
  if before.to_s == value.to_s
    say "  = #{name}"
    return
  end
  SiteSetting.set_and_log(sym, value)
  shown = SiteSetting.secret_settings.include?(sym) ? "[set]" : value.inspect
  say "  ✓ #{name} → #{shown}"
rescue StandardError => e
  warn_line "#{name}: #{e.message}"
end

settings = load_yaml(File.join(dir, "site_settings.yml"))
secrets = load_yaml(File.join(dir, "secrets.yml"))
community = load_yaml(File.join(dir, "community.yml"))

if secrets.empty?
  warn_line "secrets.yml not found: third-party logins and S3 backups will not be enabled"
end

# ── 1. Secrets (credentials must be written before the enable flags, or the validators refuse to turn them on) ────────
say "\n[1/5] Credentials"
secrets.each do |name, value|
  next if value.blank?
  apply_setting(name, value)
end

# ── 2. Regular settings ────────────────────────────────────────────────────────
say "\n[2/5] Site settings"
settings.each { |name, value| apply_setting(name, value) }

# ── 3. Login switches: enabled only when credentials are complete ──────────────────────────────────
say "\n[3/5] Login methods"
providers = {
  "GitHub" => [:enable_github_logins, %i[github_client_id github_client_secret]],
  "LINUX DO" => [:openid_connect_enabled, %i[openid_connect_client_id openid_connect_client_secret]],
  "Gitee" => [:oauth2_enabled, %i[oauth2_client_id oauth2_client_secret]],
}
providers.each do |label, (flag, keys)|
  unless SiteSetting.has_setting?(flag)
    warn_line "#{label}: #{flag} not found, its plugin may not be loaded"
    next
  end
  ready = keys.all? { |k| SiteSetting.has_setting?(k) && SiteSetting.get(k).present? }
  if ready
    apply_setting(flag, true)
  else
    say "  - #{label}: no credentials in secrets.yml, staying off"
  end
end

# ── 4. Categories and tags ──────────────────────────────────────────────────────
say "\n[4/5] Categories and tags"
system_user = Discourse.system_user

# rails runner's I18n.locale is en: without switching, a new category's "About" topic would be
# titled "About the 公告 category". Create categories in the site's default locale.
site_locale = SiteSetting.default_locale.presence || "zh_CN"
previous_locale = I18n.locale
I18n.locale = site_locale

def sym_permissions(raw)
  return nil if raw.blank?
  raw.to_h { |group, permission| [group.to_sym, permission.to_s.to_sym] }
end

Array(community["categories"]).each do |spec|
  name = spec["name"]
  slug = spec["slug"]
  begin
    category = Category.find_by(slug: slug, parent_category_id: nil)

    if category.nil? && spec["reuse_site_setting"].present?
      reuse_id = SiteSetting.get(spec["reuse_site_setting"].to_sym).to_i
      reused = Category.find_by(id: reuse_id) if reuse_id > 0
      if reused
        old_name = reused.name
        reused.name = name
        reused.slug = slug
        reused.color = spec["color"] if spec["color"].present?
        reused.text_color = spec["text_color"] if spec["text_color"].present?
        reused.position = spec["position"] if spec.key?("position")
        reused.save!
        if reused.topic&.first_post && spec["description"].present?
          reused.topic.first_post.revise(system_user, { raw: spec["description"] }, skip_validations: true)
        end
        category = reused
        say "  ✓ category \"#{old_name}\" repointed to \"#{name}\""
      end
    end

    if category.nil?
      category =
        Category.new(
          name: name,
          slug: slug,
          user: system_user,
          color: spec["color"],
          text_color: spec["text_color"] || "FFFFFF",
          description: spec["description"],
        )
      category.position = spec["position"] if spec.key?("position")
      perms = sym_permissions(spec["permissions"])
      category.set_permissions(perms) if perms
      category.save!
      say "  ✓ created category \"#{name}\" (/c/#{slug})"
    else
      category.color = spec["color"] if spec["color"].present?
      category.text_color = spec["text_color"] if spec["text_color"].present?
      perms = sym_permissions(spec["permissions"])
      category.set_permissions(perms) if perms
      category.save! if category.changed? || perms
      say "  = category \"#{category.name}\" already exists"
    end

    if spec.key?("solved")
      value = spec["solved"] ? "true" : "false"
      if category.custom_fields["enable_accepted_answers"] != value
        category.custom_fields["enable_accepted_answers"] = value
        category.save_custom_fields
        say "    solved: #{spec["solved"] ? "on" : "off"}"
      end
    end
  rescue StandardError => e
    warn_line "category \"#{name}\": #{e.message}"
  end
end

Array(community["tags"]).each do |raw|
  tag_name = DiscourseTagging.clean_tag(raw.to_s)
  next if tag_name.blank?
  if Tag.where("lower(name) = ?", tag_name.downcase).exists?
    say "  = tag #{tag_name}"
  else
    Tag.create!(name: tag_name)
    say "  ✓ created tag #{tag_name}"
  end
rescue StandardError => e
  warn_line "tag #{raw}: #{e.message}"
end

I18n.locale = previous_locale

# Category cache keys are locale-scoped (site_categories_<locale>_…), and the anonymous
# /site.json has its own ~30-minute Redis cache: without clearing, web and App keep showing the
# old categories for half an hour.
begin
  I18n.with_locale(site_locale) { Site.clear_cache }
  Site.clear_anon_cache!
  say "  ✓ category cache cleared"
rescue StandardError => e
  warn_line "clearing category cache: #{e.message}"
end

# ── 5. UI text overrides ────────────────────────────────────────────────────
say "\n[5/5] UI text"
(community["translation_overrides"] || {}).each do |locale, pairs|
  pairs.each do |key, value|
    existing = TranslationOverride.find_by(locale: locale, translation_key: key)
    if existing&.value == value
      say "  = #{locale} #{key}"
    else
      TranslationOverride.upsert!(locale, key, value)
      say "  ✓ #{locale} #{key} → #{value}"
    end
  rescue StandardError => e
    warn_line "#{locale} #{key}: #{e.message}"
  end
end

say "\nDone. Lines marked ! need attention; fix the files and run this again."
