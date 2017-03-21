require 'rubygems'

class WordPressTranslationRetrieval

  LANGS = {
    'da' => 'da',
    'de-DE' => 'de',
    'en-AU' => 'en-au',
    'en-CA' => 'en-ca',
    'en-GB' => 'en-gb',
    'en-US' => 'en', # Technically this is a hack, but I don't think we can get the original english translations from Glotpress
    'es-ES' => 'es',
    'fr-FR' => 'fr',
    'id' => 'id',
    'it' => 'it',
    'ja' => 'ja',
    'ko' => 'ko',
    'nl-NL' => 'nl',
    'no' => 'nb',
    'pt-BR' => 'pt-br',
    'pt-PT' => 'pt',
    'ru' => 'ru',
    'sv' => 'sv',
    'th' => 'th',
    'tr' => 'tr',
    'zh-Hans' => 'zh-cn',
    'zh-Hant' => 'zh-tw',
  }

  class << self

    def get_version_text_from_file_contents(file_contents, strings_file_key)
      whats_new_text = nil

      file_contents.each_with_index do |line, index|
        if line =~ Regexp.new(strings_file_key)
          whats_new_text = file_contents[index+2]
          if whats_new_text =~ Regexp.new("msgstr\s\"\"")
            whats_new_text = file_contents[index+1]
          end
        end
      end

      separator = "•"
      matcher = Regexp.new("\"(.*)\"")
      matches = whats_new_text.gsub("msgstr ", "").match(matcher)
      version_text = matches[1].split(separator).select { |text| text.length > 0 }.map { |text| text.strip }.map { |text| "#{separator} #{text}"}.join("\n")

      version_text
    end

    def retrieve_file_contents_from_glotpress(glotpress_language_code)
      if glotpress_language_code == 'en'
        url = "../../WordPress/Resources/AppStoreStrings.po"
        file_contents = File.readlines(url)
      else
        url = "https://translate.wordpress.org/projects/apps/ios/release-notes/#{glotpress_language_code}/default/export-translations?format=po"
        system "curl -so temp.po #{url}"
        file_contents = File.readlines("temp.po")
        system "rm temp.po"
      end
      

      file_contents
    end

    def get_version_text(deliver_language_code, strings_file_key)
      glotpress_language_code = LANGS[deliver_language_code]
      file_contents = retrieve_file_contents_from_glotpress(glotpress_language_code)
      version_text = get_version_text_from_file_contents(file_contents, strings_file_key)

      if version_text.length == 0
        file_contents = retrieve_file_contents_from_glotpress("en-gb")
        version_text = get_version_text_from_file_contents(file_contents, strings_file_key)
      end

      version_text
    end
  end

end

# Uncomment below and run the script from the command line to test
# WordPressTranslationRetrieval::LANGS.each do |deliver_language_code, glotpress_language_code|
#   puts "Version text for #{deliver_language_code}"
#   puts WordPressTranslationRetrieval.get_version_text(deliver_language_code, "v7.2-whats-new")
#   puts "\n"
# end

