module Featurable
  extend ActiveSupport::Concern

  QUERY_MODE = {
    flag_query_mode: :bit_operator,
    check_for_column: false
  }.freeze

  FEATURE_LIST = YAML.safe_load(Rails.root.join('config/features.yml').read).freeze

  BITMASK_FEATURE_LIMIT = 63
  BITMASK_FEATURE_LIST = FEATURE_LIST.first(BITMASK_FEATURE_LIMIT).freeze
  OVERFLOW_FEATURE_NAMES = FEATURE_LIST.drop(BITMASK_FEATURE_LIMIT).pluck('name').freeze

  FEATURES = BITMASK_FEATURE_LIST.each_with_object({}) do |feature, result|
    result[result.keys.size + 1] = "feature_#{feature['name']}".to_sym
  end

  included do
    include FlagShihTzu
    has_flags FEATURES.merge(column: 'feature_flags').merge(QUERY_MODE)

    OVERFLOW_FEATURE_NAMES.each do |feature_name|
      define_method("feature_#{feature_name}") { overflow_feature_enabled?(feature_name) }
      define_method("feature_#{feature_name}?") { overflow_feature_enabled?(feature_name) }
      define_method("feature_#{feature_name}=") do |value|
        set_overflow_feature(feature_name, FlagShihTzu::TRUE_VALUES.include?(value))
      end
    end

    before_create :enable_default_features
  end

  def enable_features(*names)
    names.each do |name|
      send("feature_#{name}=", true)
    end
  end

  def enable_features!(*names)
    enable_features(*names)
    save
  end

  def disable_features(*names)
    names.each do |name|
      send("feature_#{name}=", false)
    end
  end

  def disable_features!(*names)
    disable_features(*names)
    save
  end

  def feature_enabled?(name)
    send("feature_#{name}?")
  end

  def all_features
    FEATURE_LIST.pluck('name').index_with do |feature_name|
      feature_enabled?(feature_name)
    end
  end

  def enabled_features
    all_features.select { |_feature, enabled| enabled == true }
  end

  def disabled_features
    all_features.select { |_feature, enabled| enabled == false }
  end

  def overflow_feature_flags
    settings&.fetch('overflow_feature_flags', {}) || {}
  end

  def overflow_feature_enabled?(name)
    feature_name = name.to_s
    return overflow_feature_flags[feature_name] if overflow_feature_flags.key?(feature_name)

    FEATURE_LIST.find { |feature| feature['name'] == feature_name }&.fetch('enabled', false) == true
  end

  def set_overflow_feature(name, value)
    self.settings ||= {}
    self.settings = settings.merge(
      'overflow_feature_flags' => overflow_feature_flags.merge(name.to_s => value)
    )
  end

  private

  def enable_default_features
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return true if config.blank?

    features_to_enabled = config.value.select { |f| f[:enabled] }.pluck(:name)
    enable_features(*features_to_enabled)
  end
end
