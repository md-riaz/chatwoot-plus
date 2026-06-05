# frozen_string_literal: true

module Middleware # rubocop:disable Style/ClassAndModuleChildren
  class PlusPlatformHeader
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)
      headers['X-Platform'] = 'chatwoot-plus'
      [status, headers, response]
    end
  end
end
