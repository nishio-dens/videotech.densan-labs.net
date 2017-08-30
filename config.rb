###
# Page options, layouts, aliases and proxies
###

# Per-page layout changes:
#
# With no layout
page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false

# With alternative layout
# page "/path/to/file.html", layout: :otherlayout

# Proxy pages (http://middlemanapp.com/basics/dynamic-pages/)
# proxy "/this-page-has-no-template.html", "/template-file.html", locals: {
#  which_fake_page: "Rendering a fake page with a local variable" }

# Common
Time.zone = 'Tokyo'

###
# Helpers
###

activate :syntax
set :markdown_engine, :redcarpet
set :markdown, fenced_code_blocks: true, smartypants: true, with_toc_data: true, tables: true, autolink: true, gh_blockcode: true
set :markdown, toc_levels: [2.3]

activate :blog do |blog|
  # This will add a prefix to all links, template references and source paths
  blog.prefix = "articles"

  # blog.permalink = "{year}/{month}/{day}/{title}.html"
  # Matcher for blog source files
  # blog.sources = "{year}-{month}-{day}-{title}.html"
  blog.layout = "layout"
  blog.taglink = "keywords/:tag.html"

  # blog.summary_separator = /(READMORE)/
  # blog.summary_length = 250
  # blog.year_link = "{year}.html"
  # blog.month_link = "{year}/{month}.html"
  # blog.day_link = "{year}/{month}/{day}.html"
  # blog.default_extension = ".markdown"
  blog.generate_year_pages = true
  blog.generate_month_pages = true
  blog.generate_tag_pages = true

  blog.tag_template = "tag.html"
  blog.calendar_template = "calendar.html"

  # Enable pagination
  blog.paginate = true
  blog.per_page = 10
  blog.page_link = "page/{num}"
end

page "/feed.xml", layout: false
# Reload the browser automatically whenever files change
configure :development do
  activate :livereload
end

helpers do
  def render_toc(page)
    if config.markdown_engine == :redcarpet
      toc = Redcarpet::Markdown.new(Redcarpet::Render::HTML_TOC)
      text = File.read(page.source_file)
      toc.render(text)
    end
  end
end

# Build-specific configuration
set :build_dir, 'docs'
configure :build do
  # Minify CSS on build
  # activate :minify_css

  # Minify Javascript on build
  # activate :minify_javascript
end
