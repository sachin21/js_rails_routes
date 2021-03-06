require 'singleton'

module JSRailsRoutes
  class Generator
    COMPARE_REGEXP = %r{:(.*?)(/|$)}

    PROCESS_FUNC = <<-JAVASCRIPT.freeze
function process(route, params, keys) {
  var query = [];
  for (var param in params) if (params.hasOwnProperty(param)) {
    if (keys.indexOf(param) === -1) {
      query.push(param + "=" + encodeURIComponent(params[param]));
    }
  }
  return query.length ? route + "?" + query.join("&") : route;
}
    JAVASCRIPT

    include Singleton

    attr_accessor :include_paths, :exclude_paths, :include_names, :exclude_names, :path

    def initialize
      self.include_paths = /.*/
      self.exclude_paths = /^$/
      self.include_names = /.*/
      self.exclude_names = /^$/
      self.path = Rails.root.join('app', 'assets', 'javascripts', 'rails-routes.js')
      Rails.application.reload_routes!
    end

    def generate(task)
      lines = ["// Don't edit manually. `rake #{task}` generates this file.", PROCESS_FUNC]
      lines += routes.map do |route_name, route_path|
        handle_route(route_name, route_path) if match?(route_name, route_path)
      end.compact
      lines += [''] # End with new line
      write(lines.join("\n"))
    end

    private

    def match?(route_name, route_path)
      return false if include_paths !~ route_path
      return false if exclude_paths =~ route_path
      return false if include_names !~ route_name
      return false if exclude_names =~ route_name
      true
    end

    def handle_route(route_name, route_path)
      keys = []
      while route_path =~ COMPARE_REGEXP
        keys.push("'#{$1}'")
        route_path.sub!(COMPARE_REGEXP, "' + params.#{$1} + '#{$2}")
      end
      "export function #{route_name}_path(params) { return process('#{route_path}', params, [#{keys.join(',')}]); }"
    end

    def routes
      @routes ||= Rails.application.routes.routes
                       .select(&:name)
                       .map { |r| [r.name, r.path.spec.to_s.split('(')[0]] }
                       .sort { |a, b| a[0] <=> b[0] }
    end

    def write(string)
      File.open(path, 'w') { |f| f.write(string) }
    end
  end
end
