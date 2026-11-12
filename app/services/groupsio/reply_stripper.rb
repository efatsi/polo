module Groupsio
  # Reduce an email body to just what the sender newly wrote: HTML -> text, then
  # drop quoted reply chains, signatures, and list footers.
  # (Same rules as mcp/groupsio/text.js.)
  module ReplyStripper
    CUT_MARKERS = [
      /\A\s*On .+wrote:\s*\z/i,            # Gmail / Apple Mail attribution line
      /\A\s*-+\s*Original Message\s*-+/i,
      /\A\s*From:\s.+/i,                    # Outlook-style header block
      /\A\s*_\._,_\._,_/,                   # groups.io footer delimiter
      /\A\s*Groups\.io Links:/i,
      /\A\s*Sent from my (iPhone|iPad|Android|phone)/i,
      /\A\s*--\s*\z/                        # signature delimiter
    ].freeze

    module_function

    def call(body, plain_text: true)
      text = plain_text ? body.to_s : html_to_text(body.to_s)
      text = text.gsub(/\r\n?/, "\n")
      # Gmail often wraps the attribution line across two lines.
      text = text.gsub(/^(\s*On [^\n]+)\n([^\n]*wrote:\s*)$/i, '\1 \2')

      kept = []
      text.each_line(chomp: true) do |line|
        break if CUT_MARKERS.any? { line.match?(_1) }
        next if line.match?(/\A\s*>/)

        kept << line
      end

      kept.join("\n").gsub(/[ \t ]+$/, "").gsub(/\n{3,}/, "\n\n").strip
    end

    def html_to_text(html)
      text = html.gsub(%r{<blockquote.*?</blockquote>}mi, "")
                 .sub(/<div[^>]*class="[^"]*(gmail_quote|gmail_extra|yahoo_quoted|moz-cite-prefix)[^"]*".*\z/mi, "")
                 .gsub(%r{<(style|script)[^>]*>.*?</\1>}mi, "")
                 .gsub(%r{<br\s*/?>}i, "\n")
                 .gsub(%r{</(p|div|li|tr|h\d)>}i, "\n")
                 .gsub(/<[^>]+>/, "")
      CGI.unescapeHTML(text).tr(" ", " ")
    end
  end
end
