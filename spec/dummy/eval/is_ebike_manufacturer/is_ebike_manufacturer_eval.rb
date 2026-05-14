class IsEbikeManufacturerEval < EvalEngine::Eval
  input_type :hash do
    field :url, :string
  end

  output_type :string, match: :exact

  def generate(input)
    url = input["url"]
    html = read_file("cache/#{self.class.url_to_cache_filename(url)}")
    classify_from_html(html)
  end

  def self.url_to_cache_filename(url)
    host = URI.parse(url).host.gsub("www.", "")
    "#{host}.html"
  end

  private

  def classify_from_html(html)
    return "retailer" if html.include?("marketplace") || html.include?("sold by third parties")
    return "manufacturer" if html.include?("our products") || html.include?("we build")

    "unknown"
  end
end
