# main class for HAML template rendering
require 'haml'

class HamlTemplate < BaseDrop
  include UrlFilters
  include DropFilters
  include CoreFilters

  def initialize(site)
    @site_source = site
    @@precompiled_templates ||= {}
  end

  def liquify(*records, &block)
    self.class.liquify(@context, *records, &block)
  end

  def render(section, layout, template, assigns ={}, controller = nil)
    @layout = layout
    @template = template
    @controller = controller
    @assigns = assigns
    # psq-TODO: assigns contains mode, site, articles, section (more or less depending on mode,
    # consider using missing method to expose all of them to templates)
    # "section" would be nicer than
    # "@assigns['section']"
    @context = ::Liquid::Context.new(assigns, {}, false) # assigns, register, rethrow error

    @mode = assigns['mode']
    @archive_date = assigns['archive_date']

    @articles = assigns['articles']
    @articles.each { |article| article.context = @context } if (@articles)
    @article = assigns['article']
    @article.context = @context if @article
    
    # form handling
    @submitted = @context['submitted'] || {}
    @submitted.each{ |k, v| @submitted[k] = CGI::escapeHTML(v) }
    @errors = @context['errors']
    @message = @context['message']

    @site = @site_source.to_liquid(section)
    @site.context = @context
    if (section)
      @section = section.to_liquid
      @section.context = @context
    end

    @locals = { :mode => @mode, :controller => @controller, :archive_date => @archive_date, :articles => @articles,
      :article => @article, :submitted => @submitted, :site => @site, :section => @section}
    to_html
  end


# entry point for rendering layout and main_template to html
# not reentrant at this point because of the use of @ouput and @binding
  def to_html
    @binding = get_binding #use the same binding throughout
    do_include(@layout)
  end
  
# 
# in layout, include content using chosen template
# <% main_content %>
#
  def main_content
    do_include(@template, context={})
  end

# include template
# <% include "template name" %>
  def include(template, context={})
    do_include(@site_source.find_preferred_template(:page, template+".haml"), context)
  end

  def random_articles(section, limit = nil)
    liquify(*section.source.articles.find(:all, :order => 'RAND()', :limit => (limit || section.source.articles_per_page)))
  end

protected
  def do_include(template, context={})
    # need to save/restore @output since everything is using the same binding.
    # psq-TODO: if page caching is not working well enough, keeping a compiled version of the template could help
    # see ActionView::CompiledTemplates
    begin
      options = {}
      options[:locals] = @locals.merge(context)
      options[:filename] ||= template
      if @precompiled = get_precompiled(template)
        options[:precompiled] ||= @precompiled
        engine = Haml::Engine.new("", options)
      else
        engine = Haml::Engine.new(File.read(template), options)
        set_precompiled(template, engine.precompiled)
      end
      engine.to_html(self)
    rescue
      raise "HAML Error: #{$!}"
    end
  end

  def get_binding
    binding
  end
  
  # Gets the cached, precompiled version of the template at location <tt>filename</tt>
  # as a string.
  def get_precompiled(filename)
    # Do we have it on file? Is it new enough?
    if (precompiled, precompiled_on = @@precompiled_templates[filename]) &&
           (precompiled_on == File.mtime(filename).to_i)
      precompiled
    end
  end

  # Sets the cached, precompiled version of the template at location <tt>filename</tt>
  # to <tt>precompiled</tt>.
  def set_precompiled(filename, precompiled)
    @@precompiled_templates[filename] = [precompiled, File.mtime(filename).to_i]
  end

end
