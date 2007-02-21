require 'haml_template'
require 'dispatcher'

def after_method(klass, target, feature, &block)
  # Strip out punctuation on predicates or bang methods since
  # e.g. target?_without_feature is not a valid method name.
  aliased_target, punctuation = target.to_s.sub(/([?!=])$/, ''), $1
  class << klass; self end.class_eval do
    define_method("register_#{feature}", &block)
    define_method("#{aliased_target}_with_#{feature}#{punctuation}") {
      returning klass.send("#{aliased_target}_without_#{feature}#{punctuation}") do
        klass.send("register_#{feature}")
      end
    }
    alias_method_chain target, "#{feature}"
  end
  klass.send("register_#{feature}")
end unless self.class.method_defined?(:after_method)

def after_reset_application(feature, &block)
  after_method(Dispatcher, :reset_application!, feature, &block)
end unless self.class.method_defined?(:after_reset_application)

after_reset_application("haml_registration") {
  Site.register_template_handler(".haml", HamlTemplate)
}
