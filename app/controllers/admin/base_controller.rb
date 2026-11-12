module Admin
  # HTTP basic auth with ADMIN_PASSWORD (username ADMIN_USERNAME, default "admin").
  # Admin is disabled entirely when no password is configured.
  class BaseController < ApplicationController
    before_action :authenticate_admin!

    private

    def authenticate_admin!
      password = ENV["ADMIN_PASSWORD"]
      return head(:forbidden) if password.blank?

      authenticate_or_request_with_http_basic("Crozet Polo admin") do |user, pass|
        ActiveSupport::SecurityUtils.secure_compare(user, ENV.fetch("ADMIN_USERNAME", "admin")) &
          ActiveSupport::SecurityUtils.secure_compare(pass, password)
      end
    end
  end
end
